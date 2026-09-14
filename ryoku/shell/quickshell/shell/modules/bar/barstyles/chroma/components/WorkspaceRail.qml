pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import shell.services

Rectangle {
    id: root

    required property var colors

    readonly property int workspaceCount: {
        let highest = Math.max(5, Workspaces.activeId)
        if (Compositor.isNiri) {
            const list = Compositor.workspaces || []
            for (let i = 0; i < list.length; ++i) {
                const workspace = list[i]
                if (!workspace || workspace.output !== Compositor.focusedOutput)
                    continue
                const index = Number(workspace.index)
                if (index > 0 && index <= 10)
                    highest = Math.max(highest, index)
            }
        } else {
            const list = Hyprland.workspaces ? Hyprland.workspaces.values : []
            for (let i = 0; i < list.length; ++i) {
                const id = Number(list[i] && list[i].id)
                if (id > 0 && id <= 10)
                    highest = Math.max(highest, id)
            }
        }
        return Math.min(10, highest)
    }

    function occupied(id) {
        if (Compositor.isNiri)
            return Compositor.workspaceHasWindows(id, Compositor.focusedOutput)

        const toplevels = Hyprland.toplevels ? Hyprland.toplevels.values : []
        for (let i = 0; i < toplevels.length; ++i) {
            const data = toplevels[i] && toplevels[i].lastIpcObject || ({})
            if (data.workspace && Number(data.workspace.id) === id)
                return true
        }
        return false
    }

    function focus(id) {
        if (Compositor.isNiri)
            Compositor.focusWorkspace(id)
        else
            Hyprland.dispatch("hl.dsp.focus({ workspace = " + id + " })")
    }

    implicitWidth: row.implicitWidth + Theme.paddingMd * 2
    implicitHeight: Theme.iconLg + Theme.paddingLg

    radius: Theme.radiusWidget
    color: root.colors.backgroundAlt
    border.width: 0
    clip: true

    Row {
        id: row

        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: Theme.paddingMd
            rightMargin: Theme.paddingMd
        }

        height: parent.height
        spacing: Theme.paddingSm

        Repeater {
            model: root.workspaceCount

            Item {
                id: slot
                required property int index

                readonly property int number: index + 1
                readonly property bool active: Workspaces.activeId === number
                readonly property bool hasWindows: root.occupied(number)

                width: slot.active
                    ? Theme.iconLg + Theme.paddingMd
                    : Theme.iconLg
                height: parent.height

                Rectangle {
                    id: button

                    anchors.fill: parent
                    radius: Theme.radiusWidget
                    color: slot.active
                        ? root.colors.alpha(root.colors.accent(slot.index), 0.22)
                        : hover.containsMouse
                            ? root.colors.surfaceHover
                            : "transparent"
                    border.width: 0

                    Behavior on color {
                        enabled: !Motion.reduce
                        ColorAnimation {
                            duration: Motion.fast
                            easing.type: Motion.easeStandard
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: slot.number < 10 ? "0" + slot.number : String(slot.number)
                        color: slot.active ? root.colors.accent(slot.index) : root.colors.text
                        font.family: Theme.mono
                        font.pixelSize: Theme.fontSm
                        font.weight: Font.Black
                    }

                    Rectangle {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            bottom: parent.bottom
                            bottomMargin: Theme.paddingSm
                        }

                        width: slot.hasWindows ? Theme.paddingMd : Theme.borderWidth
                        height: Theme.borderWidth
                        radius: Theme.borderWidth / 2
                        color: root.colors.accent(slot.index)
                        opacity: slot.active ? 1.0 : slot.hasWindows ? 0.72 : 0.20

                        Behavior on opacity {
                            enabled: !Motion.reduce
                            NumberAnimation { duration: Motion.fast }
                        }
                    }

                    MouseArea {
                        id: hover
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.focus(slot.number)
                    }
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => {
            if (Compositor.isNiri)
                Compositor.focusRelative(event.angleDelta.y > 0 ? -1 : 1)
            else
                Hyprland.dispatch(event.angleDelta.y > 0 ? "workspace r-1" : "workspace r+1")
        }
    }
}
