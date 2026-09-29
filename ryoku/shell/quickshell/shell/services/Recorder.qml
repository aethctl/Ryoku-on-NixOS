pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "lib/screens.js" as Screens

// Screen recording state + control, ported from iNiR's RecorderStatus. The live
// process is the truth: it polls wf-recorder (the backend ryoku-cmd-record drives)
// so a failed launch or an external stop can never strand the island, and reads
// the recorder-status.json the backend writes for the live audio mode. Control
// goes through the one command API -- `ryoku-shell record start|stop`, handled by
// the daemon -- so nothing here builds a recorder invocation of its own. The
// capture card and the floating record island share this single source of truth.
Singleton {
    id: root

    property bool active: false
    property int recorderPid: 0
    property int startedAt: 0
    property int elapsedSec: 0
    readonly property string elapsedText: fmt(elapsedSec)

    // studio capture records through ryoku-cmd-studiorecord (same wf-recorder +
    // strongest-GPU encode as Quick, plus a cursor sidecar) and opens the clip in
    // the ryomotion editor at stop. Tracked so the island's stop routes to the
    // wrapper; anyActive keeps the island up through the brief arm before wf shows.
    property bool studioActive: false
    readonly property bool anyActive: root.active || root.studioActive

    // live audio mode from the backend's status file: none|system|microphone|both,
    // and whether a system+mic mix fell back to a single source.
    property string activeAudioMode: "none"
    property bool audioFallback: false

    // region capture: the box drawn as "WxH+X+Y" (global logical), set when a
    // region recording starts so RegionOverlay can draw the live boundary; ""
    // means a full monitor. A remembered box is valid only for the monitor layout
    // it was drawn in, so it is stamped with a cheap layout signature and dropped
    // the moment the live layout stops matching -- a stale box would land off-screen
    // or on an output that no longer exists.
    property string regionGeom: ""
    property string regionLayoutSig: ""
    readonly property string layoutSig: {
        var out = Screens.uniqueByName(Quickshell.screens);
        var parts = [];
        for (var i = 0; i < out.length; i++) {
            var s = out[i];
            parts.push(s.name + "@" + s.x + "," + s.y + ":" + s.width + "x" + s.height);
        }
        parts.sort();
        return parts.join("|");
    }
    onLayoutSigChanged: {
        if (root.regionGeom !== "" && root.regionLayoutSig !== root.layoutSig)
            root.regionGeom = "";
    }
    onRegionGeomChanged: if (root.regionGeom === "") root.regionLayoutSig = "";

    // Remembered capture options the record card reads, persisted to record.json:
    // the desktop-audio / mic toggles. Shape mirrors Flags: watch for outside
    // edits, write back on change, seed once. A first recording captures the
    // application being demonstrated (desktop audio), not the user's voice --
    // recording a microphone by default is a privacy surprise.
    property alias optDesktopAudio: recPrefs.desktopAudio
    property alias optMic: recPrefs.mic
    // "edit after" opens a finished Quick clip in ryomotion; "studio" captures with
    // a cursor sidecar for the editor's auto-zoom; "discord" makes a Discord-sized
    // copy of a finished Quick clip. All persisted with the audio toggles.
    property alias editMode: recPrefs.edit
    property alias studioMode: recPrefs.studio
    property alias discordMode: recPrefs.discord
    FileView {
        id: recPrefsFile
        path: (Quickshell.env("RYOKU_STATE_PATH") || (Quickshell.env("HOME") + "/.local/state/ryoku")) + "/record.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        JsonAdapter {
            id: recPrefs
            property bool desktopAudio: true
            property bool mic: false
            property bool edit: false
            property bool studio: false
            property bool discord: false
        }
    }
    Component.onCompleted: {
        if (!recPrefsFile.text())
            recPrefsFile.writeAdapter();
        Qt.callLater(root.refreshStatus);
    }

    // desktop-audio + mic flags -> ryoku-shell record args, shared by the card and
    // any other trigger so the argument list is never built two ways.
    function recordArgs() {
        var a = [];
        if (root.optDesktopAudio) a.push("--with-desktop-audio");
        if (root.optMic) a.push("--with-microphone-audio");
        return a;
    }

    // Persist the capture's start time so a shell reload mid-recording keeps
    // counting from the real start instead of resetting the clock. Written when a
    // capture begins, cleared when it ends; the poll reads it back on reload. A
    // capture started outside the shell has no stamp and counts from when the shell
    // first saw it.
    readonly property string sessionFile: (Quickshell.env("RYOKU_STATE_PATH") || (Quickshell.env("HOME") + "/.local/state/ryoku")) + "/record-session"
    function writeSession(v) {
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"${1%/*}\"; printf '%s' \"$2\" > \"$1\"", "sh", root.sessionFile, v]);
    }
    function readSessionStart() {
        const n = parseInt((sessionView.text() || "").trim(), 10);
        return (isFinite(n) && n > 0) ? n : 0;
    }
    FileView {
        id: sessionView
        path: root.sessionFile
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    // pre-record countdown: the capture card can arm a delay (Capture.delay,
    // 0/1/3/5/10s) so the desktop is framed before capture begins. startAfter ticks
    // that delay down -- the island renders it -- then calls start(), so the count
    // is honest. args are latched so a mid-count option change can't retarget it.
    property int countdownSec: 0
    property bool countingDown: false
    property var pendingArgs: []
    function startAfter(args, secs) {
        if (secs <= 0) {
            root.start(args);
            return;
        }
        root.pendingArgs = args || [];
        root.countdownSec = secs;
        root.countingDown = true;
        countdown.restart();
    }
    function cancelCountdown() {
        countdown.stop();
        root.countingDown = false;
        root.countdownSec = 0;
        root.pendingArgs = [];
    }
    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            root.countdownSec--;
            if (root.countdownSec <= 0) {
                countdown.stop();
                root.countingDown = false;
                var a = root.pendingArgs;
                root.pendingArgs = [];
                root.start(a);
            }
        }
    }

    function start(extraArgs) {
        var a = (extraArgs || []).slice();
        // Discord quick-compress rides the backend: pass --discord and ryoku-cmd-
        // record writes the <name>.discord.mp4 copy once the capture is finalised.
        if (root.discordMode)
            a.push("--discord");
        // edit-after is a Quick-only post-action; latch it so a mid-capture toggle
        // can't retarget the just-finished clip. Studio has its own editor hand-off.
        root.pendingEdit = root.editMode;
        // A region capture carries "--region --geometry WxH+X+Y"; stamp the box so
        // RegionOverlay draws the live boundary and it drops on a layout change.
        var isRegion = false, geom = "";
        for (var i = 0; i < a.length; i++) {
            if (a[i] === "--region")
                isRegion = true;
            else if (a[i] === "--geometry" && i + 1 < a.length)
                geom = a[i + 1];
        }
        if (isRegion && /^\d+x\d+\+\d+\+\d+$/.test(geom)) {
            root.regionGeom = geom;
            root.regionLayoutSig = root.layoutSig;
        } else {
            root.regionGeom = "";
        }
        Quickshell.execDetached(["ryoku-shell", "record", "start"].concat(a));
        root.active = true;
        root.startedAt = Math.floor(Date.now() / 1000);
        root.elapsedSec = 0;
        root.writeSession(String(root.startedAt));
        confirm.restart();
    }

    function stop() {
        // a stop during the pre-record countdown just cancels it: nothing launched,
        // so there is nothing to --stop.
        if (root.countingDown) {
            root.cancelCountdown();
            return;
        }
        // studio routes through its wrapper's SIGTERM so the sidecar is written and
        // the editor opens; a Quick capture stops through the daemon.
        if (root.studioActive) {
            root.stopStudio();
            return;
        }
        Quickshell.execDetached(["ryoku-shell", "record", "stop"]);
        root.active = false;
        root.regionGeom = "";
        root.writeSession("");
        // edit-after: hand the just-finished Quick clip to ryomotion.
        if (root.pendingEdit) {
            Quickshell.execDetached([root.editScript]);
            root.pendingEdit = false;
        }
    }

    // studio: record with a cursor sidecar (ryoku-cmd-studiorecord wraps ryoku-cmd-
    // record, so the GPU/encoder path matches Quick), then open the clip in ryomotion
    // at stop. The wrapper is a managed Process so stop can SIGTERM it -- that is what
    // finalises the clip, writes the sidecar and launches the editor.
    readonly property string studioScript: "ryoku-cmd-studiorecord"
    readonly property string editScript: "ryoku-cmd-edit-recording"
    property bool pendingEdit: false
    function startStudio(desktopAudio, mic, regionGeom) {
        var args = [root.studioScript];
        if (regionGeom)
            args.push("--region", "--geometry", regionGeom);
        if (desktopAudio)
            args.push("--with-desktop-audio");
        if (mic)
            args.push("--with-microphone-audio");
        if (regionGeom && /^\d+x\d+\+\d+\+\d+$/.test(regionGeom)) {
            root.regionGeom = regionGeom;
            root.regionLayoutSig = root.layoutSig;
        } else {
            root.regionGeom = "";
        }
        studioProc.command = args;
        studioProc.running = true;
        root.studioActive = true;
        root.startedAt = Math.floor(Date.now() / 1000);
        root.elapsedSec = 0;
        root.writeSession(String(root.startedAt));
    }
    function stopStudio() {
        if (studioProc.running && studioProc.processId > 0)
            Quickshell.execDetached(["kill", "-TERM", String(studioProc.processId)]);
        root.studioActive = false;
        root.startedAt = 0;
        root.elapsedSec = 0;
        root.regionGeom = "";
        root.writeSession("");
    }
    Process {
        id: studioProc
        onRunningChanged: {
            // the wrapper exited on its own (finished + opened the editor, or failed
            // to start): don't strand the island counting up.
            if (!studioProc.running && root.studioActive) {
                root.studioActive = false;
                root.startedAt = 0;
                root.elapsedSec = 0;
                root.writeSession("");
            }
        }
    }

    // ── reconcile against the live process. Detection is wf-recorder's pid; the
    // status file adds the live audio mode. A poll that finds a capture the shell
    // didn't start (reload, or an external launch) restores the clock from the
    // session stamp so it keeps counting rather than resetting.
    function refreshStatus() {
        if (!poll.running)
            poll.running = true;
    }

    Process {
        id: poll
        command: ["pgrep", "-xo", "wf-recorder"]
        stdout: StdioCollector {
            onStreamFinished: {
                var pid = parseInt(text.trim(), 10);
                var nowActive = isFinite(pid) && pid > 0;
                if (nowActive && !root.active) {
                    const persisted = root.readSessionStart();
                    if (persisted > 0) {
                        root.startedAt = persisted;
                        root.elapsedSec = Math.max(0, Math.floor(Date.now() / 1000) - persisted);
                    } else {
                        root.startedAt = Math.floor(Date.now() / 1000);
                        root.elapsedSec = 0;
                        root.writeSession(String(root.startedAt));
                    }
                }
                if (!nowActive && !root.studioActive) {
                    root.startedAt = 0;
                    root.elapsedSec = 0;
                    root.regionGeom = "";
                    root.activeAudioMode = "none";
                    root.audioFallback = false;
                    root.writeSession("");
                }
                root.active = nowActive;
                root.recorderPid = nowActive ? pid : 0;
                if (nowActive)
                    statusView.reload();
            }
        }
    }

    // audio metadata the backend writes alongside the capture.
    FileView {
        id: statusView
        path: (Quickshell.env("RYOKU_STATE_PATH") || (Quickshell.env("HOME") + "/.local/state/ryoku")) + "/recorder-status.json"
        blockLoading: true
        printErrors: false
        onLoaded: {
            try {
                const p = JSON.parse(statusView.text() || "{}");
                if (Number(p.recorderPid ?? 0) === root.recorderPid && root.recorderPid > 0) {
                    root.activeAudioMode = String(p.activeAudioMode ?? "none");
                    root.audioFallback = p.audioFallback === true;
                }
            } catch (e) {
                root.activeAudioMode = "none";
                root.audioFallback = false;
            }
        }
    }

    // poll hard (1s) while a capture is live -- elapsed tick + external-stop
    // detection -- and slowly (5s) idle, enough to catch a capture started outside
    // the shell without a pgrep every second around the clock.
    Timer {
        interval: root.anyActive ? 1000 : 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (root.anyActive && root.startedAt > 0)
                root.elapsedSec = Math.max(0, Math.floor(Date.now() / 1000) - root.startedAt);
            root.refreshStatus();
        }
    }

    // confirm the recorder actually came up after a start; a failed launch would
    // otherwise leave the optimistic running state counting up forever.
    Timer {
        id: confirm
        interval: 2500
        onTriggered: root.refreshStatus()
    }

    function fmt(sec) {
        var s = Math.max(0, Math.round(sec));
        var h = Math.floor(s / 3600);
        var m = Math.floor((s % 3600) / 60);
        var r = s % 60;
        if (h > 0)
            return h + ":" + (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
}
