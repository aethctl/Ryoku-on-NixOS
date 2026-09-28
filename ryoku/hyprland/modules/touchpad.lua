-- The touchpad lock (FN key, input.touchpad) is a runtime override: the
-- compositor re-enables every pad when it reads its config, so a stored "off"
-- must be pushed back after boot and after every reload -- otherwise the
-- status reads "off" while the pad still moves (#207). The window-manager seam
-- owns the state and the flip; this module only re-asserts it at those two
-- moments and is a no-op when nothing was ever turned off. At login the lock is
-- asserted at once and named a moment later, once the shell can show a toast,
-- so a pad left off is never a mystery; a reload stays silent.
hl.on("hyprland.start", function()
    hl.exec_cmd("ryoku wm act input.touchpad restore; sleep 8; ryoku wm act input.touchpad restore login")
end)
hl.on("config.reloaded", function()
    hl.exec_cmd("ryoku wm act input.touchpad restore")
end)
