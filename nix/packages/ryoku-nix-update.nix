{ pkgs, src }:

pkgs.writeShellApplication {
  name = "ryoku-nix-update";

  runtimeInputs = with pkgs; [
    coreutils
    curl
    git
    gnugrep
    gnused
    jq
    nix
    nixos-rebuild
    procps
    python3
    systemd
  ];

  text = ''
    export RYOKU_NIX_FLAKE_EDITOR="${src}/nix/scripts/ryoku-nix-track-edit.py"
    ${builtins.readFile (src + "/nix/scripts/ryoku-nix-update")}
  '';
}
