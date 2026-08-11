# stacks

Docker Compose projects for the lab host. The NixOS system lives in the repo
root; this directory is **apps only** and is deployed separately.

## Layout

| Directory | Stack |
|-----------|--------|
| `openbao/` | OpenBao (app secrets target; see that README) |
| `grimmory/` | Library app + MariaDB |
| `papra/` | Documents |
| `homepage/` | Dashboard (+ `config/`) |
| `monitoring/` | Glances + Gatus |

Each stack has `compose.yaml`. App stack secrets are **sops-encrypted** in the
repo root `secrets/<stack>.env` (same age keys as NixOS secrets) and stay that
way until consumers migrate to OpenBao KV. OpenBao itself only keeps
**unseal + root** in `secrets/openbao.env`. Example templates remain as
`*.example` for documentation only.

## Apply from a workstation

Uses the Docker CLI against the lab daemon over SSH (`DOCKER_HOST`). You do
not need a compose checkout on the server. `deploy-containers` decrypts sops env files
into gitignored paths next to compose, then runs `docker compose up`.

```fish
# docker client + sops on PATH
nix shell nixpkgs#docker-client

cd ~/src/homelab
./scripts/deploy-containers openbao      # start + unseal if secrets/openbao.env exists
./scripts/deploy-containers monitoring   # sops -d secrets/monitoring.env
./scripts/deploy-containers homepage     # sops -d secrets/homepage.env
./scripts/deploy-containers grimmory
# ./scripts/deploy-containers --all
# First OpenBao init (once): ./scripts/openbao-bootstrap [--seed-from-sops]
```

Default remote: the repo devShell sets `DOCKER_HOST=ssh://nico@homelab` (override if needed).

Edit secrets: `sops secrets/homepage.env` (etc.). OpenBao bootstrap:
`sops secrets/openbao.env`.

NixOS system deploys stay separate (`nh os switch` / `nixos-rebuild` with
`--target-host`).
