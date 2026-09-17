.pragma library

// WidgetsPage as data. Each widget keeps its own tab; a tab's rows fall into a
// handful of honest clusters (WIDGET, TIME & DATE, SIZE & SHAPE, PLACEMENT).
// Free-anchor X/Y gate on their own anchor, the clock's radius on its background,
// and the rare desktop lock is an Advanced row, so a normal PLACEMENT card reads
// as one Anchor control. Descriptions are one line each and none is shared.

var rows = [
    {
        "tab": "clock",
        "group": "WIDGET",
        "key": "clockEnabled",
        "label": "Enabled",
        "desc": "Shows the clock; your settings are kept while off",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "clock",
        "group": "WIDGET",
        "key": "clockDesign",
        "label": "Face",
        "desc": "How the time is drawn: digits, analog, flip and more",
        "ctl": "chips",
        "src": "widgets.json",
        "opts": [
            "digital",
            "minimal",
            "grand",
            "column",
            "outline",
            "banner",
            "analog",
            "flip",
            "rings",
            "bighour",
            "metal",
            "goodnight"
        ]
    },
    {
        "tab": "clock",
        "group": "WIDGET",
        "key": "clockAccent",
        "label": "Accent",
        "desc": "Palette follows the wallpaper; mono stays grey",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "palette",
            "brand",
            "mono"
        ]
    },
    {
        "tab": "clock",
        "group": "WIDGET",
        "key": "widgetFont",
        "label": "Widget font",
        "desc": "Font for every desktop widget; blank uses Space Grotesk",
        "ctl": "pick",
        "src": "widgets.json",
        "opts": []
    },
    {
        "tab": "clock",
        "group": "TIME & DATE",
        "key": "clock24h",
        "label": "24-hour clock",
        "desc": "Shows 14:30 rather than 2:30 pm on the face",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "clock",
        "group": "TIME & DATE",
        "key": "clockSeconds",
        "label": "Show seconds",
        "desc": "Adds seconds to the readout; the face ticks each second",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "clock",
        "group": "TIME & DATE",
        "key": "dateShow",
        "label": "Show date",
        "desc": "Adds today's date beside or under the time",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "clock",
        "group": "TIME & DATE",
        "key": "dateDesign",
        "label": "Date style",
        "desc": "How the date sits with the time: inline, badge or stacked",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "inline",
            "badge",
            "stacked"
        ]
    },
    {
        "tab": "clock",
        "group": "SIZE & SHAPE",
        "key": "clockScale",
        "label": "Size",
        "desc": "Scales the clock; 100% is its designed size",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.5,
        "hi": 2.5
    },
    {
        "tab": "clock",
        "group": "SIZE & SHAPE",
        "key": "clockBg",
        "label": "Background",
        "desc": "Panel behind the clock; none sits on the wallpaper",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": [
            "none",
            "card",
            "glass"
        ]
    },
    {
        "tab": "clock",
        "group": "SIZE & SHAPE",
        "key": "clockRadius",
        "label": "Corner radius",
        "desc": "Rounds the panel corners; needs a card or glass background",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.0,
        "hi": 60.0,
        "unit": "px",
        "when": { "clockBg": ["card", "glass"] }
    },
    {
        "tab": "clock",
        "group": "SIZE & SHAPE",
        "key": "clockOpacity",
        "label": "Opacity",
        "desc": "Fades the clock; a floor keeps it from vanishing",
        "ctl": "slid",
        "src": "widgets.json",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "clock",
        "group": "PLACEMENT",
        "key": "clockAnchor",
        "label": "Anchor",
        "desc": "Where the clock sits; Auto finds a calm spot, Free X/Y",
        "ctl": "pick",
        "src": "widgets.json",
        "opts": [
            "auto",
            "top-left",
            "top",
            "top-right",
            "left",
            "center",
            "right",
            "bottom-left",
            "bottom",
            "bottom-right",
            "free"
        ]
    },
    {
        "tab": "clock",
        "group": "PLACEMENT",
        "key": "clockX",
        "label": "X",
        "desc": "Clock's distance from the left edge, in pixels",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.0,
        "hi": 5000.0,
        "unit": "px",
        "when": { "clockAnchor": ["free"] }
    },
    {
        "tab": "clock",
        "group": "PLACEMENT",
        "key": "clockY",
        "label": "Y",
        "desc": "Clock's distance from the top edge, in pixels",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.0,
        "hi": 5000.0,
        "unit": "px",
        "when": { "clockAnchor": ["free"] }
    },
    {
        "tab": "clock",
        "group": "PLACEMENT",
        "key": "clockLocked",
        "label": "Lock on desktop",
        "desc": "Blocks dragging the clock on the desktop",
        "ctl": "sw",
        "src": "widgets.json",
        "adv": true
    },
    {
        "tab": "calendar",
        "group": "WIDGET",
        "key": "calendarEnabled",
        "label": "Enabled",
        "desc": "Shows the calendar; your settings are kept while off",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "calendar",
        "group": "WIDGET",
        "key": "calendarStyle",
        "label": "Style",
        "desc": "Glass follows the wallpaper tint; Paper is opaque",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": ["glass", "paper"]
    },
    {
        "tab": "calendar",
        "group": "CALENDAR",
        "key": "calendarWeeks",
        "label": "Minimum weeks",
        "desc": "Fewest week rows; the view grows when a month needs more",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 4,
        "hi": 8
    },
    {
        "tab": "calendar",
        "group": "CALENDAR",
        "key": "calendarWeekNumbers",
        "label": "ISO week numbers",
        "desc": "Adds the week-of-year column left of the grid",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "calendar",
        "group": "CALENDAR",
        "key": "calendarHolidayRegion",
        "label": "Holiday region",
        "desc": "Blank uses your locale; else a code like US or US-CA",
        "ctl": "text",
        "src": "widgets.json"
    },
    {
        "tab": "calendar",
        "group": "SIZE & SHAPE",
        "key": "calendarScale",
        "label": "Size",
        "desc": "Scales the calendar; 100% is its designed size",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.5,
        "hi": 2.0
    },
    {
        "tab": "calendar",
        "group": "SIZE & SHAPE",
        "key": "calendarOpacity",
        "label": "Opacity",
        "desc": "Fades the calendar while keeping it readable",
        "ctl": "slid",
        "src": "widgets.json",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "calendar",
        "group": "PLACEMENT",
        "key": "calendarAnchor",
        "label": "Anchor",
        "desc": "Where the calendar sits; Auto finds a calm spot, Free X/Y",
        "ctl": "pick",
        "src": "widgets.json",
        "opts": ["auto", "top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right", "free"]
    },
    {
        "tab": "calendar",
        "group": "PLACEMENT",
        "key": "calendarX",
        "label": "X",
        "desc": "Calendar's distance from the left edge, in pixels",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0,
        "hi": 5000,
        "unit": "px",
        "when": { "calendarAnchor": ["free"] }
    },
    {
        "tab": "calendar",
        "group": "PLACEMENT",
        "key": "calendarY",
        "label": "Y",
        "desc": "Calendar's distance from the top edge, in pixels",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0,
        "hi": 5000,
        "unit": "px",
        "when": { "calendarAnchor": ["free"] }
    },
    {
        "tab": "calendar",
        "group": "PLACEMENT",
        "key": "calendarLocked",
        "label": "Lock on desktop",
        "desc": "Blocks dragging the calendar on the desktop",
        "ctl": "sw",
        "src": "widgets.json",
        "adv": true
    },
    {
        "tab": "music",
        "group": "WIDGET",
        "key": "musicEnabled",
        "label": "Enabled",
        "desc": "Shows the now-playing sheet; settings are kept while off",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "music",
        "group": "WIDGET",
        "key": "musicStyle",
        "label": "Style",
        "desc": "Cover wears the album colour; Glass is a frosted pane",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": ["cover", "glass"]
    },
    {
        "tab": "music",
        "group": "WIDGET",
        "key": "musicLyrics",
        "label": "Lyrics",
        "desc": "Shows synced lyrics beside the album when found",
        "ctl": "sw",
        "src": "widgets.json"
    },
    {
        "tab": "music",
        "group": "WIDGET",
        "key": "musicViz",
        "label": "Visualiser",
        "desc": "Shown when a track has no lyrics: Bars or Wave",
        "ctl": "seg",
        "src": "widgets.json",
        "opts": ["bars", "wave"]
    },
    {
        "tab": "music",
        "group": "WIDGET",
        "key": "musicApp",
        "label": "Music app",
        "desc": "App the corner button opens; blank uses ryotunes",
        "ctl": "app",
        "src": "widgets.json"
    },
    {
        "tab": "music",
        "group": "SIZE & SHAPE",
        "key": "musicScale",
        "label": "Size",
        "desc": "Scales the music sheet; 100% is its designed size",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0.5,
        "hi": 2.0
    },
    {
        "tab": "music",
        "group": "SIZE & SHAPE",
        "key": "musicOpacity",
        "label": "Opacity",
        "desc": "Fades the music sheet while keeping it readable",
        "ctl": "slid",
        "src": "widgets.json",
        "lo": 0.2,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },
    {
        "tab": "music",
        "group": "PLACEMENT",
        "key": "musicAnchor",
        "label": "Anchor",
        "desc": "Where the music sheet sits; Auto picks, Free X/Y",
        "ctl": "pick",
        "src": "widgets.json",
        "opts": ["auto", "top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right", "free"]
    },
    {
        "tab": "music",
        "group": "PLACEMENT",
        "key": "musicX",
        "label": "X",
        "desc": "Music sheet's distance from the left edge, in pixels",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0,
        "hi": 5000,
        "unit": "px",
        "when": { "musicAnchor": ["free"] }
    },
    {
        "tab": "music",
        "group": "PLACEMENT",
        "key": "musicY",
        "label": "Y",
        "desc": "Music sheet's distance from the top edge, in pixels",
        "ctl": "step",
        "src": "widgets.json",
        "lo": 0,
        "hi": 5000,
        "unit": "px",
        "when": { "musicAnchor": ["free"] }
    },
    {
        "tab": "music",
        "group": "PLACEMENT",
        "key": "musicLocked",
        "label": "Lock on desktop",
        "desc": "Blocks dragging the music sheet on the desktop",
        "ctl": "sw",
        "src": "widgets.json",
        "adv": true
    },
    {
        "tab": "aio", "group": "WIDGET", "key": "aioEnabled", "label": "Enabled",
        "desc": "Shows the weather-and-clock card; settings kept while off",
        "ctl": "sw", "src": "widgets.json"
    },
    {
        "tab": "aio", "group": "WIDGET", "key": "aioStyle", "label": "Layout",
        "desc": "Wide is a landscape card; Tall a portrait panel",
        "ctl": "seg", "src": "widgets.json", "opts": ["wide", "tall"]
    },
    {
        "tab": "aio", "group": "SIZE & SHAPE", "key": "aioScale", "label": "Size",
        "desc": "Scales the card; 100% is its designed size",
        "ctl": "step", "src": "widgets.json", "lo": 0.5, "hi": 2.0
    },
    {
        "tab": "aio", "group": "SIZE & SHAPE", "key": "aioOpacity", "label": "Opacity",
        "desc": "Fades the card while keeping it readable",
        "ctl": "slid", "src": "widgets.json", "lo": 0.2, "hi": 1.0, "unit": "%", "pct": true
    },
    {
        "tab": "aio", "group": "PLACEMENT", "key": "aioAnchor", "label": "Anchor",
        "desc": "Where the card sits; Auto finds a calm spot, Free X/Y",
        "ctl": "pick", "src": "widgets.json",
        "opts": ["auto", "top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right", "free"]
    },
    {
        "tab": "aio", "group": "PLACEMENT", "key": "aioX", "label": "X",
        "desc": "Card's distance from the left edge, in pixels",
        "ctl": "step", "src": "widgets.json", "lo": 0, "hi": 5000, "unit": "px",
        "when": { "aioAnchor": ["free"] }
    },
    {
        "tab": "aio", "group": "PLACEMENT", "key": "aioY", "label": "Y",
        "desc": "Card's distance from the top edge, in pixels",
        "ctl": "step", "src": "widgets.json", "lo": 0, "hi": 5000, "unit": "px",
        "when": { "aioAnchor": ["free"] }
    },
    {
        "tab": "aio", "group": "PLACEMENT", "key": "aioLocked", "label": "Lock on desktop",
        "desc": "Blocks dragging the card on the desktop",
        "ctl": "sw", "src": "widgets.json", "adv": true
    },
    {
        "tab": "stats", "group": "WIDGET", "key": "statsEnabled", "label": "Enabled",
        "desc": "Shows the system-stats panel; settings kept while off",
        "ctl": "sw", "src": "widgets.json"
    },
    {
        "tab": "stats", "group": "SIZE & SHAPE", "key": "statsScale", "label": "Size",
        "desc": "Scales the stats panel; 100% is its designed size",
        "ctl": "step", "src": "widgets.json", "lo": 0.5, "hi": 2.0
    },
    {
        "tab": "stats", "group": "SIZE & SHAPE", "key": "statsOpacity", "label": "Opacity",
        "desc": "Fades the stats panel while keeping it readable",
        "ctl": "slid", "src": "widgets.json", "lo": 0.2, "hi": 1.0, "unit": "%", "pct": true
    },
    {
        "tab": "stats", "group": "PLACEMENT", "key": "statsAnchor", "label": "Anchor",
        "desc": "Where the panel sits; Auto finds a calm spot, Free X/Y",
        "ctl": "pick", "src": "widgets.json",
        "opts": ["auto", "top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right", "free"]
    },
    {
        "tab": "stats", "group": "PLACEMENT", "key": "statsX", "label": "X",
        "desc": "Stats panel's distance from the left edge, in pixels",
        "ctl": "step", "src": "widgets.json", "lo": 0, "hi": 5000, "unit": "px",
        "when": { "statsAnchor": ["free"] }
    },
    {
        "tab": "stats", "group": "PLACEMENT", "key": "statsY", "label": "Y",
        "desc": "Stats panel's distance from the top edge, in pixels",
        "ctl": "step", "src": "widgets.json", "lo": 0, "hi": 5000, "unit": "px",
        "when": { "statsAnchor": ["free"] }
    },
    {
        "tab": "stats", "group": "PLACEMENT", "key": "statsLocked", "label": "Lock on desktop",
        "desc": "Blocks dragging the stats panel on the desktop",
        "ctl": "sw", "src": "widgets.json", "adv": true
    },
    {
        "tab": "weather", "group": "WIDGET", "key": "weatherEnabled", "label": "Enabled",
        "desc": "Shows the weather; your settings are kept while off",
        "ctl": "sw", "src": "widgets.json"
    },
    {
        "tab": "weather", "group": "WIDGET", "key": "weatherDesign", "label": "Layout",
        "desc": "Compact is glyph, temp and city; Full adds much more",
        "ctl": "seg", "src": "widgets.json", "opts": ["compact", "full"]
    },
    {
        "tab": "weather", "group": "SIZE & SHAPE", "key": "weatherScale", "label": "Size",
        "desc": "Scales the weather widget; 100% is its designed size",
        "ctl": "step", "src": "widgets.json", "lo": 0.5, "hi": 2.5
    },
    {
        "tab": "weather", "group": "SIZE & SHAPE", "key": "weatherOpacity", "label": "Opacity",
        "desc": "Fades the weather widget while keeping it readable",
        "ctl": "slid", "src": "widgets.json", "lo": 0.2, "hi": 1.0, "unit": "%", "pct": true
    },
    {
        "tab": "weather", "group": "PLACEMENT", "key": "weatherAnchor", "label": "Anchor",
        "desc": "Where weather sits; Auto finds a calm spot, Free X/Y",
        "ctl": "pick", "src": "widgets.json",
        "opts": ["auto", "top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right", "free"]
    },
    {
        "tab": "weather", "group": "PLACEMENT", "key": "weatherX", "label": "X",
        "desc": "Weather's distance from the left edge, in pixels",
        "ctl": "step", "src": "widgets.json", "lo": 0, "hi": 5000, "unit": "px",
        "when": { "weatherAnchor": ["free"] }
    },
    {
        "tab": "weather", "group": "PLACEMENT", "key": "weatherY", "label": "Y",
        "desc": "Weather's distance from the top edge, in pixels",
        "ctl": "step", "src": "widgets.json", "lo": 0, "hi": 5000, "unit": "px",
        "when": { "weatherAnchor": ["free"] }
    },
    {
        "tab": "weather", "group": "PLACEMENT", "key": "weatherLocked", "label": "Lock on desktop",
        "desc": "Blocks dragging weather on the desktop",
        "ctl": "sw", "src": "widgets.json", "adv": true
    },
    {
        "tab": "notes", "group": "WIDGET", "key": "notesEnabled", "label": "Enabled",
        "desc": "Shows the scratch pad; the note is kept while off",
        "ctl": "sw", "src": "widgets.json"
    },
    {
        "tab": "notes", "group": "SIZE & SHAPE", "key": "notesWidth", "label": "Width",
        "desc": "Pad width in pixels, before Size scales it",
        "ctl": "step", "src": "widgets.json", "lo": 160, "hi": 900, "unit": "px"
    },
    {
        "tab": "notes", "group": "SIZE & SHAPE", "key": "notesHeight", "label": "Height",
        "desc": "Pad height in pixels, before Size scales it",
        "ctl": "step", "src": "widgets.json", "lo": 120, "hi": 900, "unit": "px"
    },
    {
        "tab": "notes", "group": "SIZE & SHAPE", "key": "notesScale", "label": "Size",
        "desc": "Scales the pad's width, height and text together",
        "ctl": "step", "src": "widgets.json", "lo": 0.5, "hi": 2.5
    },
    {
        "tab": "notes", "group": "SIZE & SHAPE", "key": "notesOpacity", "label": "Opacity",
        "desc": "Fades the pad while keeping it readable",
        "ctl": "slid", "src": "widgets.json", "lo": 0.2, "hi": 1.0, "unit": "%", "pct": true
    },
    {
        "tab": "notes", "group": "PLACEMENT", "key": "notesAnchor", "label": "Anchor",
        "desc": "Where the pad sits; Auto finds a calm spot, Free X/Y",
        "ctl": "pick", "src": "widgets.json",
        "opts": ["auto", "top-left", "top", "top-right", "left", "center", "right", "bottom-left", "bottom", "bottom-right", "free"]
    },
    {
        "tab": "notes", "group": "PLACEMENT", "key": "notesX", "label": "X",
        "desc": "Notes pad's distance from the left edge, in pixels",
        "ctl": "step", "src": "widgets.json", "lo": 0, "hi": 5000, "unit": "px",
        "when": { "notesAnchor": ["free"] }
    },
    {
        "tab": "notes", "group": "PLACEMENT", "key": "notesY", "label": "Y",
        "desc": "Notes pad's distance from the top edge, in pixels",
        "ctl": "step", "src": "widgets.json", "lo": 0, "hi": 5000, "unit": "px",
        "when": { "notesAnchor": ["free"] }
    },
    {
        "tab": "notes", "group": "PLACEMENT", "key": "notesLocked", "label": "Lock on desktop",
        "desc": "Blocks dragging the pad on the desktop",
        "ctl": "sw", "src": "widgets.json", "adv": true
    }
];
