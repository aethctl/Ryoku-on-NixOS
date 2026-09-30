import QtQuick
import Ryoku.Ui.Singletons

// One background job: its name, state and progress, then only the controls it allows.
Grid {
    id: chip

    required property var task
    property string barStyle: "straight"
    property real railWidth: 0
    readonly property real naturalWidth: face.implicitWidth

    readonly property string taskId: String(chip.task.id || "")
    readonly property string taskState: String(chip.task.state || "")
    readonly property int total: Math.max(Number(chip.task.total || 0), 0)
    readonly property int done: Math.min(Math.max(Number(chip.task.progress || 0), 0), chip.total)
    readonly property var caps: chip.task.capabilities || ({})

    columns: chip.railWidth > 0 ? 1 : 4
    spacing: (chip.railWidth > 0 ? 3 : 4) * Theme.scale

    function _name() {
        if (chip.taskId === "semantic-tags" || chip.taskId === "analysis") return I18n.tr("Tags")
        if (chip.taskId === "semantic-index") return I18n.tr("Index")
        if (chip.taskId === "scan") return I18n.tr("Scan")
        if (chip.taskId.indexOf("download:") === 0) return I18n.tr("Download")
        if (chip.taskId === "we-thumbnails") return I18n.tr("Scene thumbnails")
        return String(chip.task.label || chip.taskId)
    }
    function _state() {
        switch (chip.taskState) {
        case "running": return I18n.tr("Running")
        case "paused": return I18n.tr("Paused")
        case "completed": return I18n.tr("Done")
        case "failed": return I18n.tr("Failed")
        case "cancelled": return I18n.tr("Stopped")
        }
        return chip.taskState
    }
    // Downloads count in percent; the other jobs count items.
    function _progress() {
        if (chip.total <= 0) return ""
        if (chip.task.kind === "download") return " \u00b7 " + Math.round(100 * chip.done / chip.total) + "%"
        if (chip.taskState === "completed") return " \u00b7 " + chip.total
        return " \u00b7 " + chip.done + "/" + chip.total
    }

    BarButton {
        id: face
        barStyle: chip.barStyle
        railWidth: chip.railWidth
        label: chip._name() + " \u00b7 " + chip._state() + chip._progress()
        destructive: chip.taskState === "failed"
        active: chip.taskState === "failed"
        tooltip: chip.task.detail ? String(chip.task.detail) : ""

        Rectangle {
            visible: chip.taskState === "running" && chip.total > 0
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.leftMargin: face.skew
            anchors.bottomMargin: 1
            width: Math.max((parent.width - face.skew * 2) * chip.done / Math.max(chip.total, 1), 0)
            height: 2 * Theme.scale
            color: Theme.primary
            Behavior on width { NumberAnimation { duration: Theme.fast } }
        }
    }

    BarButton {
        visible: chip.caps.pause === true && chip.taskState === "running"
        barStyle: chip.barStyle
        railWidth: chip.railWidth
        label: I18n.tr("Pause")
        onTriggered: Tasks.control(chip.taskId, "pause")
    }
    BarButton {
        visible: chip.caps.resume === true && chip.taskState === "paused"
        barStyle: chip.barStyle
        railWidth: chip.railWidth
        label: I18n.tr("Resume")
        onTriggered: Tasks.control(chip.taskId, "resume")
    }
    BarButton {
        visible: chip.caps.stop === true
        barStyle: chip.barStyle
        railWidth: chip.railWidth
        label: I18n.tr("Stop")
        destructive: true
        onTriggered: Tasks.control(chip.taskId, "stop")
    }
}
