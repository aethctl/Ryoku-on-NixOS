pragma ComponentBehavior: Bound

import QtQuick
import inir.modules.background.widgets
import inir.modules.iris.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "controls"
    defaultConfig: ({
        placementStrategy: "free", widgetScale: 100, cornerRadius: -1, x: 120, y: 420
    })

    implicitWidth: root.irisFaceWidth
    implicitHeight: root.irisFaceHeight
    irisOnly: true
    irisFace: Component { IrisControlsFace { widget: root } }
    irisSizes: ["small", "medium", "large"]
    irisDefaultSize: "medium"
    semanticPaletteControls: false
}
