-- The touchpad lock (FN key, ryoku-cmd-touchpad) is a runtime override: the
-- compositor re-enables every pad when it reads its config, so a stored "off"
-- must be pushed back after boot and after every reload -- otherwise the
-- status reads "off" while the pad still moves (#207). The script owns the
-- state and the flip; this module only re-asserts it at those two moments,
-- silently, and is a no-op when nothing was ever turned off.
local function restore()
    hl.exec_cmd("command -v ryoku-cmd-touchpad >/dev/null 2>&1 && ryoku-cmd-touchpad restore")
end

hl.on("hyprland.start", restore)
hl.on("config.reloaded", restore)
