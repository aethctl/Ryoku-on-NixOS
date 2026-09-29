pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"
import Ryoku.Ui.Singletons

// One action / value row in a desktop context menu: a label on the left, an
// optional value or live state on the right, a full-width hover wash and a
// press dip. The quiet tile idiom of the quick-settings sidebar rows. A row
// that opens something closes the menu on trigger; a toggle sets
// closeOnTrigger false to stay put while the state flips.
Item {
    id: row

    property string label: ""
    property string value: ""
    property string icon: ""         // a Material Symbols glyph the row leads with
    property bool on: false          // full ink when live, dim when idle
    property bool accent: false      // a primary action: the whole row inverts
    property bool closeOnTrigger: true
    signal triggered()

    width: parent ? parent.width : 0
    implicitHeight: Theme.s6 + Theme.s1
    // Content width, so the enclosing menu grows to fit the longest row and a
    // label never clips or elides -- at any font scale or language.
    implicitWidth: (glyph.visible ? Theme.s3 + glyph.width + Theme.s2 : Theme.s3)
        + lbl.implicitWidth
        + (val.visible ? Theme.s3 + val.implicitWidth : 0)
        + Theme.s3

    // find the enclosing DesktopMenu so a triggered row can dismiss it.
    function closeMenu() {
        var p = row.parent;
        while (p) {
            if (p.ryoMenu === true) {
                p.close();
                return;
            }
            p = p.parent;
        }
    }

    scale: ma.pressed ? 0.98 : 1
    Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }

    Rectangle {
        anchors.fill: parent
        radius: Theme.menuTileRadius
        color: row.accent ? Theme.bone
            : ma.pressed ? Theme.tilePress
            : ma.containsMouse ? Theme.tileHover : "transparent"
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    // a leading glyph in the studio's ink, so a row reads at a glance the way the
    // iRiS menu's icon column does; the label steps aside to clear it.
    Text {
        id: glyph
        visible: row.icon.length > 0
        anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
        width: visible ? Theme.s4 : 0
        horizontalAlignment: Text.AlignHCenter
        text: row.icon
        color: row.accent ? Theme.inkOnBone : (ma.containsMouse ? Theme.ink : Theme.inkDim)
        font.family: Theme.iconFont
        font.pixelSize: Theme.fBody + 3
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    Text {
        id: lbl
        anchors { left: parent.left; leftMargin: glyph.visible ? Theme.s3 + glyph.width + Theme.s2 : Theme.s3; verticalCenter: parent.verticalCenter }
        text: I18n.tr(row.label)
        color: row.accent ? Theme.inkOnBone : (ma.containsMouse ? Theme.ink : Theme.inkSoft)
        font.family: Theme.font
        font.pixelSize: Theme.fBody
        font.weight: Font.Medium
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    Text {
        id: val
        visible: row.value.length > 0
        anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
        text: row.value
        color: row.accent ? Theme.inkOnBone : (row.on ? Theme.ink : Theme.inkDim)
        font.family: Theme.font
        font.pixelSize: Theme.fSmall
        font.weight: Font.Medium
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            row.triggered();
            if (row.closeOnTrigger)
                row.closeMenu();
        }
    }
}
