import QtQuick
import Ryoku.Ui.Singletons

// Anchored to the CardField's live currentRect, so it follows the selection as the scene moves.
Item {
    id: chrome

    required property PickerState state
    readonly property CardField field: state.field

    readonly property rect cardRect: chrome.field ? chrome.field.currentRect : Qt.rect(0, 0, 0, 0)
    readonly property int row: chrome.field ? chrome.field.currentIndex : -1
    // view.get() is a call QML cannot track, so any model change re-runs the lookup.
    property int _rev: 0
    Connections {
        target: chrome.state.view
        function onModelReset() { chrome._rev++ }
        function onDataChanged() { chrome._rev++ }
        function onLayoutChanged() { chrome._rev++ }
        function onCountChanged() { chrome._rev++ }
        function onCollectionChanged() { chrome._rev++ }
    }
    readonly property var entry: {
        chrome._rev
        var v = chrome.state.view
        if (!v || chrome.row < 0 || chrome.row >= v.count || chrome.cardRect.width <= 0)
            return ({})
        return v.get(chrome.row)
    }
    readonly property int badges: chrome.entry.badges !== undefined ? chrome.entry.badges : 0

    readonly property string typeLabel: {
        switch (chrome.entry.type) {
        case "static": return I18n.tr("PIC")
        case "video": return I18n.tr("VID")
        case "we": return I18n.tr("WE")
        default: return ""
        }
    }

    visible: !!(chrome.field && chrome.field.flippedIndex < 0
        && chrome.cardRect.width > 4 && chrome.cardRect.height > 4
        && (chrome.entry.name || chrome.entry.key))

    Item {
        x: chrome.cardRect.x
        y: chrome.cardRect.y
        width: chrome.cardRect.width
        height: chrome.cardRect.height
        clip: true

        Row {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: 8 * Theme.scale
            spacing: 5 * Theme.scale

            Rectangle {
                visible: chrome.typeLabel.length > 0
                radius: Theme.radius
                color: Theme.withAlpha(Theme.background, 0.72)
                border.width: 1
                border.color: Theme.withAlpha(Theme.outline, 0.40)
                implicitWidth: typeText.implicitWidth + 12 * Theme.scale
                implicitHeight: typeText.implicitHeight + 6 * Theme.scale
                Text {
                    id: typeText
                    anchors.centerIn: parent
                    text: chrome.typeLabel
                    font.family: Theme.ui
                    font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fontFine
                    color: Theme.primary
                    renderType: Text.NativeRendering
                }
            }

            Rectangle {
                visible: (chrome.badges & 1) !== 0
                radius: Theme.radius
                color: Theme.withAlpha(Theme.background, 0.72)
                border.width: 1
                border.color: Theme.withAlpha(Theme.outline, 0.40)
                implicitWidth: favGlyph.implicitWidth + 10 * Theme.scale
                implicitHeight: favGlyph.implicitHeight + 6 * Theme.scale
                Text {
                    id: favGlyph
                    anchors.centerIn: parent
                    text: "\u{f02d1}"
                    font.family: Theme.icon
                    font.pixelSize: Theme.fontFine
                    color: Theme.primary
                    renderType: Text.NativeRendering
                }
            }
        }

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            implicitHeight: nameText.implicitHeight + 12 * Theme.scale
            color: Theme.withAlpha(Theme.background, 0.62)

            Rectangle {
                visible: (chrome.badges & 32) !== 0
                anchors.left: parent.left
                anchors.top: parent.top
                width: 3 * Theme.scale
                height: parent.height
                color: Theme.primary
            }

            Text {
                id: nameText
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 12 * Theme.scale
                anchors.rightMargin: 12 * Theme.scale
                text: chrome.entry.name || chrome.entry.key || ""
                elide: Text.ElideRight
                font.family: Theme.ui
                font.weight: Theme.uiWeight
                font.pixelSize: Theme.fontBody
                color: Theme.surfaceText
                renderType: Text.NativeRendering
            }
        }
    }
}
