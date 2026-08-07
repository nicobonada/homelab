# Homelab monitoring (Glances + Uptime Kuma)

Used by Homepage widgets (`../homepage/config`).

## Services

| Service | Port | Purpose |
|---------|------|---------|
| Glances | 61208 | Host CPU/RAM/disk for Homepage header |
| Uptime Kuma | 3001 | HTTP checks + status page slug `lab` |

## Admin

Uptime Kuma credentials: `kuma-admin.env` (mode 600).

```fish
cd ~/monitoring
docker compose up -d
```

## Homepage secrets (optional rich widgets)

Fill `/home/nico/homepage/secrets.env` from `secrets.env.example`, then:

```fish
cd ~/homepage && docker compose up -d --force-recreate
```

Uncomment the matching widget blocks in `config/services.yaml`.
