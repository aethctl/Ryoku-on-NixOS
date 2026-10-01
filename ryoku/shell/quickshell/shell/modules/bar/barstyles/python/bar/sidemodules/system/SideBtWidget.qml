import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Bluetooth
import "../../../reusables"
import "../../../"

Rectangle {
    id: sideBtRoot

    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    property real targetY: 0
    property bool showLayout: moduleActive && (!barWindow || (barWindow.isStartupReady && barWindow.isDataReady))
    property alias btPill: btBtn
    property string btStatus: "Off"
    property string btIcon: "󰂲"
    property string btDevice: "Off"
    property bool isBtOn: btStatus.toLowerCase() === "enabled" || btStatus.toLowerCase() === "on"
    property bool isConnected: false

    property real targetWidth: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))
    property real targetHeight: (moduleActive && btBtn.height > 0) ? (btBtn.height + (barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10))) : 0

    width: targetWidth
    height: targetHeight

    Behavior on width { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }
    Behavior on height { NumberAnimation { duration: 400; easing.type: Easing.OutQuint } }

    x: barWindow ? ((barWindow.baseOffsetX !== undefined ? barWindow.baseOffsetX : 0) + (barWindow.barHeight - width) / 2) : 0
    y: targetY
    Behavior on y {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }

    radius: ThemeBackend.borderRadius
    border.width: 0
    color: isGrouped ? "transparent" : (isSolid ? (distinctPills ? Qt.darker(ThemeBackend.surface0, 1.15) : "transparent") : ThemeBackend.base)
    clip: true

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    Component.onCompleted: {
        updateBtData();
    }

    onModuleActiveChanged: {
        if (moduleActive) {
            updateBtData();
        }
    }

    function getBtDevicesList() {
        let adapter = Bluetooth.defaultAdapter;
        if (!adapter || !adapter.devices) return [];
        let devs = adapter.devices.values || adapter.devices;
        let list = [];
        let count = devs.length !== undefined ? devs.length : (devs.count !== undefined ? devs.count : 0);
        for (let i = 0; i < count; i++) {
            let d = devs[i] !== undefined ? devs[i] : (devs.get ? devs.get(i) : null);
            if (d) list.push(d);
        }
        return list;
    }

    function updateBtData() {
        let adapter = Bluetooth.defaultAdapter;
        let enabled = adapter ? adapter.enabled : false;

        if (!enabled) {
            btStatus = "Off";
            btIcon = "󰂲";
            btDevice = "Off";
            isConnected = false;
            return;
        }

        btStatus = "On";

        let connectedDev = null;
        let devList = getBtDevicesList();

        for (let i = 0; i < devList.length; i++) {
            let d = devList[i];
            if (d && d.connected) {
                connectedDev = d;
                break;
            }
        }

        if (connectedDev) {
            isConnected = true;
            let deviceName = connectedDev.deviceName || "";
            let alias = connectedDev.name || "";
            let name = deviceName !== "" ? deviceName : (alias !== "" ? alias : (connectedDev.address || ""));
            let iconType = connectedDev.icon || "";
            let typeLower = iconType.toLowerCase();
            let nameLower = name.toLowerCase();

            let icon = "󰂯";
            if (typeLower.indexOf("headset") !== -1 || typeLower.indexOf("headphone") !== -1 || nameLower.indexOf("headphone") !== -1 || nameLower.indexOf("buds") !== -1 || nameLower.indexOf("pods") !== -1) icon = "🎧";
            else if (typeLower.indexOf("audio") !== -1 || typeLower.indexOf("speaker") !== -1 || typeLower.indexOf("card") !== -1 || nameLower.indexOf("speaker") !== -1) icon = "📻";
            else if (typeLower.indexOf("phone") !== -1 || nameLower.indexOf("phone") !== -1 || nameLower.indexOf("iphone") !== -1 || nameLower.indexOf("android") !== -1) icon = "📱";
            else if (typeLower.indexOf("mouse") !== -1 || nameLower.indexOf("mouse") !== -1) icon = "󰍽";
            else if (typeLower.indexOf("keyboard") !== -1 || nameLower.indexOf("keyboard") !== -1) icon = "⌨️";
            else if (typeLower.indexOf("controller") !== -1 || nameLower.indexOf("controller") !== -1) icon = "🎮";

            btIcon = icon;
            btDevice = name;
        } else {
            isConnected = false;
            btIcon = "󰂯";
            btDevice = "On";
        }
    }

    Item {
        visible: false

        Connections {
            target: Bluetooth
            ignoreUnknownSignals: true
            function onDefaultAdapterChanged() { sideBtRoot.updateBtData(); }
        }

        Connections {
            target: Bluetooth.defaultAdapter || null
            ignoreUnknownSignals: true
            function onEnabledChanged() { sideBtRoot.updateBtData(); }
            function onDiscoveringChanged() { sideBtRoot.updateBtData(); }
        }

        Connections {
            target: (Bluetooth.defaultAdapter && Bluetooth.defaultAdapter.devices) ? Bluetooth.defaultAdapter.devices : null
            ignoreUnknownSignals: true
            function onObjectInsertedPost(object, index) { sideBtRoot.updateBtData(); }
            function onObjectRemovedPost(object, index) { sideBtRoot.updateBtData(); }
            function onCountChanged() { sideBtRoot.updateBtData(); }
        }

        Repeater {
            id: btDeviceRepeater
            model: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.devices : null

            Item {
                property var device: modelData
                Component.onCompleted: sideBtRoot.updateBtData()

                Connections {
                    target: device || null
                    ignoreUnknownSignals: true
                    function onConnectedChanged() { sideBtRoot.updateBtData(); }
                    function onNameChanged() { sideBtRoot.updateBtData(); }
                    function onDeviceNameChanged() { sideBtRoot.updateBtData(); }
                    function onStateChanged() { sideBtRoot.updateBtData(); }
                    function onPairedChanged() { sideBtRoot.updateBtData(); }
                    function onTrustedChanged() { sideBtRoot.updateBtData(); }
                }
            }
        }
    }

    IconButton {
        id: btBtn
        anchors.centerIn: parent
        width: barWindow ? barWindow.s(sideBtRoot.isCompact ? 28 : 30) : (sideBtRoot.isCompact ? 28 : 30)
        height: barWindow ? barWindow.s(sideBtRoot.isCompact ? 28 : 30) : (sideBtRoot.isCompact ? 28 : 30)
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
        buttonIcon: sideBtRoot.btIcon
        iconFontSize: barWindow ? barWindow.s(sideBtRoot.isCompact ? 14 : 15) : (sideBtRoot.isCompact ? 14 : 15)
        accentColor: sideBtRoot.isBtOn ? (sideBtRoot.isCompact ? Qt.lighter(ThemeBackend.mauve, 1.08) : ThemeBackend.mauve) : (sideBtRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
        textColor: sideBtRoot.isBtOn ? ThemeBackend.base : (sideBtRoot.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)
        onClicked: Quickshell.execDetached(["bash", "-c", Caching.scriptsPath + "/qs_manager.sh toggle network bt"])
    }
}
