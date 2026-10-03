{ ... }:

{
  # Ryoku ISO live-session / installer profile.
  #
  # This file is intentionally small. The maintainer-owned ISO configuration
  # can grow here without changing the reproducible boot/build foundation in
  # base.nix. Good candidates for this layer are:
  #
  # - graphical live session / compositor
  # - installer UI and autostart
  # - branding, wallpaper and greeter
  # - target installation defaults
  # - hardware convenience packages needed only by the live image
}
