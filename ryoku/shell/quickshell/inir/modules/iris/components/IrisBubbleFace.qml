pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import inir.services
import inir.modules.common
import inir.modules.common.functions
import inir.modules.common.widgets
import inir.modules.iris.style
import inir.modules.iris.pieces

Item {
    id: root

    property string kind: ""
    property string appId: ""
    property string screenName: ""
    readonly property real d: IrisStyle.density

    readonly property var player: MprisController.activePlayer
    property bool playing: root.player?.isPlaying ?? false
    property real mediaProgress: (root.player?.length ?? 0) > 0
        ? Math.max(0, Math.min(1, (root.player?.position ?? 0) / root.player.length)) : 0
    property color tint: IrisStyle.text
    property bool coverHidden: false
    readonly property alias artwork: cover

    readonly property string timerKind: TimerService.pomodoroRunning ? "pomodoro"
        : TimerService.countdownRunning ? "countdown"
        : TimerService.stopwatchRunning ? "stopwatch" : ""
    readonly property bool timerPaused: root.timerKind === "pomodoro" ? TimerService.pomodoroPaused
        : root.timerKind === "countdown" ? TimerService.countdownPaused : TimerService.stopwatchPaused
    readonly property real timerProgress: root.timerKind === "pomodoro"
        ? 1 - TimerService.pomodoroSecondsLeft / Math.max(1, TimerService.pomodoroLapDuration)
        : root.timerKind === "countdown"
            ? 1 - TimerService.countdownSecondsLeft / Math.max(1, TimerService.countdownDuration) : 0
    readonly property string timerGlyph: root.timerKind === "pomodoro" && TimerService.pomodoroBreak ? "coffee"
        : root.timerKind === "stopwatch" ? "timer" : "hourglass_top"

    property int trayCount: SystemTray.items.values.filter(item => item && item.id
        && (!(Config.options?.iris?.tray?.hidePassive ?? false) || item.status !== Status.passive)).length

    property bool pressed: false
    property bool hovered: false
    property bool plated: false
    property bool bodyless: false
    property real absorb: root.plated ? 1 : 0
    readonly property real platedInset: 3 * root.d * root.absorb

    component Glyph: MaterialSymbol {
        fill: 1
        color: IrisStyle.text
    }
    component Ring: Shape {
        id: ring
        property real progress: 0
        property color tint: IrisStyle.text
        property real stroke: Math.max(2, 2.5 * root.d)
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: IrisStyle.tintFill(ring.tint)
            strokeWidth: ring.stroke
            fillColor: "transparent"
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.width / 2 - ring.stroke / 2; radiusY: ring.width / 2 - ring.stroke / 2
                startAngle: 0; sweepAngle: 360
            }
        }
        ShapePath {
            strokeColor: ring.tint
            strokeWidth: ring.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: ring.width / 2; centerY: ring.height / 2
                radiusX: ring.width / 2 - ring.stroke / 2; radiusY: ring.width / 2 - ring.stroke / 2
                startAngle: -90
                sweepAngle: 360 * Math.max(0, Math.min(1, ring.progress))
            }
        }
    }

    Rectangle {
        visible: root.plated || root.bodyless
        anchors.fill: parent
        radius: IrisStyle.pieceRadius(width)
        color: root.pressed ? IrisStyle.fillActive
            : root.hovered ? IrisStyle.fillHover
            : ColorUtils.applyAlpha(IrisStyle.text, 0)
        Behavior on color { ColorAnimation { duration: IrisStyle.duration(120) } }
    }
    Rectangle {
        anchors.fill: parent
        radius: IrisStyle.pieceRadius(width)
        color: IrisStyle.bodySurface
        opacity: root.bodyless ? 0 : 1 - root.absorb
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
    }

    Item {
        anchors.fill: parent
        scale: root.pressed ? IrisStyle.pressScale(0.88) : root.hovered ? 1.06 : 1
        Behavior on scale { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }

        IrisArtwork {
            id: cover
            visible: root.kind === "media"
            opacity: root.coverHidden ? 0 : 1
            anchors.centerIn: parent
            width: parent.width - 12 * root.d - 2 * root.platedInset
            height: width
            source: MediaArtwork.displaySource
            circular: true
        }
        Rectangle {
            visible: root.kind === "media" && opacity > 0
            anchors.fill: cover
            radius: width / 2
            color: IrisStyle.veilStrong
            opacity: !root.playing && !root.coverHidden ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(140); easing.type: IrisStyle.feedbackEasing } }
            Glyph {
                anchors.centerIn: parent
                text: "pause"
                iconSize: 15 * root.d
            }
        }
        Ring {
            visible: root.kind === "media" || (root.kind === "timer" && root.timerKind !== "stopwatch")
            anchors.fill: parent
            anchors.margins: 2 * root.d + root.platedInset
            opacity: root.coverHidden ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
            tint: root.kind === "media" ? root.tint : IrisStyle.secondaryAccent
            progress: root.kind === "media" ? root.mediaProgress : root.timerProgress
        }
        Glyph {
            visible: root.kind === "timer"
            anchors.centerIn: parent
            text: root.timerPaused ? "pause" : root.timerGlyph
            iconSize: 16 * root.d
            color: IrisStyle.secondaryAccent
        }
        Ring {
            readonly property var task: LiveActivities.latest
            visible: root.kind === "task" && Number(task?.progress ?? -1) >= 0
            anchors.fill: parent
            anchors.margins: 2 * root.d + root.platedInset
            tint: IrisStyle.identityColor(String(task?.tint ?? "lavender"))
            progress: Math.max(0, Number(task?.progress ?? 0))
        }
        Glyph {
            readonly property var task: LiveActivities.latest
            visible: root.kind === "task"
            anchors.centerIn: parent
            text: String(task?.glyph ?? "bolt")
            iconSize: 16 * root.d
            color: IrisStyle.identityColor(String(task?.tint ?? "lavender"))
        }
        Rectangle {
            id: recordDot
            visible: root.kind === "record"
            anchors.centerIn: parent
            width: 12 * root.d
            height: width
            radius: width / 2
            color: IrisStyle.danger
            SequentialAnimation on opacity {
                running: recordDot.visible && IrisStyle.motionEnabled
                loops: Animation.Infinite
                NumberAnimation { to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
                onRunningChanged: if (!running) recordDot.opacity = 1
            }
        }
        SmartAppIcon {
            visible: root.kind === "app"
            anchors.centerIn: parent
            icon: IrisPieces.appIcon(root.appId)
            fallback: "application-x-executable"
            iconSize: Math.round(parent.width - (12 + 4 * root.absorb) * root.d)
        }
        Glyph {
            visible: root.kind === "controls"
            anchors.centerIn: parent
            text: Network.wifiEnabled ? "wifi" : "tune"
            fill: 0
            iconSize: 19 * root.d
        }
        readonly property int toolsMinutesLeft: root.timerKind === "pomodoro" ? Math.ceil(TimerService.pomodoroSecondsLeft / 60)
            : root.timerKind === "countdown" ? Math.ceil(TimerService.countdownSecondsLeft / 60) : -1
        Ring {
            visible: root.kind === "tools" && parent.toolsMinutesLeft >= 0
            anchors.fill: parent
            anchors.margins: 3 * root.d + root.platedInset
            tint: IrisStyle.secondaryAccent
            progress: root.timerProgress
        }
        Glyph {
            visible: root.kind === "tools" && parent.toolsMinutesLeft < 0
            anchors.centerIn: parent
            text: "timer"
            iconSize: 19 * root.d
            color: IrisStyle.secondaryAccent
        }
        IrisText {
            visible: root.kind === "tools" && parent.toolsMinutesLeft >= 0
            anchors.centerIn: parent
            text: parent.toolsMinutesLeft
            font.family: IrisStyle.fontNumbers
            font.features: ({ "tnum": 1 })
            font.pixelSize: 13 * IrisStyle.typeScale
            font.weight: Font.Bold
            color: IrisStyle.secondaryAccent
        }
        IrisText {
            visible: root.kind === "tray"
            anchors.centerIn: parent
            text: root.trayCount
            font.family: IrisStyle.fontNumbers
            font.features: ({ "tnum": 1 })
            font.pixelSize: 16 * IrisStyle.typeScale
            font.weight: Font.Bold
            color: IrisStyle.accent
        }
        Ring {
            visible: root.kind === "sound" || root.kind === "mic"
            anchors.fill: parent
            anchors.margins: 3 * root.d + root.platedInset
            readonly property bool muted: root.kind === "mic" ? Audio.micMuted : (Audio.sink?.audio?.muted ?? false)
            tint: muted ? (root.kind === "mic" ? IrisStyle.danger : IrisStyle.muted) : IrisStyle.text
            progress: muted ? 0 : Math.min(1, root.kind === "mic" ? (Audio.micVolume ?? 0) : (Audio.value ?? 0))
            Behavior on progress { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
        }
        Glyph {
            visible: root.kind === "sound" || root.kind === "mic"
            anchors.centerIn: parent
            text: root.kind === "mic" ? (Audio.micMuted ? "mic_off" : "mic")
                : (Audio.sink?.audio?.muted ?? false) ? "volume_off" : "volume_up"
            iconSize: 15 * root.d
            color: root.kind === "mic" && Audio.micMuted ? IrisStyle.danger : IrisStyle.text
        }
        Column {
            id: weatherFace
            readonly property string raw: String(Weather.data?.temp ?? "")
            readonly property bool ready: !weatherFace.raw.startsWith("--") && weatherFace.raw.length > 0
            readonly property string degrees: {
                const value = parseFloat(weatherFace.raw)
                return isNaN(value) ? "" : Math.round(value) + "°"
            }
            visible: root.kind === "weather"
            anchors.centerIn: parent
            anchors.verticalCenterOffset: weatherFace.ready ? root.d : 0
            spacing: -Math.round(2 * root.d)
            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Icons.getWeatherIcon(Weather.data?.wCode, Weather.isNightNow()) ?? "cloud"
                iconSize: (weatherFace.ready ? 13 : 19) * root.d
            }
            IrisText {
                visible: weatherFace.ready
                anchors.horizontalCenter: parent.horizontalCenter
                text: weatherFace.degrees
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: 11.5 * IrisStyle.typeScale
                font.weight: Font.Bold
            }
        }
        Column {
            id: calendarFace
            visible: root.kind === "calendar"
            anchors.centerIn: parent
            spacing: -Math.round(3 * root.d)
            IrisText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Qt.locale().toString(DateTime.clock.date, "ddd")
                color: IrisStyle.identity.red
                font.pixelSize: 8.5 * IrisStyle.typeScale
                font.weight: Font.Bold
            }
            IrisText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: DateTime.clock.date.getDate()
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: 16 * IrisStyle.typeScale
                font.weight: Font.Bold
            }
        }
        Item {
            id: clockFace
            visible: root.kind === "clock"
            anchors.fill: parent
            anchors.margins: 3 * root.d + root.platedInset
            readonly property var now: DateTime.clock.date
            readonly property real minutes: clockFace.now.getMinutes() + clockFace.now.getSeconds() / 60
            readonly property real hours: (clockFace.now.getHours() % 12) + clockFace.minutes / 60
            Repeater {
                model: 12
                Rectangle {
                    required property int index
                    readonly property bool major: index % 3 === 0
                    visible: major || clockFace.width >= 30 * root.d
                    x: clockFace.width / 2 - width / 2
                    y: 0
                    width: Math.max(1, (major ? 1.6 : 1) * root.d)
                    height: (major ? 3 : 2) * root.d
                    radius: width / 2
                    color: major ? IrisStyle.text : IrisStyle.textTertiary
                    transform: Rotation { origin.x: width / 2; origin.y: clockFace.height / 2; angle: index * 30 }
                }
            }
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    strokeColor: IrisStyle.text
                    strokeWidth: Math.max(2, 2.2 * root.d)
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    startX: clockFace.width / 2; startY: clockFace.height / 2
                    PathLine {
                        x: clockFace.width / 2 + Math.sin(clockFace.hours * Math.PI / 6) * Math.min(clockFace.width, clockFace.height) * 0.27
                        y: clockFace.height / 2 - Math.cos(clockFace.hours * Math.PI / 6) * Math.min(clockFace.width, clockFace.height) * 0.27
                    }
                }
                ShapePath {
                    strokeColor: IrisStyle.text
                    strokeWidth: Math.max(1.5, 1.6 * root.d)
                    capStyle: ShapePath.RoundCap
                    fillColor: "transparent"
                    startX: clockFace.width / 2; startY: clockFace.height / 2
                    PathLine {
                        x: clockFace.width / 2 + Math.sin(clockFace.minutes * Math.PI / 30) * Math.min(clockFace.width, clockFace.height) * 0.4
                        y: clockFace.height / 2 - Math.cos(clockFace.minutes * Math.PI / 30) * Math.min(clockFace.width, clockFace.height) * 0.4
                    }
                }
            }
            Rectangle {
                anchors.centerIn: parent
                width: 3.5 * root.d
                height: width
                radius: width / 2
                color: IrisStyle.identity.orange
            }
        }
        Ring {
            id: batteryRing
            visible: root.kind === "battery"
            anchors.fill: parent
            anchors.margins: 3 * root.d + root.platedInset
            readonly property real level: Math.max(0, Math.min(1, Battery.percentage))
            tint: Battery.isCharging ? IrisStyle.identity.green
                : Battery.isCritical ? IrisStyle.danger
                : Battery.isLow ? IrisStyle.secondaryAccent : IrisStyle.text
            progress: batteryRing.level
            Behavior on progress { NumberAnimation { duration: IrisStyle.duration(220); easing.type: IrisStyle.feedbackEasing } }
        }
        Column {
            visible: root.kind === "battery"
            anchors.centerIn: parent
            spacing: -Math.round(3 * root.d)
            Glyph {
                visible: Battery.isCharging
                anchors.horizontalCenter: parent.horizontalCenter
                text: "bolt"
                fill: 1
                iconSize: 11 * root.d
                color: IrisStyle.identity.green
            }
            IrisText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Math.round(batteryRing.level * 100)
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: (Battery.isCharging ? 10.5 : 12.5) * IrisStyle.typeScale
                font.weight: Font.Bold
                color: batteryRing.tint
            }
        }
        Rectangle {
            visible: root.kind === "focus"
            anchors.fill: parent
            anchors.margins: 3 * root.d + root.platedInset
            radius: Math.min(width / 2, Math.max(0, IrisStyle.pieceRadius(root.width) - anchors.margins))
            color: Notifications.silent ? IrisStyle.identity.indigo : "transparent"
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(180) } }
            Glyph {
                anchors.centerIn: parent
                text: "bedtime"
                fill: Notifications.silent ? 1 : 0
                iconSize: 17 * root.d
                color: Notifications.silent ? IrisStyle.onTint : IrisStyle.text
            }
        }
        Item {
            id: networkFace
            visible: root.kind === "network"
            anchors.fill: parent
            readonly property bool wired: Network.ethernet
            readonly property bool linked: networkFace.wired || (Network.wifiEnabled && Network.networkName.length > 0)
            Glyph {
                anchors.centerIn: parent
                text: networkFace.wired ? "lan" : !Network.wifiEnabled ? "wifi_off" : Network.materialSymbol
                iconSize: 18 * root.d
                color: networkFace.linked ? IrisStyle.text : IrisStyle.muted
            }
        }
        Item {
            id: bluetoothFace
            visible: root.kind === "bluetooth"
            anchors.fill: parent
            Column {
                anchors.centerIn: parent
                spacing: -Math.round(2 * root.d)
                Glyph {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: !BluetoothStatus.enabled ? "bluetooth_disabled"
                        : BluetoothStatus.activeDeviceCount > 0 ? "bluetooth_connected" : "bluetooth"
                    iconSize: (BluetoothStatus.activeDeviceCount > 0 ? 13 : 18) * root.d
                    color: !BluetoothStatus.enabled ? IrisStyle.muted
                        : BluetoothStatus.activeDeviceCount > 0 ? IrisStyle.accent : IrisStyle.text
                }
                IrisText {
                    visible: BluetoothStatus.activeDeviceCount > 0
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: BluetoothStatus.activeDeviceCount
                    color: IrisStyle.accent
                    font.family: IrisStyle.fontNumbers
                    font.features: ({ "tnum": 1 })
                    font.pixelSize: 11.5 * IrisStyle.typeScale
                    font.weight: Font.Bold
                }
            }
        }
        Ring {
            id: vitalsRing
            visible: root.kind === "vitals"
            anchors.fill: parent
            anchors.margins: 3 * root.d + root.platedInset
            readonly property real load: Math.max(0, Math.min(1, ResourceUsage.cpuUsage))
            tint: vitalsRing.load > 0.85 ? IrisStyle.danger
                : vitalsRing.load > 0.6 ? IrisStyle.secondaryAccent : IrisStyle.identity.teal
            progress: vitalsRing.load
            Behavior on progress { NumberAnimation { duration: IrisStyle.duration(220); easing.type: IrisStyle.feedbackEasing } }
        }
        IrisText {
            visible: root.kind === "vitals"
            anchors.centerIn: parent
            text: Math.round(vitalsRing.load * 100)
            color: vitalsRing.tint
            font.family: IrisStyle.fontNumbers
            font.features: ({ "tnum": 1 })
            font.pixelSize: 12.5 * IrisStyle.typeScale
            font.weight: Font.Bold
        }
        Column {
            id: workspacesFace
            visible: root.kind === "workspaces"
            anchors.centerIn: parent
            spacing: Math.round(2 * root.d)
            readonly property var list: (WorkspaceService.allWorkspaces ?? []).filter(ws => ws.output === root.screenName)
            readonly property var active: workspacesFace.list.find(ws => ws.is_active) ?? null
            IrisText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: workspacesFace.active ? workspacesFace.active.idx : "–"
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: 14 * IrisStyle.typeScale
                font.weight: Font.Bold
            }
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: Math.round(2 * root.d)
                Repeater {
                    model: Math.min(5, workspacesFace.list.length)
                    Rectangle {
                        required property int index
                        readonly property var entry: workspacesFace.list[index]
                        width: Math.max(2, 3 * root.d)
                        height: width
                        radius: width / 2
                        color: entry?.is_active ? IrisStyle.accent : IrisStyle.textTertiary
                    }
                }
            }
        }
        Column {
            id: updatesFace
            visible: root.kind === "updates"
            anchors.centerIn: parent
            spacing: Math.round(1.5 * root.d)
            readonly property int count: Updates.count
            Glyph {
                visible: updatesFace.count <= 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: "task_alt"
                iconSize: 18 * root.d
                color: IrisStyle.identity.green
            }
            IrisText {
                visible: updatesFace.count > 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: updatesFace.count > 99 ? "99+" : updatesFace.count
                color: IrisStyle.secondaryAccent
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: 15 * IrisStyle.typeScale
                font.weight: Font.Bold
            }
            Rectangle {
                visible: updatesFace.count > 0
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.max(3, 3.5 * root.d)
                height: width
                radius: width / 2
                color: IrisStyle.secondaryAccent
            }
        }
        Column {
            id: notificationFace
            readonly property int count: Notifications.list?.length ?? 0
            visible: root.kind === "notifications"
            anchors.centerIn: parent
            anchors.verticalCenterOffset: notificationFace.count > 0 ? root.d : 0
            spacing: -Math.round(2 * root.d)
            Glyph {
                anchors.horizontalCenter: parent.horizontalCenter
                text: notificationFace.count > 0 ? "notifications_active" : "notifications"
                iconSize: (notificationFace.count > 0 ? 13 : 18) * root.d
            }
            IrisText {
                visible: notificationFace.count > 0
                anchors.horizontalCenter: parent.horizontalCenter
                text: notificationFace.count > 99 ? "99+" : notificationFace.count
                color: IrisStyle.badgeInk
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: 11.5 * IrisStyle.typeScale
                font.weight: Font.Bold
            }
        }
    }

    ResourceUsageMonitor { target: root; active: root.kind === "vitals" }

    Accessible.role: Accessible.Button
    Accessible.name: root.kind === "controls" ? Translation.tr("Quick controls")
        : root.kind === "notifications" ? Translation.tr("Notifications")
        : root.kind === "tray" ? Translation.tr("Tray")
        : root.kind === "calendar" ? Translation.tr("Calendar")
        : root.kind === "clock" ? Translation.tr("Clock")
        : root.kind === "battery" ? Translation.tr("Battery")
        : root.kind === "focus" ? Translation.tr("Do Not Disturb")
        : root.kind === "tools" ? Translation.tr("Timers")
        : root.kind === "weather" ? Translation.tr("Weather")
        : root.kind === "media" ? Translation.tr("Now playing")
        : root.kind === "sound" ? Translation.tr("Sound")
        : root.kind === "mic" ? Translation.tr("Microphone")
        : root.kind === "network" ? Translation.tr("Network")
        : root.kind === "bluetooth" ? Translation.tr("Bluetooth")
        : root.kind === "vitals" ? Translation.tr("Vitals")
        : root.kind === "workspaces" ? Translation.tr("Workspaces")
        : root.kind === "updates" ? Translation.tr("Updates")
        : root.kind === "record" ? Translation.tr("Screen recording") : Translation.tr("Timer")
}
