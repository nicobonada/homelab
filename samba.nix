{
  lib,
  ...
}:
let
  # Same tree as music-share.nix.
  musicPath = "/mnt/pve-backup/music";
  shareRoot = "/mnt/pve-backup";
in
{
  # Guest, read-only music for TVs / phones / file browsers. Trees are
  # nico:users; force user so guest (nobody) can read.
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
