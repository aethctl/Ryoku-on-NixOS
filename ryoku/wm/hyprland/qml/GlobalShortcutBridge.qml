import Quickshell.Hyprland

// Provider bridge for the global-shortcuts protocol. This is the one place the
// Hyprland import is legal in QML, for the same reason hyprctl is legal in the
// provider binary.
//
// The re-emitted signal names are not cosmetic: GlobalShortcut has both a
// `pressed` property and a `pressed` signal, so the property shadows the signal
// and a consumer's `pressed.connect(...)` resolves to a bool and throws. These
// names are unshadowed, so the neutral loader can connect them.
GlobalShortcut {
    id: bridge

    signal shortcutPressed
    signal shortcutReleased

    appid: "ryoku"
    onPressed: bridge.shortcutPressed()
    onReleased: bridge.shortcutReleased()
}
