pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Dialogs
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Widgets
import inir
import inir.services
import inir.modules.common
import inir.modules.common.functions
import inir.modules.common.widgets
import inir.modules.mediaControls.components
import inir.modules.iris.style
import inir.modules.iris.components
import inir.modules.iris.frame
import inir.modules.iris.pieces

GridLayout {
    id: page
    required property Item island
    readonly property bool current: page.island.effectivePage === "media"
    columns: 1
    rowSpacing: 14 * IrisStyle.density
    columnSpacing: 0
    readonly property var blocks: {
        const configured = Config.options?.iris?.bar?.mediaBlocks
        return Array.isArray(configured) ? configured : ["player", "timeline", "transport", "players", "levels"]
    }
    function rowOf(kind: string): int { return page.blocks.indexOf(kind) }
    readonly property string firstExtra: page.blocks.find(kind => (kind === "players" && page.otherPlayers.length > 0) || (kind === "levels" && page.streams.length > 0)) ?? ""


    PlayerBase {
        id: media
        player: page.island.player
        positionUpdatesActive: page.current && page.island.visualExpanded
    }

    readonly property var otherPlayers: (MprisController.displayPlayers ?? []).filter(p => p && p !== page.island.player)
    readonly property var streams: {
        const groups = []
        for (const node of (Audio.outputAppNodes ?? [])) {
            if (!node?.audio) continue
            const name = Audio.appNodeDisplayName(node)
            const group = groups.find(g => g.name === name)
            if (group) group.nodes.push(node)
            else groups.push({ name: name, nodes: [node] })
        }
        return groups
    }

    ColumnLayout {
        Layout.row: Math.max(0, page.rowOf("player"))
        Layout.fillWidth: true
        visible: page.rowOf("player") >= 0
        spacing: 10 * IrisStyle.density
        RowLayout {
            Layout.fillWidth: true
            spacing: 14 * IrisStyle.density
            IrisArtwork {
                id: pageCover
                opacity: page.island.coverFlightItem.hides(pageCover) ? 0 : 1
                Component.onCompleted: page.island.pageCover = pageCover
                Layout.preferredWidth: 68 * IrisStyle.density
                Layout.preferredHeight: 68 * IrisStyle.density
                source: MediaArtwork.displaySource
                circular: Config.options?.iris?.player?.roundCover ?? true
                radius: circular ? width / 2 : 16 * IrisStyle.density
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2 * IrisStyle.density
                IrisText {
                    Layout.fillWidth: true
                    text: media.effectiveTitle
                    font.pixelSize: 15 * IrisStyle.typeScale
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                IrisText {
                    Layout.fillWidth: true
                    text: media.effectiveArtist
                    visible: text.length > 0
                    color: IrisStyle.textSecondary
                    font.pixelSize: 13 * IrisStyle.typeScale
                    elide: Text.ElideRight
                }
            }
            Waveform {
                Layout.alignment: Qt.AlignVCenter
                running: media.effectiveIsPlaying && page.current && page.island.visualExpanded
                tint: page.island.artTint
                barHeight: 20 * IrisStyle.density
            }
        }
    }

    ColumnLayout {
        Layout.row: Math.max(0, page.rowOf("timeline"))
        Layout.fillWidth: true
        visible: page.rowOf("timeline") >= 0 && media.effectiveLength > 0
        spacing: 10 * IrisStyle.density
        ColumnLayout {
            Layout.fillWidth: true
            visible: media.effectiveLength > 0
            spacing: 3 * IrisStyle.density
            IrisScrubber {
                Layout.fillWidth: true
                seekable: media.effectiveCanSeek
                value: media.effectiveLength > 0 ? media.effectivePosition / media.effectiveLength : 0
                fillColor: page.island.artTint
                trackColor: IrisStyle.tintFill(page.island.artTint)
                onSeekRequested: next => media.seek(next * media.effectiveLength)
            }
            RowLayout {
                Layout.fillWidth: true
                Tabular {
                    text: page.island.clockText(media.effectivePosition)
                    color: IrisStyle.textSecondary
                    font.pixelSize: 11 * IrisStyle.typeScale
                    font.weight: Font.Medium
                }
                Item { Layout.fillWidth: true }
                Tabular {
                    text: "-" + page.island.clockText(media.effectiveLength - media.effectivePosition)
                    color: IrisStyle.textSecondary
                    font.pixelSize: 11 * IrisStyle.typeScale
                    font.weight: Font.Medium
                }
            }
        }
    }

    ColumnLayout {
        Layout.row: Math.max(0, page.rowOf("transport"))
        Layout.fillWidth: true
        visible: page.rowOf("transport") >= 0
        spacing: 10 * IrisStyle.density
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: -6 * IrisStyle.density
            Layout.bottomMargin: -4 * IrisStyle.density
            spacing: 18 * IrisStyle.density
            Item { Layout.fillWidth: true }
            GlyphButton {
                glyph: "fast_rewind"
                glyphSize: 26 * IrisStyle.density
                implicitWidth: 44 * IrisStyle.density
                enabled: media.effectiveCanGoPrevious
                Accessible.name: Translation.tr("Previous track")
                onClicked: media.previous()
            }
            GlyphButton {
                glyph: media.effectiveIsPlaying ? "pause" : "play_arrow"
                glyphSize: 36 * IrisStyle.density
                implicitWidth: 52 * IrisStyle.density
                enabled: page.island.hasMedia
                Accessible.name: media.effectiveIsPlaying ? Translation.tr("Pause") : Translation.tr("Play")
                onClicked: media.togglePlaying()
            }
            GlyphButton {
                glyph: "fast_forward"
                glyphSize: 26 * IrisStyle.density
                implicitWidth: 44 * IrisStyle.density
                enabled: media.effectiveCanGoNext
                Accessible.name: Translation.tr("Next track")
                onClicked: media.next()
            }
            Item { Layout.fillWidth: true }
        }
    }

    ColumnLayout {
        Layout.row: Math.max(0, page.rowOf("players"))
        Layout.fillWidth: true
        visible: page.rowOf("players") >= 0 && page.otherPlayers.length > 0
        spacing: 10 * IrisStyle.density
        Rectangle {
            Layout.fillWidth: true
            visible: page.firstExtra === "players"
            implicitHeight: 1
            color: IrisStyle.hairline
        }
        Flow {
            visible: page.otherPlayers.length > 0
            Layout.fillWidth: true
            spacing: 6 * IrisStyle.density
            Repeater {
                model: page.otherPlayers
                IrisButton {
                    id: playerChip
                    required property var modelData
                    implicitHeight: Math.round(32 * IrisStyle.density)
                    implicitWidth: chipRow.implicitWidth + Math.round(20 * IrisStyle.density)
                    buttonRadius: height / 2
                    buttonRadiusPressed: height / 2
                    colBackground: IrisStyle.fillQuiet
                    colBackgroundHover: IrisStyle.fillHover
                    Accessible.name: Translation.tr("Control %1").arg(playerChip.modelData?.identity ?? "")
                    onClicked: MprisController.setActivePlayer(playerChip.modelData)
                    RowLayout {
                        id: chipRow
                        anchors.centerIn: parent
                        spacing: 6 * IrisStyle.density
                        IrisArtwork {
                            Layout.preferredWidth: Math.round(20 * IrisStyle.density)
                            Layout.preferredHeight: Layout.preferredWidth
                            source: String(playerChip.modelData?.trackArtUrl ?? "")
                        }
                        IrisText {
                            text: String(playerChip.modelData?.trackTitle || playerChip.modelData?.identity || "")
                            font.pixelSize: 11.5 * IrisStyle.typeScale
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                            Layout.maximumWidth: Math.round(150 * IrisStyle.density)
                        }
                        Glyph {
                            text: playerChip.modelData?.isPlaying ? "graphic_eq" : "pause"
                            iconSize: 14 * IrisStyle.density
                            color: playerChip.modelData?.isPlaying ? page.island.artTint : IrisStyle.muted
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.row: Math.max(0, page.rowOf("levels"))
        Layout.fillWidth: true
        visible: page.rowOf("levels") >= 0 && page.streams.length > 0
        spacing: 10 * IrisStyle.density
        Rectangle {
            Layout.fillWidth: true
            visible: page.firstExtra === "levels"
            implicitHeight: 1
            color: IrisStyle.hairline
        }
        Repeater {
            model: page.streams.slice(0, 4)
            RowLayout {
                id: appLevel
                required property var modelData
                readonly property var nodes: Array.from(appLevel.modelData?.nodes ?? [])
                readonly property bool muted: appLevel.nodes.every(node => node?.audio?.muted)
                Layout.fillWidth: true
                spacing: 10 * IrisStyle.density
                Image {
                    Layout.preferredWidth: Math.round(22 * IrisStyle.density)
                    Layout.preferredHeight: Layout.preferredWidth
                    sourceSize: Qt.size(Math.round(44 * IrisStyle.density), Math.round(44 * IrisStyle.density))
                    source: appLevel.nodes.length > 0 ? Quickshell.iconPath(MprisController.streamIconName(appLevel.nodes[0]) ?? "", "audio-x-generic") ?? "" : ""
                    opacity: appLevel.muted ? 0.45 : 1
                }
                IrisText {
                    Layout.preferredWidth: Math.round(110 * IrisStyle.density)
                    text: appLevel.nodes.length > 1 ? appLevel.modelData.name + " · " + appLevel.nodes.length : appLevel.modelData.name
                    color: (appLevel.muted ? IrisStyle.textTertiary : IrisStyle.textStrong)
                    font.pixelSize: 12 * IrisStyle.typeScale
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                IrisScrubber {
                    Layout.fillWidth: true
                    fillColor: appLevel.muted ? IrisStyle.muted : IrisStyle.text
                    value: Math.min(1, Math.max(0, ...appLevel.nodes.map(node => node?.audio?.volume ?? 0)))
                    onMoved: next => appLevel.nodes.forEach(node => { if (node?.audio) node.audio.volume = next })
                }
                GlyphButton {
                    glyph: appLevel.muted ? "volume_off" : "volume_up"
                    glyphSize: 17 * IrisStyle.density
                    implicitWidth: Math.round(30 * IrisStyle.density)
                    glyphColor: appLevel.muted ? IrisStyle.danger : IrisStyle.text
                    Accessible.name: appLevel.muted ? Translation.tr("Unmute") : Translation.tr("Mute")
                    onClicked: {
                        const mute = !appLevel.muted
                        appLevel.nodes.forEach(node => { if (node?.audio) node.audio.muted = mute })
                    }
                }
            }
        }
    }

}
