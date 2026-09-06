pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Item {
    id: root

    visible: false

    property string layout: ""
    property string variant: ""
    property string lastEvent: ""

    readonly property string signature: layout + (variant ? ":" + variant : "")

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return

            root.lastEvent = event.data || ""

            const parts = (event.data || "").split(",")

            if (parts.length >= 2) {
                root.layout = parts[0].trim()
                root.variant = parts.slice(1).join(",").trim()

                console.log(
                    "[KeyboardLayout] layout:",
                    root.layout,
                    "variant:",
                    root.variant
                )
            }
        }
    }

    // Hyprland emits activelayout only on a change, so the pill would sit blank
    // from login until the first switch. Seed the current layout from hyprctl on
    // startup; a live event, once it arrives, is authoritative and overwrites this.
    Process {
        id: probe
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.variant)
                    return
                try {
                    const kbs = JSON.parse(this.text).keyboards || []
                    const main = kbs.find(k => k.main) || kbs[0]
                    if (main) {
                        root.layout = main.name || ""
                        root.variant = main.active_keymap || ""
                    }
                } catch (e) {}
            }
        }
    }

    Component.onCompleted: {
        console.log("[KeyboardLayout] service loaded")
        probe.running = true
    }
}
