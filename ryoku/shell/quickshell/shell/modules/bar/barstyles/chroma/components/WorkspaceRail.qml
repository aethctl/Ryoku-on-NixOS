pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui.Singletons
import shell.services

Rectangle {
    id: root

    required property var colors
    required property real s
    property string screenName: ""

    readonly property bool dynamicModel: Wm.workspaceModel === "dynamic"

    // Bind directly to the Chroma object instead of hiding the dependency behind
    // a helper call. This guarantees a workspace-mode patch invalidates the rail.
    readonly property string labelMode: {
        const cfg = Config.chroma || ({});
        const mode = String(cfg.workspaceMode || "numbers");
        return ["numbers", "names", "dots"].indexOf(mode) >= 0
            ? mode
            : "numbers";
    }

    readonly property var localWorkspaces: Wm.workspaces.filter(ws =>
        !ws.special && (!root.screenName || ws.output === root.screenName))

    readonly property int workspaceCount: {
        if (root.dynamicModel)
            return root.localWorkspaces.length;

        // Fixed-workspace compositors need stable empty slots so a workspace can
        // still be selected before it has ever contained a window.
        let highest = 5;
        for (const ws of Wm.workspaces) {
            const number = Number(ws.name);
            if (!ws.special && number >= 1 && number <= 10)
                highest = Math.max(highest, number);
        }
        return Math.min(10, highest);
    }

    function workspace(slot) {
        if (root.dynamicModel)
            return root.localWorkspaces[slot - 1];

        // Prefer the workspace attached to this bar's output but keep the global
        // fallback for empty/fixed numbered slots.
        return Wm.workspaceByName(String(slot), root.screenName)
            || Wm.workspaceByName(String(slot));
    }

    function isActive(slot) {
        const ws = workspace(slot);
        return !!ws && ws.active;
    }

    function isOccupied(slot) {
        const ws = workspace(slot);
        return !!ws && ws.occupied;
    }

    function focus(slot) {
        const ws = workspace(slot);
        if (ws || !root.dynamicModel)
            Wm.focusWorkspace(ws ? Wm.workspaceKey(ws) : String(slot));
    }

    function cycle(delta) {
        if (!root.dynamicModel) {
            Wm.cycleWorkspace(delta);
            return;
        }

        const list = root.localWorkspaces;
        if (!list.length)
            return;

        const current = Math.max(0, list.findIndex(ws => ws.active));
        root.focus((current + delta + list.length) % list.length + 1);
    }

    readonly property int horizontalPadding: Math.round(8 * root.s)
    readonly property int cellGap: Math.round(4 * root.s)

    // Original Chroma used a reserved slot around each workspace while the
    // workspace itself expanded for hover/active state. The old Ryoku port
    // collapsed DOTS into 5px indicators, producing the "Tic Tac" rail.
    readonly property int dotSlotWidth: Math.round(24 * root.s)
    readonly property int labelCellWidth:
        Math.round((root.labelMode === "names" ? 58 : 30) * root.s)
    readonly property int cellWidth:
        root.labelMode === "dots"
            ? root.dotSlotWidth
            : root.labelCellWidth

    width:
        root.workspaceCount * root.cellWidth
        + Math.max(0, root.workspaceCount - 1) * root.cellGap
        + root.horizontalPadding * 2

    implicitWidth: width
    implicitHeight: Math.round(44 * root.s)

    radius: Config.chromaRadius(14) * root.s
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
                readonly property var workspace: root.workspace(number)

                readonly property string workspaceLabel: {
                    if (root.labelMode === "dots")
                        return "";

                    if (root.labelMode === "names"
                            && cell.workspace
                            && cell.workspace.name)
                        return String(cell.workspace.name).toUpperCase();

                    return cell.number < 10
                        ? "0" + cell.number
                        : String(cell.number);
                }

                width: root.cellWidth
                height: parent.height

                Rectangle {
                    id: workspaceButton

                    anchors.centerIn: parent

                    width: root.labelMode === "dots"
                        ? Math.round((cell.active
                            ? 20
                            : hover.containsMouse ? 16 : 12) * root.s)
                        : parent.width

                    height: root.labelMode === "dots"
                        ? width
                        : Math.max(1, parent.height - 12 * root.s)

                    radius: root.labelMode === "dots"
                        ? width / 2
                        : Math.min(
                            Config.chromaRadius(9) * root.s,
                            height / 2
                        )

                    color: cell.active
                        ? root.colors.accent(cell.index)
                        : hover.containsMouse
                            ? root.colors.alpha(
                                root.colors.accent(cell.index), 0.16)
                            : root.colors.alpha(
                                root.colors.inkOn(root.colors.surface),
                                cell.occupied ? 0.08 : 0.035)

                    Behavior on width {
                        enabled: !Motion.reduce
                        NumberAnimation {
                            duration: Motion.fast
                            easing.type: Motion.easeStandard
                        }
                    }

                    Behavior on height {
                        enabled: !Motion.reduce
                        NumberAnimation {
                            duration: Motion.fast
                            easing.type: Motion.easeStandard
                        }
                    }

                    Behavior on color {
                        enabled: !Motion.reduce
                        ColorAnimation {
                            duration: Motion.fast
                            easing.type: Motion.easeStandard
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible: root.labelMode !== "dots"
                        text: cell.workspaceLabel

                        color: cell.active
                            ? root.colors.inkOn(workspaceButton.color)
                            : root.colors.inkOn(root.colors.surface)

                        opacity: cell.active
                            ? 1.0
                            : cell.occupied ? 0.78 : 0.48

                        font.family: Theme.mono
                        font.pixelSize: 11 * root.s
                        font.weight: cell.active
                            ? Font.Black
                            : Font.DemiBold
                    }

                    Rectangle {
                        visible: root.labelMode !== "dots"

                        anchors {
                            horizontalCenter: parent.horizontalCenter
                            bottom: parent.bottom
                            bottomMargin: 3 * root.s
                        }

                        width: (cell.occupied ? 10 : 3) * root.s
                        height: Math.max(1, 2 * root.s)
                        radius: height / 2

                        color: cell.active
                            ? root.colors.inkOn(workspaceButton.color)
                            : root.colors.accent(cell.index)

                        opacity: cell.active
                            ? 0.9
                            : cell.occupied ? 0.75 : 0.18

                        Behavior on width {
                            enabled: !Motion.reduce
                            NumberAnimation {
                                duration: Motion.fast
                                easing.type: Motion.easeStandard
                            }
                        }
                    }
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

    WheelHandler {
        onWheel: event => {
            if (event.angleDelta.y !== 0)
                root.cycle(event.angleDelta.y > 0 ? -1 : 1);
        }
    }
}
