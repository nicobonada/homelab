{
  lib,
  ...
}:
let
  # Same tree as syncthing.nix (hub folder id music). Keep in sync.
  musicPath = "/mnt/pve-backup/music";
  shareRoot = "/mnt/pve-backup";
in
{
  # Guest, read-only music for TVs / phones / file browsers (not Syncthing peers).
  # force user: music root is 0750 syncthing:syncthing; guest is nobody.
  services.samba = {
    enable = true;
    openFirewall = true;
    settings = {
      global = {
        workgroup = "WORKGROUP";
        "server string" = "homelab";
        security = "user";
        "map to guest" = "Bad User";
      };
      music = {
        path = musicPath;
        browseable = "yes";
        "read only" = "yes";
        "guest ok" = "yes";
        "force user" = "syncthing";
        "force group" = "syncthing";
        comment = "Music library (read-only)";
        # Syncthing internals are not media.
        "hide files" = "/.stfolder/.stignore/.stversions/";
        "veto files" = "/.stfolder/.stignore/.stversions/";
      };
    };
  };

  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
    workgroup = "WORKGROUP";
  };

  systemd.services.samba-smbd = {
    after = [ "syncthing-share-dirs.service" ];
    wants = [ "syncthing-share-dirs.service" ];
    # Module already requires /var/lib/samba; keep that and wait for virtiofs.
    unitConfig.RequiresMountsFor = lib.mkForce "/var/lib/samba ${shareRoot}";
  };
}
