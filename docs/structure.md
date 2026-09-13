# Repository structure

Ryoku on NixOS keeps the shared Ryoku desktop and the NixOS implementation in the
same tree.

The important split is simple:

```text
ryoku/        shared Ryoku desktop and applications
nix/          NixOS packaging, module, installer and integration
flake.nix     public Nix entry point
docs/         project documentation
tests/        validation and integration tests
website/      Ryoku on NixOS website
```

The desktop remains Ryoku. The `nix/` tree is the adapter that makes it behave
like a native NixOS system.

## `ryoku/`: shared desktop

`ryoku/` contains the user-facing Ryoku desktop shared with upstream.

Major areas include:

- `apps/`: Ryoku applications and application-specific configuration
- `cli/`: the `ryoku` command
- `hub/`: Ryoku Hub backend and settings integration
- `hyprland/`: Hyprland configuration and Ryoku compositor integration
- `lockscreen/`: lockscreen and greeter assets
- `shell/`: the Quickshell desktop, modules, services and UI surfaces

NixOS should preserve this shared desktop wherever practical instead of forking
the UI merely because the package manager is different.

## `nix/`: NixOS implementation

`nix/` contains the Nix-native implementation of Ryoku.

```text
nix/
├── apps/
├── modules/
└── packages/
```

### `nix/apps/`

User-facing Nix applications and integration helpers.

Important entries include:

- the NixOS installer exposed as `.#install`
- the development runner exposed as `.#ryoku-dev`
- the materializer exposed as `.#ryoku-materialize`

The installer integrates Ryoku into an existing flake-based NixOS system rather
than installing or repartitioning NixOS itself.

### `nix/modules/`

The NixOS module is the declarative machine-facing integration layer.

It enables the Ryoku package set, compositor/session integration, services,
hardware-facing helpers, fonts, portals and materialization required by the
desktop.

The public module is exported as:

```nix
ryoku.nixosModules.default
```

and is enabled with:

```nix
programs.ryoku.enable = true;
```

### `nix/packages/`

One Nix expression per packaged Ryoku component or integration layer.

The package set includes the shell, Hub, Ryostore, Ryotunes, Ryogami, Ryo
Motion, QML modules, helper tools, desktop data, Hyprland components and the
combined Ryoku bundle.

The exact public package outputs are defined in `flake.nix`.

## `flake.nix`: public Nix interface

The root flake is the supported Nix entry point for the port.

It exposes:

- `nixosModules.default`
- `packages.x86_64-linux.*`
- `apps.x86_64-linux.install`
- `apps.x86_64-linux.ryoku-dev`
- `apps.x86_64-linux.ryoku-materialize`
- `checks.x86_64-linux.*`
- the development shell

The flake intentionally keeps ABI-sensitive Hyprland components on Ryoku's
locked package set so the compositor, portal and plugins stay compatible.

## `docs/`: documentation

Start with [`docs/README.md`](README.md).

The documentation tree contains both shared desktop documentation and inherited
Arch reference material. Arch-specific pages are retained because they are useful
for upstream parity work, but they are not NixOS system-management instructions.

The NixOS-specific guide is [`nixos.md`](nixos.md).

## `tests/`: validation

`tests/` contains focused checks for Ryoku behavior and integration.

The Nix flake also exposes buildable checks through:

```bash
nix flake check
```

For iterative work, prefer the narrowest relevant package/check before running a
full validation pass.

## `website/`: public site

The website contains the NixOS port's public landing, install and patch-note
pages.

Installation commands shown there should match the canonical installer entry
point:

```bash
nix run github:aethctl/Ryoku-on-NixOS/main#install
```

## Inherited Arch directories

This repository tracks upstream Ryoku closely, so some top-level trees remain
Arch-oriented, including installation, release and system-management machinery.

They are kept for upstream parity and source history. They are **not** the NixOS
implementation.

On NixOS:

- packages belong under `nix/packages/`
- system integration belongs in `nix/modules/`
- user-facing Nix entry points belong in `nix/apps/`
- the root `flake.nix` exposes the supported public interface

Do not duplicate an existing shared desktop component into `nix/` unless the
host platform genuinely requires a different implementation.

## Practical rule

When deciding where a change belongs:

```text
Does it change the Ryoku desktop itself?
    yes -> ryoku/

Does it only make that desktop work correctly on NixOS?
    yes -> nix/

Is it documentation?
    yes -> docs/

Is it a validation of existing behavior?
    yes -> tests/
```

The goal is to keep platform adaptation at the boundary while the desktop itself
stays shared.
