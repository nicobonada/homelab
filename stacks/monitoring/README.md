# Homelab monitoring (Glances + Gatus + Honeycomb hostmetrics)

Used by Homepage widgets (`../homepage/config`). Host metrics also go to
Honeycomb for the Linux Host board (history / query; not a Glances replacement).

## Services

| Service | Host port | Purpose |
|---------|-----------|---------|
| Glances | 61208 | Host CPU/RAM/disk for Homepage header |
| Gatus | **3001** | HTTP(S) checks + status UI (`3001:8080`) |
| otelcol | (none) | `hostmetrics` every 60s → Honeycomb dataset `metrics` |

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
| Sibling in this compose (otelcol) | `http://otelcol:13133` | Collector `health_check` extension. No host publish. |
| Other apps on the lab host | `http://host.docker.internal:<port>` | Published ports on the host from the Gatus container |
| Remote peers (Proxmox) | `https://pve.lab.bonada.ca` | A record → Caddy; Caddy proxies to `PVE_UPSTREAM` (`:8006`). `client.insecure` for the Caddy local CA. |
| Human / Homepage **href** | Browser Service URLs | What you click from oakhill |
| Homepage **widget** API | `http://host.docker.internal:3001` | Server-side fetch from Homepage container; published host port |

**Conditions:** every endpoint requires `[CONNECTED] == true` as well as status checks. Otherwise a DNS/dial failure leaves `[STATUS]` empty and `[STATUS] < 400` would **false-green**.

## Config

| Path | Role |
|------|------|
| `config/config.yaml` | Gatus endpoints, storage, UI (git) |
| `config/otelcol.yaml` | Collector: Linux Host scrapers, 60s, filters |
| 1P **Homelab** `GATUS_URL_*` | check URL env vars |
| 1P **Homelab** `HONEYCOMB_API_KEY` | same ingest key as Caddy |
| `.env` | materialized on deploy (gitignored) |

```fish
# edit GATUS_URL_* / HONEYCOMB_API_KEY in 1Password → Environments → Homelab
cd ~/src/homelab
./scripts/deploy-containers monitoring
```

`deploy-containers` rsyncs `config/` to `/home/nico/monitoring/config` on the lab (remote bind mount).

After data appears in Honeycomb (environment **test**, dataset **metrics**): Boards → Templates → **Linux Host**. The template wants compacted names (`system.filesystem.usage.used`); the collector flattens `state`/`direction` for those panels.

otelcol is `privileged` + `pid: host` so the `process` scraper can read host `/proc` (template panels). Loop/tmpfs/overlay/`veth*` series are dropped in `otelcol.yaml`.

## Open follow-ups

- **[ ] Alerts:** wire Gatus `alerting:` after choosing where to notify (ntfy, email, Discord, …). Channel still undecided — no providers in config yet.
- Optional: `gatus-cli` on the workstation for post-deploy `endpoint status all` (reads last status; does not force an immediate re-check).

## Homepage

Widget type `gatus`; probe URL is `http://host.docker.internal:3001` in Homepage
`services.yaml`. Human href is `https://status.lab.bonada.ca`.
