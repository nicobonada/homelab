{
  pkgs,
  ...
}:
let
  # Same virtiofs share as vzdump-b2 (host /mnt/backup → guest /mnt/pve-backup).
  shareRoot = "/mnt/pve-backup";
  musicPath = "${shareRoot}/music";
  beetsPath = "${shareRoot}/beets-state";
in
{
  # NFSv4 reexport of virtiofs music trees. Seats will mount later; Syncthing
  # hub stays until then. fsid= is required because this is a virtiofs
  # reexport. Do not export dump/.
  services.nfs.server = {
    enable = true;
    # Do NOT set openFirewall (that is all interfaces).
    exports = ''
      /mnt/pve-backup/music *(rw,fsid=1,no_subtree_check,root_squash)
      /mnt/pve-backup/beets-state *(rw,fsid=2,no_subtree_check,root_squash)
    '';
  };
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [ 2049 ];

  # First enable: mountd can start before nfs-server writes etab.
  systemd.services.nfs-mountd.serviceConfig = {
    Restart = "on-failure";
    RestartSec = "2s";
  };

  # Folder roots after virtiofs is up (tmpfiles races nofail mounts).
  # Trees are nico:users 0775 so hub Syncthing (group users) can write.
  systemd.services.music-share-dirs = {
    description = "Ensure music share paths on pve-backup";
    wantedBy = [
      "nfs-server.service"
      "syncthing.service"
      "samba-smbd.service"
    ];
    before = [
      "nfs-server.service"
      "syncthing.service"
      "samba-smbd.service"
    ];
    after = [ "local-fs.target" ];
    unitConfig.RequiresMountsFor = [ shareRoot ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "music-share-dirs" ''
        set -euo pipefail
        ${pkgs.coreutils}/bin/install -d -o nico -g users -m 0775 ${musicPath}
        ${pkgs.coreutils}/bin/install -d -o nico -g users -m 0775 ${beetsPath}
      '';
    };
  };
}
