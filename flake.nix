{
  description = "NixOS configuration for the homelab VM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Determinate Nix (same FlakeHub float as nix-config).
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
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
          # nixos-26.05 (cd4ea8d) fetches TechnitiumLibrary tag
          # dns-server-15.6.2, which 404s. The tag is dns-server-v15.6.2.
          # release-26.05 960d8f5663 fixes the string; the channel has not
          # moved. Drop this overlay once nixos-26.05 contains that commit.
          {
            nixpkgs.overlays = [
              (final: prev: {
                technitium-dns-server-library = prev.technitium-dns-server-library.overrideAttrs (old: {
                  src = prev.fetchFromGitHub {
                    owner = "TechnitiumSoftware";
                    repo = "TechnitiumLibrary";
                    tag = "dns-server-v${old.version}";
                    hash = "sha256-fb5o4AlKFU/oPypD7T3sNoUdY7nHS4skGovDSLNzpI0=";
                  };
                });
              })
            ];
          }
        ];
      };

      # Workstation shell: compose client + sops (host secrets) + lazydocker.
      # Grok is home-wide. Client tools only — no local Docker daemon; CLI targets
      # the lab over SSH. Compose deploy secrets come from 1Password Environment
      # Homelab (not this shell).
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          docker-client
          docker-compose # CLI plugin so `docker compose` works
          sops # NixOS host secrets only (e.g. vzdump-b2)
          lazydocker # day-to-day containers/logs/restart (ssh via dial-stdio)
        ];
        # So `docker` / lazydocker hit the lab by default (override if needed).
        DOCKER_HOST = "ssh://nico@homelab";
      };
    };
}
