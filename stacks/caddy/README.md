# Caddy (lab front door)

HTTPS reverse proxy for Compose UIs (Caddy local CA). OpenTelemetry traces
go to Honeycomb. **Not** on the public internet. Tailscale Serve stays as-is.

| Listen | Purpose |
|--------|---------|
| `${CADDY_BIND}:80` | HTTP → HTTPS redirect |
| `${CADDY_BIND}:443` | TLS (`local_certs`) |

## Hosts

| Host | Upstream |
|------|----------|
| `https://dashboard.lab.bonada.ca` | Homepage `:3000` |
| `https://status.lab.bonada.ca` | Gatus `:3001` |
| `https://netbox.lab.bonada.ca` | Netbox `:8000` |
| `https://docs.lab.bonada.ca` | Papra `:1221` |
| `https://books.lab.bonada.ca` | Grimmory (`BOOKLORE_PORT`, default 6060) |
| `https://dns.lab.bonada.ca` | Technitium `:5380` |

Glances, Technitium, and Proxmox are not behind this proxy.

Homepage widgets and Gatus probes keep using `host.docker.internal` — do not
route scrapes through Caddy.

## Trust the local CA

Browsers warn until each seat trusts Caddy’s CA (`/home/nico/caddy/data/caddy/pki/authorities/local/root.crt` on the lab). Copy it off the container or that path, then import (Chrome/Chromium NSS):

```fish
certutil -d sql:$HOME/.pki/nssdb -A -t "C,," -n "Caddy lab" -i root.crt
```

Or add the file under nix-config `security.pki.certificateFiles` and switch.

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
