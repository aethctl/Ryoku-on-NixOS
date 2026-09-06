# Changelog: ryoku/hyprland/

## Unreleased

### Fixed
- **A chosen icon theme survives login and wallpaper changes.**
  `ryoku-cmd-folders` (run at login and on every palette change) set the
  icon theme back to `ryoku-folders` whenever it differed, so a theme picked
  in the Hub or with gsettings reset on the next login. It now takes the
  setting over only from the shipped defaults (Papirus, Adwaita, hicolor, a
  stale generation name) and leaves any other choice alone
  (`scripts/ryoku-cmd-folders`).
