.pragma library

// AppearancePage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [{
        "tab": "Layout",
        "group": "TILING",
        "key": "desktop.appearance.layout",
        "label": "Tiling layout",
        "desc": "How tiles arrange: binary splits, master and stack, or a strip",
        "ctl": "seg",
        "src": "desktop.json",
        "caps": "tiledLayout",
        "opts": [
            "dwindle",
            "master",
            "scrolling"
        ]
    },{
        "tab": "Layout",
        "group": "TILING",
        "ctl": "layoutdemo",
        "label": "",
        "desc": "",
        "src": "desktop.json"
    },{
        "tab": "Layout",
        "group": "TILING",
        "key": "wm.hyprland.plugins.hyprscrolling.columnWidth",
        "label": "Column width",
        "desc": "Share of the screen each column takes, scrolling layout only",
        "ctl": "slid",
        "src": "desktop.json",
        "caps": "tiledLayout",
        "lo": 0.1,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },{
        "tab": "Layout",
        "group": "TILING",
        "key": "wm.hyprland.plugins.hyprscrolling.followFocus",
        "label": "Scroll to follow focus",
        "desc": "The strip scrolls to keep focus in view, scrolling layout only",
        "ctl": "sw",
        "src": "desktop.json",
        "caps": "tiledLayout"
    },{
        "tab": "Layout",
        "group": "DWINDLE",
        "key": "wm.hyprland.dwindle.preserveSplit",
        "label": "Preserve split",
        "desc": "Keep the split direction when windows close and reopen",
        "ctl": "sw",
        "src": "desktop.json",
        "caps": "tiledLayout",
        "adv": true
    },{
        "tab": "Layout",
        "group": "DWINDLE",
        "key": "wm.hyprland.dwindle.smartSplit",
        "label": "Smart split",
        "desc": "Split toward the corner of the window the cursor is nearest",
        "ctl": "sw",
        "src": "desktop.json",
        "caps": "tiledLayout",
        "adv": true
    },{
        "tab": "Layout",
        "group": "DWINDLE",
        "key": "wm.hyprland.dwindle.smartResizing",
        "label": "Smart resizing",
        "desc": "Resize toward the direction of the mouse rather than a fixed edge",
        "ctl": "sw",
        "src": "desktop.json",
        "caps": "tiledLayout",
        "adv": true
    },{
        "tab": "Layout",
        "group": "DWINDLE",
        "key": "wm.hyprland.dwindle.defaultSplitRatio",
        "label": "Default split ratio",
        "desc": "Size a new split gives the new window, 1.0 is even",
        "ctl": "slid",
        "src": "desktop.json",
        "caps": "tiledLayout",
        "lo": 0.1,
        "hi": 1.9,
        "adv": true
    },{
        "tab": "Layout",
        "group": "DWINDLE",
        "key": "wm.hyprland.dwindle.forceSplit",
        "label": "Force split side",
        "desc": "Where a new window always lands: follow the cursor, or force one side",
        "ctl": "seg",
        "src": "desktop.json",
        "caps": "tiledLayout",
        "opts": [
            "follow",
            "left/top",
            "right/bottom"
        ],
        "adv": true
    },{
        "tab": "Layout",
        "group": "DWINDLE",
        "key": "wm.hyprland.dwindle.useActiveForSplits",
        "label": "Split from active",
        "desc": "Base a new split on the active window, not the one under the cursor",
        "ctl": "sw",
        "src": "desktop.json",
        "caps": "tiledLayout",
        "adv": true
    },{
        "tab": "Layout",
        "group": "MASTER",
        "key": "wm.hyprland.master.mfact",
        "label": "Master size",
        "desc": "Share of the screen the master window takes",
        "ctl": "slid",
        "src": "desktop.json",
        "caps": "tiledLayout",
        "lo": 0.1,
        "hi": 0.9,
        "adv": true
    },{
        "tab": "Layout",
        "group": "MASTER",
        "key": "wm.hyprland.master.newStatus",
        "label": "New window role",
        "desc": "Whether a new window becomes master, a slave, or inherits",
        "ctl": "seg",
        "src": "desktop.json",
        "caps": "tiledLayout",
        "opts": [
            "master",
            "slave",
            "inherit"
        ],
        "adv": true
    },{
        "tab": "Layout",
        "group": "MASTER",
        "key": "wm.hyprland.master.newOnTop",
        "label": "New on top",
        "desc": "Put a new slave at the top of the stack instead of the bottom",
        "ctl": "sw",
        "src": "desktop.json",
        "caps": "tiledLayout",
        "adv": true
    },{
        "tab": "Layout",
        "group": "MASTER",
        "key": "wm.hyprland.master.orientation",
        "label": "Master side",
        "desc": "Which side the master column sits on",
        "ctl": "seg",
        "src": "desktop.json",
        "caps": "tiledLayout",
        "opts": [
            "left",
            "right",
            "top",
            "bottom",
            "center"
        ],
        "adv": true
    },{
        "tab": "Layout",
        "group": "MASTER",
        "key": "wm.hyprland.master.smartResizing",
        "label": "Smart resizing",
        "desc": "Resize toward the direction of the mouse rather than a fixed edge",
        "ctl": "sw",
        "src": "desktop.json",
        "caps": "tiledLayout",
        "adv": true
    },{
        "tab": "Layout",
        "group": "GAPS",
        "key": "desktop.appearance.gapsIn",
        "label": "Inner (between windows)",
        "desc": "Space between neighbouring tiled windows",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 40.0,
        "unit": "px"
    },{
        "tab": "Layout",
        "group": "GAPS",
        "key": "desktop.appearance.gapsOut",
        "label": "Outer (screen edge)",
        "desc": "Space between windows and the screen edge",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 60.0,
        "unit": "px"
    },{
        "tab": "Layout",
        "group": "GAPS",
        "key": "desktop.appearance.gapsWorkspaces",
        "label": "Workspace gaps",
        "desc": "Extra gap between workspaces while swiping between them",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 80.0,
        "unit": "px"
    },{
        "tab": "Layout",
        "group": "BEHAVIOUR",
        "key": "desktop.appearance.resizeOnBorder",
        "label": "Drag to resize at window edges",
        "desc": "Grab a window's edge with the mouse to resize it",
        "ctl": "sw",
        "src": "desktop.json"
    },{
        "tab": "Layout",
        "group": "BEHAVIOUR",
        "key": "desktop.appearance.snapEnabled",
        "label": "Snap floating windows",
        "desc": "Dragged floating windows stick to screen edges and other windows",
        "ctl": "sw",
        "src": "desktop.json"
    },{
        "tab": "Layout",
        "group": "BEHAVIOUR",
        "key": "desktop.appearance.extendBorderGrab",
        "label": "Border grab area",
        "desc": "How many pixels past the border still grab it for resizing",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 40.0,
        "unit": "px"
    },{
        "tab": "Layout",
        "group": "BEHAVIOUR",
        "key": "desktop.appearance.hoverIconOnBorder",
        "label": "Resize cursor on border",
        "desc": "Show the resize cursor when hovering a window border",
        "ctl": "sw",
        "src": "desktop.json"
    },{
        "tab": "Layout",
        "group": "BEHAVIOUR",
        "key": "desktop.appearance.noFocusFallback",
        "label": "No focus fallback",
        "desc": "When a window closes, do not fall focus back to the last window under the cursor",
        "ctl": "sw",
        "src": "desktop.json",
        "adv": true
    },{
        "tab": "Layout",
        "group": "BEHAVIOUR",
        "key": "desktop.appearance.resizeCorner",
        "label": "Resize corner",
        "desc": "Force resizing from one corner, 0 is off, 1 to 4 pick a corner",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 4.0,
        "adv": true
    },{
        "tab": "Look",
        "group": "SHAPE",
        "key": "desktop.appearance.rounding",
        "label": "Corner radius",
        "desc": "How rounded window corners are, 0 keeps them square",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 30.0,
        "unit": "px"
    },{
        "tab": "Look",
        "group": "SHAPE",
        "key": "desktop.appearance.roundingPower",
        "label": "Corner softness",
        "desc": "Corner curve shape: 2 is a circle, higher flattens toward square",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 2.0,
        "hi": 8.0
    },{
        "tab": "Look",
        "group": "OPACITY",
        "key": "desktop.appearance.activeOpacity",
        "label": "Active",
        "desc": "How solid the focused window is drawn, below 100% shows through",
        "ctl": "slid",
        "src": "desktop.json",
        "lo": 0.4,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },{
        "tab": "Look",
        "group": "OPACITY",
        "key": "desktop.appearance.inactiveOpacity",
        "label": "Inactive",
        "desc": "How solid unfocused windows are drawn",
        "ctl": "slid",
        "src": "desktop.json",
        "lo": 0.4,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },{
        "tab": "Look",
        "group": "OPACITY",
        "key": "desktop.appearance.dimInactive",
        "label": "Dim inactive windows",
        "desc": "Darkens every window except the focused one",
        "ctl": "sw",
        "src": "desktop.json"
    },{
        "tab": "Look",
        "group": "OPACITY",
        "key": "desktop.appearance.dimStrength",
        "label": "Dim strength",
        "desc": "How dark unfocused windows get while dimming is on",
        "ctl": "slid",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true
    },{
        "tab": "Look",
        "group": "OPACITY",
        "key": "desktop.appearance.fullscreenOpacity",
        "label": "Fullscreen opacity",
        "desc": "Opacity of a window while it is fullscreen",
        "ctl": "slid",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true,
        "adv": true
    },{
        "tab": "Look",
        "group": "OPACITY",
        "key": "desktop.appearance.dimSpecial",
        "label": "Dim special workspaces",
        "desc": "How much the special (scratchpad) workspace dims the desktop behind it",
        "ctl": "slid",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true,
        "adv": true
    },{
        "tab": "Look",
        "group": "OPACITY",
        "key": "desktop.appearance.dimAround",
        "label": "Dim around floating",
        "desc": "How far a floating window with the dim-around rule darkens the rest",
        "ctl": "slid",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 1.0,
        "unit": "%",
        "pct": true,
        "adv": true
    },{
        "tab": "Look",
        "group": "OPACITY",
        "key": "desktop.appearance.dimModal",
        "label": "Dim modal dialogs",
        "desc": "Darken the parent while a modal dialog is open",
        "ctl": "sw",
        "src": "desktop.json",
        "adv": true
    },{
        "tab": "Look",
        "group": "BLUR",
        "key": "desktop.appearance.blurEnabled",
        "label": "Enabled",
        "desc": "Frosted-glass blur behind translucent windows and the shell",
        "ctl": "sw",
        "src": "desktop.json"
    },{
        "tab": "Look",
        "group": "BLUR",
        "key": "desktop.appearance.blurSize",
        "label": "Size",
        "desc": "How far each pass spreads, pair with passes for overall strength",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 20.0,
        "unit": "px"
    },{
        "tab": "Look",
        "group": "BLUR",
        "key": "desktop.appearance.blurPasses",
        "label": "Passes",
        "desc": "Times the blur repeats, more is stronger but costs GPU time",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 1.0,
        "hi": 6.0
    },{
        "tab": "Look",
        "group": "BLUR",
        "key": "desktop.appearance.blurXray",
        "label": "X-ray (blur shows the wallpaper)",
        "desc": "Ignores windows beneath when blurring, lighter on the GPU",
        "ctl": "sw",
        "src": "desktop.json"
    },{
        "tab": "Look",
        "group": "BLUR",
        "key": "desktop.appearance.blurVibrancy",
        "label": "Vibrancy",
        "desc": "Boosts colour saturation seen through the blur",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 0.5
    },{
        "tab": "Look",
        "group": "BLUR",
        "key": "desktop.appearance.blurNoise",
        "label": "Noise",
        "desc": "Grain over blurred areas, hides gradient banding",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 0.1
    },{
        "tab": "Look",
        "group": "BLUR",
        "key": "desktop.appearance.blurContrast",
        "label": "Blur contrast",
        "desc": "Contrast of the blurred backdrop",
        "ctl": "slid",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 2.0,
        "adv": true
    },{
        "tab": "Look",
        "group": "BLUR",
        "key": "desktop.appearance.blurBrightness",
        "label": "Blur brightness",
        "desc": "Brightness of the blurred backdrop",
        "ctl": "slid",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 2.0,
        "adv": true
    },{
        "tab": "Look",
        "group": "BLUR",
        "key": "desktop.appearance.blurSpecial",
        "label": "Blur special workspace",
        "desc": "Also blur behind the special (scratchpad) workspace",
        "ctl": "sw",
        "src": "desktop.json",
        "adv": true
    },{
        "tab": "Look",
        "group": "BLUR",
        "key": "desktop.appearance.blurPopups",
        "label": "Blur popups",
        "desc": "Blur behind popups and menus, not just windows",
        "ctl": "sw",
        "src": "desktop.json",
        "adv": true
    },{
        "tab": "Look",
        "group": "BLUR",
        "key": "desktop.appearance.blurIgnoreOpacity",
        "label": "Blur ignores opacity",
        "desc": "Blur the backdrop even under fully transparent regions",
        "ctl": "sw",
        "src": "desktop.json",
        "adv": true
    },{
        "tab": "Look",
        "group": "BLUR",
        "key": "desktop.appearance.blurNewOptimizations",
        "label": "Blur optimizations",
        "desc": "Cache blur for a large speedup, leave on unless you see artifacts",
        "ctl": "sw",
        "src": "desktop.json",
        "adv": true
    },{
        "tab": "Look",
        "group": "BLUR",
        "key": "desktop.appearance.blurVibrancyDarkness",
        "label": "Blur vibrancy darkness",
        "desc": "How much vibrancy affects the dark parts of the blur",
        "ctl": "slid",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 1.0,
        "adv": true
    },{
        "tab": "Look",
        "group": "SHADOWS",
        "key": "desktop.appearance.shadowEnabled",
        "label": "Window shadows",
        "desc": "A soft drop shadow under every window",
        "ctl": "sw",
        "src": "desktop.json"
    },{
        "tab": "Look",
        "group": "SHADOWS",
        "key": "desktop.appearance.shadowRange",
        "label": "Shadow range",
        "desc": "How far the shadow spreads from the window",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 60.0,
        "unit": "px"
    },{
        "tab": "Look",
        "group": "SHADOWS",
        "key": "desktop.appearance.shadowPower",
        "label": "Shadow sharpness",
        "desc": "Higher pulls the shadow in tight, lower leaves a wide haze",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 1.0,
        "hi": 4.0,
        "adv": true
    },{
        "tab": "Look",
        "group": "SHADOWS",
        "key": "desktop.appearance.shadowSharp",
        "label": "Sharp shadow",
        "desc": "Draw the shadow with hard edges instead of a soft falloff",
        "ctl": "sw",
        "src": "desktop.json",
        "adv": true
    },{
        "tab": "Look",
        "group": "SHADOWS",
        "key": "desktop.appearance.shadowScale",
        "label": "Shadow scale",
        "desc": "Scale of the drop shadow, 1 matches the window",
        "ctl": "slid",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 1.0,
        "adv": true
    },{
        "tab": "Look",
        "group": "SHADOWS",
        "key": "desktop.appearance.shadowColor",
        "label": "Shadow color",
        "desc": "Color of the drop shadow",
        "ctl": "color",
        "src": "desktop.json"
    },{
        "tab": "Look",
        "group": "GLOW",
        "key": "desktop.appearance.glowEnabled",
        "label": "Glow behind windows",
        "desc": "A coloured halo cast behind every window",
        "ctl": "sw",
        "src": "desktop.json"
    },{
        "tab": "Look",
        "group": "GLOW",
        "key": "desktop.appearance.glowRange",
        "label": "Range",
        "desc": "How far the halo reaches past the window edge",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 4.0,
        "hi": 60.0,
        "unit": "px"
    },{
        "tab": "Look",
        "group": "GLOW",
        "key": "desktop.appearance.glowColor",
        "label": "Colour",
        "desc": "The halo's tint, picked here, not taken from the theme",
        "ctl": "color",
        "src": "desktop.json"
    },{
        "tab": "Borders",
        "group": "THICKNESS",
        "key": "desktop.appearance.borderSize",
        "label": "Border thickness",
        "desc": "Width of the frame around every window, 0 removes it",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 12.0,
        "unit": "px"
    },{
        "tab": "Borders",
        "group": "THICKNESS",
        "key": "desktop.appearance.borderPartOfWindow",
        "label": "Border inside window",
        "desc": "Count the border as part of the window size instead of drawn outside it",
        "ctl": "sw",
        "src": "desktop.json"
    },{
        "tab": "Borders",
        "group": "ANIMATED",
        "key": "desktop.appearance.animatedBorder",
        "label": "Rotating gradient border",
        "desc": "Sweeps your accent colours around the frame, needs thickness above 0",
        "ctl": "sw",
        "src": "desktop.json"
    },{
        "tab": "Borders",
        "group": "ANIMATED",
        "key": "desktop.appearance.borderAngleSpeed",
        "label": "Rotation speed",
        "desc": "How fast the gradient circles the window",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 1.0,
        "hi": 10.0
    },{
        "tab": "Motion",
        "group": "MOTION",
        "key": "desktop.appearance.animations",
        "label": "Animations",
        "desc": "Motion for opening, closing, moving, workspaces; off snaps instantly",
        "ctl": "sw",
        "src": "desktop.json"
    },{
        "tab": "Motion",
        "group": "MOTION",
        "key": "desktop.appearance.wobblyWindows",
        "label": "Wobbly windows",
        "desc": "Dragged windows overshoot and spring back, needs animations on",
        "ctl": "sw",
        "src": "desktop.json"
    },{
        "tab": "Motion",
        "group": "MOTION",
        "key": "desktop.appearance.windowStyle",
        "label": "Open / close",
        "desc": "Entrance and exit motion: scale from centre, slide, or GNOME style",
        "ctl": "seg",
        "src": "desktop.json",
        "opts": [
            "pop",
            "slide",
            "gnomed"
        ]
    }
];
