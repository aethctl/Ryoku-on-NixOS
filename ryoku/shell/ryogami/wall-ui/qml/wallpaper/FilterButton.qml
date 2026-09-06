import QtQuick
import QtQuick.Controls
import ".."

// Ryoku tab / filter pill, orthogonal (never skewed):
//  · text, active   -> a bone plate with dark ink, and a //LEAD when register.
//  · text, inactive -> transparent hairline, tracked ink label.
//  · icon, active    -> a subtle ink-tint cell with the sun accent glyph (never
//                       a bone blob, which is reserved for text selection).
//  · icon, inactive  -> transparent, dim ink glyph.
Item {
    id: btn

    property var colors
    property bool isActive: false
    property string icon: ""
    property string label: ""
    property bool useNerdFont: icon !== ""
    property string tooltip: ""
    property int skew: 10                 // kept for API; Ryoku draws orthogonal
    property color activeColor: "transparent"
    property bool hasActiveColor: false
    property real activeOpacity: 1.0
    property bool register: true          // //LEAD on active text (tabs); off for compact filters

    signal clicked()

    readonly property bool _icon: btn.useNerdFont
    readonly property bool isHovered: _mouse.containsMouse
    readonly property color _ink:    colors ? colors.surfaceText : "#e0e2e8"
    readonly property color _inkDim: colors ? colors.surfaceVariantText : "#c2c7cf"
    readonly property color _line:   colors ? colors.outline : Qt.rgba(1, 1, 1, 0.22)
    readonly property color _bone:   colors ? colors.inverseSurface : "#e0e2e8"
    readonly property color _onBone: colors ? colors.inverseSurfaceText : "#101418"
    readonly property color _accent: colors ? colors.primary : Style.fallbackAccent
    readonly property color _activeFill: btn.hasActiveColor ? btn.activeColor : _bone
    readonly property color _activeText: btn.hasActiveColor ? "#ffffff" : _onBone

    width: _row.implicitWidth + (btn._icon ? 14 : 22) * Config.uiScale
    height: 24 * Config.uiScale
    z: isActive ? 10 : (isHovered ? 5 : 1)

    Rectangle {
        anchors.fill: parent
        radius: Style.radiusMedium
        color: btn.isActive
            ? (btn._icon ? Qt.rgba(btn._ink.r, btn._ink.g, btn._ink.b, 0.12) : btn._activeFill)
            : (btn.isHovered ? Qt.rgba(btn._ink.r, btn._ink.g, btn._ink.b, 0.06) : "transparent")
        border.width: 1
        border.color: btn.isActive ? (btn._icon ? btn._line : btn._activeFill) : btn._line
        Behavior on color { ColorAnimation { duration: Style.animVeryFast } }
        Behavior on border.color { ColorAnimation { duration: Style.animVeryFast } }
    }

    Row {
        id: _row
        anchors.centerIn: parent
        spacing: 5
        Text {
            visible: btn.register && btn.isActive && !btn._icon && btn.label !== ""
            text: "//"
            font.family: Style.fontFamilyMono; font.pixelSize: 9 * Config.uiScale
            color: Qt.rgba(btn._activeText.r, btn._activeText.g, btn._activeText.b, 0.55)
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            id: _label
            text: btn.icon || btn.label
            font.pixelSize: (btn._icon ? 14 : 10) * Config.uiScale
            font.family: btn._icon ? Style.fontFamilyNerdIcons : Style.fontFamily
            font.weight: btn._icon ? Font.Normal : Font.Medium
            font.letterSpacing: btn._icon ? 0 : 1.2
            color: btn._icon
                ? (btn.isActive ? btn._accent : (btn.isHovered ? btn._ink : btn._inkDim))
                : (btn.isActive ? btn._activeText : btn._inkDim)
            anchors.verticalCenter: parent.verticalCenter
            Behavior on color { ColorAnimation { duration: Style.animVeryFast } }
        }
    }

    opacity: btn.activeOpacity

    MouseArea {
        id: _mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: btn.clicked()
    }

    StyledToolTip {
        visible: btn.tooltip !== "" && _mouse.containsMouse
        text: btn.tooltip
        delay: Style.tooltipDelay
        colors: btn.colors
    }
}
