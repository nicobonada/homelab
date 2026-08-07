# homelab

Personal [NixOS](https://nixos.org/) configuration for a small QEMU/KVM VM (`nixosConfigurations.homelab`).

Working personal config, not a template — steal ideas freely. Details live in the Nix files; this README only covers what does not age well next to the code.

Uses [Determinate Nix](https://determinate.systems/) (same family as the workstations). Layout: `configuration.nix` + `hardware-configuration.nix`, with `vzdump-b2.nix` for offsite Proxmox dump sync.

## Secrets

Secrets live **in this repo**, encrypted with [sops-nix](https://github.com/Mic92/sops-nix) + age (`secrets/`, `.sops.yaml`).

- Edit from a workstation: `sops secrets/<file>.yaml` (personal age key).
- System activation decrypts with the **host SSH age key** (root cannot read `~/.config/sops/age/keys.txt`).
- Tailscale, Samba, and other machine bootstrap stay off-repo.

## Deploy

| Where | Role |
|-------|------|
| **oakhill / seyruun** `~/src/homelab` | Edit with **jj**; push `main` to GitHub |
| **homelab** `~/homelab-deploy` | **git** only: pull + switch (no jj) |

**Do not** use `/etc/nixos` — that tree is an ancient leftover.

### Workstation

```fish
cd ~/src/homelab
# edit… record on wip, land, then:
jj git fetch
jj git push --bookmark main
```

### Homelab host

```fish
cd ~/homelab-deploy
git pull --ff-only
nh os switch .
# or: sudo nixos-rebuild switch --flake .#homelab
```

Optional: `set -x NH_FLAKE /home/nico/homelab-deploy` so bare `nh os switch` targets this tree.

## Offsite backups (vzdump → B2)

Proxmox writes dumps on the hypervisor at `/mnt/backup` (USB **Samsung T7 Shield**, not the flaky SanDisk Extreme). This VM mounts that tree **read-only via virtio-fs** (Directory Mapping id `pve-backup`) and runs `vzdump-b2` (rclone + sops) on a daily timer. Do not run the old PVE `rclone-backup` unit in parallel. Virtiofs is not hot-pluggable — reboot the guest after attaching the share. See `vzdump-b2.nix` for mount path, bucket, and timer.

Do **not** SCSI/USB-passthrough the T7 into this guest — the host owns it for `vzdump`.

One-shot PVE disk migration notes: `scripts/pve-migrate-backup-to-t7.sh` (run on the **Proxmox host** as root, not in this guest).

## License

[MIT](./LICENSE) — use and adapt freely; no warranty.
