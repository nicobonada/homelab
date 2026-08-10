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

## Workstation shell

Rare tools live in the flake devShell (not home-manager). From a checkout:

```text
nix develop
# or: direnv allow  (once; then cd into the repo)
```

Includes Docker **client** + Compose, **sops**, and **`bao`**. The shell
sets `DOCKER_HOST=ssh://nico@homelab` so plain `docker` / `docker compose` talk to
the lab (override for a local daemon if you ever need one).
**Grok** is on the interactive PATH via home-manager (not this shell).

## Secrets

All secrets are **sops + age** under `secrets/` (see `.sops.yaml`):

| File | Used by |
|------|---------|
| `secrets/vzdump-b2.yaml` | NixOS vzdump→B2 (sops-nix at activation) |
| `secrets/openbao.env` | OpenBao unseal key + root token only (`scripts/openbao-bootstrap`) |
| `secrets/homepage.env` | Homepage: `HOMEPAGE_ALLOWED_HOSTS`, service URLs (`HOMEPAGE_VAR_*`), optional widget keys |
| `secrets/grimmory.env` | Grimmory + MariaDB |
| `secrets/papra.env` | Papra |

Homepage `stacks/homepage/config/*.yaml` uses `{{HOMEPAGE_VAR_*}}` placeholders only —
lab hosts stay in sops, not in public git. See `stacks/homepage/secrets.env.example`.

**OpenBao** (`stacks/openbao/`) is the planned home for app secrets (KV
`secret/stacks/{homepage,grimmory,papra}`). Until migration, `deploy-containers` still
decrypts the app `secrets/*.env` files above. sops remains long-term for NixOS
and for OpenBao unseal/root.

Edit: `sops secrets/<name>.env` (or `.yaml`). Decrypted copies under `stacks/` are
gitignored and produced by `scripts/deploy-containers`.

## License

[MIT](./LICENSE) — use and adapt freely; no warranty.
