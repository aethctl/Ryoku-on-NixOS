import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: chip

    signal triggered()

    implicitHeight: line.implicitHeight + 4 * Theme.scale
    implicitWidth: line.implicitWidth + 8 * Theme.scale

    readonly property bool hovered: area.containsMouse

    Row {
        id: line
        anchors.centerIn: parent
        spacing: 4 * Theme.scale

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u21ba"
            font.family: Theme.ui
            font.weight: Theme.uiWeight
            font.pixelSize: Theme.fontFine
            color: Theme.withAlpha(Theme.primary, chip.hovered ? 1 : 0.7)
            renderType: Text.NativeRendering
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tr("Reset")
            font.family: Theme.ui
            font.weight: Theme.uiWeight
            font.pixelSize: Theme.fontFine
            color: Theme.withAlpha(Theme.primary, chip.hovered ? 1 : 0.7)
            renderType: Text.NativeRendering
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.triggered()
    }
}
