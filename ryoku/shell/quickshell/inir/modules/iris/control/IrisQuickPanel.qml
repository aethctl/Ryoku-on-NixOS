pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import inir
import inir.services
import inir.modules.common
import inir.modules.common.functions
import inir.modules.common.widgets
import inir.modules.mediaControls.components
import inir.modules.iris.components
import inir.modules.iris.style

GridLayout {
    id: root
    property var targetScreen
    readonly property real d: IrisStyle.density
    readonly property var monitor: Brightness.getMonitorForScreen(root.targetScreen)
    readonly property real blockRadius: IrisStyle.radiusPlate
    readonly property color blockColor: IrisStyle.fillQuiet
    property string picker: ""
    readonly property bool roundControls: String(Config.options?.iris?.controlCenter?.controls ?? "tiles") === "round"
    property string hint: ""
    columns: 1
    columnSpacing: 0
    rowSpacing: 10 * root.d
    opacity: IrisStyle.recompose

    readonly property var sectionKinds: ["connectivity", "media", "shortcuts", "levels", "notifications"]
    // Through the shared recompose clock: the panel is rebuilt at the bottom of
    // one dip instead of every section animating into its new place.
    readonly property var sections: Array.from(IrisStyle.structuralValue("controlCenter.sections", root.sectionKinds))
        .filter(kind => root.sectionKinds.includes(kind))
    function has(kind: string): bool { return root.sections.includes(kind) }
    function rowOf(kinds: var): int {
        const indices = kinds.map(kind => root.sections.indexOf(kind)).filter(index => index >= 0)
        return indices.length > 0 ? 1 + 2 * Math.min(...indices) : -1
    }

    component Block: Rectangle {
        radius: root.blockRadius
        color: root.blockColor
    }

    component RoundToggle: ColumnLayout {
        id: toggle
        property string glyph: ""
        property string label: ""
        property bool checked: false
        property bool labelled: true
        property color tint: IrisStyle.accent
        property real size: Math.round(46 * root.d)
        signal toggled()
        spacing: 4 * root.d
        IrisButton {
            Layout.alignment: Qt.AlignHCenter
            implicitWidth: toggle.size
            implicitHeight: implicitWidth
            buttonRadius: height / 2
            buttonRadiusPressed: height / 2
            colBackground: toggle.checked ? toggle.tint : IrisStyle.fill
            colBackgroundHover: toggle.checked ? ColorUtils.mix(toggle.tint, IrisStyle.text, 0.85) : IrisStyle.fillHover
            Accessible.name: toggle.label
            Accessible.checkable: true
            Accessible.checked: toggle.checked
            onClicked: toggle.toggled()
            MaterialSymbol {
                anchors.centerIn: parent
                text: toggle.glyph
                fill: toggle.checked ? 1 : 0
                iconSize: Math.round(21 * root.d)
                color: !toggle.checked ? IrisStyle.text : IrisStyle.onTintFor(toggle.tint)
            }
        }
        IrisText {
            Layout.alignment: Qt.AlignHCenter
            Layout.maximumWidth: Math.round(72 * root.d)
            visible: toggle.labelled
            text: toggle.label
            elide: Text.ElideRight
            color: IrisStyle.subtext
            font.pixelSize: 10.5 * IrisStyle.typeScale
            font.weight: Font.Medium
        }
    }

    component ShortcutTile: IrisButton {
        id: tile
        property string glyph: ""
        property string label: ""
        property bool lit: false
        property color tint: IrisStyle.accent
        readonly property real round: root.roundControls ? Math.round(44 * root.d) : 0
        Layout.fillWidth: !root.roundControls
        Layout.alignment: root.roundControls ? Qt.AlignHCenter : Qt.AlignVCenter
        Layout.preferredWidth: root.roundControls ? tile.round : -1
        Layout.preferredHeight: root.roundControls ? tile.round : Math.round(50 * root.d)
        buttonRadius: root.roundControls ? height / 2 : IrisStyle.radiusTile
        buttonRadiusPressed: buttonRadius
        colBackground: tile.lit ? tile.tint : root.blockColor
        colBackgroundHover: tile.lit ? ColorUtils.mix(tile.tint, IrisStyle.text, 0.85) : IrisStyle.fillHover
        Accessible.name: tile.label
        MaterialSymbol {
            anchors.centerIn: parent
            text: tile.glyph
            fill: tile.lit ? 1 : 0
            iconSize: Math.round(21 * root.d)
            color: !tile.lit ? IrisStyle.text : IrisStyle.onTintFor(tile.tint)
        }
        HoverHandler { onHoveredChanged: root.hint = hovered ? tile.label : (root.hint === tile.label ? "" : root.hint) }
    }

    RowLayout {
        Layout.row: 0
        Layout.fillWidth: true
        Layout.leftMargin: 4 * root.d
        Layout.rightMargin: 2 * root.d
        spacing: 8 * root.d
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            IrisText {
                text: Translation.tr("Control Center")
                font.pixelSize: 16 * IrisStyle.typeScale
                font.weight: Font.DemiBold
            }
            IrisText {
                text: root.hint || DateTime.date
                role: IrisText.Meta
                color: root.hint ? IrisStyle.text : IrisStyle.subtext
                font.pixelSize: 11.5 * IrisStyle.typeScale
            }
        }
        IrisIconButton {
            materialIcon: "lock"
            Accessible.name: Translation.tr("Lock")
            onClicked: {
                GlobalStates.controlPanelOpen = false
                Quickshell.execDetached(["ryoku-shell", "lock"])
            }
        }
        IrisIconButton {
            id: settingsButton
            materialIcon: "settings"
            Accessible.name: Translation.tr("Settings")
            onClicked: {
                GlobalStates.controlPanelOpen = false
                const p = settingsButton.mapToItem(null, 0, 0)
                GlobalStates.irisMorphOrigin = { x: p.x, y: p.y, width: settingsButton.width, height: settingsButton.height,
                    radius: settingsButton.height / 2, screen: GlobalStates.focusedScreen?.name ?? "" }
                GlobalStates.irisMorphOwner = "control"
                GlobalStates.openSettings()
            }
        }
        IrisIconButton {
            materialIcon: "power_settings_new"
            Accessible.name: Translation.tr("Session")
            onClicked: { GlobalStates.controlPanelOpen = false; GlobalStates.sessionOpen = true }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.row: Math.max(1, root.rowOf(["connectivity", "media"]))
        visible: root.rowOf(["connectivity", "media"]) >= 0
        spacing: 10 * root.d

        Block {
            visible: root.has("connectivity")
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            implicitHeight: connectivity.implicitHeight + 24 * root.d
            GridLayout {
                id: connectivity
                anchors.centerIn: parent
                columns: 2
                columnSpacing: 14 * root.d
                rowSpacing: 8 * root.d
                RoundToggle {
                    glyph: Network.ethernet ? "lan" : Network.wifiEnabled ? "wifi" : "wifi_off"
                    label: Network.ethernet ? Translation.tr("Ethernet") : (Network.networkName || Translation.tr("Wi-Fi"))
                    checked: Network.ethernet || Network.wifiEnabled
                    onToggled: Network.toggleWifi()
                }
                RoundToggle {
                    glyph: BluetoothStatus.enabled ? "bluetooth" : "bluetooth_disabled"
                    label: BluetoothStatus.activeDeviceSummary() || Translation.tr("Bluetooth")
                    checked: BluetoothStatus.enabled
                    enabled: BluetoothStatus.available
                    onToggled: { if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled }
                }
                RoundToggle {
                    glyph: Notifications.manualDndActive ? "do_not_disturb_on" : "do_not_disturb_off"
                    label: Translation.tr("Focus")
                    checked: Notifications.manualDndActive
                    tint: IrisStyle.identity.indigo
                    onToggled: Notifications.toggleSilent()
                }
                RoundToggle {
                    glyph: "sports_esports"
                    label: GameMode.autoActivated ? Translation.tr("Game · auto") : Translation.tr("Game mode")
                    checked: GameMode.active
                    tint: IrisStyle.identity.green
                    onToggled: GameMode.toggle()
                }
            }
        }

        Block {
            id: nowPlaying
            visible: root.has("media")
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.fillHeight: true
            clip: true
            readonly property bool hasPlayer: MprisController.activePlayer !== null && MprisController.activePlayer !== undefined
            PlayerBase { id: media; player: MprisController.activePlayer; positionUpdatesActive: nowPlaying.visible }
            Loader {
                anchors.fill: parent
                active: nowPlaying.hasPlayer && (Config.options?.iris?.player?.artworkBackground ?? true)
                    && MediaArtwork.displaySource.length > 0
                sourceComponent: IrisMediaBackdrop { source: MediaArtwork.displaySource; radius: root.blockRadius }
            }
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12 * root.d
                spacing: 4 * root.d
                IrisArtwork {
                    Layout.preferredWidth: 40 * root.d
                    Layout.preferredHeight: 40 * root.d
                    source: MediaArtwork.displaySource
                    circular: Config.options?.iris?.player?.roundCover ?? true
                    radius: circular ? width / 2 : 10 * root.d
                }
                Item { Layout.fillHeight: true }
                IrisText {
                    Layout.fillWidth: true
                    text: nowPlaying.hasPlayer ? media.effectiveTitle : Translation.tr("Not playing")
                    font.pixelSize: 13 * IrisStyle.typeScale
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }
                IrisText {
                    Layout.fillWidth: true
                    text: nowPlaying.hasPlayer ? media.effectiveArtist : Translation.tr("Music will show here")
                    color: IrisStyle.textSecondary
                    font.pixelSize: 11.5 * IrisStyle.typeScale
                    elide: Text.ElideRight
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Repeater {
                        model: [
                            { glyph: "fast_rewind", action: "previous" },
                            { glyph: media.effectiveIsPlaying ? "pause" : "play_arrow", action: "toggle" },
                            { glyph: "fast_forward", action: "next" }
                        ]
                        IrisButton {
                            id: transportButton
                            required property var modelData
                            Layout.fillWidth: true
                            quiet: true
                            enabled: nowPlaying.hasPlayer
                            implicitHeight: Math.round(30 * root.d)
                            buttonRadius: height / 2
                            Accessible.name: modelData.action
                            onClicked: modelData.action === "previous" ? media.previous()
                                : modelData.action === "next" ? media.next() : media.togglePlaying()
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: transportButton.modelData.glyph
                                fill: 1
                                iconSize: Math.round((transportButton.modelData.action === "toggle" ? 26 : 20) * root.d)
                                color: nowPlaying.hasPlayer ? IrisStyle.text : IrisStyle.textTertiary
                            }
                        }
                    }
                }
            }
        }
    }

    RowLayout {
        id: controlsRow
        Layout.fillWidth: true
        Layout.row: Math.max(1, root.rowOf(["shortcuts", "levels"]))
        visible: root.rowOf(["shortcuts", "levels"]) >= 0
        spacing: 10 * root.d
        readonly property bool levelsAlone: !root.has("shortcuts")
        readonly property real levelWidth: Math.round(46 * root.d)

        Block {
            visible: root.has("shortcuts")
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: root.roundControls ? root.blockColor : "transparent"
            implicitHeight: tileGrid.implicitHeight + (root.roundControls ? 20 * root.d : 0)
            GridLayout {
            id: tileGrid
            anchors.centerIn: parent
            width: root.roundControls ? implicitWidth : parent.width
            columns: 3
            rowSpacing: root.roundControls ? 10 * root.d : 8 * root.d
            columnSpacing: root.roundControls ? 12 * root.d : 8 * root.d
            ShortcutTile {
                glyph: "contrast"
                label: Translation.tr("Dark")
                lit: Appearance.m3colors.darkmode
                onClicked: Appearance.toggleDarkMode()
            }
            ShortcutTile {
                glyph: "nightlight"
                label: Translation.tr("Night light")
                lit: Nightlight.active
                onClicked: Nightlight.toggle()
            }
            ShortcutTile {
                glyph: "coffee"
                label: Translation.tr("Stay awake")
                lit: Idle.inhibit
                onClicked: Idle.toggleInhibit()
            }
            ShortcutTile {
                glyph: "screenshot_region"
                label: Translation.tr("Capture")
                onClicked: {
                    GlobalStates.controlPanelOpen = false
                    GlobalStates.launchRegionCapture("")
                }
            }
            ShortcutTile {
                glyph: RecorderStatus.isRecording ? "stop_circle" : "radio_button_checked"
                label: RecorderStatus.isRecording ? Translation.tr("Stop recording") : Translation.tr("Record screen")
                lit: RecorderStatus.isRecording
                tint: IrisStyle.danger
                onClicked: {
                    const args = ["/usr/bin/bash", Directories.recordScriptPath]
                    args.push(...(RecorderStatus.isRecording ? ["--stop"] : ["--fullscreen", "--sound"]))
                    Quickshell.execDetached(args)
                    RecorderStatus.scheduleQuickCheck()
                    if (!RecorderStatus.isRecording) GlobalStates.controlPanelOpen = false
                }
            }
            ShortcutTile {
                glyph: /head|bluez|airpod|buds/i.test(String(Audio.defaultSink?.name ?? "") + String(Audio.defaultSink?.description ?? ""))
                    ? "headphones" : "speaker"
                label: Translation.tr("Sound devices")
                lit: root.picker !== ""
                onClicked: root.picker = root.picker === "" ? "devices" : ""
            }
            }
        }

        IrisCapsuleSlider {
            vertical: true
            visible: root.has("levels")
            Layout.preferredWidth: controlsRow.levelWidth
            Layout.fillWidth: controlsRow.levelsAlone
            Layout.preferredHeight: controlsRow.levelsAlone ? Math.round(150 * root.d) : -1
            Layout.fillHeight: true
            enabled: root.monitor !== null
            icon: "light_mode"
            value: root.monitor?.brightness ?? 0
            Accessible.name: Translation.tr("Brightness")
            onMoved: next => root.monitor?.setBrightness(next)
        }
        IrisCapsuleSlider {
            vertical: true
            visible: root.has("levels")
            Layout.preferredWidth: controlsRow.levelWidth
            Layout.fillWidth: controlsRow.levelsAlone
            Layout.preferredHeight: controlsRow.levelsAlone ? Math.round(150 * root.d) : -1
            Layout.fillHeight: true
            muted: Audio.sink?.audio?.muted ?? false
            icon: muted ? "volume_off" : (Audio.value ?? 0) < 0.34 ? "volume_mute" : (Audio.value ?? 0) < 0.67 ? "volume_down" : "volume_up"
            value: Math.min(1, Audio.value ?? 0)
            Accessible.name: Translation.tr("Volume")
            onMoved: next => Audio.setSinkVolume(next)
            onIconClicked: Audio.toggleMute()
        }
        IrisCapsuleSlider {
            vertical: true
            visible: Audio.source !== null && root.has("levels")
            Layout.preferredWidth: controlsRow.levelWidth
            Layout.fillWidth: controlsRow.levelsAlone
            Layout.preferredHeight: controlsRow.levelsAlone ? Math.round(150 * root.d) : -1
            Layout.fillHeight: true
            muted: Audio.micMuted
            icon: muted ? "mic_off" : "mic"
            value: Math.min(1, Audio.micVolume ?? 0)
            Accessible.name: Translation.tr("Microphone")
            onMoved: next => Audio.setSourceVolume(next)
            onIconClicked: Audio.toggleMicMute()
        }
    }

    Block {
        Layout.fillWidth: true
        Layout.row: Math.max(1, root.rowOf(["shortcuts", "levels"])) + 1
        visible: implicitHeight > 1 && root.has("levels")
        clip: true
        implicitHeight: root.picker !== "" ? deviceList.implicitHeight + 12 * root.d : 0
        Behavior on implicitHeight { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve } }
        IrisDeviceList {
            id: deviceList
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6 * root.d
        }
    }

    Block {
        Layout.fillWidth: true
        Layout.row: Math.max(1, root.rowOf(["notifications"]))
        visible: root.has("notifications")
        implicitHeight: notificationColumn.implicitHeight + 20 * root.d
        ColumnLayout {
            id: notificationColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 10 * root.d
            anchors.leftMargin: 14 * root.d
            spacing: 6 * root.d
            RowLayout {
                Layout.fillWidth: true
                IrisText {
                    Layout.fillWidth: true
                    text: Notifications.list.length > 0
                        ? Translation.tr("Notifications") + "  ·  " + Notifications.list.length
                        : Translation.tr("Notifications")
                    font.pixelSize: 12.5 * IrisStyle.typeScale
                    font.weight: Font.DemiBold
                }
                IrisButton {
                    visible: Notifications.list.length > 0
                    quiet: true
                    text: Translation.tr("Clear")
                    implicitHeight: Math.round(26 * root.d)
                    buttonRadius: height / 2
                    onClicked: Notifications.discardAllNotifications()
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4 * root.d
                Layout.bottomMargin: 8 * root.d
                visible: Notifications.list.length === 0
                spacing: 8 * root.d
                MaterialSymbol { text: "notifications_none"; iconSize: Math.round(18 * root.d); color: IrisStyle.muted }
                IrisText { text: Translation.tr("You're all caught up"); role: IrisText.Meta }
            }
            Repeater {
                model: Notifications.appNameList.slice(0, 3)
                RowLayout {
                    id: groupRow
                    required property string modelData
                    readonly property var group: Notifications.groupsByAppName[modelData]
                    readonly property var latest: {
                        const n = groupRow.group?.notifications?.[groupRow.group.notifications.length - 1]
                        return n ? { summary: String(n.summary ?? ""), body: String(n.body ?? ""), urgency: String(n.urgency ?? "") } : null
                    }
                    Layout.fillWidth: true
                    spacing: 10 * root.d
                    IrisNotificationIcon {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 2 * root.d
                        size: Math.round(28 * root.d)
                        showImage: false
                        appName: String(groupRow.modelData ?? "")
                        appIcon: String(groupRow.group?.appIcon ?? "")
                        summary: String(groupRow.latest?.summary ?? "")
                        critical: String(groupRow.latest?.urgency ?? "") === "critical"
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        RowLayout {
                            Layout.fillWidth: true
                            IrisText {
                                Layout.fillWidth: true
                                text: groupRow.latest?.summary || String(groupRow.modelData ?? "")
                                font.pixelSize: 12.5 * IrisStyle.typeScale
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Rectangle {
                                visible: (groupRow.group?.notifications?.length ?? 0) > 1
                                implicitWidth: countLabel.implicitWidth + 10 * root.d
                                implicitHeight: 16 * root.d
                                radius: height / 2
                                color: IrisStyle.fill
                                IrisText {
                                    id: countLabel
                                    anchors.centerIn: parent
                                    text: groupRow.group?.notifications?.length ?? 0
                                    font.pixelSize: 10 * IrisStyle.typeScale
                                    font.weight: Font.DemiBold
                                }
                            }
                        }
                        IrisText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: groupRow.latest?.body ?? ""
                            textFormat: Text.PlainText
                            maximumLineCount: 2
                            wrapMode: Text.WordWrap
                            elide: Text.ElideRight
                            role: IrisText.Meta
                        }
                    }
                    IrisIconButton {
                        Layout.alignment: Qt.AlignTop
                        materialIcon: "close"
                        iconSize: Math.round(15 * root.d)
                        implicitWidth: Math.round(26 * root.d)
                        Accessible.name: Translation.tr("Dismiss")
                        onClicked: (groupRow.group?.notifications ?? []).slice().forEach(n => Notifications.discardNotification(n.notificationId))
                    }
                }
            }
        }
    }
}
