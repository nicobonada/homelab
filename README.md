# homelab

NixOS flake for a small **homelab** QEMU/KVM VM. Stable channel (`nixos-26.05`).

This host is the core of a home lab: mesh VPN, recursive/split DNS, Docker, and a read-only Samba share for media.

## What it runs

| Piece | Role |
|-------|------|
| **Tailscale** | Mesh access; MagicDNS used for Docker (`100.100.100.100`) |
| **Technitium DNS** | DNS server (firewall opened) |
| **Docker** | Containers for lab services |
| **Samba** | Read-only `music` share under `/mnt/backup-drive` |
| **OpenSSH** | Remote shell / `nixos-rebuild --target-host` |
| **QEMU guest agent** | Host ↔ guest integration |

Also: `nh`, neovim as default editor, common CLI tools (`bat`, `btop`, …).

## Assumptions

- **x86_64** QEMU guest with systemd-boot + EFI
- Extra disk labeled **`stuff-backup`** mounted at `/mnt/backup-drive` (see `hardware-configuration.nix`)
- Machines that deploy remotely can reach the host over **Tailscale** (hostname `homelab`)
- Samba users/passwords and Tailscale enrollment are **not** in this repo (set on the machine)

Disk UUIDs and labels in `hardware-configuration.nix` are machine-specific; regenerate or edit them for another host.

## Secrets and credentials

**No secrets are stored in this repository.** In particular you will not find:

- Tailscale auth keys
- SSH private keys or authorized_keys lists managed here
- Samba password hashes
- API tokens or cloud credentials

Join Tailscale, create Samba users, and configure SSH keys **out of band** on the host (or introduce something like [sops-nix](https://github.com/Mic92/sops-nix) / [agenix](https://github.com/ryantm/agenix) later if you want secrets in git).

This is a personal system config published for reference. Treat firewall, SSH, and sudo policy as yours to harden for your network.

## Deploy

Build and activate on the host:

```fish
nh os switch .
# or: sudo nixos-rebuild switch --flake .#homelab
```

From another machine on the tailnet, as root over Tailscale SSH:

```fish
cd ~/homelab
nixos-rebuild switch --flake .#homelab --target-host root@homelab
```

Smoke-test build without activating:

```fish
nixos-rebuild build --flake .#homelab --target-host root@homelab
```

## Adapting this flake

1. Clone and point `nixpkgs` at a channel you use (or keep `nixos-26.05` and update `flake.lock`).
2. Replace `hardware-configuration.nix` with output from `nixos-generate-config` on your machine (or adjust filesystems/boot).
3. Rename the host: `networking.hostName`, the flake attribute `nixosConfigurations.homelab`, and deploy commands.
4. Change user name, packages, and services in `configuration.nix` to match your lab.
5. Do **not** copy `system.stateVersion` casually — leave it unless you know why you are changing it ([NixOS FAQ](https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion)).

## Layout

```text
flake.nix                 # inputs + nixosConfigurations.homelab
configuration.nix         # system config (services, users, packages)
hardware-configuration.nix
flake.lock
```

Single-host on purpose. Split into `hosts/` + `modules/` when a second machine appears or `configuration.nix` gets noisy.

## License

[MIT](./LICENSE) — use and adapt freely; no warranty.
