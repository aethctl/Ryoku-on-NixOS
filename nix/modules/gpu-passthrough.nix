{ self }:

{ config, lib, pkgs, ... }:

let
  cfg = config.programs.ryoku.gpuPassthrough;

  system = pkgs.stdenv.hostPlatform.system;
  ryokuPkgs = self.packages.${system};

  ryokuBundle = ryokuPkgs.ryoku-bundle;
  ryokuHub = ryokuPkgs.ryoku-hub;

  # nixpkgs' virtio-win package exposes the Windows driver tree rather
  # than the ISO expected by upstream RyoVM. Build that ISO reproducibly
  # from the pinned package contents instead of downloading one at runtime.
  virtioWinIso = pkgs.runCommand
    "ryoku-virtio-win-${pkgs.virtio-win.version}.iso"
    {
      nativeBuildInputs = [
        pkgs.xorriso
      ];
    }
    ''
      xorriso \
        -as mkisofs \
        -quiet \
        -J \
        -R \
        -iso-level 4 \
        -V RYOKU_VIRTIO \
        -o "$out" \
        ${pkgs.virtio-win}
    '';

  # NixOS owns the libvirt hook declaratively. The hook itself performs
  # only the transient bind/unbind operation required when a passthrough
  # VM starts or stops; it never rewrites persistent host configuration.
  qemuHook = pkgs.writeShellScript "ryoku-libvirt-qemu-hook" ''
    export PATH="${
      lib.makeBinPath [
        pkgs.coreutils
        pkgs.kmod
        pkgs.pciutils
        pkgs.util-linux
        ryokuBundle
      ]
    }"

    export RYOKU_GPU_BIN="${ryokuBundle}/bin/ryoku-gpu"

    guest="''${1:-}"
    op="''${2:-}"

    case "$op" in
      prepare)
        exec ${ryokuHub}/bin/ryoku-hub \
          gpu hook prepare "$guest"
        ;;

      release|stopped)
        exec ${ryokuHub}/bin/ryoku-hub \
          gpu hook release "$guest"
        ;;

      *)
        exit 0
        ;;
    esac
  '';

in
{
  options.programs.ryoku.gpuPassthrough = {
    enable = lib.mkEnableOption ''
      declarative Ryoport Looking Glass GPU passthrough host support
    '';

    users = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];

      description = ''
        Existing NixOS users allowed to manage Ryoku passthrough VMs.

        These users are added declaratively to the kvm and libvirtd
        groups. No accounts are created by this option.
      '';
    };

    kvmfrSizeMB = lib.mkOption {
      type = lib.types.int;
      default = 128;

      description = ''
        Static shared-memory size, in MiB, allocated by kvmfr for
        Looking Glass.

        Ryoku upstream uses 128 MiB by default.
      '';
    };
  };

  config = lib.mkIf (
    config.programs.ryoku.enable
    && cfg.enable
  ) {
    assertions = [
      {
        assertion = cfg.users != [ ];

        message = ''
          programs.ryoku.gpuPassthrough.enable requires at least one
          user in programs.ryoku.gpuPassthrough.users.
        '';
      }

      {
        assertion = cfg.kvmfrSizeMB > 0;

        message = ''
          programs.ryoku.gpuPassthrough.kvmfrSizeMB must be greater
          than zero.
        '';
      }
    ];

    # ───────────────────────────────────────────────────────────
    # Looking Glass shared memory
    # ───────────────────────────────────────────────────────────

    boot.extraModulePackages = [
      config.boot.kernelPackages.kvmfr
    ];

    boot.kernelModules = [
      "kvmfr"
    ];

    boot.extraModprobeConfig = ''
      options kvmfr static_size_mb=${toString cfg.kvmfrSizeMB}
    '';

    services.udev.extraRules = ''
      SUBSYSTEM=="kvmfr", KERNEL=="kvmfr0", OWNER="root", GROUP="kvm", MODE="0660"
    '';

    # ───────────────────────────────────────────────────────────
    # Libvirt / QEMU
    # ───────────────────────────────────────────────────────────

    virtualisation.libvirtd = {
      enable = true;

      qemu.swtpm.enable = true;

      hooks.qemu = {
        "50-ryoku-gpu" = qemuHook;
      };
    };

    virtualisation.spiceUSBRedirection.enable = true;

    # NixOS calls the management group "libvirtd", not Arch's
    # "libvirt". Group membership is declarative and reversible.
    users.groups.kvm.members = cfg.users;
    users.groups.libvirtd.members = cfg.users;

    environment.systemPackages = [
      pkgs.looking-glass-client
    ];

    # Declarative capability markers consumed by Ryoku's runtime.
    #
    # Using /etc rather than relying solely on a session environment
    # means terminal invocations, systemd user services and Hub all see
    # the same generation-owned state.
    environment.etc."ryoku/gpu-passthrough-ready".text = ''
      1
    '';

    environment.etc."ryoku/virtio-win-iso".text = ''
      ${virtioWinIso}
    '';
  };
}
