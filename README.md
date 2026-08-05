# homelab

NixOS flake for a small **homelab** QEMU/KVM VM (`nixosConfigurations.homelab`).

Working personal config, not a template. Services and packages live in `configuration.nix`; this README only covers what does not age well next to the code.

## Secrets

**No secrets in this repo** (no Tailscale auth keys, SSH private keys, Samba password hashes, API tokens, or B2 keys). Enroll Tailscale, set Samba users, and configure SSH on the host. Disk labels/UUIDs in `hardware-configuration.nix` are machine-specific.

## vzdump → B2 (offsite)

Proxmox still writes dumps on the **PVE host** SSD (`/mnt/backup`). This VM only **reads** that tree over **NFS (RO)** and uploads with a current **rclone** (`vzdump-b2.nix`). Do **not** leave the old `rclone-backup` timer running on PVE.

### One-time on PVE (root console)

Install/export NFS for the dump disk only (LAN to this VM). Example:

```bash
apt install -y nfs-kernel-server
install -d -m 755 /etc/exports.d
printf '%s\n' '/mnt/backup 10.0.10.201(ro,sync,no_subtree_check,root_squash)' >/etc/exports.d/vzdump-homelab.exports
exportfs -rav
systemctl enable --now nfs-server

# Stop and disable the legacy host-side upload (old rclone).
systemctl disable --now rclone-backup.timer
systemctl stop rclone-backup.service 2>/dev/null || true
```

Firewall: allow NFS from `10.0.10.201` only if you are not already wide-open on `vmbr0`.

Copy B2 app key material off the old rclone config into the VM (see below). Prefer a **bucket-scoped** app key for `nico-homelab-proxmox-backup` (not the master key).

### Secrets on homelab

```fish
sudo install -m 600 -o root -g root /dev/null /etc/vzdump-b2.env
sudo $EDITOR /etc/vzdump-b2.env
```

```text
RCLONE_CONFIG_BACKBLAZE_TYPE=b2
RCLONE_CONFIG_BACKBLAZE_ACCOUNT=your_key_id
RCLONE_CONFIG_BACKBLAZE_KEY=your_application_key
```

### Deploy + first run

On the host:

```fish
nh os switch .
# or: sudo nixos-rebuild switch --flake .#homelab
```

From another machine on the tailnet (as root over Tailscale SSH):

```fish
nixos-rebuild switch --flake .#homelab --target-host root@homelab
```

Smoke-test without activating: same command with `build` instead of `switch`.

Then:

```fish
# Mount should show dump/ from PVE
ls /mnt/pve-backup/dump
sudo systemctl start vzdump-b2.service
journalctl -u vzdump-b2.service -f
systemctl status vzdump-b2.timer
```

Timer: daily ~**04:15** (jitter up to 15m), after typical vzdump ~02:00.

## License

[MIT](./LICENSE) — use and adapt freely; no warranty.
