{ pkgs, module }:
let
  # A minimally bootable synthetic NixOS host. Returning its full toplevel
  # below forces NixOS' real module assertions, including SDDM's backend
  # requirement, instead of merely inspecting option values.
  hostBaseline = {
    system.stateVersion = "26.05";

    fileSystems."/" = {
      device = "none";
      fsType = "tmpfs";
    };

    boot.loader.grub = {
      enable = true;
      devices = [ "/dev/vda" ];
    };
  };

  evaluate = extra: (import (pkgs.path + "/nixos/lib/eval-config.nix") {
    system = pkgs.stdenv.hostPlatform.system;

    modules = [
      module
      hostBaseline
      { programs.ryoku.enable = true; }
      extra
    ];
  }).config;

  bare = evaluate { };

  disabled = evaluate {
    services.displayManager.sddm.enable = false;
  };

  custom = evaluate {
    services.displayManager.sddm.theme = "custom";
  };

  gdm = evaluate {
    services.displayManager.gdm.enable = true;
  };

  lightdm = evaluate {
    services.xserver.displayManager.lightdm.enable = true;
  };

  greetd = evaluate {
    services.greetd.enable = true;
  };
in

# No Desktop installs have no Xserver. Ryoku's fallback SDDM must therefore
# supply its Wayland backend or NixOS rejects system.build.toplevel.
assert !bare.services.xserver.enable;
assert bare.services.displayManager.sddm.enable;
assert bare.services.displayManager.sddm.wayland.enable;
assert bare.services.displayManager.sddm.theme == "ryoku";

# Preserve explicit user choices and existing display managers.
assert !disabled.services.displayManager.sddm.enable;
assert custom.services.displayManager.sddm.theme == "custom";
assert !gdm.services.displayManager.sddm.enable;
assert !lightdm.services.displayManager.sddm.enable;
assert !greetd.services.displayManager.sddm.enable;

# This is deliberately the real system closure, not a dummy runCommand.
# Building this check forces NixOS' complete assertion machinery.
bare.system.build.toplevel
