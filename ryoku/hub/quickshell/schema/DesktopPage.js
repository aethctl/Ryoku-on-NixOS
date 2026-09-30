.pragma library

var rows = [{
        "tab": "General",
        "group": "BRAND",
        "key": "name",
        "label": "Name",
        "desc": "The name the shell calls this desktop",
        "eg": "Ryoku",
        "ctl": "text",
        "src": "brand"
    },{
        "tab": "General",
        "group": "BRAND",
        "key": "markText",
        "label": "Text mark",
        "desc": "The glyph the shell uses as its mark",
        "eg": "力",
        "ctl": "text",
        "src": "brand"
    },{
        "tab": "General",
        "group": "BRAND",
        "key": "markImage",
        "label": "Logo image",
        "desc": "An image mark, used instead of the glyph",
        "ctl": "image",
        "src": "brand"
    },{
        "tab": "General",
        "group": "BRAND",
        "key": "markTint",
        "label": "Tint image to accent",
        "ctl": "sw",
        "src": "brand"
    },{
        "tab": "General",
        "group": "SHELL RELOAD",
        "key": "reloadCover",
        "label": "Reload cover",
        "desc": "Shown while the desktop shell restarts",
        "ctl": "reload-cover",
        "src": "brand"
    },{
        "tab": "General",
        "group": "QUICK SETTINGS",
        "key": "frameBars.menus.quick-settings.anchor",
        "label": "Sidebar edge",
        "desc": "Which edge the Super+Esc sidebar opens from",
        "ctl": "seg",
        "src": "shell",
        "opts": ["left","right","top","bottom"]
    },{
        "tab": "General",
        "group": "QUICK SETTINGS",
        "key": "frameBars.menus.quick-settings.expansion",
        "label": "Fill the edge",
        "desc": "Stretch to the edge, or fit its content",
        "ctl": "seg",
        "src": "shell",
        "opts": ["always","never"]
    },{
        "tab": "General",
        "group": "QUICK SETTINGS",
        "key": "frameBars.menus.quick-settings.minWidth",
        "label": "Minimum width",
        "desc": "How wide the sidebar is at its narrowest",
        "ctl": "step",
        "src": "shell",
        "lo": 200,
        "hi": 1200,
        "unit": "px"
    },{
        "tab": "Clipboard",
        "group": "LAYOUT",
        "key": "clipboard.widthPercent",
        "label": "Width",
        "desc": "How much of the screen the clipboard panel spans",
        "ctl": "step",
        "src": "shell",
        "lo": 40,
        "hi": 90,
        "unit": "%"
    },{
        "tab": "Clipboard",
        "group": "LAYOUT",
        "key": "clipboard.heightPercent",
        "label": "Height",
        "desc": "How tall the clipboard panel can be",
        "ctl": "step",
        "src": "shell",
        "lo": 24,
        "hi": 72,
        "unit": "%"
    },{
        "tab": "Clipboard",
        "group": "LAYOUT",
        "key": "clipboard.bottomPercent",
        "label": "Bottom offset",
        "desc": "How far the panel rests above the screen edge; zero sits it on the edge",
        "ctl": "step",
        "src": "shell",
        "lo": 0,
        "hi": 20,
        "unit": "%"
    },{
        "tab": "Clipboard",
        "group": "CORNERS",
        "key": "clipboard.panelRadius",
        "label": "Panel rounding",
        "desc": "Roundness of the outer clipboard panel",
        "ctl": "step",
        "src": "shell",
        "lo": 0,
        "hi": 32,
        "unit": "px"
    },{
        "tab": "Clipboard",
        "group": "CORNERS",
        "key": "clipboard.paneRadius",
        "label": "Pane rounding",
        "desc": "Roundness of the Clipboard and Starred panes",
        "ctl": "step",
        "src": "shell",
        "lo": 0,
        "hi": 32,
        "unit": "px"
    },{
        "tab": "Clipboard",
        "group": "CORNERS",
        "key": "clipboard.cardRadius",
        "label": "Card rounding",
        "desc": "Roundness of individual clipboard cards",
        "ctl": "step",
        "src": "shell",
        "lo": 0,
        "hi": 32,
        "unit": "px"
    }
];
