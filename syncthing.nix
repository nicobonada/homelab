{
  config,
  lib,
  pkgs,
  ...
}:
let
  # Same virtiofs share as vzdump-b2 (host /mnt/backup → guest /mnt/pve-backup).
  shareRoot = "/mnt/pve-backup";
  musicPath = "${shareRoot}/music";
  beetsPath = "${shareRoot}/beets-state";

  # Device IDs are public (not secrets). Seats peer only this hub (star).
  devices = {
    oakhill = {
      id = "ZC7PNBQ-FFG4N6Y-C6KXDJW-2Z6Y3UP-PXURVNT-ZRP4G5C-3PQSMOQ-JX5AXAH";
    };
    seyruun = {
      id = "7DNZCNL-IGE7LTO-WSLAO3Y-26SUKHW-DZAZXUG-RGOFG2B-2DP6CVA-AR4CRAY";
    };
  };

  peerNames = builtins.attrNames devices;

  folderCommon = {
    type = "sendreceive";
    devices = peerNames;
    versioning = {
      type = "simple";
      params.keep = "5";
    };
  };
in
{
  # Hub copies. Seats: nix-config home/services/syncthing.nix
  # This host id (for seats): N4ARH42-726Q7IQ-Z6ORENS-7TGCZ42-YZLOYUI-KY3FML2-BGGZX6C-CZFIUQ4
  services.syncthing = {
    enable = true;
    openDefaultPorts = true;
    guiAddress = "127.0.0.1:8384";
    overrideDevices = true;
    overrideFolders = true;
    settings = {
      devices = devices;
      folders = {
        music = folderCommon // {
          id = "music";
          label = "music";
          path = musicPath;
        };
        beets-state = folderCommon // {
          id = "beets-state";
          label = "beets-state";
          path = beetsPath;
        };
      };
      options = {
        urAccepted = -1;
      };
    };
  };

  # Create folder roots after virtiofs is up (tmpfiles races nofail mounts).
  systemd.services.syncthing-share-dirs = {
    description = "Ensure Syncthing paths on pve-backup";
    wantedBy = [ "syncthing.service" ];
    before = [ "syncthing.service" ];
    after = [ "local-fs.target" ];
    unitConfig.RequiresMountsFor = [ shareRoot ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "syncthing-share-dirs" ''
        set -euo pipefail
        ${pkgs.coreutils}/bin/install -d -o syncthing -g syncthing -m 0750 ${musicPath}
        ${pkgs.coreutils}/bin/install -d -o syncthing -g syncthing -m 0750 ${beetsPath}
      '';
    };
  };

  systemd.services.syncthing = {
    requires = [ "syncthing-share-dirs.service" ];
    after = [ "syncthing-share-dirs.service" ];
    unitConfig.RequiresMountsFor = [ shareRoot ];
  };
}
