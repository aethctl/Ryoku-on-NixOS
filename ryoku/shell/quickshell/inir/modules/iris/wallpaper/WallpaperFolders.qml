pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
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

    component Strip: Flickable {
        id: strip
        default property alias items: stripRow.data
        property real rowHeight: Math.round(30 * root.d)
        Layout.fillWidth: true
        implicitHeight: strip.rowHeight
        contentWidth: stripRow.implicitWidth
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
            id: stripRow
            height: strip.rowHeight
            spacing: Math.round(6 * root.d)
        }
    }

    Strip {
        Repeater {
            model: root.picker.places
            MouseArea {
                id: place
                required property var modelData
                readonly property bool here: root.picker.folderPath === place.modelData.path
                width: placeRow.implicitWidth + Math.round(22 * root.d)
                height: Math.round(30 * root.d)
                hoverEnabled: true
                cursorShape: place.here ? Qt.ArrowCursor : Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: place.modelData.label
                onClicked: root.picker.openFolder(place.modelData.path)
                Rectangle {
                    anchors.fill: parent
                    radius: height / 2
                    color: place.here ? IrisStyle.tintFill(IrisStyle.accent)
                        : place.pressed ? IrisStyle.fillActive
                        : place.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(110) } }
                }
                Row {
                    id: placeRow
                    anchors.centerIn: parent
                    spacing: Math.round(6 * root.d)
                    MaterialSymbol {
                        anchors.verticalCenter: parent.verticalCenter
                        text: place.modelData.glyph
                        fill: 1
                        iconSize: Math.round(16 * root.d)
                        color: place.here || place.modelData.pinned ? IrisStyle.accent : IrisStyle.subtext
                    }
                    IrisText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: place.modelData.label
                        color: place.here ? IrisStyle.accent : IrisStyle.text
                        font.pixelSize: 12.5 * IrisStyle.typeScale
                        font.weight: place.here ? Font.DemiBold : Font.Medium
                    }
                }
            }
        }
    }

    Strip {
        visible: root.picker.libraryFolders.length > 0
        rowHeight: Math.round(44 * root.d)
        Repeater {
            model: root.picker.libraryFolders
            MouseArea {
                id: folder
                required property var modelData
                readonly property var info: root.picker.folderInfo[folder.modelData.path] ?? null
                readonly property string cover: String(folder.info?.cover ?? "")
                readonly property real inset: Math.round(6 * root.d)
                width: folderRow.implicitWidth + folder.inset + Math.round(14 * root.d)
                height: Math.round(44 * root.d)
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                Accessible.role: Accessible.Button
                Accessible.name: folder.modelData.name
                onClicked: root.picker.openFolder(folder.modelData.path)
                Rectangle {
                    anchors.fill: parent
                    radius: IrisStyle.radiusTile
                    color: folder.pressed ? IrisStyle.fillActive : folder.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
                    scale: folder.pressed ? IrisStyle.pressScale(0.97) : 1
                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(110) } }
                    Behavior on scale { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                }
                Row {
                    id: folderRow
                    anchors.left: parent.left
                    anchors.leftMargin: folder.inset
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Math.round(9 * root.d)
                    ClippingRectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: folder.height - 2 * folder.inset
                        height: width
                        radius: Math.max(IrisStyle.radiusMicro, IrisStyle.radiusTile - folder.inset)
                        color: IrisStyle.fill
                        MaterialSymbol {
                            anchors.centerIn: parent
                            visible: folder.cover.length === 0
                            text: "folder"
                            fill: 1
                            iconSize: Math.round(17 * root.d)
                            color: IrisStyle.accent
                        }
                        Loader {
                            anchors.fill: parent
                            active: folder.cover.length > 0
                            sourceComponent: ThumbnailImage {
                                generateThumbnail: true
                                cleanVideoStill: true
                                sourcePath: folder.cover
                                thumbnailSizeName: "normal"
                                fillMode: Image.PreserveAspectCrop
                                sourceSize.width: Math.round(width * 2)
                                sourceSize.height: Math.round(height * 2)
                            }
                        }
                    }
                    IrisText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: folder.modelData.name
                        font.pixelSize: 12.5 * IrisStyle.typeScale
                        font.weight: Font.Medium
                    }
                    IrisText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: (folder.info?.count ?? 0) > 0
                        text: String(folder.info?.count ?? "")
                        color: IrisStyle.secondaryAccent
                        font.family: IrisStyle.fontNumbers
                        font.features: ({ "tnum": 1 })
                        font.pixelSize: 11.5 * IrisStyle.typeScale
                        font.weight: Font.Bold
                    }
                }
            }
        }
    }
}
