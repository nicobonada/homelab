{
  description = "NixOS configuration for the homelab VM";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
  };

  outputs = { self, nixpkgs, ... }: {
    nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
      modules = [ ./configuration.nix ];
    };
  };
}
