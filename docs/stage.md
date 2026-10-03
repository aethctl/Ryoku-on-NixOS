# Ryostage (舞台)

The desktop as a stage: the wallpaper is the backdrop, the subject and any
extra cut-outs are the layers, and the clock, widgets and the audio
visualizer are the cast, arranged in front of or behind them. Depth and
Parallax used to be two features with two engines, two settings files, two
sidebar tabs and two artifact folders. They are one thing: **Depth is a
stage with a single still layer in front of the widgets; Parallax is the
same stage with motion on.** Ryostage is that one thing.

Names, so the parts are findable:

| Part | Name | Where |
|---|---|---|
| The feature, overview, and settings page | **Stage** (`stage` sidebar card; Desktop Scene in Hub) | `quickshell/shell/modules/stage/`, `sidebar/cards/StageCard.qml`, `ryoku/hub/quickshell/pages/DesktopScenePage.qml` |
| The cut-out engine helper | **`ryostage`** | `ryoku/shell/scripts/ryostage`, shipped to `/usr/bin` |
| The daemon module | `stage` topic and verbs | `ryoku/shell/ipc/stage.go` |
| The settings | `~/.config/ryoku/stage.json` | user-owned, GUI-managed, never materialized |
| Per-wallpaper scene state | `~/.local/state/ryoku/stage-walls.json` | daemon-owned |
| Artifacts | `~/Pictures/Stage/<stem>/` | the user's files, one folder per wallpaper |
| Engine runtime and models | `~/.local/state/ryoku/ryostage/` | one venv, one model cache |

The two retired engine helpers (the old Depth and Parallax segmentation
scripts), `depth.json`, `parallax.json`, `depth-walls.json`, `~/Pictures/Depth`,
`~/Pictures/Parallax` and the `depth`/`parallax` tabs are retired; the doctor
migrates all of them (below).

## The mental model a user needs

One feature: **Depth**. It lifts the wallpaper's subject in front of your
widgets. **Parallax** is a switch inside Depth: the same cut, the same look,
now drifting with the pointer over an inpainted backdrop. Nothing is configured
twice.

Three places, each with one job:

- **The sidebar's Stage section** shows the current wallpaper, scene mode,
  enabled widgets, and visualizer state. Its buttons open the corresponding Hub
  view; the sidebar does not duplicate the editors.
- **Ryoku Hub > Desktop Scene** owns Scene, Visualizer, and Widgets views.
  Scene settings apply live, with an explicit confirmation for a re-cut or
  clearing layers. The widget and visualizer views open their on-desktop editors.
- **The desktop** (right-click) provides direct access to wallpaper, widgets,
  and the visualizer. Its Depth row opens Desktop Scene in Hub. A widget's own
  menu and the visualizer's edit bar each retain a Depth control for lifting that
  widget above the in-front cut-outs or dropping it behind them.

There is no shell editor. The bar, dock and menus keep their Hub pages.

## The desktop right-click menu

The quick row contains Wallpaper, Widgets, Visualiser, and Search tiles.
Below it, the Depth row shows Off, On, Parallax, or the current cutting
percentage and opens **Ryoku Hub > Desktop Scene**. Quick controls opens the
left sidebar. Settings opens Hub's Widgets view; Reload shell reloads the shell.

Plain, Depth, and Parallax are chosen in Hub's Scene view:

- Plain: `set-effect off`.
- Depth: `set-effect depth`.
- Parallax: `set-effect parallax`.

Depth and Parallax use the same cut-outs. The first enable cuts the current
wallpaper if necessary; progress and Stop stay visible in Hub while the engine runs.

## Stage overview and Hub settings

`modules/sidebar/cards/StageCard.qml` is an overview. Its wallpaper preview,
scene mode, widget count, enabled-widget list, and visualizer status describe
what is on the desktop. Edit scene, Visualizer, and Widgets open the matching
Desktop Scene view in Hub.

`ryoku/hub/quickshell/pages/DesktopScenePage.qml` contains the editors. It uses
two columns when there is room and one on smaller windows, with a scrolling
viewport beneath the view selector.

### Scene

- **Preview and mode:** the current wallpaper and Plain, Depth, or Parallax.
  A running cut shows progress and a Stop button.
- **Cut and layers:** Draft, Standard, or Fine quality; selecting a different
  tier offers Download if its model is missing, then Re-cut. Layers can be
  placed behind or in front of widgets; Parallax adds a drift control.
  Cut a picture and Add a PNG add layers. Clear cut-outs asks for confirmation.
- **Look:** edge softness, shadow strength, and shadow direction. Reset look
  and motion restores those controls and motion settings, not cut quality,
  widget layer placement, or the editor grid.
- **Motion** (Parallax): Soft, Cinematic, or Beat presets; Subtle, Normal, or
  Strong amount; Still, Float, Breathe, or Sway idle motion with an idle-speed
  slider when moving; music response with an intensity slider when enabled.
  Follow mouse exposes a Fine-tune pointer section with sensitivity, range,
  and backdrop-drift sliders. A preset is highlighted only while its values match.
- **Composition:** Open widget editor hands off to the desktop editor.

### Visualizer and Widgets

Visualizer includes visibility, style, depth relative to cut-outs, frame rate,
adaptive quality, gain, and smoothing. Open visualizer editor hands off to its
desktop placement and per-look controls.

Widgets opens the desktop widget editor for placement, size, color, locking,
depth, and installed plugin widgets. Both hand-offs close Hub only after the
shell accepts the request; a failed hand-off leaves the page open with an error.

Hub reads the stores but is not their writer. Typed shell IPC updates the
canonical stage and visualizer settings; wallpaper effects and layers use the
daemon's stage commands.

## Edit widgets

The desktop lifts above open windows, the dock steps back, and every enabled
widget wears a frame:

- a 1 px outline with the widget's name at its top-left;
- drag anywhere on it to move (grid-snapped, live), the bottom-right bracket to
  resize;
- two small buttons on its top-right: **Settings** (opens that widget's own
  menu: design, lock, size, opacity, colour, snap) and **Remove** (hides it).

Every framed widget gets one: the built-ins, the Shima and Python faces, and
the plugin tiles alike.

One toolbar rests bottom-centre, one row:

```
部品 EDIT WIDGETS  [grid] [16]  [Widgets]  [Reset]  [Done]
```

- **Widgets** grows a panel out of the bar's top edge. The roster is too long
  for one honest list, so the panel is a settings page: a category rail on the
  left (Ryoku widgets, Shima widgets, Python widgets, each installed plugin
  set, with a live count) and a two-column grid of widget cards for the chosen
  category. A card carries the glyph, name, hint, an on/off dot, and (once on)
  a tune affordance that opens that widget's editor -- the inspector for a
  slot-hosted face, the Placer for the visualizer, the tile's own menu for a
  plugin. The whole card toggles. Search drops into a flat result grid across
  every category, each card wearing its category as an eyebrow. Keyboard:
  Down from the search enters the grid, arrows move, Space toggles, Esc
  unwinds. Plugin rows read the installed set (enabled or not), so a hidden
  tile keeps its card and the switch brings it back.
- **Reset** restores widgets.json as it was when the session opened (every
  widget's enabled set, placement, size, style, colour and face options, plus
  the visualizer's flag and the placed plugin set); its slot is kept while
  clean so Done never moves.
- **Done** (or Escape, or a click on bare wallpaper when nothing is selected)
  leaves. There is no Save; the desktop is the document.

## Customize visualizer

The visualizer's own editor, unchanged: the Placer (drag to move, corner to
size, dot to turn, scroll to resize) with its EditBar fixed to a screen edge.
The menu row (and the picker's tune on the visualizer card) turns the
visualizer on if it is off and opens it. Its Done closes it.

## Session model

`modules/stage/Singletons/StageSession.qml` is the Edit widgets session only:
`mode` is `""` or `"widgets"`; `monitor` names the screen that opened it;
`selected` is a widget id; `panel` is the drop-down that is open (`"add"`);
`dirty` shows Reset. `escapeStep()` unwinds one level per press: the
drop-down, then the selection, then the session. Hub keeps pending scene
confirmations locally; the settings page is not an edit session.

## Models: one catalogue, visible provenance

`ryostage` owns the curated list, and the UI renders it instead of hardcoding
tiers:

```
ryostage models --json
[
  {"id":"u2netp","label":"Draft","tier":"draft","size":"4.6 MB","installed":true,
   "licence":"Apache-2.0 (mirrored weights)","upstream":"https://github.com/xuebinqin/U-2-Net"},
  {"id":"birefnet-general-lite","label":"Fine","tier":"fine","size":"224 MB","installed":false,
   "licence":"MIT","upstream":"https://github.com/ZhengPeng7/BiRefNet"}
]
```

The Quality control maps Draft -> `u2netp`, Standard -> `u2netp` with alpha
matting, Fine -> `birefnet-general-lite` with matting. Picking a tier whose
model is not installed shows the size and a **Download** button in place;
`Remove` frees it again. The runtime (`rembg[cpu]`, MIT, on ONNX Runtime,
MIT) installs once, on the first enable, into the shared cache. Nothing ML
ships in the base image. Both scripts' licence notes live in the engine's
header and here, so a packager can check them.

## Engine: `ryostage`

One bash helper, the only place model logic lives. Backend resolution is
unchanged from the old Depth engine (the managed venv first, then a system Python in
rembg's range, `uv` provisioning a managed 3.13 otherwise).

| Subcommand | Contract |
|---|---|
| `check` | exit 0 and print `available` when the runtime and at least one model are present, else `missing` and non-zero |
| `models [--json]` | the curated catalogue: ids one per line, or the JSON above |
| `install [model...]` | provision the runtime and fetch the named models (default `u2netp`); opt-in, streams progress |
| `remove <model>` | drop a cached model |
| `cut <in> <out.png> [--model id] [--matting]` | the subject as an alpha-matted PNG; never writes a partial file |
| `inpaint <image> <mask> <out.png>` | fill the cut-out's hole with the surrounding colour (the parallax backdrop) |

Cache: `~/.local/state/ryoku/ryostage/{venv,models}`. On first run the
helper adopts a pre-split `~/.local/state/ryoku/depth` or `.../parallax` tree by
rename (same filesystem, no re-download); a leftover second tree is reported
by the doctor as reclaimable space.

`inpaint` makes the Parallax backdrop from the one cut: the subject's hole
(the matte grown outward so no subject pixel seeds the fill) is filled from its
surroundings by normalized convolution, growing inward until covered, then the
whole image is softened as the far plane (a 4 px blur, a touch darker). A
drifting subject therefore reveals the colours around it, never a flat plate
or its own silhouette. Half resolution above 1600 px keeps a 4K wallpaper at a
few seconds. Backdrops made before this land are regenerated by a re-cut or
Refresh.

## Daemon: `ipc/stage.go`

One worker, one registry (below), one topic.

- **Artifacts** `~/Pictures/Stage/<stem>/`: `subject.png` (the cut),
  `background.png` (the inpainted backdrop, made once the first time
  Parallax is chosen for that wallpaper), `layer-NN.png` (added layers),
  `.index.json` (mtime + quality reuse).
- **Topic** `stage`: `{ current, busy, stage: "cut"|"inpaint"|"", percent,
  walls: { <path>: { effect, subject, background, rev, layers: [...] } } }`,
  published on every change and on each generation phase. QML renders from it
  and nothing else. `subject`/`background` are absolute paths ("" until fresh);
  `rev` is the max mtime across the wall's `subject.png`/`background.png`/
  `layer-NN.png`, so the shell busts every url with the one revision. The frame
  layers carry `{out, label, enabled, front, depth}` and no per-layer rev, and
  `layers[0]` is always the subject slot.
- **Verbs** (`ryoku-shell stage ...`): `set-effect <off|depth|parallax>`,
  `set-layer <index> <json>` (enabled/front/depth), `add-layer <png>`,
  `cut-layer <picture>` (runs the engine on another picture and adds the
  result), `remove-layer <index>`, `refresh` (re-cut), `cancel`, `clear`,
  `status`, `models`.
- **Rules**: a wallpaper switch reconciles and never generates; a stage is
  per wallpaper; videos are skipped; an effect switch never re-cuts (only
  Parallax's first use on a wallpaper adds the inpaint); a failure leaves the
  effect off with a logged reason. The subject is still handed to ryogami as
  `depth` for the Depth effect only, unchanged on the wire.

## Settings: `~/.config/ryoku/stage.json`

Global only; anything per-wallpaper is in the registry.

| Key | Default | What it is |
|---|---|---|
| `quality` | `draft` | `draft` / `standard` / `fine`, the model + matting pair |
| `edge` | `0.15` | edge softness of every cut-out (0..1) |
| `shadow` | `0` | drop shadow behind every layer (0..1) |
| `shadowAngle` | `90` | shadow direction in degrees, 0 = right, 90 = down |
| `motion.amount` | `normal` | `subtle` / `normal` / `strong`: cursor drift, and the idle amplitude |
| `motion.idle` | `none` | `none` / `float` / `breathe` / `sway` |
| `motion.music` | `false` | layers react to the shared spectrum |
| `motion.musicLevel` | `0.6` | how hard the music pushes (0..1) |
| `motion.speed` | `1.0` | idle motion speed (0.25..2) |
| `motion.mouse` | `true` | Parallax follows the pointer at all |
| `motion.sensitivity` | `1.0` | the pointer's pull (0..2) |
| `motion.range` | `1.0` | how far a layer may travel (0..2) |
| `motion.backdrop` | `0` | the inpainted backdrop's own drift (0..1); above 0 a sliver of the base wallpaper shows at the trailing edge |
| `front` | `[]` | widget ids (built-in, plugin tile, or `visualizer`) drawn above the layers marked "in front"; written by the `Depth` row in a widget's right-click menu or the visualiser's edit bar |

The daemon reads `quality`; the shell reads the rest. On the first start after
v2 a v1 `stage.json` (one still carrying `feather`, `lift`, `preset` or the
`motion.{mouse,sensitivity,range,wallpaper}` sub-knobs) is folded once and
rewritten atomically: `feather` -> `edge`, `lift` and `preset` dropped, and the
motion sub-knobs reduce to `motion.amount` (`mouse: false` -> `subtle`,
else `sensitivity >= 1.5` -> `strong`, else `normal`) with `motion.idle`/
`motion.music` defaulted. An already-v2 file is left alone; the daemon never
creates the GUI-owned file. A stable box that skipped v1 has no `stage.json` but
still carries the retired `depth.json`/`parallax.json`; those are folded instead
(model+matting -> `quality`, higher tier winning; `feather` -> `edge`;
`shadow`/`shadowAngle` scalars kept, per-layer arrays skipped).

## Registry: per-wallpaper stage

`~/.local/state/ryoku/stage-walls.json`:

```
{ "current": "<path>",
  "walls": { "<path>": {
      "effect": "off|depth|parallax",
      "layers": [ { "out": "<png>", "label": "Subject", "enabled": true,
                    "front": true, "depth": 0.5 }, ... ] } } }
```

`layers[0]` is always the subject the engine cut (`subject.png`); every
later entry is a picture the user added (`layer-NN.png`, cut from a picture
or dropped in as a PNG). `front` is behind/in front of the widgets; `depth`
0..1 is near..far for Parallax drift. The v1 registry is folded once, gated by
`~/.local/state/ryoku/migrations/ryostage-v2`: `effect: subject` becomes
`depth`, a `scene` order reduces to each layer's `front` (a layer listed after
any `widget:*` token is `front: true`), a v1 `depthFactor` becomes `depth`, and
`mode`, `scene` and the other per-layer knobs are dropped. A v1 manual wall's
`layer-NN.png` entries are kept after a prepended subject slot. Under the same
marker and before the v1 fold, the retired Depth (`depth-walls.json` +
`~/Pictures/Depth`) and Parallax (`layers.pz` + `~/Pictures/Parallax`) state a
stable box still carries is folded in for walls v1 has not claimed, its
artifacts moved by rename into `~/Pictures/Stage/<stem>/`, so both upgrade paths
converge on one registry.

## Rendering: `modules/stage/`

One surface, one stack. The desktop surface draws, back to front:
`StageBackdrop.qml` (Parallax only: the inpainted `background.png`, sized with
the wallpaper's own fit and drifting with the cursor, so it covers the
wallpaper's baked subject and can never misalign with ryogami's surface), then
the layers marked behind the widgets (z 2), then the widgets (z 3), then the
layers marked in front (`StageLayer.qml`: edge, shadow and angle from the global
look, drift by the layer's `depth` x the shared motion Amount x Sensitivity x
Range while Follow mouse is on, idle and music; z 4), then any widget the user
lifted into `front` (z 5). Depth is the same
stack with `motionEnabled: false` and no backdrop, so the still cut is
pixel-locked over the wallpaper's own subject. While the stage is on and the
visualizer is `On desktop`, the desktop hosts the visualizer inside this stack
(`InlineVisualizer` at z 1.5: above the backdrop, below every cut-out and
widget) and the visualizer's own surface is suppressed (cava keeps running);
`Above windows` and the Placer use that surface as before. There is no second
subject renderer, and no path that can draw the subject twice.
While the engine cuts, the subject layer dims and draws its own progress ring.

Hub's Desktop Scene page sits beside the stack, not in it. It reads stage.json
and sends typed `stage-settings` IPC requests to the shell's canonical
`modules/stage/Singletons/Config.qml`; per-wallpaper changes go through the
daemon's `StageBackend` contract. Drag updates coalesce before being sent.
The desktop mounts `modules/desktop/WidgetEditBar.qml`, the widget outlines,
and the picker, and lifts to the Top layer for the edit session. Reset writes
each store as one update: bursts of single-key writes can interleave with a
watcher's reload of an older version and put an old value back.

## Delivery

`ryostage` ships in `ryoku-shell` (`/usr/bin/ryostage`) and via `deploy.sh`;
the QML in `ryoku-desktop`. `tests/shell-tool-availability.sh` gates
`[stage-engine]=ryostage` is not needed (the runtime is opt-in), but the helper
must be on both install paths, which the delivery check enforces.

## Verification

- Daemon: `go build ./...` and its unit tests: the `stage` topic carries the
  frame fields, the worker coalesces off the wallpaper hot path, and the registry
  parses.
- Doctor: hermetic Go tests for the rail migration (retired `depth`/`parallax`
  fold to one `stage` tab, idempotent), the settings migration, and the
  `ryostage cache` reclaim.
- QML: `qmllint` on the new and edited `modules/stage/` files.
- Engine: `bash -n` + shellcheck on `ryostage`; `check`, `models --json` and a
  `cut` against a provisioned cache.
- Delivery: `ryostage` is on both install paths (`deploy.sh` and the
  `ryoku-shell` PKGBUILD), enforced by the delivery check.
- The live visual result and real cut quality need a running session with the
  engine provisioned, exercised on the dev box via `dev-run.sh`.
