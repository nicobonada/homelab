{
  config,
  lib,
  pkgs,
  ...
}:
let
  # PVE hypervisor LAN IP (vmbr0). Dumps stay on the host SSD; this VM only reads them.
  pveLan = "10.0.10.200";
  exportPath = "/mnt/backup";
  mountPoint = "/mnt/pve-backup";
  # Same bucket the old pve rclone job used.
  b2Bucket = "nico-homelab-proxmox-backup";
  # Root-only env file (not in git). See README "vzdump → B2".
  # Expected keys (rclone env-config form):
  #   RCLONE_CONFIG_BACKBLAZE_TYPE=b2
  #   RCLONE_CONFIG_BACKBLAZE_ACCOUNT=...
  #   RCLONE_CONFIG_BACKBLAZE_KEY=...
  envFile = "/etc/vzdump-b2.env";

  rcloneFlags = [
    "sync"
    mountPoint
    "backblaze:${b2Bucket}"
    # Reliability over throughput: large .vma.zst + B2 multipart was thrashing on pve
    # with concurrent transfers and ancient rclone (sha1 hash differ after 100%).
    "--transfers"
    "1"
    "--checkers"
    "2"
    "--b2-upload-concurrency"
    "1"
    "--order-by"
    "modtime,descending"
    "--retries"
    "5"
    "--low-level-retries"
    "20"
    "--log-level"
    "INFO"
  ];
in
{
  # NFS client for RO dump tree from PVE (vzdump still writes on the host).
  boot.supportedFilesystems = [ "nfs" ];
  services.rpcbind.enable = true;

  fileSystems.${mountPoint} = {
    device = "${pveLan}:${exportPath}";
    fsType = "nfs";
    options = [
      "ro"
      "nfsvers=4"
      "_netdev"
      "nofail"
      "x-systemd.automount"
      "x-systemd.mount-timeout=30s"
      "soft"
      "timeo=100"
      "retrans=2"
    ];
  };

  environment.systemPackages = [
    pkgs.rclone
    pkgs.nfs-utils
  ];

  # Offsite copy of Proxmox vzdump archives. Source is NFS RO from PVE;
  # credentials live only on this host in envFile.
  systemd.services.vzdump-b2 = {
    description = "Rclone sync of PVE vzdump tree to Backblaze B2";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig = {
      # Skip cleanly until secrets exist (first boot / before you copy B2 keys).
      ConditionPathExists = envFile;
      # Triggers the NFS automount and waits for it.
      RequiresMountsFor = mountPoint;
    };
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = envFile;
      # Fail loud if the NFS tree is missing dumps (export down or wrong path).
      ExecStartPre = "${pkgs.coreutils}/bin/test -d ${mountPoint}/dump";
      ExecStart = lib.escapeShellArgs ([ "${pkgs.rclone}/bin/rclone" ] ++ rcloneFlags);
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
}
