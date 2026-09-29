pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import inir
import inir.services
import inir.services.deferred
import inir.modules.common
import inir.modules.common.functions
import inir.modules.common.models
import inir.modules.common.widgets
import inir.modules.iris.frame
import inir.modules.iris.style
import inir.modules.iris.components
import inir.modules.iris.pieces
import inir.modules.iris.field as Field

PanelWindow {
    id: root

    readonly property var options: Config.options?.iris?.palette ?? ({})
    readonly property int configuredResultLimit: Math.max(3, Math.min(14, Number(root.options?.maxResults ?? 8)))
    readonly property int heightResultLimit: Math.max(3, Math.floor(
        Math.max(180, ((root.screen?.height ?? 1080) * 0.72) - (120 * IrisStyle.density))
        / Math.max(42, 50 * IrisStyle.density)))
    readonly property int resultLimit: Math.min(root.configuredResultLimit, root.heightResultLimit)
    function edgeClear(edge: string): real {
        let held = IrisFrame.inset(edge)
        if ((Config.options?.iris?.dock?.enable ?? true) && IrisFrame.dockEdge === edge)
            held = Math.max(held, IrisFrame.band + IrisFrame.dockBand + IrisFrame.dockMargin)
        return held - IrisFrame.band + Math.round(12 * IrisStyle.density)
    }
    readonly property bool mathQuery: /[0-9]/.test(LauncherSearch.query)
    readonly property var searchResults: (LauncherSearch.results ?? [])
        .filter(entry => String(entry?.name ?? "").length > 0
            && (root.mathQuery || entry?.type !== Translation.tr("Math")))
        .slice(0, root.resultLimit)

    readonly property var island: GlobalStates.irisIslandGeometry?.[root.screen?.name ?? ""] ?? null
    readonly property bool fromIsland: String(root.options?.opens ?? "floating") === "island"
        && root.island !== null && root.island.width > 0
    readonly property bool islandBottom: root.island?.bottomEdge ?? false
    readonly property string islandSide: root.island?.vertical ? String(root.island.edge) : ""
    readonly property bool joinsEdge: root.fromIsland && IrisFrame.notch

    readonly property bool browsing: LauncherSearch.query.length === 0
    readonly property var suggestions: {
        return (TaskbarApps.apps ?? []).filter(app => app.appId !== "SEPARATOR").slice(0, 8).map(app => {
            const entry = AppSearch.lookupDesktopEntry(app.appId)
            const windows = app.toplevels ?? []
            return {
                appId: app.appId,
                name: entry?.name ?? app.appId,
                iconName: IrisPieces.appIcon(app.appId),
                iconType: LauncherSearchResult.IconType.System,
                running: windows.length > 0,
                verb: windows.length > 0 ? Translation.tr("Switch to") : Translation.tr("Open"),
                execute: () => {
                    const focused = windows.find(window => window.activated) ?? windows[0]
                    if (focused && CompositorService.nativeOverview && focused.nativeWindowId !== undefined)
                        WorkspaceService.focusWindow(focused.nativeWindowId)
                    else if (focused) focused.activate()
                    else if (entry) AppSearch.launchEntry(entry)
                }
            }
        })
    }
    readonly property var visibleResults: root.browsing ? root.suggestions : root.searchResults
    readonly property string clipboardPrefix: Config.options?.search?.prefix?.clipboard ?? ";"
    readonly property bool clipboardMode: LauncherSearch.query.startsWith(root.clipboardPrefix)
    onClipboardModeChanged: if (root.clipboardMode) Cliphist.refresh()
    property int selectedIndex: 0
    property bool pointerSelectionArmed: false
    property point lastPointerPosition: Qt.point(-1, -1)

    function disarmPointerSelection(resetPosition = false) {
        root.pointerSelectionArmed = false
        if (resetPosition)
            root.lastPointerPosition = Qt.point(-1, -1)
    }

    function armPointerSelection(area, event) {
        const point = area.mapToItem(root.contentItem, event.x, event.y)
        if (root.lastPointerPosition.x < 0 || root.lastPointerPosition.y < 0) {
            root.lastPointerPosition = Qt.point(point.x, point.y)
            return false
        }
        const moved = Math.abs(point.x - root.lastPointerPosition.x) > 0.5
            || Math.abs(point.y - root.lastPointerPosition.y) > 0.5
        root.lastPointerPosition = Qt.point(point.x, point.y)
        if (moved) root.pointerSelectionArmed = true
        return root.pointerSelectionArmed
    }

    visible: GlobalStates.searchOpen || (content.item?.progress ?? 0) > 0
    IrisOutputHold {
        id: outputHold
        wanted: GlobalStates.focusedScreen
        live: root.visible
    }
    screen: outputHold.output
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:iris-palette"
    WlrLayershell.keyboardFocus: GlobalStates.searchOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    margins {
        left: IrisFrame.band
        right: IrisFrame.band
        top: IrisFrame.band
        bottom: IrisFrame.band
    }
    mask: GlobalStates.searchOpen && (content.item?.armed ?? false)
        ? (GlobalStates.irisStudioRect ? studioMask : null) : capsuleRegion
    IrisStudioMask {
        id: studioMask
        canvasWidth: root.width
        canvasHeight: root.height
        originX: IrisFrame.band
        originY: IrisFrame.band
        screenName: root.screen?.name ?? ""
    }
    Region { id: capsuleRegion; item: content.item?.surfaceItem ?? null }

    function focusInput(): void {
        Qt.callLater(() => content.item?.focusInput())
    }

    function takeRequestedQuery(): void {
        if (GlobalStates.irisSpotlightQuery.length === 0) return
        LauncherSearch.query = GlobalStates.irisSpotlightQuery
        GlobalStates.irisSpotlightQuery = ""
    }
    Component.onCompleted: if (GlobalStates.searchOpen) { root.takeRequestedQuery(); root.focusInput() }

    Connections {
        target: GlobalStates
        function onSearchOpenChanged(): void {
            if (!GlobalStates.searchOpen) return
            root.selectedIndex = 0
            root.disarmPointerSelection(true)
            root.takeRequestedQuery()
            root.focusInput()
        }
    }

    onVisibleChanged: if (!visible) LauncherSearch.query = ""

    Connections {
        target: LauncherSearch
        function onQueryChanged(): void {
            root.selectedIndex = 0
            root.disarmPointerSelection()
        }
    }

    function executeSelected(): void {
        const entry = root.visibleResults[root.selectedIndex]
        if (!entry || typeof entry.execute !== "function") return
        entry.execute()
        GlobalStates.searchOpen = false
    }

    function moveSelection(step: int): void {
        const count = root.visibleResults.length
        if (count === 0) return
        root.selectedIndex = Math.max(0, Math.min(count - 1, root.selectedIndex + step))
    }

    function handleKey(event): void {
        const forward = event.key === Qt.Key_Down || event.key === Qt.Key_Tab
            || (root.browsing && event.key === Qt.Key_Right)
        const backward = event.key === Qt.Key_Up || event.key === Qt.Key_Backtab
            || (root.browsing && event.key === Qt.Key_Left)
        if (forward) {
            root.disarmPointerSelection()
            root.moveSelection(1)
        } else if (backward) {
            root.disarmPointerSelection()
            root.moveSelection(-1)
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            root.executeSelected()
        } else if (root.clipboardMode && event.key === Qt.Key_Delete) {
            const entry = root.visibleResults[root.selectedIndex]?.rawValue
            if (!entry) return
            Cliphist.deleteEntry(entry)
            root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, root.visibleResults.length - 2))
        } else {
            return
        }
        event.accepted = true
    }

    Shortcut {
        sequence: "Escape"
        enabled: GlobalStates.searchOpen
        onActivated: {
            if (LauncherSearch.query.length > 0) LauncherSearch.query = ""
            else GlobalStates.searchOpen = false
        }
    }

    MouseArea {
        anchors.fill: parent
        onClicked: GlobalStates.searchOpen = false
    }

    Loader {
        id: content
        anchors.fill: parent
        focus: true
        sourceComponent: spotlightComponent
    }

    Component {
        id: spotlightComponent

        Item {
            id: stage
            readonly property alias progress: surface.progress
            readonly property alias armed: surface.armed
            readonly property Item surfaceItem: surface
            readonly property real d: IrisStyle.density
            function focusInput(): void { input.forceActiveFocus() }

            function escapeHtml(value: string): string {
                return value.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
            }
            function emphasised(name: string): string {
                const query = LauncherSearch.query.trim()
                const at = query.length > 0 ? name.toLowerCase().indexOf(query.toLowerCase()) : -1
                const dim = IrisStyle.textSecondary
                if (at < 0) return stage.escapeHtml(name)
                return "<font color='" + dim + "'>" + stage.escapeHtml(name.slice(0, at)) + "</font>"
                    + "<b>" + stage.escapeHtml(name.slice(at, at + query.length)) + "</b>"
                    + "<font color='" + dim + "'>" + stage.escapeHtml(name.slice(at + query.length)) + "</font>"
            }

            function sectionOf(entry): string {
                const type = String(entry?.type ?? "")
                if (type === Translation.tr("App")) return Translation.tr("Applications")
                if (type === Translation.tr("Action")) return Translation.tr("Actions")
                if (type === Translation.tr("Math")) return Translation.tr("Calculator")
                if (type === Translation.tr("Command")) return Translation.tr("Run command")
                if (type === Translation.tr("Web")) return Translation.tr("Search the web")
                return type.length > 0 ? type : Translation.tr("Other")
            }
            function sectionAt(index: int): string {
                if (root.clipboardMode) return Translation.tr("Clipboard history")
                return index === 0 ? Translation.tr("Top hit") : stage.sectionOf(root.visibleResults[index])
            }

            RectangularShadow {
                x: surface.x + surface.lerp(surface.from.x, 0)
                y: surface.y + surface.lerp(surface.from.y, 0) + 8 * stage.d * surface.progress
                width: surface.lerp(surface.from.width, surface.width)
                height: surface.lerp(surface.from.height, surface.height)
                radius: Math.min(width / 2, height / 2, surface.lerp(surface.fromRadius, surface.radius))
                blur: 32 * stage.d
                spread: -6 * stage.d
                color: IrisStyle.shadow
                visible: !root.fromIsland
                opacity: IrisStyle.shadowAt(surface.progress)
            }
            Field.IrisField {
                anchors.fill: parent
                visible: root.joinsEdge
                framed: false
                opacity: surface.dissolve
                shapes: {
                    if (!root.joinsEdge || surface.progress <= 0) return []
                    const b = surface.bodyRect
                    const deep = Math.max(8, IrisStyle.fuseEdge)
                    return [
                        { x: -IrisStyle.fuseEdge, y: root.islandBottom ? stage.height + 1 : -deep - 1,
                            width: stage.width + 2 * IrisStyle.fuseEdge, height: deep, radius: 0, paints: true, fuse: 0, id: "edge" },
                        { x: b.x, y: root.islandBottom ? b.y : b.y - b.radius, width: b.width, height: b.height + b.radius,
                            radius: b.radius, paints: true, fuse: IrisStyle.fuseEdge, id: "spotlight", joins: "edge" }
                    ]
                }
            }
            IrisMorphSurface {
                id: surface
                open: GlobalStates.searchOpen
                motionSurface: "spotlight"
                windowOffset: Qt.point(IrisFrame.band, IrisFrame.band)
                readonly property real dissolve: root.fromIsland ? IrisStyle.ramp(surface.progress, 0, 0.14) : 1
                origin: root.fromIsland ? ({ x: root.island.x - IrisFrame.band, y: root.island.y - IrisFrame.band,
                    width: root.island.width, height: root.island.height, radius: Math.min(root.island.width, root.island.height) / 2 }) : null
                originShare: root.fromIsland ? 1 : IrisStyle.absorbShare
                color: root.fromIsland ? ColorUtils.applyAlpha(IrisStyle.bodySurface, surface.dissolve) : IrisStyle.surface
                light: root.fromIsland ? "transparent" : IrisStyle.surfaceLight("spotlight", IrisStyle.wallpaperLight)
                lightFrom: IrisFrame.islandEdge
                radius: IrisStyle.surfaceRadius("spotlight", IrisStyle.radiusPanel)
                width: Math.max(320, Math.min(root.width - 32, Math.max(480, Number(root.options?.width ?? 640) * stage.d)))
                x: !root.fromIsland ? (root.width - width) / 2
                    : root.islandSide === "left" ? Math.round(root.island.x - IrisFrame.band)
                    : root.islandSide === "right" ? Math.round(root.island.x - IrisFrame.band + root.island.width - width)
                    : Math.round(Math.max(8, Math.min(root.width - width - 8, root.island.x - IrisFrame.band + root.island.width / 2 - width / 2)))
                y: !root.fromIsland ? Math.max(72, Math.round(root.height * 0.2))
                    : root.islandSide.length > 0 ? Math.round(Math.max(8, Math.min(root.height - height - 8,
                        root.island.y - IrisFrame.band + root.island.height / 2 - height / 2)))
                    : root.islandBottom ? Math.round(root.island.y - IrisFrame.band + root.island.height - height)
                    : Math.round(root.island.y - IrisFrame.band)
                readonly property real room: {
                    const top = root.edgeClear("top")
                    const bottom = root.edgeClear("bottom")
                    if (root.fromIsland && root.islandSide.length > 0) return root.height - top - bottom
                    if (root.fromIsland && root.islandBottom) return root.island.y - IrisFrame.band + root.island.height - top
                    const y = root.fromIsland ? root.island.y - IrisFrame.band : Math.max(72, Math.round(root.height * 0.2))
                    return root.height - y - bottom
                }
                height: Math.min(body.implicitHeight, Math.max(Math.round(160 * stage.d), surface.room))
                onClosed: LauncherSearch.query = ""
                onSettledChanged: if (surface.settled && surface.open) stage.focusInput()
                Rectangle {
                    z: 100
                    visible: !root.joinsEdge
                    opacity: Math.max(0, (surface.progress - 0.85) / 0.15)
                    anchors.fill: parent
                    radius: surface.radius
                    color: "transparent"
                    border.width: 1
                    border.color: IrisStyle.border
                }
                Behavior on height {
                    enabled: surface.settled
                    NumberAnimation { duration: IrisStyle.duration(150); easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
                }

                MouseArea { anchors.fill: parent }

                GridLayout {
                    id: body
                    readonly property bool fieldLast: root.fromIsland && root.islandBottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: surface.height
                    columns: 1
                    rowSpacing: 0
                    columnSpacing: 0

                    Item {
                        Layout.row: body.fieldLast ? 3 : 0
                        Layout.fillWidth: true
                        implicitHeight: Math.round(68 * stage.d)

                        MaterialSymbol {
                            id: searchGlyph
                            anchors.left: parent.left
                            anchors.leftMargin: 24 * stage.d
                            anchors.verticalCenter: parent.verticalCenter
                            text: "search"
                            iconSize: Math.round(22 * stage.d)
                            color: input.text.length > 0 ? IrisStyle.accent : IrisStyle.subtext
                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120) } }
                        }
                        Rectangle {
                            id: modeToken
                            readonly property var modes: {
                                const prefix = Config.options?.search?.prefix ?? ({})
                                return [
                                    { key: prefix.clipboard ?? ";", label: Translation.tr("Clipboard"), glyph: "content_paste" },
                                    { key: prefix.math ?? "=", label: Translation.tr("Calculator"), glyph: "calculate" },
                                    { key: prefix.action ?? "/", label: Translation.tr("Actions"), glyph: "bolt" },
                                    { key: prefix.emojis ?? ":", label: Translation.tr("Emoji"), glyph: "mood" },
                                    { key: prefix.webSearch ?? "?", label: Translation.tr("Web"), glyph: "travel_explore" },
                                    { key: prefix.shellCommand ?? "$", label: Translation.tr("Command"), glyph: "terminal" }
                                ]
                            }
                            readonly property var mode: modeToken.modes.find(m => String(m.key).length > 0 && LauncherSearch.query.startsWith(m.key)) ?? null
                            visible: modeToken.mode !== null
                            anchors.right: parent.right
                            anchors.rightMargin: 16 * stage.d
                            anchors.verticalCenter: parent.verticalCenter
                            height: Math.round(26 * stage.d)
                            width: modeRow.implicitWidth + Math.round(20 * stage.d)
                            radius: height / 2
                            color: IrisStyle.tintFill(IrisStyle.accent)
                            Row {
                                id: modeRow
                                anchors.centerIn: parent
                                spacing: 5 * stage.d
                                MaterialSymbol {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modeToken.mode?.glyph ?? ""
                                    fill: 1
                                    iconSize: Math.round(14 * stage.d)
                                    color: IrisStyle.accent
                                }
                                IrisText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modeToken.mode?.label ?? ""
                                    color: IrisStyle.accent
                                    font.pixelSize: 12 * IrisStyle.typeScale
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                        TextInput {
                            id: input
                            anchors.left: searchGlyph.right
                            anchors.leftMargin: 12 * stage.d
                            anchors.right: modeToken.visible ? modeToken.left : parent.right
                            anchors.rightMargin: 20 * stage.d
                            anchors.verticalCenter: parent.verticalCenter
                            text: LauncherSearch.query
                            color: IrisStyle.text
                            selectionColor: IrisStyle.accentContainer
                            selectedTextColor: IrisStyle.onAccentContainer
                            font.family: IrisStyle.fontMain
                            font.pixelSize: Math.round(21 * IrisStyle.typeScale)
                            clip: true
                            focus: true
                            onTextChanged: if (LauncherSearch.query !== text) LauncherSearch.query = text
                            Keys.onPressed: event => root.handleKey(event)

                            IrisText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: input.text.length === 0
                                text: Translation.tr("Spotlight Search")
                                color: IrisStyle.muted
                                font.pixelSize: input.font.pixelSize
                                font.weight: Font.Normal
                            }
                        }
                    }

                    Rectangle {
                        Layout.row: body.fieldLast ? 2 : 1
                        Layout.fillWidth: true
                        Layout.leftMargin: 24 * stage.d
                        Layout.rightMargin: 24 * stage.d
                        implicitHeight: 1
                        visible: results.visible || browse.visible
                        color: IrisStyle.hairline
                    }

                    ColumnLayout {
                        id: browse
                        Layout.row: body.fieldLast ? 1 : 2
                        Layout.fillWidth: true
                        visible: root.browsing && (root.suggestions.length > 0 || hints.visible)
                        spacing: 0

                        IrisText {
                            visible: root.suggestions.length > 0
                            Layout.leftMargin: 24 * stage.d
                            Layout.topMargin: 16 * stage.d
                            text: Translation.tr("Suggestions")
                            color: IrisStyle.muted
                            font.pixelSize: 11.5 * IrisStyle.typeScale
                            font.weight: Font.DemiBold
                        }

                        Item {
                            id: tiles
                            visible: root.suggestions.length > 0
                            Layout.fillWidth: true
                            Layout.leftMargin: 16 * stage.d
                            Layout.rightMargin: 16 * stage.d
                            Layout.topMargin: 6 * stage.d
                            readonly property real tileWidth: width / 8
                            implicitHeight: Math.round(92 * stage.d)

                            Rectangle {
                                visible: root.suggestions.length > 0
                                x: Math.min(root.selectedIndex, root.suggestions.length - 1) * tiles.tileWidth + 2 * stage.d
                                width: tiles.tileWidth - 4 * stage.d
                                height: tiles.height
                                radius: IrisStyle.radiusTile
                                color: IrisStyle.tintFill(IrisStyle.accent)
                                Behavior on x { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
                            }

                            Row {
                                anchors.fill: parent
                                Repeater {
                                    id: tileRepeater
                                    // Keyed by app: suggestions rebuild on every window event.
                                    model: ScriptModel {
                                        objectProp: "appId"
                                        values: root.browsing ? root.suggestions : []
                                    }
                                    MouseArea {
                                        id: tile
                                        required property var modelData
                                        required property int index
                                        readonly property var live: root.suggestions[tile.index] ?? tile.modelData
                                        width: tiles.tileWidth
                                        height: tiles.height
                                        hoverEnabled: true
                                        cursorShape: root.pointerSelectionArmed ? Qt.PointingHandCursor : Qt.BlankCursor
                                        Accessible.role: Accessible.Button
                                        Accessible.name: tile.modelData.name
                                        onPositionChanged: event => {
                                            if (root.armPointerSelection(tile, event) && root.selectedIndex !== tile.index)
                                                root.selectedIndex = tile.index
                                        }
                                        onClicked: {
                                            root.pointerSelectionArmed = true
                                            root.selectedIndex = tile.index
                                            root.executeSelected()
                                        }

                                        SmartAppIcon {
                                            id: tileIcon
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            y: 12 * stage.d
                                            icon: tile.modelData.iconName
                                            fallback: "application-x-executable"
                                            iconSize: Math.round(46 * stage.d)
                                            scale: tile.pressed ? IrisStyle.pressScale(0.92) : 1
                                            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration } }
                                        }
                                        Rectangle {
                                            anchors.horizontalCenter: parent.horizontalCenter
                                            anchors.top: tileIcon.bottom
                                            anchors.topMargin: 3 * stage.d
                                            visible: tile.live.running
                                            width: 4 * stage.d
                                            height: width
                                            radius: width / 2
                                            color: IrisStyle.textTertiary
                                        }
                                        IrisText {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.leftMargin: 4 * stage.d
                                            anchors.rightMargin: 4 * stage.d
                                            anchors.bottom: parent.bottom
                                            anchors.bottomMargin: 8 * stage.d
                                            horizontalAlignment: Text.AlignHCenter
                                            text: tile.modelData.name
                                            elide: Text.ElideRight
                                            font.pixelSize: 11 * IrisStyle.typeScale
                                            color: root.selectedIndex === tile.index ? IrisStyle.text : IrisStyle.subtext
                                        }
                                    }
                                }
                            }
                        }

                        Rectangle {
                            visible: hints.visible
                            Layout.fillWidth: true
                            Layout.leftMargin: 24 * stage.d
                            Layout.rightMargin: 24 * stage.d
                            Layout.topMargin: 12 * stage.d
                            implicitHeight: 1
                            color: IrisStyle.hairline
                        }

                        GridLayout {
                            id: hints
                            columns: 3
                            columnSpacing: 8 * stage.d
                            rowSpacing: 4 * stage.d
                            visible: root.options?.showHints ?? true
                            Layout.fillWidth: true
                            Layout.leftMargin: 16 * stage.d
                            Layout.rightMargin: 16 * stage.d
                            Layout.topMargin: 12 * stage.d
                            Layout.bottomMargin: 20 * stage.d
                            Repeater {
                                model: {
                                    const prefix = Config.options?.search?.prefix ?? ({})
                                    return [
                                        { key: prefix.clipboard ?? ";", label: Translation.tr("Clipboard") },
                                        { key: prefix.math ?? "=", label: Translation.tr("Calculator") },
                                        { key: prefix.action ?? "/", label: Translation.tr("Actions") },
                                        { key: prefix.emojis ?? ":", label: Translation.tr("Emoji") },
                                        { key: prefix.webSearch ?? "?", label: Translation.tr("Web") },
                                        { key: prefix.shellCommand ?? "$", label: Translation.tr("Command") }
                                    ]
                                }
                                IrisButton {
                                    id: hint
                                    required property var modelData
                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    implicitHeight: Math.round(34 * stage.d)
                                    buttonRadius: IrisStyle.radiusRow
                                    buttonRadiusPressed: IrisStyle.radiusRow
                                    colBackground: "transparent"
                                    colBackgroundHover: IrisStyle.fillHover
                                    Accessible.name: hint.modelData.label
                                    onClicked: { LauncherSearch.query = hint.modelData.key; stage.focusInput() }
                                    RowLayout {
                                        id: hintRow
                                        anchors.fill: parent
                                        anchors.leftMargin: 10 * stage.d
                                        anchors.rightMargin: 10 * stage.d
                                        spacing: 8 * stage.d
                                        Rectangle {
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.preferredWidth: Math.max(20 * stage.d, keyText.implicitWidth + 8 * stage.d)
                                            Layout.preferredHeight: Math.round(20 * stage.d)
                                            radius: IrisStyle.radiusMicro
                                            color: hint.buttonHovered ? IrisStyle.tintFillHover(IrisStyle.accent) : IrisStyle.fill
                                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110) } }
                                            IrisText {
                                                id: keyText
                                                anchors.centerIn: parent
                                                text: hint.modelData.key
                                                color: hint.buttonHovered ? IrisStyle.accent : IrisStyle.subtext
                                                font.family: Appearance.font.family.monospace
                                                font.pixelSize: 11.5 * IrisStyle.typeScale
                                                font.weight: Font.Bold
                                            }
                                        }
                                        IrisText {
                                            Layout.alignment: Qt.AlignVCenter
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                            text: hint.modelData.label
                                            color: hint.buttonHovered ? IrisStyle.text : IrisStyle.subtext
                                            font.pixelSize: 12 * IrisStyle.typeScale
                                            font.weight: Font.Medium
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        id: results
                        Layout.row: body.fieldLast ? 0 : 3
                        Layout.fillWidth: true
                        visible: !root.browsing && LauncherSearch.query.length > 0
                        implicitHeight: resultColumn.implicitHeight + 16 * stage.d
                        Layout.fillHeight: true
                        Layout.minimumHeight: Math.min(results.implicitHeight, Math.round(96 * stage.d))
                        function reveal(index: int): void {
                            const target = resultRepeater.count > 0 ? resultRepeater.itemAt(index) : null
                            if (!target) return
                            const top = resultColumn.y + target.y + (index === 0 ? 0 : target.rowY)
                            const bottom = resultColumn.y + target.y + target.rowY + target.rowHeight
                            if (top < resultsFlick.contentY) resultsFlick.contentY = Math.max(0, top - 8 * stage.d)
                            else if (bottom > resultsFlick.contentY + resultsFlick.height)
                                resultsFlick.contentY = Math.min(resultsFlick.contentHeight - resultsFlick.height, bottom - resultsFlick.height + 8 * stage.d)
                        }
                        Connections {
                            target: root
                            function onSelectedIndexChanged(): void { results.reveal(root.selectedIndex) }
                        }
                        Connections {
                            target: LauncherSearch
                            function onQueryChanged(): void { resultsFlick.contentY = 0 }
                        }

                        Flickable {
                            id: resultsFlick
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: results.implicitHeight
                            clip: true
                            interactive: contentHeight > height + 1
                            boundsBehavior: Flickable.StopAtBounds

                            Rectangle {
                                id: highlight
                                readonly property Item target: resultRepeater.count > 0 ? resultRepeater.itemAt(root.selectedIndex) : null
                                visible: target !== null
                                x: 8 * stage.d
                                width: parent.width - 16 * stage.d
                                y: resultColumn.y + (target ? target.y + target.rowY : 0)
                                height: target?.rowHeight ?? 0
                                radius: IrisStyle.radiusTile
                                color: IrisStyle.tintFill(IrisStyle.accent)
                                Behavior on y { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                                Behavior on height { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                            }

                            Column {
                                id: resultColumn
                                y: 8 * stage.d
                                width: parent.width

                                Item {
                                    width: parent.width
                                    height: 44 * stage.d
                                    visible: root.visibleResults.length === 0
                                    IrisText {
                                        anchors.centerIn: parent
                                        text: Translation.tr("No results")
                                        color: IrisStyle.muted
                                    }
                                }

                                Repeater {
                                    id: resultRepeater
                                    model: root.browsing ? [] : root.visibleResults
                                    Column {
                                        id: result
                                        required property var modelData
                                        required property int index
                                        readonly property bool topHit: result.index === 0 && !root.clipboardMode
                                        readonly property bool mathHit: result.topHit && result.modelData?.type === Translation.tr("Math")
                                        readonly property bool clipImage: root.clipboardMode
                                            && Cliphist.entryIsImage(String(result.modelData?.rawValue ?? ""))
                                        readonly property bool selected: root.selectedIndex === result.index
                                        readonly property bool showHeader: result.index === 0
                                            || stage.sectionAt(result.index) !== stage.sectionAt(result.index - 1)
                                        readonly property real rowY: row.y
                                        readonly property real rowHeight: row.height
                                        width: resultColumn.width

                                        IrisText {
                                            visible: result.showHeader
                                            x: 20 * stage.d
                                            height: Math.round((result.index === 0 ? 24 : 30) * stage.d)
                                            verticalAlignment: Text.AlignBottom
                                            bottomPadding: 5 * stage.d
                                            text: stage.sectionAt(result.index)
                                            color: IrisStyle.muted
                                            font.pixelSize: 11.5 * IrisStyle.typeScale
                                            font.weight: Font.DemiBold
                                        }

                                        MouseArea {
                                            id: row
                                            x: 8 * stage.d
                                            width: parent.width - 16 * stage.d
                                            height: result.clipImage ? Math.max(40 * stage.d, thumbLoader.height + 14 * stage.d)
                                                : Math.round((result.mathHit ? 66 : result.topHit ? 58 : 40) * stage.d)
                                            hoverEnabled: true
                                            cursorShape: root.pointerSelectionArmed ? Qt.PointingHandCursor : Qt.BlankCursor
                                            Accessible.role: Accessible.Button
                                            Accessible.name: String(result.modelData?.name ?? "")
                                            onPositionChanged: event => {
                                                if (root.armPointerSelection(row, event) && !result.selected)
                                                    root.selectedIndex = result.index
                                            }
                                            onClicked: {
                                                root.pointerSelectionArmed = true
                                                root.selectedIndex = result.index
                                                root.executeSelected()
                                            }

                                            RowLayout {
                                                anchors.fill: parent
                                                anchors.leftMargin: 12 * stage.d
                                                anchors.rightMargin: 14 * stage.d
                                                spacing: 12 * stage.d

                                                Loader {
                                                    id: thumbLoader
                                                    active: result.clipImage
                                                    visible: active
                                                    Layout.preferredWidth: item?.implicitWidth ?? 0
                                                    Layout.preferredHeight: item?.implicitHeight ?? 0
                                                    sourceComponent: CliphistImage {
                                                        entry: String(result.modelData?.rawValue ?? "")
                                                        maxWidth: Math.round(220 * stage.d)
                                                        maxHeight: Math.round(120 * stage.d)
                                                        color: IrisStyle.fillQuiet
                                                        radius: IrisStyle.radiusRow
                                                    }
                                                }
                                                Item {
                                                    visible: !result.clipImage
                                                    readonly property real size: Math.round((result.topHit ? 38 : 24) * stage.d)
                                                    Layout.preferredWidth: size
                                                    Layout.preferredHeight: size
                                                    Loader {
                                                        anchors.fill: parent
                                                        active: result.modelData?.iconType === LauncherSearchResult.IconType.System
                                                        sourceComponent: SmartAppIcon {
                                                            icon: result.modelData?.iconName ?? "application-x-executable"
                                                            fallback: "application-x-executable"
                                                            iconSize: parent?.width ?? 24
                                                        }
                                                    }
                                                    Loader {
                                                        anchors.centerIn: parent
                                                        active: result.modelData?.iconType === LauncherSearchResult.IconType.Text
                                                        sourceComponent: IrisText {
                                                            text: result.modelData?.iconName ?? ""
                                                            font.pixelSize: Math.round((result.topHit ? 30 : 19) * IrisStyle.typeScale)
                                                        }
                                                    }
                                                    Rectangle {
                                                        anchors.fill: parent
                                                        visible: result.modelData?.iconType !== LauncherSearchResult.IconType.System
                                                            && result.modelData?.iconType !== LauncherSearchResult.IconType.Text
                                                        radius: width / 2
                                                        color: IrisStyle.fill
                                                        MaterialSymbol {
                                                            anchors.centerIn: parent
                                                            text: result.modelData?.iconName || "search"
                                                            iconSize: Math.round(parent.width * 0.56)
                                                            color: IrisStyle.text
                                                        }
                                                    }
                                                }

                                                ColumnLayout {
                                                    Layout.fillWidth: true
                                                    spacing: 1
                                                    IrisText {
                                                        Layout.fillWidth: true
                                                        readonly property bool emphasise: !root.clipboardMode && !result.mathHit
                                                            && result.modelData?.fontType !== LauncherSearchResult.FontType.Monospace
                                                        textFormat: emphasise || result.mathHit || result.clipImage ? Text.StyledText : Text.PlainText
                                                        text: result.clipImage
                                                            ? "<b>" + Translation.tr("Image") + "</b>" + (thumbLoader.item
                                                                ? "  <font color='" + IrisStyle.muted + "'>" + thumbLoader.item.imageWidth + " × " + thumbLoader.item.imageHeight + "</font>" : "")
                                                            : result.mathHit
                                                                ? "<font color='" + IrisStyle.secondaryAccent + "'>=</font> " + stage.escapeHtml(String(result.modelData?.name ?? ""))
                                                            : emphasise ? stage.emphasised(String(result.modelData?.name ?? ""))
                                                            : String(result.modelData?.name ?? "")
                                                        font.family: result.mathHit ? IrisStyle.fontMain
                                                            : result.modelData?.fontType === LauncherSearchResult.FontType.Monospace
                                                            ? Appearance.font.family.monospace : IrisStyle.fontMain
                                                        font.features: result.mathHit ? ({ "tnum": 1 }) : ({})
                                                        font.pixelSize: Math.round((result.mathHit ? 28 : result.topHit ? 16 : 13.5) * IrisStyle.typeScale)
                                                        font.weight: result.mathHit ? Font.Bold : result.topHit ? Font.DemiBold : Font.Normal
                                                        font.letterSpacing: result.mathHit ? -0.5 : 0
                                                        elide: Text.ElideRight
                                                    }
                                                    IrisText {
                                                        Layout.fillWidth: true
                                                        visible: result.topHit && text.length > 0
                                                        text: result.mathHit ? LauncherSearch.query
                                                            : result.modelData?.comment || result.modelData?.genericName || result.modelData?.type || ""
                                                        color: IrisStyle.subtext
                                                        font.pixelSize: 12 * IrisStyle.typeScale
                                                        elide: Text.ElideRight
                                                    }
                                                }

                                                IrisText {
                                                    visible: result.selected && text.length > 0
                                                    text: String(result.modelData?.verb ?? "")
                                                    color: IrisStyle.subtext
                                                    font.pixelSize: 12 * IrisStyle.typeScale
                                                }
                                                Rectangle {
                                                    visible: result.selected
                                                    Layout.preferredWidth: Math.round(24 * stage.d)
                                                    Layout.preferredHeight: Math.round(20 * stage.d)
                                                    radius: IrisStyle.radiusChip
                                                    color: IrisStyle.fill
                                                    MaterialSymbol {
                                                        anchors.centerIn: parent
                                                        text: "keyboard_return"
                                                        iconSize: Math.round(14 * stage.d)
                                                        color: IrisStyle.text
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}
