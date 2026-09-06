-- A hotplug redoes DPI autoscale. On add, login alone misses the new output's
-- scale; on remove (undock), the monitors that stay keep the gone display's
-- position, so autoscale re-lays them out from x=0 and re-scales -- unplugging an
-- external no longer strands the remaining panel at an offset. The wallpaper is
-- Ryogami's now: it adopts a hotplugged output and tears down a removed one on
-- its own, so no repaint nudge is sent from here (a live scale change is not yet
-- re-fit -- a known renderer gap).
local function rescale()
    hl.exec_cmd("command -v ryoku-monitor >/dev/null 2>&1 && ryoku-monitor autoscale")
end
hl.on("monitor.added", rescale)
hl.on("monitor.removed", rescale)
