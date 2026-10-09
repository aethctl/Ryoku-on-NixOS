{ pkgs }:

pkgs.writeShellApplication {
  name = "ryoku-install-backend";

  runtimeInputs = with pkgs; [
    coreutils
    diffutils
    git
    gnugrep
    jq
    nix
    pciutils
    python3
    systemd
  ];

  text = ''
    set -euo pipefail

    source_ref="''${RYOKU_INSTALL_SOURCE:-github:aethctl/Ryoku-on-NixOS/main}"
    flake_arg="/etc/nixos"
    assume_yes=0
    dry_run=0
    compositor=""
    browser=""
    shell_choice=""
    apps_spec=""
    apps_set=0
    default_apps="prompt,fastfetch,yazi,cli-tools,pavucontrol,songrec,openrgb,upscale,gamescope,gamemode,mangohud,vm,docker,mise"

    # Bootstrap the public cache before the new NixOS generation
    # activates its declarative substituter configuration.
    cache_url="https://ryotunes.cachix.org"
    cache_key="ryotunes.cachix.org-1:QNocajCsVm/IAMb8LPOWJi72XwqiexW9ec0UqeXLpGs="

    bootstrap_cache=(
      --option extra-substituters "$cache_url"
      --option extra-trusted-public-keys "$cache_key"
    )

    trusted_root_path="${pkgs.lib.makeBinPath [
      pkgs.coreutils
      pkgs.git
      pkgs.nix
      pkgs.systemd
    ]}:/run/current-system/sw/bin:/run/wrappers/bin"

    run_root() {
      if [ "$(id -u)" -eq 0 ]; then
        "$@"
        return
      fi

      if [ ! -x /run/wrappers/bin/sudo ]; then
        echo "ryoku-install: NixOS sudo wrapper is unavailable at /run/wrappers/bin/sudo" >&2
        exit 1
      fi

      /run/wrappers/bin/sudo \
        ${pkgs.coreutils}/bin/env \
        "PATH=$trusted_root_path" \
        "$@"
    }

    detect_gpu_vendors() {
      if [ -n "''${RYOKU_INSTALL_GPU_VENDORS:-}" ]; then
        printf '%s\n' "$RYOKU_INSTALL_GPU_VENDORS" | tr ',' '\n'
        return
      fi

      lspci -Dn 2>/dev/null | awk '
        $2 ~ /^(0300|0302|0380):$/ {
          split($3, id, ":")
          vendor = tolower(id[1])
          if (vendor == "10de") print "nvidia"
          else if (vendor == "1002") print "amd"
          else if (vendor == "8086") print "intel"
        }
      ' | awk '!seen[$0]++'
    }

    detect_nvidia_model() {
      if [ -n "''${RYOKU_INSTALL_NVIDIA_MODEL:-}" ]; then
        printf '%s\n' "$RYOKU_INSTALL_NVIDIA_MODEL"
        return
      fi

      lspci -nn 2>/dev/null |
        awk 'BEGIN { IGNORECASE=1 } /VGA compatible controller|3D controller|Display controller/ && /NVIDIA/ { print; exit }'
    }

    nvidia_package_attr() {
      model="$1"

      case "$model" in
        *"GTX 6"??*|*"GTX 7"??*)
          printf '%s\n' legacy_470
          ;;
        *"GTX 9"??*|*"GTX 10"??*)
          printf '%s\n' legacy_580
          ;;
        *)
          printf '%s\n' stable
          ;;
      esac
    }

    render_gpu_config() {
      vendors="$(detect_gpu_vendors || true)"
      has_intel=0
      has_amd=0
      has_nvidia=0

      while IFS= read -r vendor; do
        case "$vendor" in
          intel) has_intel=1 ;;
          amd) has_amd=1 ;;
          nvidia) has_nvidia=1 ;;
        esac
      done <<< "$vendors"

      cat <<'EOF_GPU'
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
EOF_GPU

      kernel_modules=()
      if [ "$has_intel" -eq 1 ]; then
        kernel_modules+=(i915)
      fi
      if [ "$has_amd" -eq 1 ]; then
        kernel_modules+=(amdgpu)
      fi
      if [ "''${#kernel_modules[@]}" -gt 0 ]; then
        printf '\n  boot.initrd.kernelModules = lib.mkAfter ['
        printf ' "%s"' "''${kernel_modules[@]}"
        printf ' ];\n'
      fi

      if [ "$has_intel" -eq 1 ]; then
        cat <<'EOF_GPU'
  hardware.graphics.extraPackages = lib.mkAfter [
    pkgs.intel-media-driver
    pkgs.vpl-gpu-rt
  ];
EOF_GPU
      fi

      if [ "$has_nvidia" -eq 1 ]; then
        model="$(detect_nvidia_model || true)"
        package_attr="$(nvidia_package_attr "$model")"
        cat <<EOF_GPU

  # NVIDIA detected by ryoku-install: ''${model:-unknown model}
  nixpkgs.config.allowUnfree = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.$package_attr;
  };
EOF_GPU
      fi
    }

    usage() {
      cat <<'EOF'
Usage:
  ryoku-install-backend [options]

Options:
  --flake PATH[#HOST]   NixOS flake to configure (default: /etc/nixos)
  --source REF          Ryoku flake reference
  --compositor NAME     Initial compositor: hyprland or niri
  --browser NAME        Browser: chromium or firefox
  --shell NAME          Interactive shell: fish or zsh
  --apps CSV            Optional app IDs, comma-separated; use none for empty
  --dry-run             Show proposed changes without writing them
  -y, --yes             Skip confirmation
  -h, --help            Show this help
EOF
    }

    while [ "$#" -gt 0 ]; do
      case "$1" in
        --flake)
          [ "$#" -ge 2 ] || {
            echo "ryoku-install: --flake requires a value" >&2
            exit 2
          }
          flake_arg="$2"
          shift 2
          ;;
        --source)
          [ "$#" -ge 2 ] || {
            echo "ryoku-install: --source requires a value" >&2
            exit 2
          }
          source_ref="$2"
          shift 2
          ;;
        --compositor)
          [ "$#" -ge 2 ] || {
            echo "ryoku-install: --compositor requires a value" >&2
            exit 2
          }
          compositor="$2"
          shift 2
          ;;
        --browser)
          [ "$#" -ge 2 ] || {
            echo "ryoku-install: --browser requires a value" >&2
            exit 2
          }
          browser="$2"
          shift 2
          ;;
        --shell)
          [ "$#" -ge 2 ] || {
            echo "ryoku-install: --shell requires a value" >&2
            exit 2
          }
          shell_choice="$2"
          shift 2
          ;;
        --apps)
          [ "$#" -ge 2 ] || {
            echo "ryoku-install: --apps requires a value" >&2
            exit 2
          }
          apps_spec="$2"
          apps_set=1
          shift 2
          ;;
        --dry-run)
          dry_run=1
          shift
          ;;
        -y|--yes)
          assume_yes=1
          shift
          ;;
        -h|--help)
          usage
          exit 0
          ;;
        *)
          echo "ryoku-install: unknown option: $1" >&2
          usage >&2
          exit 2
          ;;
      esac
    done

    case "$compositor" in
      ""|hyprland|niri) ;;
      *)
        echo "ryoku-install: invalid compositor: $compositor" >&2
        exit 2
        ;;
    esac

    case "$browser" in
      ""|chromium|firefox) ;;
      *)
        echo "ryoku-install: invalid browser: $browser" >&2
        exit 2
        ;;
    esac

    if [ -z "$compositor" ]; then
      if [ "$assume_yes" -ne 1 ] && [ -t 0 ]; then
        printf '\nInitial compositor\n'
        printf '  1) Hyprland  (Ryoku default)\n'
        printf '  2) niri      (scrollable tiling)\n'
        printf 'Choose [1]: '
        read -r answer
        case "$answer" in
          2) compositor="niri" ;;
          ""|1) compositor="hyprland" ;;
          *)
            echo "ryoku-install: invalid compositor selection" >&2
            exit 2
            ;;
        esac
      else
        compositor="hyprland"
      fi
    fi

    if [ -z "$browser" ]; then
      if [ "$assume_yes" -ne 1 ] && [ -t 0 ]; then
        printf '\nWeb browser\n'
        printf '  1) Chromium   (Ryoku NixOS default)\n'
        printf '  2) Firefox    (Gecko)\n'
        printf 'Choose [1]: '
        read -r answer
        case "$answer" in
          2) browser="firefox" ;;
          ""|1) browser="chromium" ;;
          *)
            echo "ryoku-install: invalid browser selection" >&2
            exit 2
            ;;
        esac
      else
        browser="chromium"
      fi
    fi

    case "$shell_choice" in
      ""|fish|zsh) ;;
      *)
        echo "ryoku-install: invalid shell: $shell_choice" >&2
        exit 2
        ;;
    esac

    if [ -z "$shell_choice" ]; then
      if [ "$assume_yes" -ne 1 ] && [ -t 0 ]; then
        printf '\nInteractive shell\n'
        printf '  1) Fish      (Ryoku default)\n'
        printf '  2) Zsh       (Ryoku integration, user .zshrc untouched)\n'
        printf 'Choose [1]: '
        read -r answer
        case "$answer" in
          2) shell_choice="zsh" ;;
          ""|1) shell_choice="fish" ;;
          *) echo "ryoku-install: invalid shell selection" >&2; exit 2 ;;
        esac
      else
        shell_choice="fish"
      fi
    fi

    if [ "$apps_set" -eq 0 ]; then
      apps_spec="$default_apps"
    fi

    selected_apps=()
    if [ -n "$apps_spec" ] && [ "$apps_spec" != "none" ]; then
      IFS=',' read -r -a raw_apps <<< "$apps_spec"
      declare -A seen_apps=()
      for app in "''${raw_apps[@]}"; do
        app="''${app//[[:space:]]/}"
        [ -n "$app" ] || continue
        case "$app" in
          prompt|bash-edit|fastfetch|yazi|cli-tools|git-tools|pavucontrol|songrec|openrgb|upscale|localsend|gamescope|gamemode|mangohud|vm|docker|flatpak|go|pytools|mise) ;;
          *) echo "ryoku-install: invalid optional app id: $app" >&2; exit 2 ;;
        esac
        if [ -z "''${seen_apps[$app]+x}" ]; then
          selected_apps+=("$app")
          seen_apps[$app]=1
        fi
      done
    fi

    case "$flake_arg" in
      *#*)
        flake_root="''${flake_arg%%#*}"
        host="''${flake_arg#*#}"
        ;;
      *)
        flake_root="$flake_arg"
        host=""
        ;;
    esac

    flake_root="$(readlink -f "$flake_root")"
    flake_file="$flake_root/flake.nix"
    module_file="$flake_root/ryoku.nix"

    [ -f "$flake_file" ] || {
      echo "ryoku-install: no flake.nix found at $flake_root" >&2
      exit 1
    }

    if [ -z "$host" ]; then
      current_host="$(cat /proc/sys/kernel/hostname)"

      show="$(
        nix flake show "path:$flake_root" --json --no-write-lock-file 2>/dev/null ||
        nix flake show "path:$flake_root" --json --impure --no-write-lock-file
      )"

      mapfile -t hosts < <(
        printf '%s\n' "$show" |
          jq -r '.nixosConfigurations // {} | keys[]'
      )

      [ "''${#hosts[@]}" -gt 0 ] || {
        echo "ryoku-install: no nixosConfigurations found" >&2
        exit 1
      }

      for candidate in "''${hosts[@]}"; do
        if [ "$candidate" = "$current_host" ]; then
          host="$candidate"
          break
        fi
      done

      if [ -z "$host" ] && [ "''${#hosts[@]}" -eq 1 ]; then
        host="''${hosts[0]}"
      fi

      if [ -z "$host" ]; then
        echo "ryoku-install: multiple NixOS hosts found:" >&2
        printf '  %s\n' "''${hosts[@]}" >&2
        echo "Re-run with --flake $flake_root#HOST" >&2
        exit 1
      fi
    fi

    if [ -f "$module_file" ] &&
       ! grep -Fq '# Managed by ryoku-install.' "$module_file"
    then
      echo "ryoku-install: $module_file already exists and is not installer-managed" >&2
      echo "Refusing to overwrite it." >&2
      exit 1
    fi

    work_dir="$(mktemp -d)"
    trap 'rm -rf "$work_dir"' EXIT

    work_flake="$work_dir/flake.nix"
    work_module="$work_dir/ryoku.nix"

    cp "$flake_file" "$work_flake"

    apps_block=""
    if [ "''${#selected_apps[@]}" -gt 0 ]; then
      apps_block="$(printf '      "%s"\n' "''${selected_apps[@]}")"
    fi

    gpu_block="$(render_gpu_config)"

    cat > "$work_module" <<EOF
# Managed by ryoku-install.
{ config, lib, pkgs, ... }:

{
  programs.ryoku = {
    enable = true;
    defaultCompositor = "$compositor";
    browser = "$browser";
    shell = "$shell_choice";
    optionalApps = [
$apps_block
    ];
  };

$gpu_block
}
EOF

    python3 ${./ryoku-install-edit.py} "$work_flake" "$host" "$source_ref"

    printf '\nRyoku NixOS installer\n'
    printf '%s\n' '────────────────────────────────────────'
    printf 'Flake   %s\n' "$flake_root"
    printf 'Host    %s\n' "$host"
    printf 'Source  %s\n' "$source_ref"
    printf 'WM      %s\n' "$compositor"
    printf 'Browser %s\n' "$browser"
    printf 'Shell   %s\n' "$shell_choice"
    gpu_summary="$(detect_gpu_vendors 2>/dev/null | paste -sd, -)"
    printf 'GPU     %s\n' "''${gpu_summary:-generic}"
    if [ "''${#selected_apps[@]}" -gt 0 ]; then
      printf 'Apps    %s\n' "$(IFS=,; echo "''${selected_apps[*]}")"
    else
      printf 'Apps    none\n'
    fi

    printf '\nProposed flake.nix changes:\n'
    diff -u "$flake_file" "$work_flake" || true

    printf '\nProposed ryoku.nix:\n'
    cat "$work_module"

    if [ "$dry_run" -eq 1 ]; then
      printf '\nDry run complete. No files were changed.\n'
      exit 0
    fi

    if [ "$assume_yes" -ne 1 ]; then
      printf '\nThe new NixOS generation will be built before it is switched.\n'
      printf 'Bootloader, kernel and partition settings are not modified.\n'
      printf 'Continue? [y/N] '

      read -r answer

      case "$answer" in
        y|Y|yes|YES)
          ;;
        *)
          echo "Cancelled."
          exit 0
          ;;
      esac
    fi

    if [ -x /run/current-system/sw/bin/nixos-rebuild ]; then
      nixos_rebuild=/run/current-system/sw/bin/nixos-rebuild
    else
      nixos_rebuild="$(command -v nixos-rebuild || true)"
    fi

    [ -n "$nixos_rebuild" ] || {
      echo "ryoku-install: nixos-rebuild is unavailable" >&2
      exit 1
    }

    echo "@@RYOKU_STEP prepare"
    timestamp="$(date +%Y%m%d-%H%M%S)"
    backup_dir="/var/backups/ryoku-nixos/$timestamp"

    had_lock=0
    had_module=0

    [ -f "$flake_root/flake.lock" ] && had_lock=1
    [ -f "$module_file" ] && had_module=1

    run_root mkdir -p "$backup_dir"
    run_root cp -a "$flake_file" "$backup_dir/flake.nix"

    if [ "$had_lock" -eq 1 ]; then
      run_root cp -a "$flake_root/flake.lock" "$backup_dir/flake.lock"
    fi

    if [ "$had_module" -eq 1 ]; then
      run_root cp -a "$module_file" "$backup_dir/ryoku.nix"
    fi

    rollback() {
      transaction_started=0
      run_root cp -a "$backup_dir/flake.nix" "$flake_file"

      if [ "$had_lock" -eq 1 ]; then
        run_root cp -a "$backup_dir/flake.lock" "$flake_root/flake.lock"
      else
        run_root rm -f "$flake_root/flake.lock"
      fi

      if [ "$had_module" -eq 1 ]; then
        run_root cp -a "$backup_dir/ryoku.nix" "$module_file"
      else
        run_root rm -f "$module_file"
      fi
    }

    transaction_started=0
    cleanup() {
      result=$?
      trap - EXIT INT TERM
      if [ "$transaction_started" -eq 1 ]; then
        rollback
      fi
      rm -rf "$work_dir"
      exit "$result"
    }
    trap cleanup EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM

    transaction_started=1
    run_root cp "$work_flake" "$flake_file"
    run_root install -m 0644 "$work_module" "$module_file"

    echo "@@RYOKU_STEP lock"
    printf '\nUpdating flake lock...\n'

    if ! run_root nix flake lock "path:$flake_root"; then
      rollback
      echo "ryoku-install: flake lock failed; files restored" >&2
      exit 1
    fi

    echo "@@RYOKU_STEP build"
    printf '\nBuilding NixOS generation...\n'

    if ! run_root "$nixos_rebuild" build \
      --flake "path:$flake_root#$host" \
      "''${bootstrap_cache[@]}"
    then
      rollback
      echo "ryoku-install: build failed; files restored" >&2
      exit 1
    fi

    echo "@@RYOKU_STEP switch"
    printf '\nSwitching generation...\n'

    if ! run_root "$nixos_rebuild" switch \
      --flake "path:$flake_root#$host" \
      "''${bootstrap_cache[@]}"
    then
      rollback
      echo "ryoku-install: switch failed; configuration files restored" >&2
      exit 1
    fi

    transaction_started=0
    echo "@@RYOKU_STEP materialize"
    if [ -x /run/current-system/sw/bin/ryoku-materialize ]; then
      /run/current-system/sw/bin/ryoku-materialize
    fi

    systemctl --user daemon-reload >/dev/null 2>&1 || true
    systemctl --user try-restart ryoku-shell.service >/dev/null 2>&1 || true

    echo "@@RYOKU_DONE"
    printf '\nRyoku installation complete.\n'
    printf 'Backup: %s\n' "$backup_dir"
  '';
}
