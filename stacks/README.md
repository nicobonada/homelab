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

Each stack has `compose.yaml` and `*.example` env files. Real `.env` /
`secrets.env` are gitignored.

## Apply from a workstation

Uses the Docker CLI against the lab daemon over SSH (`DOCKER_HOST`). You do
not need a compose checkout on the server.

```fish
# docker client, e.g.:
nix shell nixpkgs#docker-client

cd ~/src/homelab
cp stacks/monitoring/.env.example stacks/monitoring/.env   # once, if needed
./scripts/stack-up monitoring
./scripts/stack-up homepage
# ./scripts/stack-up --all
```

Default remote: `DOCKER_HOST=ssh://nico@homelab` (override if needed).

NixOS system deploys stay separate (`nh os switch` / `nixos-rebuild` with
`--target-host`).

## Secrets

Copy each stack’s example env file and fill in values **on the workstation**
(or another private store). Do not commit them.
