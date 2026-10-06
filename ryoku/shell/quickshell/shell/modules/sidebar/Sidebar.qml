pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Ryoku.Ui.Singletons
import shell.services

Scope {
    id: root
    required property var screen
    property bool active: false
    readonly property real s: Tokens.uiScaleFor(screen ? screen.name : "")
    readonly property var clearances: SidebarState.railClearances(screen)
    readonly property real gap: Tokens.s3 * s
    readonly property real screenWidth: screen && screen.width > 0 ? screen.width : 1280
    readonly property real screenHeight: screen && screen.height > 0 ? screen.height : 800
    readonly property real availableWidth: Math.max(1, screenWidth - clearances.left - clearances.right - gap * 2)
    readonly property real availableHeight: Math.max(1, screenHeight - clearances.top - clearances.bottom - gap * 2)
    readonly property real wantedWidth: Math.min(availableWidth, 688 * s)
    readonly property real wantedHeight: Math.min(availableHeight, chrome.fittedHeight)
    readonly property real panelX: clearances.left + gap
    readonly property real panelY: clearances.top + gap
    property real reveal: active ? 1 : 0

    Behavior on reveal {
        enabled: !Motion.reduce && !Tokens.reduceMotion
        NumberAnimation {
            duration: root.active ? SidebarState.enterDuration : SidebarState.exitDuration
            easing.type: Easing.Bezier
            easing.bezierCurve: root.active ? SidebarState.enterCurve : SidebarState.exitCurve
        }
    }

    // The dismiss surface never animates. Only the small corner buffer redraws.
    PanelWindow {
        id: dismiss
        screen: root.screen
        visible: root.active
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        anchors { top: true; bottom: true; left: true; right: true }
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "ryoku-corner-dismiss"
        // Both windows must be modal for the click-away surface to receive input.
        WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        mask: Region {
            width: dismiss.width
            height: dismiss.height
            Region { intersection: Intersection.Subtract; x: root.panelX; y: root.panelY; width: root.wantedWidth; height: root.wantedHeight }
            Region { intersection: Intersection.Subtract; width: dismiss.width; height: root.clearances.top }
            Region { intersection: Intersection.Subtract; y: dismiss.height - root.clearances.bottom; width: dismiss.width; height: root.clearances.bottom }
            Region { intersection: Intersection.Subtract; width: root.clearances.left; height: dismiss.height }
            Region { intersection: Intersection.Subtract; x: dismiss.width - root.clearances.right; width: root.clearances.right; height: dismiss.height }
        }
        MouseArea {
            anchors.fill: parent
            focus: root.active
            Keys.onEscapePressed: SidebarState.close(root.screen)
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: Qt.callLater(() => SidebarState.close(root.screen))
        }
    }
    PanelWindow {
        id: panel
        screen: root.screen
        visible: root.active || root.reveal > 0.001
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        exclusiveZone: 0
        anchors { top: true; left: true }
        margins.top: root.panelY
        margins.left: root.clearances.left + root.gap
        implicitWidth: root.wantedWidth
        implicitHeight: root.wantedHeight
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "ryoku-sidebar-left"
        WlrLayershell.keyboardFocus: root.active ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        FocusScope {
            id: surface
            anchors.fill: parent
            opacity: root.reveal
            scale: 0.985 + root.reveal * 0.015
            transformOrigin: Item.TopLeft
            transform: Translate { y: (1 - root.reveal) * -Tokens.s2 * root.s }
            focus: root.active
            Keys.onEscapePressed: SidebarState.close(root.screen)
            onFocusChanged: if (focus) Qt.callLater(() => surface.forceActiveFocus())
            SidebarFrame { anchors.fill: parent; s: root.s }
            SidebarChrome {
                id: chrome
                anchors.fill: parent
                screen: root.screen
                s: root.s
                active: root.active
                onCloseRequested: SidebarState.close(root.screen)
            }
        }
    }
}
