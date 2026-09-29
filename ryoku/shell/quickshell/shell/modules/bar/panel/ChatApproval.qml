pragma ComponentBehavior: Bound

import QtQuick
import shell.services
import "../../../components"
import Ryoku.Ui.Singletons

// The one thing a turn cannot continue without: an approval the agent is waiting
// on. It shows the exact command or input and compact Allow / Always / Reject
// buttons. Answering sends the pick over the shared stream; every open approval
// shows once and disappears when it resolves (whoever answered it).
Rectangle {
    id: root

    property real s: 1
    // perm: {requestId, toolId, title, kind, input, options:[{id,name,kind}]}
    property var perm: null

    readonly property string command: {
        if (!root.perm)
            return "";
        var input = String(root.perm.input || "");
        return input.length > 0 ? input : String(root.perm.title || "");
    }
    // Allow, Always allow, and Reject cover every answer; a standing "always
    // reject" rule only adds a fourth button to a prompt that should stay quick.
    // The daemon usually offers its own reject; add a Decline only when it did not.
    readonly property var options: {
        if (!root.perm || !root.perm.options)
            return [];
        var opts = root.perm.options.filter((o) => String(o.kind || "") !== "reject_always");
        var hasReject = opts.some((o) => String(o.kind || "").indexOf("reject") >= 0);
        return hasReject ? opts : opts.concat([{ id: "", name: I18n.tr("Decline"), kind: "reject_once" }]);
    }

    implicitHeight: col.implicitHeight + 20 * root.s
    radius: 8 * root.s
    color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.10)
    border.width: 1
    border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.45)

    Column {
        id: col
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 10 * root.s
        spacing: 8 * root.s

        Row {
            spacing: 6 * root.s
            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "shield"
                font.pixelSize: 13 * root.s
                color: Theme.primary
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("NEEDS YOUR OK")
                color: Theme.primary
                font.family: Theme.mono
                font.pixelSize: 8 * root.s
                font.letterSpacing: 1.2
                font.weight: Font.DemiBold
            }
        }

        Text {
            width: parent.width
            visible: root.command.length > 0
            text: root.command
            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
            font.family: Theme.mono
            font.pixelSize: 10.5 * root.s
            wrapMode: Text.WrapAnywhere
            maximumLineCount: 3
            elide: Text.ElideRight
        }

        Flow {
            width: parent.width
            spacing: 6 * root.s
            Repeater {
                model: root.options
                delegate: Rectangle {
                    id: btn
                    required property var modelData
                    readonly property bool reject: String(btn.modelData.kind || "").indexOf("reject") >= 0
                    readonly property bool allow: !btn.reject
                    height: 28 * root.s
                    width: btnRow.implicitWidth + 22 * root.s
                    radius: 7 * root.s
                    color: btn.allow
                        ? (bArea.containsMouse ? Qt.lighter(Theme.primary, 1.12) : Theme.primary)
                        : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, bArea.containsMouse ? 0.14 : 0.06)
                    border.width: btn.allow ? 0 : 1
                    border.color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.18)
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Row {
                        id: btnRow
                        anchors.centerIn: parent
                        spacing: 5 * root.s
                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: btn.allow ? "check" : "close"
                            font.pixelSize: 13 * root.s
                            color: btn.allow ? Theme.inkOn(Theme.primary, Theme.onPrimary)
                                : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: String(btn.modelData.name || btn.modelData.id)
                            color: btn.allow ? Theme.inkOn(Theme.primary, Theme.onPrimary)
                                : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                            font.family: Theme.fontPrimary
                            font.pixelSize: 11 * root.s
                            font.weight: btn.allow ? Font.DemiBold : Font.Normal
                        }
                    }
                    MouseArea {
                        id: bArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Needle.answerPermission(root.perm.requestId, btn.modelData.id)
                    }
                }
            }
        }
    }
}
