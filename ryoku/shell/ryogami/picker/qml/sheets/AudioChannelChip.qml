import QtQuick
import Ryoku.Ui.Singletons

Rectangle {
    id: chip

    property var output: null
    property int ordinal: 1
    property bool shared: false
    property bool muted: false
    property bool manual: false

    readonly property var _cur: (chip.output && chip.output.current) ? chip.output.current : null
    readonly property string _type: chip._cur ? (chip._cur.type || "") : ""
    readonly property bool _hasAudio: chip._type === "video" || chip._type === "we"
    readonly property bool _playing: chip._hasAudio && !chip.muted && !chip.manual
    readonly property string _name: {
        var n = chip.output ? (chip.output.name || "") : ""
        return (n === "" || n === "*") ? I18n.tr("Shared outputs") : n
    }
    readonly property string _state: !chip._hasAudio ? I18n.tr("No audio")
        : chip.manual ? I18n.tr("Paused")
        : chip.muted ? I18n.tr("Muted")
        : I18n.tr("Sound")

    color: Theme.withAlpha(Theme.surfaceContainer, 0.45)
    border.width: 1
    border.color: Theme.withAlpha(Theme.outline, 0.42)
    implicitHeight: nameCol.implicitHeight + 18 * Theme.scale

    Item {
        id: pad
        anchors.fill: parent
        anchors.leftMargin: 10 * Theme.scale
        anchors.rightMargin: 10 * Theme.scale
        anchors.topMargin: 9 * Theme.scale
        anchors.bottomMargin: 9 * Theme.scale

        Text {
            id: ord
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: chip.ordinal < 10 ? ("0" + chip.ordinal) : String(chip.ordinal)
            font.family: Theme.ui
            font.weight: Theme.uiWeight
            font.pixelSize: Theme.fontFine
            color: Theme.withAlpha(Theme.primary, chip._playing ? 1 : 0.5)
            renderType: Text.NativeRendering
        }

        Text {
            id: marker
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: chip._playing ? "\u25c6" : "\u25c7"
            font.family: Theme.ui
            font.weight: Theme.uiWeight
            font.pixelSize: Theme.fontFine
            color: chip._playing ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.34)
            renderType: Text.NativeRendering
        }

        Column {
            id: nameCol
            anchors.left: ord.right
            anchors.right: marker.left
            anchors.leftMargin: 9 * Theme.scale
            anchors.rightMargin: 9 * Theme.scale
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2 * Theme.scale

            Text {
                width: parent.width
                text: chip._name
                font.family: Theme.ui
                font.weight: Theme.uiWeight
                font.pixelSize: Theme.fontBody
                color: Theme.surfaceText
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
            Text {
                width: parent.width
                text: chip._state
                font.family: Theme.ui
                font.weight: Theme.uiWeight
                font.pixelSize: Theme.fontBase
                color: Theme.withAlpha(Theme.surfaceText, 0.46)
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }
    }
}
