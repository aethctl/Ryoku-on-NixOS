{ pkgs, ryoku }:

pkgs.writeShellApplication {
  name = "ryoku-materialize";

  runtimeInputs = with pkgs; [
    coreutils
    findutils
    jq
    systemd
  ];

  text = ''
    base="${ryoku.desktopData}/share/ryoku/config"
    qml="${ryoku.qml}/lib/qt-6/qml"

    config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
    user_units="$config_home/systemd/user"
    state="''${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/nix"
    stamp="$(date +%Y%m%d-%H%M%S)"
    backup="$state/backups/$stamp"

    mkdir -p "$state"

    # ----------------------------------------------------------
    # First deployment backup
    #
    # Derive the backup set from the packaged config itself.
    # This keeps the backup complete when upstream adds another
    # application config instead of maintaining a second list here.
    # ----------------------------------------------------------

    if [ ! -e "$state/initial-backup-complete" ]; then
      mkdir -p "$backup/config"

      while IFS= read -r -d "" packaged; do
        name="''${packaged##*/}"
        current="$config_home/$name"

        if [ -e "$current" ] || [ -L "$current" ]; then
          cp -a -- "$current" "$backup/config/"
        fi
      done < <(
        find "$base" \
          -mindepth 1 \
          -maxdepth 1 \
          -print0
      )

      # Ryoku also owns these user-local QML module names. They live
      # outside XDG_CONFIG_HOME, so preserve a previous deployment
      # before replacing the modules with Nix-store links.
      current_qml="$HOME/.local/lib/qt6/qml/Ryoku"

      if [ -e "$current_qml" ] || [ -L "$current_qml" ]; then
        mkdir -p "$backup/local-qml"
        cp -a -- "$current_qml" "$backup/local-qml/"
      fi

      # Preserve any existing Ryoku user units before NixOS takes
      # ownership of these names.
      for unit in \
        hyprland-session.target \
        ryoku-shell.service \
        ryoku-rashin.service \
        ryoku-ai-usage.service \
        ryoku-ai-usage.timer
      do
        current="$user_units/$unit"

        if [ -e "$current" ] || [ -L "$current" ]; then
          mkdir -p "$backup/systemd-user"
          cp -a -- "$current" "$backup/systemd-user/"
        fi
      done

      printf '%s\n' "$backup" > "$state/initial-backup-path"
      touch "$state/initial-backup-complete"
    fi

    # ----------------------------------------------------------
    # Upstream materialization
    # ----------------------------------------------------------

    export RYOKU_CONFIG_BASE="$base"

    ${ryoku.cli}/bin/ryoku materialize

    # Keep persisted Quick Settings state in step with Ryostage.
    #
    # Older NixOS installs may still carry the retired `depth` and
    # `parallax` modules because their shell.json survives generation
    # switches. Fold those entries into the unified `stage` module while
    # preserving the rest of the user's rail and its ordering.
    shell_store="$config_home/ryoku/shell.json"

    if [ -f "$shell_store" ]; then
      modules="$(
        jq -c \
          '.frameBars.menus["quick-settings"].modules // null' \
          "$shell_store" \
          2>/dev/null || true
      )"

      if [ -n "$modules" ] && [ "$modules" != "null" ]; then
        migrated="$(
          jq -c '
            if type != "array" then
              .
            elif any(.[]; . == "stage" or . == "depth" or . == "parallax") then
              reduce .[] as $module (
                { modules: [], stageAdded: false };

                if
                  $module == "stage"
                  or $module == "depth"
                  or $module == "parallax"
                then
                  if .stageAdded then
                    .
                  else
                    .modules += ["stage"] |
                    .stageAdded = true
                  end
                else
                  .modules += [$module]
                end
              ) |
              .modules
            elif index("home") then
              . + ["stage"]
            else
              .
            end
          ' <<< "$modules"
        )"

        if [ "$migrated" != "$modules" ]; then
          tmp="$shell_store.ryoku-nix-tmp"

          jq \
            --argjson modules "$migrated" \
            '.frameBars.menus["quick-settings"].modules = $modules' \
            "$shell_store" > "$tmp"

          chmod --reference="$shell_store" "$tmp"
          mv -f -- "$tmp" "$shell_store"
        fi
      fi
    fi

    # Seeds copied out of the Nix store need to remain writable.
    for file in \
      hypr/monitors.lua \
      hypr/gpu.lua \
      hypr/keyboard.lua \
      hypr/user.lua \
      fastfetch/config.jsonc \
      kitty/current-theme.conf
    do
      path="$config_home/$file"

      # Home Manager commonly manages config as symlinks into /nix/store.
      # Only normal materialized files should have their mode changed.
      if [ -f "$path" ] && [ ! -L "$path" ]; then
        chmod u+w "$path"
      fi
    done

    # ----------------------------------------------------------
    # QML modules
    #
    # Upstream env.lua expects ~/.local/lib/qt6/qml for a
    # non-/usr development deployment.
    # ----------------------------------------------------------

    user_qml="$HOME/.local/lib/qt6/qml/Ryoku"

    mkdir -p "$user_qml"

    for module in Ui PluginKit FrameBars Blobs; do
      rm -rf -- "''${user_qml:?}/$module"

      ln -s \
        "$qml/Ryoku/$module" \
        "$user_qml/$module"
    done

    # Hyprland's bundled plugins are immutable generation-owned packages.
    # Older Ryoku-on-NixOS revisions exposed them through ~/.local symlinks;
    # Hub now receives the store package directory directly instead.
    #
    # Remove only those old symlinks. A real user-created plugin file is left
    # alone, although bundled plugin IDs are ignored by Hub while Nix owns them.
    plugin_dir="$HOME/.local/lib/hyprland/plugins"

    if [ -d "$plugin_dir" ]; then
      for plugin in \
        dynamic-cursors \
        hyprbars \
        hyprfocus \
        hyprglass \
        imgborders \
        keysounds
      do
        if [ -L "$plugin_dir/$plugin.so" ]; then
          rm -f -- "$plugin_dir/$plugin.so"
        fi
      done
    fi

    # ----------------------------------------------------------
    # NixOS owns Ryoku's systemd user units declaratively.
    #
    # Remove legacy units left by an older materialization or an
    # existing Arch Ryoku deployment. User-local units otherwise
    # override the NixOS-managed definitions.
    # ----------------------------------------------------------

    rm -f -- \
      "$user_units/hyprland-session.target" \
      "$user_units/ryoku-shell.service" \
      "$user_units/ryoku-rashin.service" \
      "$user_units/ryoku-ai-usage.service" \
      "$user_units/ryoku-ai-usage.timer"

    systemctl --user daemon-reload 2>/dev/null || true

    # ----------------------------------------------------------
    # Seed visible assets without replacing user files
    # ----------------------------------------------------------

    data_home="''${XDG_DATA_HOME:-$HOME/.local/share}"

    mkdir -p \
      "$HOME/Pictures/Wallpapers" \
      "$HOME/Pictures/ryodecors" \
      "$data_home/ryoku/assets/brand"

    if [ -d "${ryoku.desktopData}/share/ryoku/wallpapers" ]; then
      cp -n \
        "${ryoku.desktopData}/share/ryoku/wallpapers/"* \
        "$HOME/Pictures/Wallpapers/" \
        2>/dev/null || true
    fi

    if [ -d "${ryoku.desktopData}/share/ryoku/ryodecors" ]; then
      cp -n \
        "${ryoku.desktopData}/share/ryoku/ryodecors/"* \
        "$HOME/Pictures/ryodecors/" \
        2>/dev/null || true
    fi

    if [ -d "${ryoku.desktopData}/share/ryoku/brand" ]; then
      cp -n \
        "${ryoku.desktopData}/share/ryoku/brand/"* \
        "$data_home/ryoku/assets/brand/" \
        2>/dev/null || true
    fi

    # User-space equivalents for integrations normally installed under /usr.
    ryoku_data="$data_home/ryoku"

    mkdir -p \
      "$data_home/nautilus-python/extensions" \
      "$ryoku_data/spicetify"

    ln -sfn \
      "${ryoku.desktopData}/share/ryoku/nautilus/ryoku-stash-menu.py" \
      "$data_home/nautilus-python/extensions/ryoku-stash-menu.py"

    if [ ! -e "$ryoku_data/browser" ] || [ -L "$ryoku_data/browser" ]; then
      ln -sfnT \
        "${ryoku.desktopData}/share/ryoku/browser" \
        "$ryoku_data/browser"
    fi

    ln -sfn \
      "${ryoku.desktopData}/share/ryoku/spicetify/ryoku-canvas.js" \
      "$ryoku_data/spicetify/ryoku-canvas.js"

    printf '\n'
    printf 'Ryoku desktop materialized successfully.\n'

    if [ -f "$state/initial-backup-path" ]; then
      printf 'Original config backup: %s\n' \
        "$(cat "$state/initial-backup-path")"
    fi

    printf '\nLog out and start Hyprland to enter Ryoku.\n'
  '';
}
