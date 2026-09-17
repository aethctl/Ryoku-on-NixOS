.pragma library

// RecordingPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "KEY PRESSES",
        "key": "keypressTheme",
        "label": "Keycap style",
        "desc": "Dark keycaps use white type; Light keycaps use black type",
        "ctl": "seg",
        "src": "keypresses.json",
        "opts": [
            "dark",
            "light"
        ]
    },
    {
        "tab": "",
        "group": "KEY PRESSES",
        "key": "keypressMode",
        "label": "Visible keys",
        "desc": "Show every key, or hide ordinary typing and keep shortcuts.",
        "ctl": "seg",
        "src": "keypresses.json",
        "opts": [
            "all",
            "shortcuts"
        ]
    },
    {
        "tab": "",
        "group": "QUALITY",
        "key": "fps",
        "label": "Framerate",
        "desc": "Frames per second; higher is smoother but larger.",
        "ctl": "step",
        "src": "recording.json",
        "unit": "fps"
    },
    {
        "tab": "",
        "group": "QUALITY",
        "key": "framerateMode",
        "label": "Framerate mode",
        "desc": "Constant plays everywhere; variable is smaller but choppier.",
        "ctl": "seg",
        "src": "recording.json",
        "opts": [
            "cfr",
            "vfr"
        ]
    },
    {
        "tab": "",
        "group": "QUALITY",
        "key": "quality",
        "label": "Quality",
        "desc": "Higher settings look crisper but make larger files",
        "ctl": "seg",
        "src": "recording.json",
        "opts": [
            "medium",
            "high",
            "very_high",
            "ultra"
        ]
    },
    {
        "tab": "",
        "group": "QUALITY",
        "key": "codec",
        "label": "Codec",
        "desc": "H.264 plays anywhere; AV1 is crisper but needs a newer GPU.",
        "ctl": "seg",
        "src": "recording.json",
        "opts": [
            "h264",
            "hevc",
            "av1"
        ]
    },
    {
        "tab": "",
        "group": "ENCODER",
        "key": "encoder",
        "label": "Encoder",
        "desc": "GPU barely loads the CPU; pick CPU if GPU encoding fails.",
        "ctl": "seg",
        "src": "recording.json",
        "opts": [
            "gpu",
            "cpu"
        ]
    },
    {
        "tab": "",
        "group": "ENCODER",
        "key": "cursor",
        "label": "Show the cursor in recordings",
        "desc": "Draws the mouse pointer into the video.",
        "ctl": "sw",
        "src": "recording.json"
    }
];
