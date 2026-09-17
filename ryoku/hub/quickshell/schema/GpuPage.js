.pragma library

// GpuPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "RYOKU RENDERS ON",
        "key": "AQ_DRM_DEVICES",
        "label": "Graphics mode",
        "desc": "Which GPU renders the desktop; next login",
        "ctl": "seg",
        "src": "gpu.lua (override path via $RYOKU_GPU_CONF; base honours $XDG_CONFIG_HOME)",
        "opts": [
            "hybrid",
            "performance",
            "passthrough"
        ]
    },
    {
        "tab": "",
        "group": "CPU POWER PROFILES",
        "key": "",
        "label": "Editing profile",
        "desc": "Which profile you're editing, not the live one.",
        "ctl": "seg",
        "src": "ryoku-hub cpu active (ryoku-power)",
        "opts": [
            "power-saver",
            "balanced",
            "performance"
        ]
    },
    {
        "tab": "",
        "group": "CPU POWER PROFILES",
        "key": "",
        "label": "Governor",
        "desc": "CPU scaling governor for the edited profile.",
        "ctl": "seg",
        "src": "ryoku-power profiles (scaling_governor, power.json)",
        "opts": [
            "performance",
            "powersave"
        ]
    },
    {
        "tab": "",
        "group": "CPU POWER PROFILES",
        "key": "",
        "label": "Energy preference",
        "desc": "Energy or performance hint",
        "ctl": "seg",
        "src": "ryoku-power profiles (energy_performance_preference, power.json)",
        "opts": [
            "default",
            "performance",
            "balance_performance",
            "balance_power",
            "power"
        ]
    },
    {
        "tab": "",
        "group": "CPU POWER PROFILES",
        "key": "",
        "label": "Max frequency",
        "desc": "Ceiling for the CPU clock, in percent",
        "ctl": "slid",
        "src": "ryoku-power profiles (scaling_max_freq, power.json)"
    },
    {
        "tab": "",
        "group": "CPU POWER PROFILES",
        "key": "",
        "label": "Thermal profile",
        "desc": "Fan and power envelope for the edited profile.",
        "ctl": "seg",
        "src": "ryoku-power profiles (platform_profile, power.json)",
        "opts": [
            "quiet",
            "balanced",
            "performance"
        ]
    },
    {
        "tab": "",
        "group": "CPU POWER PROFILES",
        "key": "",
        "label": "CPU boost and PPT/TDP limits",
        "desc": "Not exposed: firmware governs boost and PPT here.",
        "ctl": "readout",
        "src": "static copy"
    },
    {
        "tab": "",
        "group": "TUNING \u00b7 THIS SESSION",
        "key": "",
        "label": "Power limit / TDP",
        "desc": "GPU power budget in watts, live for this session.",
        "ctl": "slid",
        "src": "ryoku-hub gpu tune (runtime, resets on reboot)"
    },
    {
        "tab": "",
        "group": "TUNING \u00b7 THIS SESSION",
        "key": "",
        "label": "Performance level",
        "desc": "AMD performance level: auto, low, or high.",
        "ctl": "seg",
        "src": "ryoku-hub gpu tune (runtime, resets on reboot)"
    },
    {
        "tab": "",
        "group": "TUNING \u00b7 THIS SESSION",
        "key": "",
        "label": "Persistence mode",
        "desc": "Keeps the NVIDIA driver loaded",
        "ctl": "sw",
        "src": "ryoku-hub gpu tune (runtime, resets on reboot)"
    },
    {
        "tab": "",
        "group": "TUNING \u00b7 THIS SESSION",
        "key": "",
        "label": "Overclock, undervolt and fan control",
        "desc": "GPU clock and fan control; resets on reboot",
        "ctl": "slid",
        "src": "ryoku-hub gpu tune (runtime, resets on reboot)"
    },
    {
        "tab": "",
        "group": "TUNING \u00b7 THIS SESSION",
        "key": "",
        "label": "Tuning presets",
        "desc": "Save and apply named tuning bundles.",
        "ctl": "action",
        "src": "~/.config/ryoku/gpu-presets.json"
    },
    {
        "tab": "",
        "group": "BATTERY",
        "key": "",
        "label": "Charge limit",
        "desc": "Stop charging here to preserve battery health.",
        "ctl": "slid",
        "src": "ryoku-power charge-limit (charge_control_end_threshold, power.json)"
    },
    {
        "tab": "",
        "group": "BATTERY",
        "key": "",
        "label": "PCIe ASPM",
        "desc": "PCIe power policy: trade idle power for latency.",
        "ctl": "seg",
        "src": "ryoku-power aspm (pcie_aspm/parameters/policy, power.json)",
        "opts": [
            "default",
            "performance",
            "powersave",
            "powersupersave"
        ]
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Readiness checks",
        "desc": "",
        "ctl": "sw",
        "src": "none (transient page state: page.showChecks)"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Disable passthrough",
        "desc": "",
        "ctl": "action",
        "src": "qemu"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Review changes",
        "desc": "",
        "ctl": "action",
        "src": "reads nothing; prints a plan"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Enable passthrough",
        "desc": "",
        "ctl": "action",
        "src": "kvm; enables libvirtd; kvmfr static_size_mb=128"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Close",
        "desc": "",
        "ctl": "action",
        "src": "none"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Recheck",
        "desc": "",
        "ctl": "action",
        "src": "none"
    },
    {
        "tab": "",
        "group": "(no SettingSection - floating error column under the hero card)",
        "key": "",
        "label": "Retry",
        "desc": "",
        "ctl": "action",
        "src": "none"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Passthrough status",
        "desc": "",
        "ctl": "readout",
        "src": "`ryoku-hub gpu caps` -> caps.verdict"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Readiness check details",
        "desc": "",
        "ctl": "readout",
        "src": "hwcaps.go buildChecks)"
    },
    {
        "tab": "",
        "group": "RYOKU RENDERS ON",
        "key": "",
        "label": "Graphics mode explainer",
        "desc": "",
        "ctl": "readout",
        "src": "derived from page.mode + page.dgpuName"
    },
    {
        "tab": "",
        "group": "GPU PASSTHROUGH \u00b7 ADVANCED",
        "key": "",
        "label": "Passthrough section intro",
        "desc": "",
        "ctl": "readout",
        "src": "static copy + page.dgpuName"
    }
];
