import QtQuick
import QtQuick.Layouts
import Quickshell
import "Singletons"
import Ryoku.Ui.Singletons

// The region-selector front: a floating bar that picks what a drawn region does
// (Shot, Edit, OCR, Search, Record) plus the region-free tools (colour pick,
// whole-monitor capture, close). It carries no capture logic itself; the shell
// reads activeAction when a region lands and dispatches from there.
Item {
    id: bar
    implicitWidth: glass.implicitWidth
    implicitHeight: glass.implicitHeight

    property var actions: []
    property string activeAction: "shot"
    property bool audioOn: false

    signal actionPicked(string id)
    signal colorPickRequested()
    signal fullscreenRequested()
    signal audioToggled()
    signal closeRequested()

    Rectangle {
        id: glass
        anchors.fill: parent
        radius: Theme.radius
        color: Theme.panel
        border.color: Theme.hair
        border.width: 1
        implicitWidth: row.implicitWidth + 16
        implicitHeight: row.implicitHeight + 12

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 6

            // Action selector: one segment per capture action. The chosen segment
            // wears the accent so the next drawn region reads its intent at a glance.
            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: actionRow.implicitWidth + 6
                implicitHeight: 40
                radius: height / 2
                color: Theme.field

                Row {
                    id: actionRow
                    anchors.centerIn: parent
                    spacing: 2

                    Repeater {
                        model: bar.actions
                        Rectangle {
                            id: tab
                            required property var modelData
                            readonly property bool current: bar.activeAction === modelData.id
                            width: tabContent.implicitWidth + 22
                            height: 34
                            radius: height / 2
                            color: current ? Theme.accent
                                : (tabMa.containsMouse ? Theme.hover : "transparent")

                            Row {
                                id: tabContent
                                anchors.centerIn: parent
                                spacing: 6
                                Icon {
                                    anchors.verticalCenter: parent.verticalCenter
                                    name: tab.modelData.icon
                                    size: 17
                                    tint: tab.current ? Theme.accentInk
                                        : (tabMa.containsMouse ? Theme.ink : Theme.inkDim)
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: tab.modelData.label
                                    font.family: Theme.ui
                                    font.pixelSize: 13
                                    font.weight: tab.current ? Font.DemiBold : Font.Normal
                                    color: tab.current ? Theme.accentInk
                                        : (tabMa.containsMouse ? Theme.ink : Theme.inkDim)
                                }
                            }

                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: bar.actionPicked(tab.modelData.id)
                            }
                        }
                    }
                }
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 22; color: Theme.hair }

            // Sound only matters for a recording, so it appears with Record.
            IconButton {
                Layout.alignment: Qt.AlignVCenter
                icon: "sound"
                visible: bar.activeAction === "record"
                active: bar.audioOn
                tooltip: I18n.tr("Record system audio")
                onClicked: bar.audioToggled()
            }

            IconButton {
                Layout.alignment: Qt.AlignVCenter
                icon: "eyedropper"
                tooltip: I18n.tr("Pick a colour")
                onClicked: bar.colorPickRequested()
            }
            IconButton {
                Layout.alignment: Qt.AlignVCenter
                icon: "fullscreen"
                tooltip: I18n.tr("Capture this monitor")
                onClicked: bar.fullscreenRequested()
            }

            Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: 22; color: Theme.hair }

            Rectangle {
                id: closeBtn
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 32
                Layout.preferredHeight: 32
                radius: 7
                color: closeMa.containsMouse ? Qt.rgba(Theme.danger.r, Theme.danger.g, Theme.danger.b, 0.16) : "transparent"
                Icon {
                    anchors.centerIn: parent
                    name: "cancel"
                    size: 18
                    tint: closeMa.containsMouse ? Theme.danger : Theme.inkDim
                }
                MouseArea {
                    id: closeMa
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: bar.closeRequested()
                }
            }
        }
    }
}
