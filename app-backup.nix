{
  config,
  lib,
  pkgs,
  ...
}:
let
  envFile = config.sops.templates."app-backup.env".path;
  passwordFile = config.sops.secrets."app_backup/restic_password".path;

  # Host binds (compose). MariaDB datadir is not restic'd live; dump first.
  grimmoryData = "/home/nico/grimmory/data";
  grimmoryBooks = "/home/nico/grimmory/books";
  grimmoryBookdrop = "/home/nico/grimmory/bookdrop";
  papraData = "/home/nico/papra/app-data";
  caddyData = "/home/nico/caddy/data";
  avenData = "/home/nico/aven-sync";
  # Navidrome state: DB (play counts, favorites), smart playlists, cache.
  navidromeData = "/home/nico/navidrome/data";

  app-backup = pkgs.writeShellApplication {
    name = "app-backup";
    runtimeInputs = with pkgs; [
      restic
      coreutils
      docker-client
    ];
    excludeShellChecks = [ "SC1090" ];
    text = ''
      # Restic of lab app data to a dedicated B2 repo (not the music repo).
      set -euo pipefail

      env_file=${lib.escapeShellArg envFile}
      password_file=${lib.escapeShellArg passwordFile}
      state_dir="''${STATE_DIRECTORY:-/var/lib/app-backup}"
      dump_dir="$state_dir/dumps"
      dump_sql="$dump_dir/grimmory.sql"

      if [[ ! -f $env_file ]]; then
        echo "app-backup: missing sops template $env_file (skip)" >&2
        exit 0
      fi
      if [[ ! -f $password_file ]]; then
        echo "app-backup: missing restic password at $password_file" >&2
        exit 1
      fi

      set -a
      # shellcheck source=/dev/null
      source "$env_file"
      set +a

      : "''${RESTIC_REPOSITORY:?RESTIC_REPOSITORY missing from sops template}"
      if [[ -z ''${B2_ACCOUNT_ID:-} || -z ''${B2_ACCOUNT_KEY:-} \
         || ''${B2_ACCOUNT_ID} == CHANGE_ME || ''${B2_ACCOUNT_KEY} == CHANGE_ME ]]; then
        echo "app-backup: B2 credentials still CHANGE_ME in sops (skip)" >&2
        exit 0
      fi
      export RESTIC_PASSWORD_FILE="$password_file"
      export RESTIC_REPOSITORY

      mkdir -p "$dump_dir"
      mariadb_running=$(
        docker inspect -f '{{.State.Running}}' mariadb 2>/dev/null || true
      )
      if docker info >/dev/null 2>&1 && [[ $mariadb_running == true ]]; then
        # Socket-root dump; --single-transaction keeps InnoDB consistent
        # without stopping Grimmory.
        docker exec -u 0 mariadb mariadb-dump -uroot \
          --single-transaction --databases grimmory > "$dump_sql"
        echo "app-backup: wrote $dump_sql" >&2
      else
        echo "app-backup: warning: mariadb not running; skip SQL dump" >&2
        rm -f "$dump_sql"
      fi

      backup_paths=()
      add_path() {
        local p=$1
        if [[ -e $p ]]; then
          backup_paths+=("$p")
        else
          echo "app-backup: warning: missing $p" >&2
        fi
      }
      add_path "$dump_sql"
      add_path ${lib.escapeShellArg grimmoryData}
      add_path ${lib.escapeShellArg grimmoryBooks}
      add_path ${lib.escapeShellArg grimmoryBookdrop}
      add_path ${lib.escapeShellArg papraData}
      add_path ${lib.escapeShellArg caddyData}
      add_path ${lib.escapeShellArg avenData}
      add_path ${lib.escapeShellArg navidromeData}

      if [[ ''${#backup_paths[@]} -eq 0 ]]; then
        echo "app-backup: nothing to back up" >&2
        exit 1
      fi

      keep_daily="''${RESTIC_KEEP_DAILY:-7}"
      keep_weekly="''${RESTIC_KEEP_WEEKLY:-4}"

      restic backup \
        --one-file-system \
        --tag apps \
        "''${backup_paths[@]}"

      restic forget \
        --tag apps \
        --keep-daily "$keep_daily" \
        --keep-weekly "$keep_weekly" \
        --prune

      restic snapshots --tag apps --latest 5
    '';
  };

  app-backup-init = pkgs.writeShellApplication {
    name = "app-backup-init";
    runtimeInputs = with pkgs; [
      restic
      coreutils
    ];
    excludeShellChecks = [ "SC1090" ];
    text = ''
      # Only if the B2 repo was never initialized.
      set -euo pipefail
      env_file=${lib.escapeShellArg envFile}
      password_file=${lib.escapeShellArg passwordFile}
      set -a
      # shellcheck source=/dev/null
      source "$env_file"
      set +a
      if [[ -z ''${B2_ACCOUNT_ID:-} || -z ''${B2_ACCOUNT_KEY:-} \
         || ''${B2_ACCOUNT_ID} == CHANGE_ME || ''${B2_ACCOUNT_KEY} == CHANGE_ME ]]; then
        echo "app-backup-init: B2 credentials still CHANGE_ME in sops" >&2
        exit 1
      fi
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
    app-backup
    app-backup-init
    pkgs.restic
  ];

  # Bind target for aven-sync. The image runs as distroless nonroot
  # (uid 65532). tmpfiles `d` resets mode/owner on every switch, so
  # this must match the container or the bind is unreadable.
  systemd.tmpfiles.rules = [
    "d ${avenData} 0700 65532 65532 -"
  ];

  sops = {
    secrets = {
      "app_backup/b2_account_id" = {
        sopsFile = ./secrets/app-backup.yaml;
      };
      "app_backup/b2_account_key" = {
        sopsFile = ./secrets/app-backup.yaml;
      };
      "app_backup/restic_password" = {
        sopsFile = ./secrets/app-backup.yaml;
      };
      "app_backup/restic_repository" = {
        sopsFile = ./secrets/app-backup.yaml;
      };
    };

    templates."app-backup.env" = {
      content = ''
        B2_ACCOUNT_ID=${config.sops.placeholder."app_backup/b2_account_id"}
        B2_ACCOUNT_KEY=${config.sops.placeholder."app_backup/b2_account_key"}
        RESTIC_REPOSITORY=${config.sops.placeholder."app_backup/restic_repository"}
        RESTIC_KEEP_DAILY=7
        RESTIC_KEEP_WEEKLY=4
      '';
    };
  };

  systemd.services.app-backup = {
    description = "Restic backup of lab app data to B2";
    wants = [
      "network-online.target"
      "docker.service"
    ];
    after = [
      "network-online.target"
      "docker.service"
    ];
    unitConfig = {
      ConditionPathExists = envFile;
    };
    serviceConfig = {
      Type = "oneshot";
      EnvironmentFile = envFile;
      Environment = [
        "HOME=/var/lib/app-backup"
        "XDG_CACHE_HOME=/var/lib/app-backup/cache"
      ];
      StateDirectory = "app-backup";
      ExecStart = lib.getExe app-backup;
      Nice = 10;
      IOSchedulingClass = "best-effort";
      IOSchedulingPriority = 7;
      TimeoutStartSec = "12h";
    };
  };

  systemd.timers.app-backup = {
    description = "Daily restic of lab app data to B2";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Before music-backup 03:30 and vzdump-b2 04:15.
      OnCalendar = "*-*-* 02:30:00";
      Persistent = true;
      RandomizedDelaySec = "15m";
      Unit = "app-backup.service";
    };
  };
}
