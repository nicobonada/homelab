{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Same virtiofs share as vzdump-b2 (host /mnt/backup → guest /mnt/pve-backup).
  musicPath = "/mnt/pve-backup/music";
  musicParent = "/mnt/pve-backup";

  # Device IDs are public (not secrets). Collect from journal:
  #   journalctl -u syncthing | rg 'Calculated our device ID'
  # Seats use HM Syncthing and only peer this hub (star topology).
  devices = {
    oakhill = {
      id = "ZC7PNBQ-FFG4N6Y-C6KXDJW-2Z6Y3UP-PXURVNT-ZRP4G5C-3PQSMOQ-JX5AXAH";
    };
    seyruun = {
      id = "7DNZCNL-IGE7LTO-WSLAO3Y-26SUKHW-DZAZXUG-RGOFG2B-2DP6CVA-AR4CRAY";
    };
  };

  peerNames = builtins.attrNames devices;
in
{
  # Always-on hub copy of the music library. Seats use home-manager Syncthing
  # (nix-config); folder id `music` must match on every node.
  # This host's own id (for seats): N4ARH42-726Q7IQ-Z6ORENS-7TGCZ42-YZLOYUI-KY3FML2-BGGZX6C-CZFIUQ4
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    guiAddress = "127.0.0.1:8384";
    # Default user/group `syncthing` + dataDir /var/lib/syncthing (module-managed).
    # Folder path is absolute on the virtiofs share, not under dataDir.
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = devices;
      folders = {
        music = {
          id = "music";
          label = "music";
          path = musicPath;
          type = "sendreceive";
          devices = peerNames;
          # Soft safety net for accidental deletes on a seat.
          versioning = {
            type = "simple";
            params.keep = "5";
          };
        };
      };
      options = {
        # Prefer direct / Tailscale; relays still OK as fallback for v1.
        urAccepted = -1;
      };
    };
  };

  # tmpfiles can race a nofail virtiofs mount (parent not ready → no music/).
  # Create after the share is up, before syncthing starts.
  systemd.services.syncthing-music-dir = {
    description = "Ensure Syncthing music path on pve-backup";
    wantedBy = [ "syncthing.service" ];
    before = [ "syncthing.service" ];
    after = [ "local-fs.target" ];
    unitConfig.RequiresMountsFor = [ musicParent ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.coreutils}/bin/install -d -o syncthing -g syncthing -m 0750 ${musicPath}";
    };
  };

  systemd.services.syncthing = {
    requires = [ "syncthing-music-dir.service" ];
    after = [ "syncthing-music-dir.service" ];
    unitConfig.RequiresMountsFor = [ musicParent ];
  };
}
