# To get help with NixOS: https://search.nixos.org/options (`nixos-help`).
# To get help with Ryoku-on-NixOS: https://discord.gg/DdrpX5ksPK

{ config, pkgs, inputs, ... }:

{
  # You can include new modules here.
  #
  # e.g:
  #
  # imports =
  #   [
  #     ./file.nix
  #     ./modules/file.nix
  #     ./folder/file.nix
  #     ./modules/module-example.nix
  #   ];
  #
  # There is a file named "module-example.nix" inside the modules folder.
  # You can dupe it and use as a base to create your own modules and add his import here.

  imports =
    [
      # This file is generated automatically based on your hardware.
      ./hardware-configuration.nix

      # Add packages in pkgs.nix.
      ./pkgs.nix
      # Configures nvidia gpu.
      ./nvidia.nix
    ];

  # Use the systemd-boot EFI boot loader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Define system hostname.
  networking.hostName = "nixos";

  # Enable networking.
  networking.networkmanager.enable = true;

  # Enable wireless and bluetooth.
  networking.wireless.enable = true;
  hardware.bluetooth.enable = true;
  services.blueman.enable = true;

  # Set your timezone.
  time.timeZone = "America/New_York";

  # Select internationalisation (locale) properties.
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Configure keymap in X11.
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  # Add flakes to NixOS.
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Defines a user. Set a password with ‘passwd’.
  users.users."ryoku" = {
    isNormalUser = true;
    description = "ryoku";
    extraGroups = [ "networkmanager" "wheel" ];
  };

  # Allow unfree packages.
  nixpkgs.config.allowUnfree = true;

  # Basic garbage collection.
  # Deletes 14 days worth of garbage weekly.
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # Optimize/Deduplicate nix store weekly.
  nix.optimise = {
    automatic = true;
    dates = [ "weekly" ];
  };

  # Automatically optimize nix store.
  nix.settings.auto-optimise-store = true;

  # Basic aliases for fish shell specifically made for NixOS.
  programs.fish.shellFunctions = {
    # Rebuilds generation with flake.
    rebuild = {
      body = ''
        sudo nixos-rebuild switch --flake /etc/nixos#nixos
        echo "Rebuild Complete!"
      '';
    };

    # Updates Ryoku, channels, flakes and rebuilds.
    update = {
      body = ''
        ryoku status
        ryoku update
        sudo nix-channel --update
        sudo nix flake update --flake /etc/nixos
        sudo nixos-rebuild switch --flake /etc/nixos#nixos
        echo "Update Complete!"
      '';
    };

    # Simple garbage collection.
    clean = {
      body = ''
        sudo nix-collect-garbage -d
        echo "Nix garbage collection complete!"
      '';
    };

    # cd's into /etc/nixos folder.
    nixos = {
      body = ''
        cd /etc/nixos
      '';
    };

    # Enters configuration.nix with neovim.
    configuration = {
      body = ''
        sudo -E nvim /etc/nixos/configuration.nix
      '';
    };

    # Enters flake.nix with neovim.
    flake = {
      body = ''
        sudo -E nvim /etc/nixos/flake.nix
      '';
    };

    # Enters pkgs.nix with neovim.
    pkgs = {
      body = ''
        sudo -E nvim /etc/nixos/pkgs.nix
      '';
    };
  };

  system.stateVersion = "26.05";
}
