{
  inputs = {
    # Use the unstable channel of nixpkgs as the main package source.
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    # Import the Ryoku-on-NixOS flake.
    ryoku.url = "github:aethctl/Ryoku-on-NixOS/main";
  };

  # Define the NixOS system configuration and expose all flake inputs.
  outputs = { nixpkgs, ryoku, ... }@inputs: {
    nixosConfigurations.nixos = nixpkgs.lib.nixosSystem {
      # Target system architecture.
      system = "x86_64-linux";

      # Pass the flake inputs to the NixOS modules.
      specialArgs = {
        inherit inputs;
      };

      # NixOS modules loaded by this configuration.
      modules = [
        # Enable the Ryoku-on-NixOS module.
        ryoku.nixosModules.default

        # Ryoku-specific system configuration.
        ./ryoku.nix

        # Main NixOS system configuration.
        ./configuration.nix
      ];
    };
  };
}
