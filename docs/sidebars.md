# Sidebars

Ryoku has two global sidebar surfaces. They are part of the shell rather than a
bar style, so every bar uses the same pair:

- `Super+Escape` opens the **Control center** on the left screen edge.
- `Super+S` opens **Companion** on the right screen edge.

Both open on the focused display. Repeating the shortcut or using the close
button closes the surface. Escape also closes it. Either unpinned sidebar closes
on an outside click.

The shell keeps the old shortcut command names at its boundary so compositor
binds do not need special cases. In
`ryoku/shell/quickshell/shell/shell.qml`, `quicksettings` routes to
`sidebar-left` and `stash` routes to `sidebar-right`. Capture, compress, and
install requests use the same surface bus to open the relevant section.

## Surfaces

`ryoku/shell/quickshell/shell/modules/sidebar/Sidebar.qml` owns both overlays.
Each uses one `PanelWindow` on `WlrLayer.Overlay`, above normal and fullscreen
windows, with no exclusive zone. The visible panel stays clear of bars and
other screen rails and defaults to vertical centering on its own screen edge.
The layer-shell namespaces are `ryoku-sidebar-left` and `ryoku-sidebar-right`.

An unpinned sidebar catches outside presses in the same window that draws its
content. **Keep open** limits the input region to the visible panel instead, so
the rest of the desktop remains usable. Screen rails remain outside the input
region in either mode.

Both surfaces use `SidebarFrame.qml`: a rounded paper-and-ink boundary, larger
headings, readable controls, and a vertical section rail. Neither is a native
floating window. Size, placement, and contents are edited in Ryoku Hub.

## Contents and customization

The built-in catalog contains nine sections:

| Id | Label | Default surface | Contents |
|---|---|---|---|
| `system` | System | Control center | Connectivity, audio, brightness, battery, power profile, and session controls |
| `notifications` | Notifications | Control center | Notification history and do-not-disturb |
| `weather` | Weather | Control center | Current conditions, hourly forecast, daily ranges, and air conditions |
| `media` | Media | Control center | Active-player metadata and transport controls |
| `capture` | Capture | Control center | Screenshot and recording targets, destinations, and capture options |
| `stage` | Stage | Control center | Wallpaper preview, scene status, widgets, and visualizer overview |
| `usage` | Usage | Companion | Current and historical screen-time summaries |
| `tools` | Tools | Companion | Downloads, recent jobs, compression, and package installation |
| `chat` | Chat | Companion | Persistent Rashin conversation UI |

**Ryoku Hub > Sidebars > Contents** lists all nine built-ins and installed
`sidebarCard` plugins. A user can hide an entry, move it up or down, move it
between sides, and choose its **Summary** or **Full controls** presentation.
The ordered `cards` arrays are authoritative: omitted built-ins stay hidden and
are not silently appended.

Summary is a section's compact view; Full controls exposes its complete view.
A plugin may implement its own compact view. If it does not, the host shows the
manifest name and description for Summary while keeping the one real widget
instance loaded and unchanged for Full controls.

## Daily controls

System is a dashboard rather than a list of settings. Its Wi-Fi and Bluetooth
tiles open device lists inside the sidebar: scan for networks or devices,
connect to a network with a password when needed, and pair or connect a device.
Audio, brightness, power, and session controls stay alongside the status readouts.

The **Audio mixer** button below volume and microphone opens controls for output
devices, microphones, playing apps, and recording apps. Each source has its own
mute, slider, editable percentage, and 1% steps. Changing a level keeps its mute
state. **Use** selects the default output or microphone. Hover, press, and page
animations respect reduced motion.

Weather combines current conditions, the next hours, daily high/low ranges, and
humidity, wind, precipitation, visibility, UV, and pressure. Its settings button
opens the weather controls in Hub.

Capture separates screenshots from recordings. Target tiles choose a display,
window, or region; screenshot options choose the clipboard, a folder, or both,
and optional annotation. Recording options include desktop audio and microphone;
the detailed recorder settings open in Hub.

Stage is an overview, not a second editor. It shows the current wallpaper,
scene mode, enabled widgets, and visualizer state. **Edit scene**, **Visualizer**,
and **Widgets** open the matching **Ryoku Hub > Desktop Scene** view.

## Size and behavior

**Ryoku Hub > Sidebars > Layout & behavior** provides:

- compact and roomy presets, plus exact width and height;
- **Fit content** or **Fixed size** height;
- a maximum screen-height percentage in either height mode;
- top, center, or bottom alignment on the sidebar's own screen edge;
- **Keep open** pinning; and
- quick, standard, or calm opening and closing motion.

Both sides default to 1040 logical pixels wide, a height of 1000, and an 85%
screen-height limit. Actual dimensions are clamped to the available display area
after per-display UI scaling. A compact preset uses 720 by 720; roomy uses
1280 by 1100.

Hub's `SidebarWriter.qml` does not treat a successful write call as a saved
setting. It waits for both the daemon reply and the subscribed settings frame to
contain the expected value. The editor shows a saving state while confirmation
is pending and reports rejection or timeout without replacing its last confirmed
settings.

Both panels fade and settle in from their own screen edge. Section pages
crossfade, and controls provide hover and focus feedback. Opening and closing
use the selected `sidebars.motion` tempo. Every surface and chrome animation is
gated by both `Motion.reduce` and `Tokens.reduceMotion`; either reduced-motion
flag turns the animation into an immediate state change.

## Settings

The normalized settings live under `sidebars` in `shell.json`:

```json
"sidebars": {
  "motion": "standard",
  "left": {
    "enabled": true,
    "cards": ["system", "notifications", "weather", "media", "capture", "stage"],
    "width": 1040,
    "height": 1000,
    "heightMode": "fixed",
    "maxHeight": 85,
    "position": "center",
    "pinned": false,
    "presentations": {}
  },
  "right": {
    "enabled": true,
    "cards": ["usage", "tools", "chat"],
    "width": 1040,
    "height": 1000,
    "heightMode": "fixed",
    "maxHeight": 85,
    "position": "center",
    "pinned": false,
    "presentations": {}
  }
}
```

`presentations` maps a built-in or plugin id to `summary` or `expanded`; the
editor labels the latter Full controls. Width is clamped to 300–1440 for the
Control center and 380–1440 for Companion; height is 260–1200 and `maxHeight` is 40–95.
The doctor removes retired native-window geometry and converts old corner
positions to top or bottom alignment.

`ryoku/shell/framebars/Sidebars.js` owns these defaults and normalizes persisted
values through `Ryoku.FrameBars.Sidebars`. `Config.qml` exposes `Config.sidebars`;
`ryoku/shell/ipc/settings.go` remains the sole writer for patches.

## Section host contract

A built-in section is an `Item` with `pragma ComponentBehavior: Bound`.
`SidebarCardHost.qml` supplies:

| Member | Direction | Meaning |
|---|---|---|
| `s: real` | host to section | Per-display UI scale |
| `open: bool` | host to section | Whether its surface is requested open |
| `reveal: real` | host to section | Current reveal progress from 0 to 1 |
| `tabActive: bool` | host to section | Whether its section is selected |
| `compact: bool` | host to section | Summary when true, Expanded when false |
| `viewportHeight: real` | host to section | Height available below the shared chrome |
| `width` | host to section | Host-managed width; report `implicitHeight` |
| `index: int` | host to section, when declared | Position in a grouped section |
| `page: string` | host to section, when declared | Optional deep link such as a Tools action |
| `requestClose()` | section to host | Ask the owning surface to close |

The host binds these values after loading the catalog source and forwards
`requestClose()`. Sections should stop polling or other live work when `open` or
`tabActive` is false.

Visible built-in content uses `SidebarCardShell.qml` as a small layout scaffold.
It provides an optional heading and summary-aware spacing; the surface frame
and chrome own the visual boundary.

Plugins have a narrower public contract. See
[`docs/plugins.md`, section 4](plugins.md#4-sidebar-card---lives-in-a-global-sidebar)
for its entry points, optional compact contract, placement, and `pluginApi`.

## Adding a built-in section

1. Add one component under
   `ryoku/shell/quickshell/shell/modules/sidebar/cards/`.
2. Declare the host members above, report content height through
   `implicitHeight`, and put visible content in `SidebarCardShell`.
3. Add its id, default surface, label, glyph, and source to
   `SidebarCatalog.js`.
4. Add the id to the appropriate defaults in `ryoku/shell/framebars/Sidebars.js`
   only if it should ship selected. Keep Hub's customization choices in sync.

## File map

| Path | Responsibility |
|---|---|
| `ryoku/shell/quickshell/shell/modules/sidebar/Sidebar.qml` | Left and right overlays, screen bounds, input region, and dismissal |
| `ryoku/shell/quickshell/shell/modules/sidebar/SidebarFrame.qml` | Shared rounded paper/ink frame |
| `ryoku/shell/quickshell/shell/modules/sidebar/SidebarChrome.qml` | Header, section navigation, scrolling content, and customization entry points |
| `ryoku/hub/quickshell/pages/SidebarsPage.qml` | Contents and layout/behavior editor |
| `ryoku/hub/quickshell/pages/SidebarWriter.qml` | Confirmed daemon writes |
| `ryoku/shell/quickshell/shell/modules/sidebar/SidebarCardHost.qml` | Built-in and plugin loading plus host-property binding |
| `ryoku/shell/quickshell/shell/modules/sidebar/SidebarCardShell.qml` | Built-in heading and content layout scaffold |
| `ryoku/shell/quickshell/shell/modules/sidebar/SidebarCatalog.js` | Nine-section built-in registry |
| `ryoku/shell/framebars/Sidebars.js` | Shared defaults and settings normalization |
| `ryoku/shell/quickshell/shell/modules/sidebar/SidebarPlugins.qml` | Installed `sidebarCard` discovery and ordering |
| `ryoku/shell/quickshell/shell/services/SidebarState.qml` | Per-display open state, selected section, motion, and surface-bus handling |
