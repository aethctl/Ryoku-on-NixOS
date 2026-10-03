pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Bluetooth
import shell.services
import Ryoku.Ui
import Ryoku.Ui.Singletons
import ".."
import "." as Cards

Item {
    id: root

    required property real s
    required property bool open
    required property real reveal
    required property bool tabActive
    property int index: 0
    property bool compact: false
    property real viewportHeight: 0
    property string detailPage: "overview"
    readonly property bool motionAllowed: !Tokens.reduceMotion && !Motion.reduce
    readonly property real gap: (root.compact ? Tokens.s3 : Tokens.s4) * root.s
    signal requestClose()

    readonly property string focusedOutput: Wm.focusedOutput
    readonly property string ddcBus: {
        const monitors = Devices.ddcMonitors || [];
        for (let i = 0; i < monitors.length; i++)
            if (monitors[i] && monitors[i].label === root.focusedOutput)
                return monitors[i].bus;
        return "";
    }
    readonly property bool brightnessAvailable: Devices.backlightAvailable || root.ddcBus !== ""
    readonly property real brightnessValue: Devices.backlightAvailable
        ? Math.max(0, Math.min(1, Devices.backlightPct / 100)) : 0.5
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property var btDevices: Bluetooth.devices ? Bluetooth.devices.values : []
    readonly property var connectedBtDevices: root.btDevices.filter(device => device && device.connected)
    readonly property string connectedBtSummary: {
        if (!root.btAdapter)
            return I18n.tr("No adapter");
        if (!root.btAdapter.enabled)
            return I18n.tr("Radio off");
        if (root.connectedBtDevices.length === 1)
            return BtLink.label(root.connectedBtDevices[0]);
        if (root.connectedBtDevices.length > 1)
            return I18n.tr("%1 connected").arg(root.connectedBtDevices.length);
        return I18n.tr("No devices connected");
    }
    readonly property string wifiSummary: !Network.wifiPresent ? I18n.tr("No adapter")
        : !Network.wifiRadio ? I18n.tr("Radio off")
        : Network.activeSsid !== "" ? Network.activeSsid
        : Network.wifiConnectivity === "Connecting" ? I18n.tr("Connecting…")
        : I18n.tr("Not connected")

    implicitHeight: shell.implicitHeight

    function showDetail(page): void {
        root.detailPage = page === "wifi" || page === "bluetooth" || page === "audio" ? page : "overview";
    }

    function setVolume(value): void {
        if (!Audio.sink || !Audio.sink.audio)
            return;
        const next = Math.max(0, Math.min(1, value));
        if (Audio.sink.audio.muted && next > 0)
            Audio.sink.audio.muted = false;
        Audio.sink.audio.volume = next;
    }

    function setMicVolume(value): void {
        if (!Audio.source || !Audio.source.audio)
            return;
        const next = Math.max(0, Math.min(1, value));
        if (Audio.source.audio.muted && next > 0)
            Audio.source.audio.muted = false;
        Audio.source.audio.volume = next;
    }

    function setBrightness(value): void {
        const percent = Math.round(Math.max(0, Math.min(1, value)) * 100);
        if (Devices.backlightAvailable)
            Devices.setBacklight(percent);
        else if (root.ddcBus !== "")
            Devices.setBrightness(root.ddcBus, percent);
    }

    function sessionAction(action): void {
        root.requestClose();
        ShellState.askSessionAction(action, "");
    }

    function profileLabel(profile): string {
        if (profile === "power-saver")
            return I18n.tr("Saver");
        if (profile === "balanced")
            return I18n.tr("Balanced");
        if (profile === "performance")
            return I18n.tr("Performance");
        return profile;
    }

    function profileLabels(): var {
        const labels = {};
        for (let i = 0; i < PowerProfiles.profiles.length; i++)
            labels[PowerProfiles.profiles[i]] = root.profileLabel(PowerProfiles.profiles[i]);
        return labels;
    }

    function syncDisplayProbes(): void {
        if (root.open && root.tabActive && root.detailPage === "overview")
            Devices.startProbes(root);
        else
            Devices.stopProbes(root);
    }

    onOpenChanged: root.syncDisplayProbes()
    onTabActiveChanged: root.syncDisplayProbes()
    onDetailPageChanged: root.syncDisplayProbes()
    Component.onCompleted: root.syncDisplayProbes()
    Component.onDestruction: Devices.stopProbes(root)

    component Panel: Rectangle {
        id: panel
        property string title: ""
        property string subtitle: ""
        default property alias content: panelBody.data
        radius: Tokens.radius * root.s * 2
        color: Tokens.paperLift
        border.width: Tokens.border
        border.color: Tokens.lineSoft
        implicitHeight: panelBody.implicitHeight + Tokens.s4 * root.s * 2
        height: implicitHeight

        Column {
            id: panelBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.s4 * root.s
            spacing: Tokens.s3 * root.s
            Text {
                visible: panel.title !== ""
                width: parent.width
                text: panel.title
                color: Tokens.ink
                font.family: Tokens.display
                font.pixelSize: Tokens.fValue * root.s
                font.weight: Font.DemiBold
                wrapMode: Text.Wrap
            }
            Text {
                visible: panel.subtitle !== ""
                width: parent.width
                text: panel.subtitle
                color: Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall * root.s
                wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            }
        }
    }

    component ConnectionTile: Rectangle {
        id: connectionTile
        required property string glyph
        required property string title
        required property string detail
        required property bool available
        required property bool radioOn
        required property var toggleFn
        required property var manageFn

        implicitHeight: Math.max(112 * root.s, tileCopy.implicitHeight + Tokens.s3 * root.s * 2)
        height: implicitHeight
        radius: Tokens.radius * root.s * 1.5
        color: connectionTile.radioOn ? Tokens.tint10 : Tokens.tint5
        border.width: Tokens.border
        border.color: Tokens.lineSoft

        Rectangle {
            id: tileIcon
            anchors.left: parent.left
            anchors.leftMargin: Tokens.s3 * root.s
            anchors.top: parent.top
            anchors.topMargin: Tokens.s3 * root.s
            width: 40 * root.s
            height: width
            radius: width / 2
            color: connectionTile.radioOn ? Tokens.bone : Tokens.tint10
            Text {
                anchors.centerIn: parent
                text: connectionTile.glyph
                color: connectionTile.radioOn ? Tokens.inkOnBone : Tokens.inkDim
                font.family: "Material Symbols Rounded"
                font.pixelSize: 21 * root.s
            }
        }
        Column {
            id: tileCopy
            anchors.left: tileIcon.right
            anchors.right: tileRadio.left
            anchors.leftMargin: Tokens.s3 * root.s
            anchors.rightMargin: Tokens.s3 * root.s
            anchors.top: parent.top
            anchors.topMargin: Tokens.s3 * root.s
            spacing: 2 * root.s
            Text {
                width: parent.width
                text: connectionTile.title
                color: connectionTile.available ? Tokens.ink : Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: Tokens.fRow * root.s
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: connectionTile.available ? connectionTile.detail : I18n.tr("Hardware unavailable")
                color: Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall * root.s
                elide: Text.ElideRight
            }
        }
        SidebarToggle {
            id: tileRadio
            s: root.s
            compact: true
            anchors.right: parent.right
            anchors.rightMargin: Tokens.s3 * root.s
            anchors.top: parent.top
            anchors.topMargin: Tokens.s3 * root.s
            width: implicitWidth
            text: ""
            on: connectionTile.radioOn
            enabled: connectionTile.available
            Accessible.name: I18n.tr("%1 radio").arg(connectionTile.title)
            onToggleRequested: connectionTile.toggleFn()
        }
        SidebarButton {
            s: root.s
            compact: true
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Tokens.s3 * root.s
            anchors.rightMargin: Tokens.s3 * root.s
            anchors.bottom: parent.bottom
            anchors.bottomMargin: Tokens.s3 * root.s
            text: I18n.tr("Manage %1").arg(connectionTile.title)
            glyph: "arrow_forward"
            armed: connectionTile.available
            onAct: connectionTile.manageFn()
        }
    }

    component LevelRow: Item {
        id: levelRow
        required property string glyph
        required property string label
        required property real value
        required property bool available
        required property var modifiedFn
        property string detail: ""
        property bool muteable: false
        property bool muted: false
        property var muteFn: null

        width: parent ? parent.width : implicitWidth
        implicitHeight: 54 * root.s
        height: implicitHeight

        QQC.AbstractButton {
            id: levelIcon
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 40 * root.s
            height: width
            enabled: levelRow.available && levelRow.muteable
            hoverEnabled: true
            Accessible.name: levelRow.muted ? I18n.tr("Unmute %1").arg(levelRow.label)
                : I18n.tr("Mute %1").arg(levelRow.label)
            onClicked: if (levelRow.muteFn) levelRow.muteFn()
            background: Rectangle {
                radius: width / 2
                color: levelIcon.down ? Tokens.tint16 : levelIcon.hovered ? Tokens.tint10 : Tokens.tint5
            }
            contentItem: Text {
                text: levelRow.glyph
                color: levelRow.available ? Tokens.inkDim : Tokens.inkMuted
                font.family: "Material Symbols Rounded"
                font.pixelSize: 21 * root.s
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            HoverHandler { enabled: levelIcon.enabled; cursorShape: Qt.PointingHandCursor }
        }
        Column {
            anchors.left: levelIcon.right
            anchors.right: levelSlider.left
            anchors.leftMargin: Tokens.s2 * root.s
            anchors.rightMargin: Tokens.s3 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 1 * root.s
            Text {
                width: parent.width
                text: levelRow.label
                color: levelRow.available ? Tokens.ink : Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: Tokens.fRow * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: !levelRow.available ? I18n.tr("Unavailable")
                    : levelRow.detail !== "" ? levelRow.detail
                    : levelRow.muted ? I18n.tr("Muted")
                    : Math.round(levelRow.value * 100) + "%"
                color: Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall * root.s
                elide: Text.ElideRight
            }
        }
        Slid {
            id: levelSlider
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(116 * root.s, Math.min(184 * root.s, parent.width * 0.42))
            from: 0
            to: 1
            value: levelRow.value
            enabled: levelRow.available
            opacity: enabled ? 1 : 0.4
            onModified: value => levelRow.modifiedFn(value)
        }
    }

    component ModeButton: QQC.AbstractButton {
        id: modeButton
        required property string glyph
        required property string label
        required property string detail
        required property bool active
        required property bool armed
        required property var activateFn

        enabled: armed
        hoverEnabled: true
        implicitHeight: 66 * root.s
        height: implicitHeight
        Accessible.name: label
        Accessible.description: detail
        Accessible.checkable: true
        Accessible.checked: active
        onClicked: activateFn()
        opacity: enabled ? 1 : 0.5
        background: Rectangle {
            radius: Tokens.radius * root.s * 1.5
            color: modeButton.active ? Tokens.bone
                : modeButton.down ? Tokens.tint16
                : modeButton.hovered ? Tokens.tint10 : Tokens.tint5
            border.width: Tokens.border
            border.color: modeButton.visualFocus ? Tokens.sun
                : modeButton.active ? Tokens.bone : Tokens.lineSoft
        }
        contentItem: Row {
            spacing: Tokens.s2 * root.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 24 * root.s
                text: modeButton.glyph
                color: modeButton.active ? Tokens.inkOnBone : Tokens.inkDim
                font.family: "Material Symbols Rounded"
                font.pixelSize: 20 * root.s
                horizontalAlignment: Text.AlignHCenter
            }
            Column {
                width: parent.width - 24 * root.s - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                spacing: 1 * root.s
                Text {
                    width: parent.width
                    text: modeButton.label
                    color: modeButton.active ? Tokens.inkOnBone : Tokens.ink
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall * root.s
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: modeButton.detail
                    color: modeButton.active ? Tokens.inkOnBoneDim : Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fMicro * root.s
                    elide: Text.ElideRight
                }
            }
        }
        QQC.ToolTip.visible: hovered && (!enabled || detail !== "")
        QQC.ToolTip.text: detail
        HoverHandler { cursorShape: modeButton.enabled ? Qt.PointingHandCursor : Qt.ForbiddenCursor }
    }

    component SessionButton: QQC.AbstractButton {
        id: sessionButton
        required property string glyph
        required property string label
        required property var activateFn
        property bool danger: false

        hoverEnabled: true
        implicitHeight: 54 * root.s
        height: implicitHeight
        Accessible.name: label
        onClicked: activateFn()
        background: Rectangle {
            radius: Tokens.radius * root.s * 1.5
            color: sessionButton.down ? Tokens.tint16
                : sessionButton.hovered ? Tokens.tint10 : Tokens.tint5
            border.width: Tokens.border
            border.color: sessionButton.visualFocus ? Tokens.sun : Tokens.lineSoft
        }
        contentItem: Row {
            spacing: Tokens.s2 * root.s
            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 22 * root.s
                text: sessionButton.glyph
                color: sessionButton.danger ? Tokens.alert : Tokens.inkDim
                font.family: "Material Symbols Rounded"
                font.pixelSize: 20 * root.s
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                width: parent.width - 22 * root.s - parent.spacing
                anchors.verticalCenter: parent.verticalCenter
                text: sessionButton.label
                color: Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall * root.s
                font.weight: Font.Medium
                elide: Text.ElideRight
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    SidebarCardShell {
        id: shell
        width: root.width
        index: root.index
        open: root.open
        reveal: root.reveal
        tabActive: root.tabActive
        compact: root.compact
        title: I18n.tr("System")
        s: root.s
        glyph: "tune"

        Column {
            id: overview
            visible: root.detailPage === "overview"
            width: parent.width
            spacing: root.gap

            Item {
                width: parent.width
                implicitHeight: overviewHeading.implicitHeight
                height: implicitHeight
                Column {
                    id: overviewHeading
                    width: parent.width
                    spacing: Tokens.s1 * root.s
                    Text {
                        width: parent.width
                        text: Battery.present
                            ? I18n.tr("%1% battery · %2").arg(Battery.pct).arg(Battery.stateLabel)
                            : I18n.tr("Sound, display, connections and session")
                        color: Battery.low ? Tokens.alert : Tokens.inkMuted
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall * root.s
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                    }
                }
            }

            Panel {
                width: parent.width
                title: I18n.tr("Connections")
                subtitle: Network.wired.connectivity === "Connected"
                    ? (Network.vpnActive ? I18n.tr("Wired connection active · %1 VPN active").arg(Network.vpnName) : I18n.tr("Wired connection active"))
                    : Network.vpnActive ? I18n.tr("%1 VPN active").arg(Network.vpnName)
                    : I18n.tr("Networks and nearby devices")

                Grid {
                    width: parent.width
                    columns: width >= 560 * root.s ? 2 : 1
                    spacing: Tokens.s3 * root.s

                    ConnectionTile {
                        width: (parent.width - parent.spacing * (parent.columns - 1)) / parent.columns
                        glyph: "wifi"
                        title: I18n.tr("Wi-Fi")
                        detail: root.wifiSummary
                        available: Network.wifiPresent
                        radioOn: Network.wifiRadio
                        toggleFn: () => Toggles.toggleWifi()
                        manageFn: () => root.showDetail("wifi")
                    }
                    ConnectionTile {
                        width: (parent.width - parent.spacing * (parent.columns - 1)) / parent.columns
                        glyph: "bluetooth"
                        title: I18n.tr("Bluetooth")
                        detail: root.connectedBtSummary
                        available: root.btAdapter !== null
                        radioOn: root.btAdapter !== null && root.btAdapter.enabled
                        toggleFn: () => Toggles.toggleBt()
                        manageFn: () => root.showDetail("bluetooth")
                    }
                }
            }

            Grid {
                id: dashboardGrid
                width: parent.width
                columns: width >= 560 * root.s ? 2 : 1
                spacing: root.gap

                Panel {
                    width: (dashboardGrid.width - dashboardGrid.spacing * (dashboardGrid.columns - 1)) / dashboardGrid.columns
                    title: I18n.tr("Sound and display")
                    subtitle: I18n.tr("Volume, microphone and brightness")

                    LevelRow {
                        glyph: Audio.sink && Audio.sink.audio && Audio.sink.audio.muted ? "volume_off" : "volume_up"
                        label: I18n.tr("Volume")
                        value: Audio.sink && Audio.sink.audio ? Audio.sink.audio.volume : 0
                        available: !!(Audio.sink && Audio.sink.audio)
                        muteable: true
                        muted: !!(Audio.sink && Audio.sink.audio && Audio.sink.audio.muted)
                        muteFn: () => {
                            if (Audio.sink && Audio.sink.audio)
                                Audio.sink.audio.muted = !Audio.sink.audio.muted;
                        }
                        modifiedFn: value => root.setVolume(value)
                    }
                    LevelRow {
                        glyph: Toggles.micMuted ? "mic_off" : "mic"
                        label: I18n.tr("Microphone")
                        value: Audio.source && Audio.source.audio ? Audio.source.audio.volume : 0
                        available: !!(Audio.source && Audio.source.audio)
                        muteable: true
                        muted: Toggles.micMuted
                        muteFn: () => Toggles.toggleMic()
                        modifiedFn: value => root.setMicVolume(value)
                    }
                    SidebarButton {
                        width: parent.width
                        s: root.s
                        glyph: "equalizer"
                        text: I18n.tr("Audio mixer")
                        onAct: root.showDetail("audio")
                        scale: down ? 0.98 : 1
                        Behavior on scale { enabled: root.motionAllowed; NumberAnimation { duration: Tokens.snap; easing.type: Tokens.easeSnap } }
                    }
                    LevelRow {
                        glyph: "brightness_6"
                        label: I18n.tr("Brightness")
                        value: root.brightnessValue
                        available: root.brightnessAvailable
                        detail: root.brightnessAvailable && !Devices.backlightAvailable ? root.focusedOutput : ""
                        modifiedFn: value => root.setBrightness(value)
                    }
                }

                Panel {
                    width: (dashboardGrid.width - dashboardGrid.spacing * (dashboardGrid.columns - 1)) / dashboardGrid.columns
                    title: I18n.tr("Power and focus")
                    subtitle: Battery.present
                        ? Battery.stateLabel + (Battery.hasTime ? " · " + Battery.timeStr : "")
                        : I18n.tr("AC power · no battery reported")

                    Item {
                        width: parent.width
                        implicitHeight: Math.max(powerReadout.implicitHeight, batteryPct.implicitHeight)
                        height: implicitHeight
                        Column {
                            id: powerReadout
                            anchors.left: parent.left
                            anchors.right: batteryPct.visible ? batteryPct.left : parent.right
                            anchors.rightMargin: batteryPct.visible ? Tokens.s3 * root.s : 0
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: Tokens.s1 * root.s
                            Text {
                                width: parent.width
                                text: I18n.tr("Power profile")
                                color: Tokens.inkMuted
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fSmall * root.s
                            }
                            Text {
                                width: parent.width
                                text: PowerProfiles.available ? root.profileLabel(PowerProfiles.profile)
                                    : I18n.tr("Unavailable")
                                color: Tokens.ink
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fValue * root.s
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }
                        Text {
                            id: batteryPct
                            visible: Battery.present
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: Battery.pct + "%"
                            color: Battery.low ? Tokens.alert : Tokens.ink
                            font.family: Tokens.display
                            font.pixelSize: Tokens.fHero * root.s
                            font.weight: Font.DemiBold
                        }
                    }

                    SidebarSegments {
                        s: root.s
                        visible: PowerProfiles.available
                        width: parent.width
                        options: PowerProfiles.profiles
                        labels: root.profileLabels()
                        current: PowerProfiles.profile
                        onChose: profile => PowerProfiles.setProfile(profile)
                    }

                    Grid {
                        width: parent.width
                        columns: width >= 280 * root.s ? 2 : 1
                        spacing: Tokens.s2 * root.s

                        ModeButton {
                            width: (parent.width - parent.spacing * (parent.columns - 1)) / parent.columns
                            glyph: "do_not_disturb_on"
                            label: I18n.tr("Do not disturb")
                            detail: Toggles.dnd ? I18n.tr("Notifications paused") : I18n.tr("Notifications allowed")
                            active: Toggles.dnd
                            armed: true
                            activateFn: () => Toggles.toggleDnd()
                        }
                        ModeButton {
                            width: (parent.width - parent.spacing * (parent.columns - 1)) / parent.columns
                            glyph: "bedtime"
                            label: I18n.tr("Night light")
                            detail: Wm.caps.nightLight === true
                                ? (Toggles.nightOn ? I18n.tr("Warm display") : I18n.tr("Neutral display"))
                                : I18n.tr("Not supported")
                            active: Toggles.nightOn
                            armed: Wm.caps.nightLight === true
                            activateFn: () => Toggles.toggleNight()
                        }
                        ModeButton {
                            width: (parent.width - parent.spacing * (parent.columns - 1)) / parent.columns
                            glyph: "coffee"
                            label: I18n.tr("Keep awake")
                            detail: Toggles.keepAwake ? I18n.tr("Sleep blocked") : I18n.tr("Normal idle")
                            active: Toggles.keepAwake
                            armed: true
                            activateFn: () => Toggles.toggleCaffeine()
                        }
                        ModeButton {
                            width: (parent.width - parent.spacing * (parent.columns - 1)) / parent.columns
                            glyph: "sports_esports"
                            label: I18n.tr("Game mode")
                            detail: !Battery.onAc ? I18n.tr("Needs AC power")
                                : Wm.caps.liveConfigEval !== true ? I18n.tr("Not supported")
                                : Toggles.gameMode ? I18n.tr("Performance held") : I18n.tr("Normal performance")
                            active: Toggles.gameMode
                            armed: Toggles.gameMode || (Battery.onAc && Wm.caps.liveConfigEval === true)
                            activateFn: () => Toggles.toggleGame()
                        }
                    }
                }
            }

            Panel {
                width: parent.width
                title: I18n.tr("Session")
                subtitle: I18n.tr("Lock immediately, or confirm before ending the session.")

                Grid {
                    width: parent.width
                    columns: width >= 620 * root.s ? 4 : width >= 310 * root.s ? 2 : 1
                    spacing: Tokens.s2 * root.s

                    SessionButton {
                        width: (parent.width - parent.spacing * (parent.columns - 1)) / parent.columns
                        glyph: "lock"
                        label: I18n.tr("Lock")
                        activateFn: () => {
                            root.requestClose();
                            Spawn.run(["ryoku-shell", "lock"]);
                        }
                    }
                    SessionButton {
                        width: (parent.width - parent.spacing * (parent.columns - 1)) / parent.columns
                        glyph: "logout"
                        label: I18n.tr("Log out")
                        activateFn: () => root.sessionAction("logout")
                    }
                    SessionButton {
                        width: (parent.width - parent.spacing * (parent.columns - 1)) / parent.columns
                        glyph: "restart_alt"
                        label: I18n.tr("Reboot")
                        activateFn: () => root.sessionAction("reboot")
                    }
                    SessionButton {
                        width: (parent.width - parent.spacing * (parent.columns - 1)) / parent.columns
                        glyph: "power_settings_new"
                        label: I18n.tr("Shut down")
                        danger: true
                        activateFn: () => root.sessionAction("shutdown")
                    }
                }
            }
        }

        Cards.SystemWifiPage {
            visible: root.detailPage === "wifi"
            width: parent.width
            s: root.s
            active: visible && root.open && root.tabActive
            onBackRequested: root.showDetail("overview")
        }

        Cards.SystemBluetoothPage {
            visible: root.detailPage === "bluetooth"
            width: parent.width
            s: root.s
            active: visible && root.open && root.tabActive
            onBackRequested: root.showDetail("overview")
        }

        Cards.SystemAudioPage {
            visible: root.detailPage === "audio"
            width: parent.width
            s: root.s
            active: visible && root.open && root.tabActive
            onBackRequested: root.showDetail("overview")
        }
    }
}
