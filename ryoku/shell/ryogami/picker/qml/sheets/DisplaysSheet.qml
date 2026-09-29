import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: root

    required property PickerState state
    property var args
    property bool shown: false

    signal closeRequested()

    anchors.fill: parent

    property real _reveal: shown ? 1 : 0
    Behavior on _reveal { NumberAnimation { duration: Theme.standard; easing.type: Theme.revealEasing } }
    visible: _reveal > 0.001

    // Preserved across refreshes; falls back to the focused (or first) output when the list changes.
    property string _expandedName: ""

    readonly property bool _empty: !Library.outputs || Library.outputs.length === 0

    onShownChanged: if (shown) Library.refreshOutputs()

    Connections {
        target: Library
        function onOutputsChanged() {
            var outs = Library.outputs
            if (!outs || outs.length === 0) { root._expandedName = ""; return }
            for (var i = 0; i < outs.length; ++i)
                if (outs[i].name === root._expandedName) return
            var pick = outs[0].name
            for (var j = 0; j < outs.length; ++j)
                if (outs[j].focused) { pick = outs[j].name; break }
            root._expandedName = pick
        }
    }

    FolioSheet {
        id: sheet
        reveal: root._reveal
        onDismissed: root.closeRequested()

        FolioMasthead {
            parent: sheet.mastheadArea
            anchors.fill: parent
            reveal: root._reveal
            breadcrumb: I18n.tr("Displays")
            onCloseRequested: root.closeRequested()
        }

        FolioIndexShell {
            id: indexShell
            parent: sheet.indexArea
            anchors.fill: parent
            reveal: root._reveal
            title: I18n.tr("Displays")
            note: I18n.tr("Every monitor the wallpaper service can see. Expand one to change how it fills, lock it against updates, or steer its colours, sound and playback.")

            Column {
                parent: indexShell.body
                width: parent.width
                spacing: 11 * Theme.scale

                Text {
                    visible: root._empty
                    width: parent.width
                    text: I18n.tr("No displays reported yet.")
                    font.family: Theme.ui
                    font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fontBase
                    color: Theme.withAlpha(Theme.surfaceText, 0.46)
                    wrapMode: Text.WordWrap
                    renderType: Text.NativeRendering
                }

                Repeater {
                    model: Library.outputs
                    delegate: Row {
                        id: indexRow
                        required property var modelData
                        width: parent.width
                        spacing: 9 * Theme.scale

                        readonly property bool connected: (modelData.width > 0) && (modelData.height > 0)

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 6 * Theme.scale
                            height: 6 * Theme.scale
                            color: indexRow.connected ? Theme.primary : Theme.withAlpha(Theme.outline, 0.7)
                        }
                        Column {
                            width: parent.width - parent.spacing - 6 * Theme.scale
                            spacing: 1 * Theme.scale

                            Text {
                                width: parent.width
                                text: modelData.name
                                font.family: Theme.ui
                                font.weight: Theme.uiWeight
                                font.pixelSize: Theme.fontBody2
                                color: Theme.surfaceText
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }
                            Text {
                                width: parent.width
                                text: indexRow.connected
                                    ? (modelData.width + " \u00d7 " + modelData.height)
                                    : I18n.tr("Offline")
                                font.family: Theme.ui
                                font.weight: Theme.uiWeight
                                font.pixelSize: Theme.fontFine
                                color: Theme.withAlpha(Theme.surfaceText, 0.46)
                                elide: Text.ElideRight
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }
            }
        }

        Flickable {
            id: reading
            parent: sheet.readingArea
            anchors.fill: parent
            anchors.topMargin: 30 * Theme.scale
            anchors.leftMargin: 34 * Theme.scale
            anchors.rightMargin: 34 * Theme.scale
            anchors.bottomMargin: 40 * Theme.scale
            clip: true
            contentWidth: readCol.width
            contentHeight: readCol.implicitHeight
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: readCol
                width: reading.width
                spacing: 16 * Theme.scale

                Column {
                    width: parent.width
                    spacing: 7 * Theme.scale

                    Text {
                        text: I18n.tr("Current wallpapers")
                        font.family: Theme.ui
                        font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontTitle
                        color: Theme.surfaceText
                        renderType: Text.NativeRendering
                    }
                    Text {
                        width: parent.width
                        text: I18n.tr("These are the wallpapers currently reported by the wallpaper service. Changes made here apply to one display at a time.")
                        font.family: Theme.ui
                        font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontBase
                        color: Theme.withAlpha(Theme.surfaceText, 0.56)
                        lineHeight: 1.4
                        wrapMode: Text.WordWrap
                        renderType: Text.NativeRendering
                    }
                }

                FolioRule {
                    width: parent.width
                    alpha: 0.5
                    reveal: root._reveal
                }

                Column {
                    visible: root._empty
                    width: parent.width
                    spacing: 5 * Theme.scale

                    Text {
                        text: I18n.tr("Detecting displays")
                        font.family: Theme.ui
                        font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontLabel
                        color: Theme.surfaceText
                        renderType: Text.NativeRendering
                    }
                    Text {
                        width: parent.width
                        text: I18n.tr("Current wallpapers will appear when the wallpaper service reports its displays.")
                        font.family: Theme.ui
                        font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontBase
                        color: Theme.withAlpha(Theme.surfaceText, 0.5)
                        lineHeight: 1.35
                        wrapMode: Text.WordWrap
                        renderType: Text.NativeRendering
                    }
                }

                Repeater {
                    model: Library.outputs
                    delegate: StackBar {
                        id: bar
                        required property var modelData
                        width: readCol.width
                        title: {
                            var nm = modelData.name || ""
                            var cur = modelData.current || ({})
                            var p = cur.path ? String(cur.path) : ""
                            var base = ""
                            if (p.length > 0) {
                                var i = p.lastIndexOf("/")
                                base = i >= 0 ? p.substring(i + 1) : p
                            } else if (cur.key) {
                                base = String(cur.key)
                            }
                            return base.length > 0 ? (nm + "  \u00b7  " + base) : nm
                        }
                        expanded: root._expandedName === modelData.name
                        onToggled: (e) => root._expandedName = e ? modelData.name : ""

                        DisplayCard {
                            parent: bar.body
                            width: parent.width
                            state: root.state
                            output: bar.modelData
                        }
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: root.closeRequested()
}
