set -euo pipefail

source_ref="${RYOKU_INSTALL_SOURCE:-github:aethctl/Ryoku-on-NixOS/main}"
flake_arg="/etc/nixos"
assume_yes=0
dry_run=0
compositor=""
browser=""
shell_choice=""
apps_spec=""
apps_set=0
default_apps="prompt,fastfetch,yazi,cli-tools,pavucontrol,songrec,openrgb,upscale,gamescope,gamemode,mangohud,vm,docker,mise"

iso_mode=0
install_disk=""
filesystem=""
target_hostname=""
target_username=""
confirm_disk=""
firmware_choice="auto"
target_root="${RYOKU_INSTALL_TARGET_ROOT:-/mnt}"
iso_work=""

# Bootstrap the public cache before the new NixOS generation
# activates its declarative substituter configuration.
cache_url="https://ryotunes.cachix.org"
cache_key="ryotunes.cachix.org-1:QNocajCsVm/IAMb8LPOWJi72XwqiexW9ec0UqeXLpGs="

bootstrap_cache=(
  --option extra-substituters "$cache_url"
  --option extra-trusted-public-keys "$cache_key"
)

trusted_root_path="@TRUSTED_ROOT_PATH@:/run/current-system/sw/bin:/run/wrappers/bin"

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
    @COREUTILS_ENV@ \
    "PATH=$trusted_root_path" \
    "$@"
}

die() {
  printf 'ryoku-install: %s\n' "$*" >&2
  exit 1
}

nix_quote() {
  python3 - "$1" <<'PY_QUOTE'
import json
import sys

value = sys.argv[1]
if "\x00" in value or "\n" in value or "\r" in value:
    raise SystemExit("ryoku-install: Nix string values must be single-line")
print(json.dumps(value).replace("${", "\\${"))
PY_QUOTE
}

valid_hostname() {
  [[ "$1" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]]
}

valid_username() {
  [[ "$1" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]]
}

canonical_whole_disk() {
  local dev="$1"
  local resolved type parent

  resolved="$(readlink -f "$dev" 2>/dev/null || true)"
  [ -n "$resolved" ] && [ -b "$resolved" ] || return 1

  type="$(lsblk -dnro TYPE "$resolved" 2>/dev/null || true)"
  if [ "$type" = "disk" ]; then
    printf '%s\n' "$resolved"
    return 0
  fi

  parent="$(lsblk -dnro PKNAME "$resolved" 2>/dev/null | head -n 1)"
  [ -n "$parent" ] || return 1
  printf '/dev/%s\n' "$parent"
}

detect_live_disk() {
  local mountpoint source disk

  for mountpoint in /iso /nix/.ro-store /run/rootfsbase /; do
    source="$(findmnt -nro SOURCE "$mountpoint" 2>/dev/null || true)"
    case "$source" in
      /dev/*)
        disk="$(canonical_whole_disk "$source" 2>/dev/null || true)"
        if [ -n "$disk" ]; then
          printf '%s\n' "$disk"
          return 0
        fi
        ;;
    esac
  done
}

validate_install_disk() {
  local disk="$1"
  local resolved type ro live_disk size mounts

  case "$disk" in
    /dev/*) ;;
    *) die "installation disk must be an absolute /dev path" ;;
  esac

  # Dry runs intentionally permit a synthetic /dev path so CI can exercise the
  # complete planning/config-generation path without a block device.
  if [ "$dry_run" -eq 1 ] && [ ! -b "$disk" ]; then
    install_disk="$disk"
    return 0
  fi

  resolved="$(readlink -f "$disk" 2>/dev/null || true)"
  [ -n "$resolved" ] && [ -b "$resolved" ] || die "$disk is not a block device"

  type="$(lsblk -dnro TYPE "$resolved" 2>/dev/null || true)"
  [ "$type" = "disk" ] || die "$resolved is not a whole disk"

  ro="$(lsblk -dnro RO "$resolved" 2>/dev/null || true)"
  [ "$ro" = "0" ] || die "$resolved is read-only"

  live_disk="$(detect_live_disk || true)"
  if [ -n "$live_disk" ] && [ "$resolved" = "$live_disk" ]; then
    die "refusing to erase the disk backing the live installer ($resolved)"
  fi

  size="$(lsblk -bdnro SIZE "$resolved" 2>/dev/null || true)"
  [ -n "$size" ] || die "could not determine the size of $resolved"
  if [ "$size" -lt $((16 * 1024 * 1024 * 1024)) ]; then
    die "$resolved is smaller than the 16 GiB minimum"
  fi

  mounts="$(lsblk -nrpo MOUNTPOINTS "$resolved" 2>/dev/null | awk 'NF { print }')"
  if [ -n "$mounts" ]; then
    printf '%s\n' "ryoku-install: $resolved has mounted filesystems:" >&2
    printf '%s\n' "$mounts" >&2
    die "unmount them before installing"
  fi

  install_disk="$resolved"
}

choose_install_disk() {
  local live_disk path size model human choice
  local -a disks=()

  live_disk="$(detect_live_disk || true)"
  printf '\nInstallation disk\n'

  while IFS=$'\t' read -r path size model; do
    [ -n "$path" ] || continue
    [ "$path" = "$live_disk" ] && continue
    disks+=("$path")
    human="$(numfmt --to=iec --suffix=B "$size" 2>/dev/null || printf '%sB' "$size")"
    printf '  %d) %-16s %8s  %s\n' "${#disks[@]}" "$path" "$human" "${model:-Unknown disk}"
  done < <(
    lsblk -J -b -d -o PATH,SIZE,MODEL,TYPE,RO |
      jq -r '.blockdevices[] | select(.type == "disk" and (.ro == false or .ro == 0) and ((.size | tonumber) >= 17179869184)) | [.path, (.size|tostring), (.model // "")] | @tsv'
  )

  [ "${#disks[@]}" -gt 0 ] || die "no writable installation disks found"

  while true; do
    printf 'Choose disk: '
    read -r choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#disks[@]}" ]; then
      install_disk="${disks[$((choice - 1))]}"
      return 0
    fi
    printf 'Invalid disk selection.\n' >&2
  done
}

partition_by_number() {
  local disk="$1" number="$2" part attempt
  for ((attempt = 0; attempt < 50; attempt++)); do
    part="$(lsblk -nrpo NAME,PARTN "$disk" 2>/dev/null | awk -v n="$number" '$2 == n { print $1; exit }')"
    if [ -n "$part" ]; then
      printf '%s\n' "$part"
      return 0
    fi
    sleep 0.1
  done
  return 1
}

render_iso_target() {
  local outdir="$1" firmware="$2" password_hash="$3"
  local apps_block="" boot_block
  local nix_host nix_user nix_hash nix_ryoku nix_nixpkgs nix_disk
  local target_source_ref target_nixpkgs_ref

  target_source_ref="${RYOKU_INSTALL_TARGET_SOURCE:-$source_ref}"
  target_nixpkgs_ref="${RYOKU_INSTALL_NIXPKGS_SOURCE:-github:NixOS/nixpkgs/nixos-unstable}"

  nix_host="$(nix_quote "$target_hostname")"
  nix_user="$(nix_quote "$target_username")"
  nix_hash="$(nix_quote "$password_hash")"
  nix_ryoku="$(nix_quote "$target_source_ref")"
  nix_nixpkgs="$(nix_quote "$target_nixpkgs_ref")"
  nix_disk="$(nix_quote "$install_disk")"

  if [ "${#selected_apps[@]}" -gt 0 ]; then
    apps_block="$(printf '      "%s"\n' "${selected_apps[@]}")"
  fi

  if [ "$firmware" = "uefi" ]; then
    boot_block='  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;'
  else
    boot_block="  boot.loader.grub.enable = true;
  boot.loader.grub.devices = [ $nix_disk ];"
  fi

  mkdir -p "$outdir"

  cat > "$outdir/flake.nix" <<EOF_FLAKE
{
  description = "Ryoku on NixOS";

  inputs = {
    nixpkgs.url = $nix_nixpkgs;
    ryoku.url = $nix_ryoku;
  };

  outputs = { nixpkgs, ryoku, ... }: {
    nixosConfigurations.$nix_host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ryoku.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
EOF_FLAKE

  cat > "$outdir/configuration.nix" <<EOF_CONFIG
{ pkgs, ... }:

{
  imports = [ ./hardware-configuration.nix ];

$boot_block

  networking.hostName = $nix_host;
  networking.networkmanager.enable = true;

  nix.package = pkgs.nixVersions.latest;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  zramSwap.enable = true;

  users.users.$nix_user = {
    isNormalUser = true;
    extraGroups = [ "wheel" "networkmanager" "video" "audio" "input" ];
    hashedPassword = $nix_hash;
  };

  programs.ryoku = {
    enable = true;
    defaultCompositor = "$compositor";
    browser = "$browser";
    shell = "$shell_choice";
    optionalApps = [
$apps_block
    ];
  };

  system.stateVersion = "26.11";
}
EOF_CONFIG
}

install_iso() {
  local firmware password_hash typed
  local root_part boot_part
  local target_source_ref target_nixpkgs_ref

  if [ -z "$install_disk" ]; then
    if [ "$assume_yes" -eq 1 ]; then
      die "--iso --yes requires --disk DEVICE"
    fi
    choose_install_disk
  fi
  validate_install_disk "$install_disk"

  if [ -z "$filesystem" ]; then
    if [ "$assume_yes" -eq 1 ]; then
      filesystem="ext4"
    else
      printf '\nFilesystem\n  1) ext4   (default)\n  2) btrfs\nChoose [1]: '
      read -r answer
      case "$answer" in
        ""|1) filesystem="ext4" ;;
        2) filesystem="btrfs" ;;
        *) die "invalid filesystem selection" ;;
      esac
    fi
  fi
  case "$filesystem" in
    ext4|btrfs) ;;
    *) die "invalid filesystem: $filesystem" ;;
  esac

  if [ -z "$target_hostname" ]; then
    if [ "$assume_yes" -eq 1 ]; then
      target_hostname="ryoku"
    else
      printf '\nHostname [ryoku]: '
      read -r target_hostname
      target_hostname="${target_hostname:-ryoku}"
    fi
  fi
  valid_hostname "$target_hostname" || die "invalid hostname: $target_hostname"

  if [ -z "$target_username" ]; then
    if [ "$assume_yes" -eq 1 ]; then
      target_username="ryoku"
    else
      printf 'Username [ryoku]: '
      read -r target_username
      target_username="${target_username:-ryoku}"
    fi
  fi
  valid_username "$target_username" || die "invalid username: $target_username"

  case "$firmware_choice" in
    auto)
      if [ -d /sys/firmware/efi ]; then firmware="uefi"; else firmware="bios"; fi
      ;;
    uefi|bios) firmware="$firmware_choice" ;;
    *) die "invalid firmware mode: $firmware_choice" ;;
  esac

  if [ "$dry_run" -eq 1 ]; then
    password_hash="*"
  elif [ -n "${RYOKU_INSTALL_PASSWORD_HASH:-}" ]; then
    password_hash="$RYOKU_INSTALL_PASSWORD_HASH"
  elif [ "$assume_yes" -eq 1 ]; then
    die "unattended ISO installation requires RYOKU_INSTALL_PASSWORD_HASH"
  else
    local password_a password_b
    while true; do
      printf 'Password for %s: ' "$target_username"
      read -r -s password_a
      printf '\nConfirm password: '
      read -r -s password_b
      printf '\n'
      [ -n "$password_a" ] || { printf 'Password cannot be empty.\n' >&2; continue; }
      [ "$password_a" = "$password_b" ] || { printf 'Passwords do not match.\n' >&2; continue; }
      password_hash="$(printf '%s' "$password_a" | mkpasswd -m yescrypt -s)"
      unset password_a password_b
      break
    done
  fi

  target_source_ref="${RYOKU_INSTALL_TARGET_SOURCE:-$source_ref}"
  target_nixpkgs_ref="${RYOKU_INSTALL_NIXPKGS_SOURCE:-github:NixOS/nixpkgs/nixos-unstable}"

  iso_work="$(mktemp -d)"
  render_iso_target "$iso_work" "$firmware" "$password_hash"

  printf '\nRyoku NixOS full installation\n'
  printf '%s\n' '────────────────────────────────────────'
  printf 'Disk       %s\n' "$install_disk"
  printf 'Filesystem %s\n' "$filesystem"
  printf 'Firmware   %s\n' "$firmware"
  printf 'Hostname   %s\n' "$target_hostname"
  printf 'User       %s\n' "$target_username"
  printf 'WM         %s\n' "$compositor"
  printf 'Browser    %s\n' "$browser"
  printf 'Shell      %s\n' "$shell_choice"
  printf 'Ryoku      %s\n' "$target_source_ref"
  printf 'Nixpkgs    %s\n' "$target_nixpkgs_ref"

  if [ "$dry_run" -eq 1 ]; then
    printf '\nGenerated flake.nix:\n'
    cat "$iso_work/flake.nix"
    printf '\nGenerated configuration.nix:\n'
    cat "$iso_work/configuration.nix"
    rm -rf "$iso_work"
    printf '\nDry run complete. No disks or files were changed.\n'
    return 0
  fi

  if findmnt -rn "$target_root" >/dev/null 2>&1; then
    rm -rf "$iso_work"
    iso_work=""
    die "$target_root is already mounted; unmount it before installing"
  fi

  printf '\n%s\n' "WARNING: ALL DATA ON $install_disk WILL BE PERMANENTLY ERASED."
  if [ "$assume_yes" -eq 1 ]; then
    [ "$confirm_disk" = "$install_disk" ] || {
      rm -rf "$iso_work"
      iso_work=""
      die "--iso --yes requires --confirm-disk $install_disk"
    }
  else
    printf 'Type the exact disk path (%s) to continue: ' "$install_disk"
    read -r typed
    if [ "$typed" != "$install_disk" ]; then
      rm -rf "$iso_work"
      printf 'Cancelled. Nothing was changed.\n'
      return 0
    fi
  fi

  # shellcheck disable=SC2329 # invoked through the EXIT trap below
  iso_cleanup() {
    local status=$?
    trap - EXIT INT TERM
    if findmnt -rn "$target_root" >/dev/null 2>&1; then
      run_root umount -R "$target_root" >/dev/null 2>&1 || true
    fi
    if [ -n "${iso_work:-}" ]; then
      rm -rf "$iso_work"
    fi
    exit "$status"
  }
  trap iso_cleanup EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  echo "@@RYOKU_STEP partition"
  run_root wipefs -af "$install_disk"
  run_root parted -s "$install_disk" mklabel gpt

  if [ "$firmware" = "uefi" ]; then
    run_root parted -s -a optimal "$install_disk" mkpart ESP fat32 1MiB 1025MiB
    run_root parted -s "$install_disk" set 1 esp on
    run_root parted -s -a optimal "$install_disk" mkpart primary 1025MiB 100%
  else
    run_root parted -s -a optimal "$install_disk" mkpart BIOSBOOT 1MiB 3MiB
    run_root parted -s "$install_disk" set 1 bios_grub on
    run_root parted -s -a optimal "$install_disk" mkpart primary 3MiB 100%
  fi

  run_root partprobe "$install_disk"
  run_root udevadm settle

  boot_part="$(partition_by_number "$install_disk" 1 || true)"
  root_part="$(partition_by_number "$install_disk" 2 || true)"
  [ -n "$root_part" ] || die "root partition did not appear after partitioning"
  [ -n "$boot_part" ] || die "boot partition did not appear after partitioning"

  echo "@@RYOKU_STEP filesystems"
  if [ "$filesystem" = "ext4" ]; then
    run_root mkfs.ext4 -F -L nixos "$root_part"
  else
    run_root mkfs.btrfs -f -L nixos "$root_part"
  fi

  if [ "$firmware" = "uefi" ]; then
    run_root mkfs.fat -F 32 -n EFI "$boot_part"
  fi

  run_root mkdir -p "$target_root"
  run_root mount "$root_part" "$target_root"
  if [ "$firmware" = "uefi" ]; then
    run_root mkdir -p "$target_root/boot"
    run_root mount "$boot_part" "$target_root/boot"
  fi

  echo "@@RYOKU_STEP configuration"
  run_root nixos-generate-config --root "$target_root"
  run_root install -m 0644 "$iso_work/flake.nix" "$target_root/etc/nixos/flake.nix"
  run_root install -m 0644 "$iso_work/configuration.nix" "$target_root/etc/nixos/configuration.nix"

  if [ -e /etc/ryoku/source ]; then
    run_root mkdir -p "$target_root/etc/ryoku/source"
    # Preserve source-tree symlinks exactly. Dereferencing them breaks on
    # intentionally relative compatibility links in the repository.
    run_root cp -a /etc/ryoku/source/. "$target_root/etc/ryoku/source/"
  fi

  echo "@@RYOKU_STEP lock"
  run_root nix flake lock "path:$target_root/etc/nixos"

  echo "@@RYOKU_STEP install"
  run_root nixos-install \
    --root "$target_root" \
    --flake "path:$target_root/etc/nixos#$target_hostname" \
    --no-root-passwd \
    "${bootstrap_cache[@]}"

  echo "@@RYOKU_STEP finalize"
  run_root sync
  run_root umount -R "$target_root"

  trap - EXIT INT TERM
  rm -rf "$iso_work"
  iso_work=""

  echo "@@RYOKU_DONE"
  printf '\nRyoku installation complete.\n'
  printf 'Remove the installation media and reboot into %s.\n' "$target_hostname"
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
  --iso                 Install a fresh NixOS + Ryoku system to a disk
  --disk DEVICE         Whole target disk for --iso
  --filesystem TYPE     ext4 or btrfs (default: ext4)
  --hostname NAME       Target hostname for --iso (default: ryoku)
  --username NAME       Target user for --iso (default: ryoku)
  --firmware MODE       auto, uefi, or bios (default: auto)
  --confirm-disk DEVICE Required with --iso --yes; must exactly match --disk
  --dry-run             Show proposed changes without writing them
  -y, --yes             Skip non-destructive prompts; disk confirmation still required
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
    --iso)
      iso_mode=1
      shift
      ;;
    --disk)
      [ "$#" -ge 2 ] || die "--disk requires a value"
      install_disk="$2"
      shift 2
      ;;
    --filesystem)
      [ "$#" -ge 2 ] || die "--filesystem requires a value"
      filesystem="$2"
      shift 2
      ;;
    --hostname)
      [ "$#" -ge 2 ] || die "--hostname requires a value"
      target_hostname="$2"
      shift 2
      ;;
    --username)
      [ "$#" -ge 2 ] || die "--username requires a value"
      target_username="$2"
      shift 2
      ;;
    --firmware)
      [ "$#" -ge 2 ] || die "--firmware requires a value"
      firmware_choice="$2"
      shift 2
      ;;
    --confirm-disk)
      [ "$#" -ge 2 ] || die "--confirm-disk requires a value"
      confirm_disk="$2"
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
  for app in "${raw_apps[@]}"; do
    app="${app//[[:space:]]/}"
    [ -n "$app" ] || continue
    case "$app" in
      prompt|bash-edit|fastfetch|yazi|cli-tools|git-tools|pavucontrol|songrec|openrgb|upscale|localsend|gamescope|gamemode|mangohud|vm|docker|flatpak|go|pytools|mise) ;;
      *) echo "ryoku-install: invalid optional app id: $app" >&2; exit 2 ;;
    esac
    if [ -z "${seen_apps[$app]+x}" ]; then
      selected_apps+=("$app")
      seen_apps[$app]=1
    fi
  done
fi

if [ "$iso_mode" -eq 1 ]; then
  install_iso
  exit $?
fi

case "$flake_arg" in
  *#*)
    flake_root="${flake_arg%%#*}"
    host="${flake_arg#*#}"
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

  [ "${#hosts[@]}" -gt 0 ] || {
    echo "ryoku-install: no nixosConfigurations found" >&2
    exit 1
  }

  for candidate in "${hosts[@]}"; do
    if [ "$candidate" = "$current_host" ]; then
      host="$candidate"
      break
    fi
  done

  if [ -z "$host" ] && [ "${#hosts[@]}" -eq 1 ]; then
    host="${hosts[0]}"
  fi

  if [ -z "$host" ]; then
    echo "ryoku-install: multiple NixOS hosts found:" >&2
    printf '  %s\n' "${hosts[@]}" >&2
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
if [ "${#selected_apps[@]}" -gt 0 ]; then
  apps_block="$(printf '      "%s"\n' "${selected_apps[@]}")"
fi

cat > "$work_module" <<EOF
# Managed by ryoku-install.
{ ... }:

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
}
EOF

python3 @INSTALL_EDIT@ "$work_flake" "$host" "$source_ref"

printf '\nRyoku NixOS installer\n'
printf '%s\n' '────────────────────────────────────────'
printf 'Flake   %s\n' "$flake_root"
printf 'Host    %s\n' "$host"
printf 'Source  %s\n' "$source_ref"
printf 'WM      %s\n' "$compositor"
printf 'Browser %s\n' "$browser"
printf 'Shell   %s\n' "$shell_choice"
if [ "${#selected_apps[@]}" -gt 0 ]; then
  printf 'Apps    %s\n' "$(IFS=,; echo "${selected_apps[*]}")"
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
  "${bootstrap_cache[@]}"
then
  rollback
  echo "ryoku-install: build failed; files restored" >&2
  exit 1
fi

echo "@@RYOKU_STEP switch"
printf '\nSwitching generation...\n'

if ! run_root "$nixos_rebuild" switch \
  --flake "path:$flake_root#$host" \
  "${bootstrap_cache[@]}"
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
