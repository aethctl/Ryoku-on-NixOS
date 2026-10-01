import QtQuick
import QtQuick.Layouts
import "../../../../reusables"
import "../../../../"

Item {
    id: badgeFaceRoot
    property var widget: null

    readonly property string timeStr: widget ? widget.timeStr : (typeof DateTime !== "undefined" ? DateTime.time : "12:30")
    readonly property string dateStr: {
        if (widget && widget.dateStr !== undefined && widget.dateStr !== null && String(widget.dateStr) !== "") {
            return String(widget.dateStr).toUpperCase()
        }
        if (widget && widget.dayStr && widget.monthStr) {
            return (String(widget.dayStr) + " " + String(widget.monthStr)).toUpperCase()
        }
        if (typeof DateTime !== "undefined") {
            if (DateTime.day !== undefined && DateTime.monthShort !== undefined) {
                return (String(DateTime.day) + " " + String(DateTime.monthShort)).toUpperCase()
            }
            if (DateTime.fullDate) {
                return String(DateTime.fullDate).toUpperCase()
            }
        }
        return "18 SEP"
    }

    readonly property real dotSize: widget ? widget.s(widget.isCompact ? 1.8 : 2.2) : 2.2
    readonly property real dotSpacing: widget ? widget.s(widget.isCompact ? 0.9 : 1.1) : 1.1

    implicitWidth: badgeRow.implicitWidth
    implicitHeight: badgeRow.implicitHeight

    QtObject {
        id: matrixFont
        readonly property var chars: ({
            "0": [1,1,1, 1,0,1, 1,0,1, 1,0,1, 1,1,1],
            "1": [0,1,0, 1,1,0, 0,1,0, 0,1,0, 1,1,1],
            "2": [1,1,1, 0,0,1, 1,1,1, 1,0,0, 1,1,1],
            "3": [1,1,1, 0,0,1, 1,1,1, 0,0,1, 1,1,1],
            "4": [1,0,1, 1,0,1, 1,1,1, 0,0,1, 0,0,1],
            "5": [1,1,1, 1,0,0, 1,1,1, 0,0,1, 1,1,1],
            "6": [1,1,1, 1,0,0, 1,1,1, 1,0,1, 1,1,1],
            "7": [1,1,1, 0,0,1, 0,0,1, 0,0,1, 0,0,1],
            "8": [1,1,1, 1,0,1, 1,1,1, 1,0,1, 1,1,1],
            "9": [1,1,1, 1,0,1, 1,1,1, 0,0,1, 1,1,1],
            ":": [0,0,0, 0,1,0, 0,0,0, 0,1,0, 0,0,0],
            ".": [0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,1,0],
            "-": [0,0,0, 0,0,0, 1,1,1, 0,0,0, 0,0,0],
            "/": [0,0,1, 0,0,1, 0,1,0, 1,0,0, 1,0,0],
            ",": [0,0,0, 0,0,0, 0,0,0, 0,1,0, 1,0,0],
            " ": [0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0],
            "A": [0,1,0, 1,0,1, 1,1,1, 1,0,1, 1,0,1],
            "B": [1,1,0, 1,0,1, 1,1,0, 1,0,1, 1,1,0],
            "C": [0,1,1, 1,0,0, 1,0,0, 1,0,0, 0,1,1],
            "D": [1,1,0, 1,0,1, 1,0,1, 1,0,1, 1,1,0],
            "E": [1,1,1, 1,0,0, 1,1,0, 1,0,0, 1,1,1],
            "F": [1,1,1, 1,0,0, 1,1,0, 1,0,0, 1,0,0],
            "G": [0,1,1, 1,0,0, 1,0,1, 1,0,1, 0,1,1],
            "H": [1,0,1, 1,0,1, 1,1,1, 1,0,1, 1,0,1],
            "I": [1,1,1, 0,1,0, 0,1,0, 0,1,0, 1,1,1],
            "J": [0,0,1, 0,0,1, 0,0,1, 1,0,1, 0,1,0],
            "K": [1,0,1, 1,1,0, 1,0,0, 1,1,0, 1,0,1],
            "L": [1,0,0, 1,0,0, 1,0,0, 1,0,0, 1,1,1],
            "M": [1,0,1, 1,1,1, 1,0,1, 1,0,1, 1,0,1],
            "N": [1,1,0, 1,0,1, 1,0,1, 1,0,1, 1,0,1],
            "O": [0,1,0, 1,0,1, 1,0,1, 1,0,1, 0,1,0],
            "P": [1,1,0, 1,0,1, 1,1,0, 1,0,0, 1,0,0],
            "Q": [0,1,0, 1,0,1, 1,0,1, 0,1,1, 0,0,1],
            "R": [1,1,0, 1,0,1, 1,1,0, 1,0,1, 1,0,1],
            "S": [0,1,1, 1,0,0, 0,1,0, 0,0,1, 1,1,0],
            "T": [1,1,1, 0,1,0, 0,1,0, 0,1,0, 0,1,0],
            "U": [1,0,1, 1,0,1, 1,0,1, 1,0,1, 0,1,0],
            "V": [1,0,1, 1,0,1, 1,0,1, 1,0,1, 0,1,0],
            "W": [1,0,1, 1,0,1, 1,0,1, 1,1,1, 1,0,1],
            "X": [1,0,1, 1,0,1, 0,1,0, 1,0,1, 1,0,1],
            "Y": [1,0,1, 1,0,1, 0,1,0, 0,1,0, 0,1,0],
            "Z": [1,1,1, 0,0,1, 0,1,0, 1,0,0, 1,1,1]
        })

        function getPattern(charStr) {
            return chars[charStr] || chars[charStr.toUpperCase()] || [0,0,0, 0,0,0, 0,0,0, 0,0,0, 0,0,0]
        }
    }

    Row {
        id: badgeRow
        anchors.centerIn: parent
        spacing: widget ? widget.s(widget.isCompact ? 6 : 8.5) : 8.5

        Row {
            id: timeRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: widget ? widget.s(widget.isCompact ? 2 : 2.5) : 2.5

            Repeater {
                model: badgeFaceRoot.timeStr.length

                Grid {
                    id: charGrid
                    property int charIndex: index
                    property string character: badgeFaceRoot.timeStr.charAt(charIndex)
                    property var pattern: matrixFont.getPattern(character)
                    property int colonIndex: badgeFaceRoot.timeStr.indexOf(":")
                    property color activeColor: character === ":"
                        ? ThemeBackend.subtext0
                        : (colonIndex === -1 || charIndex < colonIndex ? ThemeBackend.blue : ThemeBackend.text)

                    columns: 3
                    rows: 5
                    spacing: badgeFaceRoot.dotSpacing

                    Repeater {
                        model: 15

                        Rectangle {
                            property int dotIndex: index
                            property bool isLit: charGrid.pattern && charGrid.pattern[dotIndex] === 1

                            width: badgeFaceRoot.dotSize
                            height: badgeFaceRoot.dotSize
                            radius: badgeFaceRoot.dotSize / 2
                            color: isLit ? charGrid.activeColor : Qt.alpha(charGrid.activeColor, 0.1)
                        }
                    }
                }
            }
        }

        Grid {
            id: matrixDivider
            visible: widget ? widget.showDate : true
            columns: 1
            rows: 5
            spacing: badgeFaceRoot.dotSpacing
            anchors.verticalCenter: parent.verticalCenter

            Repeater {
                model: 5

                Rectangle {
                    width: badgeFaceRoot.dotSize
                    height: badgeFaceRoot.dotSize
                    radius: badgeFaceRoot.dotSize / 2
                    color: (index === 1 || index === 3)
                        ? Qt.alpha(ThemeBackend.surface2, 0.8)
                        : Qt.alpha(ThemeBackend.surface2, 0.15)
                }
            }
        }

        Row {
            id: dateRow
            visible: widget ? widget.showDate : true
            anchors.verticalCenter: parent.verticalCenter
            spacing: widget ? widget.s(widget.isCompact ? 2 : 2.5) : 2.5

            Repeater {
                model: badgeFaceRoot.dateStr.length

                Grid {
                    id: dateCharGrid
                    property int charIndex: index
                    property string character: badgeFaceRoot.dateStr.charAt(charIndex)
                    property var pattern: matrixFont.getPattern(character)
                    property color activeColor: {
                        if (/[0-9]/.test(character)) {
                            return (widget && widget.isCompact) ? Qt.lighter(ThemeBackend.peach, 1.08) : ThemeBackend.peach
                        }
                        if (/[\.\-\/\,]/.test(character)) {
                            return ThemeBackend.surface2
                        }
                        return ThemeBackend.subtext0
                    }

                    columns: 3
                    rows: 5
                    spacing: badgeFaceRoot.dotSpacing

                    Repeater {
                        model: 15

                        Rectangle {
                            property int dotIndex: index
                            property bool isLit: dateCharGrid.pattern && dateCharGrid.pattern[dotIndex] === 1

                            width: badgeFaceRoot.dotSize
                            height: badgeFaceRoot.dotSize
                            radius: badgeFaceRoot.dotSize / 2
                            color: isLit ? dateCharGrid.activeColor : Qt.alpha(dateCharGrid.activeColor, 0.1)
                        }
                    }
                }
            }
        }
    }
}
