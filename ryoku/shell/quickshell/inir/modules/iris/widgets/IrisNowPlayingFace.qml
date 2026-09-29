pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import inir.services
import inir.modules.common
import inir.modules.common.functions
import inir.modules.common.widgets
import inir.modules.mediaControls.components
import inir.modules.iris.style
import inir.modules.iris.components

IrisWidgetFace {
    id: root

    readonly property var player: MprisController.activePlayer
    readonly property bool hasPlayer: root.player !== null && root.player !== undefined
    readonly property bool playing: root.hasPlayer && media.effectiveIsPlaying
    readonly property string art: root.hasPlayer ? media.displayedArtFilePath : ""
    readonly property color artLight: IrisStyle.vividHighlight(media.colorQuantizer?.colors?.[0] ?? root.accent, root.accent)
    readonly property real progress: media.effectiveLength > 0 ? Math.min(1, media.effectivePosition / media.effectiveLength) : 0
    readonly property bool lyricsWanted: root.large && root.live && root.hasPlayer
        && Boolean(root.widget.irisOption("lyrics", true))
    readonly property bool lyricsReady: root.lyricsWanted && LyricsService.status === "ok" && LyricsService.lyricsLines.length > 0
    readonly property string source: {
        const identity = String(root.player?.identity || String(root.player?.desktopEntry ?? "").split(".").pop() || "")
        return identity.length > 0 ? identity.charAt(0).toUpperCase() + identity.slice(1) : Translation.tr("Music")
    }

    light: root.small || !root.hasPlayer || root.art.length === 0 ? "transparent" : root.artLight
    padding: root.small && root.art.length > 0 ? 0 : root.dp(16)

    onLyricsWantedChanged: root.lyricsWanted ? LyricsService.subscribe() : LyricsService.unsubscribe()
    Component.onDestruction: if (root.lyricsWanted) LyricsService.unsubscribe()

    PlayerBase {
        id: media
        player: root.player
        positionUpdatesActive: root.live && root.playing && !root.small
    }

    component Transport: RowLayout {
        id: transport
        property real disc: root.dp(34)
        spacing: root.dp(6)
        FaceAction {
            face: root
            implicitWidth: transport.disc
            glyph: "skip_previous"
            name: Translation.tr("Previous")
            enabled: media.effectiveCanGoPrevious
            opacity: enabled ? 1 : 0.4
            onActivated: media.previous()
        }
        FaceAction {
            face: root
            implicitWidth: Math.round(transport.disc * 1.2)
            glyph: root.playing ? "pause" : "play_arrow"
            name: root.playing ? Translation.tr("Pause") : Translation.tr("Play")
            tint: root.playing ? IrisStyle.onTintFor(root.artLight) : root.ink
            color: root.playing ? root.artLight : IrisStyle.fill
            onActivated: media.togglePlaying()
        }
        FaceAction {
            face: root
            implicitWidth: transport.disc
            glyph: "skip_next"
            name: Translation.tr("Next")
            enabled: media.effectiveCanGoNext
            opacity: enabled ? 1 : 0.4
            onActivated: media.next()
        }
    }

    component Progress: Rectangle {
        implicitHeight: root.dp(4)
        radius: height / 2
        color: IrisStyle.fill
        Rectangle {
            width: parent.width * root.progress
            height: parent.height
            radius: height / 2
            color: root.ink
        }
    }

    ColumnLayout {
        anchors.fill: parent
        visible: !root.hasPlayer
        spacing: root.dp(6)

        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: "music_note"
            text: Translation.tr("Now Playing")
            tint: IrisStyle.identity.pink
        }
        Item { Layout.fillHeight: true }
        FaceText {
            face: root
            Layout.fillWidth: true
            text: Translation.tr("Nothing playing")
            size: root.small ? 14 : 15
            weight: Font.DemiBold
        }
        FaceText {
            face: root
            Layout.fillWidth: true
            text: Translation.tr("Your music appears here")
            color: root.inkSecondary
            size: 12
        }
    }

    Item {
        anchors.fill: parent
        visible: root.hasPlayer && root.small

        ClippingRectangle {
            anchors.fill: parent
            visible: root.art.length > 0
            radius: root.radius
            color: "transparent"
            Image {
                anchors.fill: parent
                source: root.art
                fillMode: Image.PreserveAspectCrop
                sourceSize.width: Math.round(root.width * 2)
                asynchronous: true
            }
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: parent.height * 0.62
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: IrisStyle.veilStrong }
                }
            }
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: root.art.length > 0 ? root.dp(14) : 0
            spacing: root.dp(1)
            IrisArtwork {
                visible: root.art.length === 0
                circular: false
                radius: root.innerRadius
                Layout.preferredWidth: root.dp(56)
                Layout.preferredHeight: root.dp(56)
            }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.fillWidth: true
                spacing: root.dp(8)
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    FaceText {
                        face: root
                        Layout.fillWidth: true
                        text: media.effectiveTitle
                        color: IrisStyle.onMedia
                        size: 13
                        weight: Font.DemiBold
                    }
                    FaceText {
                        face: root
                        Layout.fillWidth: true
                        text: media.effectiveArtist
                        color: IrisStyle.onMediaSecondary
                        size: 11.5
                    }
                }
                FaceAction {
                    face: root
                    implicitWidth: root.dp(34)
                    glyph: root.playing ? "pause" : "play_arrow"
                    name: root.playing ? Translation.tr("Pause") : Translation.tr("Play")
                    tint: IrisStyle.onMedia
                    color: IrisStyle.onMediaFill
                    onActivated: media.togglePlaying()
                }
            }
        }
    }

    RowLayout {
        anchors.fill: parent
        visible: root.hasPlayer && root.medium
        spacing: root.dp(14)

        IrisArtwork {
            source: root.art
            circular: false
            radius: root.innerRadius
            Layout.preferredWidth: root.height - root.padding * 2
            Layout.preferredHeight: Layout.preferredWidth
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.dp(2)

            FaceText {
                face: root
                Layout.fillWidth: true
                text: root.source
                color: root.inkTertiary
                size: 11
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: media.effectiveTitle
                size: 15
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: media.effectiveArtist
                color: root.inkSecondary
                size: 12.5
            }
            Item { Layout.fillHeight: true }
            Progress {
                Layout.fillWidth: true
                visible: media.effectiveLength > 0
            }
            Transport {
                Layout.topMargin: root.dp(6)
                disc: root.dp(32)
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        visible: root.hasPlayer && root.large
        spacing: root.dp(12)

        RowLayout {
            Layout.fillWidth: true
            spacing: root.dp(14)
            IrisArtwork {
                source: root.art
                circular: false
                radius: root.innerRadius
                Layout.preferredWidth: root.dp(root.lyricsReady ? 112 : 148)
                Layout.preferredHeight: Layout.preferredWidth
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: root.dp(2)
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    text: root.source
                    color: root.inkTertiary
                    size: 11
                    weight: Font.DemiBold
                }
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    text: media.effectiveTitle
                    size: 17
                    weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                }
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    text: media.effectiveArtist
                    color: root.inkSecondary
                    size: 13
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.dp(4)

            Item { Layout.fillHeight: true }
            FaceText {
                face: root
                Layout.fillWidth: true
                visible: root.lyricsReady
                text: LyricsService.slots[2] ?? ""
                color: root.inkTertiary
                size: 12.5
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: LyricsService.slots[3] || "♪"
                visible: root.lyricsReady
                size: 16
                weight: Font.DemiBold
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                visible: root.lyricsReady
                text: LyricsService.slots[4] ?? ""
                color: root.inkTertiary
                size: 12.5
            }
            Item { Layout.fillHeight: true }
        }

        Progress {
            Layout.fillWidth: true
            visible: media.effectiveLength > 0
        }
        RowLayout {
            Layout.fillWidth: true
            FaceText {
                face: root
                text: StringUtils.friendlyTimeForSeconds(media.effectivePosition)
                color: root.inkTertiary
                font.family: root.fontNumbers
                font.features: ({ "tnum": 1 })
                size: 11
            }
            Item { Layout.fillWidth: true }
            Transport { disc: root.dp(36) }
            Item { Layout.fillWidth: true }
            FaceText {
                face: root
                text: StringUtils.friendlyTimeForSeconds(media.effectiveLength)
                color: root.inkTertiary
                font.family: root.fontNumbers
                font.features: ({ "tnum": 1 })
                size: 11
            }
        }
    }
}
