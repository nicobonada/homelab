{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Host path /mnt/backup shared into this guest via PVE Directory Mapping
  # (Datacenter → Directory Mappings → id "pve-backup" → /mnt/backup).
  # Guest mount tag must match the mapping id. Not hot-pluggable: reboot after attach.
  virtiofsTag = "pve-backup";
  mountPoint = "/mnt/pve-backup";
  # Same bucket the old pve rclone job used.
  b2Bucket = "nico-homelab-proxmox-backup";

  # Decrypted by sops-nix at activation (age key: ~/.config/sops/age/keys.txt).
  envFile = config.sops.templates."vzdump-b2.env".path;

  # Only the vzdump tree — not lost+found on the host volume.
  rcloneFlags = [
    "sync"
    "${mountPoint}/dump"
    "backblaze:${b2Bucket}/dump"
    # No interactive config file; credentials come from the sops env template.
    "--config"
    "/dev/null"
    # Reliability over throughput: multi‑GiB .vma.zst + B2 multipart.
    "--transfers"
    "1"
    "--checkers"
    "2"
    "--b2-upload-concurrency"
    "1"
    # Permanently delete on remove so failed uploads do not leave billable hide versions.
    "--b2-hard-delete"
    # Avoid multi-thread reader issues on multi‑GiB files.
    "--multi-thread-streams"
    "0"
    "--order-by"
    "modtime,descending"
    "--stats"
    "1m"
    "--retries"
    "5"
    "--low-level-retries"
    "20"
    "--log-level"
    "INFO"
  ];
in
{
  # PVE virtio-fs share of host dump tree (replaces soft NFS).
  fileSystems.${mountPoint} = {
    device = virtiofsTag;
    fsType = "virtiofs";
    options = [
      "ro"
      "nofail"
    ];
  };

  environment.systemPackages = [
    pkgs.rclone
    pkgs.sops
    pkgs.age
  ];

  # B2 app key: secrets/vzdump-b2.yaml (age-encrypted for workstation + this host).
  # System activation runs as root, so decrypt via host SSH key (not nico's
  # ~/.config/sops/age/keys.txt, which root cannot read).
  sops = {
    defaultSopsFile = ./secrets/vzdump-b2.yaml;
    defaultSopsFormat = "yaml";
    age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

    secrets = {
      "vzdump_b2/b2_account_id" = { };
      "vzdump_b2/b2_account_key" = { };
    };

    templates."vzdump-b2.env" = {
      content = ''
        RCLONE_CONFIG_BACKBLAZE_TYPE=b2
        RCLONE_CONFIG_BACKBLAZE_ACCOUNT=${config.sops.placeholder."vzdump_b2/b2_account_id"}
        RCLONE_CONFIG_BACKBLAZE_KEY=${config.sops.placeholder."vzdump_b2/b2_account_key"}
      '';
    };
  };

  # Offsite copy of Proxmox vzdump archives. Source is virtio-fs from PVE;
  # B2 credentials via sops template (never plaintext in the repo).
  systemd.services.vzdump-b2 = {
    description = "Rclone sync of PVE vzdump tree to Backblaze B2";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig = {
      # Skip until sops-nix has rendered the template (age key present on host).
      ConditionPathExists = envFile;
      # Wait for virtiofs mount.
      RequiresMountsFor = mountPoint;
    };
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = envFile;
      # rclone looks up $HOME for a config dir; keep it off the root of /.
      Environment = [
        "HOME=/var/lib/vzdump-b2"
      ];
      StateDirectory = "vzdump-b2";
      # Fail loud if the dump tree is missing (share down or wrong path).
      ExecStartPre = "${pkgs.coreutils}/bin/test -d ${mountPoint}/dump";
      ExecStart = lib.escapeShellArgs (
        [
          "${pkgs.rclone}/bin/rclone"
        ]
        ++ rcloneFlags
      );
      Nice = 10;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
      # Multi-hour multi‑GiB uploads; do not kill mid-transfer on a short default.
      TimeoutStartSec = "12h";
    };
    # Not started at boot; timer (or manual start) only.
  };

  systemd.timers.vzdump-b2 = {
    description = "Daily offsite sync of PVE vzdumps to B2";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # After typical vzdump ~02:00 on PVE; former pve job was ~04:00.
      OnCalendar = "*-*-* 04:15:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
      Unit = "vzdump-b2.service";
    };
  };

  # Manual smoke: copies one tiny .log to B2 (not on a timer).
  systemd.services.vzdump-b2-smoke = {
    description = "Smoke-test B2 auth with one small vzdump log";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig = {
      ConditionPathExists = envFile;
      RequiresMountsFor = mountPoint;
    };
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = envFile;
      Environment = [ "HOME=/var/lib/vzdump-b2" ];
      StateDirectory = "vzdump-b2";
      ExecStart = lib.escapeShellArgs [
        "${pkgs.rclone}/bin/rclone"
        "copy"
        "${mountPoint}/dump"
        "backblaze:${b2Bucket}/dump"
        "--config"
        "/dev/null"
        "--include"
        "*.log"
        "--include"
        "*.notes"
        "-v"
      ];
    };
  };
}
