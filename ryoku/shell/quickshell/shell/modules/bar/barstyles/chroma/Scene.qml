pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import shell.services
import shell.barkit as Pill
import "components" as C

// CHROMA bar for Ryoku.
//
// This is a visual/layout port of aethctl/chroma-shell's ChromaBar.qml onto
// Ryoku's native data plane. It intentionally does not import CHROMA's old
// settings/theme/runtime stack: all state comes from shell.services and every
// colour comes from Ryoku's live Theme/Matugen roles.
PanelWindow {
    id: win

    property var modelData
    screen: modelData

    readonly property int barHeight: Theme.iconLg + Theme.paddingLg
    readonly property int outerMargin: Theme.paddingMd
    readonly property int gap: Theme.paddingMd

    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: barHeight + outerMargin * 2

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-chroma-bar"

    anchors {
        top: true
        left: true
        right: true
    }

    margins {
        left: outerMargin
        right: outerMargin
        top: outerMargin
    }

    implicitHeight: barHeight

    C.Palette {
        id: chroma
    }

    // CHROMA's bar is a set of discrete modules floating in one horizontal
    // signal strip. Keeping the zones independently anchored preserves the
    // centred media card even when the left/right clusters change width.
    Item {
        anchors.fill: parent

        Row {
            id: leftCluster
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            spacing: win.gap

            Rectangle {
                id: identityBlock
                width: win.barHeight
                height: parent.height
                radius: Theme.radiusWidget
                color: identityMouse.containsMouse ? chroma.accent(4) : chroma.accent(0)
                border.width: 0

                Behavior on color {
                    enabled: !Motion.reduce
                    ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
                }

                Pill.BrandMark {
                    anchors.centerIn: parent
                    size: Theme.iconMd
                    color: chroma.inkOn(identityBlock.color)
                    scale: identityMouse.containsMouse ? 1.12 : 1.0

                    Behavior on scale {
                        enabled: !Motion.reduce
                        NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack }
                    }
                }

                MouseArea {
                    id: identityMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const state = ShellState.forScreen(win.modelData)
                        if (state)
                            state.launcherOpen = !state.launcherOpen
                    }
                }
            }

            C.WorkspaceRail {
                height: parent.height
                colors: chroma
            }
        }

        C.MediaModule {
            id: mediaModule
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                bottom: parent.bottom
            }
            width: Math.min(430, Math.max(300, parent.width * 0.30))
            colors: chroma
        }

        Row {
            id: rightCluster
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            spacing: win.gap

            C.StatusCluster {
                height: parent.height
                colors: chroma
            }

            C.ClockModule {
                height: parent.height
                colors: chroma
            }
        }
    }
}
