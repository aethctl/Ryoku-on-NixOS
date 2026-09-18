# Updates and delivery

> [!NOTE]
> **Arch reference:** this page documents Ryoku's Arch implementation. It is kept
> in the NixOS repository for upstream parity and developer reference. For NixOS
> installation, updates and system-management behavior, see [`nixos.md`](nixos.md).

How a change in this repo reaches a running machine, and the contract that keeps
a user's install a mirror of a dev checkout. Read this before adding a config
file, a `shell.json` key, or anything a user must receive.

## Two worlds, one result

- A **dev box** runs the checkout: `ryoku deploy` builds the binaries and lays
  `ryoku/` into `~/.config`. `ryoku update` on it tracks `origin/main` (the git
  channel) and redeploys.
- A **user box** runs signed packages: `ryoku update` runs `pacman -Syu` from the
  `[ryoku]` repo, then `ryoku materialize`, then `ryoku doctor`.

They must converge. A change that lands on one but not the other is the bug this
page exists to prevent.

## `ryoku update`

Snapper pre-snapshot, then the channel (git fast-forward, or the `[ryoku]`
package set), then stage2 through the just-installed binary: quiesce the shell,
`ryoku materialize`, reload the compositor, restart the shell, `ryoku doctor`,
snapper post-snapshot. Each stage publishes to
`$XDG_RUNTIME_DIR/ryoku-update.json` (the
ordered steps, the current label, a live log tail, and, on failure, the error
and the pre-update snapshot), so the update island and the Hub's Updates page
render a determinate run and a one-click rollback.

## materialize: the config a user receives

`ryoku materialize` lays the package's base config (`/usr/share/ryoku/config`,
mirrored by `ryoku/shell/deploy.sh` on a dev box) into `~/.config`:

- Every shipped file is copied over on every update (the previous Ryoku copy is
  clobbered) and files dropped from a release are pruned; `~/.config/quickshell`
  is converged wholesale.
- A short **seed list** (`generatedSeed` in
  `ryoku/cli/internal/updater/materialize.go`: `fastfetch/config.jsonc`,
  `kitty/current-theme.conf`, the ghostty and nvim starting points, plus every
  provider's per-machine files from `wm.ConfigSeeds`, e.g. `hypr/monitors.lua`
  and `niri/monitors_user.kdl`) is copied only when absent, never clobbered:
  per-machine or user-owned state an update must keep, for every installed
  compositor, not just the active one.
- The user overlay (`~/.config/ryoku/user_edits`, mirroring `~/.config`) is laid
  on top last, so a file there wins at its mirrored path; see below. Anything the
  package never ships (`hypr/user.lua`, `kitty/user.conf`, a forked module) is
  left alone regardless.

So the QML and the `Config.qml` defaults reach users on every update. A **new**
`shell.json` key is safe: the user's file lacks it, and the shell reads the new
`Config.qml` default.

## user_edits: your edits, kept apart

Ryoku-owned config and user edits live in separate trees, so an update refreshes
the base freely while your edits stand. The base is the restore point; the
overlay is yours.

- **base** `/usr/share/ryoku/config` (the checkout on a dev box): pristine,
  re-laid in full on every update, so every fix and addition lands first.
- **user_edits** `~/.config/ryoku/user_edits`, mirroring `~/.config`, sparse:
  only what you changed. `materialize` overlays it last, so a file here wins at
  its mirrored path. Empty means pure base and the overlay is a no-op.

Two ways to override, neither of which blocks a fix:

- **Overlay (default).** The tool's own last-wins include: Hyprland loads the
  base modules, then `settings.lua` and `user.lua` last; kitty `globinclude`s
  `user.conf`. The base loads underneath, so a new upstream keybind still arrives
  while your file wins on what it sets.
- **Fork (opt-in).** A whole copy of a shipped file shadows the base one. You own
  it now, so an upstream fix to that file will not reach you automatically. Your
  forks are the files you see in the overlay; `ryoku reset <path>` takes the new
  base.

Ryoku Settings writes its generated `hypr/settings.lua` and `hypr/rebinds.lua`
into the overlay (authored under `user_edits`, reflected live). Its other state
(bar, colours, launcher, device lighting) it keeps under `~/.config/ryoku`,
GUI-managed and update-safe: the package ships no file there, so `materialize`
never clobbers or prunes it and a keyboard keeps the look you gave it across an
update. `ryoku reset` drops an override; `ryoku recovery` is the last
resort, wiping the overlay and that state back to shipped defaults.

## doctor: converging what materialize can't

`ryoku doctor` runs convergent reconcilers for the stateful drift materialize
can't state declaratively (disk, boot, session, and the user-owned
`~/.config/ryoku/*.json` materialize never rewrites). Reconcilers stand in for a
migration ledger: each is idempotent and safe on every update, and is retired
once every supported install has run it. `reconcileShellConfig` migrates a stale
`shell.json` (drops retired keys, revives the bar, clamps geometry).
`reconcileLauncherLocalFrostDefault` moves only the launcher's retired shipped
`bgBlur: 12` to the new 2 px local-frost default, then records a marker so a
later deliberate 12 remains a user choice.
`reconcileUserEdits` seeds the how-to guide and, for boxes upgraded from the
retired adopt step, moves the tool's own user files (`hypr/user.lua`,
`hypr/monitors_user.lua`, `kitty/user.conf`) back OUT of the overlay. Those are
edited in place; a frozen overlay copy of one used to be re-laid over the live
file on every update, wiping edits made afterward. Idempotent.
`reconcileMimeDefaults` clears the default-app map an older release froze into
`~/.config/mimeapps.list`: entries that only copy Ryoku's shipped values are
dropped (the file goes if that is all it held), and anything the user chose
stays. Ryoku's map ships to `/usr/share/applications/mimeapps.list` now, the
bottom of the XDG mimeapps chain, so it sets the defaults without ever
outranking a user's pick.
`reconcileShellInstances` clears a desktop that is running twice: a shell surface
orphaned by a daemon that was killed keeps drawing, and Quickshell allows a second
instance of one config, so the replacement draws over it. It keeps the instance
the supervising daemon started and stops the rest.
`reconcileShellLoad` gets a black screen back. Every surface is one Quickshell
instance, so a single QML file that cannot load takes the whole desktop, at login
and after an update alike. It reads the load failure from the shell daemon's
surface log (or loads the config once when there is no log), scopes the repair to
the module the loader blamed, moves a user override that breaks the desktop aside
as `.broken`, puts back every shipped file the live tree no longer matches, and
restarts the shell. When the shipped file is itself at fault it says so and names
`ryoku update` and `ryoku rollback`, the two things that help.
`reconcileWmPlugins` keeps a compositor's enabled plugins loading across a
compositor bump: a plugin is ABI-locked to the exact build and every copy Ryoku
builds carries an ABI receipt, so after an update it rebuilds each enabled
plugin whose receipts no longer match the installed headers through the provider
(`ryoku-hub desktop plugins rebuild --stale`, the Plugins page's builder) before
the next login, and names the toolchain to install when a box has none. Gated on
`CapPlugins`, so a compositor with no plugin system (niri) is a no-op. See
`docs/hyprland-plugins.md`.

## Two compositors

A box can have both compositors installed and switch between them. Update, doctor
and recovery reach the compositor only through the seam (`ryoku/wm/`), so none of
them names one. Update and doctor keep the inactive compositor's config
untouched; recovery deliberately resets both when both are installed.

- **`ryoku update`** re-lays the base config, then reloads the active compositor
  through `wm.Open()` (`update.go` `pauseConfigAutoreload`/`reloadConfig` call
  `Act(ActionConfigReload)`; a compositor that watches its own file no-ops the
  reload). The seed list folds in every provider's per-machine files from
  `wm.ConfigSeeds` (`ryoku/cli/internal/updater/materialize.go`), so an update
  while niri is active never clobbers or prunes `hypr/*` seeds, and the reverse.
- **`ryoku doctor`** repairs compositor state through the seam and only for the
  running provider: it points xdg-desktop-portal at that provider's
  `Caps.PortalBackend` (`reconcilePortalRouting`), rebuilds stale window manager
  plugins only when the provider declares `CapPlugins` (`reconcileWmPlugins`; a
  compositor with no plugin system reports no plugin support), and writes the
  overlay how-to guide against the active provider's own config files
  (`reconcileUserEdits`, so it names `niri/user.kdl` on niri and `hypr/` paths on
  Hyprland). It does not touch the inactive compositor.
- **`ryoku recovery`** clears the `user_edits` overlay and the neutral Hub
  stores, then removes every path that `ryoku wm reset-paths` prints: each
  provider's generated config plus its hand-edit files (`wm.ResetPaths` over
  `wm.Providers`), for both compositors when both are installed. It runs that
  command from the freshly fetched checkout first (`go run . wm reset-paths`), so
  a broken installed build cannot skew the list, then redeploys the shipped
  defaults. The per-machine seeds (monitors, gpu, keyboard) and saved rices are
  not in that set and survive. `--no-packages` skips pacman; it refuses on a
  machine that is not Ryoku.
- **Switching** (`ryoku wm use <name> [--keep-previous|--remove-previous]`)
  installs the target's package; removing the old compositor reclaims its
  packages. `wm.Reclaim` computes the free set from the outgoing provider's
  `Caps.Packages`, and the package and byte counts shown come from pacman's own
  removal plan, re-checked immediately before the transaction. Full switch
  contract in `docs/compositors.md`.

## Publishing: releases and channels

The `[ryoku]` repo is published into named states, all under the one bucket
mount the repo domain serves (`repo.ryoku.dev/stable/<key>` is bucket object
`<key>`; the `stable` path segment is the mount, not the channel):

| Directory | Channel | Written when |
|---|---|---|
| `x86_64/` | **stable**: the URL every installed box has | a release tag is published: a byte copy of that release |
| `releases/<tag>/x86_64/` | one frozen release; never rewritten | the tag is published (`publish-repo.yml` refuses an existing directory) |
| `releases/index.json` | the release ledger, newest first, with each release's ISO per variant (`images.plain`, `images.cachyos`) | after each release |
| `channels/testing/x86_64/` | **testing** | every push to `unstable-dev` |

So a box on stable moves between named releases, and can be put back on any
earlier one, on either variant: the `[ryoku]` packages are one `x86_64` build
that both variants install, the frozen release directories are never pruned,
and the ledger's `images` map names the Arch and CachyOS ISO of each release
(derived from the per-ISO manifests in the bucket, so it heals on every
rebuild) for a reinstall of an older release. Each build carries a strictly
increasing package version (`core.r<commit-count>.g<sha>`) that the Ryoku
upgrade moves to, and the `ryoku-desktop` package writes `/etc/ryoku-release`
(`RELEASE=`, `CHANNEL=`, `VERSION=`, `COMMIT=`) so a box can say which release
it runs; `release.json` beside each channel's db says which one the channel
serves.

A release is a tag: `main` advances only by fast-forward from `unstable-dev`,
and publishing nothing on that push. The maintainer runs **Stable Release**
(`bump_type: none` tags the `VERSION` main already carries; a bump rewrites it
first), which tags `main`, publishes `releases/<tag>/`, moves the stable
pointer onto it, records the ledger entry, and dispatches both release ISOs
(plain Arch and CachyOS) from that frozen directory, so an ISO named for a
release installs exactly that release. Arch itself keeps rolling between
releases; only the Ryoku set is frozen.

**Work on `unstable-dev` reaches testing on every push, and stable only when a
release is tagged.**

On a packaged box the channel is nothing but the `Server` line of the `[ryoku]`
stanza, so there is no second state to drift from it:

- `ryoku track unstable-dev` turns any box into a **testing box**: it follows the
  `testing` channel, rebuilt on every push to `unstable-dev`, so a tester gets
  each push as signed packages through `ryoku update`. `ryoku track main` returns
  it to **stable** (named releases). The two are aliases for `ryoku track testing`
  and `ryoku track stable`.
- `ryoku track stable | testing | v<tag>` rewrites that line and runs an update
  that moves the Ryoku set to what the channel serves, down as well as up: the
  databases are force-refreshed (a frozen release's db is older than the
  channel's, so pacman would keep the cached one), then the installed
  `ryoku/<pkg>` set is installed at the versions that channel publishes. A tag
  pins the box to that release until it is tracked away.
- `ryoku rollback --to v<tag>` is `track` onto a frozen release: the Ryoku set
  goes back in one pacman transaction while Arch stays current. Bare
  `ryoku rollback` lists the ledger and the snapshots.
- `ryoku status` reports `release` (this box) and `channelRelease` (what the
  channel serves); `ryoku version` prints the release tag.
- The doctor names the channel it finds and warns, without touching it, when
  `[ryoku]` points at a mirror Ryoku does not publish.

`ryoku track main | unstable-dev --source` is the developer path: it builds and
tracks a git checkout instead of packages (see `docs/development.md`). A box
already on a checkout is migrated onto packages by a plain track without
`--source`: the checkout is retired as the update source (the `~/ryoku-arch`
clone stays on disk) and `ryoku update` runs `pacman` from then on.

### Release names

Every release line has a name from the creation stories Ryoku draws on (the
Kojiki and the Theogony), in the order those stories tell them; `CODENAME`
holds the current one and `release/names.md` tells each name's story. The
name changes when a line begins (the pre-1.0 line is Onogoro, the first
island; 1.0 is Amaterasu) and every release inside the line keeps it. It
travels with the release: `build-repo.sh` writes it into `release.json` and
the ryoku-desktop package into `/etc/ryoku-release` (`NAME=`), the publish
copies it into `releases/index.json`, the Stable Release and Release Notes
workflows title the tag and the GitHub release with it (a line's first release
opens with its story), and a box shows it in `ryoku version --pretty` (which
fastfetch's OS line uses), `ryoku status`, `ryoku rollback`, the update
island (when the channel serves the next line) and the Hub's Updates page.

## The contract

- **A user-facing config file must be delivered by a path a user runs**: shipped
  in a package (then materialized) or seeded by the installer. A file only
  `deploy.sh` lays, or one no path lays, reaches no user. `ryoku-dev-verify-delivery`
  fails the commit on such an orphan.
- **A removed or renamed `shell.json` key, or a changed default that must reach
  existing users, needs a `doctor` reconciler** (materialize never edits a user's
  `shell.json`). An additive key needs nothing.
- **Never ship into a path the user's own tools write.** `materialize` clobbers
  every shipped file, so laying Ryoku's defaults where an app writes the user's
  choice resets that choice on each update: `~/.config/mimeapps.list` did exactly
  that to default apps. Ship such defaults one layer down where the format
  provides one (`/usr/share/applications/mimeapps.list` for mime defaults), or
  make the file a `generatedSeed` if it has no layering.
- **A user override belongs in `~/.config/ryoku/user_edits`, never in a shipped
  path.** The base still ships every file (the delivery check stays green) and
  the overlay wins on top. A whole-file fork opts out of upstream fixes for that
  one file, so prefer an overlay for anything additive.
- **A change reaches users only after `main` fast-forwards.** Keep the gap small;
  the delivery check reports it on every push.

## Checks

- `bin/ryoku-dev-verify-delivery` flags orphan configs (hard fail) and reports
  the publish lag. It runs in `pre-commit`, `post-commit`, and the Delivery check
  workflow.
- The install-test workflow builds the ISO and runs a real, unattended install in
  a VM, then verifies the desktop comes up, so a broken install or a missing
  package is caught before a user hits it.
