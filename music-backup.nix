{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Same virtiofs share as vzdump / Syncthing music hub.
  shareRoot = "/mnt/pve-backup";
  musicPath = "${shareRoot}/music";
  beetsPath = "${shareRoot}/beets-state";

  envFile = config.sops.templates."music-backup.env".path;
  passwordFile = config.sops.secrets."music_backup/restic_password".path;

  music-backup = pkgs.writeShellApplication {
    name = "music-backup";
    runtimeInputs = with pkgs; [
      restic
      coreutils
      findutils
    ];
    excludeShellChecks = [ "SC1090" ];
    text = ''
      # Restic backup of Syncthing hub trees to the existing music B2 repo.
      # Paths: music library + beets-state (library.db / state.pickle).
      # Seat restic timers are retired; this host is sole forget/prune owner.
      set -euo pipefail

      env_file=${lib.escapeShellArg envFile}
      password_file=${lib.escapeShellArg passwordFile}
      music=${lib.escapeShellArg musicPath}
      beets=${lib.escapeShellArg beetsPath}

      if [[ ! -f $env_file ]]; then
        echo "music-backup: missing sops template $env_file (skip)" >&2
        exit 0
      fi
      if [[ ! -f $password_file ]]; then
        echo "music-backup: missing restic password at $password_file" >&2
        exit 1
      fi
      if [[ ! -d $music ]]; then
        echo "music-backup: missing $music (skip; wait for Syncthing hub)" >&2
        exit 0
      fi

      set -a
      # shellcheck source=/dev/null
      source "$env_file"
      set +a

      : "''${RESTIC_REPOSITORY:?RESTIC_REPOSITORY missing from sops template}"
      if [[ -z ''${B2_ACCOUNT_ID:-} || -z ''${B2_ACCOUNT_KEY:-} \
         || ''${B2_ACCOUNT_ID} == CHANGE_ME || ''${B2_ACCOUNT_KEY} == CHANGE_ME ]]; then
        echo "music-backup: B2 credentials still CHANGE_ME in sops (skip)" >&2
        exit 0
      fi
      export RESTIC_PASSWORD_FILE="$password_file"
      export RESTIC_REPOSITORY

      keep_daily="''${RESTIC_KEEP_DAILY:-3}"
      keep_weekly="''${RESTIC_KEEP_WEEKLY:-1}"

      backup_paths=("$music")
      if [[ -d $beets ]]; then
        backup_paths+=("$beets")
      else
        echo "music-backup: warning: no beets-state at $beets yet" >&2
      fi

      # Syncthing markers / versioning are not media.
      restic backup \
        --one-file-system \
        --tag music \
        --tag hub \
        --exclude .stfolder \
        --exclude .stversions \
        --exclude .stignore.tmp \
        "''${backup_paths[@]}"

      restic forget \
        --tag music \
        --keep-daily "$keep_daily" \
        --keep-weekly "$keep_weekly" \
        --prune

      restic snapshots --tag music --latest 5
    '';
  };

  music-backup-init = pkgs.writeShellApplication {
    name = "music-backup-init";
    runtimeInputs = with pkgs; [
      restic
      coreutils
    ];
    excludeShellChecks = [ "SC1090" ];
    text = ''
      # Only if the B2 repo was never initialized (normally already exists).
      set -euo pipefail
      env_file=${lib.escapeShellArg envFile}
      password_file=${lib.escapeShellArg passwordFile}
      set -a
      # shellcheck source=/dev/null
      source "$env_file"
      set +a
      export RESTIC_PASSWORD_FILE="$password_file"
      export RESTIC_REPOSITORY
      restic snapshots >/dev/null 2>&1 && {
        echo "Repo already initialized: $RESTIC_REPOSITORY"
        exit 0
      }
      restic init
      echo "Initialized $RESTIC_REPOSITORY"
    '';
  };
in
{
  environment.systemPackages = [
    music-backup
    music-backup-init
    pkgs.restic
  ];

  sops = {
    # Merges with vzdump-b2 age.sshKeyPaths (same host key).
    secrets = {
      "music_backup/b2_account_id" = {
        sopsFile = ./secrets/music-backup.yaml;
      };
      "music_backup/b2_account_key" = {
        sopsFile = ./secrets/music-backup.yaml;
      };
      "music_backup/restic_password" = {
        sopsFile = ./secrets/music-backup.yaml;
      };
      "music_backup/restic_repository" = {
        sopsFile = ./secrets/music-backup.yaml;
      };
    };

    templates."music-backup.env" = {
      content = ''
        B2_ACCOUNT_ID=${config.sops.placeholder."music_backup/b2_account_id"}
        B2_ACCOUNT_KEY=${config.sops.placeholder."music_backup/b2_account_key"}
        RESTIC_REPOSITORY=${config.sops.placeholder."music_backup/restic_repository"}
        RESTIC_KEEP_DAILY=3
        RESTIC_KEEP_WEEKLY=1
      '';
    };
  };

  systemd.services.music-backup = {
    description = "Restic backup of hub music + beets-state to B2";
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    unitConfig = {
      ConditionPathExists = envFile;
      RequiresMountsFor = shareRoot;
    };
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = envFile;
      # restic cache/config home (system unit has no $HOME by default).
      Environment = [
        "HOME=/var/lib/music-backup"
        "XDG_CACHE_HOME=/var/lib/music-backup/cache"
      ];
      StateDirectory = "music-backup";
      # restic reads RESTIC_PASSWORD_FILE from the script; template has B2 + repo.
      ExecStart = lib.getExe music-backup;
      Nice = 10;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
      TimeoutStartSec = "12h";
    };
  };

  systemd.timers.music-backup = {
    description = "Daily restic of hub music library to B2";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:30:00";
      Persistent = true;
      RandomizedDelaySec = "20m";
      Unit = "music-backup.service";
    };
  };
}
