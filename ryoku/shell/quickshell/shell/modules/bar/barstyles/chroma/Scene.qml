pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Ryoku.Ui.Singletons
import shell.services
import shell.barkit as Pill
import "components" as C

PanelWindow {
    id: win

    property var modelData
    screen: modelData

    readonly property string outputName: modelData && modelData.name
        ? String(modelData.name)
        : ""
    readonly property real s: Config.chromaScale()
        * Tokens.uiScaleFor(outputName)
    readonly property int barHeight: Math.round((Theme.iconLg + Theme.paddingLg) * s)
    readonly property int outerMargin: Math.round(Theme.paddingMd * s)
    readonly property int gap: Math.round(Config.chromaGap(Theme.paddingMd) * s)
    readonly property string edge: Config.chromaPosition()

    color: "transparent"
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: barHeight + outerMargin * 2

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "ryoku-chroma-bar"

    anchors {
        top: win.edge === "top"
        bottom: win.edge === "bottom"
        left: true
        right: true
    }

    margins {
        left: outerMargin
        right: outerMargin
        top: win.edge === "top" ? outerMargin : 0
        bottom: win.edge === "bottom" ? outerMargin : 0
    }

    implicitHeight: barHeight

    C.Palette {
        id: chroma
        surfaceOpacity: Config.chromaOpacity()
    }

    Item {
        anchors.fill: parent

        Row {
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            spacing: win.gap

            Rectangle {
                id: identityBlock
                visible: Config.chromaWidgetEnabled("identity", win.outputName)
                width: win.barHeight
                height: parent.height
                radius: Config.chromaRadius(Theme.radiusWidget) * win.s
                color: identityMouse.containsMouse ? chroma.accent(4) : chroma.accent(0)
                border.width: 0

                Behavior on color {
                    enabled: !Motion.reduce
                    ColorAnimation { duration: Motion.fast; easing.type: Motion.easeStandard }
                }

                Pill.BrandMark {
                    anchors.centerIn: parent
                    size: Theme.iconMd * win.s
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
                visible: Config.chromaWidgetEnabled("workspaces", win.outputName)
                height: parent.height
                colors: chroma
                s: win.s
                screenName: win.outputName
            }
        }

        C.MediaModule {
            visible: Config.chromaWidgetEnabled("media", win.outputName)
            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
                bottom: parent.bottom
            }
            width: Math.min(430 * win.s, Math.max(300 * win.s, parent.width * 0.30))
            colors: chroma
            s: win.s
        }

        Row {
            anchors {
                right: parent.right
                top: parent.top
                bottom: parent.bottom
            }
            spacing: win.gap

            C.StatusCluster {
                visible:
                    Config.chromaWidgetEnabled("notifications", win.outputName)
                    || Config.chromaWidgetEnabled("wallpaper", win.outputName)
                    || Config.chromaWidgetEnabled("network", win.outputName)
                    || Config.chromaWidgetEnabled("audio", win.outputName)
                    || Config.chromaWidgetEnabled("settings", win.outputName)
                    || (Config.chromaWidgetEnabled("battery", win.outputName) && Battery.present)
                height: parent.height
                colors: chroma
                s: win.s
                screenName: win.outputName
            }

            C.ClockModule {
                visible: Config.chromaWidgetEnabled("clock", win.outputName)
                height: parent.height
                colors: chroma
                s: win.s
            }
        }
    }
}
