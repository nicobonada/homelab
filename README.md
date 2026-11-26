# homelab

Personal [NixOS](https://nixos.org/) configuration for a small lab VM
(`nixosConfigurations.homelab`), plus optional Docker Compose **app** stacks
under [`stacks/`](stacks/).

Working personal config, not a template — steal ideas freely. Details live in
the Nix files and compose files; this README only covers what does not age well
next to the code.

Uses [Determinate Nix](https://determinate.systems/) and
[sops-nix](https://github.com/Mic92/sops-nix) for **host** secrets only.

**System** (NixOS) and **apps** (Compose) are deployed separately on purpose.

OpenTelemetry (Caddy traces + host metrics → Honeycomb): [`docs/opentelemetry.md`](docs/opentelemetry.md).

Music library: NFSv4 of `/mnt/pve-backup/music` (`music-share.nix`) plus guest
read-only Samba `\\homelab\music` (`samba.nix`). Seats mount NFS. Navidrome
([stacks/navidrome](stacks/navidrome)) serves it over Subsonic at
`https://music.lab.bonada.ca`.

## Workstation shell

Rare tools live in the flake devShell (not home-manager). From a checkout:

```text
nix develop
# or: direnv allow  (once; then cd into the repo)
```

Includes Docker **client** + Compose, **sops** (for NixOS host secrets),
and the Docker TUI **lazydocker**. The shell sets
`DOCKER_HOST=ssh://nico@homelab` so `docker` and `lazydocker`
talk to the lab. **Grok** is on the interactive PATH via home-manager
(not this shell).

`lazydocker` is patched to use Docker’s SSH dial-stdio path (like the Docker
CLI) instead of streamlocal-forwarding `/var/run/docker.sock`, so it works over
Tailscale SSH.

## Secrets

| Kind | Where | Used by |
|------|--------|---------|
| **Compose / deploy** | 1Password Environment **`Homelab`** (local `.env` mount) | `scripts/deploy-containers` → stack `env_file`s |
| **NixOS host** | sops + age under `secrets/` (e.g. `vzdump-b2.yaml`) | sops-nix at activation |

### Homelab Environment (deploy)

Create Environment **Homelab** in 1Password, add the keys listed in each stack’s
`*.env.example` / `secrets.env.example`, and mount a local `.env` at:

```text
~/.config/grok/environments/Homelab.env
```

Unlock the 1Password desktop app before deploy. The mount is a FIFO (same
pattern as Grok Environments). `deploy-containers` reads it once and writes a
**filtered** gitignored env file next to compose (only that stack’s keys).

Homepage hrefs are `*.lab.bonada.ca`. Widget/probe URLs that are public-safe
(`host.docker.internal`, loopback, compose DNS) live in `config/*.yaml`.
Homelab env keeps API tokens only.

### Homepage widget secrets

Wired widgets: Proxmox, Caddy, Technitium, Tailscale. Tokens live in
1Password Environment **Homelab**; Tailscale access tokens max **90 days** —
rotate `HOMEPAGE_VAR_TAILSCALE_KEY` and redeploy homepage.

### Host sops

```text
sops secrets/vzdump-b2.yaml
sops secrets/atticd.yaml
sops secrets/app-backup.yaml
```

Age recipients: `.sops.yaml` (workstation user + lab host).

## App data backup

Restic of Grimmory (SQL dump + books/data), Papra, Aven, Navidrome state,
and the Caddy local CA to Backblaze B2. Module [`app-backup.nix`](app-backup.nix), timer
02:30. Secrets in `secrets/app-backup.yaml`. After filling B2 keys, run
`app-backup-init` once on the lab, then the timer. Attic NARs and Gatus
history are not in this repo.

## Nix binary cache (Attic)

`atticd` on this VM, HTTPS via Caddy at `https://cache.lab.bonada.ca/`.
Seats pull NARs that miss `cache.nixos.org` (Luciole, crawl-tiles, …).
Storage is `/var/lib/atticd` on the guest root (90-day default retention).
Do not put it on the T7 music/backup share.

After OS switch:

1. Technitium: A record `cache.lab.bonada.ca` → this host (same as the
   other `*.lab.bonada.ca` names). Zone state stays on the VM.
2. Deploy Caddy, Homepage, and monitoring so the name, dashboard card,
   and Gatus probe exist.
3. On the VM, mint a push token and create cache `lab`:

   ```text
   sudo atticd-atticadm make-token --sub nico --validity '10 years' \
     --pull lab --push lab --create-cache lab --configure-cache lab
   ```

   From a seat (token is a JWT; keep it in 1Password, not git):

   ```text
   attic login lab https://cache.lab.bonada.ca <token>
   attic cache create lab
   attic cache configure lab --public
   attic cache info lab
   ```

4. Add the printed public key plus substituter
   `https://cache.lab.bonada.ca/lab` on the seats (nix-config). Then
   `attic push lab <store-path>` after a luciole or crawl build.
   New crawl trunk revs still compile once; ccache covers the C++
   increment. The cache only reuses a finished store path.

## CI

GitHub Actions runs [`scripts/preflight --eval`](scripts/preflight) on pull
requests only (eval the lab toplevel, parse compose/homepage YAML, and
validate the Caddyfile). Fast-forwarding the same SHA onto `main` does
not re-run it. That is not a build, a remote switch, or a Compose deploy.
The runner installs Determinate Nix but does not log in to FlakeHub Cache.
Local `./scripts/preflight` still builds the lab image before activate.

`update-flake-lock` opens a pull request every day at midnight Argentina
time (`America/Argentina/Buenos_Aires`) that runs
`nix flake update` for every input. When `preflight` is green, CI
fast-forwards `main` to that commit. That is not a remote switch or a
Compose deploy.

## License

[MIT](./LICENSE) — use and adapt freely; no warranty.
