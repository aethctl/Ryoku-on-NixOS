pragma ComponentBehavior: Bound

import QtQuick
import shell.services

Rectangle {
    id: root

    required property var colors
    required property real s
    property string screenName: ""

    readonly property bool dynamicModel: Wm.workspaceModel === "dynamic"
    readonly property var localWorkspaces: Wm.workspaces.filter(ws =>
        !ws.special && (!root.screenName || ws.output === root.screenName))
    readonly property int workspaceCount: {
        if (root.dynamicModel)
            return root.localWorkspaces.length
        let highest = 5
        for (const ws of Wm.workspaces) {
            const number = Number(ws.name)
            if (!ws.special && number >= 1 && number <= 10)
                highest = Math.max(highest, number)
        }
        return Math.min(10, highest)
    }

    function workspace(slot) {
        return root.dynamicModel ? root.localWorkspaces[slot - 1]
                                 : Wm.workspaceByName(String(slot))
    }
    function isActive(slot) { const ws = workspace(slot); return !!ws && ws.active }
    function isOccupied(slot) { const ws = workspace(slot); return !!ws && ws.occupied }
    function focus(slot) {
        const ws = workspace(slot)
        if (ws || !root.dynamicModel)
            Wm.focusWorkspace(ws ? Wm.workspaceKey(ws) : String(slot))
    }
    function cycle(delta) {
        if (!root.dynamicModel) { Wm.cycleWorkspace(delta); return }
        const list = root.localWorkspaces
        if (!list.length) return
        const current = Math.max(0, list.findIndex(ws => ws.active))
        root.focus((current + delta + list.length) % list.length + 1)
    }

    readonly property int cellWidth: Math.round(30 * root.s)
    readonly property int cellGap: Math.round(4 * root.s)
    readonly property int horizontalPadding: Math.round(8 * root.s)

    width:
        root.workspaceCount * root.cellWidth
        + Math.max(0, root.workspaceCount - 1) * root.cellGap
        + root.horizontalPadding * 2

    implicitWidth: width
    implicitHeight: Math.round(44 * root.s)

    radius: 14 * root.s
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
                        topMargin: 6 * root.s
                        bottomMargin: 6 * root.s
                    }

                    radius: 9 * root.s

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
                        text: cell.number < 10 ? "0" + cell.number : String(cell.number)
                        color: cell.active
                            ? root.colors.inkOn(root.colors.accent(cell.index))
                            : root.colors.inkOn(root.colors.surface)
                        opacity: cell.active ? 1.0 : (cell.occupied ? 0.78 : 0.48)
                        font.family: Theme.mono
                        font.pixelSize: 11 * root.s
                        font.weight: cell.active ? Font.Black : Font.DemiBold
                    }

                    Rectangle {
                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            bottom: parent.bottom
                            bottomMargin: 3 * root.s
                        }

                        width: (cell.occupied ? 10 : 3) * root.s
                        height: Math.max(1, 2 * root.s)
                        radius: height / 2

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
