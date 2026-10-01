import QtQuick
import Ryoku.Ui.Singletons

// Owns no state; every edit is reported to the panel.
Rectangle {
    id: drawer

    property string provider: ""
    property string providerLabel: ""
    property var sources: null
    property var state: ({})
    property var collections: []
    property bool searchable: true
    property bool manual: false      // showApplyButton -> manual search mode
    property string query: ""
    property real reveal: 1

    signal queryEdited(string text)
    signal searchSubmitted(string text)
    signal filtersChanged(var next)
    signal applyPressed()

    color: Theme.withAlpha(Theme.surfaceVariant, 0.3)
    border.width: 1
    border.color: Theme.withAlpha(Theme.outline, 0.34)

    readonly property real _innerW: width - 28 * Theme.scale
    readonly property bool searchEditing: searchInput.editing

    Flickable {
        id: flick
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: applyBtn.visible ? applyBtn.top : parent.bottom
        anchors.topMargin: 15 * Theme.scale
        anchors.leftMargin: 14 * Theme.scale
        anchors.rightMargin: 4 * Theme.scale
        anchors.bottomMargin: applyBtn.visible ? 8 * Theme.scale : 15 * Theme.scale
        clip: true
        contentWidth: width
        contentHeight: col.implicitHeight
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: col
            width: flick.width - 10 * Theme.scale
            spacing: 10 * Theme.scale

            SectionLabel {
                width: parent.width
                text: I18n.tr("Search")
            }

            Rectangle {
                width: parent.width
                height: searchInput.implicitHeight + 12 * Theme.scale
                radius: Theme.radius
                color: Theme.withAlpha(Theme.surfaceText, 0.05)
                border.width: 1
                border.color: Theme.withAlpha(Theme.outline, 0.4)

                TextField {
                    id: searchInput
                    visible: drawer.searchable
                    anchors.fill: parent
                    anchors.leftMargin: 2 * Theme.scale
                    anchors.rightMargin: 2 * Theme.scale
                    variant: "ghost"
                    glyph: "\uf002"
                    placeholder: drawer.sources ? drawer.sources.searchPlaceholder(drawer.provider) : ""
                    text: drawer.query
                    onEdited: function(t) { drawer.queryEdited(t) }
                    onCommitted: function(t) { drawer.searchSubmitted(t) }
                }
                Text {
                    visible: !drawer.searchable
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 8 * Theme.scale
                    text: drawer.providerLabel
                    font.family: Theme.sans
                    font.weight: Font.Medium
                    font.pixelSize: Theme.fontField
                    color: Theme.surfaceText
                    renderType: Text.NativeRendering
                }
            }

            FolioRule { width: parent.width; alpha: 0.34; reveal: drawer.reveal }

            SectionLabel {
                visible: drawer.searchable
                width: parent.width
                text: I18n.tr("Filters")
            }
            Text {
                visible: drawer.searchable
                width: parent.width
                wrapMode: Text.WordWrap
                text: drawer.manual
                    ? I18n.tr("Change filters, then press Apply or Enter to search.")
                    : I18n.tr("Each provider has different filters. Changing them starts a new search without importing anything.")
                font.family: Theme.sans
                font.weight: Font.Normal
                font.pixelSize: Theme.fontBase
                color: Theme.withAlpha(Theme.surfaceText, 0.48 * drawer.reveal)
                renderType: Text.NativeRendering
            }

            BrowserChips {
                visible: drawer.searchable
                width: drawer._innerW
                provider: drawer.provider
                sources: drawer.sources
                state: drawer.state
                collections: drawer.collections
                onChanged: function(next) { drawer.filtersChanged(next) }
            }
        }
    }

    FolioAction {
        id: applyBtn
        visible: drawer.manual && drawer.searchable
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 14 * Theme.scale
        anchors.rightMargin: 14 * Theme.scale
        anchors.bottomMargin: 15 * Theme.scale
        label: I18n.tr("Apply")
        onTriggered: drawer.applyPressed()
    }
}
