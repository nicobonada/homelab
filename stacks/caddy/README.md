# Caddy (lab front door)

HTTPS reverse proxy for Compose UIs (Caddy local CA). OpenTelemetry traces
go to Honeycomb. **Not** on the public internet. Tailscale Serve stays as-is.

| Listen | Purpose |
|--------|---------|
| `${CADDY_BIND}:80` | HTTP → HTTPS redirect |
| `${CADDY_BIND}:443` | TLS (`local_certs`) |
| `:2019` in-container | Admin API (Homepage widget). Shared `monitoring_default` only; not published. |

## Hosts

| Host | Upstream |
|------|----------|
| `https://dashboard.lab.bonada.ca` | Homepage `:3000` |
| `https://status.lab.bonada.ca` | Gatus `:3001` |
| `https://docs.lab.bonada.ca` | Papra `:1221` |
| `https://books.lab.bonada.ca` | Grimmory (`BOOKLORE_PORT`, default 6060) |
| `https://dns.lab.bonada.ca` | Technitium `:5380` |
| `https://sync.lab.bonada.ca` | Syncthing GUI `:8384` |
| `https://pve.lab.bonada.ca` | Proxmox (`PVE_UPSTREAM`, usually `:8006`) |

Glances and Technitium are not behind this proxy. Proxmox is: the
hypervisor is a different machine, so Homepage `siteMonitor` and Gatus
hairpin here. PVE returns 501 for HEAD; Caddy sends GET upstream for those.

Other Homepage widgets and Gatus probes keep using `host.docker.internal` —
do not route those scrapes through Caddy. The Caddy card itself talks to
`http://caddy:2019` on `monitoring_default` (admin API; no auth — keep it
off the host publish list).

## Trust the local CA

Seats trust Caddy’s CA from nix-config (`nixos/common/lab-ca.nix`): system
bundle plus a Brave managed policy. Switch OS on the seat; fully quit Brave
so the policy loads.

If the lab PKI is recreated, replace `nixos/common/caddy-lab-root.crt` from:

```fish
ssh homelab -- docker exec caddy cat /data/caddy/pki/authorities/local/root.crt
```

## Secrets

Add to 1Password Environment **Homelab** (see `.env.example`):

- `HONEYCOMB_API_KEY` — ingest key
- `CADDY_BIND` — lab tailnet IPv4
- `BOOKLORE_PORT` — optional if not 6060

```fish
cd ~/src/homelab
./scripts/deploy-containers caddy
```

`deploy-containers` rsyncs `Caddyfile` to `/home/nico/caddy/` on the lab (bind mounts resolve on the remote daemon). PKI lives in `/home/nico/caddy/data`.

## Later

Move this Caddyfile to NixOS + public ACME when the domain is on the internet.
