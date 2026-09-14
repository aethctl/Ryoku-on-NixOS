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

- `apps/` one directory per application, holding that app's native config only:
  `kitty/`, `fish/`, `fastfetch/` (plus the `ryoku-fastfetch` launcher), `nvim/`
  (LazyVim), `yazi/`, `starship/`, `nautilus/`, `npm/` (`npmrc`), `pip/`
  (`pip.conf`), `hyprland-preview-share-picker/` (the screen-share source
  chooser xdph launches). `mimeapps.list` sets the default apps and ships to
  `/usr/share/applications/mimeapps.list`, the lowest XDG layer, so a user's own
  `~/.config/mimeapps.list` (what "Set as default" writes) always wins;
  `chromium-flags.conf` pins Chromium's keyring and Wayland backend.
- `hyprland/` the Hyprland config, authored in **Lua**. `hyprland.lua` is the
  entry point and `require`s each module. `keyboard.lua`, `gpu.lua`,
  `monitors.lua` are hardware-managed seeds, and `monitors_user.lua.example` shows
  how to hand-pin a display that autoscale must leave alone. `modules/` is one concern per file
  (`env`, `input`, `displays`, `decoration`, `animations`, `binds`, `ryoshot`,
  `window_rules`, `fullscreen`, `autostart`). `scripts/` holds the leaf shell helpers the UI
  calls directly: the `ryoku-cmd-*` screen tools (lens, OCR, color, QR, webcam
  mirror, screen record, night light, caffeine) plus the stash sidebar's
  download, compress, and install helpers and `ryoku-sysinfo`. `hypridle.conf`
  is the idle daemon's native config. `plugins/` holds the one compositor
  plugin Ryoku authors, `keysounds` (C++ against the Hyprland plugin API, with
  its `hyprpm.toml` recipe and the sample generator; see
  `docs/hyprland-plugins.md`); it ships as a package, not with the config. The
  rest of the directory deploys to `~/.config/hypr/`.
- `niri/` the niri config, authored in **KDL**. `config.kdl` is the entry point
  and `include`s the rest, in override order: the `keyboard.kdl`, `gpu.kdl`,
  `monitors.kdl` and `monitors_user.kdl` seeds, then the generated
  `settings.kdl` and `rebinds.kdl`, then `user.kdl` as the last word. Every
  seed ships because a missing include is a hard config error in niri, and each
  is comments only: the generated files carry every real setting. There is no
  `modules/` and no `scripts/`, since the neutral settings come from the store
  and the keybind helpers are shell verbs. It deploys to `~/.config/niri/`.
  See `docs/compositors.md`.
- `lockscreen/` `qylock/` (the lock theme and its quickshell lockscreen),
  `install-qylock`, and `sddm/` (the greeter setup).
- `shell/` the desktop shell subsystem: `quickshell/` (the QML UI. Every surface
  runs in-process in a single `qs -c shell` instance under `shell/`, drawn per
  monitor from one scene (`shell.qml`): `modules/` is one directory per surface
  (`bar` the four-edge frame bars with the bounded menu manager, rail status
  popout cards (`bar/popouts/`), the Super+Escape control sidebar and pluggable
  bar styles (`bar/barstyles/`, see `docs/barstyles.md`); then `dock` the app
  dock on the edge opposite the bar (its own surface, shared by every bar style),
  `launcher`, `overview` (Super+Tab), `wallpaper`,
  `visualizer` (a click-through spectrum layer that renders through the shared
  `Ryoku.Ui` spectrum field, keeping only its per-frame band math in its own
  `Motion.qml`), `osd`, `notifications`, `capture`, `confirm`, and `desktop` the
  wallpaper clock and enabled third-party widgets); `services/` holds the shared
  singletons every surface reads, `components/` the shared UI primitives, and
  `utils/` the shared JS. Beside it are `ryoshot`, `welcome` (the first-run
  guided tour), and `plugins` (the third-party shell plugin runtime:
  `discover.sh` merges the catalogue with the user's `plugins.json`, the widget
  host carries desktop placements, and `kit/` is the `Ryoku.PluginKit` QML module
  a plugin imports for the signature look; see `docs/plugins.md`)),
  `plugin/` (`Ryoku.Blobs`, the C++/QML SDF metaball module the frame renders
  with; `build.sh` builds it, and it ships prebuilt), `matugen/` (palette
  templates rendered on every wallpaper change), `qt6ct/` (the Qt icon theme, `qt6ct.conf`),
  `systemd/` (the user session target), `ipc/` (`ryoku-shell`, the Go shell
  daemon that supervises the Quickshell components, owns wallpaper/clipboard/
  lock and the GNOME keyring password prompt (it registers as the keyring system
  prompter; see `ipc/prompter.go` and `ipc/secretexchange.go`), and serves the
  control socket). `deploy.sh` and `dev-*.sh` are the live
  dev-loop tools.
- `ui/` `Ryoku.Ui`, the shared QML module the shell, the Hub and the apps all
  import for one look: the design tokens (`Singletons/Tokens.qml`), the shared
  primitives, and the wallpaper palette. It also hosts the desktop spectrum
  renderer, so the wallpaper and the Hub preview draw one geometry:
  `SpectrumField.qml` with the analytic `shaders/spectrum.frag(.qsb)` pass draws
  every look, `Singletons/VizStyles.qml` is the single catalogue of the eleven
  looks, and `lib/spectrum.js` (with `spectrum.test.mjs` beside it) is the pure
  band math, `lib/place.js` (with `place.test.mjs`) the placement math for a box that turns
  and leans.
  Installs to `/usr/lib/qt6/qml/Ryoku/Ui`.
- `i18n/` the translation catalog and the three runtimes that read it. English
  source strings are the keys, so a developer only ever writes English and a
  missing translation shows English rather than nothing: `langs.json` is the one
  language table (35 languages, add one here and nowhere else),
  `catalog/<code>.json` the generated strings, `catalog/overrides/<code>.json`
  the human fixes the generator may never overwrite, `i18n.go`/`langs.go` the Go
  runtime the CLI and both installers link (module `ryoku-i18n`), and `tools/`
  the extractor/translator (`sync.py`, shipped as `/usr/bin/ryoku-i18n`) and the
  QML AST wrapper. Installs to `/usr/share/ryoku/i18n`, which the QML singleton
  (`ui/Singletons/I18n.qml`), the Go runtime and the installer's shell
  (`installation/backend/lib/i18n.sh`) all read. See `docs/i18n.md`.
- `cli/` the user-facing control CLI, one Go program (`ryoku`): `update`,
  `rollback`, `snapshots`, `status`, `materialize` (lay the base configs into
  `~/.config`), and `reload`. It orchestrates pacman, yay, and snapper; it does
  not reimplement them. `main.go` is a thin dispatcher over the concerns under
  `internal/`: `updater` (update, status, rollback, channel, run-state,
  materialize, version), `doctor` (the convergent reconcilers, report, and
  `--explain`), and `sys` (the shared exec/package/path/terminal primitives,
  defined once). Per-command reference, user- vs developer-facing, in
  `docs/cli.md`.
- `hub/` Ryoku Settings, the central control-center GUI (`Super + ,`): `backend/`
  (`ryoku-hub`, the Go data plane that reads the keybind legend from the live
  Hyprland config, generates the `settings.lua` overlay (in `user_edits`) from JSON, and
  persists hub state as TOML; it also speaks the OpenRGB SDK, so the Lighting tab
  drives keyboards and mice per device) and `quickshell/` (the native Qt6/QML app,
  a `FloatingWindow` with a grouped nav rail and global fuzzy search, with live
  editors for displays, appearance, device lighting, lockscreen, animations,
  input, keybinds, window and layer
  rules, autostart, environment, the shell, and the desktop widgets). The product is "Ryoku Settings"; the binary and
  config keep the internal `hub` name. Deployed to `~/.config/quickshell/hub`;
  built by the shell's `deploy.sh`.
- `rashin/` Ryoku Rashin, the optional agent OS (off by default): `backend/`
  (`ryoku-rashin`, one Go program that maintains the markdown knowledge vault at
  `~/.local/share/ryoku/rashin/`, serves the embedded dashboard on
  `127.0.0.1:3600`, and bridges the Hermes agent over ACP) with its hand-authored
  web dashboard embedded under `backend/web/` (no build step), and the `rashin`
  terminal command (the same binary under a second name: natural language to a
  ready-to-run command plan on the fish prompt, with a `conf.d/rashin.fish`
  weave). The Hub's `RashinPage.qml` is the control surface (enable, one-click
  Hermes setup, open dashboard); built by the shell's `deploy.sh`. See
  `docs/rashin.md` and `docs/rashin-terminal.md`.
- `assets/` `brand/` the 力 logo and icons, `wallpapers/` the shipped wallpaper
  set (installs to `~/Pictures/Wallpapers`), and `ryodecors/` the decor art the
  `Decor`/`Placard` components render (installs to `~/Pictures/ryodecors`, kept
  current by `ryoku doctor`; bake more with `bin/art/ryodither`).

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
