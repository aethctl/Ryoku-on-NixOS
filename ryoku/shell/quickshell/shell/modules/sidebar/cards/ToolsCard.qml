pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import Ryoku.Ui
import Ryoku.Ui.Singletons
import shell.services
import ".."
import "." as Cards

Item {
    id: root

    required property real s
    required property bool open
    required property real reveal
    required property bool tabActive
    property int index: 0
    property string page: ""
    property bool compact: false
    property real viewportHeight: 0
    readonly property bool motionAllowed: !Tokens.reduceMotion && !Motion.reduce
    signal requestClose()
    signal pick(string mode)

    property string urlText: ""
    property bool setupOpen: false
    property bool pickerOpen: false
    property string pickerMode: "compress"

    implicitHeight: root.pickerOpen || root.setupOpen
        ? Math.max(240 * root.s, Math.min(560 * root.s, root.viewportHeight > 0 ? root.viewportHeight : card.implicitHeight))
        : card.implicitHeight

    readonly property bool engineNeedsSetup: Stash.dockerState === "setup" || Stash.dockerState === "missing"
    readonly property string engineSub: {
        if (Stash.setupState === "running") return I18n.tr("Setting up…");
        if (Stash.dockerState === "missing") return I18n.tr("Needs Docker. `ryoku update` installs it");
        if (Stash.dockerState === "setup") return I18n.tr("One-time setup — turn it on to begin");
        if (Stash.dockerState === "denied") return I18n.tr("Docker is unreachable and the ryoku-docker helper is missing");
        switch (Stash.cobaltState) {
        case "starting": return Stash.cobaltMsg === "pulling"
            ? I18n.tr("Downloading the cobalt image. First launch may take a minute.")
            : I18n.tr("Starting cobalt…");
        case "running": return I18n.tr("On — downloads use your local cobalt");
        case "error": return Stash.cobaltMsg.length > 0 ? Stash.cobaltMsg : I18n.tr("Failed to start");
        default: return I18n.tr("Off — using yt-dlp");
        }
    }

    function fileGlyph(name) {
        const ext = String(name).toLowerCase().split(".").pop();
        if (/^(png|jpe?g|webp|gif|bmp|tiff?|avif)$/.test(ext)) return "image";
        if (/^(mp4|mkv|webm|mov|avi|m4v)$/.test(ext)) return "movie";
        if (/^(mp3|flac|wav|ogg|opus|m4a|aac)$/.test(ext)) return "music_note";
        if (/^(zip|tar|gz|xz|zst|bz2|7z|rar|tgz)$/.test(ext)) return "folder_zip";
        if (/^(appimage|deb|rpm|flatpak|pkg)$/.test(ext)) return "deployed_code";
        return "draft";
    }

    function startDownload() {
        if (root.urlText.trim().length === 0)
            return;
        Stash.enqueueDownload(root.urlText, Stash.dlMode);
        root.urlText = "";
    }

    function openPicker(mode) {
        root.pickerMode = mode;
        root.pickerOpen = true;
        root.pick(mode);
    }

    property string lastPage: ""
    function applyPage() {
        if (!root.tabActive)
            return;
        if (root.page === root.lastPage)
            return;
        root.lastPage = root.page;
        if (root.page === "compress" || root.page === "install")
            root.openPicker(root.page);
    }

    onPageChanged: root.applyPage()
    onTabActiveChanged: if (root.tabActive) root.applyPage()
    Component.onCompleted: root.applyPage()

    component ToolSection: Column {
        id: section
        property string title
        default property alias content: body.data
        spacing: Tokens.s3 * root.s
        Text {
            width: parent.width
            text: section.title
            color: Tokens.ink
            font.family: Tokens.ui
            font.pixelSize: Tokens.fRow * root.s
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
        }
        Column {
            id: body
            width: parent.width
            spacing: Tokens.s2 * root.s
        }
    }

    SidebarCardShell {
        id: card
        visible: !root.pickerOpen && !root.setupOpen
        width: root.width
        s: root.s
        index: root.index
        open: root.open
        reveal: root.reveal
        tabActive: root.tabActive
        compact: root.compact
        title: I18n.tr("Stash tools")
        glyph: "download"
        eyebrow: I18n.tr("Downloads and packages")

        Column {
            width: parent.width
            spacing: (root.compact ? Tokens.s3 : Tokens.s5) * root.s
            Flow {
                width: parent.width
                spacing: Tokens.s2 * root.s
                SidebarButton {
                    s: root.s
                    motionEnabled: root.motionAllowed
                    compact: true
                    text: I18n.tr("Compress video…")
                    onAct: root.openPicker("compress")
                }
                SidebarButton {
                    s: root.s
                    motionEnabled: root.motionAllowed
                    compact: true
                    text: I18n.tr("Install app…")
                    onAct: root.openPicker("install")
                }
            }


            ToolSection {
                width: parent.width
                title: I18n.tr("Download")

                Column {
                    width: parent.width
                    spacing: Tokens.s3 * root.s

                    Item {
                        width: parent.width
                        height: Math.max(engineState.implicitHeight, engineSwitch.implicitHeight)

                        Text {
                            id: engineState
                            anchors.left: parent.left
                            anchors.right: engineSwitch.left
                            anchors.rightMargin: Tokens.s3 * root.s
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("Cobalt engine") + ": " + root.engineSub
                            color: Stash.cobaltState === "error" ? Tokens.alert : Tokens.inkDim
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fSmall * root.s
                            font.weight: Font.Medium
                            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        }

                        SidebarToggle {
                            s: root.s; compact: true
                            Accessible.name: I18n.tr("Cobalt engine")
                            id: engineSwitch
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            readonly property bool engineOn: Stash.cobaltState === "running" || Stash.cobaltState === "starting"
                            on: engineOn
                            enabled: Stash.setupState !== "running"
                            onToggleRequested: {
                                if (engineSwitch.engineOn) {
                                    Stash.setEngine(false);
                                    return;
                                }
                                if (root.engineNeedsSetup || Stash.dockerState === "unknown") {
                                    root.setupOpen = true;
                                    Stash.startSetup();
                                    return;
                                }
                                Stash.setEngine(true);
                            }
                        }
                    }

                    QQC.TextField {
                        id: urlField
                        width: parent.width
                        height: 48 * root.s
                        placeholderText: I18n.tr("Paste a link to download")
                        Accessible.name: I18n.tr("Download URL")
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fRow * root.s
                        color: Tokens.ink
                        placeholderTextColor: Tokens.inkMuted
                        selectionColor: Tokens.bone
                        selectedTextColor: Tokens.inkOnBone
                        selectByMouse: true
                        text: root.urlText
                        onTextEdited: root.urlText = text
                        onAccepted: root.startDownload()
                        background: Rectangle {
                            radius: Tokens.radius * root.s * 1.5
                            color: Tokens.tint5
                            border.width: Tokens.border
                            border.color: urlField.activeFocus ? Tokens.bone : Tokens.line
                        }
                    }

                    SidebarButton {
                        s: root.s
                        motionEnabled: root.motionAllowed
                        id: downloadButton
                        width: parent.width
                        text: I18n.tr("Download")
                        primary: true
                        armed: root.urlText.trim().length > 0
                        onAct: root.startDownload()
                    }

                    SidebarSegments {
                        s: root.s
                        width: parent.width
                        options: ["auto", "audio", "mute"]
                        labels: ({ auto: I18n.tr("Auto"), audio: I18n.tr("Audio"), mute: I18n.tr("Mute") })
                        current: Stash.dlMode
                        onChose: key => Stash.dlMode = key
                    }

                    Text {
                        visible: !root.compact
                        width: parent.width
                        text: Stash.cobaltState === "running"
                            ? I18n.tr("Works with %1 sites: %2")
                                .arg(Stash.supportedSites.length)
                                .arg(Stash.supportedSites.map(site => site === "twitter" ? "x" : site).join(", "))
                            : I18n.tr("Works with 1000+ sites, including YouTube, Twitter/X, Reddit, TikTok, and more.")
                        wrapMode: Text.WrapAtWordBoundaryOrAnywhere
                        color: Tokens.inkMuted
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall * root.s
                        lineHeight: 1.3
                    }
                }
            }

            ToolSection {
                width: parent.width
                visible: Stash.queueModel.count > 0
                title: I18n.tr("Queue")

                Column {
                    width: parent.width
                    spacing: 0

                    Repeater {
                        model: Stash.queueModel
                        delegate: Item {
                            id: queueRow
                            required property var model
                            required property int index
                            width: parent.width
                            implicitHeight: queueBody.implicitHeight + Tokens.s2 * root.s * 2

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: Tokens.border
                                visible: queueRow.index > 0
                                color: Tokens.lineSoft
                            }

                            Column {
                                id: queueBody
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.topMargin: Tokens.s2 * root.s
                                spacing: Tokens.s2 * root.s

                                Item {
                                    width: parent.width
                                    height: Math.max(queueName.implicitHeight, queueActions.implicitHeight)

                                    Text {
                                        id: queueName
                                        anchors.left: parent.left
                                        anchors.right: queueActions.left
                                        anchors.rightMargin: Tokens.s2 * root.s
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: queueRow.model.name && queueRow.model.name.length > 0 ? queueRow.model.name : queueRow.model.arg
                                        elide: Text.ElideMiddle
                                        color: Tokens.ink
                                        font.family: Tokens.ui
                                        font.pixelSize: Tokens.fSmall * root.s
                                        font.weight: Font.Medium
                                    }

                                    Row {
                                        id: queueActions
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        spacing: Tokens.s1 * root.s

                                        IconBtn {
                                            visible: queueRow.model.state === "error"
                                            glyph: "↻"
                                            onAct: Stash.retryJob(queueRow.index)
                                        }
                                        IconBtn {
                                            visible: queueRow.model.state === "queued"
                                                || queueRow.model.state === "done"
                                                || queueRow.model.state === "error"
                                            glyph: "×"
                                            onAct: Stash.dismissJob(queueRow.index)
                                        }
                                    }
                                }

                                Text {
                                    width: parent.width
                                    text: queueRow.model.state === "running" ? queueRow.model.pct + "%"
                                        : queueRow.model.state === "error" ? (queueRow.model.msg && queueRow.model.msg.length > 0 ? queueRow.model.msg : I18n.tr("failed"))
                                        : queueRow.model.state === "done" ? I18n.tr("done")
                                        : queueRow.model.state === "queued" ? I18n.tr("queued")
                                        : queueRow.model.state
                                    color: queueRow.model.state === "error" ? Tokens.alert : Tokens.inkMuted
                                    font.family: Tokens.ui
                                    font.pixelSize: Tokens.fSmall * root.s
                                    wrapMode: queueRow.model.state === "error"
                                        ? Text.WrapAtWordBoundaryOrAnywhere : Text.NoWrap
                                    elide: Text.ElideRight
                                }

                                Rectangle {
                                    visible: queueRow.model.state === "running" || queueRow.model.state === "queued"
                                    width: parent.width
                                    height: 3 * root.s
                                    radius: height / 2
                                    color: Tokens.tint10
                                    Rectangle {
                                        width: parent.width * Math.max(0, Math.min(1, (queueRow.model.pct || 0) / 100))
                                        height: parent.height
                                        radius: parent.radius
                                        color: Tokens.sun
                                        Behavior on width {
                                            enabled: root.motionAllowed
                                            NumberAnimation {
                                                duration: Tokens.move
                                                easing.type: Tokens.ease
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ToolSection {
                width: parent.width
                visible: !root.compact
                title: I18n.tr("Recently downloaded")

                Column {
                    width: parent.width
                    spacing: 0

                    Text {
                        width: parent.width
                        visible: Stash.count === 0
                        text: I18n.tr("Nothing downloaded yet. Links you grab land here.")
                        color: Tokens.inkMuted
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall * root.s
                        wrapMode: Text.WordWrap
                    }

                    Column {
                        width: parent.width
                        spacing: 0

                        Repeater {
                            model: Stash.recentFiles
                            delegate: Item {
                                id: fileRow
                                required property var modelData
                                required property int index
                                width: parent.width
                                height: 48 * root.s

                                Rectangle {
                                    anchors.fill: parent
                                    color: fileHover.hovered ? Tokens.tint5 : "transparent"
                                    Behavior on color {
                                        enabled: root.motionAllowed
                                        ColorAnimation { duration: Tokens.snap }
                                    }
                                }

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    height: Tokens.border
                                    visible: fileRow.index > 0
                                    color: Tokens.lineSoft
                                }

                                Text {
                                    id: fileIcon
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 22 * root.s
                                    horizontalAlignment: Text.AlignHCenter
                                    font.family: "Material Symbols Rounded"
                                    text: root.fileGlyph(fileRow.modelData.name)
                                    color: Tokens.sun
                                    font.pixelSize: 18 * root.s
                                }

                                Text {
                                    anchors.left: fileIcon.right
                                    anchors.right: removeFile.left
                                    anchors.leftMargin: Tokens.s2 * root.s
                                    anchors.rightMargin: Tokens.s2 * root.s
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: fileRow.modelData.name
                                    elide: Text.ElideMiddle
                                    color: Tokens.ink
                                    font.family: Tokens.ui
                                    font.pixelSize: Tokens.fSmall * root.s
                                    font.weight: Font.Medium
                                }

                                IconBtn {
                                    id: removeFile
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    glyph: "×"
                                    onAct: Stash.removeFile(fileRow.modelData.path)
                                }

                                HoverHandler {
                                    id: fileHover
                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler { onTapped: Stash.openFile(fileRow.modelData.path) }
                            }
                        }
                    }
                }
            }

        }
    }

    Cards.FilePickerOverlay {
        anchors.fill: parent
        s: root.s
        open: root.pickerOpen
        mode: root.pickerMode
        onCancelled: root.pickerOpen = false
        onConfirmed: paths => {
            if (root.pickerMode === "install")
                Stash.install(paths);
            else
                Stash.compress(paths);
            root.pickerOpen = false;
        }
    }

    Cards.CobaltSetupOverlay {
        anchors.fill: parent
        s: root.s
        open: root.setupOpen
        onClosed: root.setupOpen = false
    }
}
