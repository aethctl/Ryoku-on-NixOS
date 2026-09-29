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
import inir.modules.common.functions
import inir.modules.common.widgets
import inir.modules.iris.frame
import inir.modules.iris.components
import inir.modules.iris.style
import inir.modules.iris.pieces
import inir.modules.iris.sidebar
import inir.modules.iris.preview
import Ryoku.Ui.Singletons

PanelWindow {
    id: root
    property string section: "bar"
    property string query: ""
    property string group: ""
    readonly property bool browsing: root.query.length === 0 && root.group.length === 0 
    property string requestedSection: ""
    readonly property real d: IrisStyle.density
    readonly property bool previews: Config.options?.iris?.appearance?.previews ?? true
    readonly property var sections: [
        { id: "bar", title: "Island", subtitle: "Composition, size and how the Island responds", icon: "pill", tint: IrisStyle.identity.blue, tip: "Rest on the Island to peek, click to keep it, scroll for volume." },
        { id: "player", title: "Now Playing", subtitle: "Music in the Island and on the lock screen", icon: "music_note", tint: IrisStyle.identity.pink, tip: "Middle-click the Island to play or pause." },
        { id: "bubbles", title: "Bubbles", subtitle: "Where the Island's bubbles rest and how they float", icon: "bubble_chart", tint: IrisStyle.identity.sky, tip: "Hold a bubble to carry it; drop it beside the Island to bring it back." },
        { id: "dock", title: "Dock", subtitle: "Visibility, material and app icons", icon: "dock_to_bottom", tint: IrisStyle.identity.indigo, tip: "Right-click an icon for its windows or to float it as a bubble; middle-click opens a new one." },
        { id: "appearance", title: "Appearance", subtitle: "Shape and motion of every iRiS surface", icon: "palette", tint: IrisStyle.identity.purple, tip: "Shorter durations feel snappier; the curve stays the same." },
        { id: "desktop", title: "Desktop", subtitle: "Widgets on the wallpaper and the overview backdrop", icon: "widgets", tint: IrisStyle.identity.teal, tip: "Right-click the desktop to edit widgets." },
        { id: "sidebars", title: "Side Panels", subtitle: "Focus and Today, arranged around your workflow", icon: "dock_to_right", tint: IrisStyle.identity.green, tip: "Ctrl+E customizes a panel; Keep open makes room beside windows." },
        { id: "surfaces", title: "Spotlight & Panels", subtitle: "Search, Control Center and system feedback", icon: "space_dashboard", tint: IrisStyle.identity.orange, tip: "Spotlight prefixes: ; clipboard, = calculator, / actions." }
    ]
    // Latin names the section, the kanji seals it — the Ryoku nav language.
    readonly property var jpName: ({ bar: "島", player: "再生", bubbles: "泡", dock: "台座",
        appearance: "外観", desktop: "卓上", sidebars: "側面", surfaces: "探索" })
    readonly property var specifications: IrisOptions.settings
    readonly property var currentSection: root.sections.find(s => s.id === root.section) ?? root.sections[0]
    function shown(spec: var): bool {
        if (!IrisOptions.availableIn(spec)) return false
        const when = String(spec.visibleWhen ?? "")
        if (when.length === 0) return true
        if (when.includes("=")) return String(Config.getNestedValue(when.split("=")[0], "")) === when.split("=")[1]
        const negated = when.startsWith("!")
        const on = Boolean(Config.getNestedValue(negated ? when.slice(1) : when, false))
        return negated ? !on : on
    }
    readonly property int searchLimit: 24
    readonly property var searchIndex: root.specifications.map(spec => {
        const label = Translation.tr(spec.label).toLowerCase()
        return { spec: spec, label: label, rest: (Translation.tr(spec.group ?? "") + " " + Translation.tr(spec.description ?? "")).toLowerCase() }
    })
    function searchScore(entry: var, terms: var): int {
        if (!terms.every(term => entry.label.includes(term) || entry.rest.includes(term))) return -1
        const first = terms[0]
        if (entry.label.startsWith(first)) return 0
        if (entry.label.includes(" " + first)) return 1
        if (entry.label.includes(first)) return 2
        return 3
    }
    readonly property var matches: {
        Config.revision
        const terms = root.query.toLowerCase().split(/\s+/).filter(term => term.length > 0)
        if (terms.length === 0) return []
        return root.searchIndex
            .map((entry, order) => ({ spec: entry.spec, order: order, score: root.searchScore(entry, terms) }))
            .filter(hit => hit.score >= 0 && root.shown(hit.spec))
            .sort((a, b) => a.score - b.score || a.order - b.order)
            .map(hit => hit.spec)
    }
    readonly property var entries: {
        Config.revision
        return root.query.length > 0 ? root.matches.slice(0, root.searchLimit)
            : root.specifications.filter(spec => spec.section === root.section && root.shown(spec))
    }
    readonly property var groups: {
        const out = []
        for (const spec of root.entries) {
            const title = root.query.length > 0
                ? Translation.tr(root.sections.find(s => s.id === spec.section)?.title ?? "")
                : Translation.tr(spec.group ?? "")
            let group = out.find(entry => entry.title === title)
            if (!group) { group = { title: title, key: String(spec.group ?? ""), rows: [] }; out.push(group) }
            group.rows.push(spec)
        }
        return out
    }
    readonly property var shownGroups: root.query.length > 0 ? root.groups
        : root.group.length > 0 ? root.groups.filter(entry => entry.title === root.group) : []
    readonly property var groupGlyphs: ({
        "Accent": "palette", "Adaptive": "auto_awesome", "At rest": "schedule", "Badges": "notifications_unread",
        "Behaviour": "touch_app", "Bubble": "bubble_chart", "Card contents": "view_agenda", "Cards": "web_asset",
        "Control Center": "tune", "Curve": "show_chart", "Desktop page": "dashboard", "Extra bubbles": "add_circle",
        "Faces": "font_download", "Feedback": "campaign", "Floating": "flight", "Frame": "crop_free",
        "Highlight": "highlight", "Icons": "apps", "Interaction": "ads_click", "Joining": "join_inner",
        "Layout": "view_quilt", "Light": "light_mode", "Look": "visibility", "Material": "layers", "Menus": "menu",
        "Motion": "animation", "Notifications": "notifications", "On the contour": "border_outer",
        "Opening bodies": "open_in_full", "Overview backdrop": "grid_view", "Pages": "view_carousel",
        "Per surface": "tune", "Placement": "location_on", "Player": "music_note", "Previews": "preview", "Player page": "album",
        "Resting Island": "pill", "Settings": "settings", "Shape": "rounded_corner", "Side panels": "dock_to_right",
        "Size": "straighten", "Spotlight": "search", "Text": "text_fields", "Timing": "timer", "Touch": "touch_app",
        "Tray": "inventory_2", "Visibility": "visibility", "Wallpaper": "wallpaper", "Wallpaper gallery": "photo_library",
        "Widgets": "widgets", "Windows": "select_window", "Workspaces": "view_column"
    })
    function valueText(spec: var): string {
        const value = Config.getNestedValue(spec.path, spec.fallback)
        switch (spec.kind) {
        case "switch": return value ? Translation.tr(spec.label) : ""
        case "choice": return Translation.tr(String(((IrisStyle.ryokuFrontend && spec.ryokuChoices !== undefined ? spec.ryokuChoices : spec.choices) ?? []).find(choice => choice.value === value)?.label ?? ""))
        case "range": return spec.zeroLabel && Number(value) === 0 ? Translation.tr(spec.zeroLabel)
            : Translation.tr(spec.label) + " " + Math.round(Number(value)) + (spec.unit ?? "")
        default: return ""
        }
    }
    function summaryOf(entry: var): string {
        Config.revision
        return entry.rows.map(spec => root.valueText(spec)).filter(text => text.length > 0).slice(0, 4).join(" · ")
    }
    function modifiedIn(entry: var): bool {
        Config.revision
        return entry.rows.some(spec => spec.fallback !== undefined && String(spec.path ?? "").startsWith("iris.")
            && !IrisOptions.same(Config.getNestedValue(spec.path, spec.fallback), spec.fallback))
    }

    property string requestedGroup: ""
    Timer {
        id: groupRequest
        property int tries: 0
        interval: 60
        repeat: true
        onRunningChanged: if (running) tries = 0
        onTriggered: {
            const wanted = root.requestedGroup.toLowerCase()
            const match = root.groups.find(group => group.title.toLowerCase() === wanted || group.key.toLowerCase() === wanted)
            if (match || ++tries > 20) {
                stop()
                root.requestedGroup = ""
                if (match) root.group = match.title
            }
        }
    }
    function applyRequest(): void {
        const request = String(GlobalStates.settingsOverlayRequestedSection ?? "").split("/")
        root.requestedSection = request[0] ?? ""
        if (request.length > 1) {
            root.requestedGroup = request.slice(1).join("/")
            groupRequest.restart()
        }
        GlobalStates.settingsOverlayRequestedSection = ""
        GlobalStates.settingsOverlayRequestedPage = -1
        // The legacy page index is ignored (Ryoku Hub owns non-frame pages), so the
        // requested section deep-links whenever it names a real section.
        if (root.requestedSection.length > 0 && root.sections.some(s => s.id === root.requestedSection)) {
            root.group = ""
            root.section = root.requestedSection
        }
    }
    function selectSection(id: string): void {
        root.group = ""
        root.section = id
        searchField.text = ""
    }
    Component.onCompleted: if (GlobalStates.settingsOverlayOpen) root.applyRequest()
    Connections {
        target: GlobalStates
        function onSettingsOverlayRequestedPageChanged(): void { Qt.callLater(root.applyRequest) }
        // A section deep-link (`iris settings <section>`, an "Edit in Studio" jump)
        // arriving while the overlay is already open must still navigate; the page
        // index no longer changes, so react to the section itself.
        function onSettingsOverlayRequestedSectionChanged(): void {
            if (String(GlobalStates.settingsOverlayRequestedSection ?? "").length > 0) Qt.callLater(root.applyRequest)
        }
        function onSettingsOverlayOpenChanged(): void { if (GlobalStates.settingsOverlayOpen) root.applyRequest() }
    }
    onSectionChanged: pageEnter.restart()
    onGroupChanged: { settingsFlick.contentY = 0; pageEnter.restart() }

    visible: GlobalStates.settingsOverlayOpen || frame.progress > 0
    IrisOutputHold {
        id: outputHold
        wanted: GlobalStates.focusedScreen
        live: root.visible
    }
    screen: outputHold.output
    color: "transparent"
    anchors { left: true; right: true; top: true; bottom: true }
    margins {
        left: IrisFrame.band
        right: IrisFrame.band
        top: IrisFrame.band
        bottom: IrisFrame.band
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:iris-settings"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    mask: GlobalStates.settingsOverlayOpen && frame.armed ? null : frameRegion
    Region { id: frameRegion; item: frame }
    Shortcut {
        sequence: "Escape"
        enabled: GlobalStates.settingsOverlayOpen
        onActivated: {
            if (root.query.length > 0) searchField.text = ""
            else if (root.group.length > 0) root.group = ""
                        else GlobalStates.settingsOverlayOpen = false
        }
    }
    Shortcut { sequence: "Ctrl+F"; enabled: GlobalStates.settingsOverlayOpen; onActivated: searchField.forceActiveFocus() }
    MouseArea { anchors.fill: parent; onClicked: GlobalStates.settingsOverlayOpen = false }

    IrisMorphSurface {
        motionSurface: "settings"
        windowOffset: Qt.point(IrisFrame.band, IrisFrame.band)
        id: frame
        open: GlobalStates.settingsOverlayOpen
        light: IrisStyle.surfaceLight("settings", IrisStyle.wallpaperLight)
        radius: IrisStyle.surfaceRadius("settings", IrisStyle.radiusPanel)
        onClosed: GlobalStates.irisMorphOwner = ""
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: Math.min(parent.width - 32, 1180 * root.d)
        height: Math.min(parent.height - 48, 820 * root.d)
        MouseArea { anchors.fill: parent }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            Rectangle {
                id: sidebar
                readonly property int pad: IrisStyle.concentricPad(frame.radius, 12 * root.d)
                Layout.fillHeight: true
                Layout.preferredWidth: Math.min(236 * root.d, frame.width * 0.3)
                topLeftRadius: frame.radius
                bottomLeftRadius: frame.radius
                color: IrisStyle.glassy ? ColorUtils.applyAlpha(IrisStyle.surfaceOpaque, IrisStyle.wallpaperVeil) : IrisStyle.surfaceHigh
                Rectangle {
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    width: 1
                    color: IrisStyle.hairline
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: sidebar.pad
                    anchors.topMargin: sidebar.pad + 4 * root.d
                    spacing: 2 * root.d

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 10 * root.d
                        implicitHeight: Math.round(32 * root.d)
                        radius: Math.min(height / 2, Math.max(IrisStyle.radiusRow, frame.radius - sidebar.pad))
                        color: (searchField.activeFocus ? IrisStyle.fill : IrisStyle.fillQuiet)
                        border.width: searchField.activeFocus ? 1 : 0
                        border.color: IrisStyle.tintBorder(IrisStyle.accent)
                        MaterialSymbol {
                            id: searchGlyph
                            anchors.left: parent.left
                            anchors.leftMargin: 10 * root.d
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                            iconSize: Math.round(16 * root.d)
                            color: IrisStyle.muted
                        }
                        TextInput {
                            id: searchField
                            anchors.left: searchGlyph.right
                            anchors.leftMargin: 6 * root.d
                            anchors.right: parent.right
                            anchors.rightMargin: 12 * root.d
                            anchors.verticalCenter: parent.verticalCenter
                            color: IrisStyle.text
                            selectionColor: IrisStyle.accentContainer
                            font.family: IrisStyle.fontMain
                            font.pixelSize: 13 * IrisStyle.typeScale
                            clip: true
                            onTextChanged: {
                                if (text.length === 0) { searchDelay.stop(); root.query = ""; return }
                                        searchDelay.restart()
                            }
                            Timer { id: searchDelay; interval: 160; onTriggered: root.query = searchField.text }
                            IrisText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: searchField.text.length === 0
                                text: Translation.tr("Search")
                                color: IrisStyle.muted
                                font.pixelSize: searchField.font.pixelSize
                            }
                        }
                    }

                    Repeater {
                        model: root.sections
                        MouseArea {
                            id: sectionRow
                            required property var modelData
                            readonly property bool selected: root.query.length === 0 && root.section === sectionRow.modelData.id
                            Layout.fillWidth: true
                            implicitHeight: Math.round(36 * root.d)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Button
                            Accessible.name: Translation.tr(sectionRow.modelData.title)
                            onClicked: root.selectSection(sectionRow.modelData.id)
                            Rectangle {
                                anchors.fill: parent
                                radius: IrisStyle.radiusRow
                                color: sectionRow.selected ? (IrisStyle.ryokuFrontend ? IrisStyle.accentContainer : IrisStyle.tintFill(IrisStyle.accent))
                                    : sectionRow.containsMouse ? IrisStyle.fillHover : "transparent"
                                Behavior on color { ColorAnimation { duration: IrisStyle.duration(110) } }
                            }
                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 8 * root.d
                                anchors.rightMargin: 10 * root.d
                                spacing: 10 * root.d
                                IrisText {
                                    visible: IrisStyle.ryokuFrontend && sectionRow.selected
                                    text: "//"
                                    color: IrisStyle.onAccentContainer
                                    font.family: IrisStyle.fontNumbers
                                    font.pixelSize: 11 * IrisStyle.typeScale
                                }
                                Rectangle {
                                    visible: !IrisStyle.ryokuFrontend
                                    implicitWidth: Math.round(24 * root.d)
                                    implicitHeight: implicitWidth
                                    radius: IrisStyle.radiusChip
                                    color: sectionRow.modelData.tint
                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: sectionRow.modelData.icon
                                        iconSize: Math.round(15 * root.d)
                                        fill: 1
                                        color: IrisStyle.onTint
                                    }
                                }
                                IrisText {
                                    Layout.fillWidth: true
                                    text: Translation.tr(sectionRow.modelData.title)
                                    color: IrisStyle.ryokuFrontend && sectionRow.selected ? IrisStyle.onAccentContainer : IrisStyle.text
                                    font.pixelSize: 13 * IrisStyle.typeScale
                                    font.weight: sectionRow.selected ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                }
                                IrisText {
                                    visible: IrisStyle.ryokuFrontend
                                    text: root.jpName[sectionRow.modelData.id] ?? ""
                                    color: sectionRow.selected ? IrisStyle.onAccentContainer : IrisStyle.muted
                                    font.family: Tokens.jp
                                    font.pixelSize: 12 * IrisStyle.typeScale
                                }
                                IrisText {
                                    readonly property int count: root.specifications.filter(spec => spec.section === sectionRow.modelData.id).length
                                    visible: !IrisStyle.ryokuFrontend && count > 0
                                    text: count
                                    color: IrisStyle.textTertiary
                                    font.family: IrisStyle.fontNumbers
                                    font.features: ({ "tnum": 1 })
                                    font.pixelSize: 11.5 * IrisStyle.typeScale
                                }
                            }
                        }
                    }

                    Item { Layout.fillHeight: true }

                    Item {
                        Layout.fillWidth: true
                        Layout.bottomMargin: 4 * root.d
                        implicitHeight: Math.max(footerMark.implicitHeight, footerText.implicitHeight, frontendSwitch.implicitHeight)
                        // The rail rows reach the content edge with a 10 px right pad;
                        // the look switch is anchored to that same edge so it reads with
                        // the rows rather than cramped against the mark.
                        IrisMark {
                            id: footerMark
                            anchors.left: parent.left
                            anchors.leftMargin: 8 * root.d
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: Math.round(22 * root.d)
                        }
                        // Flips the whole iRiS family between Ryoku's paper-and-ink
                        // language and the upstream iNiR look, live. Kept here so a
                        // user on either look can always find the way back.
                        MouseArea {
                            id: frontendSwitch
                            readonly property bool ryoku: IrisStyle.ryokuFrontend
                            anchors.right: parent.right
                            anchors.rightMargin: 10 * root.d
                            anchors.verticalCenter: parent.verticalCenter
                            implicitWidth: Math.round(46 * root.d)
                            implicitHeight: Math.round(24 * root.d)
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            Accessible.role: Accessible.Switch
                            Accessible.name: Translation.tr("Ryoku look")
                            Accessible.checked: frontendSwitch.ryoku
                            onClicked: Config.setNestedValue("iris.appearance.frontend", frontendSwitch.ryoku ? "inir" : "ryoku")
                            Rectangle {
                                anchors.fill: parent
                                radius: height / 2
                                color: frontendSwitch.ryoku ? IrisStyle.accent : IrisStyle.fillHover
                                Behavior on color { ColorAnimation { duration: IrisStyle.duration(140) } }
                            }
                            Rectangle {
                                y: 2 * root.d
                                x: frontendSwitch.ryoku ? parent.width - width - 2 * root.d : 2 * root.d
                                width: parent.height - 4 * root.d
                                height: width
                                radius: width / 2
                                color: IrisStyle.onTint
                                scale: frontendSwitch.pressed ? IrisStyle.pressScale(0.9) : 1
                                Behavior on x { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
                                Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration } }
                                IrisText {
                                    anchors.centerIn: parent
                                    text: frontendSwitch.ryoku ? "力" : "i"
                                    color: frontendSwitch.ryoku ? IrisStyle.accent : IrisStyle.muted
                                    font.family: frontendSwitch.ryoku ? Tokens.jp : IrisStyle.fontMain
                                    font.pixelSize: 11 * IrisStyle.typeScale
                                    font.weight: Font.Bold
                                }
                            }
                        }
                        ColumnLayout {
                            id: footerText
                            anchors.left: footerMark.right
                            anchors.leftMargin: 8 * root.d
                            anchors.right: frontendSwitch.left
                            anchors.rightMargin: 8 * root.d
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0
                            IrisText { text: "iRiS"; font.pixelSize: 13 * IrisStyle.typeScale; font.weight: Font.DemiBold }
                            IrisText {
                                Layout.fillWidth: true
                                text: IrisStyle.ryokuFrontend ? Translation.tr("Ryoku look") : Translation.tr("By iNiR shell")
                                color: IrisStyle.muted
                                font.pixelSize: 11 * IrisStyle.typeScale
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 0

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 28 * root.d
                    Layout.rightMargin: IrisStyle.concentricPad(frame.radius, 14 * root.d)
                    Layout.topMargin: IrisStyle.concentricPad(frame.radius, 14 * root.d)
                    Layout.preferredHeight: Math.round(56 * root.d)
                    spacing: 8 * root.d
                    IrisIconButton {
                        visible: (root.group.length > 0 && root.query.length === 0)
                        materialIcon: "chevron_left"
                        onClicked: root.group = ""
                        Accessible.name: Translation.tr("Back")
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        IrisText {
                            Layout.fillWidth: true
                            text: root.query.length > 0 ? Translation.tr("Results for “%1”").arg(root.query)

                                : root.group.length > 0 ? root.group
                                : Translation.tr(root.currentSection.title)
                            font.family: IrisStyle.fontTitle
                            font.pixelSize: 21 * IrisStyle.typeScale
                            font.weight: Font.Bold
                            elide: Text.ElideRight
                        }
                        IrisText {
                            Layout.fillWidth: true
                            visible: root.query.length === 0 
                            text: root.group.length > 0 ? Translation.tr(root.currentSection.title) : Translation.tr(root.currentSection.subtitle)
                            color: IrisStyle.muted
                            font.pixelSize: 12 * IrisStyle.typeScale
                            elide: Text.ElideRight
                        }
                    }
                    IrisButton {
                        readonly property string editTarget: ({ bar: "island", player: "bodies", bubbles: "pieces", dock: "dock", appearance: "material", desktop: "desktop", sidebars: "places", surfaces: "places" })[root.section] ?? ""
                        visible: root.query.length === 0 && editTarget.length > 0
                        quiet: true
                        text: Translation.tr("Edit in place")
                        buttonRadius: height / 2
                        onClicked: {
                            GlobalStates.settingsOverlayOpen = false
                            GlobalStates.irisEditTarget = editTarget
                            GlobalStates.irisEdit = true
                        }
                    }
                    IrisButton {
                        readonly property string studioTarget: ({ bar: "island", player: "bodies", bubbles: "pieces", dock: "dock", appearance: "material", desktop: "desktop", sidebars: "places", surfaces: "places" })[root.section] ?? ""
                        visible: root.query.length === 0 && studioTarget.length > 0
                        emphasized: true
                        text: Translation.tr("Edit the look in Studio")
                        buttonRadius: height / 2
                        onClicked: { GlobalStates.settingsOverlayOpen = false; GlobalStates.irisStudioTarget = studioTarget; GlobalStates.irisStudioOpen = true }
                    }
                    IrisButton {
                        readonly property var resettable: (root.group.length > 0 ? (root.shownGroups[0]?.rows ?? []) : root.specifications
                            .filter(spec => spec.section === root.section)).filter(spec => String(spec.path).startsWith("iris."))
                        readonly property bool modified: {
                            Config.revision
                            return resettable.some(spec => JSON.stringify(Config.getNestedValue(spec.path, spec.fallback)) !== JSON.stringify(spec.fallback))
                        }
                        visible: root.query.length === 0 && modified
                        quiet: true
                        text: Translation.tr("Restore defaults")
                        buttonRadius: height / 2
                        onClicked: resettable.forEach(spec => Config.setNestedValue(spec.path, spec.fallback))
                    }
                    IrisIconButton {
                        materialIcon: "close"
                        onClicked: GlobalStates.settingsOverlayOpen = false
                        Accessible.name: Translation.tr("Close settings")
                    }
                }

                Item {
                    id: pageArea
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true

                    ParallelAnimation {
                        id: pageEnter
                        NumberAnimation { target: pageArea; property: "opacity"; from: 0.35; to: 1; duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing }
                        NumberAnimation { target: pageShift; property: "y"; from: 10 * root.d; to: 0; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
                    }
                    transform: Translate { id: pageShift }

                    Flickable {
                        id: settingsFlick
                        anchors.fill: parent
                        contentHeight: settingsRows.implicitHeight + 28 * root.d
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                        NumberAnimation on contentY { id: scrollTo; running: false; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }

                        ColumnLayout {
                            id: settingsRows
                            y: 8 * root.d
                            width: root.group.length > 0 && root.query.length === 0
                                ? Math.min(settingsFlick.width - 56 * root.d, 820 * root.d) : settingsFlick.width - 56 * root.d
                            x: Math.round((settingsFlick.width - width) / 2)
                            spacing: 20 * root.d

                            Rectangle {
                                id: guide
                                Layout.fillWidth: true
                                visible: root.browsing && String(root.currentSection.tip ?? "").length > 0
                                implicitHeight: guideContent.implicitHeight + 24 * root.d
                                radius: IrisStyle.radiusCard
                                color: IrisStyle.surfaceHigh
                                border.width: IrisStyle.ryokuFrontend ? 1 : 0
                                border.color: IrisStyle.hairline
                                gradient: IrisStyle.ryokuFrontend ? null : guideGrad
                                Gradient {
                                    id: guideGrad
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: ColorUtils.mix(IrisStyle.surfaceHigh, root.currentSection.tint, 0.84) }
                                    GradientStop { position: 0.6; color: IrisStyle.surfaceHigh }
                                }
                                ColumnLayout {
                                    id: guideContent
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: 12 * root.d
                                    anchors.rightMargin: 14 * root.d
                                    spacing: 8 * root.d
                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 12 * root.d
                                        Rectangle {
                                            Layout.alignment: Qt.AlignTop
                                            implicitWidth: Math.round(34 * root.d)
                                            implicitHeight: implicitWidth
                                            radius: IrisStyle.iconRadius(width)
                                            color: "transparent"
                                            border.width: IrisStyle.ryokuFrontend ? 1 : 0
                                            border.color: IrisStyle.hairline
                                            gradient: IrisStyle.ryokuFrontend ? null : guideIconGrad
                                            Gradient {
                                                id: guideIconGrad
                                                GradientStop { position: 0; color: Qt.lighter(root.currentSection.tint, 1.2) }
                                                GradientStop { position: 1; color: root.currentSection.tint }
                                            }
                                            MaterialSymbol { anchors.centerIn: parent; text: root.currentSection.icon; fill: 1; iconSize: Math.round(20 * root.d); color: IrisStyle.ryokuFrontend ? IrisStyle.text : IrisStyle.onTint }
                                        }
                                        IrisText {
                                            Layout.fillWidth: true
                                            Layout.alignment: Qt.AlignVCenter
                                            text: Translation.tr(root.currentSection.tip ?? "")
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                            color: IrisStyle.subtext
                                            font.pixelSize: 12.5 * IrisStyle.typeScale
                                        }
                                    }
                                }
                            }

                            IrisGroupPreview {
                                id: groupPreview
                                Layout.fillWidth: true
                                Layout.preferredHeight: groupPreview.wantedHeight
                                section: root.section
                                group: root.query.length === 0 && root.group.length > 0 ? String(root.shownGroups[0]?.key ?? "") : ""
                                visible: root.query.length === 0 && available
                                playing: visible && GlobalStates.settingsOverlayOpen
                            }

                            Loader {
                                id: sectionPreview
                                readonly property string mapped: ({ player: "bodies", bubbles: "pieces", dock: "dock", appearance: "material",
                                    desktop: "desktop", sidebars: "places", surfaces: "transients" })[root.section] ?? ""
                                Layout.fillWidth: true
                                Layout.preferredHeight: mapped === "material" ? Math.max(Math.round(380 * root.d), Number(sectionPreview.item?.specimenHeight ?? 0)) : Math.round(220 * root.d)
                                active: root.previews && root.query.length === 0 && mapped.length > 0 && !groupPreview.available
                                visible: active
                                sourceComponent: IrisTargetPreview {
                                    target: sectionPreview.mapped
                                    playing: sectionPreview.visible && GlobalStates.settingsOverlayOpen
                                }
                            }

                            Loader {
                                Layout.fillWidth: true
                                Layout.preferredHeight: Math.round((IrisFrame.islandEdge === "left" || IrisFrame.islandEdge === "right" ? 320 : 168) * root.d)
                                active: root.previews && root.section === "bar" && root.query.length === 0 && !groupPreview.available
                                visible: active
                                sourceComponent: IrisScreenPreview {
                                    id: islandPreview
                                    screen: root.screen
                                    focusRect: islandPreview.islandReach
                                }
                            }

                            IrisText {
                                visible: root.query.length > 0 && root.entries.length === 0
                                Layout.topMargin: 24 * root.d
                                Layout.alignment: Qt.AlignHCenter
                                text: Translation.tr("No matching settings")
                                color: IrisStyle.muted
                            }

                            GridLayout {
                                id: groupCards
                                Layout.fillWidth: true
                                visible: root.browsing && root.section !== "system"
                                columns: settingsRows.width >= 860 * root.d ? 3 : settingsRows.width >= 520 * root.d ? 2 : 1
                                columnSpacing: 12 * root.d
                                rowSpacing: 12 * root.d
                                Repeater {
                                    model: groupCards.visible ? root.groups : []
                                    GroupCard {}
                                }
                            }

                            RowLayout {
                                id: groupColumns
                                Layout.fillWidth: true
                                visible: root.shownGroups.length > 0
                                spacing: 16 * root.d
                                readonly property int count: root.query.length > 0 && settingsRows.width >= 720 * root.d && root.shownGroups.length > 1 ? 2 : 1
                                readonly property var split: {
                                    const weight = spec => ({ range: 1.7, zone: 2.6, pieces: 2.4, curve: 4.4, hue: 1.7 })[spec.kind]
                                        ?? (spec.kind === "choice" && (spec.choices ?? []).length > 3 ? 2 : 1)
                                    const columns = Array.from({ length: groupColumns.count }, () => ({ height: 0, groups: [] }))
                                    root.shownGroups.forEach((group, index) => {
                                        const target = columns.reduce((low, column) => column.height < low.height ? column : low, columns[0])
                                        target.groups.push(Object.assign({ index: index }, group))
                                        target.height += 1.2 + group.rows.reduce((sum, spec) => sum + weight(spec), 0)
                                    })
                                    return columns.map(column => column.groups)
                                }
                                Repeater {
                                    model: groupColumns.count
                                    ColumnLayout {
                                        id: groupColumn
                                        required property int index
                                        Layout.fillWidth: true
                                        Layout.preferredWidth: 1
                                        Layout.alignment: Qt.AlignTop
                                        spacing: 20 * root.d
                                        Repeater {
                                            model: groupColumns.split[groupColumn.index] ?? []
                                            GroupBlock {}
                                        }
                                    }
                                }
                            }

                            IrisText {
                                visible: root.query.length > 0 && root.matches.length > root.entries.length
                                Layout.alignment: Qt.AlignHCenter
                                Layout.topMargin: 4 * root.d
                                text: Translation.tr("%1 more — keep typing to narrow the results").arg(root.matches.length - root.entries.length)
                                color: IrisStyle.muted
                                font.pixelSize: 12 * IrisStyle.typeScale
                            }

                            LinkCard {
                                visible: root.section === "sidebars" && root.browsing
                                links: [
                                    { label: Translation.tr("Open Focus"), icon: "dock_to_left", action: () => { GlobalStates.settingsOverlayOpen = false; GlobalStates.openSidebarLeft("") } },
                                    { label: Translation.tr("Open Today"), icon: "dock_to_right", action: () => { GlobalStates.settingsOverlayOpen = false; GlobalStates.openSidebarRight("") } }
                                ]
                            }

                            Repeater {
                                model: root.section === "sidebars" && root.browsing ? ["left", "right"] : []
                                ColumnLayout {
                                    id: panelEditor
                                    required property string modelData
                                    Layout.fillWidth: true
                                    spacing: 8 * root.d
                                    IrisText { text: panelEditor.modelData === "left" ? Translation.tr("Focus sections") : Translation.tr("Today sections"); color: IrisStyle.muted }
                                    IrisSidebarEditor { Layout.fillWidth: true; side: panelEditor.modelData }
                                }
                            }
                        }
                    }
                }
            }
        }
    }


    component GroupBlock: ColumnLayout {
        id: group
        required property var modelData
        Layout.fillWidth: true
        spacing: 6 * root.d
        IrisText {
            visible: root.query.length > 0
            Layout.leftMargin: 16 * root.d
            text: group.modelData.title
            color: IrisStyle.label
            font.family: IrisStyle.fontTitle
            font.pixelSize: 12 * IrisStyle.typeScale
            font.weight: Font.DemiBold
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: groupRows.implicitHeight
            radius: IrisStyle.radiusTile
            color: IrisStyle.surfaceHigh
            ColumnLayout {
                id: groupRows
                anchors.left: parent.left
                anchors.right: parent.right
                spacing: 0
                Repeater {
                    model: group.modelData.rows
                    IrisSetting {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        spec: modelData
                        last: index === group.modelData.rows.length - 1
                    }
                }
            }
        }
    }

    component GroupCard: MouseArea {
        id: card
        required property var modelData
        readonly property string summary: root.summaryOf(card.modelData)
        readonly property bool modified: root.modifiedIn(card.modelData)
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.maximumWidth: Number.POSITIVE_INFINITY
        implicitHeight: Math.round(122 * root.d)
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.Button
        Accessible.name: card.modelData.title
        Accessible.description: card.summary
        onClicked: root.group = card.modelData.title
        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.radiusCard
            color: card.containsMouse ? IrisStyle.surfaceHighest : IrisStyle.surfaceHigh
            scale: card.pressed ? IrisStyle.pressScale(0.97) : 1
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120) } }
            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration } }
        }
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 14 * root.d
            spacing: 4 * root.d
            RowLayout {
                Layout.fillWidth: true
                Layout.bottomMargin: 4 * root.d
                spacing: 8 * root.d
                Rectangle {
                    implicitWidth: Math.round(30 * root.d)
                    implicitHeight: implicitWidth
                    radius: IrisStyle.iconRadius(width)
                    color: "transparent"
                    border.width: IrisStyle.ryokuFrontend ? 1 : 0
                    border.color: IrisStyle.hairline
                    gradient: IrisStyle.ryokuFrontend ? null : cardIconGrad
                    Gradient {
                        id: cardIconGrad
                        GradientStop { position: 0; color: Qt.lighter(root.currentSection.tint, 1.2) }
                        GradientStop { position: 1; color: root.currentSection.tint }
                    }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: root.groupGlyphs[card.modelData.key] ?? root.currentSection.icon
                        fill: 1
                        iconSize: Math.round(17 * root.d)
                        color: IrisStyle.ryokuFrontend ? IrisStyle.text : IrisStyle.onTint
                    }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    visible: card.modified
                    implicitWidth: Math.round(7 * root.d)
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: IrisStyle.accent
                    Accessible.name: Translation.tr("Changed")
                }
                MaterialSymbol {
                    text: "chevron_right"
                    iconSize: Math.round(18 * root.d)
                    color: card.containsMouse ? IrisStyle.text : IrisStyle.muted
                }
            }
            IrisText {
                Layout.fillWidth: true
                text: card.modelData.title
                font.pixelSize: 14 * IrisStyle.typeScale
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            IrisText {
                Layout.fillWidth: true
                Layout.fillHeight: true
                verticalAlignment: Text.AlignTop
                text: card.summary.length > 0 ? card.summary
                    : (card.modelData.rows.length === 1 ? Translation.tr("1 setting") : Translation.tr("%1 settings").arg(card.modelData.rows.length))
                color: IrisStyle.subtext
                font.pixelSize: 12 * IrisStyle.typeScale
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }
    }

    component LinkCard: Rectangle {
        id: card
        property var links: []
        Layout.fillWidth: true
        implicitHeight: linkColumn.implicitHeight
        radius: IrisStyle.radiusTile
        color: IrisStyle.surfaceHigh
        ColumnLayout {
            id: linkColumn
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 0
            Repeater {
                model: card.links
                MouseArea {
                    id: link
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: Math.round(44 * root.d)
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    Accessible.role: Accessible.Button
                    Accessible.name: link.modelData.label
                    onClicked: link.modelData.action()
                    Rectangle {
                        anchors.fill: parent
                        radius: card.radius
                        color: (link.containsMouse ? IrisStyle.fillQuiet : ColorUtils.applyAlpha(IrisStyle.text, 0))
                    }
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16 * root.d
                        anchors.rightMargin: 12 * root.d
                        spacing: 12 * root.d
                        MaterialSymbol {
                            text: link.modelData.icon
                            iconSize: Math.round(18 * root.d)
                            color: IrisStyle.subtext
                        }
                        IrisText {
                            Layout.fillWidth: true
                            text: link.modelData.label
                            font.pixelSize: 13.5 * IrisStyle.typeScale
                            font.weight: Font.Normal
                            elide: Text.ElideRight
                        }
                        MaterialSymbol {
                            text: "chevron_right"
                            iconSize: Math.round(18 * root.d)
                            color: IrisStyle.muted
                        }
                    }
                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.leftMargin: 46 * root.d
                        height: 1
                        visible: link.index < card.links.length - 1
                        color: IrisStyle.hairline
                    }
                }
            }
        }
    }
}
