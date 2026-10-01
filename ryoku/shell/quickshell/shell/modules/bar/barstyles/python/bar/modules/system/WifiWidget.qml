import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Networking
import "../../../reusables"
import "../../../"

Rectangle {
    id: wifiWidgetRoot
    property var barWindow
    property bool isSolid: false
    property bool distinctPills: barWindow ? (barWindow.distinctPills !== undefined ? barWindow.distinctPills : false) : false
    property bool moduleActive: true
    property bool isGrouped: false
    property bool isCompact: isGrouped || (isSolid && distinctPills)
    property bool isDesktop: false
    property string ethStatus: "Ethernet"
    property string wifiStatus: "Off"
    property string wifiIcon: "󰤮"
    property string wifiSsid: ""
    property bool isWifiOn: Networking.wifiEnabled
    property bool showEthernet: ethStatus === "Connected" || (isDesktop && !isWifiOn)
    property real targetX: 0
    property bool showLayout: moduleActive && (!barWindow || (barWindow.isStartupReady && barWindow.isDataReady))
    property alias wifiPill: wifiPill

    property var ethDevice: null
    property var wifiDevice: null

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
        running: wifiWidgetRoot.moduleActive
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
            if (!wifiWidgetRoot.ethDevice && isEthDevice(d)) {
                wifiWidgetRoot.ethDevice = d;
            } else if (!wifiWidgetRoot.wifiDevice && isWifiDevice(d)) {
                wifiWidgetRoot.wifiDevice = d;
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
            function onWifiEnabledChanged() { wifiWidgetRoot.updateNetworkData(); }
            function onDevicesChanged() {
                wifiWidgetRoot.findDevices();
                wifiWidgetRoot.updateNetworkData();
            }
        }

        Connections {
            target: Networking.devices || null
            ignoreUnknownSignals: true
            function onObjectInsertedPost(object, index) {
                wifiWidgetRoot.findDevices();
                wifiWidgetRoot.updateNetworkData();
            }
            function onObjectRemovedPost(object, index) {
                wifiWidgetRoot.findDevices();
                wifiWidgetRoot.updateNetworkData();
            }
            function onCountChanged() {
                wifiWidgetRoot.findDevices();
                wifiWidgetRoot.updateNetworkData();
            }
        }

        Connections {
            target: wifiWidgetRoot.ethDevice || null
            ignoreUnknownSignals: true
            function onConnectedChanged() { wifiWidgetRoot.updateNetworkData(); }
            function onStateChanged() { wifiWidgetRoot.updateNetworkData(); }
            function onHasLinkChanged() { wifiWidgetRoot.updateNetworkData(); }
        }

        Connections {
            target: wifiWidgetRoot.wifiDevice || null
            ignoreUnknownSignals: true
            function onConnectedChanged() { wifiWidgetRoot.updateNetworkData(); }
            function onStateChanged() { wifiWidgetRoot.updateNetworkData(); }
            function onNetworksChanged() { wifiWidgetRoot.updateNetworkData(); }
        }

        Connections {
            target: (wifiWidgetRoot.wifiDevice && wifiWidgetRoot.wifiDevice.networks) ? wifiWidgetRoot.wifiDevice.networks : null
            ignoreUnknownSignals: true
            function onObjectInsertedPost(object, index) { wifiWidgetRoot.updateNetworkData(); }
            function onObjectRemovedPost(object, index) { wifiWidgetRoot.updateNetworkData(); }
            function onCountChanged() { wifiWidgetRoot.updateNetworkData(); }
        }

        Repeater {
            id: netDeviceRepeater
            model: Networking.devices
            Item {
                property var device: modelData
                Component.onCompleted: {
                    if (device && device.type === DeviceType.Wired) {
                        wifiWidgetRoot.ethDevice = device;
                    } else if (device && device.type === DeviceType.Wifi) {
                        wifiWidgetRoot.wifiDevice = device;
                    }
                    wifiWidgetRoot.updateNetworkData();
                }
                Connections {
                    target: device || null
                    ignoreUnknownSignals: true
                    function onStateChanged() { wifiWidgetRoot.updateNetworkData(); }
                    function onConnectedChanged() { wifiWidgetRoot.updateNetworkData(); }
                    function onHasLinkChanged() { wifiWidgetRoot.updateNetworkData(); }
                }
            }
        }

        Repeater {
            id: wifiNetworkRepeater
            model: wifiWidgetRoot.wifiDevice ? wifiWidgetRoot.wifiDevice.networks : null
            Item {
                property var network: modelData
                Component.onCompleted: wifiWidgetRoot.updateNetworkData()
                Connections {
                    target: network || null
                    ignoreUnknownSignals: true
                    function onSignalStrengthChanged() { wifiWidgetRoot.updateNetworkData(); }
                    function onStateChanged() { wifiWidgetRoot.updateNetworkData(); }
                    function onConnectedChanged() { wifiWidgetRoot.updateNetworkData(); }
                    function onNameChanged() { wifiWidgetRoot.updateNetworkData(); }
                    function onSsidChanged() { wifiWidgetRoot.updateNetworkData(); }
                }
            }
        }
    }

    x: targetX
    Behavior on x {
        enabled: barWindow && barWindow.startupCascadeFinished
        NumberAnimation { duration: 600; easing.type: Easing.OutQuint }
    }
    height: barWindow ? (isGrouped ? barWindow.barHeight - 8 : ((isSolid && distinctPills) ? barWindow.barHeight - 6 : barWindow.barHeight)) : (isGrouped ? 22 : ((isSolid && distinctPills) ? 24 : 30))
    y: barWindow ? barWindow.baseOffsetY + (barWindow.barHeight - height) / 2 : 0
    radius: ThemeBackend.borderRadius
    border.width: 0
    color: isGrouped ? "transparent" : (isSolid ? (distinctPills ? Qt.darker(ThemeBackend.surface0, 1.15) : "transparent") : ThemeBackend.base)
    clip: true

    property real targetWidth: (moduleActive && sysLayout.implicitWidth > 0) ? (sysLayout.implicitWidth + (barWindow ? barWindow.s(isCompact ? 8 : 10) : (isCompact ? 8 : 10))) : 0
    width: targetWidth

    opacity: (showLayout && moduleActive) ? ((barWindow && barWindow.barOpacity !== undefined) ? barWindow.barOpacity : 1.0) : 0.0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    transform: Translate {
        x: wifiWidgetRoot.showLayout ? 0 : barWindow.s(60)
        Behavior on x { NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    }

    Row {
        id: sysLayout
        anchors.centerIn: parent
        property int pillHeight: barWindow ? barWindow.s(wifiWidgetRoot.isCompact ? 28 : 30) : (wifiWidgetRoot.isCompact ? 28 : 30)

        ClickButton {
            id: wifiPill
            property bool initAnimTrigger: wifiWidgetRoot.showLayout
            property bool isActive: showEthernet ? (ethStatus === "Connected") : isWifiOn

            height: sysLayout.pillHeight
            maxWidth: barWindow ? barWindow.s(wifiWidgetRoot.isCompact ? 156 : 160) : (wifiWidgetRoot.isCompact ? 156 : 160)
            cornerRadius: Math.max(0, ThemeBackend.borderRadius - (barWindow ? barWindow.s(2) : 2))
            horizontalPadding: barWindow ? barWindow.s(wifiWidgetRoot.isCompact ? 10 : 12) : (wifiWidgetRoot.isCompact ? 10 : 12)
            buttonIcon: showEthernet ? "󰈀" : wifiIcon
            iconFontSize: barWindow ? barWindow.s(wifiWidgetRoot.isCompact ? 14 : 15) : (wifiWidgetRoot.isCompact ? 14 : 15)
            buttonText: showEthernet ? ethStatus : ((isWifiOn ? (wifiSsid !== "" ? wifiSsid : "On") : "Off"))
            textFontSize: barWindow ? barWindow.s(wifiWidgetRoot.isCompact ? 11 : 12) : (wifiWidgetRoot.isCompact ? 11 : 12)
            accentColor: isActive ? (wifiWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.blue, 1.08) : ThemeBackend.blue) : (wifiWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.surface0, 1.18) : ThemeBackend.surface0)
            textColor: isActive ? ThemeBackend.base : (wifiWidgetRoot.isCompact ? Qt.lighter(ThemeBackend.text, 1.05) : ThemeBackend.text)

            property real targetWidth: implicitWidth
            width: targetWidth
            Behavior on width { NumberAnimation { duration: 480; easing.type: Easing.OutQuint } }

            opacity: initAnimTrigger ? 1.0 : 0.0
            transform: Translate { y: wifiPill.initAnimTrigger ? 0 : barWindow.s(15); Behavior on y { NumberAnimation { duration: 620; easing.type: Easing.OutQuint } } }
            Behavior on opacity { NumberAnimation { duration: 450; easing.type: Easing.OutCubic } }

            onClicked: Quickshell.execDetached(["bash", "-c", Caching.scriptsPath + "/qs_manager.sh toggle network wifi"])
        }
    }
}
