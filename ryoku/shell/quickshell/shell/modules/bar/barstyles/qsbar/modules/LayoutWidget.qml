import QtQuick
import Quickshell
import shell.services
import Ryoku.Ui.Singletons

Item {
    id: rootMod
    required property var root

    readonly property bool iconOnly: root.iconOnly("G19")
    readonly property bool shown: root.modLayout && Wm.caps.keyboardLayoutSwitch

    property string layout: {
        var value = KeyboardLayout.variant || ""
        if (!value)
            return ""

        var match = value.match(/\(([^)]+)\)/)
        return match ? match[1].toUpperCase() : value.toUpperCase()
    }

    readonly property string layoutIcon: "keyboard"
    readonly property color contentColor: root.widgetContentColor("G19", root.widgetIconColor)

    readonly property string tooltipText: I18n.tr("Keyboard layout · %1").arg(rootMod.layout)

    visible: rootMod.shown && implicitWidth > 0.5
    implicitWidth: rootMod.shown ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: rootMod.shown ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: 140
            easing.type: Easing.OutCubic
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 4

        IconText {
            anchors.verticalCenter: parent.verticalCenter

            text: rootMod.layoutIcon
            color: rootMod.contentColor

            font.pixelSize: 15
            font.weight: Font.Medium
            fill: 1

            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }
        }

        UiText {
            visible: !root.iconOnly("G19")

            anchors.verticalCenter: parent.verticalCenter

            text: rootMod.layout
            color: rootMod.contentColor

            font.family: root.mono
            font.pixelSize: 12

            Behavior on color {
                ColorAnimation {
                    duration: 160
                }
            }
        }
    }

    TooltipMixin {
        id: tip
        root: rootMod.root
        owner: rootMod
        text: rootMod.tooltipText
    }

    MouseArea {
        anchors.fill: parent

        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onEntered: tip.show()
        onExited: tip.hide()

        // Left click opens the keyboard settings page; right click cycles to the
        // next configured layout.
        onClicked: function (mouse) {
            tip.hide()
            if (mouse.button === Qt.RightButton)
                Wm.cycleKeyboardLayout()
            else
                Quickshell.execDetached(["ryoku-shell", "hub", "open", "input"])
        }
    }
}
