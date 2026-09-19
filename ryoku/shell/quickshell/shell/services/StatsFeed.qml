pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../utils/menupoll.js" as MenuPoll

// Live GPU / network / disk / fan stats for the desktop system-stats panel.
// GPU utilisation, power and temperature come from the NVIDIA driver when one
// is present (absent on a machine with no NVIDIA card, then gpuAvailable stays
// false and the readouts read zero); network throughput is the RX/TX byte delta
// of every non-loopback interface across the poll interval; disk usage is df on
// /; the fan speed is the first readable hwmon fan tacho. Like Sysinfo it
// refreshes on a 1.5s tick only while a visible owner claims it (setActive,
// owner-refcounted like AudioBars), so an unseen panel costs nothing. Short
// down/up histories feed the chart.
//
// Nothing here forks per tick: the sysfs sources are FileViews and the one
// shell run resolves this machine's sensor paths at load. A runtime-suspended
// discrete GPU is treated as absent: probing it with nvidia-smi would pull the
// card back out of D3 (about 10 W on a hybrid laptop), so the guard reads the
// driver's runtime_status attribute (free, no power impact) and nvidia-smi
// only runs on its own slower tick while the card is already awake. Same guard
// the bar's GPU telemetry and the Hub's plate use.
//
// The properties below are written from the read handlers (as in Sysinfo), so
// they are plain properties; consumers treat them as read-only.
Singleton {
    id: root

    property var owners: []
    readonly property bool active: root.owners.length > 0
    function setActive(owner, on) { root.owners = MenuPoll.setOwnership(root.owners, owner, on); }

    // tick cadence; also the time base for the network byte-rate delta, so the
    // rate needs no wall clock (Date.now throws in the QML engine).
    readonly property int pollMs: 1500

    // GPU: utilisation 0..100, draw in W, package temp in C. gpuAvailable is
    // false when no source answers, and the values stay zero.
    property real gpuPct: 0
    property real gpuPowerW: 0
    property real gpuTempC: 0
    property bool gpuAvailable: false

    // network throughput in bytes/s, plus recent histories for the chart.
    property real downBps: 0
    property real upBps: 0
    property var netDownHist: []
    property var netUpHist: []

    // root filesystem usage in GiB.
    property real diskUsedGiB: 0
    property real diskTotalGiB: 0

    // first readable hwmon fan tacho, in RPM (0 when none is exposed).
    property real fanRpm: 0

    // previous cumulative RX/TX totals; _haveNet gates the first (baseline) read.
    property real _prevRx: 0
    property real _prevTx: 0
    property bool _haveNet: false

    // this machine's sensor paths, resolved once at load; "" means the source
    // is absent. nv is the NVIDIA driver slot dir, amd the drm device node
    // carrying gpu_busy_percent, hwmon its temperature/power sibling, fan the
    // directory holding the first readable tacho.
    property string nv: ""
    property string amd: ""
    property string hwmon: ""
    property string fan: ""
    // the NVIDIA card's runtime-PM state; unknown until the first read, and
    // "unknown" must not probe (that is the whole point of the guard).
    property bool _nvAwake: false

    Process {
        id: discoverProc
        running: true
        command: ["sh", "-c",
            "nv=; for d in /sys/bus/pci/drivers/nvidia/*/; do [ -r \"$d/power/runtime_status\" ] && { nv=${d%/}; break; }; done; "
            + "amd=; hm=; for d in /sys/class/drm/card*/device; do [ -r \"$d/gpu_busy_percent\" ] || continue; "
            + "amd=${d%/}; for h in \"$amd\"/hwmon/hwmon*; do [ -r \"$h/temp1_input\" ] && { hm=${h%/}; break; }; done; break; done; "
            + "fan=; for f in /sys/class/hwmon/hwmon*/fan1_input; do [ -r \"$f\" ] && { fan=$(dirname \"$f\"); break; }; done; "
            + "printf '{\"nv\":\"%s\",\"amd\":\"%s\",\"hwmon\":\"%s\",\"fan\":\"%s\"}\\n' \"$nv\" \"$amd\" \"$hm\" \"$fan\""]
        stdout: StdioCollector { onStreamFinished: root._readPaths(this.text) }
    }

    function _readPaths(text) {
        try {
            const p = JSON.parse(text.trim());
            root.nv = p.nv || "";
            root.amd = p.amd || "";
            root.hwmon = p.hwmon || "";
            root.fan = p.fan || "";
        } catch (e) {
            // No paths resolved: the GPU and fan readouts stay absent, which is
            // the same outcome as a machine with no sensors.
        }
    }

    // nvidia-smi CSV first line: "<util>, <power>, <temp>" (nounits). A missing
    // binary yields empty stdout (2>/dev/null, sh exits nonzero) -> unavailable.
    function _readGpu(text) {
        var line = ((text || "").trim().split("\n")[0] || "").trim();
        var p = line.length > 0 ? line.split(",") : [];
        if (p.length < 3) {
            root.gpuAvailable = false;
            root.gpuPct = 0; root.gpuPowerW = 0; root.gpuTempC = 0;
            return;
        }
        var u = Number((p[0] || "").trim());
        var w = Number((p[1] || "").trim());
        var t = Number((p[2] || "").trim());
        root.gpuPct = isNaN(u) ? 0 : Math.max(0, Math.min(100, u));
        root.gpuPowerW = isNaN(w) ? 0 : Math.max(0, w);
        root.gpuTempC = isNaN(t) ? 0 : t;
        root.gpuAvailable = true;
    }

    // /proc/net/dev: each data line is "iface: rxbytes ... txbytes ...". Sum RX
    // (field 1) and TX (field 9) over every interface but lo, then rate = delta
    // over the fixed poll interval. Header lines have no ':' and fall through.
    function _readNet(text) {
        var lines = (text || "").split("\n");
        var rx = 0, tx = 0;
        for (var i = 0; i < lines.length; i++) {
            var ci = lines[i].indexOf(":");
            if (ci < 0)
                continue;
            var name = lines[i].slice(0, ci).trim();
            if (name === "" || name === "lo")
                continue;
            var f = lines[i].slice(ci + 1).trim().split(/\s+/);
            if (f.length < 9)
                continue;
            rx += Number(f[0]) || 0;
            tx += Number(f[8]) || 0;
        }
        if (root._haveNet) {
            var dt = root.pollMs / 1000;
            root.downBps = Math.max(0, (rx - root._prevRx) / dt);
            root.upBps = Math.max(0, (tx - root._prevTx) / dt);
            var dh = root.netDownHist.slice();
            dh.push(root.downBps);
            while (dh.length > 48)
                dh.shift();
            root.netDownHist = dh;
            var uh = root.netUpHist.slice();
            uh.push(root.upBps);
            while (uh.length > 48)
                uh.shift();
            root.netUpHist = uh;
        }
        root._prevRx = rx;
        root._prevTx = tx;
        root._haveNet = true;
    }

    // df -B1 --output=used,size /: header row then "<used> <size>" in bytes.
    function _readDisk(text) {
        var lines = (text || "").trim().split("\n");
        if (lines.length < 2)
            return;
        var f = lines[lines.length - 1].trim().split(/\s+/);
        if (f.length < 2)
            return;
        var used = Number(f[0]), size = Number(f[1]);
        var giB = 1073741824;
        if (!isNaN(used))
            root.diskUsedGiB = used / giB;
        if (!isNaN(size))
            root.diskTotalGiB = size / giB;
    }

    // hwmon reports temp in millidegrees and power in microwatts; the AMD
    // busy_percent node is the utilisation. A machine with an NVIDIA card but
    // no readable AMD node never binds these paths, so nothing parses.
    function _readBusy(text) {
        var v = parseInt((text || "").trim(), 10);
        if (isNaN(v)) {
            root.gpuAvailable = false;
            return;
        }
        root.gpuPct = Math.max(0, Math.min(100, v));
        root.gpuAvailable = true;
    }
    function _readGpuTemp(text) {
        var v = parseInt((text || "").trim(), 10);
        root.gpuTempC = (!isNaN(v) && v > 0) ? (v > 1000 ? v / 1000 : v) : 0;
    }
    function _readGpuPower(text) {
        var v = parseInt((text || "").trim(), 10);
        root.gpuPowerW = (!isNaN(v) && v > 0) ? v / 1000000 : 0;
    }
    function _readFan(text) {
        var v = parseInt((text || "").trim(), 10);
        root.fanRpm = (!isNaN(v) && v >= 0) ? v : 0;
    }

    FileView { id: netFile; path: "/proc/net/dev"; blockLoading: true; printErrors: false; onLoaded: root._readNet(netFile.text()) }
    FileView { id: runtimeFile; path: root.nv !== "" ? root.nv + "/power/runtime_status" : ""; blockLoading: true; printErrors: false
        onLoaded: {
            var s = text().trim();
            root._nvAwake = s !== "" && s !== "suspended";
            if (!root._nvAwake) {
                root.gpuAvailable = false;
                root.gpuPct = 0; root.gpuPowerW = 0; root.gpuTempC = 0;
            }
        }
    }
    FileView { id: busyFile; path: root.nv === "" && root.amd !== "" ? root.amd + "/gpu_busy_percent" : ""; blockLoading: true; printErrors: false; onLoaded: root._readBusy(busyFile.text()) }
    FileView { id: gpuTempFile; path: root.nv === "" && root.hwmon !== "" ? root.hwmon + "/temp1_input" : ""; blockLoading: true; printErrors: false; onLoaded: root._readGpuTemp(gpuTempFile.text()) }
    FileView { id: gpuPowerFile; path: root.nv === "" && root.hwmon !== "" ? root.hwmon + "/power1_average" : ""; blockLoading: true; printErrors: false; onLoaded: root._readGpuPower(gpuPowerFile.text()) }
    FileView { id: fanFile; path: root.fan !== "" ? root.fan + "/fan1_input" : ""; blockLoading: true; printErrors: false; onLoaded: root._readFan(fanFile.text()) }

    // nvidia-smi is the only GPU source that costs a fork, so it runs at a
    // quarter of the tick rate and only while the card is already awake.
    Process {
        id: gpuProc
        running: false
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,power.draw,temperature.gpu", "--format=csv,noheader,nounits"]
        stdout: StdioCollector { onStreamFinished: root._readGpu(this.text) }
    }

    Process {
        id: diskProc
        running: false
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector { onStreamFinished: root._readDisk(this.text) }
    }

    Timer {
        interval: root.pollMs
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            netFile.reload();
            if (root.nv !== "")
                runtimeFile.reload();
            else if (root.amd !== "") {
                busyFile.reload();
                gpuTempFile.reload();
                gpuPowerFile.reload();
            }
            if (root.fan !== "")
                fanFile.reload();
        }
    }
    Timer {
        interval: 5000
        running: root.active && root.nv !== "" && root._nvAwake
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            gpuProc.running = false;
            gpuProc.running = true;
        }
    }
    // disk usage moves on a human scale, not a frame scale.
    Timer {
        interval: 30000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            diskProc.running = false;
            diskProc.running = true;
        }
    }
    // drop the stale byte baseline on close so the next open measures a fresh
    // interval rather than one spanning the idle gap.
    onActiveChanged: if (!root.active) root._haveNet = false;
}
