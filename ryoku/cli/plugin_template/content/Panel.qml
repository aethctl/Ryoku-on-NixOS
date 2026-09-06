import QtQuick
import Ryoku.PluginKit.Singletons

// content/Panel.qml is the bar panel: when this plugin is on the bar and the
// manifest declares entryPoints.panel, the host renders this file under the
// plugin's glyph in the shared panel surface (Escape or an outside click closes
// it, one panel open at a time). The host sets pluginApi, density ("full"), s,
// widthBudget (from manifest panel.width) and active; report implicitHeight and
// the host sizes the card to it.
Item {
    id: root

    property var pluginApi
    property string density: "full"
    property real s: 1
    property real widthBudget: 320
    property bool active: false

    readonly property var service: pluginApi ? pluginApi.mainInstance : null
    readonly property int count: service ? service.count : 0

    implicitWidth: root.widthBudget
    implicitHeight: col.implicitHeight + 24 * root.s

    Column {
        id: col
        x: 12 * root.s
        y: 12 * root.s
        width: root.width - 24 * root.s
        spacing: 10 * root.s

        Text {
            text: "Demo plugin"
            color: Theme.bright
            font.family: Theme.display
            font.pixelSize: 16 * root.s
        }

        Text {
            text: "Ticks: " + root.count
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 13 * root.s
        }

        Rectangle {
            width: resetLabel.implicitWidth + 24 * root.s
            height: resetLabel.implicitHeight + 12 * root.s
            radius: Theme.radius
            color: resetArea.pressed ? Theme.vermDeep : Theme.accent

            Text {
                id: resetLabel
                anchors.centerIn: parent
                text: "RESET"
                color: Theme.cardBot
                font.family: Theme.font
                font.pixelSize: 12 * root.s
            }

            MouseArea {
                id: resetArea
                anchors.fill: parent
                onClicked: if (root.service) root.service.reset()
            }
        }
    }
}
