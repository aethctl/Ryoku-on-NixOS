import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Ryoku.Ui.Singletons
import "../../../reusables"
import "../../../"

// Ryoku routes workspace facts through the window-manager seam instead of
// probing the compositor or re-polling its event stream directly:
// Wm.workspaces is the live, compositor-neutral list (id, name, active,
// occupied, special), Wm.focusedWorkspace names the active slot, and
// Wm.focusWorkspace(id) is the intent, so one widget serves every supported
// desktop unchanged. The serpantinum slot model (0-based indices, the
// grow-on-active workspaceCount rule, pills/numbers/pacman faces) is preserved.
Rectangle {
    id: workspacesWidgetRoot

    property var barWindow
    property var paths
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { workspacesWidgetRoot.configRevision++; }
        function onRawSettingsChanged() { workspacesWidgetRoot.configRevision++; }
    }

    property string workspacesStyle: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            if (Config.rawSettings.bar.workspacesStyle) return Config.rawSettings.bar.workspacesStyle;
            if (Config.rawSettings.bar.workspaces && Config.rawSettings.bar.workspaces.style) return Config.rawSettings.bar.workspaces.style;
        }
        return "pills";
    }

    property int baseWorkspaceCount: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings) {
            if (Config.rawSettings.bar && Config.rawSettings.bar.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.bar.workspaceCount));
            }
            if (Config.rawSettings.general && Config.rawSettings.general.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.general.workspaceCount));
            }
            if (Config.rawSettings.workspaceCount !== undefined) {
                return Math.max(2, Math.min(10, Config.rawSettings.workspaceCount));
            }
        }
        return 8;
    }

    // The seam's live list; the faces read occupancy through this widget.
    readonly property var wsList: Wm.workspaces

    property int workspaceCount: Math.max(2, (activeIndex >= baseWorkspaceCount) ? (activeIndex + 1) : baseWorkspaceCount)

    property bool hideEmptyWorkspaces: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            if (Config.rawSettings.bar.hideEmptyWorkspaces !== undefined)
                return Boolean(Config.rawSettings.bar.hideEmptyWorkspaces);
        }
        return false;
    }

    ListModel {
        id: workspaceListModel
    }

    function syncModel() {
        let target = workspaceCount;

        while (workspaceListModel.count < target) {
            workspaceListModel.append({ "modelData": workspaceListModel.count });
        }
        while (workspaceListModel.count > target) {
            workspaceListModel.remove(workspaceListModel.count - 1);
        }
    }

    onWorkspaceCountChanged: syncModel()

    function findRepeater(obj) {
        if (!obj) return null;
        if (obj.model !== undefined && obj.count !== undefined && typeof obj.itemAt === "function") {
            return obj;
        }
        if (obj.children) {
            for (let i = 0; i < obj.children.length; i++) {
                let res = findRepeater(obj.children[i]);
                if (res) return res;
            }
        }
        if (obj.data) {
            for (let j = 0; j < obj.data.length; j++) {
                let res = findRepeater(obj.data[j]);
                if (res) return res;
            }
        }
        return null;
    }

    function attachModel() {
        if (faceLoader.item) {
            faceLoader.item.widget = workspacesWidgetRoot;
            let rep = findRepeater(faceLoader.item);
            if (rep && rep.model !== workspaceListModel) {
                rep.model = workspaceListModel;
            }
        }
    }

    function s(val) {
        if (barWindow && typeof barWindow.s === "function") return barWindow.s(val);
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") return Math.round(Scaler.s(val));
        return val;
    }

    function numericSlot(w) {
        let n = parseInt(w.name !== undefined && w.name !== "" ? w.name : w.id);
        return (!isNaN(n) && n > 0) ? n : -1;
    }

    function wsForSlot(index) {
        let list = wsList;
        for (let i = 0; i < list.length; i++) {
            if (!list[i].special && numericSlot(list[i]) === index + 1) return list[i];
        }
        return null;
    }

    function isOccupied(index) {
        let ws = wsForSlot(index);
        return ws !== null && ws.occupied === true;
    }

    function isShown(index) {
        if (!hideEmptyWorkspaces)
            return true;
        return index === activeIndex || isOccupied(index);
    }

    function focusWorkspace(index) {
        let ws = wsForSlot(index);
        Wm.focusWorkspace(ws ? String(ws.id) : String(index + 1));
    }

    property int activeIndex: {
        let fw = Wm.focusedWorkspace;
        if (!fw) return -1;
        let slot = numericSlot(fw);
        return slot > 0 ? slot - 1 : -1;
    }

    Component.onCompleted: syncModel()

    property real targetX: 0
    x: targetX
    Behavior on x {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    radius: ThemeBackend.borderRadius
    border.width: 0
    color: isGrouped ? "transparent" : (isSolid ? (distinctPills ? Qt.darker(ThemeBackend.surface0, 1.15) : "transparent") : ThemeBackend.base)
    height: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))
    y: barWindow ? barWindow.baseOffsetY + (barWindow.barHeight - height) / 2 : 0
    clip: true

    property real targetWidth: (moduleActive && workspaceCount > 0 && faceLoader.item) ? faceLoader.item.implicitWidth + s(isCompact ? 18 : 22) : 0
    width: targetWidth
    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    opacity: (moduleActive && workspaceCount > 0) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    property real wheelAccumulator: 0
    Timer {
        id: wsWheelTimer
        interval: 200
        onTriggered: workspacesWidgetRoot.wheelAccumulator = 0
    }

    MouseArea {
        id: wsScrollArea
        anchors.fill: parent
        z: 10
        acceptedButtons: Qt.NoButton
        cursorShape: Qt.PointingHandCursor
        onWheel: wheel => {
            wsWheelTimer.restart();
            workspacesWidgetRoot.wheelAccumulator += wheel.angleDelta.y;
            const threshold = 120;
            if (Math.abs(workspacesWidgetRoot.wheelAccumulator) >= threshold) {
                let steps = Math.trunc(workspacesWidgetRoot.wheelAccumulator / threshold);
                workspacesWidgetRoot.wheelAccumulator = workspacesWidgetRoot.wheelAccumulator % threshold;

                if (workspacesWidgetRoot.workspaceCount > 1) {
                    let cur = workspacesWidgetRoot.activeIndex;
                    let nextIndex = 0;
                    if (cur < 0) {
                        nextIndex = steps > 0 ? (workspacesWidgetRoot.workspaceCount - 1) : 0;
                    } else {
                        if (steps > 0) {
                            nextIndex = (cur - 1 + workspacesWidgetRoot.workspaceCount) % workspacesWidgetRoot.workspaceCount;
                        } else if (steps < 0) {
                            nextIndex = (cur + 1) % workspacesWidgetRoot.workspaceCount;
                        }
                    }
                    if (nextIndex !== workspacesWidgetRoot.activeIndex) {
                        workspacesWidgetRoot.focusWorkspace(nextIndex);
                    }
                }
            }
        }
    }

    Loader {
        id: faceLoader
        z: 2
        anchors.left: parent.left
        anchors.leftMargin: s(isCompact ? 18 : 22) / 2
        anchors.verticalCenter: parent.verticalCenter
        source: {
            switch (workspacesWidgetRoot.workspacesStyle) {
                case "numbers": return Qt.resolvedUrl("faces/NumbersFace.qml");
                case "pacman": return Qt.resolvedUrl("faces/PacmanFace.qml");
                case "pills":
                default: return Qt.resolvedUrl("faces/PillsFace.qml");
            }
        }
        onLoaded: {
            attachModel();
            Qt.callLater(attachModel);
        }
    }

    Binding {
        target: faceLoader.item
        property: "widget"
        value: workspacesWidgetRoot
    }
}
