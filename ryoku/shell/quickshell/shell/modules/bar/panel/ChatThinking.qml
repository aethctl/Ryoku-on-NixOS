import QtQuick
import shell.services
import "../../../components"
import Ryoku.Ui.Singletons

// The agent's reasoning: it streams open and growing while the agent thinks,
// then auto-collapses to a one-line "Thought" header the moment the answer
// starts or the turn ends. Click the header to reopen it. Modelled on iNiR's
// aiChat/MessageThinkBlock.qml (end-4 illogical-impulse, GPL-3.0).
Item {
    id: root

    property real s: 1
    property string thought: ""
    // live: the agent is still thinking (message open, no answer yet). While
    // live the block is forced open; once settled the user drives it.
    property bool live: false
    property bool userExpanded: false

    readonly property bool expanded: root.live || root.userExpanded
    visible: root.thought.length > 0
    implicitHeight: visible ? col.implicitHeight : 0

    Column {
        id: col
        width: parent.width
        spacing: 4 * root.s

        Rectangle {
            width: parent.width
            height: 22 * root.s
            radius: 6 * root.s
            color: hdrArea.containsMouse && !root.live
                ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.06)
                : "transparent"
            Row {
                anchors.left: parent.left
                anchors.leftMargin: 6 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 5 * root.s
                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "neurology"
                    font.pixelSize: 12 * root.s
                    color: root.live ? Theme.primary : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    opacity: root.live ? 0.95 : 0.7
                }
                Text {
                    id: label
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.live ? I18n.tr("Thinking") + dots.text : I18n.tr("Thought")
                    color: root.live ? Theme.primary : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    font.family: Theme.mono
                    font.pixelSize: 9 * root.s
                    font.letterSpacing: 1.0
                    font.weight: Font.DemiBold
                    // A quiet animated ellipsis so a live block reads as active.
                    QtObject {
                        id: dots
                        property int n: 0
                        readonly property string text: root.live ? ".".repeat(dots.n) : ""
                    }
                    Timer {
                        running: root.live
                        interval: 400
                        repeat: true
                        onTriggered: dots.n = (dots.n + 1) % 4
                    }
                }
            }
            MaterialIcon {
                anchors.right: parent.right
                anchors.rightMargin: 6 * root.s
                anchors.verticalCenter: parent.verticalCenter
                visible: !root.live
                text: "expand_more"
                font.pixelSize: 13 * root.s
                rotation: root.expanded ? 180 : 0
                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                Behavior on rotation { NumberAnimation { duration: Motion.fast } }
            }
            MouseArea {
                id: hdrArea
                anchors.fill: parent
                hoverEnabled: true
                enabled: !root.live
                cursorShape: Qt.PointingHandCursor
                onClicked: root.userExpanded = !root.userExpanded
            }
        }

        Rectangle {
            width: parent.width
            visible: root.expanded && root.thought.length > 0
            implicitHeight: visible ? think.implicitHeight + 12 * root.s : 0
            radius: 6 * root.s
            color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.04)
            border.width: 1
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.22)

            TextEdit {
                id: think
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8 * root.s
                text: root.thought
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.Wrap
                textFormat: TextEdit.PlainText
                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                selectionColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                selectedTextColor: color
                font.family: Theme.fontPrimary
                font.pixelSize: 11 * root.s
                font.italic: true
                opacity: 0.85
            }
        }
    }
}
