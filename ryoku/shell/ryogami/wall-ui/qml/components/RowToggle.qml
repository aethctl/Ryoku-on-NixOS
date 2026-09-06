import QtQuick
import ".."

// Ryoku's boolean switch: a flat hairline rounded-rect with a monochrome ink
// knob (filled when on, hairline-outlined when off). The sun accent is reserved
// for selection, never a toggle track. Replaces skwd's coloured skewed pill.
SettingsRow {
  id: row
  property bool checked: false
  property var onToggle

  onClicked: if (onToggle) onToggle(!checked)

  readonly property color _ink:  colors ? colors.surfaceText : "#e0e2e8"
  readonly property color _line: colors ? colors.outline : Qt.rgba(1, 1, 1, 0.22)

  Rectangle {
    id: track
    width: 48 * Config.uiScale
    height: 22 * Config.uiScale
    radius: Style.radiusMedium
    color: "transparent"
    border.width: 1
    border.color: row.checked ? Qt.rgba(row._ink.r, row._ink.g, row._ink.b, 0.5) : row._line
    Behavior on border.color { ColorAnimation { duration: Style.animVeryFast } }

    Rectangle {
      id: knob
      width: 22 * Config.uiScale
      height: 16 * Config.uiScale
      radius: Style.radiusSmall
      anchors.verticalCenter: parent.verticalCenter
      x: row.checked ? parent.width - width - 3 : 3
      color: row.checked ? row._ink : "transparent"
      border.width: row.checked ? 0 : 1
      border.color: row._line
      Behavior on x { NumberAnimation { duration: Style.animFast; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: Style.animVeryFast } }
    }
  }
}
