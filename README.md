# homelab

NixOS flake for a small **homelab** QEMU/KVM VM (`nixosConfigurations.homelab`).

Working personal config, not a template. Services and packages live in `configuration.nix`; this README only covers what does not age well next to the code.

## Secrets

**No plaintext secrets in this repo.** B2 credentials for vzdump offsite live in **`secrets/vzdump-b2.yaml`** (sops/age), same pattern as `~/nix-config` music-backup. The **age private key** stays on each machine at `~/.config/sops/age/keys.txt` (not committed). Other host secrets (Tailscale, Samba, SSH) are enrolled on the machine only. Disk labels/UUIDs in `hardware-configuration.nix` are machine-specific.

## vzdump → B2 (offsite)

Proxmox still writes dumps on the **PVE host** SSD (`/mnt/backup`). This VM only **reads** that tree over **NFS (RO)** and uploads with a current **rclone** (`vzdump-b2.nix` + sops-nix). Do **not** leave the old `rclone-backup` timer running on PVE.

### One-time on PVE (root console)

Install/export NFS for the dump disk only (LAN to this VM). Example:

```bash
apt install -y nfs-kernel-server
install -d -m 755 /etc/exports.d
printf '%s\n' '/mnt/backup 10.0.10.201(ro,sync,no_subtree_check,root_squash)' >/etc/exports.d/vzdump-homelab.exports
# /usr/sbin may be missing from PATH
/usr/sbin/exportfs -rav
systemctl enable --now nfs-server

# Stop and disable the legacy host-side upload (old rclone).
systemctl disable --now rclone-backup.timer
systemctl stop rclone-backup.service 2>/dev/null || true
```

Firewall: allow NFS from `10.0.10.201` only if you are not already wide-open on `vmbr0`.

### Age key on this host (sops-nix)

sops-nix decrypts at activation. Install the **same** personal age key used for `nix-config` (before or with the first switch that needs secrets):

```fish
install -d -m 700 ~/.config/sops/age
# from seyruun/oakhill, once:
scp ~/.config/sops/age/keys.txt homelab:.config/sops/age/keys.txt
chmod 600 ~/.config/sops/age/keys.txt
```

Edit secrets: `sops secrets/vzdump-b2.yaml` (needs `sops` + age key).

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
