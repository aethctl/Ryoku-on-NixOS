# iRiS Module SDK

iRiS bar modules use the existing iNiR CustomWidgets registry. There is no second plugin format or
scanner. A widget may provide its normal desktop component, an iRiS compact component, or both.

## Create a module

```bash
inir customWidgets create my-widget
```

The generated manifest includes an `iris` block and the scaffold includes `IrisCompact.qml`.
Reload after editing:

```bash
inir customWidgets reload
```

Place the module in **Settings -> iRiS -> Modules -> User modules**.

## Manifest

```json
{
  "name": "My Widget",
  "main": "MyWidget.qml",
  "iris": {
    "main": "IrisCompact.qml",
    "slots": ["bar.left", "bar.center", "bar.right"]
  }
}
```

`slots` is optional. An empty list means every iRiS slot is allowed.

The arrays `iris.bar.leftModules`, `iris.bar.centerModules`, and `iris.bar.rightModules` are ordered.
Settings can move a module between slots and reorder it inside the selected slot; no additional
layout registration is required.

## Minimal compact component

```qml
pragma ComponentBehavior: Bound

import QtQuick
import qs.services
import qs.modules.iris.style
import qs.modules.iris.components

Item {
    property string irisSlot: ""
    property var targetScreen

    implicitWidth: row.implicitWidth
    implicitHeight: Math.round(28 * IrisStyle.density)

    Row {
        id: row
        anchors.centerIn: parent
        spacing: IrisStyle.spaceSmall

        IrisMark { implicitSize: Math.round(14 * IrisStyle.density) }
        IrisText {
            text: DateTime.timeDisplay
            font.family: IrisStyle.fontNumbers
            role: IrisText.Meta
        }
    }
}
```

## Compact API

Use these first:

- `IrisStyle`: colors, fonts, density, radii, spacing and motion duration;
- `IrisText`: semantic text roles;
- `IrisSurface`: normal/raised outlined surface;
- `IrisButton` / `IrisIconButton`: hover/tap/selected states;
- `IrisMark`: family mark;
- `IrisSlider`: compact slider (use `IrisCapsuleSlider` for Control Center style levels).

Normal iNiR services remain available through `import qs.services`, but a compact module should
import only what it actually needs. Avoid pulling in media visualizers, preview services or
background processes for a value that is not continuously visible.

## Lifecycle rules

- Do not start a subprocess from a hidden component just to cache data.
- Do not use a permanent animation for decoration.
- Prefer service signals over polling timers.
- Keep module failure local; do not mutate family loader state.
- Respect `targetScreen` for output-specific data.
- Use `Config.setNestedValue(...)` for persistent writes; do not assign into `Config.options`.
- Keep presentation in iRiS tokens rather than hard-coded theme colors.

For full desktop-widget APIs and the broader service/component catalog, see `WIDGET-SDK.md`.
