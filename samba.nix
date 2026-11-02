{
  lib,
  ...
}:
let
  # Same tree as music-share.nix / syncthing.nix (hub folder id music).
  musicPath = "/mnt/pve-backup/music";
  shareRoot = "/mnt/pve-backup";
in
{
  # Guest, read-only music for TVs / phones / file browsers (not Syncthing
  # peers). Trees are nico:users; force user so guest (nobody) can read.
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
        "force user" = "nico";
        "force group" = "users";
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
    after = [ "music-share-dirs.service" ];
    wants = [ "music-share-dirs.service" ];
    # Module already requires /var/lib/samba; keep that and wait for virtiofs.
    unitConfig.RequiresMountsFor = lib.mkForce "/var/lib/samba ${shareRoot}";
  };
}
