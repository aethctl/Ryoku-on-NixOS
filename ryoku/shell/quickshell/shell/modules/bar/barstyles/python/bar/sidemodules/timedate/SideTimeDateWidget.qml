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
    id: sideTimeDateRoot

    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    readonly property bool isRightBar: barWindow ? (barWindow.barPosition === "right") : false

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() { sideTimeDateRoot.configRevision++; }
        function onRawSettingsChanged() { sideTimeDateRoot.configRevision++; }
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

    readonly property string timeStr: (typeof DateTime !== "undefined" && DateTime.time) ? DateTime.time : "14:28"
    readonly property string timeOnlyStr: (typeof DateTime !== "undefined" && DateTime.timeOnly) ? DateTime.timeOnly : "14:28"
    readonly property string hourStr: (typeof DateTime !== "undefined" && DateTime.hour) ? DateTime.hour : (DateTime.time ? DateTime.time.split(":")[0] : "14")
    readonly property string minuteStr: (typeof DateTime !== "undefined" && DateTime.minute) ? DateTime.minute : (DateTime.time ? DateTime.time.split(":")[1] : "28")
    readonly property string secondStr: (typeof DateTime !== "undefined" && DateTime.second) ? DateTime.second : ""
    readonly property string timeAmPmStr: (typeof DateTime !== "undefined" && DateTime.amPm) ? DateTime.amPm : ""
    readonly property string dayStr: (typeof DateTime !== "undefined" && DateTime.day) ? DateTime.day : "18"
    readonly property string monthStr: (typeof DateTime !== "undefined" && DateTime.monthShort) ? DateTime.monthShort : "Sep"
    readonly property string fullDateStr: (typeof DateTime !== "undefined" && DateTime.fullDate) ? DateTime.fullDate : "Fri, Sep 18"
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
        running: sideTimeDateRoot.moduleActive && barWindow && barWindow.isStartupReady && typeInIndex < fullDateStr.length
        repeat: true
        onTriggered: typeInIndex += 1
    }

    function s(val) {
        if (barWindow && typeof barWindow.s === "function") return barWindow.s(val);
        if (typeof Scaler !== "undefined" && typeof Scaler.s === "function") return Math.round(Scaler.s(val));
        return val;
    }

    property int animDuration: 600
    property real targetY: 0
    y: targetY

    Behavior on y {
        enabled: barWindow && barWindow.startupCascadeFinished && !barWindow.positionChanging
        NumberAnimation { duration: sideTimeDateRoot.animDuration; easing.type: Easing.OutQuint }
    }

    property real verticalPadding: s(isCompact ? 10 : 12)
    property real baseWidth: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))

    property real targetWidth: moduleActive ? baseWidth : 0
    property real targetHeight: (moduleActive && faceLoader.item) ? (faceLoader.item.implicitHeight + (verticalPadding * 2)) : 0

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

    property real targetX: isRightBar ? (parent ? (parent.width - targetWidth) : 0) : 0
    x: targetX

    Behavior on x {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: sideTimeDateRoot.animDuration; easing.type: Easing.OutQuint }
    }

    width: targetWidth
    height: targetHeight

    color: "transparent"
    border.width: 0
    clip: true
    visible: (height > 0 || opacity > 0) && (!barWindow || !barWindow.positionChanging)
    opacity: (showLayout && moduleActive && (!barWindow || !barWindow.positionChanging)) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0

    Rectangle {
        id: bgRect
        z: -1
        width: parent.width
        height: parent.height
        radius: ThemeBackend.borderRadius
        color: sideTimeDateRoot.isGrouped ? "transparent" : (sideTimeDateRoot.isSolid ? (sideTimeDateRoot.distinctPills ? (sideTimeDateRoot.isHovered ? ThemeBackend.surface0 : Qt.darker(ThemeBackend.surface0, 1.15)) : "transparent") : (sideTimeDateRoot.isHovered ? ThemeBackend.surface0 : ThemeBackend.base))
        border.width: 0
        visible: height > 0

        Behavior on color { enabled: barWindow ? !barWindow.positionChanging : true; ColorAnimation { duration: 250 } }
    }

    Behavior on width {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: sideTimeDateRoot.animDuration; easing.type: Easing.OutQuint }
    }
    Behavior on height {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: sideTimeDateRoot.animDuration; easing.type: Easing.OutQuint }
    }
    Behavior on opacity {
        enabled: barWindow ? !barWindow.positionChanging : true
        NumberAnimation { duration: 550; easing.type: Easing.OutCubic }
    }

    transform: Translate {
        x: sideTimeDateRoot.showLayout ? 0 : (barWindow ? (sideTimeDateRoot.isRightBar ? barWindow.s(20) : barWindow.s(-20)) : (sideTimeDateRoot.isRightBar ? 20 : -20))
        Behavior on x {
            enabled: barWindow ? !barWindow.positionChanging : true
            NumberAnimation { duration: 800; easing.type: Easing.OutQuint }
        }
    }

    Timer {
        running: barWindow && barWindow.isStartupReady
        interval: 120
        onTriggered: sideTimeDateRoot.showLayout = true
    }

    Loader {
        id: faceLoader
        z: 2
        anchors.centerIn: parent
        source: {
            switch (sideTimeDateRoot.timeStyle) {
                case "material": return Qt.resolvedUrl("faces/SideMaterialFace.qml");
                case "badge": return Qt.resolvedUrl("faces/SideBadgeFace.qml");
                case "classic":
                default: return Qt.resolvedUrl("faces/SideClassicFace.qml");
            }
        }
    }

    Binding {
        target: faceLoader.item
        property: "widget"
        value: sideTimeDateRoot
    }
}
