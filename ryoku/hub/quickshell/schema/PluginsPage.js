.pragma library
.import "CursorPage.js" as Cursor
.import "AnimationsPage.js" as Animations

// PluginsPage as data: the Hyprland compositor plugins Ryoku bundles, one tab
// each. The tab titles are the names `ryoku-hub desktop plugins list` reports, so
// the page pairs a tab with its plugin's status card. Cursor motion and Focus
// flash keep their rows on the Cursor and Animations pages (where they belong
// in context) and are borrowed here, re-tabbed, so each row is written once.
// A plugin the user adds from git gets its rows from the settings the backend
// detects in its .so; those are built by the page, not listed here.

var plugins = [
    { "id": "hyprbars", "tab": "Title bars" },
    { "id": "hyprglass", "tab": "Glass" },
    { "id": "imgborders", "tab": "Image borders" },
    { "id": "dynamic-cursors", "tab": "Cursor motion" },
    { "id": "hyprfocus", "tab": "Focus flash" },
    { "id": "keysounds", "tab": "Key sounds" }
];

var rows = [
    {
        "tab": "Title bars",
        "group": "TITLE BARS",
        "key": "wm.hyprland.plugins.hyprbars.enabled",
        "label": "Window title bars",
        "desc": "Adds a bar with the window's title above it, applies on Save",
        "ctl": "sw",
        "src": "desktop.json",
        "caps": "plugins"
    },
    {
        "tab": "Title bars",
        "group": "TITLE BARS",
        "key": "wm.hyprland.plugins.hyprbars.height",
        "label": "Bar height",
        "desc": "Vertical space the title bar takes on each window",
        "ctl": "step",
        "src": "desktop.json",
        "caps": "plugins",
        "lo": 12.0,
        "hi": 48.0,
        "unit": "px",
        "when": { "wm.hyprland.plugins.hyprbars.enabled": [true] }
    },
    {
        "tab": "Title bars",
        "group": "TITLE BARS",
        "key": "wm.hyprland.plugins.hyprbars.textSize",
        "label": "Title text size",
        "desc": "How big the window's name renders in the bar",
        "ctl": "step",
        "src": "desktop.json",
        "caps": "plugins",
        "lo": 8.0,
        "hi": 20.0,
        "unit": "px",
        "when": { "wm.hyprland.plugins.hyprbars.enabled": [true] }
    },
    {
        "tab": "Title bars",
        "group": "TITLE BARS",
        "key": "wm.hyprland.plugins.hyprbars.blur",
        "label": "Blur the bar",
        "desc": "The bar goes translucent and blurs whatever sits behind it",
        "ctl": "sw",
        "src": "desktop.json",
        "caps": "plugins",
        "when": { "wm.hyprland.plugins.hyprbars.enabled": [true] }
    },
    {
        "tab": "Title bars",
        "group": "TITLE BARS",
        "key": "wm.hyprland.plugins.hyprbars.buttons",
        "label": "Close and maximise buttons",
        "desc": "Coloured dots on the bar: red closes, green goes fullscreen",
        "ctl": "sw",
        "src": "desktop.json",
        "caps": "plugins",
        "when": { "wm.hyprland.plugins.hyprbars.enabled": [true] }
    },
    {
        "tab": "Glass",
        "group": "GLASS",
        "key": "wm.hyprland.plugins.hyprglass.enabled",
        "label": "Liquid glass windows",
        "desc": "Blur with glass-like refraction on windows, applies on Save",
        "ctl": "sw",
        "src": "desktop.json",
        "caps": "plugins"
    },
    {
        "tab": "Glass",
        "group": "GLASS",
        "key": "wm.hyprland.plugins.hyprglass.preset",
        "label": "Preset",
        "desc": "Starting glass character, from nearly clear to heavy frosting",
        "ctl": "seg",
        "src": "desktop.json",
        "caps": "plugins",
        "opts": [
            "clear",
            "subtle",
            "high_contrast",
            "glass"
        ],
        "when": { "wm.hyprland.plugins.hyprglass.enabled": [true] }
    },
    {
        "tab": "Glass",
        "group": "GLASS",
        "key": "wm.hyprland.plugins.hyprglass.blurStrength",
        "label": "Blur strength",
        "desc": "How heavily the glass frosts what is behind the window",
        "ctl": "step",
        "src": "desktop.json",
        "caps": "plugins",
        "lo": 0.0,
        "hi": 5.0,
        "when": { "wm.hyprland.plugins.hyprglass.enabled": [true] }
    },
    {
        "tab": "Glass",
        "group": "GLASS",
        "key": "wm.hyprland.plugins.hyprglass.opacity",
        "label": "Glass opacity",
        "desc": "How visible the glass pane is over the window",
        "ctl": "slid",
        "src": "desktop.json",
        "caps": "plugins",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true,
        "when": { "wm.hyprland.plugins.hyprglass.enabled": [true] }
    },
    {
        "tab": "Glass",
        "group": "GLASS",
        "key": "wm.hyprland.plugins.hyprglass.brightness",
        "label": "Glass brightness",
        "desc": "Brightness of the glass effect",
        "ctl": "slid",
        "src": "desktop.json",
        "caps": "plugins",
        "lo": 0.0,
        "hi": 2.0,
        "adv": true,
        "when": { "wm.hyprland.plugins.hyprglass.enabled": [true] }
    },
    {
        "tab": "Glass",
        "group": "GLASS",
        "key": "wm.hyprland.plugins.hyprglass.theme",
        "label": "Glass theme",
        "desc": "Light or dark base for the glass tint",
        "ctl": "seg",
        "src": "desktop.json",
        "caps": "plugins",
        "opts": [
            "dark",
            "light"
        ],
        "adv": true,
        "when": { "wm.hyprland.plugins.hyprglass.enabled": [true] }
    },
    {
        "tab": "Glass",
        "group": "GLASS",
        "key": "wm.hyprland.plugins.hyprglass.tint",
        "label": "Glass tint",
        "desc": "Color washed over the glass",
        "ctl": "color",
        "src": "desktop.json",
        "caps": "plugins",
        "adv": true,
        "when": { "wm.hyprland.plugins.hyprglass.enabled": [true] }
    },
    {
        "tab": "Image borders",
        "group": "IMAGE",
        "key": "wm.hyprland.plugins.imgborders.enabled",
        "label": "Image border around windows",
        "desc": "Tiles a picture around each window as its frame, applies on Save",
        "ctl": "sw",
        "src": "desktop.json",
        "caps": "plugins"
    },
    {
        "tab": "Image borders",
        "group": "IMAGE",
        "key": "wm.hyprland.plugins.imgborders.image",
        "label": "Border image",
        "desc": "The picture tiled around windows, takes effect on Save",
        "eg": "~/Pictures/frame.png",
        "ctl": "text",
        "src": "desktop.json",
        "caps": "plugins",
        "when": { "wm.hyprland.plugins.imgborders.enabled": [true] }
    },
    {
        "tab": "Image borders",
        "group": "IMAGE",
        "key": "wm.hyprland.plugins.imgborders.scale",
        "label": "Border scale",
        "desc": "Grows or shrinks the tiled picture around each window",
        "ctl": "step",
        "src": "desktop.json",
        "caps": "plugins",
        "lo": 0.5,
        "hi": 3.0,
        "when": { "wm.hyprland.plugins.imgborders.enabled": [true] }
    },
    {
        "tab": "Image borders",
        "group": "IMAGE",
        "key": "wm.hyprland.plugins.imgborders.smooth",
        "label": "Smooth scaling",
        "desc": "Filters the picture when scaled, off keeps hard pixel edges",
        "ctl": "sw",
        "src": "desktop.json",
        "caps": "plugins",
        "adv": true,
        "when": { "wm.hyprland.plugins.imgborders.enabled": [true] }
    },
    {
        "tab": "Image borders",
        "group": "IMAGE",
        "key": "wm.hyprland.plugins.imgborders.blur",
        "label": "Blur border image",
        "desc": "Blur what shows through a transparent border image",
        "ctl": "sw",
        "src": "desktop.json",
        "caps": "plugins",
        "adv": true,
        "when": { "wm.hyprland.plugins.imgborders.enabled": [true] }
    },
    {
        "tab": "Image borders",
        "group": "IMAGE",
        "key": "wm.hyprland.plugins.imgborders.sizes",
        "label": "Border sizes",
        "desc": "Edge thicknesses as left,right,top,bottom in pixels",
        "eg": "4,4,4,4",
        "ctl": "text",
        "src": "desktop.json",
        "caps": "plugins",
        "adv": true,
        "when": { "wm.hyprland.plugins.imgborders.enabled": [true] }
    },
    {
        "tab": "Image borders",
        "group": "IMAGE",
        "key": "wm.hyprland.plugins.imgborders.insets",
        "label": "Border insets",
        "desc": "How far the image tucks under the window, left,right,top,bottom",
        "eg": "0,0,0,0",
        "ctl": "text",
        "src": "desktop.json",
        "caps": "plugins",
        "adv": true,
        "when": { "wm.hyprland.plugins.imgborders.enabled": [true] }
    },
    {
        "tab": "Key sounds",
        "group": "KEY SOUNDS",
        "key": "wm.hyprland.plugins.keysounds.enabled",
        "label": "Keyboard sounds",
        "desc": "Plays a sound on every key press, in every app, applies on Save",
        "ctl": "sw",
        "src": "desktop.json",
        "caps": "plugins"
    },
    {
        "tab": "Key sounds",
        "group": "KEY SOUNDS",
        "key": "wm.hyprland.plugins.keysounds.profile",
        "label": "Sound profile",
        "desc": "Which switch you hear, real recordings; a Mechvibes pack of your own becomes a profile with ryoku-keysounds-import",
        "ctl": "seg",
        "src": "desktop.json",
        "caps": "plugins",
        "opts": [
            "cherry-mx-blue",
            "cherry-mx-brown",
            "cherry-mx-black",
            "cherry-mx-red",
            "topre",
            "creamy",
            "nk-cream",
            "holy-panda",
            "tealios",
            "crystal-purple",
            "oreo"
        ],
        "when": { "wm.hyprland.plugins.keysounds.enabled": [true] }
    },
    {
        "tab": "Key sounds",
        "group": "KEY SOUNDS",
        "key": "wm.hyprland.plugins.keysounds.volume",
        "label": "Volume",
        "desc": "How loud the samples play, relative to how they were made",
        "ctl": "slid",
        "src": "desktop.json",
        "caps": "plugins",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true,
        "when": { "wm.hyprland.plugins.keysounds.enabled": [true] }
    },
    {
        "tab": "Key sounds",
        "group": "KEY SOUNDS",
        "key": "wm.hyprland.plugins.keysounds.release",
        "label": "Key release sound",
        "desc": "Also play a softer sample when a key comes back up",
        "ctl": "sw",
        "src": "desktop.json",
        "caps": "plugins",
        "when": { "wm.hyprland.plugins.keysounds.enabled": [true] }
    }
];

// the rows another page owns, shown here under that plugin's tab
function borrow(source, prefix, tab) {
    return source.filter(function (r) { return r.key && r.key.indexOf(prefix) === 0; })
        .map(function (r) { var c = Object.assign({}, r); c.tab = tab; return c; });
}

// the sheet's rows in the plugins' order above (the tab strip follows the
// first row of each tab); rows inside a tab keep their written order
var sheetRows = rows
    .concat(borrow(Cursor.rows, "wm.hyprland.plugins.dynamicCursors.", "Cursor motion"))
    .concat(borrow(Animations.rows, "wm.hyprland.plugins.hyprfocus.", "Focus flash"))
    .map(function (r, i) { return { r: r, i: i, t: plugins.findIndex(function (p) { return p.tab === r.tab; }) }; })
    .sort(function (a, b) { return a.t - b.t || a.i - b.i; })
    .map(function (x) { return x.r; });
