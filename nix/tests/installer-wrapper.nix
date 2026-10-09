{ pkgs, installer }:

pkgs.runCommand "ryoku-installer-wrapper-check"
  {
    nativeBuildInputs = [
      pkgs.bash
      pkgs.coreutils
      pkgs.gnugrep
    ];
  }
  ''
    set -euo pipefail

    fixture="$TMPDIR/nixos"
    mkdir -p "$fixture"

    cat > "$fixture/flake.nix" <<'FLAKE'
    {
      inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

      outputs = { self, nixpkgs, ... }: {
        nixosConfigurations.host = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [ ./configuration.nix ];
        };
      };
    }
FLAKE

    cat > "$fixture/configuration.nix" <<'NIX'
    { ... }: {
      system.stateVersion = "26.05";
    }
NIX

    output="$(${installer}/bin/ryoku-install \
      --cli \
      --flake "$fixture#host" \
      --source github:aethctl/Ryoku-on-NixOS/main \
      --compositor niri \
      --browser firefox \
      --shell zsh \
      --apps prompt,flatpak,go \
      --dry-run \
      -y)"

    printf '%s\n' "$output" | grep -Fq 'WM      niri'
    printf '%s\n' "$output" | grep -Fq 'Browser firefox'
    printf '%s\n' "$output" | grep -Fq 'Shell   zsh'
    printf '%s\n' "$output" | grep -Fq 'Apps    prompt,flatpak,go'
    printf '%s\n' "$output" | grep -Fq 'defaultCompositor = "niri";'
    printf '%s\n' "$output" | grep -Fq 'browser = "firefox";'
    printf '%s\n' "$output" | grep -Fq 'shell = "zsh";'
    printf '%s\n' "$output" | grep -Fq '"flatpak"'
    printf '%s\n' "$output" | grep -Fq 'Dry run complete. No files were changed.'
    printf '%s\n' "$output" | grep -Fq 'hardware.graphics = {'

    gpu_case() {
      vendors="$1"
      model="$2"
      RYOKU_INSTALL_GPU_VENDORS="$vendors" \
      RYOKU_INSTALL_NVIDIA_MODEL="$model" \
        ${installer}/bin/ryoku-install \
          --cli \
          --flake "$fixture#host" \
          --source github:aethctl/Ryoku-on-NixOS/main \
          --compositor niri \
          --browser firefox \
          --shell zsh \
          --apps none \
          --dry-run \
          -y
    }

    intel_output="$(gpu_case intel "")"
    printf '%s\n' "$intel_output" | grep -Fq '"i915"'
    printf '%s\n' "$intel_output" | grep -Fq 'pkgs.intel-media-driver'

    amd_output="$(gpu_case amd "")"
    printf '%s\n' "$amd_output" | grep -Fq '"amdgpu"'

    gtx700_output="$(gpu_case nvidia 'NVIDIA Corporation GK104 [GeForce GTX 770]')"
    printf '%s\n' "$gtx700_output" | grep -Fq 'nvidiaPackages.legacy_470'

    gtx10_output="$(gpu_case nvidia 'NVIDIA Corporation GP104 [GeForce GTX 1080]')"
    printf '%s\n' "$gtx10_output" | grep -Fq 'nvidiaPackages.legacy_580'

    modern_output="$(gpu_case nvidia 'NVIDIA Corporation GB203 [GeForce RTX 5080]')"
    printf '%s\n' "$modern_output" | grep -Fq 'nvidiaPackages.stable'

    hybrid_output="$(gpu_case intel,nvidia 'NVIDIA Corporation GP106 [GeForce GTX 1060]')"
    printf '%s\n' "$hybrid_output" | grep -Fq '"i915"'
    printf '%s\n' "$hybrid_output" | grep -Fq 'nvidiaPackages.legacy_580'

    dual_mesa_output="$(gpu_case intel,amd "")"
    printf '%s\n' "$dual_mesa_output" | grep -Fq 'lib.mkAfter [ "i915" "amdgpu" ]'

    test ! -e "$fixture/ryoku.nix"
    grep -Fq './configuration.nix' "$fixture/flake.nix"
    ! grep -Fq 'ryoku.nixosModules.default' "$fixture/flake.nix"

    touch "$out"
  ''
