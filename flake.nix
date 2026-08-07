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
    in
    {
      nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
        modules = [
          determinate.nixosModules.default
          sops-nix.nixosModules.sops
          ./configuration.nix
        ];
      };

      # Workstation shell: compose client + sops + bao (not home-manager). Grok is home-wide.
      # Client tools only — compose targets the lab daemon (DOCKER_HOST=ssh://…).
      devShells.${system}.default = pkgs.mkShellNoCC {
        packages = with pkgs; [
          docker-client
          docker-compose # CLI plugin so `docker compose` works
          sops
          openbao # `bao` CLI for operator/KV work from the workstation
        ];
      };
    };
}
