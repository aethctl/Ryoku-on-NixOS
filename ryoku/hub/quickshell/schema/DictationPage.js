.pragma library

// DictationPage as data. Generated from the page it replaces.
// Descriptions are written by hand; the inventory carries engineering
// notes, which are not user copy.

var rows = [
    {
        "tab": "",
        "group": "DICTATION",
        "key": "enabled",
        "label": "Voice typing",
        "desc": "Tap Super+` to dictate into the focused app",
        "ctl": "sw",
        "src": " disable --now (off). Read back via `systemctl --user is-enabled --quiet voxtype.service`."
    },
    {
        "tab": "",
        "group": "ENGINE & MODEL",
        "key": "# ryoku-preset: <key>",
        "label": "Speech engine",
        "desc": "Which engine turns speech into text",
        "ctl": "seg",
        "src": "voxtype.go, mode 0600, atomicWrite. Selection is persisted ONLY as a TOML *comment* marker `# ryoku-preset: <key>` and read back by selectedPreset() scanning for that comment prefix.",
        "opts": [
            "whisper-fast",
            "whisper-accurate",
            "openai"
        ]
    },
    {
        "tab": "",
        "group": "ENGINE & MODEL",
        "key": "whisper.model = \"base.en\" + whisper.language = \"en\"",
        "label": "Whisper - Fast",
        "desc": "English, offline, small model, quick to load",
        "ctl": "action",
        "src": "ggml-base.en.bin"
    },
    {
        "tab": "",
        "group": "ENGINE & MODEL",
        "key": "whisper.model = \"large-v3-turbo\" + whisper.language = \"auto\"",
        "label": "Whisper - Accurate",
        "desc": "Any language, offline, a 1.6 GB download",
        "ctl": "action",
        "src": "ggml-large-v3-turbo.bin"
    },
    {
        "tab": "",
        "group": "ENGINE & MODEL",
        "key": "whisper.mode = \"remote\" + whisper.remote_model = \"whisper-1\" + whisper.remote_endpoint = \"https://api.openai.com/v1\"",
        "label": "OpenAI API",
        "desc": "Cloud transcription; audio leaves your machine",
        "ctl": "action",
        "src": "config.toml"
    },
    {
        "tab": "",
        "group": "API KEY",
        "key": "remote_api_key",
        "label": "OpenAI API key",
        "desc": "Your OpenAI key, kept in config.toml",
        "ctl": "text",
        "src": "config.toml, under [whisper], mode 0600. Also satisfied read-only by env VOXTYPE_WHISPER_API_KEY."
    },
    {
        "tab": "",
        "group": "API KEY",
        "key": "remote_api_key",
        "label": "Save key",
        "desc": "Writes the key and checks that it works",
        "ctl": "action",
        "src": "config.toml"
    },
    {
        "tab": "",
        "group": "(install empty-state, not a SettingSection)",
        "key": "",
        "label": "Install Voxtype",
        "desc": "",
        "ctl": "action",
        "src": "none (package manager)"
    },
    {
        "tab": "",
        "group": "PACKAGE",
        "key": "",
        "label": "Remove Voxtype",
        "desc": "",
        "ctl": "action",
        "src": "none (package manager + systemd unit removal)"
    }
];
