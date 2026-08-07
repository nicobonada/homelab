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

All secrets are **sops + age** under `secrets/` (see `.sops.yaml`):

| File | Used by |
|------|---------|
| `secrets/vzdump-b2.yaml` | NixOS vzdump→B2 (sops-nix at activation) |
| `secrets/homepage.env` | Homepage: `HOMEPAGE_ALLOWED_HOSTS`, service URLs (`HOMEPAGE_VAR_*`), optional widget keys |
| `secrets/grimmory.env` | Grimmory + MariaDB |
| `secrets/papra.env` | Papra |

Homepage `stacks/homepage/config/*.yaml` uses `{{HOMEPAGE_VAR_*}}` placeholders only —
lab IPs / MagicDNS names stay in sops, not in public git. See
`stacks/homepage/secrets.env.example`.

Edit: `sops secrets/<name>.env` (or `.yaml`). Decrypted copies under `stacks/` are
gitignored and produced by `scripts/stack-up`.

## License

[MIT](./LICENSE) — use and adapt freely; no warranty.
