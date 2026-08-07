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
    {
      nixosConfigurations.homelab = nixpkgs.lib.nixosSystem {
        modules = [
          determinate.nixosModules.default
          sops-nix.nixosModules.sops
          ./configuration.nix
        ];
      };

      # Workstation shell: enter from this repo (`nix develop` / direnv), not global HM.
      # Expand packages here later (e.g. docker client, sops) for lab ops tools.
      devShells.x86_64-linux.default = grok-config.devShells.x86_64-linux.default;
    };
}
