import QtQuick
import QtQuick.Layouts
import Ryoku.Ui.Singletons

Item {
    id: card

    required property PickerState state
    property var output: ({})

    readonly property string name: (output && output.name) ? String(output.name) : ""
    readonly property var current: (output && output.current) ? output.current : ({})
    readonly property string curType: (current && current.type) ? String(current.type) : ""
    readonly property string curKey: (current && current.key) ? String(current.key) : ""
    readonly property int w: (output && output.width) ? Number(output.width) : 0
    readonly property int h: (output && output.height) ? Number(output.height) : 0
    // A detached output reports no size and drops to the placement and lock subset.
    readonly property bool connected: card.w > 0 && card.h > 0
    readonly property bool hasAudio: card.curType === "video" || card.curType === "we"

    implicitHeight: col.implicitHeight

    // Optimistic mirror so a drag reads back at once and only the release reaches the daemon.
    property string _fill: ""
    property bool _locked: false
    property bool _themeSource: false
    property int _volume: 100
    property bool _muted: false
    property bool _manualPaused: false
    property string _thumbPath: ""

    function _cb(result, error) {
        if (error && card.state)
            card.state.toast(error.message || I18n.tr("That change could not be applied."), "error")
    }

    // Outputs showing the same item share one audio bus, so mute and volume move together.
    function _groupNames() {
        var outs = Library.outputs
        if (card.curKey.length === 0 || !outs)
            return card.name.length > 0 ? [card.name] : []
        var g = []
        for (var i = 0; i < outs.length; ++i) {
            var c = outs[i] && outs[i].current ? outs[i].current : null
            if (c && String(c.type) === card.curType && String(c.key) === card.curKey)
                g.push(outs[i].name)
        }
        return g.length > 0 ? g : [card.name]
    }

    function _syncFill() {
        var m = Settings.value("display.fillModes." + card.name)
        if (m === undefined || m === null || m === "")
            m = Settings.value("display.fillMode")
        card._fill = (m === undefined || m === null) ? "" : String(m)
    }
    function _syncLock() { card._locked = card.name.length > 0 && !!Settings.value("display.outputLocks." + card.name) }
    function _syncTheme() { card._themeSource = card.name.length > 0 && String(Settings.value("display.themeOutput") || "") === card.name }
    function _syncAudio() {
        var v = card.current ? card.current.volume : undefined
        card._volume = (v === undefined || v === null) ? 100 : Number(v)
        card._muted = !!(card.current && card.current.mute)
    }
    function _syncThumb() {
        if (card.curKey.length === 0) { card._thumbPath = ""; return }
        var coll = (card.state && card.state.view) ? card.state.view.collection : "wallpapers"
        var e = Library.entry(coll, card.curKey)
        if (!e || !e.thumb) e = Library.entry("wallpapers", card.curKey)
        if (!e || !e.thumb) e = Library.entry("workshop", card.curKey)
        card._thumbPath = (e && e.thumb) ? String(e.thumb) : ""
    }

    onOutputChanged: { _syncFill(); _syncLock(); _syncTheme(); _syncAudio(); _syncThumb() }
    Component.onCompleted: { _syncFill(); _syncLock(); _syncTheme(); _syncAudio(); _syncThumb() }

    Connections {
        target: Settings
        function onChanged(key, value) {
            if (key === "display.fillModes." + card.name || key === "display.fillMode") card._syncFill()
            else if (key === "display.outputLocks." + card.name) card._syncLock()
            else if (key === "display.themeOutput") card._syncTheme()
        }
    }
    Connections {
        target: Library
        function onChanged(collection) { card._syncThumb() }
        function onCurrentChanged() { card._syncThumb() }
    }

    Column {
        id: col
        width: card.width
        spacing: 14 * Theme.scale

        RowLayout {
            width: parent.width
            spacing: 12 * Theme.scale

            Rectangle {
                Layout.preferredWidth: 86 * Theme.scale
                Layout.preferredHeight: 48 * Theme.scale
                color: Theme.withAlpha(Theme.surfaceContainer, 0.32)
                border.width: 1
                border.color: Theme.withAlpha(Theme.outline, card._thumbPath.length > 0 ? 0.52 : 0.34)
                clip: true

                Image {
                    id: thumbImg
                    anchors.fill: parent
                    source: card._thumbPath.length > 0 ? "file://" + card._thumbPath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: card._thumbPath.length === 0 || thumbImg.status !== Image.Ready
                    text: "\u25c7"
                    font.family: Theme.ui
                    font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fontBase
                    color: Theme.withAlpha(Theme.surfaceText, 0.36)
                    renderType: Text.NativeRendering
                }
            }

            Column {
                Layout.fillWidth: true
                spacing: 1 * Theme.scale

                Text {
                    width: parent.width
                    text: card.name
                    font.family: Theme.ui
                    font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fontBody2
                    color: Theme.surfaceText
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
                Text {
                    width: parent.width
                    text: card.connected
                        ? (card.w + " \u00d7 " + card.h + (card.curType.length > 0 ? " \u00b7 " + card.curType : ""))
                        : (I18n.tr("Offline") + " \u00b7 " + card.w + " \u00d7 " + card.h)
                    font.family: Theme.ui
                    font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fontFine
                    color: Theme.withAlpha(Theme.surfaceText, 0.52)
                    elide: Text.ElideRight
                    renderType: Text.NativeRendering
                }
            }
        }

        Column {
            width: parent.width
            spacing: 6 * Theme.scale

            Text {
                text: I18n.tr("Placement")
                font.family: Theme.ui
                font.weight: Theme.uiWeight
                font.pixelSize: Theme.fontBody
                color: Theme.surfaceText
                renderType: Text.NativeRendering
            }
            Text {
                width: parent.width
                text: I18n.tr("Choose whether the wallpaper fills, fits, stretches, centres, tiles, or spans the display.")
                font.family: Theme.ui
                font.weight: Theme.uiWeight
                font.pixelSize: Theme.fontBase
                color: Theme.withAlpha(Theme.surfaceText, 0.5)
                lineHeight: 1.32
                wrapMode: Text.WordWrap
                renderType: Text.NativeRendering
            }
            DisplayPlacementControl {
                width: parent.width
                current: card._fill
                onPicked: (mode) => {
                    card._fill = mode
                    Settings.set("display.fillModes." + card.name, mode)
                    Daemon.call("wall.apply", {
                        type: card.curType.length > 0 ? card.curType : "static",
                        path: (card.current && card.current.path) ? card.current.path : "",
                        outputs: [card.name]
                    }, card._cb)
                }
            }
        }

        RowLayout {
            width: parent.width
            spacing: 12 * Theme.scale

            Column {
                Layout.fillWidth: true
                spacing: 2 * Theme.scale

                Text {
                    text: I18n.tr("Lock")
                    font.family: Theme.ui
                    font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fontBody
                    color: Theme.surfaceText
                    renderType: Text.NativeRendering
                }
                Text {
                    width: parent.width
                    text: I18n.tr("Only update this monitor's wallpaper through the multipicker.")
                    font.family: Theme.ui
                    font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fontBase
                    color: Theme.withAlpha(Theme.surfaceText, 0.5)
                    lineHeight: 1.32
                    wrapMode: Text.WordWrap
                    renderType: Text.NativeRendering
                }
            }
            FolioAction {
                Layout.alignment: Qt.AlignTop
                label: card._locked ? I18n.tr("Enabled") : I18n.tr("Disabled")
                active: card._locked
                onTriggered: {
                    card._locked = !card._locked
                    Settings.set("display.outputLocks." + card.name, card._locked)
                }
            }
        }

        Row {
            width: parent.width
            visible: card.connected
            spacing: 8 * Theme.scale

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 72 * Theme.scale
                text: I18n.tr("Colours")
                font.family: Theme.ui
                font.weight: Theme.uiWeight
                font.pixelSize: Theme.fontFine
                color: Theme.withAlpha(Theme.surfaceText, 0.46)
                renderType: Text.NativeRendering
            }
            FolioAction {
                anchors.verticalCenter: parent.verticalCenter
                label: card._themeSource ? I18n.tr("Colour source") : I18n.tr("Use for colours")
                active: card._themeSource
                onTriggered: {
                    Settings.set("display.themeOutput", card._themeSource ? "" : card.name)
                    card._themeSource = !card._themeSource
                }
            }
        }

        RowLayout {
            width: parent.width
            visible: card.connected && card.hasAudio
            spacing: 8 * Theme.scale

            Text {
                Layout.preferredWidth: 72 * Theme.scale
                Layout.alignment: Qt.AlignVCenter
                text: I18n.tr("Audio")
                font.family: Theme.ui
                font.weight: Theme.uiWeight
                font.pixelSize: Theme.fontFine
                color: Theme.withAlpha(Theme.surfaceText, 0.46)
                renderType: Text.NativeRendering
            }
            DisplayAudioControl {
                Layout.fillWidth: true
                muted: card._muted
                volume: card._volume
                playing: !card._manualPaused
                onMuteToggled: (m) => {
                    card._muted = m
                    Daemon.call("wall.set_audio", { mute: m, outputs: card._groupNames() }, card._cb)
                }
                onVolumeMoved: (v) => card._volume = v
                onVolumeReleased: (v) => {
                    card._volume = v
                    card._muted = (v === 0)
                    Daemon.call("wall.set_audio", { volume: v, mute: (v === 0), outputs: card._groupNames() }, card._cb)
                }
            }
        }

        Row {
            width: parent.width
            visible: card.connected && card.hasAudio
            spacing: 8 * Theme.scale

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: 72 * Theme.scale
                text: I18n.tr("Wallpaper")
                font.family: Theme.ui
                font.weight: Theme.uiWeight
                font.pixelSize: Theme.fontFine
                color: Theme.withAlpha(Theme.surfaceText, 0.46)
                renderType: Text.NativeRendering
            }
            DisplayPlaybackControl {
                anchors.verticalCenter: parent.verticalCenter
                manual: card._manualPaused
                paused: false
                onPauseToggled: (m) => {
                    card._manualPaused = m
                    Daemon.call("wall.pause", { outputs: [card.name], paused: m }, card._cb)
                }
            }
        }
    }
}
