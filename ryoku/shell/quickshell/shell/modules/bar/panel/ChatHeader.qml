pragma ComponentBehavior: Bound

import QtQuick
import shell.services
import "../../../components"
import Ryoku.Ui.Singletons

// The chat header: the masthead, the agent + model chip (opens the picker), an
// approvals toggle that flips the shared session between auto-approving reads and
// asking every time, and new-chat and history actions.
Item {
    id: root

    property real s: 1
    signal requestModelPicker()
    signal requestHistory()
    signal requestNewChat()

    implicitHeight: 40 * root.s

    function shortModel(id) {
        var t = String(id);
        var c = t.lastIndexOf("/");
        if (c < 0) c = t.lastIndexOf(":");
        return c >= 0 ? t.slice(c + 1) : t;
    }
    function chipLabel() {
        var a = String(Needle.currentAgent);
        var m = Needle.currentModel.length > 0 ? root.shortModel(Needle.currentModel) : "";
        if (a.length > 0 && m.length > 0) return a + " · " + m;
        return a.length > 0 ? a : (m.length > 0 ? m : I18n.tr("Agent"));
    }

    Text {
        id: masthead
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: I18n.tr("RASHIN")
        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
        font.family: Theme.mono
        font.pixelSize: 9 * root.s
        font.letterSpacing: 1.5
        font.weight: Font.DemiBold
    }

    Row {
        id: actions
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 4 * root.s

        // approvals toggle
        Rectangle {
            id: appr
            anchors.verticalCenter: parent.verticalCenter
            readonly property bool on: Needle.approvalsMode === "read-only"
            height: 20 * root.s
            width: apprRow.implicitWidth + 12 * root.s
            radius: 10 * root.s
            color: appr.on ? Theme.primary
                : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, apprArea.containsMouse ? 0.12 : 0.06)
            Behavior on color { ColorAnimation { duration: Motion.fast } }
            Row {
                id: apprRow
                anchors.centerIn: parent
                spacing: 3 * root.s
                MaterialIcon {
                    anchors.verticalCenter: parent.verticalCenter
                    text: appr.on ? "verified_user" : "shield"
                    font.pixelSize: 11 * root.s
                    color: appr.on ? Theme.inkOn(Theme.primary, Theme.onPrimary)
                        : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: appr.on ? I18n.tr("READ-ONLY") : I18n.tr("ASK EACH")
                    color: appr.on ? Theme.inkOn(Theme.primary, Theme.onPrimary)
                        : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    font.family: Theme.mono
                    font.pixelSize: 7.5 * root.s
                    font.letterSpacing: 0.8
                    font.weight: Font.DemiBold
                }
            }
            MouseArea {
                id: apprArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Needle.setApprovals(appr.on ? "ask" : "read-only")
            }
        }

        Repeater {
            model: [
                { icon: "history", act: "history" },
                { icon: "add_comment", act: "new" }
            ]
            delegate: Rectangle {
                id: hbtn
                required property var modelData
                anchors.verticalCenter: parent.verticalCenter
                width: 24 * root.s
                height: 24 * root.s
                radius: width / 2
                color: hArea.containsMouse
                    ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
                    : "transparent"
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                MaterialIcon {
                    anchors.centerIn: parent
                    font.pixelSize: 13 * root.s
                    text: hbtn.modelData.icon
                    color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                }
                MouseArea {
                    id: hArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (hbtn.modelData.act === "new") root.requestNewChat();
                        else root.requestHistory();
                    }
                }
            }
        }
    }

    // agent + model chip, between the masthead and the actions
    Rectangle {
        id: chip
        anchors.left: masthead.right
        anchors.right: actions.left
        anchors.leftMargin: 8 * root.s
        anchors.rightMargin: 8 * root.s
        anchors.verticalCenter: parent.verticalCenter
        height: 20 * root.s
        radius: 10 * root.s
        visible: Needle.currentAgent.length > 0 || Needle.currentModel.length > 0
        color: chipArea.containsMouse
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.18)
            : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.06)
        Behavior on color { ColorAnimation { duration: Motion.fast } }
        Row {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: 8 * root.s
            anchors.rightMargin: 6 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3 * root.s
            Text {
                width: parent.width - 13 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: root.chipLabel()
                elide: Text.ElideRight
                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                font.family: Theme.mono
                font.pixelSize: 8.5 * root.s
            }
            MaterialIcon {
                anchors.verticalCenter: parent.verticalCenter
                text: "expand_more"
                font.pixelSize: 10 * root.s
                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
            }
        }
        MouseArea {
            id: chipArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.requestModelPicker()
        }
    }
}
