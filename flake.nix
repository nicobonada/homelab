{
  description = "NixOS configuration for the homelab VM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    # Same Determinate Nix stack as workstations (lazy trees / faster eval).
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/*";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Portable Grok wrapper + agent-apps (not on interactive PATH).
    grok-config.url = "git+ssh://git@github.com/nicobonada/grok-config.git";
  };

  outputs =
    {
      self,
      nixpkgs,
      determinate,
      sops-nix,
      grok-config,
      ...
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    {
      nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
        modules = [
          determinate.nixosModules.default
          sops-nix.nixosModules.sops
          ./configuration.nix
        ];
      };

      # Workstation shell: enter from this repo (`nix develop` / direnv), not global HM.
      # Client tools only — compose targets the lab daemon (DOCKER_HOST=ssh://…).
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = [
          grok-config.packages.${system}.grok
        ]
        ++ (with pkgs; [
          docker-client
          docker-compose # CLI plugin so `docker compose` works
          sops
        ]);
        shellHook = ''
          # Prefer the writable checkout so rules/skills edits land in git.
          if [ -x "$HOME/src/grok-config/scripts/ensure-grok-home" ]; then
            "$HOME/src/grok-config/scripts/ensure-grok-home" || true
          fi
        '';
      };
    };
}
