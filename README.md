# homelab

NixOS configuration for the **homelab** VM (stable channel).

## Deploy

From a machine on the tailnet (e.g. seyruun), as root over Tailscale SSH:

```fish
cd ~/homelab
nixos-rebuild switch --flake .#homelab --target-host root@homelab
```

Build without activating (smoke test):

```fish
nixos-rebuild build --flake .#homelab --target-host root@homelab
```

On the host itself:

```fish
nh os switch .
# or: sudo nixos-rebuild switch --flake .#homelab
```
