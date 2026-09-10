pragma ComponentBehavior: Bound

import QtQuick
import shell.services
import shell.barkit as Pill

Rectangle {
    id: root

    required property var colors

    property string icon: "circle"
    property string label: ""
    property bool active: false
    property bool scrollable: false
    property int accentIndex: 0

    signal clicked()
    signal scrolled(int steps)

    implicitWidth: label.length > 0
        ? Theme.iconLg + Theme.paddingLg + Theme.paddingMd
        : Theme.iconLg
    implicitHeight: Theme.iconLg + Theme.paddingLg

    radius: Theme.radiusWidget
    color: active
        ? colors.alpha(colors.accent(accentIndex), 0.18)
        : mouse.containsMouse
            ? colors.surfaceHover
            : "transparent"

    border.width: 0

    readonly property color contentColor: active ? colors.accent(accentIndex) : colors.text

    Behavior on color {
        enabled: !Motion.reduce
        ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
    }

    Row {
        anchors.centerIn: parent
        spacing: Theme.paddingSm

        Pill.MaterialIcon {
            anchors.verticalCenter: parent.verticalCenter
            text: root.icon
            color: root.contentColor
            font.pixelSize: Theme.iconSm
            fill: root.active ? 1 : 0
        }

        Text {
            visible: root.label.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.contentColor
            font.family: Theme.mono
            font.pixelSize: Theme.fontSm
            font.weight: Font.Bold
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onWheel: event => {
            if (root.scrollable)
                root.scrolled(event.angleDelta.y > 0 ? 1 : -1)
        }
    }
}
