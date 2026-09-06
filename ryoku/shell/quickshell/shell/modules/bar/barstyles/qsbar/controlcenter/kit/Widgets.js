.pragma library

// Presentation facts about a bar widget that the catalogue (widgets.json, the
// source of ids, labels, glosses and settings) deliberately does not carry: the
// Material Symbols glyph a chip and a row wear, whether icon-only density
// applies, and whether the widget can be hidden at all. Both the Layout lanes and
// the Widgets rows read from here, so a chip and its settings row wear the same
// mark and neither hand-lists a glyph.

// id -> Material Symbols Rounded name (rendered by IconText). A plugin id is not
// here, so it falls back to its label's initial.
var GLYPHS = {
    "launcher":   "apps",
    "workspaces": "grid_view",
    "status":     "notifications",
    "memory":     "memory",
    "cpu":        "developer_board",
    "volume":     "graphic_eq",
    "ai":         "smart_toy",
    "clock":      "schedule",
    "media":      "music_note",
    "quick":      "tune",
    "network":    "signal_wifi_4_bar",
    "battery":    "battery_full",
    "brightness": "brightness_6",
    "power":      "bolt",
    "bluetooth":  "bluetooth",
    "cputemp":    "device_thermostat",
    "gpu":        "view_in_ar",
    "storage":    "storage",
    "layout":     "keyboard"
};

// Built-ins whose bar rendering has an icon-only density (the iconOnlyGids
// mechanism). Status is icon-only by design and the media/now-playing widget
// carries its own style setting instead, so neither offers a density toggle.
var DENSITY = [
    "memory", "cpu", "volume", "network", "battery", "brightness",
    "power", "bluetooth", "gpu", "cputemp", "storage", "layout"
];

// Built-ins with no visibility key are always on the bar (the launcher mark, the
// workspaces, the clock), so their row shows an inert ON switch instead of a
// toggle. Everything else (a built-in with a visKey, any plugin) can be hidden.
var ALWAYS_ON = ["launcher", "workspaces", "clock"];

function glyphFor(id) {
    return GLYPHS[id] !== undefined ? GLYPHS[id] : "";
}

// The one-glyph fallback for a plugin (or any id with no Material mark): its
// label's first letter, so a lane chip is never blank.
function initialFor(label) {
    var s = String(label || "").trim();
    return s.length > 0 ? s.charAt(0).toUpperCase() : "?";
}

function densitySupported(id) {
    return DENSITY.indexOf(id) >= 0;
}

function hideable(id) {
    return ALWAYS_ON.indexOf(id) < 0;
}
