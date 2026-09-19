# Chroma bar for Ryoku

This folder ports the visual language of `aethctl/chroma-shell`'s Chroma bar onto
Ryoku's bar-style API.

The port deliberately does **not** carry Chroma Shell's old runtime, theme engine,
settings store, notification server, MPRIS picker, CAVA process or Hyprland config.
Ryoku already owns those jobs. The bar binds to `shell.services` instead:

- `Theme` / `Scheme` for live Matugen and named-theme colours
- `Workspaces` + `Quickshell.Hyprland` for workspace state
- `Media` for MPRIS
- `AudioBars` for the playback spectrum
- `Notifs`, `Network`, `Audio`, and `Battery` for status
- `ShellState` for launcher and Ryoku menu surfaces

That keeps Chroma a bar style rather than a second shell embedded inside Ryoku.


## Settings

Chroma stores its live settings under `chroma` in `~/.config/ryoku/shell.json`.
Bar Studio edits its edge, scale, module gap, radius, surface opacity, workspace
labels, clock format and global module visibility live. A display can select
Chroma with `displays.bar_style.<connector>` and override its modules through
`displays.bar_widgets.<connector>.chroma`; missing values inherit the global
choice, preserving the shipped 1.0/full-bar defaults.
