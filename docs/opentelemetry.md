# OpenTelemetry in this lab

Two independent OTLP paths to Honeycomb. Neither goes through the other.
Apps besides Caddy are not instrumented.

| Signal   | Source                         | How it is sent                         | Honeycomb dataset |
|----------|--------------------------------|----------------------------------------|-------------------|
| Traces   | Caddy (`tracing { span caddy }`) | Official Caddy image → OTLP/gRPC       | `caddy` (from `OTEL_SERVICE_NAME`) |
| Metrics  | Host (CPU, mem, disk, net, processes) | `otelcol` `host_metrics` receiver, 60s | `metrics` (Honeycomb Environments native metrics dataset) |

Environment: **test** (team `nico-testing`). One ingest key in 1Password Environment **Homelab** (`HONEYCOMB_API_KEY`), materialized into both stack `.env` files by `scripts/deploy-containers`.

Live glance (Homepage Glances) and up/down (Gatus) are **not** OpenTelemetry. They stay local.

```text
browser / Gatus ──► Caddy ──OTLP/gRPC──► Honeycomb  (traces, dataset caddy)

host /proc /sys
      ▲
otelcol (privileged, pid:host, /hostfs)
      └──OTLP/HTTP──► Honeycomb  (metrics dataset; Linux Host board)
```

## Traces: Caddy

Caddy is the only traced service. Every `*.lab.bonada.ca` site in the Caddyfile shares one `tracing` block.

| Piece | Where |
|-------|--------|
| Span name `caddy` | `stacks/caddy/Caddyfile` |
| `OTEL_SERVICE_NAME=caddy` | `stacks/caddy/compose.yaml` |
| Endpoint `https://api.honeycomb.io:443` (gRPC) | same compose; official image does not use HTTP/protobuf |
| Header `x-honeycomb-team` | Homelab env → `stacks/caddy/.env` |

No Collector in this path. No dataset header: Honeycomb Environments uses `service.name`.

Apply: `./scripts/deploy-containers caddy`.

## Metrics: Linux host

Collector in the monitoring stack scrapes the **VM**, not the sidecar. That is why it is `privileged`, `pid: host`, `user: 0:0`, and mounts `/` at `/hostfs`.

| Piece | Where |
|-------|--------|
| Image `otel/opentelemetry-collector-contrib:0.159.0` | `stacks/monitoring/compose.yaml` (`otelcol`) |
| Pipeline | `stacks/monitoring/config/otelcol.yaml` |
| Health | `http://otelcol:13133` (Gatus, compose DNS, no host port) |

Scrapers match Honeycomb’s **Linux Host** board template: cpu, disk, load, filesystem, memory, network, paging, `processes` (counts), `process` (per-PID). `process` skips PIDs younger than 10s and mutes `/proc` permission errors.

Processors:

- Drop loop/ram/zram, `veth*`/`br-*`/`docker*`, `lo`, and pseudo filesystems (tmpfs, overlay, cgroup, …). NixOS + Docker otherwise explode series count.
- Truncate metric timestamps to 1s so points from one scrape pack together.
- Set `service.name=linux-host` and `host.name=homelab` (container UTS hostname is a container id).
- Flatten enums the Linux Host template expects as metric names (`system.cpu.time.user`, `system.filesystem.usage.used`, `system.disk.io.write`, `system.network.io.receive`, …). Native OTLP keeps `state`/`direction` on the datapoint; memory stays `system.memory.usage` + `state` because that panel already matches.
- Process panels need `process.owner`. The collector mounts host `/etc/passwd` and `/etc/group`, and sets `unknown` when a UID has no name (nss-systemd DynamicUser accounts are not in passwd; Technitium uses a named system user so `DnsServerApp` resolves).

Exporter: OTLP/HTTP to `api.honeycomb.io`. Environments ignore `x-honeycomb-dataset` for metrics and store them in dataset **`metrics`**.

Apply: `./scripts/deploy-containers monitoring` (rsyncs `config/` including `otelcol.yaml`). Config changes need a recreate (`--force-recreate otelcol`); the process does not watch the file.

After a few minutes of data: Honeycomb → env **test** → board **Homelab host** (dataset **`metrics`**). The stock Linux Host template queries 500 on this team; do not use them.

## Free-plan usage

Traces count as **events** (Caddy volume is tiny). Host scrapes count as **metrics data points** (or event-based metrics if Honeycomb stores them that way). 60s + filters is meant to sit under the free cap on this one VM. Check **Team Settings → Usage** after a couple of days; do not add a second full `process` scrape (e.g. Proxmox) without looking at that first.

## Not in scope

- No OTLP receiver on `otelcol` (Caddy does not send to it).
- No traces from Homepage, Gatus, Papra, Grimmory, Technitium, Syncthing, PVE.
- No logs pipeline.
- Collector is not on the NixOS system image; it is a Compose app.

## Debug

```fish
nix develop
docker logs otelcol --tail 80
docker logs caddy --tail 80
```

Successful exports are quiet at info level. Failures (bad key, rejected payload) show as exporter errors. Gatus endpoint **otelcol** going down means the collector process is not serving `/` on 13133.
