import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../reusables"
import "../../../"

Rectangle {
    id: timeDateRoot

    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    readonly property bool isBottomBar: barWindow ? (barWindow.barPosition === "bottom") : false

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { timeDateRoot.configRevision++; }
        function onRawSettingsChanged() { timeDateRoot.configRevision++; }
    }

    property string timeStyle: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            if (Config.rawSettings.bar.timeStyle) return Config.rawSettings.bar.timeStyle;
        }
        return "classic";
    }

    property bool showDate: {
        let dummy = configRevision;
        if (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar) {
            if (Config.rawSettings.bar.timeShowDate !== undefined) return Config.rawSettings.bar.timeShowDate;
            if (Config.rawSettings.bar.showDate !== undefined) return Config.rawSettings.bar.showDate;
        }
        return true;
    }

    readonly property string timeStr: DateTime.time
    readonly property string timeOnlyStr: DateTime.timeOnly
    readonly property string hourStr: (typeof DateTime !== "undefined" && DateTime.hour) ? DateTime.hour : (DateTime.time ? DateTime.time.split(":")[0] : "")
    readonly property string minuteStr: (typeof DateTime !== "undefined" && DateTime.minute) ? DateTime.minute : (DateTime.time ? DateTime.time.split(":")[1] : "")
    readonly property string secondStr: (typeof DateTime !== "undefined" && DateTime.second) ? DateTime.second : ""
    readonly property string fullDateStr: DateTime.fullDate
    property int typeInIndex: 0
    property string dateStr: fullDateStr.substring(0, typeInIndex)

    onFullDateStrChanged: {
        if (typeInIndex >= fullDateStr.length) {
            typeInIndex = fullDateStr.length;
        }
    }

    Timer {
        id: typewriterTimer
        interval: 30
        running: timeDateRoot.moduleActive && barWindow && barWindow.isStartupReady && typeInIndex < fullDateStr.length
        repeat: true
        onTriggered: typeInIndex += 1
    }

    function s(val) {
        if (barWindow && typeof barWindow.s === "function") return barWindow.s(val);
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") return Math.round(Scaler.s(val));
        return val;
    }

    property int animDuration: 600
    property real targetX: 0
    x: targetX

    Behavior on x {
        enabled: barWindow && barWindow.startupCascadeFinished && !barWindow.positionChanging
        NumberAnimation { duration: timeDateRoot.animDuration; easing.type: Easing.OutQuint }
    }

    property real horizontalPadding: s(isCompact ? 12 : 14)
    property real baseHeight: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))

    property real targetHeight: baseHeight
    property real targetWidth: (moduleActive && faceLoader.item) ? (faceLoader.item.implicitWidth + (horizontalPadding * 2)) : 0

    width: targetWidth
    height: targetHeight

    MouseArea {
        id: bgMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (Caching.serpantinumDir) {
                Quickshell.execDetached(["bash", Caching.scriptsPath + "/qs_manager.sh", "toggle", "calendar"]);
            }
        }
    }

    property bool isHovered: bgMouse.containsMouse
    property bool showLayout: false

    property real targetY: barWindow ? barWindow.baseOffsetY + (barWindow.barHeight - targetHeight) / 2 : 0
    y: targetY

    Behavior on y {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: timeDateRoot.animDuration; easing.type: Easing.OutQuint }
    }

    color: "transparent"
    border.width: 0
    clip: true
    visible: (width > 0 || opacity > 0) && (!barWindow || !barWindow.positionChanging)
    opacity: (showLayout && moduleActive && (!barWindow || !barWindow.positionChanging)) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0

    Rectangle {
        id: bgRect
        z: -1
        width: parent.width
        height: parent.height
        radius: ThemeBackend.borderRadius
        color: timeDateRoot.isGrouped ? "transparent" : (timeDateRoot.isSolid ? (timeDateRoot.distinctPills ? (timeDateRoot.isHovered ? ThemeBackend.surface0 : Qt.darker(ThemeBackend.surface0, 1.15)) : "transparent") : (timeDateRoot.isHovered ? ThemeBackend.surface0 : ThemeBackend.base))
        border.width: 0
        visible: height > 0

        Behavior on color { enabled: barWindow ? !barWindow.positionChanging : true; ColorAnimation { duration: 250 } }
    }

    Behavior on width {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: timeDateRoot.animDuration; easing.type: Easing.OutQuint }
    }
    Behavior on height {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: timeDateRoot.animDuration; easing.type: Easing.OutQuint }
    }
    Behavior on opacity {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: 550; easing.type: Easing.OutCubic }
    }

    transform: Translate {
        y: timeDateRoot.showLayout ? 0 : (barWindow ? (timeDateRoot.isBottomBar ? barWindow.s(20) : barWindow.s(-20)) : (timeDateRoot.isBottomBar ? 20 : -20))
        Behavior on y {
            enabled: barWindow ? !barWindow.positionChanging : true
            NumberAnimation { duration: 800; easing.type: Easing.OutQuint }
        }
    }

    Timer {
        running: barWindow && barWindow.isStartupReady
        interval: 120
        onTriggered: timeDateRoot.showLayout = true
    }

    Loader {
        id: faceLoader
        z: 2
        anchors.centerIn: parent
        source: {
            switch (timeDateRoot.timeStyle) {
                case "material": return Qt.resolvedUrl("faces/MaterialFace.qml");
                case "badge": return Qt.resolvedUrl("faces/BadgeFace.qml");
                case "classic":
                default: return Qt.resolvedUrl("faces/ClassicFace.qml");
            }
        }
    }

    Binding {
        target: faceLoader.item
        property: "widget"
        value: timeDateRoot
    }
}
