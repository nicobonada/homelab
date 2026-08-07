# homelab

Personal [NixOS](https://nixos.org/) configuration for a small lab VM
(`nixosConfigurations.homelab`).

Working personal config, not a template — steal ideas freely. Details live in
the Nix files; this README only covers what does not age well next to the code.

Uses [Determinate Nix](https://determinate.systems/) and [sops-nix](https://github.com/Mic92/sops-nix).
Docker app stacks are **not** in this repo (see sibling projects / your own compose layout).

## Secrets

Secrets live **in this repo**, encrypted with sops + age (`secrets/`, `.sops.yaml`).

- Edit from a machine that has the personal age key: `sops secrets/<file>.yaml`.
- The host decrypts at activation with its own age recipient (see `.sops.yaml`).
- Do not commit plaintext credentials.

## License

[MIT](./LICENSE) — use and adapt freely; no warranty.
