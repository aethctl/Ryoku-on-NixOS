import QtQuick

Row {
    id: strip

    // hueFilter: -1 none, 0-11 hue bucket, 99 grey.
    required property LibraryView view
    // Squeezes the strip to this width on the vertical rail; 0 keeps full cells.
    property real stripWidth: 0

    spacing: (strip.stripWidth > 0 ? 1 : 2) * Theme.scale

    Repeater {
        model: 13

        Rectangle {
            id: cell
            required property int index
            readonly property int filterValue: index < 12 ? index : 99
            readonly property bool isSelected: strip.view && strip.view.hueFilter === filterValue
            readonly property bool isHovered: cellMouse.containsMouse

            width: strip.stripWidth > 0 ? (strip.stripWidth - strip.spacing * 12) / 13 : 15 * Theme.scale
            height: (strip.stripWidth > 0 ? 14 : 22) * Theme.scale
            radius: Theme.radius
            z: isSelected ? 10 : (isHovered ? 5 : 1)

            color: index === 12
                ? Qt.hsla(0, 0, 0.5, 1.0)
                : Qt.hsla(index / 12.0, 0.52, 0.5, 1.0)
            opacity: (isSelected || isHovered || (strip.view && strip.view.hueFilter === -1)) ? 1.0 : 0.42
            border.width: isSelected ? 2 : 0
            border.color: Theme.surfaceText
            scale: isSelected ? 1.12 : 1.0

            Behavior on scale { NumberAnimation { duration: Theme.fast; easing.type: Easing.OutBack } }
            Behavior on opacity { NumberAnimation { duration: Theme.fast } }

            MouseArea {
                id: cellMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (!strip.view)
                        return
                    strip.view.hueFilter = cell.isSelected ? -1 : cell.filterValue
                }
            }
        }
    }
}
