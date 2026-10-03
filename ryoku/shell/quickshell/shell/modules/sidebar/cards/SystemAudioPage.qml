pragma ComponentBehavior: Bound

import QtQuick
import shell.services
import Ryoku.Ui.Singletons
import ".."
import "." as Cards

Column {
    id: root

    required property real s
    required property bool active
    readonly property bool motionAllowed: !Motion.reduce && !Tokens.reduceMotion
    signal backRequested()

    spacing: Tokens.s4 * root.s
    opacity: root.active ? 1 : 0
    transform: Translate {
        x: root.active ? 0 : Tokens.s3 * root.s
        Behavior on x { enabled: root.motionAllowed; NumberAnimation { duration: Tokens.swap; easing.type: Tokens.ease } }
    }
    Behavior on opacity { enabled: root.motionAllowed; NumberAnimation { duration: Tokens.swap; easing.type: Tokens.ease } }

    component SourceGroup: Rectangle {
        id: group
        required property string title
        required property string subtitle
        required property string emptyText
        required property var nodes
        property bool device: false
        property bool capture: false

        implicitHeight: body.implicitHeight + Tokens.s4 * root.s * 2
        height: implicitHeight
        radius: Tokens.radius * root.s * 2
        color: Tokens.paperLift
        border.width: Tokens.border
        border.color: Tokens.lineSoft

        Column {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.s4 * root.s
            spacing: Tokens.s3 * root.s

            Text {
                width: parent.width
                text: group.title
                color: Tokens.ink
                font.family: Tokens.display
                font.pixelSize: Tokens.fValue * root.s
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }
            Text {
                width: parent.width
                text: group.subtitle
                color: Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall * root.s
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
            Repeater {
                model: root.active ? group.nodes : []
                delegate: Column {
                    required property var modelData
                    required property int index
                    width: body.width
                    spacing: Tokens.s3 * root.s
                    Rectangle {
                        visible: index > 0
                        width: parent.width
                        height: Tokens.border
                        color: Tokens.lineSoft
                    }
                    Cards.SystemAudioRow {
                        width: parent.width
                        s: root.s
                        node: modelData
                        device: group.device
                        capture: group.capture
                    }
                }
            }
            Text {
                visible: group.nodes.length === 0
                width: parent.width
                text: group.emptyText
                color: Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: Tokens.fRow * root.s
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                topPadding: Tokens.s3 * root.s
                bottomPadding: Tokens.s3 * root.s
            }
        }
    }

    Row {
        width: root.width
        spacing: Tokens.s4 * root.s
        SidebarButton {
            id: backButton
            s: root.s
            glyph: "arrow_back"
            text: I18n.tr("Overview")
            onAct: root.backRequested()
        }
        Text {
            width: Math.max(0, parent.width - backButton.width - parent.spacing)
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tr("Audio mixer")
            color: Tokens.ink
            font.family: Tokens.display
            font.pixelSize: Tokens.fTitle * root.s
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
        }
    }

    Text {
        width: root.width
        text: I18n.tr("Adjust each source separately. Type a percentage or use + and − for 1% changes.")
        color: Tokens.inkMuted
        font.family: Tokens.ui
        font.pixelSize: Tokens.fSmall * root.s
        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    }

    Grid {
        id: groups
        width: root.width
        columns: width >= 560 * root.s ? 2 : 1
        spacing: Tokens.s4 * root.s

        SourceGroup {
            width: (groups.width - groups.spacing * (groups.columns - 1)) / groups.columns
            title: I18n.tr("Output devices")
            subtitle: I18n.tr("Speakers and headphones")
            emptyText: I18n.tr("Connect speakers or headphones to control their volume.")
            nodes: Audio.outputs
            device: true
        }
        SourceGroup {
            width: (groups.width - groups.spacing * (groups.columns - 1)) / groups.columns
            title: I18n.tr("Microphones")
            subtitle: I18n.tr("Input gain and mute for each microphone")
            emptyText: I18n.tr("Connect a microphone to control its input level.")
            nodes: Audio.inputs
            device: true
            capture: true
        }
        SourceGroup {
            width: (groups.width - groups.spacing * (groups.columns - 1)) / groups.columns
            title: I18n.tr("Playing apps")
            subtitle: I18n.tr("Volume and mute for each playback stream")
            emptyText: I18n.tr("Play audio in an app to see its controls here.")
            nodes: Audio.streams
        }
        SourceGroup {
            width: (groups.width - groups.spacing * (groups.columns - 1)) / groups.columns
            title: I18n.tr("Recording apps")
            subtitle: I18n.tr("Input level and mute for each recording stream")
            emptyText: I18n.tr("Apps appear here while using a microphone or recording audio.")
            nodes: Audio.captureStreams
            capture: true
        }
    }
}
