import QtQuick
import Ryoku.Ui.Singletons

// A disabled provider is never hidden: it greys and says why. Emphasis is weight, not colour:
// the open provider reads bold and one bone rule slides beneath its name.
Item {
    id: strip

    // [{ id, label, searchable, enabled, reason }]
    property var tabs: []
    property string current: ""
    property real reveal: 1

    signal selected(string id)

    implicitHeight: 48 * Theme.scale

    property real ruleX: 0
    property real ruleW: 0
    property bool _placed: false

    Row {
        id: row
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 24 * Theme.scale
        anchors.rightMargin: 24 * Theme.scale
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1 * Theme.scale

        readonly property int n: strip.tabs.length
        readonly property real tabW: n > 0
            ? Math.floor((width - (n - 1) * 1 * Theme.scale) / n)
            : 0

        Repeater {
            model: strip.tabs
            delegate: Item {
                id: tab
                required property var modelData
                required property int index
                width: index === row.n - 1
                    ? row.width - (row.n - 1) * (row.tabW + 1 * Theme.scale)
                    : row.tabW
                height: 48 * Theme.scale

                readonly property bool selected: strip.current === modelData.id
                readonly property bool available: modelData.enabled === true
                readonly property bool hovered: tabHover.containsMouse

                // Sized for the bold cut, so the rule holds its width as the name inverts to open.
                TextMetrics {
                    id: boldCut
                    font.family: Theme.sans
                    font.weight: Font.DemiBold
                    font.pixelSize: Theme.fontBase
                    text: tab.modelData.label
                }

                Binding {
                    target: strip; property: "ruleX"
                    value: tab.x + (tab.width - boldCut.advanceWidth) * 0.5
                    when: tab.selected && tab.available; restoreMode: Binding.RestoreNone
                }
                Binding {
                    target: strip; property: "ruleW"; value: boldCut.advanceWidth
                    when: tab.selected && tab.available; restoreMode: Binding.RestoreNone
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius
                    color: Theme.withAlpha(Theme.surfaceText,
                        tab.hovered && tab.available && !tab.selected ? 0.07 : 0)
                    Behavior on color { ColorAnimation { duration: Theme.fast } }
                }

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 14 * Theme.scale
                    spacing: 2 * Theme.scale

                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.label
                        elide: Text.ElideRight
                        font.family: Theme.sans
                        font.weight: tab.selected ? Font.DemiBold : Font.Medium
                        font.pixelSize: Theme.fontBase
                        color: !tab.available
                            ? Theme.withAlpha(Theme.surfaceText, 0.34)
                            : Theme.withAlpha(Theme.surfaceText, tab.selected || tab.hovered ? 1 : 0.66)
                        renderType: Text.NativeRendering
                        Behavior on color { ColorAnimation { duration: Theme.fast } }
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        visible: !tab.available && modelData.reason !== undefined
                            && String(modelData.reason).length > 0
                        text: modelData.reason !== undefined ? modelData.reason : ""
                        elide: Text.ElideRight
                        font.family: Theme.sans
                        font.weight: Font.Medium
                        font.pixelSize: Theme.fontMicro
                        color: Theme.withAlpha(Theme.surfaceText, 0.28)
                        renderType: Text.NativeRendering
                    }
                }

                MouseArea {
                    id: tabHover
                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: tab.available && !tab.selected
                    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: strip.selected(tab.modelData.id)
                }
            }
        }
    }

    // One bone rule sits under the open provider and slides to the next; the first placement
    // lands without travelling, only a switch springs it.
    Rectangle {
        x: row.x + strip.ruleX
        width: strip.ruleW
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 6 * Theme.scale
        height: 2 * Theme.scale
        radius: height
        color: Theme.surfaceText
        visible: strip.ruleW > 0
        Behavior on x {
            enabled: strip._placed
            NumberAnimation { duration: Theme.standard; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
        }
        Behavior on width {
            enabled: strip._placed
            NumberAnimation { duration: Theme.standard; easing.type: Easing.OutCubic }
        }
    }
    Timer { interval: 1; running: strip.ruleW > 0 && !strip._placed; onTriggered: strip._placed = true }
}
