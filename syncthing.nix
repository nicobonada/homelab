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
    # All interfaces so Caddy/Homepage can scrape via host.docker.internal.
    # Tailnet :8384 stays closed; humans use https://sync.lab.bonada.ca.
    guiAddress = "0.0.0.0:8384";
    overrideDevices = true;
    overrideFolders = true;
    # Do not set settings.gui: 26.05 syncthing-init PUTs /rest/config/gui
    # and rotates the API key (nixpkgs#428808). 26.11 uses PATCH (#529449).
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

  # Compose apps use a user bridge; docker0 stays DOWN. host.docker.internal is
  # still 172.17.0.1, so an interface-only docker0 rule never matches. Open 8384
  # like Technitium. Human URL stays https://sync.lab.bonada.ca; set a GUI
  # password (Syncthing Actions → Settings) now that the console is reachable.
  networking.firewall.allowedTCPPorts = [ 8384 ];

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
