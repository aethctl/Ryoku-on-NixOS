# Ryoku on NixOS ISO

This directory owns the bootable Ryoku live/install image.

## Structure

- `base.nix` is the stable boot/install foundation. It owns ISO boot support,
  current Nix, flakes, networking, installation tools, and the embedded Ryoku
  source tree.
- `profile.nix` owns live-session behavior. The console ISO currently launches
  the guided terminal installer once on TTY1; a maintainer can layer graphical
  live-session branding or a terminal launcher here later.
- `default.nix` composes the live image and exposes the same `ryoku-install`
  package used on an existing NixOS host.

Keep target-system installation logic in the installer backend, not in
`base.nix`. That keeps one installation implementation regardless of how the
live session is presented.

## Building

From the repository root:

```bash
nix build .#ryoku-iso
```

The ISO is exposed as `packages.x86_64-linux.ryoku-iso` and the underlying
NixOS configuration as `nixosConfigurations.ryoku-iso`.

## One installer, two modes

`ryoku-install` is the single guided terminal installer.

On an already-installed flake-based NixOS system, run it normally. The backend
edits the selected host configuration transactionally, builds the new
generation, and switches only after validation.

On the live ISO, TTY1 launches:

```bash
ryoku-install --iso
```

ISO mode performs a complete fresh installation:

1. choose a whole target disk;
2. choose ext4 or Btrfs;
3. set hostname, username and password;
4. require exact target-disk confirmation before destructive work;
5. create a GPT layout appropriate for UEFI or BIOS;
6. format and mount the target under `/mnt`;
7. generate hardware configuration;
8. write a flake-based NixOS + Ryoku target configuration;
9. lock the target inputs;
10. run `nixos-install --flake ...`, never `nixos-rebuild switch` against the
    disposable live system;
11. unmount the target and ask the user to remove the installation media.

Quitting the installer returns to the normal live shell. Run
`ryoku-install --iso` to reopen it.

## Disk-safety contract

The ISO installer intentionally refuses several convenient-but-dangerous
shortcuts:

- only whole `/dev` disks are accepted;
- the disk backing the live installer is excluded;
- disks with mounted filesystems are refused;
- target disks smaller than 16 GiB are refused;
- interactive installs require typing the exact disk path before erasure;
- `--iso --yes` still requires a matching `--confirm-disk DEVICE` token;
- `--dry-run` never partitions, formats, mounts or invokes `nixos-install`.

Partition-table destruction cannot be rolled back after confirmation. Failures
after mounting are cleaned up by unmounting the target tree.

## Live image guarantees

The live environment:

- follows this flake's locked `nixos-unstable` input;
- uses `pkgs.nixVersions.latest`;
- enables `nix-command` and `flakes`;
- includes NetworkManager, Git, disk/install tools, and OpenSSH;
- embeds the exact Ryoku source used to build the ISO at `/etc/ryoku/source`;
- registers that embedded source as the `ryoku` flake registry entry;
- exports `RYOKU_INSTALL_SOURCE=path:/etc/ryoku/source` for live/recovery use;
- on clean builds, gives the target installer exact Ryoku and nixpkgs revisions;
- on dirty developer builds, deliberately falls back to the embedded Ryoku
  source rather than claiming an older Git revision represents uncommitted
  code.

Ryoku-owned packages continue to use the independently pinned
`ryokuPackagesNixpkgs` input so updating the live ISO base does not silently
change Ryoku's tested package universe.
