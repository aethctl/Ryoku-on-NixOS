# Changelog

Notable changes to the repository as a whole. Each tree keeps its own changelog
for finer detail.

## Unreleased

### Added
- **Ryotunes 2.5.1 is native on NixOS.** Ryoku now builds the new
  `ryotunesd` daemon, CLI, native Quickshell client, shipped skins and Matugen
  payload from the pinned upstream source. NixOS owns the playback daemon
  declaratively through `ryotunesd.socket` and `ryotunesd.service` rather than
  Arch's package preset or mutable user-unit installation.
- **Plain-language GitHub release notes, generated from commit notes.** A change
  users notice gets a `Note: New|Fixed|Removed: ...` trailer on its commit;
  `bin/ryoku-release-notes` collects these between releases and the
  `release-notes.yml` bot publishes them as a formatted GitHub Release, with
  optional demo gifs (`| release/media/...`). A stable `v*` tag becomes a full
  release; each unstable-dev bump refreshes one rolling `unstable` pre-release.
  The `commit-msg` and `pre-push` hooks now also hold subjects to 72 characters
  with no trailing period and validate the trailer. A stable release is also
  announced to Discord, reusing the existing `DISCORD_WEBHOOK_URL` secret: the
  published GitHub changelog is posted verbatim in a branded embed (wordmark
  banner, logo mark, brand footer). The rolling `unstable` pre-release is not
  announced, to keep the channel quiet. See `CONTRIBUTING.md`.
- **User edits live in a `user_edits` overlay, separate from Ryoku-owned config.**
  `~/.config/ryoku/user_edits` mirrors `~/.config` and is laid over the base on
  every `ryoku materialize`/deploy, so a file there wins while the base (the
  restore point) still delivers every fix and addition underneath. Overriding by
  overlay (a last-loaded `user.lua`/`settings.lua`/`user.conf`) keeps upstream
  fixes flowing; forking a whole file opts out for that one file. `ryoku reset
  [path]` reverts an override; `ryoku
  recovery` wipes the overlay and the Hub's stores back to shipped defaults.
  Ryoku Settings writes its output into the overlay too, and a seeded `README.md`
  plus clearer file headers explain to hand-editors what edits what. See
  `docs/updates.md`.
- Update-delivery guard: `bin/ryoku-dev-verify-delivery` fails a commit when a
  `ryoku/apps` config reaches no user (shipped by no package, installer, or
  deploy path) and reports how far `main` lags `unstable-dev`. Wired into
  pre-commit, post-commit, and a Delivery check workflow. `docs/updates.md`
  documents the update, materialize, and doctor flow and the delivery contract.
- Fresh repository layout: `installation/`, `system/`, `ryoku/`, each with a README
  and changelog.
- A working installer (Go TUI plus a bash backend) that partitions, optionally
  encrypts with LUKS, installs the base system, configures it, deploys the desktop,
  and sets up Limine.
- A plain Hyprland desktop with kitty, fastfetch, fish, and nautilus, an SDDM
  greeter using the qylock clockwork theme, and Limine with Ryoku branding.
- A `shell/` tree: the full Ryoku shell (a Quickshell bar, panels, launcher, lock,
  and screenshot tool) driven by one Go IPC daemon, `ryoku-shell`, that supervises
  the components and handles every shell control command. Imported and de-branded
  as a base; not yet wired into the installer.
- A shell plugin system: third-party widgets a user places where they like. A
  plugin ships a service plus one adaptive `content/Widget.qml` (glyph / compact
  / full densities); the shell owns the layer, shape, size, and motion of each
  host (frame popout, desktop widget; topbar glyph, window, island to follow),
  so plugins always read as native. Managed in Ryoku Settings -> Plugins
  (enable + pick a host), discovered from `~/.local/share/ryoku/plugins` and the
  user's `plugins.json`, with the signature kit shipped as the `Ryoku.PluginKit`
  QML module. The `ryoku-extras` `plugin` bundle items now install instead of
  being deferred. The legacy `wallhaven` plugin is reworked as the worked
  example.

### Fixed
- **Existing NixOS installs now migrate to the unified Ryostage controls.**
  Materialization folds persisted `depth` and `parallax` Quick Settings modules
  into the current `stage` tab instead of leaving upgraded systems with retired
  controls.
- **NixOS privileged actions now use the real security wrappers.** The Ryoku
  shell exposes NixOS's setuid `pkexec`/`sudo` wrappers through its otherwise
  immutable service PATH, and the Nix updater calls the configured sudo wrapper
  directly instead of accidentally selecting the non-setuid Nix store binary.
  This fixes SDDM lock-skin switching and `ryoku update` privilege escalation.
- **Repository Git hooks now run natively on NixOS.** Hook scripts use the
  portable `env bash` interpreter instead of assuming `/bin/bash` exists, and
  safely treat an unset force-push override as disabled under strict shell mode.
- **Rashin now carries its agent skill correctly on NixOS.** Musubi packages
  the shipped `ryoku` skill tree, exports its immutable Nix-store root to the
  Rashin service, and removes live prompts that incorrectly identify NixOS
  systems as Arch Linux.
- **Musubi now ships the ISO builder RyoVM expects.** `xorriso` is part of
  the declarative Ryoport runtime so instant/cloud-init VMs can create their
  `cidata` seed images without relying on an Arch package-manager fallback.
- **Nix update status now reports the generation and local checkout correctly.** `ryoku-nix-update` falls back to `/etc/ryoku-release` for the installed version and no longer replaces a local development checkout's `VERSION` with the version published on its Git remote.
- **Musubi completes the 0.58.6 runtime dependency and GPU helper sync.**
  NixOS now ships upstream-pinned Prowl v0.15.6 for Rashin code intelligence,
  and the shared GPU runtime helper tracks the final 0.58.6 implementation so
  Doctor and `ryoku-gpu` agree on the `check-pin` contract.

- The overview's new-workspace controls now allocate workspace ids globally, so
  clicking `+` or `NEW` on a secondary monitor creates the workspace on that
  monitor instead of jumping to an existing workspace on another output.
- Limine now shows the generated boot menu: the branded config moved from
  `/boot/limine/limine.conf` (which Limine scans first, shadowing everything
  `limine-entry-tool` generates into `/boot/limine.conf`: the UKI tree and the
  snapper Snapshots submenu) to `/boot/limine.conf` itself, and the EFI binary
  moved onto the path the tool's pacman hook refreshes
  (`EFI/limine/limine_x64.efi`), so the booted bootloader stops aging against
  the installed package. `ryoku doctor` migrates existing installs in place.

### Notes
- The previous Arch tree stays on the `main` branch as reference. The NixOS work
  moved to its own repository.
