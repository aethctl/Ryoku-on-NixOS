# Ryoku on NixOS ISO

This directory owns the bootable Ryoku live/install image.

## Structure

- `base.nix` is the stable boot/install foundation. It owns ISO boot support,
  current Nix, flakes, networking, installation tools, and the embedded Ryoku
  source tree.
- `profile.nix` is the maintainer-facing live-session layer. Put the graphical
  session, installer UI/autostart, branding, wallpaper, and live-only hardware
  conveniences here.
- `default.nix` composes the two layers and exposes the existing `ryoku-install`
  helper for development and recovery.

Keep target-system installation logic out of `base.nix`.

## Building

From the repository root:

```bash
nix build .#ryoku-iso
```

The ISO is exposed as `packages.x86_64-linux.ryoku-iso` and the underlying
NixOS configuration as `nixosConfigurations.ryoku-iso`.

## Installer contract

The live image and the installed system are separate systems.

A fresh-disk installer should:

1. partition and format the selected target disk;
2. mount the target filesystem tree at `/mnt`;
3. generate or write the target hardware and NixOS flake configuration;
4. enable the Ryoku NixOS module in that target configuration;
5. run `nixos-install --flake /mnt/etc/nixos#<host>`;
6. never use `nixos-rebuild switch` as the final bare-metal installation step.

The existing `ryoku-install` command is intentionally retained for installing
Ryoku onto an already-installed flake-based NixOS system. It is not the
fresh-disk installer.

## Live image guarantees

The live environment:

- follows this flake's locked `nixos-unstable` input;
- uses `pkgs.nixVersions.latest`;
- enables `nix-command` and `flakes`;
- includes NetworkManager, Git, disk/install tools, and OpenSSH;
- embeds the exact Ryoku source used to build the ISO at `/etc/ryoku/source`;
- registers that embedded source as the `ryoku` flake registry entry;
- exports `RYOKU_INSTALL_SOURCE=path:/etc/ryoku/source` for live/recovery use.

Ryoku-owned packages continue to use the independently pinned
`ryokuPackagesNixpkgs` input so updating the live ISO base does not silently
change Ryoku's tested package universe.
