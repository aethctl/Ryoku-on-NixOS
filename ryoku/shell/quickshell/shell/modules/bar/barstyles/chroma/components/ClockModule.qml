pragma ComponentBehavior: Bound

import QtQuick
import shell.services

Rectangle {
    id: root

    required property var colors

    property date now: new Date()

    implicitWidth: Theme.iconLg * 4 + Theme.paddingLg
    implicitHeight: Theme.iconLg + Theme.paddingLg

    radius: Theme.radiusWidget

    // Keep the clock on one Matugen role. It still retints live with the
    // wallpaper, but no longer snaps back to palette slot zero between steps.
    color: colors.accent(0)

    readonly property color contentColor: colors.inkOn(color)

    Behavior on color {
        enabled: !Motion.reduce
        ColorAnimation { duration: Motion.standard; easing.type: Motion.easeStandard }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }

    Column {
        anchors {
            left: parent.left
            leftMargin: Theme.paddingLg
            verticalCenter: parent.verticalCenter
        }
        spacing: 0

        Text {
            text: Qt.formatDateTime(root.now, "HH:mm")
            color: root.contentColor
            font.family: Theme.mono
            font.pixelSize: 21
            font.weight: Font.Black
            font.letterSpacing: 1
        }

        Text {
            text: Qt.formatDateTime(root.now, "ddd  dd.MM.yy").toUpperCase()
            color: root.contentColor
            opacity: 0.68
            font.family: Theme.mono
            font.pixelSize: 8
            font.weight: Font.Bold
            font.letterSpacing: 1.1
        }
    }

    Rectangle {
        anchors {
            right: parent.right
            rightMargin: Theme.paddingLg
            verticalCenter: parent.verticalCenter
        }
        width: Theme.paddingMd
        height: Theme.iconMd
        radius: width / 2
        color: root.contentColor
        opacity: 0.9
    }
}
