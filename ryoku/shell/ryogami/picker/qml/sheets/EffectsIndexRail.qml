import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: rail

    // [{ name, effects: [{ id, label }] }]
    property var categories: []
    // [{ id, label }] -- the standing grade/upscale/optimise entries.
    property var extras: []
    property string selectedId: ""
    property string expandedCategory: ""
    property bool focusCategory: false
    property bool focusEffect: false
    property bool imagesOnly: true

    signal categoryPicked(string name)
    signal effectPicked(string id)
    signal extraPicked(string id)

    FolioIndexShell {
        anchors.fill: parent
        title: I18n.tr("Effects")
        note: I18n.tr("Pick an effect, adjust it, then apply.")

        Item {
            parent: parent.body
            anchors.fill: parent

            Column {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                visible: !rail.imagesOnly
                spacing: 7 * Theme.scale
                Text {
                    width: parent.width
                    text: I18n.tr("Images only")
                    font.family: Theme.ui
                    font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fontLabel
                    color: Theme.surfaceText
                    renderType: Text.NativeRendering
                }
                Text {
                    width: parent.width
                    text: I18n.tr("Effects do not work with videos, so there is nothing to edit here.")
                    font.family: Theme.ui
                    font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fontMini
                    color: Theme.withAlpha(Theme.surfaceText, 0.48)
                    lineHeight: 1.4
                    wrapMode: Text.WordWrap
                    renderType: Text.NativeRendering
                }
            }

            Flickable {
                anchors.fill: parent
                visible: rail.imagesOnly
                contentHeight: tree.height
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: tree
                    width: parent.width
                    spacing: 1 * Theme.scale

                    Repeater {
                        model: rail.categories

                        delegate: Column {
                            id: catBlock
                            required property var modelData
                            width: tree.width
                            spacing: 1 * Theme.scale

                            readonly property bool _expanded: catBlock.modelData.name === rail.expandedCategory

                            Rectangle {
                                width: parent.width
                                height: catLabel.implicitHeight + 16 * Theme.scale
                                color: catHover.containsMouse
                                    ? Theme.withAlpha(Theme.surfaceVariant, 0.62)
                                    : "transparent"
                                border.width: (rail.focusCategory && catBlock._expanded) ? 2 : 0
                                border.color: Theme.withAlpha(Theme.primary, 1)

                                Row {
                                    anchors.fill: parent
                                    anchors.leftMargin: 8 * Theme.scale
                                    anchors.rightMargin: 8 * Theme.scale
                                    spacing: 8 * Theme.scale

                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: (rail.focusCategory && catBlock._expanded) ? "\u25c6"
                                            : catBlock._expanded ? "\u25be" : "\u25b8"
                                        font.family: Theme.ui
                                        font.weight: Theme.uiWeight
                                        font.pixelSize: Theme.fontFine
                                        color: Theme.withAlpha(Theme.surfaceText, 0.7)
                                        renderType: Text.NativeRendering
                                    }
                                    Text {
                                        id: catLabel
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: String(catBlock.modelData.name).toLowerCase()
                                        font.family: Theme.ui
                                        font.weight: Theme.uiWeight
                                        font.pixelSize: Theme.fontBody2
                                        color: Theme.surfaceText
                                        renderType: Text.NativeRendering
                                    }
                                }
                                MouseArea {
                                    id: catHover
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rail.categoryPicked(catBlock.modelData.name)
                                }
                            }

                            Column {
                                width: parent.width
                                visible: catBlock._expanded
                                spacing: 1 * Theme.scale

                                Repeater {
                                    model: catBlock.modelData.effects

                                    delegate: Rectangle {
                                        id: fxRow
                                        required property var modelData
                                        width: parent.width
                                        height: fxLabel.implicitHeight + 14 * Theme.scale

                                        readonly property bool _sel: fxRow.modelData.id === rail.selectedId
                                        readonly property bool _focus: rail.focusEffect && fxRow._sel

                                        color: fxRow._sel
                                            ? Theme.withAlpha(Theme.primary, 0.18)
                                            : fxHover.containsMouse ? Theme.withAlpha(Theme.surfaceVariant, 0.62)
                                            : "transparent"
                                        border.width: fxRow._focus ? 2 : 0
                                        border.color: Theme.withAlpha(Theme.primary, 1)

                                        Rectangle {
                                            width: 1
                                            color: Theme.withAlpha(Theme.primary, 0.42)
                                            anchors.left: parent.left
                                            anchors.leftMargin: 4 * Theme.scale
                                            anchors.top: parent.top
                                            anchors.bottom: parent.bottom
                                        }

                                        Row {
                                            anchors.fill: parent
                                            anchors.leftMargin: 17 * Theme.scale
                                            anchors.rightMargin: 8 * Theme.scale
                                            spacing: 8 * Theme.scale

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: fxRow._focus ? "\u25c6" : fxRow._sel ? "\u25cf" : "\u25c7"
                                                font.family: Theme.ui
                                                font.weight: Theme.uiWeight
                                                font.pixelSize: Theme.fontTiny
                                                color: Theme.withAlpha(Theme.primary, fxRow._sel ? 1 : 0.44)
                                                renderType: Text.NativeRendering
                                            }
                                            Text {
                                                id: fxLabel
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: fxRow.modelData.label
                                                font.family: Theme.ui
                                                font.weight: Theme.uiWeight
                                                font.pixelSize: Theme.fontWide
                                                color: Theme.surfaceText
                                                renderType: Text.NativeRendering
                                            }
                                        }
                                        MouseArea {
                                            id: fxHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: rail.effectPicked(fxRow.modelData.id)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    FolioRule {
                        width: parent.width
                        alpha: 0.4
                        visible: rail.extras.length > 0
                    }

                    Repeater {
                        model: rail.extras

                        delegate: Rectangle {
                            id: extraRow
                            required property var modelData
                            width: tree.width
                            height: extraLabel.implicitHeight + 16 * Theme.scale

                            readonly property bool _sel: extraRow.modelData.id === rail.selectedId

                            color: extraRow._sel
                                ? Theme.withAlpha(Theme.primary, 0.18)
                                : extraHover.containsMouse ? Theme.withAlpha(Theme.surfaceVariant, 0.62)
                                : "transparent"

                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 8 * Theme.scale
                                anchors.rightMargin: 8 * Theme.scale
                                spacing: 8 * Theme.scale

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: extraRow._sel ? "\u25cf" : "\u25c7"
                                    font.family: Theme.ui
                                    font.weight: Theme.uiWeight
                                    font.pixelSize: Theme.fontTiny
                                    color: Theme.withAlpha(Theme.primary, extraRow._sel ? 1 : 0.44)
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    id: extraLabel
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: extraRow.modelData.label
                                    font.family: Theme.ui
                                    font.weight: Theme.uiWeight
                                    font.pixelSize: Theme.fontBody2
                                    color: Theme.surfaceText
                                    renderType: Text.NativeRendering
                                }
                            }
                            MouseArea {
                                id: extraHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: rail.extraPicked(extraRow.modelData.id)
                            }
                        }
                    }
                }
            }
        }
    }
}
