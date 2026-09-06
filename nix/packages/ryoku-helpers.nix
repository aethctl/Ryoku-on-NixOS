{ pkgs, src }:

let
  # Depth uses the rembg Python API directly. Keep the runtime inside Nix
  # instead of creating a mutable pip environment on NixOS.
  depthPython = pkgs.python3.withPackages (ps: [
    ps.rembg
  ]);

  # Parallax uses the same foreground-removal stack as Depth plus a
  # deterministic scipy/Pillow inpaint pass. Keep the Python runtime
  # declarative on NixOS; only downloaded model data belongs in user state.
  parallaxPython = pkgs.python3.withPackages (ps: [
    ps.rembg
    ps.numpy
    ps.pillow
    ps.scipy
  ]);
in
pkgs.stdenvNoCC.mkDerivation {
  pname = "ryoku-helpers";
  version = "unstable";

  inherit src;

  dontBuild = true;

  installPhase = ''
    runHook preInstall

    mkdir -p "$out/bin" "$out/libexec"

    install_helpers() {
      for helper in "$@"; do
        [ -f "$helper" ] || continue

        case "$helper" in
          *.service|*.rules|*.conf)
            continue
            ;;
        esac

        install -Dm755 \
          "$helper" \
          "$out/bin/$(basename "$helper")"
      done
    }

    install_helpers \
      system/hardware/*/ryoku-* \
      system/containers/ryoku-*

    # These are useful desktop helpers. Package-management mutations
    # remain a separate NixOS-porting concern.
    install_helpers \
      system/extras/ryoku-cmd-present

    # Depth foreground cutout helper.
    #
    # Upstream provisions rembg into a user venv. NixOS instead supplies
    # rembg declaratively and keeps only downloaded model data in user state.
    install -Dm755 \
      ryoku/shell/scripts/ryoku-depth \
      "$out/libexec/ryoku-depth"

    cat > "$out/bin/ryoku-depth" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

real="@REAL@"
python="@PYTHON@"

export PATH="@DEPTH_BIN@:$PATH"

if [[ ''${1:-} != install ]]; then
  exec "$real" "$@"
fi

shift

state="''${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/depth"
models="$state/models"

export REMBG_HOME="$models"
export U2NET_HOME="$models"

mkdir -p "$models"

if (( $# == 0 )); then
  set -- u2netp
fi

for model in "$@"; do
  case "$model" in
    u2netp|birefnet-general-lite)
      ;;
    *)
      printf 'ryoku-depth: unsupported model: %s\n' "$model" >&2
      exit 2
      ;;
  esac

  printf 'Downloading model %s...\n' "$model"

  "$python" - "$model" <<'PY'
import sys

import onnxruntime as ort
from rembg import new_session

model = sys.argv[1]

available = set(ort.get_available_providers())
providers = [
    provider
    for provider in ("CUDAExecutionProvider", "CPUExecutionProvider")
    if provider in available
]

try:
    if providers:
        new_session(model, providers=providers)
    else:
        new_session(model)
except TypeError:
    new_session(model)
PY
done

exec "$real" check
SH

    substituteInPlace "$out/bin/ryoku-depth" \
      --replace-fail '@REAL@' "$out/libexec/ryoku-depth" \
      --replace-fail '@PYTHON@' "${depthPython}/bin/python3" \
      --replace-fail '@DEPTH_BIN@' "${depthPython}/bin"

    chmod 755 "$out/bin/ryoku-depth"

    # Parallax wallpaper cutout/inpaint engine.
    #
    # Upstream creates a mutable pip venv. NixOS provides the complete Python
    # runtime declaratively instead, while REMBG_HOME remains writable so model
    # files can be downloaded to user state.
    install -Dm755 \
      ryoku/shell/scripts/ryoku-parallax-engine \
      "$out/libexec/ryoku-parallax-engine"

    cat > "$out/bin/ryoku-parallax-engine" <<'SH'
#!/usr/bin/env bash
set -euo pipefail

real="@REAL@"
python="@PYTHON@"

export PATH="@PARALLAX_BIN@:@FINDUTILS_BIN@:@COREUTILS_BIN@:$PATH"

state="''${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/parallax"
models="$state/models"

export REMBG_HOME="$models"
export U2NET_HOME="$models"

mkdir -p "$models"

# On Arch, `install` provisions a pip venv. The Nix package already contains
# rembg, numpy, Pillow and scipy, so install means only fetching model data.
if [[ ''${1:-} == install ]]; then
  shift

  if (( $# == 0 )); then
    set -- u2netp
  fi

  for model in "$@"; do
    case "$model" in
      u2netp|birefnet-general-lite)
        ;;
      *)
        printf 'ryoku-parallax-engine: unsupported model: %s\n' "$model" >&2
        exit 2
        ;;
    esac

    printf 'Downloading model %s...\n' "$model"

    "$python" - "$model" <<'PYMODEL'
import sys
from rembg import new_session

model = sys.argv[1]

try:
    new_session(
        model,
        providers=[
            "CUDAExecutionProvider",
            "CPUExecutionProvider",
        ],
    )
except Exception:
    new_session(model)
PYMODEL
  done

  exec "$real" check
fi

exec "$real" "$@"
SH

    substituteInPlace "$out/bin/ryoku-parallax-engine" \
      --replace-fail '@REAL@' "$out/libexec/ryoku-parallax-engine" \
      --replace-fail '@PYTHON@' "${parallaxPython}/bin/python3" \
      --replace-fail '@PARALLAX_BIN@' "${parallaxPython}/bin" \
      --replace-fail '@FINDUTILS_BIN@' "${pkgs.findutils}/bin" \
      --replace-fail '@COREUTILS_BIN@' "${pkgs.coreutils}/bin"

    chmod 755 "$out/bin/ryoku-parallax-engine"

    # Settings -> language integration.
    install -Dm755 \
      ryoku/ui/i18n-sync.py \
      "$out/bin/ryoku-i18n"

    runHook postInstall
  '';

  meta = {
    description = "Runtime helper commands used by the Ryoku desktop";
    homepage = "https://github.com/neur0map/ryoku-arch";
    license = pkgs.lib.licenses.gpl3Only;
    platforms = [ "x86_64-linux" ];
  };
}
