pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import inir.services
import inir.modules.common
import inir.modules.common.widgets
import inir.modules.iris.style
import inir.modules.iris.components

ColumnLayout {
    id: root

    required property var picker
    readonly property real d: IrisStyle.density

    spacing: Math.round(8 * root.d)

    component ChipStrip: Flickable {
        id: strip
        default property alias chips: chipRow.data
        Layout.fillWidth: true
        implicitHeight: Math.round(30 * root.d)
        contentWidth: chipRow.implicitWidth
        boundsBehavior: Flickable.StopAtBounds
        clip: true
        WheelHandler {
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            onWheel: event => {
                const delta = event.pixelDelta.x || event.pixelDelta.y || (event.angleDelta.y || event.angleDelta.x) / 2
                strip.contentX = Math.max(0, Math.min(Math.max(0, strip.contentWidth - strip.width), strip.contentX - delta))
            }
        }
        Row {
            id: chipRow
            height: strip.height
            spacing: Math.round(6 * root.d)
        }
    }

    ChipStrip {
        Repeater {
            model: root.picker.discoveries
            IrisButton {
                id: tagChip
                required property var modelData
                required property int index
                readonly property bool active: root.picker.discovery === tagChip.index && root.picker.series === null
                    && root.picker.query.length === 0
                text: tagChip.modelData.label
                selected: tagChip.active
                quiet: !tagChip.active
                implicitHeight: Math.round(30 * root.d)
                buttonRadius: height / 2
                buttonRadiusPressed: height / 2
                onClicked: root.picker.pickDiscovery(tagChip.index)
            }
        }
    }

    ChipStrip {
        visible: root.picker.airing.length > 0
        IrisText {
            anchors.verticalCenter: parent?.verticalCenter
            rightPadding: Math.round(4 * root.d)
            text: Translation.tr("Airing now")
            color: IrisStyle.label
            font.pixelSize: 12 * IrisStyle.typeScale
            font.weight: Font.DemiBold
        }
        Repeater {
            model: root.picker.airing
            MouseArea {
                id: seriesChip
                required property var modelData
                readonly property bool active: root.picker.series?.id === seriesChip.modelData.id
                width: seriesRow.implicitWidth + Math.round(16 * root.d)
                height: Math.round(30 * root.d)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: String(seriesChip.modelData.title ?? "")
                onClicked: root.picker.pickSeries(seriesChip.modelData)
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: seriesChip.active ? IrisStyle.tintFill(IrisStyle.accent)
                        : seriesChip.pressed ? IrisStyle.fillActive
                        : seriesChip.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(110) } }
                }
                Row {
                    id: seriesRow
                    anchors.left: parent.left
                    anchors.leftMargin: Math.round(4 * root.d)
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(7 * root.d)
                    IrisArtwork {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.round(22 * root.d)
                        height: width
                        circular: false
                        radius: IrisStyle.iconRadius(width)
                        source: String(seriesChip.modelData.imageSmall ?? "")
                        decodeSize: width * 2
                    }
                    IrisText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.picker.seriesLabel(seriesChip.modelData)
                        color: seriesChip.active ? IrisStyle.accent : IrisStyle.text
                        font.pixelSize: 12.5 * IrisStyle.typeScale
                        font.weight: seriesChip.active ? Font.DemiBold : Font.Medium
                    }
                }
            }
        }
    }
}
