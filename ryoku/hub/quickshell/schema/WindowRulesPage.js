.pragma library

// WindowRulesPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "OTHER",
        "key": "desktop.windowRules",
        "label": "Rule editor",
        "desc": "Match by class and/or title; changing the action resets its value",
        "ctl": "list",
        "src": "desktop.json",
        "caps": "windowRules"
    },
    {
        "tab": "",
        "group": "OTHER",
        "key": "desktop.windowRules",
        "label": "Rule editor",
        "desc": "Match by class and/or title; changing the action resets its value",
        "ctl": "multi",
        "src": "desktop.json",
        "caps": "windowRules",
        "opts": [
            "Match class (placeholder text; no visible field label)",
            "Match title (placeholder text; no visible field label)",
            "float",
            "Value - free-form text (no visible label; placeholder is an action-dependent hint)",
            "always",
            "maximize"
        ]
    }
];
