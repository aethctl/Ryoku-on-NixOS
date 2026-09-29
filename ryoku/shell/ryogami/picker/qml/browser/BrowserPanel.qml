import QtQuick
import QtQuick.Effects
import Ryoku.Ui.Singletons

Item {
    id: panel

    required property PickerState state
    property var args: ({})
    property bool shown: false
    signal closeRequested()

    anchors.fill: parent
    focus: panel.shown

    property real ease: panel.shown ? 1 : 0
    Behavior on ease { NumberAnimation { duration: Theme.slow; easing.type: Easing.OutCubic } }
    visible: panel.ease > 0.001

    property var sourceData: BrowserSources { id: sourceData }

    property string provider: ""
    property string query: ""
    property var chipState: ({})
    property var stateCache: ({})
    property var providerTabs: []
    property var rpcProviders: null
    property var collections: []

    readonly property bool manual: panel.provider.length > 0
        && sourceData.showApplyButton(panel.provider, Settings)
    readonly property bool searchable: {
        var d = sourceData.descriptor(panel.provider)
        return d ? d.searchable !== false : true
    }
    readonly property string providerLabel: {
        for (var i = 0; i < panel.providerTabs.length; ++i)
            if (panel.providerTabs[i].id === panel.provider)
                return panel.providerTabs[i].label
        var d = sourceData.descriptor(panel.provider)
        return d ? d.label : panel.provider
    }

    property var pathMap: ({})
    property bool pendingApply: false
    property var applyItem: null
    property var applyingId: undefined
    property string steamUrl: ""
    property bool steamPromptOpen: false

    property bool previewOpen: false
    property int previewRow: -1
    property var previewItem: null
    property string previewFull: ""

    RemoteResults { id: remote }

    function _num(key, fb) { var v = Number(Settings.value(key)); return (isNaN(v) || v <= 0) ? fb : v }
    readonly property var grid: {
        if (panel.provider === "wallhaven")
            return { cols: _num("components.wallpaperSelector.wallhavenColumns", 6),
                     rows: _num("components.wallpaperSelector.wallhavenRows", 3),
                     tw: _num("components.wallpaperSelector.wallhavenThumbWidth", 300),
                     th: _num("components.wallpaperSelector.wallhavenThumbHeight", 169) }
        if (panel.provider === "steam")
            return { cols: _num("components.wallpaperSelector.steamColumns", 6),
                     rows: _num("components.wallpaperSelector.steamRows", 3),
                     tw: _num("components.wallpaperSelector.steamThumbWidth", 300),
                     th: _num("components.wallpaperSelector.steamThumbHeight", 169) }
        return { cols: _num("components.wallpaperSelector.gridColumns", 6), rows: 3, tw: 300, th: 169 }
    }
    readonly property real _s: Theme.scale
    readonly property real filterW: Math.max(238, Math.min(310, 282 * _s))
    readonly property real _gap: 8 * _s
    readonly property real _wsGap: 14 * _s
    readonly property real _readPadX: 48 * _s
    readonly property real _gridW: grid.cols * grid.tw * _s + (grid.cols - 1) * _gap
    readonly property real panelW: Math.min(Math.max(_gridW + filterW + _wsGap + _readPadX, 620 * _s),
                                            Math.max(220, panel.width - 24))
    readonly property real _gridHDesired: grid.rows * grid.th * _s + (grid.rows - 1) * _gap
    readonly property real panelH: Math.min(Math.max(_gridHDesired + 298 * _s, 500 * _s),
                                            Math.max(160, panel.height - 24))

    readonly property var cardPalette: ({
        primary: Theme.primary, accent: Theme.primary, primaryText: Theme.primaryText,
        surface: Theme.surface, surfaceVariant: Theme.surfaceVariant,
        surfaceContainer: Theme.surfaceContainer, background: Theme.background,
        outline: Theme.outline, text: Theme.surfaceText, shadow: Qt.rgba(0, 0, 0, 0.5)
    })

    function _artOf(row) {
        if (row < 0 || !remote || row >= remote.count) return ""
        var it = remote.get(row)
        return it && it.thumb ? it.thumb : ""
    }
    property string atmosphereArt: ""
    property string heroArt: ""
    function _refreshArt() {
        panel.atmosphereArt = panel._artOf(0)
        var r = results.field ? results.field.currentIndex : 0
        panel.heroArt = panel._artOf(r >= 0 ? r : 0)
    }

    function refreshProviders() {
        Daemon.call("source.providers", ({}), function(result, error) {
            panel.rpcProviders = (!error && result) ? result : null
            panel.rebuildTabs()
        })
        panel.rebuildTabs()
    }
    function rebuildTabs() {
        var rpc = panel.rpcProviders
        var byKey = ({})
        if (rpc)
            for (var i = 0; i < rpc.length; ++i) { var e = rpc[i]; byKey[e.key || e.id] = e }
        var out = []
        var seen = ({})
        for (var c = 0; c < sourceData.providers.length; ++c) {
            var d = sourceData.providers[c]
            var r = byKey[d.id]
            var av = sourceData.availability(d.id, Settings, r)
            out.push({ id: d.id, label: (r && r.label) ? r.label : d.label,
                       searchable: d.searchable, enabled: av.enabled, reason: av.reason })
            seen[d.id] = true
        }
        if (rpc)
            for (var j = 0; j < rpc.length; ++j) {
                var e2 = rpc[j]; var k = e2.key || e2.id
                if (seen[k]) continue
                var av2 = sourceData.availability(k, Settings, e2)
                out.push({ id: k, label: e2.label || k, searchable: e2.searchable !== false,
                           enabled: av2.enabled, reason: av2.reason })
                seen[k] = true
            }
        panel.providerTabs = out
    }

    function _tabEnabled(id) {
        for (var i = 0; i < panel.providerTabs.length; ++i)
            if (panel.providerTabs[i].id === id)
                return panel.providerTabs[i].enabled === true
        return false
    }

    function applyArgs() {
        var p = (panel.args && panel.args.provider && panel.args.provider.length > 0)
            ? panel.args.provider : (panel.provider.length > 0 ? panel.provider : "wallhaven")
        if (panel.args && panel.args.query !== undefined)
            panel.query = String(panel.args.query)
        panel.refreshProviders()
        panel.switchTo(p, true)
    }

    function switchTo(id, doSearch) {
        if (panel.provider.length > 0)
            panel.stateCache[panel.provider] = panel.chipState
        panel.provider = id
        panel.chipState = panel.stateCache[id] || sourceData.defaultState(id, Settings)
        panel.collections = []
        remote.provider = id
        if (id === "wallhaven")
            panel.loadCollections()
        if (doSearch)
            panel.runSearch()
    }

    function loadCollections() {
        var user = Settings.value("wallhaven.username")
        if (!user || String(user).length === 0)
            return
        Daemon.call("wallhaven.collections", { username: String(user) }, function(result, error) {
            if (!error && result)
                panel.collections = result
        })
    }

    function runSearch() {
        if (!Daemon.connected)
            return
        remote.provider = panel.provider
        remote.query = panel.query
        remote.filters = sourceData.buildFilters(panel.provider, panel.chipState, Settings)
        remote.search()
    }

    function onFilters(next) {
        panel.chipState = next
        if (!panel.manual)
            panel.runSearch()
    }

    function _youtubeClip(it) {
        var dur = it && it.durationSecs ? Number(it.durationSecs) : 0
        if (dur <= 0) return null
        var maxM = panel._num("sources.youtube.maxMinutes", 3)
        return { start: 0, dur: Math.min(dur, maxM * 60) }
    }
    function doDownload(row, clip) {
        if (clip)
            remote.download(row, { clip: clip })
        else
            remote.download(row)
    }
    function saveRow(row) {
        var it = remote.get(row)
        if (!it) return
        panel.doDownload(row, panel.provider === "youtube" ? panel._youtubeClip(it) : null)
    }
    function applyRow(row) {
        var it = remote.get(row)
        if (!it) return
        if (it.downloaded === true) {
            panel.performApply(it, panel.pathMap[String(it.id)])
            return
        }
        panel.applyingId = it.id
        panel.applyItem = it
        panel.pendingApply = true
        panel.saveRow(row)
    }
    function performApply(it, path) {
        var kind = it.type || "static"
        var outs = (Settings.value("general.applyOnPickerMonitor") === true && panel.state.monitor)
            ? [panel.state.monitor] : []
        var params = { outputs: outs }
        if (kind === "we") { params.type = "we"; params.we_id = it.id }
        else { params.type = (kind === "video") ? "video" : "static"; params.path = path || "" }
        Daemon.call("wall.apply", params, function(result, error) {
            if (error) {
                panel.state.toast(error.message || I18n.tr("This wallpaper could not be applied."), "error")
            } else {
                panel.state.toast(I18n.tr("Wallpaper applied."), "success")
                if (Settings.value("general.closeOnSelection") === true)
                    panel.closeRequested()
            }
        })
    }

    function openPreview(row) {
        panel.previewRow = row
        panel.previewItem = remote.get(row)
        panel.previewFull = ""
        panel.previewOpen = true
        remote.preview(row)
        preview.forceActiveFocus()
    }
    function closePreview() {
        panel.previewOpen = false
        panel.previewRow = -1
        panel.previewItem = null
        panel.previewFull = ""
        panel.forceActiveFocus()
    }

    function copyId(id) {
        clipHelper.text = String(id)
        clipHelper.selectAll()
        clipHelper.copy()
        panel.state.toast(I18n.tr("Workshop ID copied."), "success")
    }

    Connections {
        target: Daemon
        function onEvent(name, data) {
            if (name !== "ryogami.source.download" && name !== "ryogami.workshop.download")
                return
            if (!data) return
            var id = String(data.id)
            if (data.status === "done" && data.path)
                panel.pathMap[id] = data.path
            if ((data.status === "error" || data.status === "auth_error")) {
                if (panel.applyingId !== undefined && String(panel.applyingId) === id) {
                    panel.pendingApply = false
                    panel.applyingId = undefined
                }
                if (data.error === "cancelled")
                    panel.state.toast(I18n.tr("Download cancelled."), "info")
                else
                    panel.state.toast(data.error || data.message || I18n.tr("That download failed."), "error")
            }
            if (data.status === "done" && panel.pendingApply
                    && panel.applyingId !== undefined && String(panel.applyingId) === id) {
                var it = panel.applyItem
                panel.pendingApply = false
                panel.applyingId = undefined
                panel.performApply(it, data.path)
            }
        }
        function onReconnected() { if (panel.shown) panel.runSearch() }
        function onConnectedChanged() { if (panel.shown && Daemon.connected && remote.count === 0) panel.runSearch() }
    }
    Connections {
        target: remote
        ignoreUnknownSignals: true
        // The preview holds a copy of its row; refresh it as downloads move it along.
        function onDataChanged(topLeft, bottomRight, roles) {
            if (panel.previewOpen && panel.previewRow >= topLeft.row && panel.previewRow <= bottomRight.row)
                panel.previewItem = remote.get(panel.previewRow)
        }
        function onOpenInSteam(id, url) {
            panel.steamUrl = url
            panel.steamPromptOpen = true
            if (panel.applyingId !== undefined && String(panel.applyingId) === String(id)) {
                panel.pendingApply = false
                panel.applyingId = undefined
            }
        }
        function onPreviewReady(id, path) {
            if (panel.previewItem && String(panel.previewItem.id) === String(id))
                panel.previewFull = path
        }
        function onCountChanged() {
            panel._refreshArt()
            if (panel.shown && !panel.previewOpen && remote.count > 0
                    && results.field && results.field.visible && !drawer.searchEditing)
                results.field.forceActiveFocus()
        }
    }
    Connections {
        target: results.field
        ignoreUnknownSignals: true
        function onCurrentIndexChanged() { panel._refreshArt() }
    }
    Connections {
        target: Settings
        ignoreUnknownSignals: true
        function onChanged(key, value) { if (String(key).indexOf("sources.") === 0 || String(key).indexOf("features.") === 0) panel.rebuildTabs() }
    }

    onShownChanged: {
        if (panel.shown) {
            panel.applyArgs()
            panel.forceActiveFocus()
        } else {
            panel.previewOpen = false
            panel.steamPromptOpen = false
        }
    }
    onArgsChanged: if (panel.shown) panel.applyArgs()

    Scrim {
        anchors.fill: parent
        alpha: 0.68
        reveal: panel.ease
        onDismissed: panel.closeRequested()
    }

    Item {
        anchors.centerIn: parent
        width: panel.panelW
        height: panel.panelH
        transform: Translate { y: (1 - panel.ease) * 38 * panel._s }

        RectangularShadow {
            anchors.fill: sheet
            offset.y: 16 * panel._s
            blur: 48 * panel._s
            color: Qt.rgba(0, 0, 0, 0.58)
            opacity: panel.ease
            cached: true
        }

        Rectangle {
            id: sheet
            anchors.fill: parent
            clip: true
            color: Theme.withAlpha(Theme.surface, 0.985 * panel.ease)
            border.width: 1
            border.color: Theme.withAlpha(Theme.outline, 0.58 * panel.ease)

            Image {
                anchors.fill: parent
                visible: panel.atmosphereArt.length > 0
                source: panel.atmosphereArt
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: false
                opacity: 0.055 * panel.ease
            }
            Rectangle {
                anchors.fill: parent
                color: Theme.withAlpha(Theme.surface, 0.92 * panel.ease)
            }

            Column {
                anchors.fill: parent
                spacing: 0

                FolioMasthead {
                    width: parent.width
                    reveal: panel.ease
                    breadcrumb: I18n.tr("Sources  /  %1  \u00b7  %2  \u00b7  page %3")
                        .arg(panel.providerLabel)
                        .arg(I18n.tr("%1 results").arg(remote.count))
                        .arg(remote.page)
                    onCloseRequested: panel.closeRequested()
                }

                BrowserTabs {
                    id: tabs
                    width: parent.width
                    reveal: panel.ease
                    tabs: panel.providerTabs
                    current: panel.provider
                    onSelected: function(id) { if (panel._tabEnabled(id)) panel.switchTo(id, true) }
                }

                Item {
                    width: parent.width
                    height: parent.height - y

                    Column {
                        anchors.fill: parent
                        anchors.topMargin: 16 * panel._s
                        anchors.rightMargin: 24 * panel._s
                        anchors.bottomMargin: 22 * panel._s
                        anchors.leftMargin: 24 * panel._s
                        spacing: 14 * panel._s

                        BrowserHero {
                            width: parent.width
                            reveal: panel.ease
                            sourceLabel: panel.providerLabel
                            count: remote.count
                            page: remote.page
                            artSource: panel.heroArt
                        }

                        Row {
                            width: parent.width
                            height: parent.height - y
                            spacing: panel._wsGap

                            BrowserDrawer {
                                id: drawer
                                width: panel.filterW
                                height: parent.height
                                provider: panel.provider
                                providerLabel: panel.providerLabel
                                sources: sourceData
                                state: panel.chipState
                                collections: panel.collections
                                searchable: panel.searchable
                                manual: panel.manual
                                query: panel.query
                                reveal: panel.ease
                                onQueryEdited: function(t) { panel.query = t }
                                onSearchSubmitted: function(t) { panel.query = t; panel.runSearch() }
                                onFiltersChanged: function(next) { panel.onFilters(next) }
                                onApplyPressed: panel.runSearch()
                            }

                            BrowserResults {
                                id: results
                                width: parent.width - panel.filterW - panel._wsGap
                                height: parent.height
                                source: remote
                                settings: Settings
                                sources: sourceData
                                provider: panel.provider
                                sourceLabel: panel.providerLabel
                                columns: panel.grid.cols
                                showApply: panel.manual
                                palette: panel.cardPalette
                                reveal: panel.ease
                                pendingApply: panel.pendingApply
                                applyItem: panel.applyItem
                                applyingId: panel.applyingId
                                onPreviewRequested: function(row) { panel.openPreview(row) }
                                onDownloadRequested: function(row) { panel.saveRow(row) }
                                onApplyRequested: function(row) { panel.applyRow(row) }
                                cancellable: panel.provider !== "steam"
                                onCancelRequested: function(row) { remote.cancelDownload(row) }
                            }
                        }
                    }
                }
            }
        }
    }

    BrowserPreview {
        id: preview
        anchors.fill: parent
        shown: panel.previewOpen
        item: panel.previewItem
        provider: panel.provider
        fullPath: panel.previewFull
        showApply: panel.manual
        applying: panel.applyingId !== undefined && panel.previewItem
            && String(panel.applyingId) === String(panel.previewItem.id)
        maxMinutes: panel._num("sources.youtube.maxMinutes", 3)
        sources: sourceData
        onCloseRequested: panel.closePreview()
        onCopyId: function(id) { panel.copyId(id) }
        onSave: {
            if (panel.previewRow < 0) return
            var clip = (panel.provider === "youtube")
                ? { start: preview.clipStartSecs, dur: preview.clipLenSecs } : null
            panel.doDownload(panel.previewRow, clip)
        }
        onApply: if (panel.previewRow >= 0) panel.applyRow(panel.previewRow)
        cancellable: panel.provider !== "steam"
        onCancel: if (panel.previewRow >= 0) remote.cancelDownload(panel.previewRow)
    }

    Item {
        anchors.fill: parent
        visible: panel.steamPromptOpen

        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.6)
            MouseArea { anchors.fill: parent; onClicked: panel.steamPromptOpen = false }
        }
        ChamferPanel {
            anchors.centerIn: parent
            width: Math.min(460 * panel._s, panel.width - 60 * panel._s)
            height: promptCol.implicitHeight + 44 * panel._s

            Column {
                id: promptCol
                anchors.centerIn: parent
                width: parent.width - 44 * panel._s
                spacing: 14 * panel._s

                Text {
                    width: parent.width
                    text: I18n.tr("This item downloads through Steam")
                    font.family: Theme.ui; font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fontHead
                    color: Theme.surfaceText
                    renderType: Text.NativeRendering
                }
                Text {
                    width: parent.width
                    wrapMode: Text.WordWrap
                    text: I18n.tr("Steam will subscribe and download it. It appears in your library automatically once Steam finishes.")
                    font.family: Theme.ui; font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fontBody
                    color: Theme.withAlpha(Theme.surfaceText, 0.7)
                    renderType: Text.NativeRendering
                }
                Row {
                    anchors.right: parent.right
                    spacing: 10 * panel._s
                    FolioAction {
                        label: I18n.tr("Dismiss")
                        onTriggered: panel.steamPromptOpen = false
                    }
                    FolioAction {
                        label: I18n.tr("Open in Steam")
                        active: true
                        enabled: panel.steamUrl.length > 0
                        onTriggered: {
                            if (panel.steamUrl.length > 0)
                                Qt.openUrlExternally(panel.steamUrl)
                            panel.steamPromptOpen = false
                        }
                    }
                }
            }
        }
    }

    // Off-screen helper that puts the Workshop ID on the clipboard.
    TextEdit { id: clipHelper; visible: false }

    Keys.onPressed: function(event) {
        if (event.key === Qt.Key_Escape) {
            if (panel.steamPromptOpen) { panel.steamPromptOpen = false; event.accepted = true; return }
            if (panel.previewOpen) { panel.closePreview(); event.accepted = true; return }
            panel.closeRequested()
            event.accepted = true
        } else if (event.key >= Qt.Key_1 && event.key <= Qt.Key_6
                   && !(event.modifiers & Qt.ControlModifier)) {
            var idx = event.key - Qt.Key_1
            if (idx < sourceData.providers.length) {
                var id = sourceData.providers[idx].id
                if (panel._tabEnabled(id) && id !== panel.provider)
                    panel.switchTo(id, true)
                event.accepted = true
            }
        }
    }
}
