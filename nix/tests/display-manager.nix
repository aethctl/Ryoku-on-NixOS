{ pkgs, module }:
let
  evaluate = extra: (import (pkgs.path + "/nixos/lib/eval-config.nix") {
    system = pkgs.stdenv.hostPlatform.system;
    modules = [ module { programs.ryoku.enable = true; } extra ];
  }).config;
  bare = evaluate { };
  disabled = evaluate { services.displayManager.sddm.enable = false; };
  custom = evaluate { services.displayManager.sddm.theme = "custom"; };
  gdm = evaluate { services.displayManager.gdm.enable = true; };
  lightdm = evaluate { services.xserver.displayManager.lightdm.enable = true; };
  greetd = evaluate { services.greetd.enable = true; };
in
assert bare.services.displayManager.sddm.enable;
assert bare.services.displayManager.sddm.theme == "ryoku";
assert !disabled.services.displayManager.sddm.enable;
assert custom.services.displayManager.sddm.theme == "custom";
assert !gdm.services.displayManager.sddm.enable;
assert !lightdm.services.displayManager.sddm.enable;
assert !greetd.services.displayManager.sddm.enable;
pkgs.runCommand "ryoku-display-manager-check" { } "touch $out"
