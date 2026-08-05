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
    {
      nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
        modules = [
          determinate.nixosModules.default
          sops-nix.nixosModules.sops
          ./configuration.nix
        ];
      };
    };
}
