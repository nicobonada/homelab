# stacks

Docker Compose projects for the lab host. The NixOS system lives in the repo
root; this directory is **apps only** and is deployed separately.

## Layout

| Directory | Stack |
|-----------|--------|
| `grimmory/` | Library app + MariaDB |
| `papra/` | Documents |
| `homepage/` | Dashboard (+ `config/`) |
| `monitoring/` | Glances + Uptime Kuma |

Each stack has `compose.yaml`. Secrets are **sops-encrypted** in the repo root
`secrets/<stack>.env` (same age keys as NixOS secrets). Example templates remain
as `*.example` for documentation only.

## Apply from a workstation

Uses the Docker CLI against the lab daemon over SSH (`DOCKER_HOST`). You do
not need a compose checkout on the server. `deploy-containers` decrypts sops env files
into gitignored paths next to compose, then runs `docker compose up`.

```fish
# docker client + sops on PATH
nix shell nixpkgs#docker-client

cd ~/src/homelab
./scripts/deploy-containers monitoring   # no secrets
./scripts/deploy-containers homepage     # sops -d secrets/homepage.env
./scripts/deploy-containers grimmory
# ./scripts/deploy-containers --all
```

Default remote: `DOCKER_HOST=ssh://nico@homelab` (override if needed).

Edit secrets: `sops secrets/homepage.env` (etc.).

NixOS system deploys stay separate (`nh os switch` / `nixos-rebuild` with
`--target-host`).
