.pragma library

var builtIns = [
    { id: "system", label: "System", glyph: "monitor_heart" },
    { id: "notifications", label: "Notifications", glyph: "notifications" },
    { id: "weather", label: "Weather", glyph: "partly_cloudy_day" },
    { id: "media", label: "Media", glyph: "music_note" },
    { id: "capture", label: "Capture", glyph: "screenshot_region" },
    { id: "stage", label: "Stage", glyph: "layers" },
    { id: "usage", label: "Usage", glyph: "query_stats" },
    { id: "tools", label: "Tools", glyph: "construction" },
    { id: "chat", label: "Chat", glyph: "forum" }
];

var rows = [
    { tab: "Contents", group: "SECTIONS", key: "sidebars.left.cards", label: "Controls sections", desc: "Show, order, move, and choose the detail level of every section", src: "shell" },
    { tab: "Contents", group: "SECTIONS", key: "sidebars.right.cards", label: "Companion sections", desc: "Show, order, move, and choose the detail level of every section", src: "shell" },
    { tab: "Layout", group: "FRAME", key: "sidebars.left.width", label: "Controls width", desc: "Exact width, height mode, alignment and screen limit", src: "shell" },
    { tab: "Layout", group: "FRAME", key: "sidebars.right.width", label: "Companion width", desc: "Exact width, height mode, alignment and screen limit", src: "shell" },
    { tab: "Behaviour", group: "OPENING", key: "sidebars.motion", label: "Opening motion", desc: "Quick, standard, or calm opening tempo", src: "shell" },
    { tab: "Behaviour", group: "OPENING", key: "sidebars.left.pinned", label: "Keep Controls open", desc: "Keep the sidebar visible when focus moves away", src: "shell" },
    { tab: "Behaviour", group: "OPENING", key: "sidebars.right.pinned", label: "Keep Companion open", desc: "Keep the sidebar visible when focus moves away", src: "shell" }
];

function builtIn(id) {
    for (var i = 0; i < builtIns.length; ++i) if (builtIns[i].id === id) return builtIns[i];
    return null;
}
