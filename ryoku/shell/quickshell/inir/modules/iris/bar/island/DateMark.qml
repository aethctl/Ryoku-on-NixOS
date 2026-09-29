pragma ComponentBehavior: Bound

import QtQuick
import inir.services
import inir.modules.common
import inir.modules.common.widgets
import inir.modules.iris.style
import inir.modules.iris.components

Row {
    id: dateMark
    property real pixelSize: 12 * IrisStyle.typeScale
    property color dayColor: IrisStyle.frameAccent
    spacing: Math.round(dateMark.pixelSize * 0.3)
    IrisText {
        id: weekdayText
        text: Qt.locale().toString(DateTime.clock.date, "ddd").replace(/\.$/, "")
        color: IrisStyle.muted
        font.pixelSize: dateMark.pixelSize * 0.92
        font.weight: Font.Medium
    }
    IrisText {
        anchors.baseline: weekdayText.baseline
        text: Qt.locale().toString(DateTime.clock.date, "d")
        color: dateMark.dayColor
        font.pixelSize: dateMark.pixelSize
        font.family: IrisStyle.fontNumbers
        font.weight: Font.Bold
        font.features: ({ "tnum": 1 })
    }
}
