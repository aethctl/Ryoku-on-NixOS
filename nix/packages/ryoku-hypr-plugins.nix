{
  pkgs,
  hyprglass,
  imgborders,
  keysounds,
}:

pkgs.runCommand "ryoku-hyprland-plugins"
  {
    nativeBuildInputs = [
      pkgs.coreutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.gnused
    ];
  }
  ''
    outdir="$out/lib/hyprland/plugins"

    mkdir -p "$outdir"

    install_plugin() {
      out_name="$1"
      package="$2"

      candidate="$(
        find "$package" \
          -type f \
          -name "*$out_name*.so" \
          -print \
          | head -n 1
      )"

      if [ -z "$candidate" ]; then
        printf '%s\n' \
          "ryoku-hyprland-plugins: no $out_name shared object in $package" >&2

        exit 1
      fi

      ln -s \
        "$candidate" \
        "$outdir/$out_name.so"
    }

    # ----------------------------------------------------------
    # Plugin binaries
    #
    # Every package here comes from Ryoku's locked nixpkgs set and
    # therefore targets the exact same Hyprland package ABI.
    # ----------------------------------------------------------

    install_plugin \
      dynamic-cursors \
      ${pkgs.hyprlandPlugins.hypr-dynamic-cursors}

    install_plugin \
      hyprbars \
      ${pkgs.hyprlandPlugins.hyprbars}

    install_plugin \
      hyprfocus \
      ${pkgs.hyprlandPlugins.hyprfocus}

    install_plugin \
      imgborders \
      ${imgborders}

    install_plugin \
      hyprglass \
      ${hyprglass}

    install_plugin \
      keysounds \
      ${keysounds}

    # Key Sounds deliberately searches beside its loaded .so.
    # Keep the immutable shipped profiles beside the aggregate plugin
    # path as well as inside the original keysounds package.
    ln -s \
      ${keysounds}/lib/keysounds \
      "$outdir/keysounds"

    # ----------------------------------------------------------
    # Hyprland ABI receipts
    #
    # Upstream Ryoku writes these after a local plugin build. On
    # NixOS the ABI is known while constructing the immutable bundle,
    # so generate the same receipt format from the locked Hyprland
    # development headers.
    # ----------------------------------------------------------

    version_h="$(
      find \
        ${pkgs.hyprland.dev} \
        -type f \
        -path '*/hyprland/src/version.h' \
        -print \
        | head -n 1
    )"

    if [ -z "$version_h" ] || [ ! -f "$version_h" ]; then
      printf '%s\n' \
        "ryoku-hyprland-plugins: Hyprland version.h was not found" >&2

      exit 1
    fi

    define() {
      name="$1"

      sed -n \
        's/^#define[[:space:]]\+'"$name"'[[:space:]]\+"\([^"]*\)".*/\1/p' \
        "$version_h" \
        | head -n 1
    }

    strip_patch() {
      printf '%s\n' "$1" \
        | sed -E 's/\.[^.]+$//'
    }

    commit="$(define GIT_COMMIT_HASH)"
    aquamarine="$(strip_patch "$(define AQUAMARINE_VERSION)")"
    hyprutils="$(strip_patch "$(define HYPRUTILS_VERSION)")"
    hyprgraphics="$(strip_patch "$(define HYPRGRAPHICS_VERSION)")"
    hyprcursor="$(strip_patch "$(define HYPRCURSOR_VERSION)")"
    hyprlang="$(strip_patch "$(define HYPRLANG_VERSION)")"

    for value in \
      "$commit" \
      "$aquamarine" \
      "$hyprutils" \
      "$hyprgraphics" \
      "$hyprcursor" \
      "$hyprlang"
    do
      if [ -z "$value" ]; then
        printf '%s\n' \
          "ryoku-hyprland-plugins: incomplete Hyprland ABI metadata" >&2

        exit 1
      fi
    done

    abi="$commit"
    abi="''${abi}_aq_$aquamarine"
    abi="''${abi}_hu_$hyprutils"
    abi="''${abi}_hg_$hyprgraphics"
    abi="''${abi}_hc_$hyprcursor"
    abi="''${abi}_hlg_$hyprlang"

    printf '%s\n' \
      "$abi" \
      > "$outdir/.abi"

    for plugin in \
      dynamic-cursors \
      hyprbars \
      hyprfocus \
      imgborders \
      hyprglass \
      keysounds
    do
      printf '%s\n' \
        "$abi" \
        > "$outdir/$plugin.abi"
    done
  ''
