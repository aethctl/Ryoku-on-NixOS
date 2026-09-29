import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: member

    property var entry: null
    property int ordinal: 1
    property int total: 1
    property bool smart: false

    signal moveUp()
    signal moveDown()
    signal removeRequested()

    readonly property bool _canUp: member.ordinal > 1
    readonly property bool _canDown: member.ordinal < member.total
    readonly property string _kind: (member.entry && member.entry.kind) ? String(member.entry.kind) : ""
    readonly property string _art: {
        if (!member.entry)
            return ""
        var p = member.entry.thumb_sm || member.entry.thumb || member.entry.preview || ""
        if (!p || p.length === 0)
            return ""
        return p.indexOf("://") >= 0 ? p : "file://" + p
    }

    implicitHeight: body.implicitHeight

    Column {
        id: body
        width: member.width

        Item {
            width: parent.width
            height: 158 * Theme.scale + 20 * Theme.scale

            Row {
                anchors.fill: parent
                anchors.topMargin: 10 * Theme.scale
                anchors.bottomMargin: 10 * Theme.scale
                spacing: 8 * Theme.scale

                Item {
                    id: spine
                    width: 26 * Theme.scale
                    height: parent.height

                    Column {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 5 * Theme.scale

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: member.ordinal < 10 ? "0" + member.ordinal : String(member.ordinal)
                            font.family: Theme.ui
                            font.weight: Theme.uiWeight
                            font.pixelSize: Theme.fontField
                            color: Theme.primary
                            renderType: Text.NativeRendering
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: member._kind === "video" ? "\u25b6"
                                : (member._kind === "we" || member._kind === "scene") ? "\u25c6"
                                : (member._kind === "static" || member._kind === "image") ? "\u25a7"
                                : "\u25c7"
                            font.family: Theme.ui
                            font.weight: Theme.uiWeight
                            font.pixelSize: Theme.fontBase
                            color: Theme.withAlpha(Theme.surfaceText, 0.54)
                            renderType: Text.NativeRendering
                        }
                    }

                    Column {
                        visible: !member.smart
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4 * Theme.scale

                        FolioAction {
                            label: "\u02c4"
                            fixedWidth: 26 * Theme.scale
                            enabled: member._canUp
                            onTriggered: member.moveUp()
                        }
                        FolioAction {
                            label: "\u02c5"
                            fixedWidth: 26 * Theme.scale
                            enabled: member._canDown
                            onTriggered: member.moveDown()
                        }
                        FolioDestructiveAction {
                            label: "\u00d7"
                            fixedWidth: 26 * Theme.scale
                            confirm: true
                            onTriggered: member.removeRequested()
                        }
                    }

                    Text {
                        visible: member.smart
                        anchors.bottom: parent.bottom
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: I18n.tr("Active")
                        font.family: Theme.ui
                        font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontMicro
                        color: Theme.withAlpha(Theme.primary, 0.72)
                        renderType: Text.NativeRendering
                    }
                }

                Item {
                    width: parent.width - spine.width - parent.spacing
                    height: parent.height

                    Image {
                        anchors.fill: parent
                        visible: member._art.length > 0
                        source: member._art
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        clip: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        visible: member._art.length === 0
                        color: Theme.withAlpha(Theme.background, 0.72)
                        border.width: 1
                        border.color: Theme.withAlpha(Theme.outline, 0.40)

                        Text {
                            anchors.centerIn: parent
                            text: member._kind.length > 0 ? member._kind.charAt(0).toUpperCase() : "?"
                            font.family: Theme.ui
                            font.weight: Theme.uiWeight
                            font.pixelSize: Theme.fs(18)
                            color: Theme.withAlpha(Theme.surfaceText, 0.40)
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }

        FolioRule {
            width: parent.width
            alpha: 0.58
        }
    }
}
