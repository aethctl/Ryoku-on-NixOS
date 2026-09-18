# Unpushed work review (2026-08-31)

Everything below lives in the one shared repo (`/home/nero/Work/ryoku-arch/.git`).
Nothing was pushed. Nothing was deleted. This file is untracked; delete it when done.

> **Update (later on 2026-08-31):** `feat/depth` and `feat/ryogami` are now
> MERGED into local `unstable-dev` (merge 7cac647a9): depth stayed in Go,
> ryogami kept the wallpaper surface, and a Go-to-ryogami bridge was added
> (`ipc/ryogami.go`, ryogami `depth set`/`depth clear`). The conflict hazard
> below is resolved. Deployed and smoke-tested on this machine. Still unpushed.

This folder (`ryoku-unstable`) is a worktree on local `unstable-dev` (c646128d9),
the common ancestor of the two big feature tips. It replaces the deleted
`ryoku-arch-unstable` worktree, whose branch and 28 unpushed commits were intact.

## State of main

`/home/nero/Work/ryoku-arch` is on `main`, fast-forwarded to `origin/main`
(dc7b8117c), clean. Its previously uncommitted 180-file changeset was preserved
before the pull (see "main worktree WIP" below).

## Unpushed branches, most work first

| Branch | Not on origin | What it is |
|---|---|---|
| `feat/depth` | 54 | Depth wallpaper line: cutout engine (rembg/GPU), compose mode, banner/grand/column/outline clock faces, per-widget colour/fonts/sliders, doctor delivery. Tip e43157b58. |
| `feat/ryogami` | 48 | Ryogami Rust wallpaper daemon: forked from skwd-daemon, in-process EGL renderer, 16-kind transition engine, pub/sub IPC, drops the Go/C backend, ports depth cutout worker to Rust. Tip d067af33a. |
| `unstable-dev` | 28 | Reload cover feature (custom media, lifecycle, FIFO guards), Oh My Zsh delivery, dual-boot dedicated ESP fallback, visualizer placement. Fully contained in BOTH branches above; nothing here is only on this branch. |
| `cachyos` | 9 | Imported from `/home/nero/Work/ryoku-cachy` (its remote pointed at the deleted unstable folder). CachyOS offline ISO line: offline repo trust, initramfs once + zstd:1, nvidia variants, opt-in CachyOS Layer bundle. Tip 3cbb58077. |
| `live-materialize` | 1 | 4430ebb38 "[ryoku] skip directory symlinks during materialize". |
| `wip/main-worktree-2026-08-31` | snapshot | The 180-file uncommitted changeset that sat in the main worktree (weather panel + calendar popup, dock removal, importer/lighting removal, ryoku-leds, translations). Also kept as `stash@{0}`. |

Branch overlap: `feat/depth` and `feat/ryogami` share 9 depth commits beyond
`unstable-dev` (merge-base 295adf8bc); beyond that, depth has 17 unique commits
and ryogami 11 unique.

## Contributor PR branches (not on origin, kept locally)

| Branch | Commits | Tip |
|---|---|---|
| `pr-80` | 1 | fix idle GPU pin from ungated clock colon-blink |
| `pr-82` | 21 | Voyrox unstable-dev merge |
| `pr-85` | 1 | hub: press/release trigger toggle for custom keybinds |
| `pr-86` | 1 | keybinding to pin floating windows |
| `pr-98` | 1 | switcher rollback (origin ref was pruned upstream; rescued as local branch) |

## Review commands

```sh
# the two big tips against their shared base
git log --stat unstable-dev..feat/depth
git log --stat unstable-dev..feat/ryogami

# the main worktree WIP (diff against the old main it was written on)
git diff 280e27c8a wip/main-worktree-2026-08-31

# cachy line
git log --stat unstable-dev..cachyos
```

## Known hazard: depth vs ryogami merge conflict

A probe merge (`git merge-tree feat/depth feat/ryogami`) conflicts:
content conflict in `ryoku/shell/ipc/daemon.go`, and modify/delete on
`ryoku/shell/ipc/depth.go` + `depth_test.go` (ryogami deletes the Go depth ipc
that feat/depth keeps improving, since ryogami ports it to Rust). Consolidating
these two into one branch needs a human decision on which depth backend wins.
No merge was attempted.

## Branches with NOTHING unpushed (deletable after review)

`depth-to-unstable` (checked out in ryoku-arch-depth), `feature-network-kill`,
`issue99-review`, `reload-customize`. All fully contained in origin.

## Folder disposition (nothing removed yet)

- `ryoku-arch-depth`: clean worktree, branch fully on origin. Safe to remove via `git worktree remove` after review.
- `ryoku-arch-ryogami`: clean worktree; `feat/ryogami` is safe in the shared repo. Safe to remove after review.
- `ryoku-cachy`: standalone clone, now fully duplicated into the shared repo (branch `cachyos`, remote `cachy`). Safe to remove after review.
- `ryoku-arch-rework`: NOT a git repo, only plans/research/handoff notes. Keep or archive by hand; git cannot protect it.
- `ryoku-ud-wt`, `ryoku-main-wt`: broken worktrees of a deleted parent repo (2 months old, `.git` file points nowhere). Their files may hold old uncommitted edits that exist nowhere else. Inspect by hand before deleting.
