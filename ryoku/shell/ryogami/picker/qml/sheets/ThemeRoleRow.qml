import QtQuick

Item {
    id: row

    property string roleName: ""
    property string roleKey: ""
    property color swatch: "transparent"
    property string hex: ""
    property bool active: false

    signal clicked()

    implicitHeight: 30 * Theme.scale
    implicitWidth: 200 * Theme.scale

    Rectangle {
        anchors.fill: parent
        color: row.active ? Theme.withAlpha(Theme.primary, 0.18)
             : hover.containsMouse ? Theme.withAlpha(Theme.surfaceVariant, 0.62)
             : "transparent"
    }

    Text {
        id: hexLabel
        anchors.right: parent.right
        anchors.rightMargin: 7 * Theme.scale
        anchors.verticalCenter: parent.verticalCenter
        text: row.hex
        font.family: Theme.ui
        font.weight: Theme.uiWeight
        font.pixelSize: Theme.fontFine
        color: Theme.withAlpha(Theme.surfaceText, 0.46)
        renderType: Text.NativeRendering
    }

    Row {
        id: lead
        anchors.left: parent.left
        anchors.leftMargin: 7 * Theme.scale
        anchors.right: hexLabel.left
        anchors.rightMargin: 8 * Theme.scale
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8 * Theme.scale

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 10 * Theme.scale
            horizontalAlignment: Text.AlignHCenter
            text: row.active ? "\u25c6" : "\u25c7"
            font.family: Theme.ui
            font.pixelSize: Theme.fontMicro
            color: Theme.withAlpha(Theme.primary, row.active ? 1.0 : 0.44)
            renderType: Text.NativeRendering
        }

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 24 * Theme.scale
            height: 16 * Theme.scale
            color: row.swatch
            border.width: 1
            border.color: Theme.withAlpha(Theme.outline, 0.5)
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, lead.width - (10 + 24) * Theme.scale - lead.spacing * 2)
            text: row.roleName
            elide: Text.ElideRight
            font.family: Theme.ui
            font.weight: Theme.uiWeight
            font.pixelSize: Theme.fontWide
            color: Theme.surfaceText
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
