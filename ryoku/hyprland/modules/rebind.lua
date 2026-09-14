--[[
rebinds.lua is generated from the neutral store's desktop.keybindRebinds and maps
a shipped chord to a user-chosen one, e.g. { ["SUPER + Q"] = "SUPER + X" }.

K() wraps every bind's key argument, so a rebind is a pure key swap: the default
chord is never registered and the dispatcher never moves. Absent or malformed,
K() is the identity and every shortcut keeps its shipped default.

Every module that registers a bind must go through K(), or a rebind would add a
second handler instead of moving the first.
]]
local ok, rebinds = pcall(require, "rebinds")
if not ok or type(rebinds) ~= "table" then rebinds = {} end

return function(k) return rebinds[k] or k end
