# homelab

Personal [NixOS](https://nixos.org/) for the **homelab** QEMU/KVM VM
(`nixosConfigurations.homelab`).

Working personal config, not a template — steal ideas freely.

Docker Compose stacks live in a **separate** repo (`homelab-stacks`), not here.
This flake is **system only**: boot, network, Docker engine, sops, vzdump→B2, etc.

## Layout

| File | Role |
|------|------|
| `flake.nix` | nixpkgs 26.05, Determinate Nix, sops-nix |
| `configuration.nix` | Host services (docker, ssh, samba off, nh, sudo) |
| `hardware-configuration.nix` | Disks / EFI for this VM |
| `vzdump-b2.nix` | Virtiofs dump tree → rclone B2 timer |
| `secrets/` | sops-encrypted secrets (age) |

## Secrets

- Edit on a workstation: `sops secrets/<file>.yaml` (personal age key).
- At activation, sops-nix decrypts with the **host SSH age key**
  (`/etc/ssh/ssh_host_ed25519_key` → age recipient in `.sops.yaml`).
- Do not commit plaintext keys or B2 tokens.

## Deploy (from a workstation)

**Source of truth:** this repo on oakhill/seyruun (`~/src/homelab`), pushed to
GitHub. **Do not** keep a long-lived config checkout on the VM for day-to-day
applies. **Do not** use `/etc/nixos` (ancient leftover).

Both machines are `x86_64-linux`. Build on the workstation, activate over SSH:

```fish
cd ~/src/homelab
# after edits: record, land, push main (jj) as usual

nh os switch . \
  --hostname homelab \
  --target-host nico@homelab \
  --elevation-strategy passwordless
```

Equivalent with stock tools:

```fish
nixos-rebuild switch --flake .#homelab \
  --target-host nico@homelab \
  --elevate sudo
```

Requires:

- SSH as **`nico@homelab`** (Tailscale or LAN)
- `wheelNeedsPassword = false` for `nico` (this flake) so remote
  `nixos-rebuild`/`nh` activation can elevate without a TTY
- `PermitRootLogin = no` — deploy is user SSH + sudo, not root login

`jj` stays on the workstation. The VM only needs git if you choose to clone for
recovery; normal deploys never pull on the host.

## Offsite backups (vzdump → B2)

Proxmox writes dumps on the hypervisor at `/mnt/backup` (USB **Samsung T7
Shield**). This guest mounts that tree **read-only via virtio-fs** (Directory
Mapping id **`pve-backup`**) and runs the `vzdump-b2` timer (rclone + sops).

- Not hot-pluggable: reboot the guest after attaching the mapping.
- Do **not** passthrough the T7 USB into the guest.
- Do **not** run the old PVE `rclone-backup` unit in parallel.
- One-shot PVE disk migration (run on **PVE as root**, not this guest):
  `scripts/pve-migrate-backup-to-t7.sh`

## Related

| Repo / path | Purpose |
|-------------|---------|
| `nicobonada/homelab` (this) | NixOS system for the VM |
| `homelab-stacks` | Docker Compose / Arcane projects |
| Workstations `nix-config` | oakhill / seyruun HM + NixOS |

## License

[MIT](./LICENSE) — use and adapt freely; no warranty.
