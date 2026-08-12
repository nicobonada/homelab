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

## Workstation shell

Rare tools live in the flake devShell (not home-manager). From a checkout:

```text
nix develop
# or: direnv allow  (once; then cd into the repo)
```

Includes Docker **client** + Compose and **sops** (for NixOS host secrets).
The shell sets `DOCKER_HOST=ssh://nico@homelab` so plain `docker` /
`docker compose` talk to the lab. **Grok** is on the interactive PATH via
home-manager (not this shell).

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

Homepage `stacks/homepage/config/*.yaml` keeps `{{HOMEPAGE_VAR_*}}` placeholders
only — no private hosts in public git.

### Open follow-ups

- **[ ] Homepage optional widget keys** in Homelab Environment (then uncomment
  matching blocks in `stacks/homepage/config/services.yaml`):
  - [x] `HOMEPAGE_VAR_PVE_TOKEN` / `HOMEPAGE_VAR_PVE_SECRET` (Proxmox API token
    `homepage@pam!homelab-dashboard`, PVEAuditor)
  - [ ] `HOMEPAGE_VAR_TECHNITIUM_KEY` (Technitium API key)
  - [ ] `HOMEPAGE_VAR_TAILSCALE_KEY` / `HOMEPAGE_VAR_TAILSCALE_DEVICE_ID` (Tailscale API)

### Host sops

```text
sops secrets/vzdump-b2.yaml
```

Age recipients: `.sops.yaml` (workstation user + lab host).

## License

[MIT](./LICENSE) — use and adapt freely; no warranty.
