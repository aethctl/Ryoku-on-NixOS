import QtQuick

// moved fires while dragging; released fires once on let-go.
Item {
    id: slider

    property real from: 0
    property real to: 1
    property real value: 0
    // Snap increment; 0 leaves the value continuous.
    property real step: 0

    readonly property bool dragging: drag.pressed
    property bool focused: false

    signal moved(real value)
    signal released(real value)

    implicitHeight: 26 * Theme.scale
    implicitWidth: 160 * Theme.scale

    readonly property real _thumb: 8 * Theme.scale
    readonly property real _inset: slider._thumb * 0.71
    readonly property real _trackW: Math.max(1, width - slider._inset * 2)
    readonly property real _span: (slider.to - slider.from) || 1
    readonly property real _t: Math.max(0, Math.min(1, (slider.value - slider.from) / slider._span))
    // Snapped to a half pixel so the diamond stays crisp.
    readonly property real _thumbX: Math.round(slider._inset + slider._t * slider._trackW) + 0.5

    function _snap(v) {
        var c = Math.max(slider.from, Math.min(slider.to, v))
        if (slider.step > 0)
            c = slider.from + Math.round((c - slider.from) / slider.step) * slider.step
        return c
    }
    function _fromX(x) {
        var t = (x - slider._inset) / slider._trackW
        return slider._snap(slider.from + t * slider._span)
    }

    Rectangle {
        height: 1
        width: slider._trackW
        x: slider._inset
        y: (slider.height - height) / 2
        color: Theme.withAlpha(Theme.outline, slider.enabled ? 0.5 : 0.28)
    }

    Rectangle {
        height: 2
        width: Math.max(0, slider._thumbX - slider._inset)
        x: slider._inset
        y: (slider.height - height) / 2
        color: Theme.withAlpha(Theme.primary, slider.enabled ? 1 : 0.4)
    }

    Rectangle {
        width: slider._thumb
        height: slider._thumb
        x: slider._thumbX - width / 2
        y: (slider.height - height) / 2
        rotation: 45
        antialiasing: true
        color: Theme.surface
        border.width: 1
        border.color: Theme.withAlpha(Theme.primary, slider.enabled ? 1 : 0.4)
        scale: slider.dragging || slider.focused ? 1.15 : 1
        Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Theme.revealEasing } }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        enabled: slider.enabled
        preventStealing: true
        cursorShape: Qt.PointingHandCursor
        onPressed: (m) => { var v = slider._fromX(m.x); if (v !== slider.value) { slider.value = v; slider.moved(v) } }
        onPositionChanged: (m) => { if (pressed) { var v = slider._fromX(m.x); if (v !== slider.value) { slider.value = v; slider.moved(v) } } }
        onReleased: slider.released(slider.value)
    }
}
