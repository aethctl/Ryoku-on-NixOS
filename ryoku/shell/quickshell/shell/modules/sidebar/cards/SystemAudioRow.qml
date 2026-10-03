pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import shell.services
import Ryoku.Ui
import Ryoku.Ui.Singletons
import ".."

Column {
    id: root

    required property real s
    required property var node
    property bool device: false
    property bool capture: false
    readonly property var audio: root.node ? root.node.audio : null
    readonly property bool muted: !!(root.audio && root.audio.muted)
    readonly property string title: root.device ? Audio.nodeLabel(root.node) : Audio.streamName(root.node)
    readonly property var defaultNode: root.capture ? Audio.source : Audio.sink
    readonly property bool isDefault: !!(root.device && root.node && root.defaultNode && root.node.name === root.defaultNode.name)
    readonly property bool motionAllowed: !Motion.reduce && !Tokens.reduceMotion
    readonly property string detail: {
        if (root.device)
            return root.capture ? I18n.tr("Microphone gain") : I18n.tr("Output volume");
        const properties = root.node ? root.node.properties || {} : {};
        const media = properties["media.name"] || "";
        return media !== root.title ? media : "";
    }

    spacing: Tokens.s2 * root.s
    enabled: root.audio !== null

    function setPercent(value): void {
        if (root.audio)
            root.audio.volume = Math.max(0, Math.min(100, Math.round(value))) / 100;
    }

    component SpinIndicator: Rectangle {
        required property bool increase
        required property bool hovered
        required property bool pressed
        width: 28 * root.s
        height: percent.height
        radius: Tokens.radius * root.s
        color: pressed ? Tokens.tint16 : hovered ? Tokens.tint10 : "transparent"
        Behavior on color { enabled: root.motionAllowed; ColorAnimation { duration: Tokens.snap } }
        Text {
            anchors.centerIn: parent
            text: parent.increase ? "+" : "−"
            color: Tokens.ink
            font.family: Tokens.ui
            font.pixelSize: Tokens.fRow * root.s
            Accessible.ignored: true
        }
    }

    Row {
        width: root.width
        spacing: Tokens.s2 * root.s

        SidebarButton {
            id: muteButton
            s: root.s
            width: 44 * root.s
            glyph: root.capture ? (root.muted ? "mic_off" : "mic") : (root.muted ? "volume_off" : "volume_up")
            primary: root.muted
            Accessible.name: root.muted ? I18n.tr("Unmute %1").arg(root.title) : I18n.tr("Mute %1").arg(root.title)
            onAct: if (root.audio) root.audio.muted = !root.audio.muted
            scale: down ? 0.94 : 1
            Behavior on scale { enabled: root.motionAllowed; NumberAnimation { duration: Tokens.snap; easing.type: Tokens.easeSnap } }
        }
        Column {
            width: Math.max(0, parent.width - muteButton.width - parent.spacing - (defaultButton.visible ? defaultButton.width + parent.spacing : 0))
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s1 * root.s
            Text {
                width: parent.width
                text: root.title
                color: Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: Tokens.fRow * root.s
                font.weight: Font.Medium
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
            Text {
                visible: root.detail !== "" || root.muted
                width: parent.width
                text: root.muted ? I18n.tr("Muted") : root.detail
                color: Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall * root.s
                elide: Text.ElideRight
            }
        }
        SidebarButton {
            id: defaultButton
            visible: root.device
            s: root.s
            compact: true
            anchors.verticalCenter: parent.verticalCenter
            text: root.isDefault ? I18n.tr("Default") : I18n.tr("Use")
            primary: root.isDefault
            Accessible.name: root.isDefault ? I18n.tr("%1 is the default device").arg(root.title)
                : I18n.tr("Use %1 as the default device").arg(root.title)
            onAct: if (!root.isDefault) {
                if (root.capture) Audio.setInput(root.node);
                else Audio.setOutput(root.node);
            }
        }
    }

    Row {
        width: root.width
        spacing: Tokens.s2 * root.s

        Slid {
            width: Math.max(0, parent.width - percent.width - suffix.implicitWidth - parent.spacing * 2)
            height: 44 * root.s
            from: 0
            to: 100
            value: root.audio ? root.audio.volume * 100 : 0
            opacity: root.muted ? 0.45 : 1
            Accessible.name: I18n.tr("%1 volume").arg(root.title)
            onModified: value => root.setPercent(value)
            Behavior on opacity { enabled: root.motionAllowed; NumberAnimation { duration: Tokens.snap } }
        }
        QQC.SpinBox {
            id: percent
            width: 108 * root.s
            height: 44 * root.s
            from: 0
            to: 100
            stepSize: 1
            editable: true
            value: root.audio ? Math.round(root.audio.volume * 100) : 0
            font.family: Tokens.ui
            font.pixelSize: Tokens.fRow * root.s
            leftPadding: 28 * root.s
            rightPadding: 28 * root.s
            Accessible.name: I18n.tr("%1 volume percent").arg(root.title)
            onValueModified: root.setPercent(value)
            contentItem: TextInput {
                text: percent.textFromValue(percent.value, percent.locale)
                font: percent.font
                color: Tokens.ink
                selectionColor: Tokens.bone
                selectedTextColor: Tokens.inkOnBone
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                readOnly: !percent.editable
                validator: percent.validator
                inputMethodHints: Qt.ImhDigitsOnly
            }
            background: Rectangle {
                radius: Tokens.radius * root.s * 1.5
                color: Tokens.tint5
                border.width: Tokens.border
                border.color: percent.activeFocus ? Tokens.bone : Tokens.lineSoft
            }
            up.indicator: SpinIndicator {
                x: percent.width - width
                increase: true
                hovered: percent.up.hovered
                pressed: percent.up.pressed
            }
            down.indicator: SpinIndicator {
                increase: false
                hovered: percent.down.hovered
                pressed: percent.down.pressed
            }
        }
        Text {
            id: suffix
            anchors.verticalCenter: parent.verticalCenter
            text: "%"
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: Tokens.fSmall * root.s
        }
    }
}
