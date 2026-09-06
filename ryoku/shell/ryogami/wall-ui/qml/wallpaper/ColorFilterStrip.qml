import QtQuick
import ".."

// Colour filter, Ryoku "colour-as-data": compact flat swatches, orthogonal and
// hairline-tight, slightly muted. Selecting one rings it in ink and dims the
// rest to focus the choice. Replaces skwd's skewed, overlapping full-rainbow.
Row {
  id: strip

  property var colors
  property int selectedValue: -1
  signal valueSelected(int value)

  spacing: 2 * Config.uiScale

  Repeater {
    model: 13

    Rectangle {
      width: 15 * Config.uiScale
      height: 22 * Config.uiScale
      radius: Style.radiusSmall
      readonly property int filterValue: index < 12 ? index : 99
      readonly property bool isSelected: strip.selectedValue === filterValue
      readonly property bool isHovered: _m.containsMouse
      z: isSelected ? 10 : (isHovered ? 5 : 1)

      color: index === 12 ? Qt.hsla(0, 0, 0.5, 1.0) : Qt.hsla(index / 12.0, 0.52, 0.5, 1.0)
      opacity: (isSelected || isHovered || strip.selectedValue === -1) ? 1.0 : 0.42
      border.width: isSelected ? 2 : 0
      border.color: strip.colors ? strip.colors.surfaceText : "#ffffff"
      scale: isSelected ? 1.12 : 1.0
      Behavior on scale { NumberAnimation { duration: Style.animVeryFast; easing.type: Easing.OutBack } }
      Behavior on opacity { NumberAnimation { duration: Style.animVeryFast } }

      MouseArea {
        id: _m
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: strip.valueSelected(parent.isSelected ? -1 : parent.filterValue)
      }
    }
  }
}
