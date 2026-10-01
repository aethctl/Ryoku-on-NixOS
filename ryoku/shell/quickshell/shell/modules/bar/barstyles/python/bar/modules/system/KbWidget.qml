import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../reusables"
import "../../../"
import Ryoku.Ui.Singletons

Rectangle {
    id: kbWidgetRoot
    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    property string kbLayout: "us"
    property real targetX: 0
    property bool showLayout: false
    property alias kbPill: kbPill
    readonly property bool hasLayout: Wm.keyboardLayout !== ""

    Component.onCompleted: {
        if (Wm.keyboardLayout !== "") kbLayout = shortLabel(Wm.keyboardLayout);
    }

    Connections {
        target: Wm
        function onKeyboardLayoutChanged() {
            if (Wm.keyboardLayout !== "") {
                kbLayout = shortLabel(Wm.keyboardLayout);
                if (barWindow) barWindow.fastPollerLoaded = true;
            }
        }
    }

    function shortLabel(name) {
        // "English (US)" / "us" / "eng" all read as the two-letter code.
        let paren = name.match(/\(([^)]+)\)\s*$/);
        let base = paren ? paren[1] : name;
        return base.slice(0, 2).toUpperCase();
    }


    x: targetX
    Behavior on x {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }
    height: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))
    y: barWindow ? barWindow.baseOffsetY + (barWindow.barHeight - height) / 2 : 0
    radius: ThemeBackend.borderRadius
    border.width: 0
    color: isGrouped ? "transparent" : (isSolid ? (distinctPills ? Qt.darker(ThemeBackend.surface0, 1.15) : "transparent") : ThemeBackend.base)
    clip: true

    property real targetWidth: (moduleActive && sysLayout.implicitWidth > 0) ? (sysLayout.implicitWidth + (barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10))) : 0
    width: targetWidth

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Timer {
        running: kbWidgetRoot.moduleActive && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: kbWidgetRoot.showLayout = true
    }

    transform: Translate {
        x: kbWidgetRoot.showLayout ? 0 : barWindow.s(60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    Row {
        id: sysLayout
        anchors.centerIn: parent
        property int pillHeight: barWindow ? barWindow.s(kbWidgetRoot.isCompact ? 28 : 30) : (kbWidgetRoot.isCompact ? 28 : 30)

        ClickButton {
            id: kbPill
            property bool initAnimTrigger: false
            height: sysLayout.pillHeight
            maxWidth: barWindow ? barWindow.s(kbWidgetRoot.isCompact ? 96 : 100) : (kbWidgetRoot.isCompact ? 96 : 100)
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
            horizontalPadding: barWindow ? barWindow.s(kbWidgetRoot.isCompact ? 10 : 12) : (kbWidgetRoot.isCompact ? 10 : 12)
            buttonIcon: "󰌌"
            iconFontSize: barWindow ? barWindow.s(kbWidgetRoot.isCompact ? 14 : 15) : (kbWidgetRoot.isCompact ? 14 : 15)
            buttonText: kbLayout
            textFontSize: barWindow ? barWindow.s(kbWidgetRoot.isCompact ? 11 : 12) : (kbWidgetRoot.isCompact ? 11 : 12)
            accentColor: kbWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (kbWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)

            property real targetWidth: Math.max(barWindow ? barWindow.s(kbWidgetRoot.isCompact ? 48 : 52) : (kbWidgetRoot.isCompact ? 48 : 52), implicitWidth)
            width: targetWidth

            Behavior on width {
                enabled: barWindow.startupCascadeFinished
                NumberAnimation { duration: 480; easing.type: Easing.OutQuint }
            }

            Timer { running: kbWidgetRoot.moduleActive && kbWidgetRoot.showLayout && !kbPill.initAnimTrigger; interval: 70; onTriggered: kbPill.initAnimTrigger = true }
            opacity: initAnimTrigger ? 1.0 : 0.0
            transform: Translate { y: kbPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            onClicked: Wm.cycleKeyboardLayout()
        }
    }
}
