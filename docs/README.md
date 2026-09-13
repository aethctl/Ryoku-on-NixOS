# Ryoku documentation

This repository contains two kinds of documentation:

1. documentation for the **shared Ryoku desktop**, which applies to both Arch and
   NixOS;
2. documentation inherited from the **Arch distribution**, which is useful as an
   upstream reference but does not describe NixOS system management.

If you are using the NixOS port, start with [`nixos.md`](nixos.md).

## Start here

| Document | Scope | Purpose |
| --- | --- | --- |
| [`nixos.md`](nixos.md) | NixOS | Installation, updates, module ownership, materialization and Nix-specific behavior |
| [`structure.md`](structure.md) | NixOS port | How this repository is organized |
| [`store.md`](store.md) | Shared desktop | Ryostore architecture and product model |
| [`plugins.md`](plugins.md) | Shared desktop | Plugin architecture |
| [`barstyles.md`](barstyles.md) | Shared desktop | External bar-style contract and development |
| [`launcher.md`](launcher.md) | Shared desktop | Launcher behavior and providers |
| [`frame.md`](frame.md) | Shared desktop | Ryoku frame architecture |
| [`depth.md`](depth.md) | Shared desktop | Depth and surface conventions |
| [`conventions.md`](conventions.md) | Shared desktop | Project conventions |

## Shared desktop documentation

These describe the desktop itself and generally apply to both Ryoku on Arch and
Ryoku on NixOS:

- [`bar.md`](bar.md)
- [`barstyles.md`](barstyles.md)
- [`config-import.md`](config-import.md)
- [`conventions.md`](conventions.md)
- [`depth.md`](depth.md)
- [`frame.md`](frame.md)
- [`hyprland-plugins.md`](hyprland-plugins.md)
- [`launcher.md`](launcher.md)
- [`plugins.md`](plugins.md)
- [`store.md`](store.md)
- [`rashin.md`](rashin.md)
- [`rashin-terminal.md`](rashin-terminal.md)

A shared feature may still need different packaging or service integration on
NixOS. When that matters, the NixOS implementation lives under `nix/`.

## NixOS documentation

- [`nixos.md`](nixos.md): install, module behavior, updates, materialization,
  package reporting and development entry points
- [`structure.md`](structure.md): the NixOS port's repository layout

The public Nix entry point is the repository root `flake.nix`.

## Upstream Arch reference

The following pages came from Ryoku's Arch distribution and describe Arch system
management. They remain useful when understanding upstream behavior, but commands
involving Pacman, the AUR, Limine, mkinitcpio, Snapper or Arch installation should
not be followed as NixOS instructions:

- [`cli.md`](cli.md)
- [`development.md`](development.md)
- [`installation-hardware.md`](installation-hardware.md)
- [`kernels.md`](kernels.md)
- [`preinstalled.md`](preinstalled.md)
- [`ryoku.md`](ryoku.md)
- [`updates.md`](updates.md)

For the NixOS equivalent of installation, updating and rollback behavior, use
[`nixos.md`](nixos.md).

## Source-of-truth rule

The shared desktop should not be documented twice just because it runs on two
distributions.

When behavior is identical, keep one shared description. When the host operating
system changes the implementation, document the difference in the NixOS guide or
next to the Nix-specific code.

That keeps the port close to upstream without pretending that NixOS is Arch.
