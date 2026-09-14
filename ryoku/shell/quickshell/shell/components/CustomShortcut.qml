pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui.Singletons

// One shell keybind. When the compositor offers a global-shortcuts protocol
// (caps.globalShortcuts) the provider bridge dispatches straight to this
// instance with no process spawn. Where the capability is absent the shortcut is
// a compositor keybind execing ryoku-shell instead, so this stays inert.
// Consumers set name/description and handle pressed/released.
Item {
    id: root

    property string name
    property string description

    signal pressed
    signal released

    property QtObject _bridge: null
    property var _component: null

    onNameChanged: if (root._bridge) root._bridge.name = root.name
    onDescriptionChanged: if (root._bridge) root._bridge.description = root.description

    // A property binding re-evaluates whenever Wm.caps arrives, so this cannot
    // miss the capability the way a one-shot ready handler did: the topic can
    // land before or after this instance exists.
    readonly property bool _canBridge: Wm.caps.globalShortcuts === true
    on_CanBridgeChanged: root._build()
    Component.onCompleted: root._build()

    function _build() {
        if (root._bridge || !Wm.caps.globalShortcuts)
            return;
        if (!root._component)
            root._component = Qt.createComponent("Ryoku.Wm.Hyprland", "GlobalShortcutBridge");
        const c = root._component;
        if (c.status === Component.Loading) {
            c.statusChanged.connect(root._build);
            return;
        }
        if (c.status !== Component.Ready)
            return;
        const b = c.createObject(root, { name: root.name, description: root.description });
        if (!b)
            return;
        // shortcutPressed/shortcutReleased, not pressed/released: GlobalShortcut's
        // `pressed` property shadows its signal of the same name.
        b.shortcutPressed.connect(root.pressed);
        b.shortcutReleased.connect(root.released);
        root._bridge = b;
    }
}
