{ self, pkgs, lib, modulesPath, ... }:

{
  imports = [
    "${modulesPath}/installer/cd-dvd/installation-cd-base.nix"
  ];

  # ──────────────────────────────────────────────────────────────────────────
  # Ryoku ISO identity
  # ──────────────────────────────────────────────────────────────────────────
  networking.hostName = "ryoku-live";

  image.baseName = lib.mkForce
    "ryoku-nixos-${self.lib.version}-${pkgs.stdenv.hostPlatform.system}";

  isoImage = {
    volumeID = lib.mkForce "RYOKU_NIXOS";
    makeEfiBootable = true;
    makeUsbBootable = true;
  };

  # ──────────────────────────────────────────────────────────────────────────
  # Modern Nix baseline
  # ──────────────────────────────────────────────────────────────────────────
  # The live image is intentionally flake-native. Keep the Nix implementation
  # current even when the installer profile itself stays pinned and reproducible.
  nix.package = pkgs.nixVersions.latest;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # The source tree embedded in the image is the exact revision used to build
  # it. Installer/profile code can therefore install that revision rather than
  # silently chasing a moving Git branch.
  environment.etc."ryoku/source".source = self;
  environment.sessionVariables.RYOKU_INSTALL_SOURCE = "path:/etc/ryoku/source";
  nix.registry.ryoku.flake = self;

  # ──────────────────────────────────────────────────────────────────────────
  # Live installation toolbox
  # ──────────────────────────────────────────────────────────────────────────
  networking.networkmanager.enable = true;

  environment.systemPackages = with pkgs; [
    bash
    coreutils
    curl
    git
    gnugrep
    jq
    nix
    nixos-install-tools
    parted
    rsync
    util-linux
  ];

  # Useful both for hand-testing the ISO and for whatever installer frontend
  # the profile grows later. installation-cd-base already supplies the live
  # nixos user and installer-oriented sudo policy.
  services.openssh.enable = true;

  system.stateVersion = "26.11";
}
