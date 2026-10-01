import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../../../reusables"
import "../../../"

Rectangle {
    id: sideWifiRoot

    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    property bool isDesktop: false
    property real targetY: 0
    property bool showLayout: moduleActive && (!barWindow || (barWindow.isStartupReady && barWindow.isDataReady))
    property alias wifiPill: wifiBtn

    property string ethStatus: "Ethernet"
    property string wifiStatus: "Off"
    property string wifiIcon: "󰤮"
    property string wifiSsid: ""
    property bool isWifiOn: Networking.wifiEnabled
    property bool showEthernet: ethStatus === "Connected" || (isDesktop && !isWifiOn)
    property bool isActive: showEthernet ? (ethStatus === "Connected") : isWifiOn

    property var ethDevice: null
    property var wifiDevice: null

    property real targetWidth: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))
    property real targetHeight: (moduleActive && wifiBtn.height > 0) ? (wifiBtn.height + (barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10))) : 0

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
        findDevices();
        updateNetworkData();
    }

    onModuleActiveChanged: {
        if (!moduleActive) {
            chassisDetector.running = false;
        } else {
            chassisDetector.running = true;
            findDevices();
            updateNetworkData();
        }
    }

    Process {
        id: chassisDetector
        running: sideWifiRoot.moduleActive
        command: ["bash", "-c", "if ls /sys/class/power_supply/BAT* 1> /dev/null 2>&1; then echo 'laptop'; else echo 'desktop'; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                isDesktop = (this.text.trim() === "desktop");
            }
        }
    }

    function isEthDevice(dev) {
        return !!dev && dev.type === DeviceType.Wired;
    }

    function isWifiDevice(dev) {
        return !!dev && dev.type === DeviceType.Wifi;
    }

    function findDevices() {
        if (!Networking || !Networking.devices) return;
        let devs = Networking.devices.values || Networking.devices;
        let count = devs.length !== undefined ? devs.length : (devs.count !== undefined ? devs.count : 0);
        for (let i = 0; i < count; i++) {
            let d = devs[i] !== undefined ? devs[i] : (devs.get ? devs.get(i) : null);
            if (!d) continue;
            if (!sideWifiRoot.ethDevice && isEthDevice(d)) {
                sideWifiRoot.ethDevice = d;
            } else if (!sideWifiRoot.wifiDevice && isWifiDevice(d)) {
                sideWifiRoot.wifiDevice = d;
            }
        }
    }

    function getWifiNetworksList() {
        if (!wifiDevice || !wifiDevice.networks) return [];
        let nets = wifiDevice.networks.values || wifiDevice.networks;
        let list = [];
        let count = nets.length !== undefined ? nets.length : (nets.count !== undefined ? nets.count : 0);
        for (let i = 0; i < count; i++) {
            let n = nets[i] !== undefined ? nets[i] : (nets.get ? nets.get(i) : null);
            if (n) list.push(n);
        }
        return list;
    }

    function updateNetworkData() {
        findDevices();

        let isWifiEnabled = Networking.wifiEnabled;
        wifiStatus = isWifiEnabled ? "Enabled" : "Off";

        if (ethDevice) {
            if (ethDevice.connected) {
                ethStatus = "Connected";
            } else if (ethDevice.hasLink) {
                ethStatus = "Disconnected";
            } else {
                ethStatus = "Ethernet";
            }
        } else {
            ethStatus = "Ethernet";
        }

        if (!isWifiEnabled) {
            wifiSsid = "";
            wifiIcon = "󰤮";
            return;
        }

        let connectedNet = null;
        let netList = getWifiNetworksList();
        for (let i = 0; i < netList.length; i++) {
            let n = netList[i];
            if (n && n.connected) {
                connectedNet = n;
                break;
            }
        }

        if (connectedNet) {
            wifiSsid = connectedNet.name || connectedNet.ssid || "";
            let sig = connectedNet.signalStrength !== undefined ? Math.round(connectedNet.signalStrength * (connectedNet.signalStrength <= 1 ? 100 : 1)) : 100;
            if (sig >= 80) wifiIcon = "󰤨";
            else if (sig >= 60) wifiIcon = "󰤥";
            else if (sig >= 40) wifiIcon = "󰤢";
            else if (sig >= 20) wifiIcon = "󰤟";
            else wifiIcon = "󰤯";
        } else {
            wifiSsid = "";
            wifiIcon = "󰤯";
        }
    }

    Item {
        visible: false

        Connections {
            target: Networking
            ignoreUnknownSignals: true
            function onWifiEnabledChanged() { sideWifiRoot.updateNetworkData(); }
            function onDevicesChanged() {
                sideWifiRoot.findDevices();
                sideWifiRoot.updateNetworkData();
            }
        }

        Connections {
            target: Networking.devices || null
            ignoreUnknownSignals: true
            function onObjectInsertedPost(object, index) {
                sideWifiRoot.findDevices();
                sideWifiRoot.updateNetworkData();
            }
            function onObjectRemovedPost(object, index) {
                sideWifiRoot.findDevices();
                sideWifiRoot.updateNetworkData();
            }
            function onCountChanged() {
                sideWifiRoot.findDevices();
                sideWifiRoot.updateNetworkData();
            }
        }

        Connections {
            target: sideWifiRoot.ethDevice || null
            ignoreUnknownSignals: true
            function onConnectedChanged() { sideWifiRoot.updateNetworkData(); }
            function onStateChanged() { sideWifiRoot.updateNetworkData(); }
            function onHasLinkChanged() { sideWifiRoot.updateNetworkData(); }
        }

        Connections {
            target: sideWifiRoot.wifiDevice || null
            ignoreUnknownSignals: true
            function onConnectedChanged() { sideWifiRoot.updateNetworkData(); }
            function onStateChanged() { sideWifiRoot.updateNetworkData(); }
            function onNetworksChanged() { sideWifiRoot.updateNetworkData(); }
        }

        Connections {
            target: (sideWifiRoot.wifiDevice && sideWifiRoot.wifiDevice.networks) ? sideWifiRoot.wifiDevice.networks : null
            ignoreUnknownSignals: true
            function onObjectInsertedPost(object, index) { sideWifiRoot.updateNetworkData(); }
            function onObjectRemovedPost(object, index) { sideWifiRoot.updateNetworkData(); }
            function onCountChanged() { sideWifiRoot.updateNetworkData(); }
        }

        Repeater {
            id: netDeviceRepeater
            model: Networking.devices
            Item {
                property var device: modelData
                Component.onCompleted: {
                    if (device && device.type === DeviceType.Wired) {
                        sideWifiRoot.ethDevice = device;
                    } else if (device && device.type === DeviceType.Wifi) {
                        sideWifiRoot.wifiDevice = device;
                    }
                    sideWifiRoot.updateNetworkData();
                }
                Connections {
                    target: device || null
                    ignoreUnknownSignals: true
                    function onStateChanged() { sideWifiRoot.updateNetworkData(); }
                    function onConnectedChanged() { sideWifiRoot.updateNetworkData(); }
                    function onHasLinkChanged() { sideWifiRoot.updateNetworkData(); }
                }
            }
        }

        Repeater {
            id: wifiNetworkRepeater
            model: sideWifiRoot.wifiDevice ? sideWifiRoot.wifiDevice.networks : null
            Item {
                property var network: modelData
                Component.onCompleted: sideWifiRoot.updateNetworkData()
                Connections {
                    target: network || null
                    ignoreUnknownSignals: true
                    function onSignalStrengthChanged() { sideWifiRoot.updateNetworkData(); }
                    function onStateChanged() { sideWifiRoot.updateNetworkData(); }
                    function onConnectedChanged() { sideWifiRoot.updateNetworkData(); }
                    function onNameChanged() { sideWifiRoot.updateNetworkData(); }
                    function onSsidChanged() { sideWifiRoot.updateNetworkData(); }
                }
            }
        }
    }

    IconButton {
        id: wifiBtn
        anchors.centerIn: parent
        width: barWindow ? barWindow.s(sideWifiRoot.isCompact ? 28 : 30) : (sideWifiRoot.isCompact ? 28 : 30)
        height: barWindow ? barWindow.s(sideWifiRoot.isCompact ? 28 : 30) : (sideWifiRoot.isCompact ? 28 : 30)
        cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
        buttonIcon: sideWifiRoot.showEthernet ? "󰈀" : sideWifiRoot.wifiIcon
        iconFontSize: barWindow ? barWindow.s(sideWifiRoot.isCompact ? 14 : 15) : (sideWifiRoot.isCompact ? 14 : 15)
        accentColor: sideWifiRoot.isActive ? (sideWifiRoot.isCompact ? Qt.lighter(ThemeBackend.blue, 1.08) : ThemeBackend.blue) : (sideWifiRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
        textColor: sideWifiRoot.isActive ? ThemeBackend.base : (sideWifiRoot.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)
        iconOffsetX: sideWifiRoot.showEthernet ? 0 : -3
        onClicked: Quickshell.execDetached(["bash", "-c", Caching.scriptsPath + "/qs_manager.sh toggle network wifi"])
    }
}
