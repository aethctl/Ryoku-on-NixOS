import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: row

    property int pid: 0
    property string name: ""
    property string detail: ""
    property bool playing: false
    property bool selected: false

    signal clicked()

    implicitHeight: Math.max(mid.implicitHeight, marker.implicitHeight) + 18 * Theme.scale

    Rectangle {
        anchors.fill: parent
        color: row.selected ? Theme.withAlpha(Theme.primary, 0.18)
             : hover.containsMouse ? Theme.withAlpha(Theme.surfaceVariant, 0.62)
             : "transparent"
    }

    Text {
        id: idLabel
        anchors.left: parent.left
        anchors.leftMargin: 10 * Theme.scale
        anchors.verticalCenter: parent.verticalCenter
        text: I18n.tr("ID %1").arg(row.pid)
        font.family: Theme.ui
        font.weight: Theme.uiWeight
        font.pixelSize: Theme.fontFine
        color: (row.selected || row.playing) ? Theme.primary : Theme.withAlpha(Theme.primary, 0.46)
        renderType: Text.NativeRendering
    }

    Text {
        id: marker
        anchors.right: parent.right
        anchors.rightMargin: 10 * Theme.scale
        anchors.verticalCenter: parent.verticalCenter
        text: row.playing ? "\u25cf" : row.selected ? "\u25c6" : "\u25c7"
        font.family: Theme.ui
        font.weight: Theme.uiWeight
        font.pixelSize: Theme.fontFine
        color: (row.selected || row.playing) ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.32)
        renderType: Text.NativeRendering
    }

    Column {
        id: mid
        anchors.left: idLabel.right
        anchors.leftMargin: 9 * Theme.scale
        anchors.right: marker.left
        anchors.rightMargin: 9 * Theme.scale
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3 * Theme.scale

        Text {
            width: parent.width
            text: row.name
            font.family: Theme.ui
            font.weight: Theme.uiWeight
            font.pixelSize: Theme.fontBody
            color: Theme.surfaceText
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
        Text {
            width: parent.width
            text: row.detail
            font.family: Theme.ui
            font.weight: Theme.uiWeight
            font.pixelSize: Theme.fontTiny
            color: row.playing ? Theme.withAlpha(Theme.primary, 0.86) : Theme.withAlpha(Theme.surfaceText, 0.44)
            elide: Text.ElideRight
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        id: hover
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
}
