pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import shell.services
import Ryoku.Ui
import Ryoku.Ui.Singletons
import ".."

Item {
    id: root

    required property real s
    required property bool open
    required property real reveal
    required property bool tabActive
    property int index: 0
    property bool compact: false
    readonly property bool wide: width >= 620 * s && !compact
    readonly property real gap: Tokens.s4 * s
    readonly property real pad: Tokens.s4 * s
    readonly property var delaySteps: [0, 1, 3, 5, 10]
    signal requestClose()

    implicitHeight: content.implicitHeight

    function shoot(mode): void {
        root.requestClose();
        Capture.shoot(mode);
    }
    function record(mode): void {
        root.requestClose();
        if (mode === "screen")
            Recorder.startAfter(Recorder.recordArgs(), Capture.delay);
        else
            Capture.recordTarget(mode, Recorder.recordArgs());
    }
    function openRecordingSettings(): void {
        root.requestClose();
        Spawn.run(["ryoku-shell", "hub", "open", "recording"]);
    }
    function cycleDelay(): void {
        const at = root.delaySteps.indexOf(Capture.delay);
        Capture.delay = root.delaySteps[(at + 1) % root.delaySteps.length];
    }

    component Zone: Rectangle {
        id: zone
        required property string title
        required property string description
        required property string glyph
        default property alias body: zoneBody.data
        implicitHeight: zoneContent.implicitHeight + root.pad * 2
        radius: Tokens.radius * root.s * 2
        color: Tokens.paperLift
        border.width: Tokens.border
        border.color: Tokens.lineSoft

        Column {
            id: zoneContent
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.pad }
            spacing: Tokens.s4 * root.s
            Column {
                width: parent.width
                spacing: Tokens.s2 * root.s
                Text {
                    text: zone.glyph
                    color: Tokens.inkDim
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 28 * root.s
                    Accessible.ignored: true
                }
                Text {
                    width: parent.width
                    text: zone.title
                    color: Tokens.ink
                    font.family: Tokens.display
                    font.pixelSize: 26 * root.s
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: zone.description
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall * root.s
                    wrapMode: Text.WordWrap
                }
            }
            Column {
                id: zoneBody
                width: parent.width
                spacing: Tokens.s3 * root.s
            }
        }
    }

    component ModeButton: QQC.AbstractButton {
        id: modeButton
        required property string glyph
        required property string hint
        required property var actionFn
        implicitHeight: Math.max(112 * root.s, modeCopy.implicitHeight + padding * 2)
        padding: Tokens.s3 * root.s
        hoverEnabled: true
        Accessible.name: text
        Accessible.description: hint
        onClicked: actionFn()
        background: Rectangle {
            radius: Tokens.radius * root.s * 1.5
            color: modeButton.down ? Tokens.bone : modeButton.hovered ? Tokens.tint10 : Tokens.tint5
            border.width: Tokens.border
            border.color: modeButton.visualFocus ? Tokens.bone : Tokens.lineSoft
        }
        contentItem: Column {
            id: modeCopy
            spacing: Tokens.s1 * root.s
            Text {
                text: modeButton.glyph
                color: modeButton.down ? Tokens.inkOnBone : Tokens.inkDim
                font.family: "Material Symbols Rounded"
                font.pixelSize: 23 * root.s
                Accessible.ignored: true
            }
            Text {
                width: parent.width
                text: modeButton.text
                color: modeButton.down ? Tokens.inkOnBone : Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: Tokens.fRow * root.s
                font.weight: Font.DemiBold
                wrapMode: Text.WordWrap
            }
            Text {
                width: parent.width
                text: modeButton.hint
                color: modeButton.down ? Tokens.inkOnBone : Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall * root.s
                wrapMode: Text.WordWrap
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    Column {
        id: content
        width: root.width
        spacing: root.gap

        Rectangle {
            visible: Recorder.anyActive || Recorder.countingDown
            width: parent.width
            implicitHeight: liveContent.implicitHeight + root.pad * 2
            radius: Tokens.radius * root.s * 2
            color: Tokens.bone
            Column {
                id: liveContent
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: root.pad }
                spacing: Tokens.s3 * root.s
                Text {
                    width: parent.width
                    text: Recorder.countingDown ? I18n.tr("Recording in %1 seconds").arg(Recorder.countdownSec)
                        : Recorder.paused ? I18n.tr("Recording paused") : I18n.tr("Recording in progress")
                    color: Tokens.inkOnBone
                    font.family: Tokens.ui
                    font.pixelSize: 22 * root.s
                    font.weight: Font.DemiBold
                    wrapMode: Text.WordWrap
                }
                Text {
                    text: Recorder.countingDown ? I18n.tr("Get your desktop ready") : Recorder.elapsedText
                    color: Tokens.inkOnBone
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fRow * root.s
                }
                Flow {
                    width: parent.width
                    spacing: Tokens.s2 * root.s
                    SidebarButton {
                        s: root.s
                        visible: !Recorder.countingDown
                        text: Recorder.paused ? I18n.tr("Resume") : I18n.tr("Pause")
                        onAct: Recorder.togglePause()
                    }
                    SidebarButton {
                        s: root.s
                        text: Recorder.countingDown ? I18n.tr("Cancel countdown") : I18n.tr("Stop recording")
                        onAct: Recorder.stop()
                    }
                }
            }
        }

        Flow {
            width: parent.width
            spacing: Tokens.s2 * root.s
            SidebarButton {
                s: root.s
                glyph: "timer"
                text: Capture.delay === 0 ? I18n.tr("No delay") : I18n.tr("%1-second delay").arg(Capture.delay)
                onAct: root.cycleDelay()
            }
            SidebarButton {
                s: root.s
                glyph: "folder_open"
                text: I18n.tr("Open screenshots")
                onAct: Qt.openUrlExternally("file://" + Capture.shotsDir)
            }
        }

        Grid {
            id: zones
            width: parent.width
            columns: root.wide ? 2 : 1
            columnSpacing: root.gap
            rowSpacing: root.gap
            readonly property real zoneWidth: (width - columnSpacing * (columns - 1)) / columns

            Zone {
                width: zones.zoneWidth
                title: I18n.tr("Screenshot")
                description: I18n.tr("Choose exactly what goes into the picture.")
                glyph: "photo_camera"

                Grid {
                    id: shots
                    width: parent.width
                    columns: 2
                    columnSpacing: Tokens.s2 * root.s
                    rowSpacing: Tokens.s2 * root.s
                    readonly property real modeWidth: (width - columnSpacing) / 2
                    ModeButton { width: shots.modeWidth; glyph: "desktop_windows"; text: I18n.tr("All displays"); hint: I18n.tr("The whole desktop"); actionFn: () => root.shoot("all") }
                    ModeButton { width: shots.modeWidth; glyph: "monitor"; text: I18n.tr("Display"); hint: I18n.tr("Pick a screen"); actionFn: () => root.shoot("monitor") }
                    ModeButton { width: shots.modeWidth; glyph: "window"; text: I18n.tr("Window"); hint: I18n.tr("Pick an application"); actionFn: () => root.shoot("window") }
                    ModeButton { width: shots.modeWidth; glyph: "screenshot_region"; text: I18n.tr("Region"); hint: I18n.tr("Draw a selection"); actionFn: () => root.shoot("region") }
                }
                Text {
                    text: I18n.tr("Save to")
                    color: Tokens.inkDim
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall * root.s
                }
                SidebarSegments {
                    s: root.s
                    width: parent.width
                    options: ["both", "clipboard", "file"]
                    labels: ({ both: I18n.tr("Both"), clipboard: I18n.tr("Clipboard"), file: I18n.tr("Folder") })
                    current: Capture.save
                    onChose: value => Capture.save = value
                }
                SidebarToggle {
                    s: root.s
                    width: parent.width
                    glyph: "auto_fix_high"
                    text: I18n.tr("Open in editor")
                    detail: I18n.tr("Annotate and beautify after capture")
                    on: Capture.beautify
                    onToggleRequested: Capture.beautify = !Capture.beautify
                }
                Text {
                    width: parent.width
                    text: Capture.save === "clipboard" && !Capture.beautify ? I18n.tr("Ready to paste from the clipboard") : Capture.shotsDir
                    textFormat: Text.PlainText
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall * root.s
                    wrapMode: Text.WrapAnywhere
                }
            }

            Zone {
                width: zones.zoneWidth
                title: I18n.tr("Screen recording")
                description: I18n.tr("Record a display, application or selected area.")
                glyph: "videocam"

                Grid {
                    id: recordings
                    visible: !Recorder.anyActive && !Recorder.countingDown
                    width: parent.width
                    columns: 2
                    columnSpacing: Tokens.s2 * root.s
                    rowSpacing: Tokens.s2 * root.s
                    readonly property real modeWidth: (width - columnSpacing) / 2
                    ModeButton { width: recordings.modeWidth; glyph: "monitor"; text: I18n.tr("Screen"); hint: I18n.tr("Active display"); actionFn: () => root.record("screen") }
                    ModeButton { width: recordings.modeWidth; glyph: "desktop_windows"; text: I18n.tr("Display"); hint: I18n.tr("Pick a screen"); actionFn: () => root.record("monitor") }
                    ModeButton { width: recordings.modeWidth; glyph: "window"; text: I18n.tr("Window"); hint: I18n.tr("Pick an application"); actionFn: () => root.record("window") }
                    ModeButton { width: recordings.modeWidth; glyph: "screenshot_region"; text: I18n.tr("Region"); hint: I18n.tr("Draw a selection"); actionFn: () => root.record("region") }
                }
                SidebarToggle {
                    s: root.s
                    width: parent.width
                    text: I18n.tr("Desktop audio")
                    glyph: "volume_up"
                    on: Recorder.optDesktopAudio
                    enabled: !Recorder.anyActive && !Recorder.countingDown
                    onToggleRequested: Recorder.optDesktopAudio = !Recorder.optDesktopAudio
                }
                SidebarToggle {
                    s: root.s
                    width: parent.width
                    text: I18n.tr("Microphone")
                    glyph: "mic"
                    on: Recorder.optMic
                    enabled: !Recorder.anyActive && !Recorder.countingDown
                    onToggleRequested: Recorder.optMic = !Recorder.optMic
                }
                Flow {
                    width: parent.width
                    spacing: Tokens.s2 * root.s
                    SidebarButton { s: root.s; compact: true; glyph: "keyboard"; text: I18n.tr("Key presses"); armed: !Recorder.anyActive; onAct: Keypresses.toggle() }
                    SidebarButton { s: root.s; compact: true; glyph: "videocam"; text: I18n.tr("Webcam"); armed: !Recorder.anyActive; onAct: Camera.toggle() }
                }
                Text {
                    width: parent.width
                    text: (Recorder.recCodec === "hevc" ? "HEVC" : Recorder.recCodec === "av1" ? "AV1" : "H.264")
                        + " / " + Recorder.recFps + " fps / " + Recorder.recContainer.toUpperCase()
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall * root.s
                    wrapMode: Text.WordWrap
                }
                SidebarButton {
                    s: root.s
                    width: Math.min(implicitWidth, parent.width)
                    glyph: "tune"
                    text: I18n.tr("Recording settings in Hub")
                    onAct: root.openRecordingSettings()
                }
            }
        }
    }
}
