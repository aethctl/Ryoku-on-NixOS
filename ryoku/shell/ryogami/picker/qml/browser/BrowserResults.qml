import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: results

    property var source: null          // RemoteResults
    property var settings: null
    property var sources: null         // BrowserSources
    property string provider: ""
    property string sourceLabel: ""
    property int columns: 6
    property bool showApply: false
    property var palette: ({})
    property real reveal: 1
    property bool cancellable: false

    property bool pendingApply: false
    property var applyItem: null
    property var applyingId: undefined

    signal previewRequested(int row)
    signal downloadRequested(int row)
    signal applyRequested(int row)
    signal cancelRequested(int row)

    readonly property alias field: cardField

    property int active: 0
    property int queued: 0
    property var activeItem: null
    property var queuedItem: null

    function recount() {
        if (!results.source || !results.sources) return
        var a = 0, q = 0, ai = null, qi = null
        var n = results.source.count
        for (var i = 0; i < n; ++i) {
            var it = results.source.get(i)
            if (!it) continue
            if (results.sources.isQueued(it)) { q++; if (!qi) qi = it }
            else if (results.sources.isDownloading(it)) { a++; if (!ai) ai = it }
        }
        results.active = a; results.queued = q
        results.activeItem = ai; results.queuedItem = qi
    }

    Connections {
        target: results.source
        ignoreUnknownSignals: true
        function onCountChanged() { results.recount(); results._maybePage() }
        function onLoadingChanged() { results.recount() }
        // The model applies each download event before announcing the row, so read it here.
        function onDataChanged(topLeft, bottomRight, roles) {
            results.recount()
            if (actions.row >= topLeft.row && actions.row <= bottomRight.row)
                actions.refreshItem()
        }
    }

    function _maybePage() {
        var s = results.source
        if (!s || s.loading) return
        if (s.page >= s.lastPage) return
        var end = cardField.visibleEnd
        var probe = (end !== undefined) ? end : cardField.currentIndex
        if (probe + 8 >= s.count)
            s.nextPage()
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.background, 0.34)
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, 0.24)
        clip: true

        BrowserStatus {
            id: strip
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            sources: results.sources
            error: results.source ? results.source.error : ""
            loading: results.source ? results.source.loading : false
            sourceLabel: results.sourceLabel
            count: results.source ? results.source.count : 0
            pendingApply: results.pendingApply
            applyItem: results.applyItem
            active: results.active
            queued: results.queued
            activeItem: results.activeItem
            queuedItem: results.queuedItem
        }

        Item {
            id: gridArea
            anchors.top: strip.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            CardField {
                id: cardField
                anchors.fill: parent
                source: results.source
                settings: results.settings
                mode: "wall"
                columns: results.columns
                palette: results.palette
                interactive: true
                active: results.visible && (results.source ? results.source.count > 0 : false)
                visible: results.source ? results.source.count > 0 : false

                onActivated: function(row) { results.previewRequested(row) }
            }

            Item {
                id: actionAnchor
                property int row: actions.row
                property rect box: (actions.row >= 0 && cardField.visible)
                    ? cardField.rectOf(actions.row)
                    : Qt.rect(0, 0, 0, 0)
                x: box.x
                y: box.y
                width: box.width
                height: box.height
                visible: actions.row >= 0 && width > 0 && height > 0

                BrowserCardActions {
                    id: actions
                    anchors.fill: parent
                    property int row: -1
                    function refreshItem() {
                        item = (row >= 0 && results.source) ? results.source.get(row) : null
                    }
                    sources: results.sources
                    showApply: results.showApply
                    applying: results.applyingId !== undefined && !!item
                        && String(results.applyingId) === String(item.id)
                    reveal: results.reveal
                    cancellable: results.cancellable
                    onSave: if (row >= 0) results.downloadRequested(row)
                    onApply: if (row >= 0) results.applyRequested(row)
                    onCancel: if (row >= 0) results.cancelRequested(row)
                }
            }

            Connections {
                target: cardField
                ignoreUnknownSignals: true
                function onHoveredIndexChanged() {
                    if (cardField.hoveredIndex >= 0) {
                        actions.row = cardField.hoveredIndex
                        actions.refreshItem()
                    } else if (!actions.hovering) {
                        actions.row = -1
                        actions.item = null
                    }
                }
                function onCurrentIndexChanged() { results._maybePage() }
                function onVisibleEndChanged() { results._maybePage() }
            }
            Connections {
                target: actions
                function onHoveringChanged() {
                    if (!actions.hovering && cardField.hoveredIndex < 0) {
                        actions.row = -1
                        actions.item = null
                    }
                }
            }
        }

        BrowserSpinner {
            anchors.centerIn: parent
            visible: results.source ? (results.source.loading && results.source.count === 0) : false
            size: 90
            color: Theme.primary
        }
        Text {
            anchors.centerIn: parent
            width: parent.width - 40 * Theme.scale
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: results.source
                ? (!results.source.loading && results.source.count === 0)
                : true
            text: (results.source && results.source.error && results.source.error.length > 0)
                ? results.source.error
                : I18n.tr("No remote wallpapers found")
            font.family: Theme.ui
            font.weight: Theme.uiWeight
            font.pixelSize: Theme.fontLabel
            color: Theme.withAlpha(Theme.surfaceText, 0.4)
            renderType: Text.NativeRendering
        }
    }
}
