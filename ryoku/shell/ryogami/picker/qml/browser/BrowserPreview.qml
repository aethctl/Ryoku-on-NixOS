import QtQuick
import QtMultimedia
import Ryoku.Ui.Singletons

Item {
    id: preview

    property var item: null
    property string provider: ""
    property string fullPath: ""
    property bool showApply: false
    property bool applying: false
    property int maxMinutes: 3
    property var sources: null
    property bool cancellable: false

    property string clipStart: "0:00"
    property string clipLen: "3:00"

    property bool shown: false
    property real anim: shown ? 1 : 0
    Behavior on anim { NumberAnimation { duration: Theme.fast; easing.type: Theme.revealEasing } }

    signal closeRequested()
    signal save()
    signal apply()
    signal cancel()
    signal copyId(string id)

    visible: anim > 0.001
    anchors.fill: parent

    readonly property bool _isSteam: provider === "steam"
    readonly property bool _isYoutube: provider === "youtube"
    readonly property real _duration: item && item.durationSecs ? Number(item.durationSecs) : 0
    readonly property bool _downloaded: !!item && item.downloaded === true
    readonly property bool _downloading: !!sources && sources.isDownloading(item)
    readonly property bool _hasClip: _isYoutube && _duration > 0
    // The thumbnail is a plain cache path until the full image arrives.
    readonly property string _artSource: Library.fileUrl(fullPath.length > 0 ? fullPath
        : (item && item.thumb ? String(item.thumb) : ""))
    readonly property string _clipUrl: {
        var u = item && item.fullUrl ? String(item.fullUrl) : ""
        var path = u.split(/[?#]/)[0].toLowerCase()
        return /\.(webm|mp4|mkv|mov)$/.test(path) ? u : ""
    }

    // The panel refreshes item as a download progresses; only a different item resets the clip.
    property string _clipFor: ""
    onItemChanged: {
        var id = preview.item ? String(preview.item.id) : ""
        if (id === preview._clipFor)
            return
        preview._clipFor = id
        if (preview._hasClip) {
            preview.clipStart = "0:00"
            var cap = Math.min(preview._duration, preview.maxMinutes * 60)
            preview.clipLen = preview._fmtClock(cap)
        }
    }

    function _fmtClock(secs) {
        secs = Math.max(0, Math.floor(secs))
        var h = Math.floor(secs / 3600)
        var m = Math.floor((secs % 3600) / 60)
        var s = secs % 60
        var ss = s < 10 ? "0" + s : "" + s
        if (h > 0) {
            var mm = m < 10 ? "0" + m : "" + m
            return h + ":" + mm + ":" + ss
        }
        return m + ":" + ss
    }
    function _parseClock(text) {
        var parts = String(text).split(":")
        var n = parts.length
        var val = 0
        for (var i = 0; i < n; ++i) {
            var p = parseInt(parts[i], 10)
            if (isNaN(p)) p = 0
            val = val * 60 + p
        }
        return val
    }
    readonly property int clipStartSecs: _parseClock(clipStart)
    readonly property int clipLenSecs: _parseClock(clipLen)

    function _fmtSize(v) {
        if (v === undefined || v === null || v === "") return ""
        if (typeof v === "string") return v
        var b = Number(v)
        if (isNaN(b) || b < 1024) return ""
        if (b >= 1024 * 1024) return (b / (1024 * 1024)).toFixed(1) + " MB"
        return Math.round(b / 1024) + " KB"
    }

    function _purityColour(p) {
        if (p === "sketchy") return Qt.rgba(1, 0.8, 0, 0.2)
        if (p === "nsfw") return Qt.rgba(1, 0.3, 0.3, 0.2)
        return Qt.rgba(0.3, 0.8, 0.3, 0.2)
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.97 * preview.anim)
        MouseArea { anchors.fill: parent; onClicked: preview.closeRequested() }
    }

    Image {
        anchors.fill: parent
        anchors.margins: 40 * Theme.scale
        visible: preview._artSource.length > 0
        source: preview._artSource
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: false
        opacity: preview.anim
    }
    // A result whose link is the clip plays it here; the thumbnail above covers the first frames.
    Loader {
        anchors.fill: parent
        anchors.margins: 40 * Theme.scale
        active: preview.shown && preview._clipUrl.length > 0
        sourceComponent: Video {
            source: preview._clipUrl
            fillMode: VideoOutput.PreserveAspectFit
            loops: MediaPlayer.Infinite
            muted: true
            opacity: preview.anim
            Component.onCompleted: play()
        }
    }
    BrowserSpinner {
        anchors.centerIn: parent
        visible: preview._artSource.length === 0
        size: 64
        color: Theme.primary
    }

    Row {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 20 * Theme.scale
        spacing: 8 * Theme.scale
        visible: preview.fullPath.length === 0 && preview._artSource.length > 0 && preview._clipUrl.length === 0
        BrowserSpinner { anchors.verticalCenter: parent.verticalCenter; size: 14; color: "white" }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: I18n.tr("Loading full preview\u2026")
            font.family: Theme.ui
            font.weight: Theme.uiWeight
            font.pixelSize: Theme.fontBody
            color: "white"
            renderType: Text.NativeRendering
        }
    }

    Rectangle {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 8 * Theme.scale
        width: 36 * Theme.scale
        height: 36 * Theme.scale
        color: Qt.rgba(1, 1, 1, 0.1)
        Text {
            anchors.centerIn: parent
            text: "\u{f0156}"
            font.family: Theme.icon
            font.pixelSize: Theme.fs(20)
            color: "white"
            renderType: Text.NativeRendering
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: preview.closeRequested() }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: barCol.implicitHeight + 24 * Theme.scale
        color: Qt.rgba(0, 0, 0, 0.6 * preview.anim)

        MouseArea { anchors.fill: parent }

        Column {
            id: barCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 24 * Theme.scale
            anchors.rightMargin: 24 * Theme.scale
            spacing: 8 * Theme.scale

            Row {
                width: parent.width
                spacing: 12 * Theme.scale
                Text {
                    id: title
                    width: parent.width - idBits.implicitWidth - 12 * Theme.scale
                    anchors.verticalCenter: parent.verticalCenter
                    text: preview.item ? (preview.item.title && preview.item.title.length > 0
                        ? preview.item.title : String(preview.item.id)) : ""
                    elide: Text.ElideRight
                    font.family: Theme.ui
                    font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fs(18)
                    color: "white"
                    renderType: Text.NativeRendering
                }
                Row {
                    id: idBits
                    anchors.verticalCenter: parent.verticalCenter
                    visible: preview._isSteam && preview.item
                    spacing: 10 * Theme.scale
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: preview.item ? I18n.tr("Workshop ID: %1").arg(String(preview.item.id)) : ""
                        font.family: Theme.ui
                        font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontLabel
                        color: Qt.rgba(1, 1, 1, 0.7)
                        renderType: Text.NativeRendering
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: copyText.implicitWidth + 20 * Theme.scale
                        height: 24 * Theme.scale
                        color: Qt.rgba(1, 1, 1, 0.12)
                        Text {
                            id: copyText
                            anchors.centerIn: parent
                            text: I18n.tr("Copy ID")
                            font.family: Theme.ui
                            font.weight: Theme.uiWeight
                            font.pixelSize: Theme.fontBase
                            color: "white"
                            renderType: Text.NativeRendering
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (preview.item) preview.copyId(String(preview.item.id))
                        }
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: 10 * Theme.scale

                Text {
                    visible: !!preview.item && !!preview.item.resolution
                    text: preview.item ? String(preview.item.resolution) : ""
                    font.family: Theme.ui; font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fontLabel; color: "white"
                    renderType: Text.NativeRendering
                }
                Text {
                    readonly property string sz: preview.item ? preview._fmtSize(preview.item.fileSize) : ""
                    visible: sz.length > 0
                    text: sz
                    font.family: Theme.ui; font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fontBody; color: Qt.rgba(1, 1, 1, 0.65)
                    renderType: Text.NativeRendering
                }
                Rectangle {
                    visible: !!preview.item && !!preview.item.category
                    width: catText.implicitWidth + 10 * Theme.scale
                    height: catText.implicitHeight + 2 * Theme.scale
                    color: Qt.rgba(1, 1, 1, 0.1)
                    Text {
                        id: catText
                        anchors.centerIn: parent
                        text: preview.item ? String(preview.item.category) : ""
                        font.family: Theme.ui; font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontBase; color: Qt.rgba(1, 1, 1, 0.85)
                        renderType: Text.NativeRendering
                    }
                }
                Rectangle {
                    visible: !!preview.item && !!preview.item.purity
                    width: purText.implicitWidth + 10 * Theme.scale
                    height: purText.implicitHeight + 2 * Theme.scale
                    color: preview.item ? preview._purityColour(preview.item.purity) : "transparent"
                    Text {
                        id: purText
                        anchors.centerIn: parent
                        text: preview.item ? String(preview.item.purity) : ""
                        font.family: Theme.ui; font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontBase; color: Qt.rgba(1, 1, 1, 0.85)
                        renderType: Text.NativeRendering
                    }
                }
                Text {
                    visible: !!preview.item && !!preview.item.attribution
                    text: preview.item ? String(preview.item.attribution) : ""
                    font.family: Theme.ui; font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fontBody; color: Qt.rgba(1, 1, 1, 0.7)
                    renderType: Text.NativeRendering
                }

                Row {
                    visible: preview._hasClip
                    spacing: 6 * Theme.scale
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Clip")
                        font.family: Theme.ui; font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontBase; color: "white"
                        renderType: Text.NativeRendering
                    }
                    BrowserClockField {
                        anchors.verticalCenter: parent.verticalCenter
                        placeholder: "0:00"
                        text: preview.clipStart
                        onEdited: preview.clipStart = value
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "+"
                        font.family: Theme.ui; font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontBase; color: "white"
                        renderType: Text.NativeRendering
                    }
                    BrowserClockField {
                        anchors.verticalCenter: parent.verticalCenter
                        placeholder: "3:00"
                        text: preview.clipLen
                        onEdited: preview.clipLen = value
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("of %1").arg(preview._fmtClock(preview._duration))
                        font.family: Theme.ui; font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontBase; color: Qt.rgba(1, 1, 1, 0.7)
                        renderType: Text.NativeRendering
                    }
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 10 * Theme.scale

                Rectangle {
                    // Sized to the progress text too, so hovering to "Cancel" never shrinks it under the pointer.
                    width: Math.max(saveLbl.implicitWidth, progressMetrics.advanceWidth) + 24 * Theme.scale
                    TextMetrics {
                        id: progressMetrics
                        font: saveLbl.font
                        text: preview._downloading && preview.sources
                            ? preview.sources.progressLabel(I18n.tr("Saving"), preview.item) : ""
                    }
                    height: 30 * Theme.scale
                    color: Qt.rgba(1, 1, 1, 0.12)
                    Text {
                        id: saveLbl
                        anchors.centerIn: parent
                        text: preview._downloaded
                            ? I18n.tr("\u2713 Saved")
                            : preview._downloading
                                ? (preview.cancellable && saveArea.containsMouse
                                    ? I18n.tr("Cancel")
                                    : (preview.sources ? preview.sources.progressLabel(I18n.tr("Saving"), preview.item) : I18n.tr("Saving\u2026")))
                                : I18n.tr("Save")
                        font.family: Theme.ui; font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontBase; color: "white"
                        renderType: Text.NativeRendering
                    }
                    MouseArea {
                        id: saveArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: !preview._downloaded && (!preview._downloading || preview.cancellable)
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: preview._downloading ? preview.cancel() : preview.save()
                    }
                }
                Rectangle {
                    visible: preview.showApply
                    width: applyLbl.implicitWidth + 24 * Theme.scale
                    height: 30 * Theme.scale
                    color: Theme.primary
                    Text {
                        id: applyLbl
                        anchors.centerIn: parent
                        text: preview.applying ? I18n.tr("Applying") : I18n.tr("Apply")
                        font.family: Theme.ui; font.weight: Font.Bold
                        font.pixelSize: Theme.fontBase; color: Theme.primaryText
                        renderType: Text.NativeRendering
                    }
                    MouseArea {
                        anchors.fill: parent
                        enabled: !preview.applying
                        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                        onClicked: preview.apply()
                    }
                }
            }
        }
    }

    Keys.onEscapePressed: preview.closeRequested()
}
