import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: root

    required property PickerState state
    readonly property LibraryView view: root.state ? root.state.view : null

    // A cheap stamp so settings-driven bindings re-evaluate without one SettingValue per key.
    property int settingsRev: 0
    Connections {
        target: Settings
        function onChanged(key, value) { root.settingsRev++ }
    }
    function val(key, def) {
        root.settingsRev
        var v = Settings.value(key)
        return (v === undefined || v === null) ? def : v
    }
    function show(key) { return root.val(key, true) !== false }

    readonly property string barStyle: {
        root.settingsRev
        var vs = root.val("filterBar.visualStyle", "match")
        if (vs === "slices") return "slices"
        if (vs === "hex") return "geometric"
        if (vs === "wall") return "straight"
        var m = root.state ? root.state.mode : "slices"
        if (m === "hex") return "geometric"
        if (m === "wall" || m === "grid" || m === "collection") return "straight"
        return "slices"
    }

    readonly property CardField field: root.state ? root.state.field : null
    readonly property string mode: root.state ? root.state.mode : "slices"
    // Sandy keeps its bar along the bottom edge and never turns it vertical.
    readonly property bool menuUp: root.mode === "sandy"
    readonly property bool vertical: root.val("filterBar.orientation", "horizontal") === "vertical" && !root.menuUp
    readonly property rect stage: root.field ? root.field.stageRect : Qt.rect(0, 0, root.width, root.height)
    readonly property real gap: 8 * Theme.scale
    readonly property real offX: Number(root.val("filterBar.offsetX", 0))
    readonly property real offY: Number(root.val("filterBar.offsetY", 0))
    readonly property bool muted: root.val("wallpaperMute", true) === true
    readonly property bool audioActive: {
        var outs = Library.outputs || []
        for (var i = 0; i < outs.length; ++i) {
            var t = outs[i].current ? outs[i].current.type : ""
            if (t === "video" || t === "we")
                return true
        }
        return false
    }

    readonly property bool revealed: (root.state ? root.state.filterBarShown : false)
        && !(root.field && root.field.flippedIndex >= 0)
    opacity: root.revealed ? 1 : 0
    Behavior on opacity { NumberAnimation { duration: Theme.standard; easing.type: Theme.revealEasing } }

    // Children the Flow actually lays out: positioners skip hidden and zero-sized items.
    function laidOut(c) { return c.visible && c.width > 0 && c.height > 0 }
    readonly property real naturalExtent: {
        var total = 0
        var n = 0
        for (var i = 0; i < bar.children.length; ++i) {
            var c = bar.children[i]
            if (!root.laidOut(c)) continue
            total += root.vertical ? c.height : c.width
            n++
        }
        return Math.ceil(total + Math.max(n - 1, 0) * bar.spacing)
    }
    // skwd's vertical rail: every item takes the widest one's width, at least 84.
    readonly property real rail: {
        if (!root.vertical) return 0
        var w = 84 * Theme.scale
        for (var i = 0; i < bar.children.length; ++i) {
            var c = bar.children[i]
            if (c.visible)
                w = Math.max(w, c.naturalWidth !== undefined ? c.naturalWidth : c.implicitWidth)
        }
        return Math.ceil(w)
    }
    readonly property size used: {
        var r = 0
        var b = 0
        for (var i = 0; i < bar.children.length; ++i) {
            var c = bar.children[i]
            if (!root.laidOut(c)) continue
            r = Math.max(r, c.x + c.width)
            b = Math.max(b, c.y + c.height)
        }
        return Qt.size(r, b)
    }

    readonly property real barX: {
        if (root.vertical && root.mode === "wall")
            return Math.max(root.stage.x - root.gap - root.used.width + root.offX, 0)
        if (root.vertical)
            return Math.max(16 + root.offX, 0)
        return Math.max((root.width - root.used.width) * 0.5 + root.offX, 0)
    }
    readonly property real barY: {
        if (root.menuUp)
            return Math.max(root.height - 12 - root.used.height + root.offY, 0)
        if (root.vertical && root.mode === "wall")
            return Math.max(root.stage.y + root.offY, 0)
        if (root.vertical)
            return Math.max((root.height - root.used.height) * 0.5 + root.offY, 0)
        if (root.mode === "wall")
            return Math.max(root.stage.y - root.gap - root.used.height + root.offY, 0)
        return Math.max(root.stage.y + 13 + root.offY, 0)
    }

    // The wall grid and the bar centre as one group while the bar shows over the scene.
    readonly property bool obscured: root.state !== null && root.state.sheet !== "" && !root.state.sceneThrough
    Binding {
        when: root.field !== null
        target: root.field
        property: "barReserve"
        value: root.revealed && !root.obscured
            ? Qt.size(root.used.width + root.gap, root.used.height + root.gap)
            : Qt.size(0, 0)
    }
    Binding {
        when: root.field !== null
        target: root.field
        property: "barVertical"
        value: root.vertical
    }

    property bool rotationActive: false
    function refreshRotation() {
        Daemon.call("wall.rotation_status", {}, function (r, e) {
            if (r) root.rotationActive = r.active === true
        })
    }
    Connections {
        target: Daemon
        function onEvent(name, data) {
            if (name === "ryogami.wall.random_started") root.rotationActive = true
            else if (name === "ryogami.wall.random_stopped") root.rotationActive = false
        }
        function onReconnected() { root.refreshRotation() }
    }
    function toggleRotation() {
        if (root.rotationActive) { Daemon.call("wall.rotation_stop", {}, function () {}); return }
        var types = []
        if (root.val("general.randomIncludeStatic", true) === true) types.push("static")
        if (root.val("general.randomIncludeVideo", true) === true) types.push("video")
        if (root.val("general.randomIncludeWE", true) === true) types.push("we")
        if (types.length === 0) {
            if (root.state) root.state.toast(I18n.tr("Select at least one random source category in settings"), "error")
            return
        }
        Daemon.call("wall.random_start", {
            interval: Number(root.val("general.randomInterval", 300)),
            types: types,
            favourites_only: root.val("general.randomIncludeFavourites", false) === true
        }, function () {})
    }

    // The library filters on wide/tall; the remote browser's landscape/portrait belong to a
    // different view and never matched, so the Shape button relabelled without filtering.
    function cycleShape() {
        if (!root.view) return
        var o = root.view.orientation
        root.view.orientation = (o === "" || o === undefined) ? "wide"
                              : (o === "wide") ? "tall" : ""
    }
    function shapeLabel() {
        if (!root.view) return I18n.tr("Shape")
        var o = root.view.orientation
        return (o === "wide") ? I18n.tr("Wide")
             : (o === "tall") ? I18n.tr("Tall") : I18n.tr("Shape")
    }

    property int resIndex: -1
    function resPresets() {
        var p = root.val("filterBar.resolutionPresets", [])
        return Array.isArray(p) ? p : []
    }
    function cycleResolution() {
        if (!root.view) return
        var presets = root.resPresets()
        if (presets.length === 0) return
        root.resIndex = root.resIndex + 1
        if (root.resIndex >= presets.length) {
            root.resIndex = -1
            root.view.minWidth = 0; root.view.minHeight = 0
            root.view.maxWidth = 0; root.view.maxHeight = 0
            return
        }
        var p = presets[root.resIndex]
        root.view.minWidth = Number(p.minWidth) || 0
        root.view.minHeight = Number(p.minHeight) || 0
        root.view.maxWidth = Number(p.maxWidth) || 0
        root.view.maxHeight = Number(p.maxHeight) || 0
        if (p.orientation === "wide") root.view.orientation = "wide"
        else if (p.orientation === "tall") root.view.orientation = "tall"
    }
    function resLabel() {
        var presets = root.resPresets()
        if (root.resIndex >= 0 && root.resIndex < presets.length && presets[root.resIndex].label)
            return presets[root.resIndex].label
        return I18n.tr("Size")
    }

    function setThemeMode(mode) {
        Settings.set("theme.mode", mode)
    }

    readonly property bool sticky: root.val("filterBar.sticky", false) === true
    property bool _restoring: false
    function save(name, value) {
        if (root._restoring || !root.sticky) return
        Daemon.call("state.set", { key: "filterBar.last." + name, value: String(value) }, function () {})
    }
    property bool _initialized: false
    function applyInitial() {
        if (!root.view || root._initialized) return
        root._initialized = true
        if (root.sticky) {
            root._restoring = true
            var v = root.view
            Daemon.call("state.get", { key: "filterBar.last.type" }, function (r) { if (r && r.value !== null && r.value !== undefined) v.typeFilter = r.value })
            Daemon.call("state.get", { key: "filterBar.last.folder" }, function (r) { if (r && r.value !== null && r.value !== undefined) v.folder = r.value })
            Daemon.call("state.get", { key: "filterBar.last.color" }, function (r) { if (r && r.value !== null && r.value !== undefined) v.hueFilter = parseInt(r.value) })
            Daemon.call("state.get", { key: "filterBar.last.sort" }, function (r) { if (r && r.value !== null && r.value !== undefined && r.value !== "") v.sort = r.value })
            Daemon.call("state.get", { key: "filterBar.last.favourites" }, function (r) {
                if (r && r.value !== null && r.value !== undefined) v.favouritesOnly = (r.value === "1" || r.value === "true")
                root._restoring = false
            })
        } else {
            root.view.folder = root.val("filterBar.defaultFolder", "*")
        }
    }
    Component.onCompleted: { root.refreshRotation(); root.applyInitial() }
    onViewChanged: root.applyInitial()

    Connections {
        target: root.view
        ignoreUnknownSignals: true
        function onTypeFilterChanged() { root.save("type", root.view.typeFilter) }
        function onFolderChanged() { root.save("folder", root.view.folder) }
        function onHueFilterChanged() { root.save("color", root.view.hueFilter) }
        function onSortChanged() { root.save("sort", root.view.sort) }
        function onFavouritesOnlyChanged() { root.save("favourites", root.view.favouritesOnly ? "1" : "0") }
    }

    readonly property var typeModel: [
        { value: "", label: I18n.tr("All"), key: "filterBar.show.type.all" },
        { value: "static", label: I18n.tr("PIC"), key: "filterBar.show.type.static" },
        { value: "video", label: I18n.tr("VID"), key: "filterBar.show.type.video" },
        { value: "we", label: I18n.tr("WE"), key: "filterBar.show.type.we" }
    ]
    readonly property var sortModel: [
        { value: "date", glyph: "\u{f00f0}", label: I18n.tr("Newest"), key: "filterBar.show.sort.date" },
        { value: "recent", glyph: "\u{f02da}", label: I18n.tr("Recently applied"), key: "filterBar.show.sort.recent" },
        { value: "color", glyph: "\u{f03d8}", label: I18n.tr("Default (by colour)"), key: "filterBar.show.sort.color" },
        { value: "pop", glyph: "\u{f0238}", label: I18n.tr("Colour pop"), key: "filterBar.show.sort.pop" },
        { value: "richness", glyph: "\u{f0b74}", label: I18n.tr("Colourful"), key: "filterBar.show.sort.richness" },
        { value: "minimalist", glyph: "\u{f0764}", label: I18n.tr("Minimalist"), key: "filterBar.show.sort.minimalist" },
        { value: "res", glyph: "\u{f0a24}", label: I18n.tr("Highest resolution"), key: "filterBar.show.sort.res" }
    ]

    // Wraps like skwd: into rows past the viewport width, into columns past its height.
    Flow {
        id: bar
        x: root.barX
        y: root.barY
        width: root.vertical ? implicitWidth : Math.min(root.naturalExtent, root.width - 24)
        height: root.vertical ? Math.min(root.naturalExtent, root.height - 32) : implicitHeight
        enabled: root.revealed
        flow: root.vertical ? Flow.TopToBottom : Flow.LeftToRight
        spacing: (root.vertical ? 3 : 4) * Theme.scale

        CollectionTabs {
            state: root.state
            barStyle: root.barStyle
            railWidth: root.rail
        }

        Item {
            readonly property real naturalWidth: 0
            width: root.vertical ? root.rail : 9 * Theme.scale
            height: root.vertical ? 9 * Theme.scale : 26 * Theme.scale
            Rectangle {
                anchors.centerIn: parent
                width: root.vertical ? root.rail - 16 * Theme.scale : 1
                height: root.vertical ? 1 : 22 * Theme.scale
                color: Theme.withAlpha(Theme.outline, 0.3)
            }
        }

        Repeater {
            model: root.typeModel
            delegate: BarButton {
                required property var modelData
                visible: root.show(modelData.key)
                barStyle: root.barStyle
                railWidth: root.rail
                label: modelData.label
                active: root.view && root.view.typeFilter === modelData.value
                onTriggered: {
                    if (!root.view) return
                    root.view.typeFilter = (root.view.typeFilter === modelData.value && modelData.value !== "") ? "" : modelData.value
                }
            }
        }

        FolderMenu {
            visible: root.show("filterBar.show.folder") && root.view && (root.view.collection === "wallpapers" || root.view.collection === "workshop")
            view: root.view
            barStyle: root.barStyle
            railWidth: root.rail
            menuUp: root.menuUp
        }

        Repeater {
            model: root.sortModel
            delegate: BarButton {
                required property var modelData
                visible: root.show(modelData.key)
                barStyle: root.barStyle
                railWidth: root.rail
                glyph: modelData.glyph
                tooltip: modelData.label
                active: root.view && root.view.sort === modelData.value
                onTriggered: if (root.view) root.view.sort = modelData.value
            }
        }

        BarButton {
            visible: root.show("filterBar.show.favourites")
            barStyle: root.barStyle
            railWidth: root.rail
            glyph: "\u{f02d1}"
            tooltip: I18n.tr("Favourites")
            active: root.view && root.view.favouritesOnly
            onTriggered: if (root.view) root.view.favouritesOnly = !root.view.favouritesOnly
        }

        BarButton {
            visible: root.show("filterBar.show.random")
            barStyle: root.barStyle
            railWidth: root.rail
            glyph: "\u{f049d}"
            tooltip: root.rotationActive
                ? I18n.tr("Stop auto-rotate")
                : I18n.tr("Auto-rotate: continuous random wallpapers")
            active: root.rotationActive
            onTriggered: root.toggleRotation()
        }

        Item {
            visible: root.show("filterBar.show.colors")
            readonly property real naturalWidth: 84 * Theme.scale
            width: root.vertical ? root.rail : sw.implicitWidth
            height: (root.vertical ? 24 : 26) * Theme.scale
            BarSwatches {
                id: sw
                anchors.centerIn: parent
                view: root.view
                stripWidth: root.vertical ? 84 * Theme.scale : 0
            }
        }

        BarButton {
            visible: root.show("filterBar.show.theme")
            barStyle: root.barStyle
            railWidth: root.rail
            glyph: "\u{f0599}"
            label: I18n.tr("Light")
            active: root.val("theme.mode", "dark") === "light"
            onTriggered: root.setThemeMode("light")
        }
        BarButton {
            visible: root.show("filterBar.show.theme")
            barStyle: root.barStyle
            railWidth: root.rail
            glyph: "\u{f0594}"
            label: I18n.tr("Dark")
            active: root.val("theme.mode", "dark") === "dark"
            onTriggered: root.setThemeMode("dark")
        }

        BarButton {
            visible: root.show("filterBar.show.tagcloud")
            barStyle: root.barStyle
            railWidth: root.rail
            glyph: "\u{f0349}"
            tooltip: I18n.tr("Search")
            active: root.state && root.state.searchOpen
            onTriggered: if (root.state) root.state.searchOpen = !root.state.searchOpen
        }

        BarButton {
            visible: root.show("filterBar.show.orient")
            barStyle: root.barStyle
            railWidth: root.rail
            glyph: "\u{f065f}"
            label: root.shapeLabel()
            active: root.view && root.view.orientation !== "" && root.view.orientation !== undefined
            onTriggered: root.cycleShape()
        }

        BarButton {
            visible: root.show("filterBar.show.resolution") && root.resPresets().length > 0
            barStyle: root.barStyle
            railWidth: root.rail
            glyph: "\u{f0a24}"
            label: root.resLabel()
            active: root.resIndex >= 0
            onTriggered: root.cycleResolution()
        }

        Item {
            visible: root.view !== null
            readonly property real naturalWidth: cnt.implicitWidth
            width: root.vertical ? root.rail : cnt.implicitWidth
            height: (root.vertical ? 24 : 26) * Theme.scale
            Row {
                id: cnt
                anchors.centerIn: parent
                spacing: 4 * Theme.scale
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{f0b38}"
                    font.family: Theme.icon
                    font.pixelSize: Theme.fontSmall
                    color: Theme.withAlpha(Theme.surfaceText, 0.55)
                    renderType: Text.NativeRendering
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.view ? String(root.view.count) : "0"
                    font.family: Theme.ui
                    font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fontSmall
                    color: Theme.withAlpha(Theme.surfaceText, 0.7)
                    renderType: Text.NativeRendering
                }
            }
        }

        BarButton {
            visible: root.show("filterBar.show.playlists")
            barStyle: root.barStyle
            railWidth: root.rail
            glyph: "\u{f0cb8}"
            tooltip: I18n.tr("Playlists")
            active: root.state && root.state.sheet === "playlists"
            onTriggered: if (root.state) root.state.openSheet("playlists", undefined)
        }

        // Shown while a display plays a video or scene, the only wallpapers with sound.
        BarButton {
            visible: root.audioActive
            barStyle: root.barStyle
            railWidth: root.rail
            glyph: root.muted ? "\u{f075f}" : "\u{f057e}"
            tooltip: root.muted ? I18n.tr("Unmute wallpapers") : I18n.tr("Mute wallpapers")
            active: !root.muted
            onTriggered: Settings.set("wallpaperMute", !root.muted)
        }
        BarButton {
            visible: root.audioActive
            barStyle: root.barStyle
            railWidth: root.rail
            glyph: "\u{f062e}"
            tooltip: I18n.tr("Audio mixer")
            active: root.state && root.state.sheet === "audio"
            onTriggered: if (root.state) root.state.openSheet("audio", undefined)
        }

        DownloadMenu {
            visible: root.show("filterBar.show.download")
            state: root.state
            barStyle: root.barStyle
            railWidth: root.rail
            menuUp: root.menuUp
        }

        BarButton {
            barStyle: root.barStyle
            railWidth: root.rail
            glyph: "\u{f0493}"
            tooltip: I18n.tr("Settings")
            active: root.state && root.state.sheet === "settings"
            onTriggered: if (root.state) root.state.openSheet("settings", undefined)
        }

        Repeater {
            model: Tasks.bar
            delegate: TaskChip {
                required property var modelData
                task: modelData
                barStyle: root.barStyle
                railWidth: root.rail
            }
        }
    }
}
