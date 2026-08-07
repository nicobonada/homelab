# OpenBao

Secrets engine for lab **app** stacks. NixOS host secrets stay on **sops-nix**;
Compose app env stays on **sops + `deploy-containers`** until you migrate consumers to Bao.

## Role of sops vs OpenBao

| Secret class | Where it lives |
|--------------|----------------|
| Unseal key + initial root token | sops `secrets/openbao.env` only |
| Homepage / Grimmory / Papra app secrets | **Target:** OpenBao KV (see below) |
| Same app secrets **today** | Still `secrets/{homepage,grimmory,papra}.env` via `deploy-containers` |
| NixOS (e.g. vzdump B2) | sops-nix forever |

Dual-write is fine: seed KV from existing sops env, keep deploying env files until
each stack is switched.

## KV layout (kv-v2 mount `secret/`)

Logical paths (CLI):

| Path | Source stack / use |
|------|--------------------|
| `secret/stacks/homepage` | `HOMEPAGE_*` and widget keys (same names as env) |
| `secret/stacks/grimmory` | Grimmory + MariaDB fields from `grimmory.env` |
| `secret/stacks/papra` | Papra `AUTH_SECRET`, base URLs, etc. |

API data path is `secret/data/stacks/<name>` (kv-v2). Field names match the
existing dotenv keys so migration is a mechanical switch later.

## Deploy

```fish
cd ~/src/homelab
nix develop   # docker client, sops, bao CLI

./scripts/deploy-containers openbao
# First time only:
./scripts/openbao-bootstrap
# Optional: copy current sops app env into KV (deploy-containers still uses sops):
./scripts/openbao-bootstrap --seed-from-sops

# Later restarts: deploy-containers unseals when secrets/openbao.env exists
./scripts/deploy-containers openbao
# or: ./scripts/openbao-unseal
```

Edit bootstrap secrets: `sops secrets/openbao.env`.

Host paths (Docker daemon host):

- config: `/home/nico/openbao/config` (rsync’d from this tree)
- data: `/home/nico/openbao/data` (file storage; container runs as 1000:100 like host `nico`; back up with the VM)

Run **`./scripts/deploy-containers openbao` from a workstation** (not on the lab
VM). Compose talks to the lab Docker daemon over `DOCKER_HOST=ssh://…`.

Listener is plaintext on `:8200` inside the lab (Tailscale / localhost). Do not
publish it to the open internet.

## After migration (later)

1. Consumers read from Bao (agent, template, or `deploy-containers` export from KV).
2. Stop writing app secrets into `secrets/*.env` (leave openbao bootstrap in sops).
3. Optional: revoke the long-lived root token; use AppRole / userpass + policies.
