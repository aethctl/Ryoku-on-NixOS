{
  description = "Nix packaging for the Ryoku desktop";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    glazepkg = {
      url = "github:neur0map/glazepkg";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    hyprglassSrc = {
      url = "github:hyprnux/hyprglass/v0.7.0";
      flake = false;
    };

    bibataMaterialSrc = {
      url = "github:rtgiskard/bibata_cursor/f4ccfe8abb63fddc7b3ce51a866fd8378395cb3d";
      flake = false;
    };

    imgbordersSrc = {
      url = "git+https://codeberg.org/zacoons/imgborders.git?ref=master";
      flake = false;
    };

    # Native Ryotunes 2.5.1 application used by Ryoku 0.59.7.
    # Keep this pinned to the exact upstream release commit.
    ryotunesSrc = {
      url = "github:ryoku-dev/ryotunes/2e2652192d629632fe6bc5a5232bba82c77d41e2";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, glazepkg, hyprglassSrc, bibataMaterialSrc, imgbordersSrc, ryotunesSrc, ... }:
    let
      version =
        builtins.replaceStrings
          [ "\n" "\r" ]
          [ "" "" ]
          (builtins.readFile ./VERSION);

      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
      };

      ryoku = import ./nix/packages {
        inherit
          pkgs
          hyprglassSrc
          bibataMaterialSrc
          imgbordersSrc
          ryotunesSrc
          version
          ;

        src = self;
      };

      ryokuDev = import ./nix/apps/ryoku-dev.nix {
        inherit pkgs ryoku;
        src = self;
      };

      ryokuMaterialize = import ./nix/apps/ryoku-materialize.nix {
        inherit pkgs ryoku;
      };
      ryokuInstall = import ./nix/apps/ryoku-install.nix {
        inherit pkgs;
      };
    in
    {
      lib.version = version;

      nixosModules.default =
        import ./nix/modules/ryoku.nix {
          inherit self;
          ryokuNixpkgs = pkgs;
        };

      packages.${system} = {
        ryoku-install = ryokuInstall;
        ryoku-shell = ryoku.shell;
        ryoku-ui = ryoku.ui;
        ryoku-plugin-kit = ryoku.pluginKit;
        ryoku-framebars = ryoku.frameBars;
        ryoku-blobs = ryoku.blobs;

        ryoku-qml = ryoku.qml;

        ryoku-cli = ryoku.cli;
        ryoku-nix-update = ryoku.nixUpdate;
        ryoku-hub = ryoku.hub;
        ryoku-rashin = ryoku.rashin;
        ryoku-ryostore = ryoku.ryostore;
        ryoku-ryomotion = ryoku.ryomotion;
        ryoku-ryovm-helpers = ryoku.ryovmHelpers;
        ryoku-livewall = ryoku.livewall;
        ryoku-ryogami = ryoku.ryogami;
        ryoku-ryotunes = ryoku.ryotunes;
        ryoku-keysounds = ryoku.keysounds;
        ryoku-qmk-hid = ryoku.qmkHid;
        ryoku-waifu2x = ryoku.waifu2x;
        ryoku-helpers = ryoku.helpers;
        ryoku-nixos-system-bridge = ryoku.nixosSystemBridge;
        ryoku-desktop-data = ryoku.desktopData;

        # Ryoku owns its compositor ABI. These come from Ryoku's
        # locked nixpkgs rather than the host's package set.
        ryoku-hyprland = pkgs.hyprland;
        ryoku-xdg-desktop-portal-hyprland = pkgs.xdg-desktop-portal-hyprland;
        ryoku-matugen = pkgs.matugen;

        ryoku-hyprglass = ryoku.hyprglass;
        ryoku-imgborders = ryoku.imgborders;
        ryoku-hypr-plugins = ryoku.hyprPlugins;
        ryoku-cursor-material = ryoku.cursorMaterial;
        ryoku-maple-mono-nf = ryoku.mapleMonoNF;

        ryoku-bundle = ryoku.bundle;

        ryoku-dev = ryokuDev;
        ryoku-materialize = ryokuMaterialize;
        gpk = glazepkg.packages.${system}.gpk;

        default = ryoku.bundle;
      };

      apps.${system} = {
        install = {
          type = "app";
          program = "${ryokuInstall}/bin/ryoku-install";
          meta.description = "Install Ryoku on an existing flake-based NixOS system";
        };

        ryoku-dev = {
          type = "app";
          program = "${ryokuDev}/bin/ryoku-dev";
          meta.description = "Run Ryoku directly from a development checkout";
        };

        ryoku-materialize = {
          type = "app";
          program = "${ryokuMaterialize}/bin/ryoku-materialize";
          meta.description = "Materialize the packaged Ryoku desktop into the user configuration";
        };

        default = {
          type = "app";
          program = "${ryokuDev}/bin/ryoku-dev";
          meta.description = "Run the Ryoku development environment";
        };
      };

      checks.${system} = {
        # Core runtime
        ryoku-shell = ryoku.shell;
        ryoku-cli = ryoku.cli;
        ryoku-hub = ryoku.hub;
        ryoku-rashin = ryoku.rashin;
        ryoku-ryostore = ryoku.ryostore;
        ryoku-ryomotion = ryoku.ryomotion;
        ryoku-ryovm-helpers = ryoku.ryovmHelpers;
        ryoku-livewall = ryoku.livewall;
        ryoku-ryogami = ryoku.ryogami;
        ryoku-ryotunes = ryoku.ryotunes;
        ryoku-keysounds = ryoku.keysounds;
        ryoku-qmk-hid = ryoku.qmkHid;
        ryoku-waifu2x = ryoku.waifu2x;

        ryoku-waifu2x-models = pkgs.runCommand
          "ryoku-waifu2x-models-check"
          { }
          ''
            test -d               "${ryoku.waifu2x}/share/waifu2x-ncnn-vulkan/models-cunet"

            test -n "$(
              find                 "${ryoku.waifu2x}/share/waifu2x-ncnn-vulkan/models-cunet"                 -maxdepth 1                 -type f                 -print                 -quit
            )"

            touch "$out"
          '';

        # QML modules
        ryoku-ui = ryoku.ui;
        ryoku-plugin-kit = ryoku.pluginKit;
        ryoku-framebars = ryoku.frameBars;
        ryoku-blobs = ryoku.blobs;
        ryoku-qml = ryoku.qml;

        # Desktop integration
        ryoku-desktop-data = ryoku.desktopData;
        ryoku-helpers = ryoku.helpers;
        ryoku-nixos-system-bridge = ryoku.nixosSystemBridge;
        ryoku-bundle = ryoku.bundle;

        # CLI integration
        ryoku-cli-config-base = pkgs.runCommand
          "ryoku-cli-config-base-check"
          { }
          ''
            output="$(${ryoku.cli}/bin/ryoku status)"

            printf '%s\n' "$output" |
              ${pkgs.gnugrep}/bin/grep -Fq \
                "config base:   ${ryoku.desktopData}/share/ryoku/config"

            touch "$out"
          '';

        # Installer
        ryoku-install = ryokuInstall;

        ryoku-install-parser = pkgs.runCommand
          "ryoku-install-parser-check"
          {
            nativeBuildInputs = [
              pkgs.python3
              pkgs.nix
            ];
          }
          ''
            RYOKU_INSTALL_PARSER=${./nix/apps/ryoku-install-edit.py} \
              python3 ${./nix/tests/test-ryoku-install-edit.py}

            touch "$out"
          '';

        # User-facing deployment utility
        ryoku-materialize = ryokuMaterialize;
      };

      devShells.${system}.default = pkgs.mkShell {
        packages = with pkgs; [
          go
          cmake
          ninja
          pkg-config

          qt6.qtbase
          qt6.qtdeclarative
          qt6.qtmultimedia
          qt6.qtshadertools

          quickshell
        ];

        shellHook = ''
          export GOTOOLCHAIN=local
        '';
      };
    };
}
