pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import inir
import inir.services
import inir.modules.common
import inir.modules.common.functions
import inir.modules.common.widgets
import inir.modules.iris.frame
import inir.modules.iris.style
import inir.modules.iris.components
import inir.modules.iris.bar.island

Scope {
    id: root
    property string kind: "volume"
    property string keyboardText: ""
    property string keyboardIcon: ""
    property bool keyboardActive: false
    property string mediaAction: ""
    property string warningText: ""
    property bool open: false
    property bool presentationVisible: false
    property bool presentationShown: false
    readonly property var screen: outputHold.output
    IrisOutputHold {
        id: outputHold
        wanted: GlobalStates.focusedScreen
        live: root.presentationVisible
    }
    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(root.screen)
    readonly property bool fullscreen: CompositorService.nativeOverview
        && GameMode.hasFullscreenOnOutput(root.screen?.name ?? "") && !WorkspaceService.inOverview
    readonly property real surfaceBottomMargin: 18 * IrisStyle.density
        + (root.fullscreen ? 0 : IrisFrame.clear("bottom"))

    readonly property bool level: root.kind === "volume" || root.kind === "brightness" || root.kind === "mic"
    readonly property var rows: ({ volume: levelRow, brightness: levelRow, mic: levelRow,
        keyboard: keyboardRow, media: mediaRow, warning: warningRow })

    function show(nextKind: string, holdMs: int): void {
        root.kind = nextKind
        root.open = true
        closePresentation.stop()
        root.presentationVisible = true
        Qt.callLater(() => root.presentationShown = true)
        hideTimer.interval = holdMs
        hideTimer.restart()
    }

    function hide(): void {
        root.open = false
        root.presentationShown = false
        closePresentation.restart()
        GlobalStates.osdVolumeOpen = false
        GlobalStates.osdBrightnessOpen = false
        GlobalStates.osdMicOpen = false
        GlobalStates.osdMediaOpen = false
        GlobalStates.osdKeyboardLayoutOpen = false
    }

    readonly property real value: root.kind === "brightness"
        ? (root.brightnessMonitor?.brightness ?? 0)
        : root.kind === "mic"
            ? Math.max(0, Math.min(1, Audio.micVolume ?? 0))
            : Math.max(0, Math.min(1, Audio.value ?? 0))
    readonly property bool muted: root.kind === "mic" ? Audio.micMuted
        : root.kind === "volume" ? (Audio.sink?.audio?.muted ?? false) : false
    readonly property string icon: root.kind === "brightness" ? "light_mode"
        : root.kind === "mic" ? (Audio.micMuted ? "mic_off" : "mic")
        : root.muted ? "volume_off"
        : root.value < 0.34 ? "volume_mute"
        : root.value < 0.67 ? "volume_down" : "volume_up"

    readonly property var player: MprisController.activePlayer
    readonly property bool ytMusic: root.player !== null && root.player !== undefined
        && MprisController._isYtMusicMpv(root.player)
    readonly property string mediaTitle: StringUtils.cleanMusicTitle(
        root.ytMusic ? YtMusic.currentTitle : String(root.player?.trackTitle ?? ""))
    readonly property string mediaArtist: root.ytMusic ? YtMusic.currentArtist
        : String(root.player?.trackArtist ?? "")
    readonly property string mediaIcon: root.mediaAction === "next" ? "skip_next"
        : root.mediaAction === "previous" ? "skip_previous"
        : root.mediaAction === "pause" ? "pause" : "play_arrow"

    component OsdRow: RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 13 * IrisStyle.density
        anchors.rightMargin: 14 * IrisStyle.density
        spacing: 11 * IrisStyle.density
        opacity: visible ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(90); easing.type: IrisStyle.feedbackEasing } }
    }

    Timer { id: hideTimer; interval: 1500; onTriggered: root.hide() }
    Timer {
        id: closePresentation
        interval: IrisStyle.duration(90)
        onTriggered: root.presentationVisible = false
    }
    Timer { id: warm; interval: 4000; running: true; property bool ready: false; onTriggered: warm.ready = true }

    // A request raised while the Island owned this output is still set when the
    // fallback takes over, and would never fire a change again.
    Component.onCompleted: {
        if (GlobalStates.osdVolumeOpen) root.show("volume", 1500)
        else if (GlobalStates.osdBrightnessOpen) root.show("brightness", 1500)
        else if (GlobalStates.osdMicOpen) root.show("mic", 1500)
        else if (GlobalStates.osdMediaOpen) root.show("media", 2600)
        else if (GlobalStates.osdKeyboardLayoutOpen) {
            root.keyboardIcon = "language"
            root.keyboardActive = true
            root.keyboardText = KeyboardIndicators.currentLayoutCodeInline || KeyboardIndicators.currentLayoutName
            root.show("keyboard", 1600)
        }
    }

    Connections {
        target: Brightness
        function onBrightnessChanged(): void { root.show("brightness", 1500) }
    }
    Connections {
        target: Audio.sink?.audio ?? null
        function onVolumeChanged(): void { root.show("volume", 1500) }
        function onMutedChanged(): void { root.show("volume", 1500) }
    }
    Connections {
        target: Audio
        function onMicVolumeChanged(): void { root.show("mic", 1500) }
        function onMicMutedChanged(): void { root.show("mic", 1500) }
        function onSinkProtectionTriggered(reason: string): void {
            root.warningText = reason
            root.show("warning", 2600)
        }
    }
    Connections {
        target: warm.ready ? KeyboardIndicators : null
        function onPopupSequenceChanged(): void {
            if (!KeyboardIndicators.ready) return
            root.keyboardIcon = KeyboardIndicators.popupMaterialIcon
            root.keyboardActive = KeyboardIndicators.popupActive
            root.keyboardText = KeyboardIndicators.popupKind === "layout"
                ? (KeyboardIndicators.currentLayoutCodeInline || KeyboardIndicators.popupText)
                : KeyboardIndicators.popupText
            root.show("keyboard", 1600)
        }
    }
    Connections {
        target: MprisController
        function onTrackChanged(reverse: bool): void {
            if (!warm.ready || root.mediaTitle.length === 0) return
            root.mediaAction = ""
            root.show("media", 2600)
        }
    }
    Connections {
        target: GlobalStates
        function onOsdVolumeOpenChanged(): void { if (GlobalStates.osdVolumeOpen) root.show("volume", 1500) }
        function onOsdBrightnessOpenChanged(): void { if (GlobalStates.osdBrightnessOpen) root.show("brightness", 1500) }
        function onOsdMicOpenChanged(): void { if (GlobalStates.osdMicOpen) root.show("mic", 1500) }
        function onOsdKeyboardLayoutOpenChanged(): void {
            if (!GlobalStates.osdKeyboardLayoutOpen) return
            root.keyboardIcon = "language"
            root.keyboardActive = true
            root.keyboardText = KeyboardIndicators.currentLayoutCodeInline || KeyboardIndicators.currentLayoutName
            root.show("keyboard", 1600)
        }
        function onOsdMediaActionTriggered(action: string): void {
            root.mediaAction = action
            root.show("media", 2600)
        }
    }

    PanelWindow {
        visible: root.presentationVisible
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "quickshell:iris-osd"
        anchors { bottom: true; left: true; right: true }
        margins {
            left: root.fullscreen ? 0 : IrisFrame.clear("left")
            right: root.fullscreen ? 0 : IrisFrame.clear("right")
            bottom: 0
        }
        implicitHeight: root.surfaceBottomMargin + 96 * IrisStyle.density
        mask: Region {}

        IrisSurface {
            id: osdSurface
            readonly property real d: IrisStyle.density
            readonly property Item activeRow: root.rows[root.kind] ?? levelRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.surfaceBottomMargin
            readonly property real restWidth: Math.max(260, Math.min(520,
                Number(Config.options?.iris?.osd?.width ?? 320))) * osdSurface.d
            width: Math.round(Math.min(parent.width - 24, root.level ? osdSurface.restWidth
                : Math.max(150 * osdSurface.d, Math.min(osdSurface.restWidth * 1.2,
                    osdSurface.activeRow.implicitWidth + 26 * osdSurface.d))))
            height: Math.round((root.kind === "media" ? 64 : 52) * osdSurface.d)
            raised: true
            radius: IrisStyle.pieceRadius(height)
            opacity: root.presentationShown ? 1 : 0
            Behavior on width { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
            Behavior on height { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
            transform: Translate {
                y: root.presentationShown ? 0 : 5 * IrisStyle.density
                Behavior on y { NumberAnimation { duration: IrisStyle.duration(90); easing.type: IrisStyle.feedbackEasing } }
            }
            Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(80); easing.type: IrisStyle.feedbackEasing } }

            OsdRow {
                id: levelRow
                visible: root.level
                Glyph {
                    text: root.icon
                    iconSize: 20 * osdSurface.d
                    color: root.muted ? IrisStyle.subtext : IrisStyle.text
                    Layout.preferredWidth: 22 * osdSurface.d
                }
                IrisScrubber {
                    Layout.fillWidth: true
                    seekable: false
                    value: root.muted ? 0 : Math.min(1, root.value)
                    Behavior on value { NumberAnimation { duration: IrisStyle.duration(110); easing.type: IrisStyle.feedbackEasing } }
                }
                Item {
                    Layout.preferredWidth: 40 * osdSurface.d
                    Layout.fillHeight: true
                    Metric {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        value: Math.round(root.value * 100)
                        unit: "%"
                        pixelSize: 15 * IrisStyle.typeScale
                        weight: Font.Bold
                        color: root.muted ? IrisStyle.subtext : IrisStyle.text
                    }
                }
            }

            OsdRow {
                id: keyboardRow
                visible: root.kind === "keyboard"
                Glyph {
                    text: root.keyboardIcon
                    iconSize: 20 * osdSurface.d
                    color: root.keyboardActive ? IrisStyle.accent : IrisStyle.subtext
                    Layout.preferredWidth: 22 * osdSurface.d
                }
                IrisText {
                    Layout.fillWidth: true
                    text: root.keyboardText
                    elide: Text.ElideRight
                    font.pixelSize: 14 * IrisStyle.typeScale
                    font.weight: Font.DemiBold
                    color: root.keyboardActive ? IrisStyle.text : IrisStyle.subtext
                }
            }

            OsdRow {
                id: mediaRow
                visible: root.kind === "media"
                IrisArtwork {
                    Layout.preferredWidth: 40 * osdSurface.d
                    Layout.preferredHeight: 40 * osdSurface.d
                    circular: false
                    radius: IrisStyle.iconRadius(40 * osdSurface.d)
                    source: MediaArtwork.displaySource
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    IrisText {
                        Layout.fillWidth: true
                        text: root.mediaTitle.length > 0 ? root.mediaTitle : Translation.tr("Now playing")
                        elide: Text.ElideRight
                        font.pixelSize: 13.5 * IrisStyle.typeScale
                        font.weight: Font.DemiBold
                    }
                    IrisText {
                        Layout.fillWidth: true
                        visible: root.mediaArtist.length > 0
                        text: root.mediaArtist
                        elide: Text.ElideRight
                        color: IrisStyle.muted
                        font.pixelSize: 11.5 * IrisStyle.typeScale
                    }
                }
                Glyph {
                    visible: root.mediaAction.length > 0
                    text: root.mediaIcon
                    iconSize: 20 * osdSurface.d
                    color: IrisStyle.accent
                }
            }

            OsdRow {
                id: warningRow
                visible: root.kind === "warning"
                Glyph {
                    text: "volume_off"
                    iconSize: 20 * osdSurface.d
                    color: IrisStyle.danger
                    Layout.preferredWidth: 22 * osdSurface.d
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    IrisText {
                        Layout.fillWidth: true
                        text: Translation.tr("Volume held back")
                        elide: Text.ElideRight
                        font.pixelSize: 13.5 * IrisStyle.typeScale
                        font.weight: Font.DemiBold
                    }
                    IrisText {
                        Layout.fillWidth: true
                        visible: root.warningText.length > 0
                        text: root.warningText
                        elide: Text.ElideRight
                        color: IrisStyle.muted
                        font.pixelSize: 11.5 * IrisStyle.typeScale
                    }
                }
            }
        }
    }
}
