import QtQuick
import QtMultimedia

Item {
    id: root

    property string path: ""
    property bool active: true
    readonly property bool ready: player.playbackState === MediaPlayer.PlayingState && player.hasVideo
    readonly property bool failed: player.error !== MediaPlayer.NoError || player.mediaStatus === MediaPlayer.InvalidMedia
    readonly property string errorText: player.errorString

    MediaPlayer {
        id: player
        source: root.path === "" ? "" : (root.path.indexOf("://") >= 0 ? root.path : "file://" + root.path)
        loops: MediaPlayer.Infinite
        videoOutput: output
        audioOutput: AudioOutput { muted: true }
        onSourceChanged: root.active && source.toString() !== "" ? play() : stop()
    }

    onActiveChanged: {
        if (active && path !== "")
            player.play()
        else
            player.stop()
    }

    VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
    }
}
