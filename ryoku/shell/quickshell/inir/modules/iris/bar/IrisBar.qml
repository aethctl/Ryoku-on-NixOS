pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import inir
import inir.services
import inir.modules.common
import inir.modules.iris.control
import inir.modules.iris.field
import inir.modules.iris.frame
import inir.modules.iris.stage
import inir.modules.iris.dock
import inir.modules.iris.edit
import inir.modules.iris.notificationPopup
import inir.modules.iris.style
import inir.modules.iris.components as IrisParts
import inir.modules.iris.pieces
import inir.modules.iris.settings

Scope {
    id: root

    readonly property var options: Config.options?.iris?.bar ?? ({})
    readonly property string edge: IrisFrame.islandEdge
    readonly property int barHeight: Math.max(32, Math.round(Number(root.options?.height ?? 42) * IrisStyle.density))
    readonly property int restMargin: Math.max(0, Math.round(Number(root.options?.margin ?? 8) * IrisStyle.density))
    readonly property int outerMargin: (root.options?.notch ?? false) ? 0 : root.restMargin
    signal islandRequested(bool expanded, string page)
    property string editScreen: ""
    Connections {
        target: GlobalStates
        function onIrisEditChanged(): void {
            if (GlobalStates.irisEdit) root.editScreen = GlobalStates.focusedScreen?.name ?? ""
        }
    }

    IpcHandler {
        target: "iris"
        function open(): void { GlobalStates.barOpen = true; root.islandRequested(true, "") }
        function page(name: string): void {
            if (!["media", "activity", "desktop", "tray", "tools", "next", "prev"].includes(name)) return
            GlobalStates.barOpen = true
            root.islandRequested(true, name)
        }
        function close(): void { root.islandRequested(false, "") }
        function toggle(): void {
            if (GlobalStates.irisIslandExpanded) root.islandRequested(false, "")
            else { GlobalStates.barOpen = true; root.islandRequested(true, "") }
        }
        function card(action: string): void {
            if (action === "pin") {
                Config.setNestedValue("iris.player.cardPinned", !(Config.options?.iris?.player?.cardPinned ?? false))
                return
            }
            const open = GlobalStates.irisBubbleCard?.kind === "media"
            if (action === "close" || (open && action !== "open")) { GlobalStates.irisBubbleCard = null; return }
            if (open) return
            GlobalStates.irisBubbleCardRequest = ""
            GlobalStates.irisBubbleCardRequest = "media"
        }
        function theme(action: string): string {
            const verb = String(action).split(":")[0]
            const arg = String(action).slice(verb.length + 1)
            switch (verb) {
            case "list":
                return IrisThemes.all.map(entry => `${entry.id}\t${entry.name}${entry.id === IrisThemes.activeId ? (IrisThemes.modified ? "  (active, changed)" : "  (active)") : ""}`).join("\n")
            case "apply": {
                const found = IrisThemes.find(arg)
                if (!found) return "Unknown theme: see `inir iris theme list`"
                IrisThemes.apply(found)
                return found.name
            }
            case "save":
                return IrisThemes.save(arg, "")
            case "import":
                if (arg.length === 0) return "import:<path to a theme .json>"
                IrisThemes.importFile(arg)
                return "Importing into " + IrisThemes.folder
            case "export": {
                const found = arg.length > 0 ? IrisThemes.find(arg)
                    : { id: IrisThemes.activeId, name: IrisThemes.active?.name ?? "My theme", values: IrisThemes.differences(IrisThemes.current()) }
                return found ? IrisThemes.exportText(found) : "Unknown theme"
            }
            case "folder":
                return IrisThemes.folder
            default:
                return "list | apply:<id> | save:<name> | import:<path> | export[:<id>] | folder"
            }
        }
        function settings(section: string): void {
            GlobalStates.openSettingsPage(-1, section)
        }
        function wallpaper(action: string): void {
            GlobalStates.wallpaperSelectorOpen = action !== "close"
        }
        function bubble(slot: string, place: string): string {
            const extra = IrisPieces.extraIds.includes(slot)
            if (!extra && !IrisPieces.slotIds.includes(slot)) return "Unknown bubble"
            const zones = IrisPieces.zones
            const path = IrisPieces.configPath(slot)
            const updates = {}
            if ((extra && place === "off") || (!extra && place === "island")) {
                updates[path + (extra ? ".enable" : ".place")] = extra ? false : "island"
            } else if (zones.includes(place)) {
                updates[path + ".place"] = place
            } else if (/^edge:(top|bottom|left|right)(:\d*\.?\d+)?$/.test(place)) {
                const parts = place.split(":")
                updates[path + ".place"] = "edge:" + parts[1]
                const along = Math.min(1, Number(parts[2] ?? 0.5))
                updates[path + (parts[1] === "top" || parts[1] === "bottom" ? ".fx" : ".fy")] = along
            } else {
                const m = String(place).match(/^(\d*\.?\d+),(\d*\.?\d+)$/)
                if (!m) return "Unknown place: a zone, x,y fractions, or island/off"
                updates[path + ".fx"] = Math.min(1, Number(m[1]))
                updates[path + ".fy"] = Math.min(1, Number(m[2]))
                updates[path + ".place"] = "free"
            }
            if (extra && place !== "off") updates[path + ".enable"] = true
            Config.setNestedValues(updates)
            return place
        }
        function dock(action: string): void {
            GlobalStates.irisDockShown = action === "reveal" ? true : action === "hide" ? false : !GlobalStates.irisDockShown
        }
        function dockApp(appId: string, mode: string): string {
            if (mode === "close") { GlobalStates.irisDockMenuRequest = { appId: "", mode: "close" }; GlobalStates.irisDockShown = false; return "closed" }
            if (mode !== "windows" && mode !== "menu") return "Unknown mode: windows, menu or close"
            GlobalStates.irisDockMenuRequest = { appId: appId, mode: mode }
            return appId
        }
        function appBubble(appId: string, place: string): string {
            if (appId.length === 0) return "Unknown app"
            if (place === "dock" || place === "off") { IrisPieces.removeApp(appId); return "docked" }
            if (IrisPieces.zones.includes(place)) { IrisPieces.placeApp(appId, place, 0.5, 0.5); return place }
            const m = String(place).match(/^(\d*\.?\d+),(\d*\.?\d+)$/)
            if (!m) return "Unknown place: a zone, x,y fractions, or dock"
            IrisPieces.placeApp(appId, "free", Math.min(1, Number(m[1])), Math.min(1, Number(m[2])))
            return place
        }
        function pin(side: string): void {
            if (side !== "left" && side !== "right") return
            const path = "iris.sidebars." + side + ".pinned"
            Config.setNestedValue(path, !(Config.getNestedValue(path, false)))
        }
        function layout(name: string): string {
            if (!["island", "left", "right", "full"].includes(name)) return "Unknown layout: island, left, right or full"
            Config.setNestedValue("iris.bar.layout", name)
            return name
        }
        function edge(name: string): string {
            if (!IrisFrame.edges.includes(name)) return "Unknown edge: top, bottom, left or right"
            Config.setNestedValue("iris.bar.position", name)
            return name
        }
        function dockEdge(name: string): string {
            if (name !== "auto" && !IrisFrame.edges.includes(name)) return "Unknown edge: auto, top, bottom, left or right"
            Config.setNestedValue("iris.dock.position", name)
            return IrisFrame.dockEdge
        }
        function zone(name: string, kinds: string): string {
            const path = ({ start: "iris.bar.fullStart", center: "iris.bar.fullCenter", end: "iris.bar.fullEnd" })[name]
            if (!path) return "Unknown zone: start, center or end"
            const list = String(kinds).split(/[+\s]+/).filter(kind => kind.length > 0 && kind !== "none")
            Config.setNestedValue(path, list)
            return JSON.stringify(list)
        }
        function barPiece(kind: string, action: string): string {
            if (!IrisPieces.extraIds.includes(kind)) return "Unknown piece"
            const current = Array.from(Config.options?.iris?.bar?.pieces ?? [])
            const on = current.includes(kind)
            const wanted = action === "on" ? true : action === "off" ? false : !on
            if (wanted === on) return on ? "on" : "off"
            const next = current.filter(entry => entry !== kind)
            if (wanted) next.push(kind)
            Config.setNestedValue("iris.bar.pieces", next)
            return wanted ? "on" : "off"
        }
        function arrange(action: string): string {
            const wanted = action === "on" ? true : action === "off" ? false : !GlobalStates.irisArrange
            if (wanted) GlobalStates.irisIslandPageRequest = "desktop"
            GlobalStates.irisArrange = wanted
            return wanted ? "on" : "off"
        }
        function edit(action: string): string {
            if (action.startsWith("tab:")) {
                const tab = action.slice(4)
                if (!["pieces", "look", "motion", "layout"].includes(tab)) return "Unknown tab"
                GlobalStates.irisEditTab = tab
                GlobalStates.irisEdit = true
                return action
            }
            if (!["on", "off", "toggle", ""].includes(action)) {
                GlobalStates.irisEdit = true
                if (IrisPieces.extraIds.includes(action)) GlobalStates.irisEditSelection = "extra:" + action
                else if (IrisPieces.slotIds.includes(action) || IrisPieces.isApp(action)) GlobalStates.irisEditSelection = action
                else GlobalStates.irisEditTarget = action
                return action
            }
            const wanted = action === "on" ? true : action === "off" ? false : !GlobalStates.irisEdit
            GlobalStates.irisEdit = wanted
            return wanted ? "on" : "off"
        }
        function studio(action: string): string {
            if (!["on", "off", "toggle"].includes(action)) {
                GlobalStates.irisStudioTarget = action
                GlobalStates.irisStudioOpen = true
                return action
            }
            const wanted = action === "on" ? true : action === "off" ? false : !GlobalStates.irisStudioOpen
            GlobalStates.irisStudioOpen = wanted
            return wanted ? "on" : "off"
        }
        function notch(action: string): string {
            const on = Config.options?.iris?.bar?.notch ?? false
            const wanted = action === "on" ? true : action === "off" ? false : !on
            Config.setNestedValue("iris.bar.notch", wanted)
            return wanted ? "on" : "off"
        }
        function surround(action: string): string {
            const on = Config.options?.iris?.surround?.enable ?? false
            const wanted = action === "on" ? true : action === "off" ? false : !on
            Config.setNestedValue("iris.surround.enable", wanted)
            return wanted ? "on" : "off"
        }
        function accent(name: string): string {
            if (!["blue", "mint", "rose", "lilac", "wallpaper"].includes(name)) return "Unknown accent"
            Config.setNestedValue("iris.appearance.accent", name)
            return String(Config.options.iris.appearance.accent)
        }
        function spotlight(query: string): void {
            GlobalStates.irisSpotlightQuery = query
            GlobalStates.searchOpen = true
        }
        function bubbleCard(kind: string): string {
            if (kind === "close") { GlobalStates.irisBubbleCard = null; return "closed" }
            if (!IrisPieces.cardIds.includes(kind)) return "Unknown card"
            GlobalStates.irisBubbleCardRequest = ""
            GlobalStates.irisBubbleCardRequest = kind
            return kind
        }
        function bubbleMenu(kind: string): string {
            if (kind.length === 0) return "Which bubble?"
            GlobalStates.irisBubbleMenuRequest = ""
            GlobalStates.irisBubbleMenuRequest = kind
            return kind
        }
        function morph(name: string): string {
            if (!Object.keys(IrisStyle.morphStyles).includes(name)) return "Unknown morph style"
            Config.setNestedValue("iris.appearance.morph", name)
            return name
        }
        function activity(action: string, id: string, value: string): string {
            let result = null
            switch (action) {
            case "start": result = LiveActivities.start(id, value); break
            case "title": result = LiveActivities.setTitle(id, value); break
            case "progress": result = LiveActivities.setProgress(id, value); break
            case "detail": result = LiveActivities.setDetail(id, value); break
            case "glyph": result = LiveActivities.setGlyph(id, value); break
            case "tint": result = LiveActivities.setTint(id, value); break
            case "end": result = LiveActivities.end(id, value); break
            case "dismiss": LiveActivities.dismiss(id); return "dismissed"
            case "clear": LiveActivities.clear(); return "cleared"
            default: return "Unknown action: start, title, progress, detail, glyph, tint, end, dismiss, clear"
            }
            return result ? JSON.stringify(result) : "No activity " + id
        }
        function activities(): string {
            return JSON.stringify(LiveActivities.active)
        }
        function set(path: string, value: string): string {
            if (!path.startsWith("iris.")) return "Only iris.* options"
            let parsed = value
            try { parsed = JSON.parse(value) } catch (error) {}
            Config.setNestedValue(path, parsed)
            return JSON.stringify(Config.getNestedValue(path, null))
        }
        function adaptive(amount: string): string {
            const value = Math.round(Number(amount))
            if (isNaN(value)) return JSON.stringify({ strength: IrisMood.strength, luminance: IrisMood.luminance,
                contrast: IrisMood.contrast, colorfulness: IrisMood.colorfulness, colors: IrisMood.colors.length,
                sampled: IrisMood.sampled, glassTint: IrisStyle.glassTint })
            Config.setNestedValue("iris.appearance.adaptive", Math.max(0, Math.min(100, value)))
            return String(Math.max(0, Math.min(100, value)))
        }
        function preset(name: string): string {
            if (!Object.keys(IrisStyle.presets).includes(name)) return "Unknown preset"
            Config.setNestedValue("iris.appearance.preset", name)
            return String(Config.options.iris.appearance.preset)
        }
        function utility(name: string): string {
            if (!["tray", "tools", "sound", "mic", "none"].includes(name)) return "Unknown utility"
            Config.setNestedValue("iris.bar.auxiliary", name)
            return String(Config.options.iris.bar.auxiliary)
        }
        function status(): string {
            return JSON.stringify({
                islandExpanded: GlobalStates.irisIslandExpanded,
                islandPage: GlobalStates.irisIslandPage,
                accent: Config.options?.iris?.appearance?.accent ?? "blue",
                preset: IrisStyle.presetName,
                bubbleCard: GlobalStates.irisBubbleCard?.kind ?? "",
                utility: Config.options?.iris?.bar?.auxiliary ?? "tray",
                trayItems: SystemTray.items.values.length,
                dockShown: GlobalStates.irisDockShown,
                controlCenter: GlobalStates.controlPanelOpen,
                spotlight: GlobalStates.searchOpen,
                focus: { open: GlobalStates.sidebarLeftOpen, pinned: Config.options?.iris?.sidebars?.left?.pinned ?? false },
                today: { open: GlobalStates.sidebarRightOpen, pinned: Config.options?.iris?.sidebars?.right?.pinned ?? false }
            })
        }
    }

    function islandAllowed(screen: var): bool {
        const list = root.options?.screenList ?? []
        if (!list || list.length === 0) return true
        const matched = Quickshell.screens.filter(s => list.includes(s?.name ?? ""))
        return matched.length === 0 || list.includes(screen?.name ?? "")
    }

    Variants {
        model: Quickshell.screens

        delegate: LazyLoader {
            id: windowLoader
            required property var modelData
            property string loadedEdge: "top"
            readonly property bool loadedBottom: windowLoader.loadedEdge === "bottom"
            readonly property bool loadedVertical: windowLoader.loadedEdge === "left" || windowLoader.loadedEdge === "right"
            Component.onCompleted: windowLoader.loadedEdge = root.edge
            property bool recycling: false
            readonly property string requestedEdge: root.edge
            onRequestedEdgeChanged: windowLoader.recycle()
            // Rebuilt on shape changes: a ClippingRectangle does not re-mask when its corner structure changes.
            readonly property string shapeKey: String(Config.options?.iris?.surround?.enable ?? false)
            onShapeKeyChanged: windowLoader.recycle()
            function recycle(): void {
                windowLoader.recycling = true
                Qt.callLater(() => {
                    windowLoader.loadedEdge = windowLoader.requestedEdge
                    windowLoader.recycling = false
                })
            }
            activeAsync: !windowLoader.recycling

            component: Scope {
            PanelWindow {
                id: barWindow
                readonly property bool expanded: islandLoader.item?.expanded ?? false
                readonly property bool pinned: islandLoader.item?.pinned ?? false
                screen: windowLoader.modelData
                visible: true
                color: "transparent"
                exclusionMode: ExclusionMode.Ignore
                exclusiveZone: 0
                WlrLayershell.namespace: "quickshell:iris-chassis"
                readonly property bool editHere: GlobalStates.irisEdit
                    && (root.editScreen.length === 0 || barWindow.screen?.name === root.editScreen)
                readonly property bool presenting: barWindow.pinned || stage.cardPresent
                    || (controlCentreLoader.item?.present ?? false) || barWindow.editHere
                    || (dockLoader.item?.overFullscreen ?? false) || (dockLoader.item?.menuOpen ?? false)
                // Niri keeps a fullscreen window above the Top layer, so the overview
                // over a game would show every other surface but this one.
                readonly property bool overviewOverFullscreen: CompositorService.nativeOverview && WorkspaceService.inOverview
                    && GameMode.hasFullscreenOnOutput(barWindow.screen?.name ?? "")
                readonly property bool canvasSuppressed: barWindow.suppressed && !barWindow.presenting
                readonly property bool overlaid: ((islandLoader.item?.fullscreenCovered ?? false) && !barWindow.canvasSuppressed)
                    || barWindow.overviewOverFullscreen
                // Switching layers recreates the surface above the Dock's window, whose icons it would cover.
                onOverlaidChanged: if (!barWindow.overlaid) GlobalStates.irisChassisEpoch++
                WlrLayershell.layer: barWindow.overlaid ? WlrLayer.Overlay : WlrLayer.Top
                WlrLayershell.keyboardFocus: barWindow.pinned || stage.cardOpen || (controlCentreLoader.item?.morphOpen ?? false)
                    || barWindow.editHere || (dockLoader.item?.menuOpen ?? false)
                    ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                anchors { left: true; right: true; top: true; bottom: true }
                readonly property bool suppressed: islandLoader.active
                    ? (islandLoader.item?.suppressed ?? false) : false
                mask: barWindow.canvasSuppressed ? emptyRegion
                    : barWindow.pinned || stage.cardArmed || (controlCentreLoader.item?.armed ?? false)
                        || (dockLoader.item?.menuOpen ?? false)
                        || (islandLoader.item?.morphing ?? false)
                        ? (GlobalStates.irisStudioRect ? chassisStudioMask : null) : chassisRegion
                Region { id: emptyRegion }
                IrisParts.IrisStudioMask {
                    id: chassisStudioMask
                    canvasWidth: barWindow.width
                    canvasHeight: barWindow.height
                    screenName: barWindow.screen?.name ?? ""
                }
                component PieceRegion: Region {
                    required property int index
                    readonly property var rect: stage.hitRects[index] ?? null
                    x: rect ? rect.x : 0
                    y: rect ? rect.y : 0
                    width: rect ? rect.width : 0
                    height: rect ? rect.height : 0
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: dockLoader.item?.menuOpen ?? false
                    acceptedButtons: Qt.AllButtons
                    onPressed: dockLoader.item.closeMenu()
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: barWindow.pinned
                    acceptedButtons: Qt.AllButtons
                    onPressed: islandLoader.item.expanded = false
                }
                Region {
                    id: chassisRegion
                    item: islandInput
                    Region { item: extensionInput }
                    Region { item: dockLoader.item && !dockLoader.item.inputOff ? dockLoader.item.hitItem : null }
                    Region {
                        readonly property var rect: editLoader.item?.hitRect ?? null
                        x: rect?.x ?? 0
                        y: rect?.y ?? 0
                        width: rect?.width ?? 0
                        height: rect?.height ?? 0
                    }
                    Region {
                        readonly property var rect: editLoader.item?.inspectorRect ?? null
                        x: rect?.x ?? 0
                        y: rect?.y ?? 0
                        width: rect?.width ?? 0
                        height: rect?.height ?? 0
                    }
                    Region {
                        readonly property var panel: (controlCentreLoader.item?.present ?? false)
                            ? controlCentreLoader.item.body : null
                        x: panel ? controlCentreLoader.x + panel.x : 0
                        y: panel ? controlCentreLoader.y + panel.y : 0
                        width: panel ? panel.width : 0
                        height: panel ? panel.height : 0
                    }
                    Region {
                        x: banners.hitRect?.x ?? 0
                        y: banners.hitRect?.y ?? 0
                        width: banners.hitRect?.width ?? 0
                        height: banners.hitRect?.height ?? 0
                    }
                    PieceRegion { index: 0 }
                    PieceRegion { index: 1 }
                    PieceRegion { index: 2 }
                    PieceRegion { index: 3 }
                    PieceRegion { index: 4 }
                    PieceRegion { index: 5 }
                    PieceRegion { index: 6 }
                    PieceRegion { index: 7 }
                    PieceRegion { index: 8 }
                    PieceRegion { index: 9 }
                    PieceRegion { index: 10 }
                    PieceRegion { index: 11 }
                    PieceRegion { index: 12 }
                    PieceRegion { index: 13 }
                    PieceRegion { index: 14 }
                    PieceRegion { index: 15 }
                    PieceRegion { index: 16 }
                    PieceRegion { index: 17 }
                    PieceRegion { index: 18 }
                    PieceRegion { index: 19 }
                    PieceRegion { index: 20 }
                    PieceRegion { index: 21 }
                    PieceRegion { index: 22 }
                    PieceRegion { index: 23 }
                }
                readonly property var blurShapes: barWindow.canvasSuppressed ? []
                    : (barWindow.fieldShapes ?? []).filter(shape => chassisField.glassOf(shape) === 2)
                readonly property bool frameBlurred: !barWindow.canvasSuppressed && IrisFrame.framed && chassisField.frameGlass === 2
                BackgroundEffect.blurRegion: glassBlurRegion
                component BlurSlot: Region {
                    required property int index
                    readonly property var shape: barWindow.blurShapes[index] ?? null
                    x: shape ? shape.x : 0
                    y: shape ? shape.y : 0
                    width: shape ? shape.width : 0
                    height: shape ? shape.height : 0
                    radius: shape ? Number(shape.radius ?? 0) : 0
                }
                Region {
                    id: glassBlurRegion
                    Region {
                        width: barWindow.frameBlurred ? barWindow.width : 0
                        height: barWindow.frameBlurred ? barWindow.height : 0
                        Region {
                            intersection: Intersection.Subtract
                            x: IrisFrame.band
                            y: IrisFrame.band
                            width: Math.max(0, barWindow.width - 2 * IrisFrame.band)
                            height: Math.max(0, barWindow.height - 2 * IrisFrame.band)
                            radius: IrisFrame.cornerRadius
                        }
                    }
                    BlurSlot { index: 0 }
                    BlurSlot { index: 1 }
                    BlurSlot { index: 2 }
                    BlurSlot { index: 3 }
                    BlurSlot { index: 4 }
                    BlurSlot { index: 5 }
                    BlurSlot { index: 6 }
                    BlurSlot { index: 7 }
                    BlurSlot { index: 8 }
                    BlurSlot { index: 9 }
                    BlurSlot { index: 10 }
                    BlurSlot { index: 11 }
                    BlurSlot { index: 12 }
                    BlurSlot { index: 13 }
                    BlurSlot { index: 14 }
                    BlurSlot { index: 15 }
                    BlurSlot { index: 16 }
                    BlurSlot { index: 17 }
                    BlurSlot { index: 18 }
                    BlurSlot { index: 19 }
                }
                // Keep the area under a still pointer: Wayland sends no re-enter after a resize.
                Item {
                    id: islandInput
                    readonly property real liveWidth: Math.max(islandLoader.width, islandLoader.item?.inputWidth ?? 0)
                    readonly property real liveHeight: Math.max(islandLoader.height, islandLoader.item?.inputHeight ?? 0)
                    property real heldWidth: 0
                    property real heldHeight: 0
                    readonly property bool holding: canvasHover.hovered
                        && (heldWidth > liveWidth + 1 || heldHeight > liveHeight + 1)
                    function release(): void { heldWidth = liveWidth; heldHeight = liveHeight }
                    onLiveWidthChanged: heldWidth = canvasHover.hovered ? Math.max(heldWidth, liveWidth) : liveWidth
                    onLiveHeightChanged: heldHeight = canvasHover.hovered ? Math.max(heldHeight, liveHeight) : liveHeight
                    width: Math.max(liveWidth, heldWidth)
                    height: Math.max(liveHeight, heldHeight)
                    x: !windowLoader.loadedVertical ? islandLoader.x + (islandLoader.width - width) / 2
                        : windowLoader.loadedEdge === "right" ? islandLoader.x + islandLoader.width - width : islandLoader.x
                    y: windowLoader.loadedVertical ? islandLoader.y + (islandLoader.height - height) / 2
                        : windowLoader.loadedBottom ? islandLoader.y + islandLoader.height - height : islandLoader.y
                }
                Item {
                    id: extensionInput
                    readonly property rect area: islandLoader.item?.extensionArea ?? Qt.rect(0, 0, 0, 0)
                    x: islandLoader.x + extensionInput.area.x
                    y: islandLoader.y + extensionInput.area.y
                    width: extensionInput.area.width
                    height: extensionInput.area.height
                }
                HoverHandler {
                    id: canvasHover
                    property point last: Qt.point(-1, -1)
                    onHoveredChanged: if (!hovered) islandInput.release()
                    onPointChanged: {
                        const p = point.position
                        if (Math.abs(p.x - last.x) + Math.abs(p.y - last.y) > 2) {
                            last = p
                            islandInput.release()
                        }
                    }
                }

                Shortcut {
                    sequence: "Escape"
                    enabled: barWindow.expanded
                    onActivated: islandLoader.item.expanded = false
                }

                Shortcut {
                    sequence: "Escape"
                    enabled: barWindow.editHere
                    onActivated: GlobalStates.irisEdit = false
                }

                // Never coalesced: the field is the outline of what the items paint,
                // so a table that lands a turn later draws the rim and the shadow of
                // the shape the chassis had on the previous frame. Measured at 3 ms
                // per open/close for the whole chain — cheaper than one frame of lag.
                readonly property var fieldShapes: {
                    const dockBody = dockLoader.item?.bodyShape ?? null
                    const hung = (controlCentreLoader.item?.fieldShapes ?? [])
                        .concat(stage.fieldShapes)
                        .concat(editLoader.item?.fieldShapes ?? [])
                        .concat(Array.isArray(dockBody) ? dockBody : [])
                    const bodies = hung.filter(shape => shape.joins === "island")
                    const island = (islandLoader.item?.fieldShapes ?? []).map(shape => {
                        if (!shape.satellite) return shape
                        const reach = IrisStyle.fuse
                        const body = bodies.find(b => shape.x < b.x + b.width + reach && shape.x + shape.width > b.x - reach
                            && shape.y < b.y + b.height + reach && shape.y + shape.height > b.y - reach)
                        return body ? Object.assign({}, shape, { joins: [body.id].concat(Array.isArray(shape.joins) ? shape.joins.slice(1) : []), fuse: IrisStyle.fuse }) : shape
                    })
                    const all = island.concat(hung)
                    if (all.length <= chassisField.capacity) return all
                    return all.filter(shape => !shape.paints)
                        .concat(all.filter(shape => shape.paints))
                        .slice(0, chassisField.capacity)
                }

                IrisField {
                    id: chassisField
                    anchors.fill: parent
                    compositorAllowed: true
                    edgeWave: framePulse.amplitudes
                    waveClock: framePulse.phase
                    shapes: barWindow.fieldShapes
                    opacity: barWindow.canvasSuppressed ? 0 : 1
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(160); easing.type: IrisStyle.feedbackEasing } }
                }

                IrisFramePulse {
                    id: framePulse
                    active: IrisFrame.framed && !barWindow.canvasSuppressed
                        && (Config.options?.background?.edgeWidgets?.organic?.enable ?? false)
                        && String(Config.options?.iris?.surround?.music ?? "widget") === "frame"
                }

                IrisParts.IrisSpring {
                    id: islandPlacement
                    surface: "island"
                    intent: "move"
                    to: islandLoader.layout === "left" ? 0 : islandLoader.layout === "right" ? 1 : 0.5
                }

                Loader {
                    id: islandLoader
                    z: 3
                    active: GlobalStates.barOpen && root.islandAllowed(barWindow.screen)
                    readonly property string layout: String(root.options?.layout ?? "island")
                    readonly property real inset: IrisFrame.band + root.outerMargin
                    readonly property real edgeMargin: IrisFrame.band + (islandLoader.item
                        ? Math.round(root.restMargin * (1 - Math.min(1, islandLoader.item.notchness))) : root.outerMargin)
                    readonly property real along: islandPlacement.value
                        * ((windowLoader.loadedVertical ? parent.height - islandLoader.height : parent.width - islandLoader.width) - 2 * islandLoader.inset)
                    x: Math.round(!windowLoader.loadedVertical ? islandLoader.inset + islandLoader.along
                        : windowLoader.loadedEdge === "right" ? parent.width - islandLoader.width - islandLoader.edgeMargin : islandLoader.edgeMargin)
                    y: Math.round(windowLoader.loadedVertical ? islandLoader.inset + islandLoader.along
                        : windowLoader.loadedBottom ? parent.height - islandLoader.height - islandLoader.edgeMargin : islandLoader.edgeMargin)
                    width: item?.implicitWidth ?? (windowLoader.loadedVertical ? root.barHeight : 240)
                    height: item?.implicitHeight ?? (windowLoader.loadedVertical ? 240 : root.barHeight)
                    sourceComponent: IrisIsland {
                        id: island
                        targetScreen: barWindow.screen
                        pointerHeld: islandInput.holding
                        availableWidth: (windowLoader.loadedVertical ? barWindow.height : barWindow.width) - (IrisFrame.band + root.outerMargin) * 2
                        availableAcross: barWindow.width - 2 * (IrisFrame.band + root.outerMargin) - root.barHeight - Math.round(24 * IrisStyle.density)
                        compactHeight: root.barHeight
                        edge: windowLoader.loadedEdge
                        screenOffsetY: 0
                        Connections {
                            target: root
                            function onIslandRequested(open: bool, page: string): void {
                                if (!open || barWindow.screen?.name === GlobalStates.focusedScreen?.name) {
                                    if (open && (page === "next" || page === "prev")) {
                                        island.stepPage(page === "next" ? 1 : -1)
                                        return
                                    }
                                    if (open) island.page = page
                                    island.pinned = open
                                    island.expanded = open
                                }
                            }
                        }
                    }
                }

                IrisBanners {
                    id: banners
                    z: 2
                    anchors.fill: parent
                    screenData: barWindow.screen
                }

                Loader {
                    id: dockLoader
                    z: 2
                    anchors.fill: parent
                    active: (Config.options?.iris?.dock?.enable ?? true) && GlobalStates.deferredPanelsReady
                    asynchronous: true
                    sourceComponent: IrisDock {
                        screen: barWindow.screen
                        onPieceActivated: (slot, kind, rect) => stage.activate(slot, kind, rect)
                        onPieceMenuRequested: (slot, kind, rect, menu) => {
                            menu.model = stage.pieceMenu(slot, kind, rect)
                            menu.requestOpen()
                        }
                    }
                }

                IrisStage {
                    id: stage
                    z: 2
                    anchors.fill: parent
                    modelData: barWindow.screen
                    suppressed: barWindow.canvasSuppressed
                }

                Loader {
                    id: editLoader
                    z: 4
                    anchors.fill: parent
                    // Kept for the recede, on a grace timer: reading the item's own
                    // state back into `active` is a binding loop.
                    property bool grace: false
                    Timer { id: editGrace; interval: 700; onTriggered: editLoader.grace = false }
                    Connections {
                        target: GlobalStates
                        function onIrisEditChanged(): void {
                            if (GlobalStates.irisEdit) { editGrace.stop(); editLoader.grace = false }
                            else if (editLoader.active) { editLoader.grace = true; editGrace.restart() }
                        }
                    }
                    active: barWindow.editHere || editLoader.grace
                    sourceComponent: IrisEditBar { screenData: barWindow.screen }
                }

                Loader {
                    id: controlCentreLoader
                    z: 1
                    anchors.fill: parent
                    readonly property bool panelMode: String(Config.options?.iris?.controlCenter?.opens ?? "island") !== "island"
                    readonly property bool externalOpen: GlobalStates.controlPanelOpen
                        && (controlCentreLoader.panelMode || GlobalStates.irisMorphOwner === "stage")
                    readonly property bool wanted: controlCentreLoader.externalOpen
                        || (controlCentreLoader.panelMode && GlobalStates.irisControlsWarm)
                        || stage.controlIntent
                    property bool resident: false
                    property Timer releaseTimer: Timer {
                        interval: Math.max(IrisStyle.recedeDuration, IrisStyle.settleDuration) + 120
                        onTriggered: if (!controlCentreLoader.wanted) controlCentreLoader.resident = false
                    }
                    onWantedChanged: {
                        if (controlCentreLoader.wanted) {
                            controlCentreLoader.releaseTimer.stop()
                            controlCentreLoader.resident = true
                        } else if (controlCentreLoader.resident) {
                            controlCentreLoader.releaseTimer.restart()
                        }
                    }
                    Component.onCompleted: if (controlCentreLoader.wanted) controlCentreLoader.resident = true
                    active: (Config.options?.iris?.modules?.controlCenter ?? true) && controlCentreLoader.resident
                    asynchronous: true
                    sourceComponent: IrisControlCenter { screenData: barWindow.screen }
                }
            }
            }
        }
    }
}
