pragma Singleton

import QtQuick
import inir.services
import inir.modules.common

QtObject {
    id: root

    readonly property var zones: ["top-left", "top-right", "left", "right", "bottom-left", "bottom-right"]
    function zoneChoices(withIsland: bool): var {
        const labels = { "top-left": "Top left", "top-right": "Top right", "left": "Left",
            "right": "Right", "bottom-left": "Bottom left", "bottom-right": "Bottom right" }
        const choices = withIsland ? [{ label: "Island", value: "island" }] : []
        for (const zone of root.zones) choices.push({ label: labels[zone], value: zone })
        choices.push({ label: "Free", value: "free" })
        return choices
    }

    readonly property var slots: [
        { id: "left", label: "Activity bubble", description: "Media, a timer or a recording beside the clock (Cluster)." },
        { id: "right", label: "Trailing bubble", description: "Controls, notifications, weather or a level after the clock." },
        { id: "utility", label: "Utility bubble", description: "Tray, timers, sound or microphone at the end of the Island." }
    ]
    readonly property var extras: [
        { id: "weather", label: "Weather", description: "The sky now; its card holds the details.", card: true },
        { id: "notifications", label: "Notifications", description: "A count of unread notifications; its card lists them.", card: true },
        { id: "controls", label: "Controls", description: "Opens the Control Center out of the bubble.", card: false },
        { id: "sound", label: "Sound", description: "Output level as a ring; scroll to change it. Its card holds devices and apps.", card: true },
        { id: "mic", label: "Microphone", description: "Input level as a ring; scroll to change it. Its card holds the inputs.", card: true },
        { id: "tools", label: "Timers", description: "Countdown presets, Focus and the stopwatch.", card: true },
        { id: "media", label: "Now playing", description: "The cover while something plays; opens its card.", card: true },
        { id: "tray", label: "Tray", description: "How many tray apps are running, and the apps themselves.", card: true },
        { id: "calendar", label: "Calendar", description: "Today's weekday over the date; its card holds the month and what is coming up.", card: true },
        { id: "clock", label: "Clock", description: "An analog face; opens the Desktop page.", card: false },
        { id: "battery", label: "Battery", description: "Charge as a ring that turns orange and red as it runs low; a bolt while charging.", card: false },
        { id: "focus", label: "Do Not Disturb", description: "A moon that silences notifications with a tap.", card: false },
        { id: "network", label: "Network", description: "The link you are on as a signal arc; its card holds the networks.", card: true },
        { id: "bluetooth", label: "Bluetooth", description: "What is connected; its card holds the devices.", card: true },
        { id: "vitals", label: "Vitals", description: "The load as a ring; its card holds processor, memory, heat and disk.", card: true },
        { id: "workspaces", label: "Workspaces", description: "This output's workspaces; tap for Overview or a workspace card.", card: true },
        { id: "updates", label: "Updates", description: "How many packages are waiting; its card checks and opens them.", card: true }
    ]
    readonly property var slotIds: root.slots.map(piece => piece.id)
    readonly property var extraIds: root.extras.map(piece => piece.id)
    readonly property var cardIds: root.extras.filter(piece => piece.card).map(piece => piece.id)
    readonly property string defaultPlace: "right"
    function labelOf(id: string): string {
        return root.slots.concat(root.extras).find(piece => piece.id === id)?.label ?? id
    }

    readonly property bool hasPlayer: String(MprisController.activePlayer?.trackTitle ?? "").length > 0
    readonly property int trayCount: SystemTray.items.values.filter(item => item && item.id).length
    function available(id: string): bool {
        if (id === "media") return root.hasPlayer
        if (id === "tray") return root.trayCount > 0
        if (id === "battery") return Battery.available
        if (id === "bluetooth") return BluetoothStatus.available
        if (id === "updates") return Updates.available
        return root.extraIds.includes(id)
    }

    readonly property string appPrefix: "app:"
    readonly property int maxApps: 8
    readonly property var apps: Config.options?.iris?.bubbles?.apps ?? []
    function isApp(id: string): bool { return id.startsWith(root.appPrefix) }
    function appIdOf(id: string): string { return id.slice(root.appPrefix.length) }
    function appPieceId(appId: string): string { return root.appPrefix + appId }
    function appIcon(appId: string): string {
        const id = String(appId ?? "")
        const entry = AppSearch.lookupDesktopEntry(id)
        const icon = entry?.icon || AppSearch.guessIcon(id)
        return IconThemeService.smartIconName(icon, id)
    }
    function appEntry(appId: string): var { return root.apps.find(entry => entry && entry.appId === appId) ?? null }
    function appPieceIds(): var {
        return root.apps.filter(entry => entry && String(entry.appId ?? "").length > 0)
            .slice(0, root.maxApps).map(entry => root.appPrefix + entry.appId)
    }
    function appFloating(appId: string): bool { return root.appEntry(appId) !== null }
    function writeApps(next: var): void { Config.setNestedValue("iris.bubbles.apps", next) }
    function placeApp(appId: string, place: string, fx: real, fy: real): void {
        if (String(appId ?? "").length === 0) return
        const next = root.apps.filter(entry => entry && entry.appId).map(entry => Object.assign({}, entry))
        const found = next.find(entry => entry.appId === appId)
        const value = { appId: appId, place: place, fx: fx, fy: fy }
        if (found) Object.assign(found, value)
        else if (next.length < root.maxApps) next.push(value)
        else return
        root.writeApps(next)
    }
    function removeApp(appId: string): void {
        root.writeApps(root.apps.filter(entry => entry && entry.appId && entry.appId !== appId)
            .map(entry => Object.assign({}, entry)))
    }

    function configPath(id: string): string {
        return root.extraIds.includes(id) ? "iris.bubbles.extras." + id : "iris.bubbles." + id
    }
    function anyFloating(options: var): bool {
        return root.slotIds.some(id => String(options?.[id]?.place ?? "island") !== "island")
            || root.extraIds.some(id => options?.extras?.[id]?.enable ?? false)
            || (options?.apps ?? []).some(entry => entry && String(entry.appId ?? "").length > 0)
    }
}
