# stacks

Docker Compose projects for the lab host. The NixOS system lives in the repo
root; this directory is **apps only** and is deployed separately.

## Layout

| Directory | Stack |
|-----------|--------|
| `grimmory/` | Library app + MariaDB |
| `papra/` | Documents |
| `homepage/` | Dashboard (+ `config/`) |
| `monitoring/` | Glances + Gatus |
| `caddy/` | HTTP front door + Honeycomb traces (tailnet only) |

Each stack has `compose.yaml`. Deploy secrets live in the 1Password Environment
**Homelab** (not in this public tree). Example key lists remain as `*.env.example`
/ `secrets.env.example` for documentation only.

## Apply from a workstation

Uses the Docker CLI against the lab daemon over SSH (`DOCKER_HOST`). You do
not need a compose checkout on the server. `deploy-containers` reads the
Homelab Environment mount, writes a filtered gitignored env file next to
compose, then runs `docker compose up`.

```fish
# docker client on PATH; 1Password unlocked (Homelab mount)
nix develop   # or: nix shell nixpkgs#docker-client

cd ~/src/homelab
./scripts/deploy-containers monitoring
./scripts/deploy-containers homepage
./scripts/deploy-containers grimmory
# ./scripts/deploy-containers --all
```

Default remote: the repo devShell sets `DOCKER_HOST=ssh://nico@homelab` (override if needed).

Mount path (override with `HOMELAB_ENV_MOUNT`):

```text
~/.config/grok/environments/Homelab.env
```

NixOS system deploys stay separate (`nixos-rebuild` with `--target-host`).
