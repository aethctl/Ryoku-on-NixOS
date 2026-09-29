pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"
import Ryoku.Ui.Singletons

// A single-line text entry for the desktop context menu, filling the gap the
// menu family carried: MenuRow and MenuSlider have no keyboard input. A quiet
// tracked eyebrow label sits over a bordered field in the menu-tile idiom; the
// value commits once -- on Enter or when focus leaves -- so a daemon write never
// fires per keystroke. The host menu window holds keyboard OnDemand while a menu
// is open, so the field types the way the colour picker's hex field already
// does.
Item {
    id: field

    property string label: ""
    property string placeholder: ""
    property string text: ""
    signal committed(string value)

    width: parent ? parent.width : 0
    implicitHeight: lbl.implicitHeight + Theme.s1 + box.height
    // A field grows the card only to a readable minimum, never to its content:
    // long poster copy scrolls inside the fixed box instead of stretching it.
    implicitWidth: Math.max(lbl.implicitWidth + Theme.s3 * 2, Theme.s7 * 4)

    Text {
        id: lbl
        anchors { left: parent.left; leftMargin: Theme.s3; top: parent.top }
        text: I18n.tr(field.label)
        color: Theme.inkDim
        font.family: Theme.font
        font.pixelSize: Theme.fMicro
        font.weight: Font.DemiBold
        font.letterSpacing: Theme.trackMark
    }

    Rectangle {
        id: box
        anchors {
            left: parent.left; leftMargin: Theme.s3
            right: parent.right; rightMargin: Theme.s3
            top: lbl.bottom; topMargin: Theme.s1
        }
        height: Theme.ctlH + Theme.s2
        radius: Theme.menuTileRadius
        color: Theme.tile
        border.width: input.activeFocus ? 2 : 1
        border.color: input.activeFocus ? Theme.ink : Theme.line
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: Theme.s2
            anchors.rightMargin: Theme.s2
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            color: Theme.ink
            font.family: Theme.font
            font.pixelSize: Theme.fSmall
            selectByMouse: true
            text: field.text
            onActiveFocusChanged: if (activeFocus) selectAll()

            // Persist once, then re-bind to the live value so a later config
            // change (a preset, a reset) flows back into the field.
            function commit() {
                field.committed(text);
                text = Qt.binding(function () { return field.text; });
            }
            Keys.onReturnPressed: { commit(); focus = false; }
            Keys.onEnterPressed: { commit(); focus = false; }
            onEditingFinished: commit()

            Text {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                visible: input.text.length === 0 && !input.activeFocus
                text: I18n.tr(field.placeholder)
                color: Theme.inkDim
                font: input.font
                elide: Text.ElideRight
            }
        }
    }
}
