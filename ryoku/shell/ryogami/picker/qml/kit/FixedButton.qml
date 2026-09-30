import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: btn

    property string label: ""
    property string glyph: ""
    // "toggle" holds the fill while active; "action" flashes on press.
    property string mode: "toggle"
    property bool active: false
    property bool destructive: false
    property bool focused: false
    // Arm-then-confirm: first press arms, second within the window triggers.
    property bool confirm: false
    readonly property bool armed: btn.armState

    property real idleFillAlpha: 0.92
    property real hoverFillAlpha: 0.62
    property real activeFillAlpha: 0.92

    // A positive fixedWidth wins; otherwise the box hugs its content within [minWidth, maxWidth].
    property real fixedWidth: 0
    property real minWidth: 0
    property real maxWidth: 100000
    property real hpad: 14

    signal clicked()
    signal triggered()

    implicitHeight: 30 * Theme.scale
    implicitWidth: btn.fixedWidth > 0
        ? btn.fixedWidth
        : Math.max(btn.minWidth * Theme.scale,
                   Math.min(btn.maxWidth * Theme.scale, content.implicitWidth + btn.hpad * 2 * Theme.scale))

    readonly property color accent: btn.destructive ? Theme.tertiary : Theme.primary
    readonly property bool hovered: hoverArea.containsMouse
    readonly property bool hot: btn.active || btn.holdFill

    // The wipe follows its target through a Behavior, so it animates without per-frame JS.
    property bool holdFill: false
    property bool armState: false
    readonly property real wipeTarget: (btn.active || btn.holdFill) ? 1 : 0
    property real wipeProgress: btn.wipeTarget
    Behavior on wipeProgress {
        NumberAnimation { duration: Theme.fast; easing.type: Theme.revealEasing }
    }

    Timer { id: flashTimer; interval: Theme.fast; onTriggered: btn.holdFill = false }
    Timer { id: disarmTimer; interval: 3000; onTriggered: btn.armState = false }
    function flash() { btn.holdFill = true; flashTimer.restart() }

    function _activate() {
        if (!btn.enabled)
            return
        if (btn.confirm) {
            if (btn.armState) {
                btn.armState = false
                disarmTimer.stop()
                btn.triggered()
                btn.clicked()
            } else {
                btn.armState = true
                disarmTimer.restart()
            }
            return
        }
        if (btn.mode === "action" && !btn.active)
            btn.flash()
        btn.triggered()
        btn.clicked()
    }

    Rectangle {
        id: box
        anchors.fill: parent
        radius: Theme.radius
        clip: true

        color: !btn.enabled
            ? Theme.withAlpha(Theme.surfaceContainer, 0.42)
            : btn.hovered
                ? Theme.withAlpha(Theme.surfaceVariant, btn.hoverFillAlpha)
                : Theme.withAlpha(Theme.surfaceContainer, btn.idleFillAlpha)

        border.width: btn.focused ? 2 : 1
        border.color: !btn.enabled
            ? Theme.withAlpha(Theme.outline, 0.18)
            : btn.focused
                ? Theme.withAlpha(Theme.primary, 0.90)
                : (btn.hot || btn.hovered || btn.destructive)
                    ? Theme.withAlpha(btn.accent, 0.90)
                    : Theme.withAlpha(Theme.outline, 0.40)

        readonly property real slant: box.height * 0.72

        Rectangle {
            id: wipe
            height: box.height
            width: box.width + box.slant
            y: 0
            x: -(width + box.slant) + btn.wipeProgress * width
            color: Theme.withAlpha(btn.accent, btn.activeFillAlpha)
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, box.slant / wipe.height, 0, 0,
                                     0, 1, 0, 0,
                                     0, 0, 1, 0,
                                     0, 0, 0, 1)
            }
        }

        Rectangle {
            id: edge
            width: 2
            height: box.height
            y: 0
            x: wipe.x + wipe.width - width
            color: Theme.withAlpha(Theme.tertiary, 0.9)
            visible: btn.wipeProgress > 0.001 && btn.wipeProgress < 0.999
            transform: Matrix4x4 {
                matrix: Qt.matrix4x4(1, box.slant / edge.height, 0, 0,
                                     0, 1, 0, 0,
                                     0, 0, 1, 0,
                                     0, 0, 0, 1)
            }
        }
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 6 * Theme.scale

        // Follows the fill under the label, not the target state, so it never reads dark on dark mid-wipe.
        readonly property color textColor: !btn.enabled
            ? Theme.withAlpha(Theme.surfaceText, 0.3)
            : btn.wipeProgress > 0.5
                ? (btn.destructive ? Theme.background : Theme.primaryText)
                : Theme.surfaceText

        Text {
            visible: btn.glyph.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: btn.glyph
            font.family: Theme.icon
            font.pixelSize: Theme.fontLabel
            color: content.textColor
            renderType: Text.NativeRendering
        }
        Text {
            visible: btn.label.length > 0 || btn.armState
            anchors.verticalCenter: parent.verticalCenter
            text: btn.armState ? (I18n.tr("Confirm") + " " + btn.label) : btn.label
            font.family: Theme.ui
            font.weight: Theme.uiWeight
            font.pixelSize: Theme.fontLabel
            color: content.textColor
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: btn.enabled
        cursorShape: Qt.PointingHandCursor
        onClicked: btn._activate()
    }
}
