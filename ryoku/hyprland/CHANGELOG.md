# Changelog: ryoku/hyprland/

## Unreleased

### Changed
- **`binds.lua` carries the shared catalogue's new shortcuts.** Page Up/Down
  workspace navigation and sending, screen focus and send with Super+Alt and
  its Shift/Ctrl variants, Alt+Tab for the last window, Super+T group toggle,
  Super+D maximise, Super+C centre, Super+[ ] move-window-or-group, and the
  number pad for workspaces with both NumLock keysyms. Every one goes through
  `K()` so it stays rebindable. The provider's `binds` verb now parses this
  file itself and reports the legend to the Hub (`modules/binds.lua`).
- **`scripts/` keeps only Hyprland's own helpers.** The compositor-neutral leaf
  scripts (`ryoku-app`, the `ryoku-cmd-*` tools, the recorder helpers, folder
  tinting, sysinfo, clamshell) moved to the shell payload and the base hardware
  helpers so every box ships them; `ryoku-monitor`, `ryoku-workspace` and the
  new `ryoku-cursor-track` stay here because they speak Hyprland's IPC. The
  touchpad lock and the game-mode decoration strip are provider actions now
  (`modules/binds.lua`, `modules/touchpad.lua`).
- **`hypridle.conf` is generated, not shipped.** `ryoku-idle` renders the idle
  daemon's config from the Hub's idle policy into `~/.config/ryoku`, with screen
  power routed through the window-manager seam, so the tree no longer carries
  one.

### Fixed
- **Maximize keybinds work again.**
  Ryoku no longer resets every Hyprland mode-1 fullscreen state to normal.
  The old handler worked around Hyprland #13322, which is fixed upstream in
  Hyprland 0.56.0. Removing the workaround restores native maximize behavior
  while leaving fullscreen handling to Hyprland (`hyprland.lua`; removed
  `modules/fullscreen.lua`).

- **Hiding the scratchpad no longer makes the next bar panel pop it open.**
  Super+Alt+H toggled the special workspace through Hyprland directly, which
  leaves keyboard focus on the window it just hid. Any surface that then takes
  and releases a keyboard grab (a qsbar panel, the bar settings menu, a menu
  dismissed by clicking outside) hands focus back to that window, and focusing a
  window on a special workspace shows the workspace: closing a panel revealed the
  scratchpad. The bind now goes through `ryoku-workspace scratch`, which hands
  focus to a window that is actually on screen when it hides the scratchpad, the
  same care the `hide` command already took. It focuses a window rather than the
  workspace on purpose: focusing an empty workspace leaves Hyprland with nothing
  to take the focus, so it keeps the hidden window and re-reveals the scratchpad
  on the spot (`modules/binds.lua`, `scripts/ryoku-workspace`).

- **A chosen icon theme survives login and wallpaper changes.**
  `ryoku-cmd-folders` (run at login and on every palette change) set the
  icon theme back to `ryoku-folders` whenever it differed, so a theme picked
  in the Hub or with gsettings reset on the next login. It now takes the
  setting over only from the shipped defaults (Papirus, Adwaita, hicolor, a
  stale generation name) and leaves any other choice alone
  (`scripts/ryoku-cmd-folders`).

