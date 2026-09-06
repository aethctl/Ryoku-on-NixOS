import QtQuick

QtObject {
    required property string screenName
    property bool ready: false
    property string path: ""
    property int revision: 0
    property string fit: "Cover"
    property var transition: null
    property string depth: ""
    property int depthRev: 0
    property string videoPath: ""
    property bool live: false
    // The in-shell clip's audio: muted by default, full volume (0-100). The
    // daemon fills them for a video frame; a still leaves the defaults.
    property bool mute: true
    property int volume: 100

    function apply(line: string): bool {
        try {
            const state = JSON.parse(line);
            const entry = (state.outputs && state.outputs[screenName]) || state.default;
            if (!entry)
                return false;
            ready = true;
            fit = entry.fit || "Cover";
            transition = entry.transition || null;
            path = entry.path || "";
            depth = entry.depth || "";
            depthRev = entry.depthRev || 0;
            revision = entry.revision || 0;
            videoPath = entry.videoPath || "";
            live = entry.live === true;
            mute = entry.mute !== false;
            volume = (typeof entry.volume === "number") ? entry.volume : 100;
            return true;
        } catch (error) {
            return false;
        }
    }
}
