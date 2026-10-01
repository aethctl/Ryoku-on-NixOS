import QtQuick
import QtQuick.Layouts
import "../../../../reusables"
import "../../../../"

Item {
    id: classicFaceRoot
    property var widget: null

    implicitWidth: timeCol.implicitWidth
    implicitHeight: timeCol.implicitHeight

    Column {
        id: timeCol
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        spacing: -2

        Text {
            id: timeText
            anchors.left: parent.left
            text: widget ? widget.timeStr : (typeof DateTime !== "undefined" ? DateTime.time : "12:00")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: widget ? widget.s(widget.isCompact ? 14 : 15) : 15
            font.weight: Font.Black
            color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.blue, 1.1) : ThemeBackend.blue
        }

        Text {
            id: dateText
            visible: widget ? widget.showDate : true
            anchors.left: parent.left
            text: widget ? widget.dateStr : (typeof DateTime !== "undefined" ? DateTime.fullDate : "Mon, Jan 1")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: widget ? widget.s(widget.isCompact ? 9 : 10) : 10
            font.weight: Font.Bold
            color: (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.subtext0, 1.08) : ThemeBackend.subtext0
        }
    }
}
