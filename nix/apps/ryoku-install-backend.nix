{ pkgs }:

let
  trustedRootPath = pkgs.lib.makeBinPath (with pkgs; [
    coreutils
    diffutils
    git
    gnugrep
    gnused
    gawk
    jq
    nix
    nixos-install-tools
    parted
    util-linux
    dosfstools
    e2fsprogs
    btrfs-progs
    systemd
    whois
  ]);

  backendScript = builtins.replaceStrings
    [
      "@TRUSTED_ROOT_PATH@"
      "@COREUTILS_ENV@"
      "@INSTALL_EDIT@"
    ]
    [
      trustedRootPath
      "${pkgs.coreutils}/bin/env"
      "${./ryoku-install-edit.py}"
    ]
    (builtins.readFile ./ryoku-install-backend.sh);
in
pkgs.writeShellApplication {
  name = "ryoku-install-backend";

  runtimeInputs = with pkgs; [
    coreutils
    diffutils
    git
    gnugrep
    gnused
    gawk
    jq
    nix
    nixos-install-tools
    parted
    util-linux
    dosfstools
    e2fsprogs
    btrfs-progs
    python3
    systemd
    whois
  ];

  text = backendScript;
}
