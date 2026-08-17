# Homelab monitoring (Glances + Gatus)

Used by Homepage widgets (`../homepage/config`).

## Services

| Service | Host port | Purpose |
|---------|-----------|---------|
| Glances | 61208 | Host CPU/RAM/disk for Homepage header |
| Gatus | **3001** | HTTP(S) checks + status UI (`3001:8080`) |

### Why host port 3001

Gatus listens on **8080** in the container; we publish **`3001:8080`**:

- Continuity with the previous **Uptime Kuma** publish — Tailscale Service / bookmarks / muscle memory keep the same host port
- Only the process behind the port changed

### Why bridge publish (not host network)

| Bridge + `3001:8080` | Host network |
|----------------------|--------------|
| Homepage (and other bridge containers) can reach Gatus via host `100.x:3001` or the Docker gateway — same as Kuma/Glances | Host-network Gatus was **unreachable** from Homepage → widget `ETIMEDOUT` on the lab tailnet IP |
| Checks use `host.docker.internal` → host-gateway for sibling ports | Loopback checks work, but the status API is hard for other containers to call |

## Check targets

| Target | URL style | Why |
|--------|-----------|-----|
| Homepage | `https://dashboard.lab.bonada.ca/api/healthcheck` | Same Host as the browser. Direct `host.docker.internal:3000` is **400** (Homepage `ALLOWED_HOSTS`). Hairpin to Caddy on `CADDY_BIND` works from this container; `client.insecure` for the Caddy local CA (Gatus has no extra-CA hook). |
| Sibling in this compose (Glances) | `http://glances:61208` | Same Docker network as Gatus — **do not** use `host.docker.internal` (hairpin to published 61208 times out from containers; browser/Tailscale still work) |
| Other apps on the lab host | `http://host.docker.internal:<port>` | Published ports on the host from the Gatus container |
| Remote peers (Proxmox) | MagicDNS node name | Not co-located |
| Human / Homepage **href** | Browser Service URLs | What you click from oakhill |
| Homepage **widget** API | `HOMEPAGE_VAR_GATUS_HTTP` → lab host `:3001` | Server-side fetch from Homepage container; must be a published host port (not loopback inside Homepage) |

**Conditions:** every endpoint requires `[CONNECTED] == true` as well as status checks. Otherwise a DNS/dial failure leaves `[STATUS]` empty and `[STATUS] < 400` would **false-green**.

## Config

| Path | Role |
|------|------|
| `config/config.yaml` | Endpoints, storage, UI (git) |
| 1P **Homelab** `GATUS_URL_*` | check URL env vars |
| `.env` | materialized on deploy (gitignored) |

```fish
# edit GATUS_URL_* in 1Password → Environments → Homelab
cd ~/src/homelab
./scripts/deploy-containers monitoring
```

`deploy-containers` rsyncs `config/` to `/home/nico/monitoring/config` on the lab (remote bind mount).

## Open follow-ups

- **[ ] Alerts:** wire Gatus `alerting:` after choosing where to notify (ntfy, email, Discord, …). Channel still undecided — no providers in config yet.
- Optional: `gatus-cli` on the workstation for post-deploy `endpoint status all` (reads last status; does not force an immediate re-check).

## Homepage

Widget type `gatus`; secret `HOMEPAGE_VAR_GATUS_HTTP` (e.g. `http://<lab-tailnet-ip>:3001`).  
`HOMEPAGE_VAR_STATUS_URL` can stay the human Service URL if you use one.
