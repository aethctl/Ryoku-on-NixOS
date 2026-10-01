import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Ryoku.Ui.Singletons
import "../../../reusables"
import "../../../"

Rectangle {
    id: sideKbRoot

    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    property string kbLayout: "US"
    property real targetY: 0
    property bool showLayout: false
    property alias kbPill: kbBtn
    readonly property bool hasLayout: Wm.keyboardLayout !== ""

    function shortLabel(name) {
        let paren = name.indexOf("(");
        let base = paren > 0 ? name.slice(0, paren) : name;
        return base.slice(0, 2).toUpperCase();
    }

    Component.onCompleted: {
        if (Wm.keyboardLayout !== "") kbLayout = shortLabel(Wm.keyboardLayout);
    }
    Connections {
        target: Wm
        function onKeyboardLayoutChanged() {
            if (Wm.keyboardLayout !== "") kbLayout = shortLabel(Wm.keyboardLayout);
        }
    }


    property real targetWidth: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))
    property real targetHeight: targetWidth

    width: targetWidth
    height: targetHeight

    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    x: barWindow ? ((barWindow.baseOffsetX !== undefined ? barWindow.baseOffsetX : 0) + (barWindow.barHeight - width) / 2) : 0
    y: targetY
    Behavior on y {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    radius: ThemeBackend.borderRadius
    border.width: 0
    color: isGrouped ? "transparent" : (isSolid ? (distinctPills ? Qt.darker(ThemeBackend.surface0, 1.15) : "transparent") : ThemeBackend.base)
    clip: true

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Timer {
        running: sideKbRoot.moduleActive && barWindow && barWindow.isStartupReady && barWindow.isDataReady
        interval: 100
        onTriggered: sideKbRoot.showLayout = true
    }

    ClickButton {
        id: kbBtn
        anchors.centerIn: parent
        width: barWindow ? barWindow.s(sideKbRoot.isCompact ? 28 : 30) : (sideKbRoot.isCompact ? 28 : 30)
        height: barWindow ? barWindow.s(sideKbRoot.isCompact ? 28 : 30) : (sideKbRoot.isCompact ? 28 : 30)
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
        horizontalPadding: 0
        buttonText: kbLayout
        textFontSize: barWindow ? barWindow.s(sideKbRoot.isCompact ? 11 : 12) : (sideKbRoot.isCompact ? 11 : 12)
        accentColor: sideKbRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0
        textColor: isHoveredOrHighlighted ? ThemeBackend.text : (sideKbRoot.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)

        onClicked: Wm.cycleKeyboardLayout()
    }
}
