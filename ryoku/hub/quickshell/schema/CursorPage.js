.pragma library

// AppearancePage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [{
        "tab": "Pointer",
        "group": "CURSOR",
        "key": "desktop.cursor.theme",
        "label": "Theme",
        "desc": "From installed icon sets, applies now and to newly opened apps",
        "ctl": "seg",
        "src": "desktop.json",
        "opts": [
            "DYNAMIC"
        ]
    },{
        "tab": "Pointer",
        "group": "CURSOR",
        "key": "desktop.cursor.material",
        "label": "Material Bibata",
        "desc": "Swap the pointer for the Bibata cursor recolored in the Ryoku vermillion accent",
        "ctl": "sw",
        "src": "desktop.json"
    },{
        "tab": "Pointer",
        "group": "CURSOR",
        "key": "desktop.cursor.size",
        "label": "Size",
        "desc": "How large the pointer is drawn",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 12.0,
        "hi": 64.0,
        "unit": "px"
    },{
        "tab": "Pointer",
        "group": "CURSOR",
        "key": "desktop.cursor.inactiveTimeout",
        "label": "Hide after idle",
        "desc": "Seconds of stillness before the pointer hides, 0 never hides",
        "ctl": "step",
        "src": "desktop.json",
        "lo": 0.0,
        "hi": 30.0,
        "unit": "s"
    },{
        "tab": "Pointer",
        "group": "CURSOR",
        "key": "desktop.cursor.hideOnKeyPress",
        "label": "Hide while typing",
        "desc": "The pointer vanishes on a keypress and returns when moved",
        "ctl": "sw",
        "src": "desktop.json"
    }
];
