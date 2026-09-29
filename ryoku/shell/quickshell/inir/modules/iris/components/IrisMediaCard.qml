pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import inir.services
import inir.modules.common
import inir.modules.common.functions
import inir.modules.common.widgets
import inir.modules.mediaControls.components
import inir.modules.iris.style

Item {
    id: root
    property var player: MprisController.activePlayer
    property bool compact: false
    property bool active: visible
    property bool showBackground: true
    property real headerReserve: 0
    property color tint: IrisStyle.text
    readonly property bool hasPlayer: root.player !== null && root.player !== undefined
    property real seenLength: 0
    property string seenTrack: ""
    property bool lengthGrew: false
    property int atEndSamples: 0
    Timer {
        interval: 2000
        repeat: true
        running: root.active && root.hasPlayer && media.effectiveIsPlaying && !root.liveStream
        onTriggered: {
            const len = media.effectiveLength
            if (len > 0 && media.effectivePosition >= len - 1) root.atEndSamples++
            else root.atEndSamples = 0
        }
    }
    readonly property bool liveStream: root.hasPlayer
        && (media.effectiveLength <= 0
            || (media.effectiveIsPlaying && !media.effectiveCanSeek)
            || root.lengthGrew
            || root.atEndSamples >= 2)
    readonly property bool hasTimeline: root.hasPlayer && !root.liveStream && media.effectiveLength > 0
    Connections {
        target: media
        function onEffectiveTitleChanged(): void {
            root.seenTrack = media.effectiveTitle
            root.seenLength = media.effectiveLength
            root.lengthGrew = false
            root.atEndSamples = 0
        }
        function onEffectiveLengthChanged(): void {
            const now = media.effectiveLength
            if (root.seenLength > 0 && now > root.seenLength + 2) root.lengthGrew = true
            root.seenLength = now
        }
    }
    implicitHeight: (root.compact ? compactBody.implicitHeight : body.implicitHeight) + 28 * IrisStyle.density
    implicitWidth: 360 * IrisStyle.density
    PlayerBase { id: media; player: root.player; positionUpdatesActive: root.active }

    Item {
        anchors.fill: parent
        visible: root.showBackground
        Rectangle { anchors.fill: parent; radius: IrisStyle.radiusSmall; color: IrisStyle.surfaceHigh }
        Loader {
            anchors.fill: parent
            active: root.active && root.showBackground && (Config.options?.iris?.player?.artworkBackground ?? true)
                && media.displayedArtFilePath.length > 0
            sourceComponent: IrisMediaBackdrop { source: media.displayedArtFilePath; radius: IrisStyle.radiusSmall; strength: 0.5 }
        }
    }
    ColumnLayout {
        id: body
        visible: !root.compact
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 14 * IrisStyle.density
        spacing: 12 * IrisStyle.density
        RowLayout {
            Layout.fillWidth: true
            Layout.rightMargin: root.headerReserve
            spacing: 14 * IrisStyle.density
            IrisArtwork {
                source: media.displayedArtFilePath
                circular: Config.options?.iris?.player?.roundCover ?? true
                Layout.preferredWidth: 68 * IrisStyle.density
                Layout.preferredHeight: 68 * IrisStyle.density
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                IrisText { Layout.fillWidth: true; text: root.hasPlayer ? media.effectiveTitle : Translation.tr("Nothing playing"); font.weight: Font.DemiBold; elide: Text.ElideRight }
                IrisText { Layout.fillWidth: true; text: root.hasPlayer ? media.effectiveArtist : Translation.tr("Your music appears here"); role: IrisText.Meta; elide: Text.ElideRight }
            }
        }
        IrisScrubber {
            id: timeline
            Layout.fillWidth: true
            Layout.bottomMargin: -8 * IrisStyle.density
            visible: root.hasTimeline
            seekable: media.effectiveCanSeek
            fillColor: root.tint
            trackColor: IrisStyle.tintFill(root.tint)
            value: media.effectiveLength > 0 ? Math.min(1, media.effectivePosition / media.effectiveLength) : 0
            onSeekRequested: next => media.seek(next * media.effectiveLength)
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.hasTimeline
            IrisText {
                text: StringUtils.friendlyTimeForSeconds(media.effectivePosition)
                color: IrisStyle.textTertiary
                font.pixelSize: 11 * IrisStyle.typeScale
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
            }
            Item { Layout.fillWidth: true }
            IrisText {
                text: StringUtils.friendlyTimeForSeconds(media.effectiveLength)
                color: IrisStyle.textTertiary
                font.pixelSize: 11 * IrisStyle.typeScale
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
            }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: root.hasPlayer && root.liveStream
            spacing: 6 * IrisStyle.density
            Rectangle {
                implicitWidth: Math.round(7 * IrisStyle.density)
                implicitHeight: implicitWidth
                radius: width / 2
                color: IrisStyle.danger
                SequentialAnimation on opacity {
                    running: media.effectiveIsPlaying && root.active
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
            IrisText {
                text: Translation.tr("Live")
                color: IrisStyle.textSecondary
                font.pixelSize: 11.5 * IrisStyle.typeScale
                font.weight: Font.DemiBold
            }
            Item { Layout.fillWidth: true }
            IrisText {
                visible: media.effectivePosition > 0
                text: StringUtils.friendlyTimeForSeconds(media.effectivePosition)
                color: IrisStyle.textTertiary
                font.pixelSize: 11 * IrisStyle.typeScale
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignHCenter
            spacing: 4 * IrisStyle.density
            Item { Layout.fillWidth: true }
            IrisIconButton { materialIcon: "skip_previous"; Accessible.name: Translation.tr("Previous track"); enabled: media.effectiveCanGoPrevious; onClicked: media.previous() }
            IrisIconButton { materialIcon: media.effectiveIsPlaying ? "pause" : "play_arrow"; Accessible.name: media.effectiveIsPlaying ? Translation.tr("Pause") : Translation.tr("Play"); enabled: root.hasPlayer; onClicked: media.togglePlaying(); iconSize: 28 }
            IrisIconButton { materialIcon: "skip_next"; Accessible.name: Translation.tr("Next track"); enabled: media.effectiveCanGoNext; onClicked: media.next() }
            Item { Layout.fillWidth: true }
        }
    }

    RowLayout {
        id: compactBody
        visible: root.compact
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.margins: 14 * IrisStyle.density
        spacing: 12 * IrisStyle.density
        IrisArtwork {
            source: media.displayedArtFilePath
            circular: Config.options?.iris?.player?.roundCover ?? true
            Layout.preferredWidth: 46 * IrisStyle.density
            Layout.preferredHeight: 46 * IrisStyle.density
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            IrisText { Layout.fillWidth: true; text: root.hasPlayer ? media.effectiveTitle : Translation.tr("Nothing playing"); font.weight: Font.DemiBold; elide: Text.ElideRight }
            IrisText { Layout.fillWidth: true; text: root.hasPlayer ? media.effectiveArtist : Translation.tr("Your music appears here"); role: IrisText.Meta; elide: Text.ElideRight }
            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 5 * IrisStyle.density
                visible: root.hasTimeline
                implicitHeight: Math.max(2, Math.round(3 * IrisStyle.density))
                radius: height / 2
                color: IrisStyle.fill
                Rectangle {
                    height: parent.height
                    radius: parent.radius
                    color: root.tint
                    width: parent.width * (media.effectiveLength > 0 ? Math.min(1, media.effectivePosition / media.effectiveLength) : 0)
                }
            }
        }
        IrisIconButton { materialIcon: "skip_previous"; Accessible.name: Translation.tr("Previous track"); enabled: media.effectiveCanGoPrevious; onClicked: media.previous() }
        IrisIconButton { materialIcon: media.effectiveIsPlaying ? "pause" : "play_arrow"; Accessible.name: media.effectiveIsPlaying ? Translation.tr("Pause") : Translation.tr("Play"); enabled: root.hasPlayer; onClicked: media.togglePlaying(); iconSize: 24 }
        IrisIconButton { materialIcon: "skip_next"; Accessible.name: Translation.tr("Next track"); enabled: media.effectiveCanGoNext; onClicked: media.next() }
    }
}
