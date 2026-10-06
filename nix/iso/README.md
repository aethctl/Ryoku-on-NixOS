# Ryoku on NixOS ISO

The Ryoku ISO is a bootable NixOS installer image that carries the exact Ryoku
source revision used to build it and launches `ryoku-install --iso` on the first
local TTY1 login.

## Live environment

The live image provides:

- current Nix with flakes enabled;
- NetworkManager and SSH for recovery/testing;
- the guided Ryoku terminal installer;
- the exact Ryoku source tree embedded at `/etc/ryoku/source`;
- the standard NixOS installation/recovery toolbox.

Closing the installer returns to the live shell. Run `ryoku-install --iso` to
open it again.

## Guided installation

The installer currently supports a safe whole-disk installation flow. It asks
for or determines:

- Ryoku compositor: Hyprland, niri, or MangoWM;
- browser and shell;
- optional Ryoku apps/tools;
- target disk and ext4/btrfs filesystem;
- hostname, username, password;
- timezone, locale, and keyboard layout;
- UEFI/BIOS mode;
- GPU vendors, detected automatically from PCI devices with NVIDIA/AMD/Intel
  and hybrid combinations supported.

Before partitioning, the user must type the exact target disk path. Unattended
installs require both `--disk` and a matching `--confirm-disk`. The installer
refuses the disk backing the live medium and writable targets smaller than
16 GiB. The live image also enables compressed zram and automatically limits
Nix build parallelism on lower-memory machines; 8 GiB RAM is the tested minimum
for the default full desktop installation.

**Guided dual boot / preserve-existing-partitions is not implemented yet.** The
selected installation disk is erased. Advanced users can leave the installer
and use the normal NixOS live shell for manual partitioning.

## Installed `/etc/nixos`

The canonical installed config comes from [`../iso-configs`](../iso-configs):

```text
/etc/nixos/
├── flake.nix
├── configuration.nix
├── hardware-configuration.nix
├── install-values.nix
├── pkgs.nix
├── ryoku.nix
├── hardware/
│   └── gpu/
│       ├── common.nix
│       ├── nvidia.nix
│       ├── amd.nix
│       └── intel.nix
└── modules/
    └── module-example.nix
```

Only `install-values.nix` and `hardware-configuration.nix` are machine-specific.
The other files stay clean and user-editable. Release ISOs keep the normal
`main` / `nixos-unstable` input URLs while the generated `flake.lock` pins both
Ryoku and Nixpkgs to the exact revisions tested by the image. A later
`nix flake update` therefore advances normally.

Rebuild an installed system with:

```bash
sudo nixos-rebuild switch --flake /etc/nixos#ryoku
```

## Build

From the repository root:

```bash
nix build .#ryoku-iso
```

The resulting ISO is under `result/iso/`.
