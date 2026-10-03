pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons

Item {
    id: root

    property string title: ""
    property string glyph: ""
    property string eyebrow: ""
    property real s: 1
    property bool compact: false
    property bool showHeading: false
    property int index: 0
    property bool open: false
    property real reveal: 0
    property bool tabActive: false
    default property alias content: contentColumn.data

    implicitHeight: frame.implicitHeight
    height: implicitHeight


    Item {
        id: frame
        anchors { left: parent.left; right: parent.right; top: parent.top }
        implicitHeight: header.height
            + (header.visible && contentColumn.implicitHeight > 0 ? Tokens.s2 * root.s : 0)
            + contentColumn.implicitHeight
        height: implicitHeight

        Item {
            id: header
            anchors { left: parent.left; right: parent.right; top: parent.top }
            visible: root.showHeading && (root.title !== "" || root.glyph !== "" || root.eyebrow !== "")
            height: visible ? (root.eyebrow !== "" ? Tokens.s7 : Tokens.s6) * root.s : 0

            Text {
                id: glyphText
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: root.glyph
                visible: text !== ""
                color: Tokens.inkMuted
                font.family: "Material Symbols Rounded"
                font.pixelSize: Tokens.fRow * root.s
            }

            Column {
                anchors {
                    left: glyphText.visible ? glyphText.right : parent.left
                    leftMargin: glyphText.visible ? Tokens.s2 * root.s : 0
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                }
                spacing: 2

                Text {
                    width: parent.width
                    text: root.title
                    color: Tokens.ink
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fRow * root.s
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    visible: root.eyebrow !== ""
                    text: root.eyebrow
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall * root.s
                    elide: Text.ElideRight
                }
            }
        }

        Column {
            id: contentColumn
            anchors {
                left: parent.left
                right: parent.right
                top: header.bottom
                topMargin: header.visible ? Tokens.s2 * root.s : 0
            }
            spacing: (root.compact ? Tokens.s2 : Tokens.s3) * root.s
        }
    }

}
