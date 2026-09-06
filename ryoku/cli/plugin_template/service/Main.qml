pragma ComponentBehavior: Bound

import QtQuick

// service/Main.qml is the plugin's logic: no UI. The host loads one instance and
// hands it to every view as pluginApi.mainInstance, so the widget and the panel
// read the same live state. Replace the demo counter below with your plugin's
// real state and the singletons or bin/ scripts that feed it.
Item {
    id: svc

    // Set by the host after this loads; the plugin's settings live behind it.
    // Read settings through pluginApi.pluginSettings, always behind a default,
    // and write them only through pluginApi.saveSetting(key, value) (R5).
    property var pluginApi
    readonly property var settings: pluginApi ? pluginApi.pluginSettings : null

    // Demo state: a counter that ticks once a second.
    property int count: 0

    // The panel's RESET button calls this.
    function reset() {
        svc.count = 0;
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: svc.count += 1
    }
}
