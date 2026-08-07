# homelab

Personal [NixOS](https://nixos.org/) configuration for a small lab VM
(`nixosConfigurations.homelab`), plus optional Docker Compose **app** stacks
under [`stacks/`](stacks/).

Working personal config, not a template — steal ideas freely. Details live in
the Nix files and compose files; this README only covers what does not age well
next to the code.

Uses [Determinate Nix](https://determinate.systems/) and
[sops-nix](https://github.com/Mic92/sops-nix).

**System** (NixOS) and **apps** (Compose) are deployed separately on purpose.

## Secrets

NixOS secrets: sops + age under `secrets/` (see `.sops.yaml`).

Compose secrets: `stacks/*/.env` and `stacks/*/secrets.env` (gitignored);
start from each stack’s `*.example` files.

## License

[MIT](./LICENSE) — use and adapt freely; no warranty.
