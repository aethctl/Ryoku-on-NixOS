pragma ComponentBehavior: Bound

import QtQuick
import shell.services

Rectangle {
    id: root

    required property var colors
    property string screenName: ""

    readonly property string workspaceOutput:
        Wm.workspaceModel === "dynamic" ? root.screenName : ""

    readonly property int workspaceCount: {
        // Chroma must always have at least five visible slots. Wm workspace
        // state can be unavailable briefly while the compositor provider comes
        // online; never let that transient state collapse the rail to zero width.
        if (Wm.workspaceModel === "dynamic")
            return 5

        let highest = 5
        const list = Array.isArray(Wm.workspaces) ? Wm.workspaces : []

        for (let i = 0; i < list.length; ++i) {
            const ws = list[i]
            if (!ws || ws.special)
                continue

            const id = Number(ws.name)
            if (!isNaN(id) && id >= 1 && id <= 10)
                highest = Math.max(highest, id)
        }

        return Math.min(10, highest)
    }

    function workspaceName(id) {
        if (Wm.workspaceModel === "dynamic" && root.workspaceOutput.length > 0)
            return "ryoku:" + root.workspaceOutput + ":" + id

        return String(id)
    }

    function workspace(id) {
        return Wm.workspaceByName(
            root.workspaceName(id),
            root.workspaceOutput
        )
    }

    function isActive(id) {
        const ws = root.workspace(id)
        return !!ws && ws.active
    }

    function isOccupied(id) {
        const ws = root.workspace(id)
        return !!ws && ws.occupied
    }

    function focus(id) {
        Wm.focusWorkspace(root.workspaceName(id))
    }

    function cycle(delta) {
        if (Wm.workspaceModel === "dynamic" && root.workspaceOutput.length > 0) {
            let current = 1

            for (let id = 1; id <= root.workspaceCount; ++id) {
                if (root.isActive(id)) {
                    current = id
                    break
                }
            }

            let next = current + delta

            if (next < 1)
                next = root.workspaceCount
            else if (next > root.workspaceCount)
                next = 1

            root.focus(next)
            return
        }

        Wm.cycleWorkspace(delta)
    }

    // Explicit geometry: Chroma owns exactly this much bar space.
    readonly property int cellWidth: 30
    readonly property int cellGap: 4
    readonly property int horizontalPadding: 8

    width:
        root.workspaceCount * root.cellWidth
        + Math.max(0, root.workspaceCount - 1) * root.cellGap
        + root.horizontalPadding * 2

    implicitWidth: width
    implicitHeight: 44

    radius: 14
    color: root.colors.surface
    border.width: 0
    clip: true

    Row {
        anchors {
            fill: parent
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }

        spacing: root.cellGap

        Repeater {
            model: root.workspaceCount

            delegate: Item {
                id: cell
                required property int index

                readonly property int number: index + 1
                readonly property bool active: root.isActive(number)
                readonly property bool occupied: root.isOccupied(number)

                width: root.cellWidth
                height: parent.height

                Rectangle {
                    anchors {
                        fill: parent
                        topMargin: 6
                        bottomMargin: 6
                    }

                    radius: 9

                    color: cell.active
                        ? root.colors.alpha(root.colors.accent(cell.index), 0.28)
                        : hover.containsMouse
                            ? root.colors.alpha(root.colors.accent(cell.index), 0.12)
                            : root.colors.alpha(
                                root.colors.inkOn(root.colors.surface),
                                cell.occupied ? 0.08 : 0.035
                            )

                    Text {
                        anchors.centerIn: parent

                        text: cell.number < 10
                            ? "0" + cell.number
                            : String(cell.number)

                        color: cell.active
                            ? root.colors.inkOn(root.colors.accent(cell.index))
                            : root.colors.inkOn(root.colors.surface)

                        opacity: cell.active ? 1.0 : (cell.occupied ? 0.78 : 0.48)

                        font.family: Theme.mono
                        font.pixelSize: 11
                        font.weight: cell.active ? Font.Black : Font.DemiBold
                    }

                    Rectangle {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            bottom: parent.bottom
                            bottomMargin: 3
                        }

                        width: cell.occupied ? 10 : 3
                        height: 2
                        radius: 1

                        color: root.colors.accent(cell.index)
                        opacity: cell.active
                            ? 1.0
                            : cell.occupied
                                ? 0.75
                                : 0.18
                    }

                    MouseArea {
                        id: hover

                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        cursorShape: Qt.PointingHandCursor

                        onClicked: root.focus(cell.number)
                    }
                }
            }
        }
    }

    WheelHandler {
        onWheel: event => {
            if (event.angleDelta.y !== 0)
                root.cycle(event.angleDelta.y > 0 ? -1 : 1)
        }
    }
}
