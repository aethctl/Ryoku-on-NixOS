import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../reusables"
import "../../"

Rectangle {
    id: sideFocusRoot

    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    property real targetY: 0

    readonly property string displayText: CurrentFocus.displayText
    readonly property bool isFocused: CurrentFocus.isFocused

    property real topPadding: (isSolid && !distinctPills) ? 0 : (barWindow ? barWindow.s(6) : 6)
    property real bottomPadding: (isSolid && !distinctPills) ? 0 : (barWindow ? barWindow.s(12) : 12)
    property real maxHeight: barWindow ? barWindow.s(300) : 300
    property real maxTextHeight: Math.max(0, maxHeight - (topPadding + focusIconButton.height + innerLayout.spacing + bottomPadding))
    property real targetHeight: (moduleActive && isFocused) ? Math.min(maxHeight, topPadding + focusIconButton.height + innerLayout.spacing + titleClipRect.height + bottomPadding) : 0

    x: barWindow ? (barWindow.baseOffsetX !== undefined ? barWindow.baseOffsetX + Math.round((barWindow.barHeight - width) / 2) : 0) : 0
    y: targetY
    Behavior on y {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
    }

    width: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))
    height: targetHeight
    Behavior on height { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

    radius: ThemeBackend.borderRadius
    color: isGrouped ? "transparent" : (isSolid ? (distinctPills ? Qt.darker(ThemeBackend.surface0, 1.15) : "transparent") : ThemeBackend.base)
    border.width: 0
    clip: true

    opacity: (moduleActive && isFocused) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Column {
        id: innerLayout
        anchors.top: parent.top
        anchors.topMargin: sideFocusRoot.topPadding
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: (isSolid && !distinctPills) ? 0 : (barWindow ? barWindow.s(sideFocusRoot.isCompact ? 5 : 6) : (sideFocusRoot.isCompact ? 5 : 6))

        property bool initAnimTrigger: !barWindow || barWindow.startupCascadeFinished

        opacity: initAnimTrigger ? 1.0 : 0.0
        transform: Translate {
            x: innerLayout.initAnimTrigger ? 0 : (barWindow ? barWindow.s(15) : 15)
            Behavior on x { NumberAnimation { duration: 400; easing.type: Easing.OutCubic } }
        }
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }

        IconButton {
            id: focusIconButton
            width: barWindow ? barWindow.s(sideFocusRoot.isCompact ? 28 : 30) : (sideFocusRoot.isCompact ? 28 : 30)
            height: barWindow ? barWindow.s(sideFocusRoot.isCompact ? 28 : 30) : (sideFocusRoot.isCompact ? 28 : 30)
            cornerRadius: barWindow ? barWindow.s(sideFocusRoot.isCompact ? 9 : 10) : (sideFocusRoot.isCompact ? 9 : 10)
            buttonIcon: "✦"
            iconFontSize: barWindow ? barWindow.s(sideFocusRoot.isCompact ? 14 : 15) : (sideFocusRoot.isCompact ? 14 : 15)
            accentColor: sideFocusRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ((isSolid && !distinctPills) ? "transparent" : ThemeBackend.surface0)
            textColor: isHoveredOrHighlighted ? ThemeBackend.text : (sideFocusRoot.isCompact ? ThemeBackend.subtext0 : ThemeBackend.overlay2)
            anchors.horizontalCenter: parent.horizontalCenter
            onClicked: {
                if (Caching.serpantinumDir) {
                    Quickshell.execDetached(["bash", "-c", Caching.scriptsPath + "/qs_manager.sh toggle applauncher"])
                }
            }
        }

        Item {
            id: titleClipRect
            width: focusIconButton.width
            height: Math.min(titleTextMain.implicitWidth, sideFocusRoot.maxTextHeight)
            clip: true
            anchors.horizontalCenter: parent.horizontalCenter

            Item {
                id: rotator
                anchors.centerIn: parent
                width: titleClipRect.height
                height: titleClipRect.width
                rotation: 90

                Text {
                    id: titleTextMain
                    anchors.verticalCenter: parent.verticalCenter
                    width: rotator.width
                    text: sideFocusRoot.displayText
                    color: ThemeBackend.text
                    font.pixelSize: barWindow ? barWindow.s(sideFocusRoot.isCompact ? 11 : 12) : (sideFocusRoot.isCompact ? 11 : 12)
                    elide: Text.ElideRight
                }
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        z: -1
        onClicked: {
            if (Caching.serpantinumDir) {
                Quickshell.execDetached(["bash", "-c", Caching.scriptsPath + "/qs_manager.sh toggle applauncher"])
            }
        }
    }
}
