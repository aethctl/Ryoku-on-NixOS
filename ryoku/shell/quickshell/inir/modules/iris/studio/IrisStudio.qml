pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import inir
import inir.services
import inir.modules.common
import inir.modules.common.widgets
import inir.modules.iris.frame
import inir.modules.iris.components
import inir.modules.iris.settings
import inir.modules.iris.style
import inir.modules.iris.preview

PanelWindow {
    id: root
    readonly property real d: IrisStyle.density
    property string target: "material"

    readonly property var targets: [
        { id: "material", label: "Material", glyph: "layers" },
        { id: "colour", label: "Colour", glyph: "palette" },
        { id: "type", label: "Type", glyph: "text_fields" },
        { id: "motion", label: "Motion", glyph: "animation" },
        { id: "island", label: "Island", glyph: "pill" },
        { id: "pieces", label: "Pieces", glyph: "bubble_chart" },
        { id: "bodies", label: "Bodies", glyph: "web_asset" },
        { id: "places", label: "Places", glyph: "space_dashboard" },
        { id: "transients", label: "Feedback", glyph: "notifications" },
        { id: "dock", label: "Dock", glyph: "dock_to_bottom" },
        { id: "desktop", label: "Desktop", glyph: "widgets" },
        { id: "themes", label: "Themes", glyph: "style" }
    ]
    readonly property var presetOrder: ["iris", "soft", "round", "crisp", "angular", "contrast"]

    readonly property var specifications: IrisOptions.studio
    function shown(spec: var): bool {
        if (!IrisOptions.availableIn(spec)) return false
        const when = String(spec.visibleWhen ?? "")
        if (when.length === 0) return true
        if (when.includes("=")) return String(Config.getNestedValue(when.split("=")[0], "")) === when.split("=")[1]
        const negated = when.startsWith("!")
        const on = Boolean(Config.getNestedValue(negated ? when.slice(1) : when, false))
        return negated ? !on : on
    }
    function hasContent(id: string): bool {
        if (id === "themes") return true
        void Config.revision
        for (const spec of root.specifications)
            if (spec.target === id && root.shown(spec)) return true
        return false
    }
    readonly property var groups: {
        Config.revision
        const out = []
        for (const spec of root.specifications) {
            if (spec.target !== root.target || !root.shown(spec)) continue
            if (out.length === 0 || out[out.length - 1].title !== spec.group) out.push({ title: spec.group, rows: [] })
            out[out.length - 1].rows.push(spec)
        }
        return out
    }

    function fallbackOf(path: string): var {
        const owned = IrisThemes.paths.find(entry => entry.path === path)
        if (owned) return owned.fallback
        return root.specifications.find(spec => spec.path === path)?.fallback
    }
    property string notice: ""
    Timer { id: noticeTimer; interval: 2400; onTriggered: root.notice = "" }
    function say(text: string): void { root.notice = text; noticeTimer.restart() }
    function applyTheme(theme: var): void {
        IrisThemes.apply(theme)
        root.say(Translation.tr("Applied %1").arg(theme.name))
    }
    function saveTheme(name: string): void {
        IrisThemes.save(name, "")
        root.say(Translation.tr("Saved as a theme"))
    }
    function shareTheme(theme: var): void {
        Quickshell.clipboardText = IrisThemes.exportText(theme)
        root.say(Translation.tr("Copied “%1” — paste it anywhere to share it").arg(theme.name))
    }
    function shareCurrent(): void {
        const theme = { id: IrisThemes.slug(IrisThemes.active?.name ?? "my-theme"), name: IrisThemes.active?.name ?? Translation.tr("My theme"),
            author: Quickshell.env("USER") ?? "", description: "", values: IrisThemes.differences(IrisThemes.current()) }
        root.shareTheme(theme)
    }
    function pasteTheme(): void {
        const theme = IrisThemes.importText(String(Quickshell.clipboardText ?? ""))
        root.say(theme ? Translation.tr("Imported “%1”").arg(theme.name) : Translation.tr("The clipboard does not hold an iRiS theme"))
    }

    readonly property bool previewsOn: Config.options?.iris?.appearance?.previews ?? true
    readonly property bool showPreview: root.previewsOn && (Config.options?.iris?.appearance?.studioPreview ?? true)
    property bool desktopPreview: false
    onDesktopPreviewChanged: root.preview(root.target, root.desktopPreview)
    function preview(id: string, on: bool): void {
        if (on && !root.desktopPreview) return
        switch (id) {
        case "island":
            if (on) GlobalStates.irisIslandPageRequest = "desktop"
            else GlobalStates.irisArrange = false
            break
        case "bodies":
            GlobalStates.controlPanelOpen = on
            break
        case "places":
            if (on) GlobalStates.openSidebarRight("")
            else GlobalStates.sidebarRightOpen = false
            break
        case "dock":
            GlobalStates.irisDockShown = on
            break
        }
    }
    function select(id: string): void {
        const wanted = root.hasContent(id) ? id : "material"
        if (wanted === root.target) return
        root.preview(root.target, false)
        root.target = wanted
        root.preview(wanted, true)
        flick.contentY = 0
    }
    function takeRequest(): void {
        const wanted = GlobalStates.irisStudioTarget
        if (wanted.length === 0) return
        GlobalStates.irisStudioTarget = ""
        if (root.targets.some(entry => entry.id === wanted)) root.select(wanted)
    }
    Component.onCompleted: root.takeRequest()
    Connections {
        target: GlobalStates
        function onIrisStudioTargetChanged(): void { root.takeRequest() }
        function onIrisStudioOpenChanged(): void {
            if (GlobalStates.irisStudioOpen) root.preview(root.target, true)
            else root.preview(root.target, false)
        }
    }
    Connections {
        target: IrisStyle
        function onRyokuFrontendChanged(): void {
            if (!root.hasContent(root.target)) root.select("material")
        }
    }
    function resetTarget(): void {
        const updates = {}
        for (const spec of root.specifications) {
            if (spec.target === root.target && String(spec.path).startsWith("iris.")) updates[spec.path] = spec.fallback
        }
        Config.setNestedValues(updates)
    }

    readonly property var descriptions: ({
        material: "What every surface is made of: its character, corners, lines and the frame.",
        colour: "Accent, highlight, the light bodies carry and how much wallpaper iRiS takes in.",
        type: "Typefaces, figures and how large text reads.",
        motion: "How shapes open, move and settle — everywhere at once, or per surface.",
        island: "Its shape on the edge, what it shows at rest, and its pages.",
        pieces: "Bubbles off the Island and the bars they form.",
        bodies: "Cards, the Control Center and the player.",
        places: "Side panels, Spotlight, the gallery, Settings and menus.",
        transients: "Notifications and level feedback.",
        dock: "The Dock's shape and its icons.",
        desktop: "Widgets on the desktop.",
        themes: "Whole redesigns of iRiS, and the ones you save and share."
    })
    readonly property var railSections: [["material", "colour", "type", "motion"],
        ["island", "pieces", "bodies", "places", "transients", "dock", "desktop"], ["themes"]]
    function targetOf(id: string): var { return root.targets.find(entry => entry.id === id) ?? root.targets[0] }
    function modifiedIn(id: string): int {
        void Config.revision
        let count = 0
        for (const spec of root.specifications) {
            if (spec.target !== id || !String(spec.path).startsWith("iris.") || spec.fallback === undefined) continue
            if (!IrisOptions.same(Config.getNestedValue(spec.path, spec.fallback), spec.fallback)) count++
        }
        return count
    }

    property string query: ""
    readonly property var matches: {
        void Config.revision
        const q = root.query.trim().toLowerCase()
        if (q.length === 0) return []
        const out = []
        for (const spec of root.specifications) {
            if (!root.shown(spec)) continue
            const text = [spec.label, spec.description ?? "", spec.group, root.targetOf(spec.target).label].join(" ").toLowerCase()
            if (!text.includes(q)) continue
            const title = root.targetOf(spec.target).label + " · " + spec.group
            if (out.length === 0 || out[out.length - 1].title !== title) out.push({ title: title, rows: [] })
            out[out.length - 1].rows.push(spec)
        }
        return out
    }

    readonly property var trackedPaths: {
        const set = {}
        set["iris.appearance.preset"] = true
        set["iris.appearance.themeId"] = true
        for (const entry of IrisThemes.paths) set[entry.path] = true
        for (const spec of root.specifications) if (String(spec.path).startsWith("iris.")) set[spec.path] = true
        return Object.keys(set)
    }
    function snapshot(): var {
        const values = {}
        for (const path of root.trackedPaths) values[path] = IrisOptions.plain(Config.getNestedValue(path, root.fallbackOf(path)))
        return values
    }
    property var undoStack: []
    property var redoStack: []
    property var lastSnapshot: null
    property string lastKey: ""
    property bool restoring: false
    function recordHistory(): void {
        const snap = root.snapshot()
        const key = JSON.stringify(snap)
        if (key === root.lastKey) return
        if (root.lastSnapshot && !root.restoring) {
            root.undoStack = root.undoStack.concat([root.lastSnapshot]).slice(-60)
            root.redoStack = []
        }
        root.restoring = false
        root.lastSnapshot = snap
        root.lastKey = key
    }
    function undo(): void {
        if (root.undoStack.length === 0) return
        const previous = root.undoStack[root.undoStack.length - 1]
        root.undoStack = root.undoStack.slice(0, -1)
        root.redoStack = root.redoStack.concat([root.snapshot()])
        root.restoring = true
        Config.setNestedValues(previous)
        root.say(Translation.tr("Undone"))
    }
    function redo(): void {
        if (root.redoStack.length === 0) return
        const next = root.redoStack[root.redoStack.length - 1]
        root.redoStack = root.redoStack.slice(0, -1)
        root.undoStack = root.undoStack.concat([root.snapshot()])
        root.restoring = true
        Config.setNestedValues(next)
        root.say(Translation.tr("Redone"))
    }
    Timer {
        id: historyTimer
        interval: 320
        onTriggered: root.recordHistory()
    }
    Connections {
        target: Config
        enabled: GlobalStates.irisStudioOpen
        function onRevisionChanged(): void { historyTimer.restart() }
    }
    Connections {
        target: GlobalStates
        function onIrisStudioOpenChanged(): void {
            if (!GlobalStates.irisStudioOpen) return
            root.lastSnapshot = root.snapshot()
            root.lastKey = JSON.stringify(root.lastSnapshot)
            root.undoStack = []
            root.redoStack = []
        }
    }

    readonly property var presentedRect: GlobalStates.irisStudioOpen && frame.armed
        ? { screen: root.screen?.name ?? "", x: frame.x, y: frame.y, width: frame.width, height: frame.height } : null
    onPresentedRectChanged: GlobalStates.irisStudioRect = root.presentedRect
    Component.onDestruction: GlobalStates.irisStudioRect = null

    visible: GlobalStates.irisStudioOpen || frame.progress > 0
    IrisOutputHold {
        id: outputHold
        wanted: GlobalStates.focusedScreen
        live: root.visible
    }
    screen: outputHold.output
    color: "transparent"
    anchors { left: true; top: true; bottom: true }
    implicitWidth: frame.width + Math.round(24 * root.d) + IrisFrame.clear("left")
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:iris-studio"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: GlobalStates.irisStudioOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    mask: Region { item: frame }

    Shortcut {
        sequence: "Escape"
        enabled: GlobalStates.irisStudioOpen
        onActivated: {
            if (root.query.length > 0) { root.query = ""; searchField.text = "" }
            else GlobalStates.irisStudioOpen = false
        }
    }
    Shortcut { sequences: [StandardKey.Undo]; enabled: GlobalStates.irisStudioOpen; onActivated: root.undo() }
    Shortcut { sequences: [StandardKey.Redo, "Ctrl+Shift+Z"]; enabled: GlobalStates.irisStudioOpen; onActivated: root.redo() }
    Shortcut { sequence: "Ctrl+F"; enabled: GlobalStates.irisStudioOpen; onActivated: searchField.forceActiveFocus() }

    IrisMorphSurface {
        id: frame
        open: GlobalStates.irisStudioOpen
        motionSurface: "settings"
        radius: IrisStyle.surfaceRadius("settings", IrisStyle.radiusPanel)
        light: IrisStyle.surfaceLight("settings", IrisStyle.wallpaperLight)
        x: Math.round(12 * root.d) + IrisFrame.clear("left")
        y: (parent.height - height) / 2
        width: Math.min((root.screen?.width ?? 1920) - Math.round(48 * root.d) - IrisFrame.band * 2, Math.round(540 * root.d))
        height: Math.min(parent.height - Math.round(24 * root.d) - IrisFrame.band * 2, Math.round(960 * root.d))
        MouseArea { anchors.fill: parent }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: IrisStyle.concentricPad(frame.radius, 16 * root.d)
            spacing: Math.round(12 * root.d)

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(8 * root.d)
                IrisMark { implicitSize: Math.round(24 * root.d) }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    IrisText {
                        text: Translation.tr("Studio")
                        font.family: IrisStyle.fontTitle
                        font.pixelSize: 19 * IrisStyle.typeScale
                        font.weight: Font.Bold
                    }
                    IrisText {
                        Layout.fillWidth: true
                        text: root.notice.length > 0 ? root.notice : Translation.tr("Everything you change is the shell itself")
                        color: root.notice.length > 0 ? IrisStyle.accent : IrisStyle.muted
                        font.pixelSize: 11.5 * IrisStyle.typeScale
                        elide: Text.ElideRight
                    }
                }
                IrisIconButton {
                    materialIcon: "undo"
                    enabled: root.undoStack.length > 0
                    opacity: enabled ? 1 : 0.35
                    Accessible.name: Translation.tr("Undo")
                    onClicked: root.undo()
                }
                IrisIconButton {
                    materialIcon: "redo"
                    enabled: root.redoStack.length > 0
                    opacity: enabled ? 1 : 0.35
                    Accessible.name: Translation.tr("Redo")
                    onClicked: root.redo()
                }
                Rectangle { implicitWidth: 1; implicitHeight: Math.round(18 * root.d); color: IrisStyle.hairline }
                IrisIconButton {
                    materialIcon: "edit"
                    selected: GlobalStates.irisEdit
                    Accessible.name: Translation.tr("Edit iRiS in place")
                    onClicked: {
                        GlobalStates.irisEdit = !GlobalStates.irisEdit
                        if (GlobalStates.irisEdit) GlobalStates.irisStudioOpen = false
                    }
                }
                IrisIconButton {
                    materialIcon: "tune"
                    Accessible.name: Translation.tr("All settings")
                    onClicked: { GlobalStates.irisStudioOpen = false; GlobalStates.openSettings() }
                }
                IrisIconButton {
                    materialIcon: "close"
                    Accessible.name: Translation.tr("Close Studio")
                    onClicked: GlobalStates.irisStudioOpen = false
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.round(34 * root.d)
                radius: height / 2
                color: searchField.activeFocus ? IrisStyle.fill : IrisStyle.fillQuiet
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(12 * root.d)
                    anchors.rightMargin: Math.round(6 * root.d)
                    spacing: Math.round(8 * root.d)
                    MaterialSymbol { text: "search"; iconSize: Math.round(17 * root.d); color: IrisStyle.muted }
                    TextInput {
                        id: searchField
                        Layout.fillWidth: true
                        verticalAlignment: TextInput.AlignVCenter
                        color: IrisStyle.text
                        selectionColor: IrisStyle.accentContainer
                        font.family: IrisStyle.fontMain
                        font.pixelSize: 13 * IrisStyle.typeScale
                        clip: true
                        onTextChanged: { root.query = text; flick.contentY = 0 }
                        IrisText {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: searchField.text.length === 0
                            text: Translation.tr("Search every option")
                            color: IrisStyle.muted
                            font.pixelSize: searchField.font.pixelSize
                        }
                    }
                    IrisIconButton {
                        visible: searchField.text.length > 0
                        implicitWidth: Math.round(24 * root.d)
                        materialIcon: "close"
                        iconSize: Math.round(14 * root.d)
                        Accessible.name: Translation.tr("Clear search")
                        onClicked: searchField.text = ""
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Math.round(12 * root.d)

                Flickable {
                    Layout.preferredWidth: Math.round(58 * root.d)
                    Layout.fillHeight: true
                    contentHeight: rail.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true
                    opacity: root.query.length > 0 ? 0.4 : 1
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140) } }

                    ColumnLayout {
                        id: rail
                        width: parent.width
                        spacing: Math.round(2 * root.d)
                        Repeater {
                            model: root.railSections
                            ColumnLayout {
                                id: railSection
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                spacing: Math.round(2 * root.d)
                                Rectangle {
                                    visible: railSection.index > 0
                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: Math.round(5 * root.d)
                                    Layout.bottomMargin: Math.round(5 * root.d)
                                    implicitWidth: Math.round(24 * root.d)
                                    implicitHeight: 1
                                    color: IrisStyle.hairline
                                }
                                Repeater {
                                    model: railSection.modelData
                                    RailButton {
                                        required property string modelData
                                        Layout.fillWidth: true
                                        entry: root.targetOf(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    spacing: Math.round(10 * root.d)

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.query.length === 0
                        spacing: Math.round(8 * root.d)
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Math.round(1 * root.d)
                            IrisText {
                                text: Translation.tr(root.targetOf(root.target).label)
                                font.family: IrisStyle.fontTitle
                                font.pixelSize: 17 * IrisStyle.typeScale
                                font.weight: Font.Bold
                            }
                            IrisText {
                                Layout.fillWidth: true
                                text: Translation.tr(root.descriptions[root.target] ?? "")
                                color: IrisStyle.muted
                                font.pixelSize: 11.5 * IrisStyle.typeScale
                                wrapMode: Text.WordWrap
                            }
                        }
                        IrisButton {
                            readonly property int changed: root.modifiedIn(root.target)
                            visible: root.target !== "themes" && changed > 0
                            quiet: true
                            buttonRadius: height / 2
                            text: Translation.tr("Reset %1").arg(changed)
                            Accessible.name: Translation.tr("Reset what changed here")
                            onClicked: root.resetTarget()
                        }
                        IrisButton {
                            visible: root.target === "themes"
                            quiet: true
                            buttonRadius: height / 2
                            text: Translation.tr("Paste a theme")
                            onClicked: root.pasteTheme()
                        }
                    }

                    Loader {
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.round((root.target === "island" || root.target === "dock" ? 150 : 206) * root.d)
                        active: root.showPreview && root.query.length === 0 && root.target !== "themes"
                        visible: active
                        sourceComponent: root.target === "island" || root.target === "dock" ? screenPreview : scenePreview
                    }
                    Component {
                        id: screenPreview
                        IrisScreenPreview {
                            id: screenMiniature
                            screen: root.screen
                            focusRect: root.target === "dock" ? screenMiniature.dockReach : screenMiniature.islandReach
                        }
                    }
                    Component {
                        id: scenePreview
                        IrisTargetPreview {
                            target: root.target
                            playing: GlobalStates.irisStudioOpen
                        }
                    }

                    Flow {
                        Layout.fillWidth: true
                        visible: root.query.length === 0 && root.target !== "themes"
                        spacing: Math.round(6 * root.d)
                        ActionChip {
                            visible: root.previewsOn
                            glyph: root.showPreview ? "visibility" : "visibility_off"
                            label: root.showPreview ? Translation.tr("Preview") : Translation.tr("Preview hidden")
                            on: root.showPreview
                            onActivated: Config.setNestedValue("iris.appearance.studioPreview", !root.showPreview)
                        }
                        ActionChip {
                            glyph: "desktop_windows"
                            label: Translation.tr("Live on screen")
                            on: root.desktopPreview
                            onActivated: root.desktopPreview = !root.desktopPreview
                        }
                        ActionChip {
                            visible: root.target === "island"
                            glyph: "open_in_full"
                            label: Translation.tr("Open the Island")
                            onActivated: GlobalStates.irisIslandPageRequest = "desktop"
                        }
                        ActionChip {
                            visible: root.target === "island"
                            glyph: "dashboard_customize"
                            label: GlobalStates.irisArrange ? Translation.tr("Arranging") : Translation.tr("Arrange blocks")
                            on: GlobalStates.irisArrange
                            onActivated: {
                                if (!GlobalStates.irisArrange) GlobalStates.irisIslandPageRequest = "desktop"
                                GlobalStates.irisArrange = !GlobalStates.irisArrange
                            }
                        }
                        ActionChip {
                            visible: root.target === "bodies"
                            glyph: "partly_cloudy_day"
                            label: Translation.tr("Show a card")
                            onActivated: { GlobalStates.controlPanelOpen = false; GlobalStates.irisBubbleCardRequest = "weather" }
                        }
                        ActionChip {
                            visible: root.target === "bodies"
                            glyph: "toggle_on"
                            label: Translation.tr("Control Center")
                            on: GlobalStates.controlPanelOpen
                            onActivated: GlobalStates.controlPanelOpen = !GlobalStates.controlPanelOpen
                        }
                        ActionChip {
                            visible: root.target === "transients"
                            glyph: "volume_up"
                            label: Translation.tr("Show a level")
                            onActivated: GlobalStates.osdVolumeOpen = true
                        }
                        ActionChip {
                            visible: root.target === "dock"
                            glyph: "dock_to_bottom"
                            label: Translation.tr("Reveal the Dock")
                            on: GlobalStates.irisDockShown
                            onActivated: GlobalStates.irisDockShown = !GlobalStates.irisDockShown
                        }
                        ActionChip {
                            visible: root.target === "places"
                            glyph: "view_sidebar"
                            label: Translation.tr("Open Today")
                            onActivated: GlobalStates.openSidebarRight("")
                        }
                        ActionChip {
                            visible: root.target === "pieces" || root.target === "desktop" || root.target === "dock"
                            glyph: "edit"
                            label: Translation.tr("Edit in place")
                            onActivated: { GlobalStates.irisEdit = true; GlobalStates.irisStudioOpen = false }
                        }
                    }

                    Flickable {
                        id: flick
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        clip: true
                        contentHeight: rows.implicitHeight + Math.round(8 * root.d)
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

                        ColumnLayout {
                            id: rows
                            width: flick.width
                            spacing: Math.round(14 * root.d)

                            IrisText {
                                visible: root.query.length > 0 && root.matches.length === 0
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: Math.round(24 * root.d)
                                text: Translation.tr("Nothing matches “%1”").arg(root.query)
                                color: IrisStyle.muted
                            }

                            GroupCard {
                                Layout.fillWidth: true
                                visible: root.query.length === 0 && root.target === "material"
                                title: Translation.tr("Character")
                                plain: true
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: Math.round(6 * root.d)
                                    Repeater {
                                        model: root.presetOrder
                                        PresetTile {
                                            required property string modelData
                                            Layout.fillWidth: true
                                            name: modelData
                                        }
                                    }
                                }
                            }

                            Repeater {
                                model: root.query.length > 0 ? root.matches : root.target === "themes" ? [] : root.groups
                                GroupCard {
                                    id: groupCard
                                    required property var modelData
                                    Layout.fillWidth: true
                                    title: groupCard.modelData.title
                                    Repeater {
                                        model: groupCard.modelData.rows
                                        IrisSetting {
                                            required property var modelData
                                            required property int index
                                            Layout.fillWidth: true
                                            spec: modelData
                                            last: index === groupCard.modelData.rows.length - 1
                                        }
                                    }
                                }
                            }

                            Loader {
                                Layout.fillWidth: true
                                active: root.query.length === 0 && root.target === "themes"
                                visible: active
                                sourceComponent: themesPage
                            }
                        }
                    }
                }
            }
        }
    }

    component RailButton: MouseArea {
        id: railButton
        required property var entry
        readonly property bool present: root.hasContent(railButton.entry.id)
        readonly property bool selected: root.target === railButton.entry.id && root.query.length === 0
        readonly property int changed: root.modifiedIn(railButton.entry.id)
        visible: railButton.present
        implicitHeight: railButton.present ? Math.round(50 * root.d) : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.PageTab
        Accessible.name: Translation.tr(railButton.entry.label)
        Accessible.checked: railButton.selected
        onClicked: {
            if (root.query.length > 0) searchField.text = ""
            root.select(railButton.entry.id)
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(2 * root.d)
            width: Math.round(40 * root.d)
            height: Math.round(28 * root.d)
            radius: height / 2
            color: railButton.selected ? (IrisStyle.ryokuFrontend ? IrisStyle.accentContainer : IrisStyle.tintFill(IrisStyle.accent))
                : railButton.containsMouse ? IrisStyle.fillHover : "transparent"
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
            MaterialSymbol {
                anchors.centerIn: parent
                text: railButton.entry.glyph
                iconSize: Math.round(19 * root.d)
                fill: railButton.selected ? 1 : 0
                animateFill: true
                color: railButton.selected ? (IrisStyle.ryokuFrontend ? IrisStyle.onAccentContainer : IrisStyle.accent) : IrisStyle.textSecondary
            }
            Rectangle {
                visible: railButton.changed > 0
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: Math.round(4 * root.d)
                anchors.topMargin: Math.round(3 * root.d)
                width: Math.round(6 * root.d)
                height: width
                radius: width / 2
                color: IrisStyle.accent
            }
        }
        IrisText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Math.round(3 * root.d)
            text: Translation.tr(railButton.entry.label)
            color: railButton.selected ? IrisStyle.text : IrisStyle.muted
            font.pixelSize: 10 * IrisStyle.typeScale
            font.weight: railButton.selected ? Font.DemiBold : Font.Normal
        }
    }

    component ActionChip: MouseArea {
        id: chip
        property string glyph: ""
        property string label: ""
        property bool on: false
        signal activated
        implicitWidth: chipRow.implicitWidth + Math.round(20 * root.d)
        implicitHeight: Math.round(28 * root.d)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: chip.label
        onClicked: chip.activated()
        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: chip.on ? IrisStyle.tintFill(IrisStyle.accent) : chip.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
        }
        Row {
            id: chipRow
            anchors.centerIn: parent
            spacing: Math.round(6 * root.d)
            MaterialSymbol {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.glyph
                iconSize: Math.round(15 * root.d)
                fill: chip.on ? 1 : 0
                color: chip.on ? IrisStyle.accent : IrisStyle.textSecondary
            }
            IrisText {
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: chip.on ? IrisStyle.text : IrisStyle.subtext
                font.pixelSize: 12 * IrisStyle.typeScale
            }
        }
    }

    component GroupCard: ColumnLayout {
        id: card
        property string title: ""
        property bool plain: false
        default property alias rows: body.data
        spacing: Math.round(6 * root.d)
        IrisText {
            Layout.leftMargin: Math.round(14 * root.d)
            text: Translation.tr(card.title)
            color: IrisStyle.label
            font.family: IrisStyle.fontTitle
            font.pixelSize: 12 * IrisStyle.typeScale
            font.weight: Font.DemiBold
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: body.implicitHeight
            radius: IrisStyle.radiusTile
            color: card.plain ? "transparent" : IrisStyle.surfaceHigh
            ColumnLayout {
                id: body
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0
            }
        }
    }

    component PresetTile: MouseArea {
        id: tile
        required property string name
        readonly property var values: IrisStyle.presets[tile.name] ?? IrisStyle.presets.iris
        readonly property bool selected: IrisStyle.presetName === tile.name
        implicitHeight: Math.round(66 * root.d)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.RadioButton
        Accessible.name: tile.name
        Accessible.checked: tile.selected
        onClicked: Config.setNestedValue("iris.appearance.preset", tile.name)
        Rectangle {
            id: miniature
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.round(44 * root.d)
            radius: Math.round(12 * tile.values.shape * root.d)
            color: IrisStyle.surfaceOpaque
            border.width: tile.selected ? 2 : 1
            border.color: tile.selected ? IrisStyle.accent : (tile.containsMouse ? IrisStyle.borderStrong : IrisStyle.border)
            Behavior on border.color { ColorAnimation { duration: IrisStyle.duration(110) } }
            Column {
                anchors.fill: parent
                anchors.margins: Math.round(8 * root.d)
                spacing: Math.round(4 * root.d)
                Rectangle {
                    width: parent.width
                    height: Math.round(16 * root.d)
                    radius: Math.round(7 * tile.values.shape * root.d)
                    color: Qt.alpha(IrisStyle.text, Math.min(0.5, 0.12 * tile.values.fill))
                }
                Row {
                    spacing: Math.round(4 * root.d)
                    Rectangle { width: Math.round(18 * root.d); height: Math.round(9 * root.d); radius: height / 2; color: IrisStyle.accent }
                    Rectangle { width: Math.round(26 * root.d); height: Math.round(9 * root.d); radius: height / 2; color: Qt.alpha(IrisStyle.text, tile.values.textTertiary) }
                }
            }
        }
        IrisText {
            anchors.top: miniature.bottom
            anchors.topMargin: Math.round(4 * root.d)
            anchors.horizontalCenter: parent.horizontalCenter
            text: Translation.tr(tile.name.charAt(0).toUpperCase() + tile.name.slice(1))
            color: tile.selected ? IrisStyle.text : IrisStyle.subtext
            font.pixelSize: 11.5 * IrisStyle.typeScale
            font.weight: tile.selected ? Font.DemiBold : Font.Normal
        }
    }

    Component {
        id: themesPage
        ColumnLayout {
            spacing: Math.round(14 * root.d)

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: currentRow.implicitHeight + Math.round(20 * root.d)
                radius: IrisStyle.radiusTile
                color: IrisStyle.surfaceHigh
                RowLayout {
                    id: currentRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Math.round(14 * root.d)
                    anchors.rightMargin: Math.round(8 * root.d)
                    spacing: Math.round(6 * root.d)
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(1 * root.d)
                        IrisText {
                            Layout.fillWidth: true
                            text: IrisThemes.active ? IrisThemes.active.name : Translation.tr("Your own mix")
                            font.pixelSize: 14 * IrisStyle.typeScale
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        IrisText {
                            Layout.fillWidth: true
                            text: IrisThemes.modified ? Translation.tr("Changed since it was applied — save it to keep it")
                                : Translation.tr("Applied as it comes")
                            color: IrisThemes.modified ? IrisStyle.secondaryAccent : IrisStyle.muted
                            font.pixelSize: 11.5 * IrisStyle.typeScale
                            elide: Text.ElideRight
                        }
                    }
                    IrisIconButton { materialIcon: "ios_share"; Accessible.name: Translation.tr("Copy what you see now, to share it"); onClicked: root.shareCurrent() }
                    IrisIconButton {
                        visible: IrisThemes.modified && IrisThemes.active !== null
                        materialIcon: "restart_alt"
                        Accessible.name: Translation.tr("Back to the theme as it comes")
                        onClicked: root.applyTheme(IrisThemes.active)
                    }
                }
            }

            ThemeGrid {
                Layout.fillWidth: true
                title: Translation.tr("Themes")
                themes: IrisThemes.curated
            }

            ThemeGrid {
                Layout.fillWidth: true
                title: Translation.tr("Yours")
                themes: IrisThemes.user
                visible: IrisThemes.user.length > 0
            }

            GroupCard {
                Layout.fillWidth: true
                title: IrisThemes.user.length > 0 ? "" : Translation.tr("Yours")
                RowLayout {
                    Layout.fillWidth: true
                    Layout.margins: Math.round(12 * root.d)
                    spacing: Math.round(8 * root.d)
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: Math.round(32 * root.d)
                        radius: height / 2
                        color: nameField.activeFocus ? IrisStyle.fill : IrisStyle.fillQuiet
                        TextInput {
                            id: nameField
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(14 * root.d)
                            anchors.rightMargin: Math.round(14 * root.d)
                            verticalAlignment: TextInput.AlignVCenter
                            color: IrisStyle.text
                            selectionColor: IrisStyle.accentContainer
                            font.family: IrisStyle.fontMain
                            font.pixelSize: 13 * IrisStyle.typeScale
                            clip: true
                            onAccepted: { root.saveTheme(text); text = "" }
                            IrisText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: nameField.text.length === 0
                                text: Translation.tr("Name what you see now")
                                color: IrisStyle.muted
                                font.pixelSize: nameField.font.pixelSize
                            }
                        }
                    }
                    IrisButton {
                        emphasized: true
                        text: Translation.tr("Save as theme")
                        buttonRadius: height / 2
                        onClicked: { root.saveTheme(nameField.text); nameField.text = "" }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Math.round(12 * root.d)
                    Layout.rightMargin: Math.round(12 * root.d)
                    spacing: Math.round(8 * root.d)
                    IrisButton {
                        quiet: true
                        text: Translation.tr("Paste a theme")
                        buttonRadius: height / 2
                        onClicked: root.pasteTheme()
                    }
                    IrisButton {
                        quiet: true
                        text: Translation.tr("Open the themes folder")
                        buttonRadius: height / 2
                        onClicked: IrisThemes.reveal()
                    }
                    Item { Layout.fillWidth: true }
                }
                IrisText {
                    Layout.fillWidth: true
                    Layout.margins: Math.round(14 * root.d)
                    text: Translation.tr("A theme is one small file. Share it by sending the .json from the themes folder, or copy it and paste it anywhere; whoever gets it pastes it here or drops the file into their own folder.")
                    color: IrisStyle.muted
                    font.pixelSize: 11.5 * IrisStyle.typeScale
                    wrapMode: Text.WordWrap
                }
            }
        }
    }

    component ThemeGrid: ColumnLayout {
        id: grid
        property string title: ""
        property var themes: []
        spacing: Math.round(6 * root.d)
        IrisText {
            Layout.leftMargin: Math.round(14 * root.d)
            text: grid.title
            color: IrisStyle.label
            font.family: IrisStyle.fontTitle
            font.pixelSize: 12 * IrisStyle.typeScale
            font.weight: Font.DemiBold
        }
        GridLayout {
            id: cells
            Layout.fillWidth: true
            columns: 2
            rowSpacing: Math.round(10 * root.d)
            columnSpacing: Math.round(10 * root.d)
            Repeater {
                model: grid.themes
                ThemeCard {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: (cells.width - cells.columnSpacing) / 2
                    theme: modelData
                }
            }
        }
    }

    component ThemeCard: MouseArea {
        id: card
        required property var theme
        readonly property var look: IrisThemes.swatch(card.theme)
        readonly property bool current: IrisThemes.activeId === card.theme.id
        readonly property bool mine: Boolean(card.theme.user)
        readonly property color body: card.look.glass ? Qt.alpha(card.look.surface, Math.max(0.42, card.look.tint)) : card.look.surface
        readonly property color line: Qt.alpha(IrisStyle.text, Math.min(0.4, 0.14 * card.look.lines))
        readonly property real s: card.look.shape
        readonly property string islandEdge: IrisFrame.islandEdge
        readonly property string dockEdge: IrisFrame.edges.includes(card.look.dockPosition) && card.look.dockPosition !== card.islandEdge
            ? card.look.dockPosition : IrisFrame.opposite(card.islandEdge)
        function sideways(edge: string): bool { return edge === "left" || edge === "right" }
        function piece(size: real): real {
            const scale = Math.max(0.6, card.s)
            return Math.min(size / 2, card.look.pieceShape === "square" ? size * 0.22 * scale
                : card.look.pieceShape === "squircle" ? size * 0.34 * scale : size / 2)
        }
        implicitHeight: scene.height + caption.implicitHeight + Math.round(12 * root.d)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: card.theme.name
        onClicked: root.applyTheme(card.theme)

        ClippingRectangle {
            id: scene
            width: parent.width
            height: Math.round(width * 0.58)
            radius: IrisStyle.radiusTile
            color: IrisStyle.surfaceOpaque
            border.width: card.current ? 2 : 1
            border.color: card.current ? IrisStyle.accent : card.containsMouse ? IrisStyle.borderStrong : IrisStyle.border

            Image {
                anchors.fill: parent
                source: WallpaperListener.wallpaperUrlForScreen(root.screen)
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: 240
                sourceSize.height: 136
                asynchronous: true
                cache: true
                opacity: 0.85
            }

            readonly property real band: card.look.framed ? Math.round(4 * root.d) : 0
            Rectangle {
                anchors.fill: parent
                visible: card.look.framed
                color: "transparent"
                border.width: scene.band
                border.color: card.body
                radius: IrisStyle.radiusTile
            }

            Rectangle {
                id: island
                readonly property bool full: card.look.layout === "full"
                readonly property bool vertical: card.sideways(card.islandEdge)
                readonly property real thick: Math.round(13 * root.d)
                readonly property real span: island.vertical ? parent.height : parent.width
                readonly property real length: island.full ? island.span - 2 * scene.band : Math.round(island.span * (island.vertical ? 0.5 : 0.36))
                readonly property real along: card.look.layout === "left" ? scene.band + Math.round(8 * root.d)
                    : card.look.layout === "right" ? island.span - island.length - scene.band - Math.round(8 * root.d)
                    : island.full ? scene.band : (island.span - island.length) / 2
                readonly property real inset: card.look.notch ? scene.band : scene.band + Math.round(4 * root.d)
                readonly property real across: card.islandEdge === "bottom" ? parent.height - island.thick - island.inset
                    : card.islandEdge === "right" ? parent.width - island.thick - island.inset : island.inset
                readonly property bool flat: island.full || card.look.notch
                width: island.vertical ? island.thick : island.length
                height: island.vertical ? island.length : island.thick
                x: island.vertical ? island.across : island.along
                y: island.vertical ? island.along : island.across
                radius: island.full ? 0 : card.look.notch ? island.thick / 2 : card.piece(island.thick)
                topLeftRadius: island.flat && (card.islandEdge === "top" || card.islandEdge === "left") ? 0 : radius
                topRightRadius: island.flat && (card.islandEdge === "top" || card.islandEdge === "right") ? 0 : radius
                bottomLeftRadius: island.flat && (card.islandEdge === "bottom" || card.islandEdge === "left") ? 0 : radius
                bottomRightRadius: island.flat && (card.islandEdge === "bottom" || card.islandEdge === "right") ? 0 : radius
                color: card.body
                border.width: card.look.rim && !card.look.notch ? 1 : 0
                border.color: card.line
                Grid {
                    anchors.centerIn: parent
                    columns: island.vertical ? 1 : 3
                    horizontalItemAlignment: Grid.AlignHCenter
                    Text { text: "07"; color: IrisStyle.text; font.family: card.look.numbersFont; font.weight: card.look.figureWeight; font.pixelSize: Math.round(8 * root.d) }
                    Text {
                        text: island.vertical ? "··" : ":"
                        lineHeight: island.vertical ? 0.5 : 1
                        color: card.look.clockAccent === "plain" ? IrisStyle.text : card.look.clockAccent === "accent" ? card.look.accent : card.look.highlight
                        font.family: card.look.numbersFont; font.weight: card.look.figureWeight; font.pixelSize: Math.round(8 * root.d)
                    }
                    Text { text: "08"; color: IrisStyle.text; font.family: card.look.numbersFont; font.weight: card.look.figureWeight; font.pixelSize: Math.round(8 * root.d) }
                }
            }
            Rectangle {
                visible: !island.full
                width: island.thick
                height: island.thick
                x: island.vertical ? island.x : island.x + island.width + Math.round(4 * root.d)
                y: island.vertical ? island.y + island.height + Math.round(4 * root.d) : island.y
                radius: card.piece(width)
                color: card.body
                Rectangle { anchors.centerIn: parent; width: Math.round(5 * root.d); height: width; radius: card.piece(width); color: card.look.accent }
            }

            Rectangle {
                id: sheet
                width: Math.round(parent.width * 0.44)
                height: Math.round(parent.height * 0.42)
                x: card.islandEdge === "right" || card.dockEdge === "right" ? scene.band + Math.round(22 * root.d)
                    : parent.width - width - scene.band - Math.round(8 * root.d)
                y: card.islandEdge === "top" ? island.y + island.height + Math.round(6 * root.d)
                    : card.islandEdge === "bottom" ? island.y - height - Math.round(6 * root.d)
                    : Math.round(parent.height * 0.18)
                radius: Math.round(9 * Math.min(1.3, card.s) * root.d)
                color: card.body
                border.width: card.look.rim ? 1 : 0
                border.color: card.line
                Column {
                    anchors.fill: parent
                    anchors.margins: Math.round(7 * root.d)
                    spacing: Math.round(4 * root.d)
                    Text {
                        text: "Aa"
                        color: IrisStyle.text
                        font.family: card.look.titleFont
                        font.weight: Font.DemiBold
                        font.pixelSize: Math.round(11 * root.d)
                    }
                    Rectangle { width: parent.width * 0.8; height: Math.round(4 * root.d); radius: height / 2; color: Qt.alpha(IrisStyle.text, 0.3) }
                    Row {
                        spacing: Math.round(4 * root.d)
                        Rectangle { width: Math.round(18 * root.d); height: Math.round(8 * root.d); radius: card.piece(height); color: card.look.accent }
                        Rectangle { width: Math.round(8 * root.d); height: Math.round(8 * root.d); radius: card.piece(height); color: card.look.highlight }
                    }
                }
            }

            Rectangle {
                id: dockMini
                readonly property bool vertical: card.sideways(card.dockEdge)
                readonly property real thick: Math.round(11 * root.d)
                readonly property real length: Math.round((dockMini.vertical ? parent.height * 0.6 : parent.width * 0.34))
                readonly property real inset: scene.band + (card.look.dockNotch ? 0 : Math.round(4 * root.d))
                width: dockMini.vertical ? dockMini.thick : dockMini.length
                height: dockMini.vertical ? dockMini.length : dockMini.thick
                x: card.dockEdge === "left" ? dockMini.inset : card.dockEdge === "right" ? parent.width - width - dockMini.inset : (parent.width - width) / 2
                y: card.dockEdge === "top" ? dockMini.inset : card.dockEdge === "bottom" ? parent.height - height - dockMini.inset : (parent.height - height) / 2
                radius: card.look.dockNotch ? dockMini.thick / 2 : card.piece(dockMini.thick)
                topLeftRadius: card.look.dockNotch && (card.dockEdge === "top" || card.dockEdge === "left") ? 0 : radius
                topRightRadius: card.look.dockNotch && (card.dockEdge === "top" || card.dockEdge === "right") ? 0 : radius
                bottomLeftRadius: card.look.dockNotch && (card.dockEdge === "bottom" || card.dockEdge === "left") ? 0 : radius
                bottomRightRadius: card.look.dockNotch && (card.dockEdge === "bottom" || card.dockEdge === "right") ? 0 : radius
                color: card.body
                Grid {
                    anchors.centerIn: parent
                    columns: dockMini.vertical ? 1 : 5
                    spacing: Math.round(3 * root.d)
                    Repeater {
                        model: 5
                        Rectangle {
                            required property int index
                            width: Math.round(6 * root.d); height: width
                            radius: Math.round(width * 0.26 * Math.min(1.2, card.s))
                            color: index === 1 ? card.look.accent : index === 3 ? card.look.highlight : Qt.alpha(IrisStyle.text, 0.45)
                        }
                    }
                }
            }

            Rectangle {
                visible: card.current
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: Math.round(7 * root.d) + scene.band
                width: Math.round(18 * root.d)
                height: width
                radius: width / 2
                color: IrisStyle.accent
                MaterialSymbol { anchors.centerIn: parent; text: "check"; iconSize: Math.round(13 * root.d); color: IrisStyle.onAccent }
            }

            Row {
                anchors.left: parent.left
                anchors.top: parent.top
                anchors.margins: Math.round(5 * root.d) + scene.band
                spacing: Math.round(2 * root.d)
                visible: card.containsMouse
                IrisIconButton { materialIcon: "ios_share"; Accessible.name: Translation.tr("Copy to share"); onClicked: root.shareTheme(card.theme) }
                IrisIconButton { visible: card.mine; materialIcon: "delete"; Accessible.name: Translation.tr("Delete"); onClicked: IrisThemes.remove(card.theme.id) }
            }
        }

        ColumnLayout {
            id: caption
            anchors.top: scene.bottom
            anchors.topMargin: Math.round(6 * root.d)
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Math.round(2 * root.d)
            spacing: Math.round(1 * root.d)
            IrisText {
                Layout.fillWidth: true
                text: card.theme.name
                font.family: card.look.titleFont
                font.pixelSize: 13 * IrisStyle.typeScale
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            IrisText {
                Layout.fillWidth: true
                text: card.mine ? (card.theme.description || (card.theme.author ? Translation.tr("by %1").arg(card.theme.author) : ""))
                    : Translation.tr(card.theme.description)
                color: IrisStyle.textSecondary
                font.pixelSize: 11 * IrisStyle.typeScale
                wrapMode: Text.WordWrap
                maximumLineCount: 3
                elide: Text.ElideRight
            }
        }
    }
}
