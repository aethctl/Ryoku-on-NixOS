pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Ryoku.Ui.Singletons
import shell.services

Scope {
    id: root
    required property var screen
    required property string side
    property bool visible: true
    readonly property real s: Tokens.uiScaleFor(screen ? screen.name : "")
    readonly property var options: Config.sidebars[side]
    readonly property bool open: SidebarState.isOpen(screen, side)
    readonly property var clearances: SidebarState.railClearances(screen)
    readonly property real gap: Tokens.s4 * s
    readonly property real screenWidth: screen && screen.width > 0 ? screen.width : 1280
    readonly property real screenHeight: screen && screen.height > 0 ? screen.height : 800
    readonly property real availableWidth: Math.max(1, screenWidth - clearances.left - clearances.right - gap * 2)
    readonly property real availableHeight: Math.max(1, screenHeight - clearances.top - clearances.bottom - gap * 2)
    readonly property real wantedWidth: Math.min(availableWidth, options.width * s)
    readonly property real heightCap: Math.min(availableHeight, screenHeight * options.maxHeight / 100)
    readonly property real wantedHeight: Math.min(heightCap, options.heightMode === "fit"
        ? Math.max(520 * s, chrome.fittedHeight) : options.height * s)
    readonly property real panelX: side === "right"
        ? screenWidth - clearances.right - gap - wantedWidth : clearances.left + gap
    readonly property real panelY: options.position === "top" ? clearances.top + gap
        : options.position === "bottom" ? screenHeight - clearances.bottom - gap - wantedHeight
        : Math.max(clearances.top + gap, Math.min((screenHeight - wantedHeight) / 2,
            screenHeight - clearances.bottom - gap - wantedHeight))
    property real reveal: open ? 1 : 0

    onRevealChanged: SidebarState.setProgress(screen, side, reveal)
    Component.onCompleted: SidebarState.setProgress(screen, side, reveal)
    Component.onDestruction: SidebarState.setProgress(screen, side, 0)
    Behavior on reveal {
        enabled: !Motion.reduce && !Tokens.reduceMotion
        NumberAnimation { duration: root.open ? SidebarState.enterDuration : SidebarState.exitDuration; easing.type: Tokens.ease }
    }

    PanelWindow {
        id: panel
        screen: root.screen
        visible: root.visible && (root.open || root.reveal > 0.001)
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "ryoku-sidebar-" + root.side
        WlrLayershell.keyboardFocus: !root.open ? WlrKeyboardFocus.None
            : root.options.pinned ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive
        mask: Region {
            x: root.open && !root.options.pinned ? 0 : root.panelX
            y: root.open && !root.options.pinned ? 0 : root.panelY
            width: root.open && !root.options.pinned ? panel.width : root.wantedWidth
            height: root.open && !root.options.pinned ? panel.height : root.wantedHeight
            Region { intersection: Intersection.Subtract; width: panel.width; height: root.clearances.top }
            Region { intersection: Intersection.Subtract; y: panel.height - root.clearances.bottom; width: panel.width; height: root.clearances.bottom }
            Region { intersection: Intersection.Subtract; width: root.clearances.left; height: panel.height }
            Region { intersection: Intersection.Subtract; x: panel.width - root.clearances.right; width: root.clearances.right; height: panel.height }
        }
        MouseArea {
            anchors.fill: parent
            enabled: root.open && !root.options.pinned
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: mouse => {
                if (mouse.x < surface.x || mouse.x >= surface.x + surface.width
                        || mouse.y < surface.y || mouse.y >= surface.y + surface.height)
                    Qt.callLater(() => SidebarState.closeSide(root.side, root.screen));
            }
        }
        Item {
            id: surface
            x: root.panelX; y: root.panelY
            width: root.wantedWidth; height: root.wantedHeight
            opacity: root.reveal
            transform: Translate { x: (1 - root.reveal) * Tokens.s5 * root.s * (root.side === "left" ? -1 : 1) }
            SidebarFrame { anchors.fill: parent; s: root.s }
            SidebarChrome {
                id: chrome
                anchors.fill: parent
                screen: root.screen; side: root.side
                reveal: root.reveal; open: root.open
                maximumHeight: root.heightCap
                onCloseRequested: SidebarState.closeSide(root.side, root.screen)
            }
        }
    }
}
