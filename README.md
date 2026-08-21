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

Wired widgets: Proxmox, Technitium, Tailscale, Syncthing. Tokens live in
1Password Environment **Homelab**; Tailscale access tokens max **90 days** —
rotate `HOMEPAGE_VAR_TAILSCALE_KEY` and redeploy homepage.

### Host sops

```text
sops secrets/vzdump-b2.yaml
```

Age recipients: `.sops.yaml` (workstation user + lab host).

## CI

GitHub Actions runs [`scripts/preflight --eval`](scripts/preflight) on pull
requests and on `main` (eval the lab toplevel only). That is not a build, a
remote switch, or a Compose deploy. Local `./scripts/preflight` still builds
the lab image before activate.

Dependabot opens a weekly grouped PR for `flake.lock` inputs. Merge still
waits on the preflight check; that is not a remote switch.

## License

[MIT](./LICENSE) — use and adapt freely; no warranty.
