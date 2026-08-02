# homelab

NixOS flake for a small **homelab** QEMU/KVM VM (`nixosConfigurations.homelab`).

Working personal config, not a template. Services and packages live in `configuration.nix`; this README only covers what does not age well next to the code.

## Secrets

**No secrets in this repo** (no Tailscale auth keys, SSH private keys, Samba password hashes, or API tokens). Enroll Tailscale, set Samba users, and configure SSH on the host. Disk labels/UUIDs in `hardware-configuration.nix` are machine-specific.

## Deploy

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

## License

[MIT](./LICENSE) — use and adapt freely; no warranty.
