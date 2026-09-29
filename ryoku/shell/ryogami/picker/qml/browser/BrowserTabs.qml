import QtQuick
import Ryoku.Ui.Singletons

// A disabled provider is never hidden: it greys and shows its reason.
Item {
    id: strip

    // [{ id, label, searchable, enabled, reason }]
    property var tabs: []
    property string current: ""
    property real reveal: 1

    signal selected(string id)

    implicitHeight: 48 * Theme.scale

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

                Rectangle {
                    anchors.fill: parent
                    color: !tab.available
                        ? "transparent"
                        : tab.selected
                            ? Theme.withAlpha(Theme.primary, 0.92)
                            : tab.hovered
                                ? Theme.withAlpha(Theme.surfaceVariant, 0.62)
                                : Theme.withAlpha(Theme.surfaceContainer, 0.92)
                    border.width: 1
                    border.color: !tab.available
                        ? Theme.withAlpha(Theme.outline, 0.18)
                        : (tab.selected || tab.hovered)
                            ? Theme.withAlpha(Theme.primary, 0.90)
                            : Theme.withAlpha(Theme.outline, 0.40)
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
                        font.family: Theme.ui
                        font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontBase
                        color: tab.selected
                            ? Theme.withAlpha(Theme.primaryText, tab.available ? 0.96 : 0.34)
                            : Theme.withAlpha(Theme.surfaceText, tab.available ? 0.96 : 0.34)
                        renderType: Text.NativeRendering
                    }
                    Text {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData.reason !== undefined ? modelData.reason : ""
                        elide: Text.ElideRight
                        font.family: Theme.ui
                        font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontMicro
                        color: tab.selected
                            ? Theme.withAlpha(Theme.primaryText, tab.available ? 0.58 : 0.28)
                            : Theme.withAlpha(Theme.surfaceText, tab.available ? 0.58 : 0.28)
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
}
