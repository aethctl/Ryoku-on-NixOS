import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland
import Ryoku.Ui.Singletons

PanelWindow {
    id: wsPanel
    required property var root

    screen: root.activePopupScreen

    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ryoku-workspace"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    property real reveal: root.workspaceVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.workspaceVisible ? 160 : 120
            easing.type: root.workspaceVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.workspaceVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.workspaceVisible = false }

    Rectangle {
        id: card
        property int navIndex: -1
        readonly property var panelWorkspaces: {
            var rows = []

            if (Wm.workspaceModel === "dynamic") {
                var output = root.activePopupScreenName
                if (output === "") return rows

                for (var slot = 1; slot <= 5; slot++) {
                    var name = "ryoku:" + output + ":" + slot
                    var workspace = Wm.workspaceByName(name, output)

                    rows.push(workspace || ({
                        id: "",
                        name: name,
                        active: false,
                        focused: false,
                        occupied: false,
                        windows: 0,
                        fullscreen: false,
                        special: false,
                        output: output,
                        layout: ""
                    }))
                }

                return rows
            }

            var live = Wm.workspaces
            for (var i = 0; i < live.length; i++) {
                if (!live[i].special)
                    rows.push(live[i])
            }

            rows.sort(function(x, y) {
                return Number(x.name) - Number(y.name)
            })

            return rows
        }

        readonly property var wsIds: {
            var ids = []

            for (var i = 0; i < panelWorkspaces.length; i++) {
                var workspace = panelWorkspaces[i]
                ids.push(Wm.workspaceModel === "dynamic"
                    ? String(workspace.name)
                    : String(workspace.id || workspace.name))
            }

            return ids
        }
        width: 240
        height: col.implicitHeight + 24
        radius: reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.color: root.panelBorder
        border.width: 0
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: wsPanel.root
            ownerActive: wsPanel.root.workspaceVisible
            targetX: wsPanel.root.workspaceBarX
            reveal: wsPanel.reveal
        }

        x: Math.round(Math.max(6, Math.min(root.workspaceBarX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - barBottom - gap - height) + 2 * (1 - wsPanel.reveal)
            : (barBottom + gap) - 2 * (1 - wsPanel.reveal)
        opacity: wsPanel.reveal
        focus: root.workspaceVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.workspaceVisible = false; event.accepted = true }
            else if (event.key === Qt.Key_Down) { card.navIndex = card.navIndex < 0 ? 0 : Math.min(card.navIndex + 1, card.wsIds.length - 1); event.accepted = true }
            else if (event.key === Qt.Key_Up) { card.navIndex = card.navIndex <= 0 ? 0 : card.navIndex - 1; event.accepted = true }
            else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && card.navIndex >= 0 && card.navIndex < card.wsIds.length) {
                root.gotoWorkspace(card.wsIds[card.navIndex]); root.workspaceVisible = false; event.accepted = true
            }
        }

        MouseArea { anchors.fill: parent; onClicked: {} }

        Column {
            id: col
            anchors.fill: parent
            anchors.margins: 12
            spacing: 8

            Item {
                width: parent.width
                height: 24
                UiText {
                    anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Workspaces")
                    color: root.ink; font.family: root.mono; font.pixelSize: 13
                    font.letterSpacing: 2; font.weight: Font.Medium
                }
                UiText {
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    text: "✕"; color: closeMa.containsMouse ? root.seal : root.sumi; font.pixelSize: 12
                    Behavior on color { ColorAnimation { duration: 120 } }
                    MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: root.workspaceVisible = false }
                }
            }

            Rectangle { width: parent.width; height: 1; color: root.sep }

            Column {
                width: parent.width
                spacing: 4
                Repeater {
                    model: card.panelWorkspaces

                    delegate: Rectangle {
                        required property var modelData
                        visible: !modelData.special
                        readonly property string wsName:
                            String(modelData.name || "")
                        readonly property string wsHandle:
                            Wm.workspaceModel === "dynamic"
                                ? wsName
                                : String(modelData.id || modelData.name)
                        readonly property string wsLabel:
                            Wm.workspaceModel === "dynamic"
                                ? wsName.substring(wsName.lastIndexOf(":") + 1)
                                : wsName
                        readonly property bool isActive: {
                            if (Wm.workspaceModel === "dynamic")
                                return modelData.active === true

                            var f = Wm.focusedWorkspace
                            return !!f && String(f.id || f.name) === wsHandle
                        }
                        readonly property bool navOn:
                            card.navIndex >= 0
                            && card.navIndex < card.wsIds.length
                            && card.wsIds[card.navIndex] === wsHandle
                        width: col.width
                        height: 30; radius: root.panelButtonRadius
                        color: isActive ? root.fillActive
                                : (navOn || ma.containsMouse) ? root.fillHover : root.fillIdle
                        border.color: (ma.containsMouse || isActive || navOn) ? root.seal : root.sep
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        UiText {
                            anchors.left: parent.left; anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Workspace %1").arg(wsLabel)
                            color: (ma.containsMouse || isActive) ? root.seal : root.ink
                            font.family: root.mono; font.pixelSize: 12
                            font.weight: isActive ? Font.Medium : Font.Normal
                        }
                        UiText {
                            anchors.right: parent.right; anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.windows !== undefined
                               ? String(modelData.windows)
                               : ""
                            color: root.sumiHi; font.family: root.mono; font.pixelSize: 10
                        }

                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.gotoWorkspace(wsHandle)
                                root.workspaceVisible = false
                            }
                        }
                    }
                }
            }
        }
    }

}
