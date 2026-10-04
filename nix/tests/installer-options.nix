{ pkgs, module }:
let
  lib = pkgs.lib;

  baseline = {
    system.stateVersion = "26.05";
    networking.hostName = "ryoku-installer-test";
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
      baseline
      { programs.ryoku.enable = true; }
      extra
    ];
  }).config;

  defaults = evaluate { };
  slim = evaluate {
    programs.ryoku = {
      defaultCompositor = "niri";
      browser = "firefox";
      shell = "zsh";
      optionalApps = [ "prompt" "flatpak" "go" ];
    };
  };

  names = cfg: map lib.getName cfg.environment.systemPackages;
  manifest = cfg:
    builtins.fromJSON (
      builtins.unsafeDiscardStringContext
        cfg.environment.etc."ryoku/nix-integration.json".text
    );

  defaultNames = names defaults;
  slimNames = names slim;
  slimManifest = manifest slim;
in
assert lib.hasSuffix ".drv" defaults.system.build.toplevel.drvPath;
assert lib.hasSuffix ".drv" slim.system.build.toplevel.drvPath;
assert defaults.services.displayManager.sddm.enable;
assert defaults.services.displayManager.sddm.wayland.enable;
assert !(evaluate { services.displayManager.sddm.enable = false; }).services.displayManager.sddm.enable;
assert !(evaluate { services.greetd.enable = true; }).services.displayManager.sddm.enable;
assert (evaluate {
  programs.ryoku.defaultCompositor = "niri";
  services.displayManager.defaultSession = "hyprland";
}).services.displayManager.defaultSession == "hyprland";
assert defaults.virtualisation.docker.enable;
assert !defaults.services.flatpak.enable;
assert builtins.elem "fastfetch" defaultNames;
assert builtins.elem "gamescope" defaultNames;
assert builtins.elem "quickemu" defaultNames;

assert !slim.virtualisation.docker.enable;
assert slim.services.flatpak.enable;
assert builtins.elem "starship" slimNames;
assert builtins.elem "go" slimNames;
assert builtins.elem "firefox" slimNames;
assert !builtins.elem "fastfetch" slimNames;
assert !builtins.elem "gamescope" slimNames;
assert !builtins.elem "quickemu" slimNames;
assert slim.services.displayManager.defaultSession == "niri";
assert slim.environment.sessionVariables.RYOKU_DEFAULT_BROWSER == "firefox";

assert slimManifest.schema == 1;
assert slimManifest.host == "ryoku-installer-test";
assert slimManifest.shell == "zsh";
assert slimManifest.browser == "firefox";
assert slimManifest.defaultCompositor == "niri";
assert slimManifest.optionalApps == [ "prompt" "flatpak" "go" ];
assert lib.hasPrefix "/nix/store/" slimManifest.configBase;
assert lib.hasPrefix "/nix/store/" slimManifest.i18nDir;
assert builtins.length slimManifest.packages > 0;
assert builtins.all (p: lib.hasPrefix "/nix/store/" p.path) slimManifest.packages;

pkgs.runCommand "ryoku-installer-options-check" { } ''
  touch "$out"
''
