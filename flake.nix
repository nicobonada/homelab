{
  description = "NixOS configuration for the homelab VM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Same DetSys pin as nix-config workstations (already on this seat's store).
    # Do not float `*` — FlakeHub can resolve to a newer minor (e.g. 3.22) and
    # every `nix develop` / direnv load fetches it even though the shell only
    # uses nixpkgs packages. Bump in lockstep with nix-config when ready.
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/=3.21.9";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      determinate,
      sops-nix,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
      # Upstream lazydocker tunnels ssh:// via streamlocal to /var/run/docker.sock,
      # which Tailscale SSH rejects. Use Docker CLI connhelper (dial-stdio) instead.
      # Patch against nixpkgs lazydocker; source also in ~/src/lazydocker feat/ssh-dial-stdio.
      lazydocker = pkgs.lazydocker.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [
          ./packages/patches/lazydocker-ssh-dial-stdio.patch
        ];
      });
    in
    {
      nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
        modules = [
          determinate.nixosModules.default
          sops-nix.nixosModules.sops
          ./configuration.nix
        ];
      };

      # Workstation shell: compose client + sops (host secrets) + Docker TUIs.
      # Grok is home-wide. Client tools only — no local Docker daemon; CLI targets
      # the lab over SSH. Compose deploy secrets come from 1Password Environment
      # Homelab (not this shell).
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          docker-client
          docker-compose # CLI plugin so `docker compose` works
          sops # NixOS host secrets only (e.g. vzdump-b2)
          lazydocker # day-to-day containers/logs/restart (ssh via dial-stdio)
          ctop # live container metrics
        ];
        # So `docker` / lazydocker / ctop hit the lab by default (override if needed).
        DOCKER_HOST = "ssh://nico@homelab";
      };
    };
}
