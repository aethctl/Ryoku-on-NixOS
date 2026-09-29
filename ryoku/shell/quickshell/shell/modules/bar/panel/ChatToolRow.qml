import QtQuick
import shell.services
import "../../../components"
import Ryoku.Ui.Singletons

// One tool the agent ran, as a compact activity row: a glyph by kind, the title,
// the one-line input in mono, a live status, an "auto" mark when the daemon
// auto-approved it, and an expandable preview of the output and any diffs. An
// approval the agent is waiting on for this tool renders inline underneath.
Item {
    id: root

    property real s: 1
    property string toolId: ""
    property string title: ""
    property string tkind: ""
    property string status: "pending"
    property string input: ""
    property string output: ""
    property string diffsJson: "[]"
    property bool auto: false
    property string permJson: ""

    property bool expanded: false

    readonly property bool running: root.status !== "completed" && root.status !== "failed"
    readonly property bool failed: root.status === "failed"
    readonly property var diffs: {
        try { return JSON.parse(root.diffsJson) || []; } catch (e) { return []; }
    }
    readonly property var perm: {
        if (root.permJson.length === 0)
            return null;
        try { return JSON.parse(root.permJson); } catch (e) { return null; }
    }
    readonly property bool hasPreview: root.output.trim().length > 0 || root.diffs.length > 0
    readonly property string kindGlyph: {
        switch (root.tkind) {
        case "read": return "description";
        case "edit": return "edit_note";
        case "execute": return "terminal";
        case "search": return "search";
        case "fetch": return "public";
        case "delete": return "delete";
        case "move": return "drive_file_move";
        case "think": return "psychology";
        default: return "build";
        }
    }
    // The first ~12 lines of output, trimmed; the rest is summarised.
    readonly property var outLines: root.output.replace(/\s+$/, "").split("\n")
    readonly property string outHead: root.outLines.slice(0, 12).join("\n")
    readonly property int outMore: Math.max(0, root.outLines.length - 12)

    implicitHeight: col.implicitHeight

    Column {
        id: col
        width: parent.width
        spacing: 4 * root.s

        // header row
        Item {
            width: parent.width
            height: 20 * root.s

            MaterialIcon {
                id: glyph
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 12 * root.s
                text: root.kindGlyph
                color: root.failed ? Theme.vermLit : Theme.primary
                opacity: 0.95
            }

            // status marker on the right
            MaterialIcon {
                id: statusIcon
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                font.pixelSize: 13 * root.s
                text: root.running ? "progress_activity" : root.failed ? "error" : "check"
                color: root.failed ? Theme.vermLit : Theme.primary
                opacity: root.running ? 0.6 : 0.9
                NumberAnimation on rotation {
                    running: root.running
                    from: 0; to: 360
                    duration: 900
                    loops: Animation.Infinite
                }
            }

            // "auto" mark, left of the status
            Text {
                id: autoTag
                visible: root.auto
                anchors.right: statusIcon.left
                anchors.rightMargin: 6 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("AUTO")
                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                font.family: Theme.mono
                font.pixelSize: 7 * root.s
                font.letterSpacing: 1.0
                opacity: 0.8
            }

            // expand chevron when there is a preview
            MaterialIcon {
                id: chevron
                visible: root.hasPreview
                anchors.right: root.auto ? autoTag.left : statusIcon.left
                anchors.rightMargin: 6 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: "expand_more"
                font.pixelSize: 12 * root.s
                rotation: root.expanded ? 180 : 0
                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                opacity: 0.7
                Behavior on rotation { NumberAnimation { duration: Motion.fast } }
            }

            Row {
                anchors.left: glyph.right
                anchors.right: chevron.visible ? chevron.left : (root.auto ? autoTag.left : statusIcon.left)
                anchors.leftMargin: 6 * root.s
                anchors.rightMargin: 6 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6 * root.s
                Text {
                    id: titleText
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.title.length > 0 ? root.title : (root.tkind.length > 0 ? root.tkind : I18n.tr("tool"))
                    color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                    font.family: Theme.fontPrimary
                    font.pixelSize: 11 * root.s
                    elide: Text.ElideRight
                    // Give the input room but never let the title vanish.
                    width: Math.min(implicitWidth, parent.width * 0.55)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    // A title like "$ uname -r" already carries the command.
                    visible: root.input.length > 0 && root.title.indexOf(root.input) < 0
                    text: root.input
                    color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    font.family: Theme.mono
                    font.pixelSize: 9.5 * root.s
                    elide: Text.ElideMiddle
                    width: parent.width - titleText.width - 6 * root.s
                    opacity: 0.85
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: root.hasPreview
                cursorShape: root.hasPreview ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: root.expanded = !root.expanded
            }
        }

        // output preview
        Rectangle {
            width: parent.width
            visible: root.expanded && root.output.trim().length > 0
            implicitHeight: visible ? outCol.implicitHeight + 12 * root.s : 0
            radius: 6 * root.s
            color: Qt.rgba(0, 0, 0, 0.28)
            border.width: 1
            border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
            Column {
                id: outCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 6 * root.s
                spacing: 3 * root.s
                Text {
                    width: parent.width
                    text: root.outHead
                    color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                    font.family: Theme.mono
                    font.pixelSize: 10 * root.s
                    wrapMode: Text.WrapAnywhere
                    textFormat: Text.PlainText
                }
                Text {
                    visible: root.outMore > 0
                    text: I18n.tr("+%1 more lines").arg(root.outMore)
                    color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    font.family: Theme.mono
                    font.pixelSize: 8.5 * root.s
                    opacity: 0.8
                }
            }
        }

        // diffs
        Column {
            width: parent.width
            visible: root.expanded && root.diffs.length > 0
            spacing: 4 * root.s
            Repeater {
                model: root.expanded ? root.diffs : []
                delegate: Rectangle {
                    id: dcell
                    required property var modelData
                    width: parent.width
                    implicitHeight: dCol.implicitHeight + 10 * root.s
                    radius: 6 * root.s
                    color: Qt.rgba(0, 0, 0, 0.28)
                    border.width: 1
                    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.3)
                    Column {
                        id: dCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 6 * root.s
                        spacing: 3 * root.s
                        Row {
                            spacing: 5 * root.s
                            MaterialIcon {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "edit_note"
                                font.pixelSize: 11 * root.s
                                color: Theme.primary
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: String(dcell.modelData.path || "")
                                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                                font.family: Theme.mono
                                font.pixelSize: 9.5 * root.s
                                elide: Text.ElideMiddle
                                width: dcell.width - 30 * root.s
                            }
                        }
                        Text {
                            width: parent.width
                            visible: String(dcell.modelData.old || "").length > 0
                            text: "- " + String(dcell.modelData.old || "").replace(/\s+$/, "").split("\n").slice(0, 4).join("\n- ")
                            color: Theme.vermDim
                            font.family: Theme.mono
                            font.pixelSize: 9.5 * root.s
                            wrapMode: Text.WrapAnywhere
                        }
                        Text {
                            width: parent.width
                            visible: String(dcell.modelData.new || "").length > 0
                            text: "+ " + String(dcell.modelData.new || "").replace(/\s+$/, "").split("\n").slice(0, 4).join("\n+ ")
                            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                            font.family: Theme.mono
                            font.pixelSize: 9.5 * root.s
                            wrapMode: Text.WrapAnywhere
                        }
                    }
                }
            }
        }

        // inline approval for this tool
        Loader {
            width: parent.width
            active: root.perm !== null
            visible: active
            sourceComponent: ChatApproval {
                s: root.s
                width: col.width
                perm: root.perm
            }
        }
    }
}
