import QtQuick
import ".."

// A titled group of settings, drawn Ryoku-style: a flat sheet with a hairline
// border and no shadow ("the Hub is print"), a //TRACKED_ header with an
// optional kana seal, closed by a hairline rule, then the rows. Replaces skwd's
// chamfered, filled, drop-shadowed card with the accent corner-tick.
Item {
  id: root
  property var colors
  property string title: ""
  property string subtitle: ""
  property string kana: ""
  default property alias _content: contentCol.data
  property alias titleAction: titleActionSlot.data
  property int innerPad: 16

  width: parent ? parent.width : 0
  implicitHeight: cardArea.height + 14

  readonly property color _ink:    colors ? colors.surfaceText : "#e0e2e8"
  readonly property color _inkDim: colors ? colors.surfaceVariantText : "#c2c7cf"
  readonly property color _line:   colors ? colors.outline : Qt.rgba(1, 1, 1, 0.22)
  readonly property color _paper:  colors ? colors.surface : "#101418"

  Rectangle {
    id: cardArea
    anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 4; rightMargin: 4 }
    height: bodyCol.implicitHeight + root.innerPad * 2
    radius: Style.radiusMedium
    border.width: 1
    border.color: root._line
    color: Qt.rgba(root._paper.r, root._paper.g, root._paper.b, 0.97)
    Column {
      id: bodyCol
      anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: root.innerPad; rightMargin: root.innerPad; topMargin: root.innerPad }
      spacing: 12

      // header: //TITLE_ tracked + kana seal + optional action slot
      Item {
        id: headerItem
        visible: root.title !== "" || root.subtitle !== "" || titleActionSlot.children.length > 0
        width: parent.width
        implicitHeight: Math.max(headerCol.implicitHeight, titleActionSlot.height)

        Column {
          id: headerCol
          anchors { left: parent.left; right: titleActionSlot.left; verticalCenter: parent.verticalCenter; rightMargin: 12 }
          spacing: 4
          Row {
            spacing: 6
            Text {
              text: "//"
              font.family: Style.fontFamilyMono; font.pixelSize: 11 * Config.uiScale
              color: Qt.rgba(root._inkDim.r, root._inkDim.g, root._inkDim.b, 0.5)
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              visible: root.title !== ""
              text: root.title.toUpperCase() + "_"
              font.family: Style.fontFamily; font.pixelSize: 11 * Config.uiScale
              font.weight: Font.Medium; font.letterSpacing: 1.4
              color: root._inkDim
              anchors.verticalCenter: parent.verticalCenter
            }
            Text {
              visible: root.kana !== ""
              text: root.kana
              font.family: Style.fontFamilyJp; font.pixelSize: 12 * Config.uiScale
              color: Qt.rgba(root._inkDim.r, root._inkDim.g, root._inkDim.b, 0.5)
              anchors.verticalCenter: parent.verticalCenter
            }
          }
          Text {
            visible: root.subtitle !== ""
            width: parent.width
            text: root.subtitle
            wrapMode: Text.WordWrap
            font.family: Style.fontFamily; font.pixelSize: 11
            color: Qt.rgba(root._inkDim.r, root._inkDim.g, root._inkDim.b, 0.8)
          }
        }

        Item {
          id: titleActionSlot
          anchors { right: parent.right; verticalCenter: parent.verticalCenter }
          width: childrenRect.width; height: childrenRect.height
        }
      }

      // the rule that closes the header, Ryoku's print divider
      Rectangle {
        visible: headerItem.visible
        width: parent.width; height: 1
        color: Qt.rgba(root._line.r, root._line.g, root._line.b, 0.55)
      }

      Column { id: contentCol; width: parent.width }
    }
  }
}
