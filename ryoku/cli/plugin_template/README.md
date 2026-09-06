# {{NAME}}

A Ryoku shell plugin (`{{ID}}`). This scaffold is a working demo: a counter that
ticks once a second, a mark on the bar, and a panel with a RESET button. Edit it
into your own widget.

## What it does

- **Service** (`service/Main.qml`): the logic, no UI. Holds the live state the
  views read through `pluginApi.mainInstance`.
- **Widget** (`content/Widget.qml`): the one view the host mounts. A left click
  toggles the panel; it never changes state.
- **Panel** (`content/Panel.qml`): the bar panel the host renders under the
  glyph when this plugin is on the bar.

## What it reads and writes

The demo reads nothing off the machine and writes nothing. When you add real
behaviour, keep to the rules in `AGENTS.md`: read settings through
`pluginApi.pluginSettings` behind a default, write them only through
`pluginApi.saveSetting(key, value)`, and write files only under
`pluginApi.stateDir`. Every external command belongs in `bin/` or in
`dependencies.commands`; every host you contact belongs in
`capabilities.network`; a privileged action runs only through `pkexec` listed in
`capabilities.privileged`.

## Settings

| key       | type   | default | description         |
| --------- | ------ | ------- | ------------------- |
| showCount | toggle | true    | Show the tick count |

## Preview

Capture a real screenshot of the widget and save it as
`assets/preview-widget.png`, then list it under `files` in `manifest.json`. The
store shows it in the catalogue.

## Build, check, install

```
ryoku plugin validate .
ryoku plugin add . --bar --yes
```

It lists under **Community** in QS Bar Settings. Publish it only when you want
to share it: `ryoku plugin share {{ID}}`.

## Author

{{AUTHOR}}: this plugin is community-made (`official` is false).
