pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons

Item {
    id: pg

    property var hub
    property string tab: "scene"
    property var stageFrame: ({ current: "", busy: false, stage: "", percent: 0, walls: ({}) })
    property var models: []
    property string modelError: ""
    property string pendingQuality: ""
    property string pickedCut: ""
    property bool clearArmed: false
    property var commandQueue: []
    property string commandLabel: ""
    property string error: ""
    property var pendingLayers: ({})
    property var pendingEdits: ({})
    property string launchTarget: ""
    property bool pointerDetails: false
    readonly property var motionPresets: ({
        soft: { amount: "subtle", idle: "float", speed: 0.6, music: false },
        cinematic: { amount: "normal", idle: "sway", speed: 0.5, music: false },
        beat: { amount: "strong", idle: "none", speed: 1, music: true }
    })

    readonly property string currentWall: stageFrame.current || ""
    readonly property var wall: currentWall && stageFrame.walls ? (stageFrame.walls[currentWall] || null) : null
    readonly property string effect: wall && wall.effect ? wall.effect : "off"
    readonly property var layers: wall && Array.isArray(wall.layers) ? wall.layers : []
    readonly property bool stageBusy: stageFrame.busy === true
    readonly property bool commandBusy: commandProc.running || commandQueue.length > 0
    readonly property string stateDir: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
    readonly property string previewPath: pg.isVideo(pg.currentWall) ? pg.stateDir + "/ryoku-live-frame.png" : pg.currentWall
    readonly property string shownQuality: pendingQuality !== "" ? pendingQuality : stageCfg.quality
    readonly property var shownModel: pg.modelForQuality(shownQuality)
    readonly property bool shownInstalled: shownModel && shownModel.installed === true
    readonly property string stageSock: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"
    readonly property string engine: {
        var dir = Quickshell.env("RYOKU_SHELL_DIR");
        return dir !== "" ? dir + "/scripts/ryostage" : "ryostage";
    }
    readonly property bool twoColumns: width >= 700

    function focusKey(key) {
        var text = String(key || "");
        pg.tab = text.indexOf("visualizer") >= 0 ? "visualizer" : text.indexOf("widget") >= 0 ? "widgets" : "scene";
    }
    function isVideo(path) { return /\.(mp4|webm|mkv|mov)$/i.test(String(path || "")); }
    function pathFromUrl(url) {
        var text = String(url || "");
        return text.indexOf("file://") === 0 ? decodeURIComponent(text.slice(7)) : text;
    }
    function leaf(path) { var parts = String(path || "").split("/"); return parts.length ? parts[parts.length - 1] : ""; }
    function effectLabel() {
        if (effect === "parallax") return I18n.tr("Parallax scene");
        if (effect === "depth") return I18n.tr("Depth scene");
        return I18n.tr("Plain wallpaper");
    }
    function layerLabel(index) {
        var layer = layers[index] || ({}), label = String(layer.label || "");
        return label !== "" ? label.charAt(0).toUpperCase() + label.slice(1) : (index === 0 ? I18n.tr("Subject") : I18n.tr("Layer %1").arg(index + 1));
    }
    function modelForQuality(value) {
        var tier = value === "fine" ? "fine" : "draft";
        for (var i = 0; i < models.length; ++i) if (models[i].tier === tier) return models[i];
        return null;
    }
    function motionValue(key, fallback) {
        var value = stageCfg.motion ? stageCfg.motion[key] : undefined;
        return value === undefined ? fallback : value;
    }
    function motionPreset() {
        for (var name in pg.motionPresets) {
            var preset = pg.motionPresets[name];
            if (pg.motionValue("amount", "normal") === preset.amount
                && pg.motionValue("idle", "none") === preset.idle
                && pg.motionValue("speed", 1) === preset.speed
                && pg.motionValue("music", false) === preset.music)
                return name;
        }
        return "";
    }
    function applyMotionPreset(name) {
        var preset = pg.motionPresets[name];
        if (!preset) return;
        pg.flushEdits();
        pg.shellCall("stage-settings", "setAmount", preset.amount, I18n.tr("Saving motion preset"));
        pg.shellCall("stage-settings", "setIdle", preset.idle, I18n.tr("Saving motion preset"));
        pg.shellCall("stage-settings", "setSpeed", preset.speed, I18n.tr("Saving motion preset"));
        pg.shellCall("stage-settings", "setMusic", preset.music, I18n.tr("Saving motion preset"));
    }
    function shellCall(target, method, value, label) {
        var cmd = ["qs", "-c", "shell", "ipc", "call", target, method];
        if (value !== undefined) cmd.push(String(value));
        pg.enqueue(cmd, label || I18n.tr("Saving setting"));
    }
    function coalesce(key, target, method, value, label) {
        var next = Object.assign({}, pg.pendingEdits);
        next[key] = { target: target, method: method, value: value, label: label };
        pg.pendingEdits = next;
        editSettle.restart();
    }
    function flushEdits() {
        editSettle.stop();
        var edits = pg.pendingEdits;
        pg.pendingEdits = ({});
        for (var key in edits) {
            var edit = edits[key];
            pg.shellCall(edit.target, edit.method, edit.value, edit.label);
        }
    }
    function stageCall(verb) {
        var cmd = ["ryoku-shell", "stage", verb];
        for (var i = 1; i < arguments.length; ++i) cmd.push(String(arguments[i]));
        pg.enqueue(cmd, I18n.tr("Updating the scene"));
    }
    function enqueue(command, label) {
        var queue = pg.commandQueue.slice();
        queue.push({ command: command, label: label });
        pg.commandQueue = queue;
        if (!commandProc.running) pg.runNext();
    }
    function runNext() {
        if (!pg.commandQueue.length) { pg.commandLabel = ""; return; }
        pg.error = "";
        pg.commandLabel = pg.commandQueue[0].label;
        commandProc.command = pg.commandQueue[0].command;
        commandProc.running = true;
    }
    function finishCommand(code) {
        var out = commandOut.text.trim(), err = commandErr.text.trim();
        if (code !== 0 || (out !== "" && !/^ok(?:\s|$)/.test(out))) {
            pg.error = err || out || I18n.tr("The desktop service did not accept this change.");
            pg.commandQueue = [];
            pg.commandLabel = "";
            return;
        }
        pg.commandQueue = pg.commandQueue.slice(1);
        pg.runNext();
    }
    function chooseQuality(value) { pendingQuality = value === stageCfg.quality ? "" : value; }
    function applyQuality() {
        if (pendingQuality === "" || !shownInstalled) return;
        pg.shellCall("stage-settings", "setQuality", pendingQuality, I18n.tr("Saving cut quality"));
        pg.stageCall("refresh");
        pendingQuality = "";
    }
    function installModel() {
        if (!shownModel || installProc.running) return;
        pg.error = "";
        installProc.command = [pg.engine, "install", shownModel.id];
        installProc.running = true;
    }
    function setLayer(index, values) { pg.stageCall("set-layer", index, JSON.stringify(values)); }
    function setLayerDepth(index, value) {
        var pending = Object.assign({}, pg.pendingLayers);
        pending[index] = Math.max(0, Math.min(1, value));
        pg.pendingLayers = pending;
        layerSettle.restart();
    }
    function launchEditor(target) {
        if (launchProc.running) return;
        pg.error = "";
        pg.launchTarget = target;
        launchProc.command = target === "widgets"
            ? ["qs", "-c", "shell", "ipc", "call", "desktop", "editWidgets", ""]
            : ["qs", "-c", "shell", "ipc", "call", "visualizer", "place"];
        launchProc.running = true;
    }

    FileView {
        id: stageFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/stage.json"
        blockLoading: true; watchChanges: true; printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: stageCfg
            property string quality: "draft"
            property real edge: 0.15
            property real shadow: 0
            property int shadowAngle: 90
            property var motion: ({ amount: "normal", idle: "none", music: false, mouse: true })
            property var front: []
        }
    }
    FileView {
        id: vizFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/visualizer.json"
        blockLoading: true; watchChanges: true; printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: vizCfg
            property bool enabled: true
            property string style: "wave"
            property int fps: 60
            property bool adaptive: true
            property real gain: 1
            property real smoothing: 0.5
        }
    }
    Socket {
        id: stageSub
        path: pg.stageSock
        parser: SplitParser { onRead: line => { try { var value = JSON.parse(line); if (value && typeof value === "object") pg.stageFrame = value; } catch (e) {} } }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) { write("subscribe stage\n"); flush(); }
            else stageRetry.restart();
        }
    }
    Timer { id: stageRetry; interval: 2000; onTriggered: if (!stageSub.connected) stageSub.connected = true }
    Timer {
        id: editSettle
        interval: 180
        onTriggered: pg.flushEdits()
    }
    Timer {
        id: layerSettle
        interval: 300
        onTriggered: {
            for (var index in pg.pendingLayers) pg.setLayer(Number(index), { depth: pg.pendingLayers[index] });
            pg.pendingLayers = ({});
        }
    }
    Process {
        id: commandProc
        stdout: StdioCollector { id: commandOut }
        stderr: StdioCollector { id: commandErr }
        onExited: code => pg.finishCommand(code)
    }
    Process {
        id: modelsProc
        command: [pg.engine, "models", "--json"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var value = JSON.parse(text || "[]");
                    pg.models = Array.isArray(value) ? value : [];
                    pg.modelError = pg.models.length > 0 ? "" : I18n.tr("The cut model catalogue is empty.");
                } catch (e) {
                    pg.models = [];
                    pg.modelError = I18n.tr("The cut model catalogue could not be read.");
                }
            }
        }
        stderr: StdioCollector { id: modelsErr }
        onExited: code => {
            if (code !== 0)
                pg.modelError = modelsErr.text.trim() || I18n.tr("The cut model catalogue is unavailable.");
        }
    }
    Process {
        id: installProc
        stderr: StdioCollector { id: installErr }
        onExited: code => {
            if (code !== 0) pg.error = installErr.text.trim() || I18n.tr("The cut model could not be installed.");
            modelsProc.running = false; modelsProc.running = true;
        }
    }
    Process {
        id: launchProc
        stdout: StdioCollector { id: launchOut }
        stderr: StdioCollector { id: launchErr }
        onExited: code => {
            var result = launchOut.text.trim();
            if (code !== 0 || (result !== "" && result !== "ok")) {
                pg.error = launchErr.text.trim() || result || I18n.tr("The desktop editor did not open.");
                return;
            }
            if (pg.hub) pg.hub.requestQuit();
        }
    }

    component Title: Column {
        property string text: ""
        property string detail: ""
        width: parent.width; spacing: Tokens.s1
        Text { width: parent.width; text: parent.text; color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fRow; font.weight: Font.DemiBold; wrapMode: Text.WordWrap }
        Text { visible: text !== ""; width: parent.width; text: parent.detail; color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap }
    }
    component Sheet: Rectangle {
        id: sheet
        default property alias content: sheetBody.data
        property string title: ""
        width: parent.width; implicitHeight: sheetBody.implicitHeight + Tokens.s4 * 2
        radius: Tokens.radius; color: Tokens.paperLift; border.width: Tokens.border; border.color: Tokens.line
        Column { id: sheetBody; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Tokens.s4; spacing: Tokens.s4
            Text { visible: text !== ""; width: parent.width; text: sheet.title; color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; font.weight: Font.DemiBold; font.letterSpacing: Tokens.trackLabel }
        }
    }
    component ValueRow: Item {
        id: row
        property string label: ""
        property string detail: ""
        property real controlWidth: 260
        default property alias control: controlSlot.data
        width: parent.width; implicitHeight: Math.max(58, copy.implicitHeight, controlSlot.implicitHeight)
        Column { id: copy; anchors.left: parent.left; anchors.right: controlSlot.left; anchors.rightMargin: Tokens.s4; anchors.verticalCenter: parent.verticalCenter
            Text { width: parent.width; text: row.label; color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fRow; wrapMode: Text.WordWrap }
            Text { visible: text !== ""; width: parent.width; text: row.detail; color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap }
        }
        Column { id: controlSlot; width: Math.min(row.controlWidth, row.width * 0.5); anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter }
    }
    component LayerCard: Rectangle {
        id: layerCard
        required property int layerIndex
        readonly property var layerData: pg.layers[layerIndex] || ({})
        width: parent.width; implicitHeight: layerBody.implicitHeight + Tokens.s3 * 2
        radius: Tokens.radius; color: Tokens.tint5; border.width: Tokens.border; border.color: Tokens.line
        Column {
            id: layerBody
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Tokens.s3; spacing: Tokens.s3
            Item { width: parent.width; implicitHeight: Math.max(layerName.implicitHeight, layerActions.implicitHeight)
                Text { id: layerName; anchors.left: parent.left; anchors.right: layerActions.left; anchors.rightMargin: Tokens.s2; anchors.verticalCenter: parent.verticalCenter; text: pg.layerLabel(layerCard.layerIndex); color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fRow; font.weight: Font.DemiBold; elide: Text.ElideRight
                    HoverHandler { id: layerNameHover }
                    QQC.ToolTip.visible: layerNameHover.hovered && layerName.truncated
                    QQC.ToolTip.text: layerName.text
                }
                Row { id: layerActions; anchors.right: parent.right; spacing: Tokens.s2
                    Seg { options: ["behind", "front"]; labels: ({ behind: I18n.tr("Behind"), front: I18n.tr("In front") }); current: layerCard.layerData.front === true ? "front" : "behind"; onChose: value => pg.setLayer(layerCard.layerIndex, { front: value === "front" }) }
                    Btn { visible: layerCard.layerIndex > 0; text: I18n.tr("Remove"); compact: true; onAct: pg.stageCall("remove-layer", layerCard.layerIndex) }
                }
            }
            ValueRow { visible: pg.effect === "parallax"; label: I18n.tr("Drift"); detail: I18n.tr("How far this layer travels"); controlWidth: 190
                Slid { width: parent.width; value: typeof layerCard.layerData.depth === "number" ? layerCard.layerData.depth : 0.5; from: 0; to: 1; onModified: value => pg.setLayerDepth(layerCard.layerIndex, value) }
            }
        }
    }

    Column {
        id: head
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
        anchors.leftMargin: Tokens.s6; anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s5
        spacing: Tokens.s3
        Row { spacing: Tokens.s2
            Rectangle { width: 16; height: 1; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "力"; color: Tokens.ink; font.family: Tokens.jp; font.pixelSize: Tokens.fMicro; anchors.verticalCenter: parent.verticalCenter }
            Text { text: I18n.tr("DESKTOP"); color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fTiny; font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark; anchors.verticalCenter: parent.verticalCenter }
        }
        Text { text: I18n.tr("Desktop Scene"); color: Tokens.ink; font.family: Tokens.display; font.pixelSize: Tokens.fTitle }
        Text { width: Math.min(parent.width, 760); text: I18n.tr("Build depth into the wallpaper, tune its motion, and place sound and widgets in the composition."); color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fBody; wrapMode: Text.WordWrap }
        Seg { options: ["scene", "visualizer", "widgets"]; labels: ({ scene: I18n.tr("Scene"), visualizer: I18n.tr("Visualizer"), widgets: I18n.tr("Widgets") }); current: pg.tab; onChose: value => pg.tab = value }
    }

    Flickable {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: head.bottom; anchors.bottom: parent.bottom
        anchors.leftMargin: Tokens.s6; anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s5
        contentWidth: width; contentHeight: pageBody.implicitHeight + Tokens.s6; clip: true; boundsBehavior: Flickable.StopAtBounds
        QQC.ScrollBar.vertical: ScrollRail { policy: QQC.ScrollBar.AsNeeded }
        WheelScroll {}
        Column {
            id: pageBody
            width: parent.width - Tokens.s2; spacing: Tokens.s5

            Grid {
                visible: pg.tab === "scene"; width: parent.width; columns: pg.twoColumns ? 2 : 1; columnSpacing: Tokens.s5; rowSpacing: Tokens.s5
                Column {
                    width: pg.twoColumns ? (pageBody.width - Tokens.s5) / 2 : pageBody.width; spacing: Tokens.s4
                    Rectangle {
                        width: parent.width; implicitHeight: 268; radius: Tokens.radius; clip: true; color: Tokens.tint5; border.width: Tokens.border; border.color: Tokens.line
                        Image { id: wallpaperPreview; anchors.fill: parent; source: pg.previewPath !== "" ? "file://" + pg.previewPath : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; opacity: status === Image.Ready ? 0.72 : 0 }
                        Rectangle {
                            anchors.fill: parent
                            color: "transparent"
                            gradient: Gradient {
                                orientation: Gradient.Vertical
                                GradientStop { position: 0; color: Qt.rgba(Tokens.paper.r, Tokens.paper.g, Tokens.paper.b, 0.02) }
                                GradientStop { position: 1; color: Qt.rgba(Tokens.paper.r, Tokens.paper.g, Tokens.paper.b, 0.94) }
                            }
                        }
                        Image { visible: pg.effect !== "off" && pg.layers.length > 0; anchors.fill: parent; source: pg.layers.length > 0 && pg.layers[0].out ? "file://" + pg.layers[0].out : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; opacity: status === Image.Ready ? 0.86 : 0 }
                        Text { visible: wallpaperPreview.status !== Image.Ready; anchors.centerIn: parent; text: "layers"; color: Tokens.inkFaint; font.family: "Material Symbols Rounded"; font.pixelSize: 72 }
                        Column { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: Tokens.s4; spacing: Tokens.s1
                            Text { width: parent.width; text: pg.effectLabel(); color: Tokens.ink; font.family: Tokens.display; font.pixelSize: Tokens.fHero; elide: Text.ElideRight }
                            Text { width: parent.width; text: pg.stageBusy ? I18n.tr("Building layers · %1%").arg(stageFrame.percent || 0) : pg.layers.length ? I18n.tr("%1 layers ready").arg(pg.layers.length) : I18n.tr("Choose Depth or Parallax to cut this wallpaper into layers."); color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap }
                        }
                    }
                    Seg { width: parent.width; options: ["off", "depth", "parallax"]; labels: ({ off: I18n.tr("Plain"), depth: I18n.tr("Depth"), parallax: I18n.tr("Parallax") }); current: pg.effect; onChose: value => pg.stageCall("set-effect", value) }
                    Rectangle { visible: pg.stageBusy; width: parent.width; implicitHeight: busyRow.implicitHeight + Tokens.s3 * 2; radius: Tokens.radius; color: Tokens.tint5; border.width: Tokens.border; border.color: Tokens.line
                        Row { id: busyRow; anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.margins: Tokens.s3; spacing: Tokens.s3
                            Text { text: "progress_activity"; color: Tokens.bone; font.family: "Material Symbols Rounded"; font.pixelSize: 22; anchors.verticalCenter: parent.verticalCenter }
                            Text { width: parent.width - stopCut.width - 42; text: I18n.tr("Cutting · %1%").arg(stageFrame.percent || 0); color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
                            Btn { id: stopCut; text: I18n.tr("Stop"); compact: true; onAct: pg.stageCall("cancel") }
                        }
                    }
                    Sheet { visible: pg.effect !== "off"; title: I18n.tr("CUT & LAYERS")
                        Title { text: I18n.tr("Cut quality"); detail: I18n.tr("Fine quality uses a larger model. A quality change rebuilds the current wallpaper.") }
                        Seg { width: parent.width; options: ["draft", "standard", "fine"]; labels: ({ draft: I18n.tr("Draft"), standard: I18n.tr("Standard"), fine: I18n.tr("Fine") }); current: pg.shownQuality; onChose: value => pg.chooseQuality(value) }
                        Rectangle { visible: pg.pendingQuality !== ""; width: parent.width; implicitHeight: qualityRow.implicitHeight + Tokens.s3 * 2; radius: Tokens.radius; color: Tokens.tint5; border.width: Tokens.border; border.color: Tokens.line
                            Row { id: qualityRow; anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.margins: Tokens.s3; spacing: Tokens.s3
                                Text { width: parent.width - qualityAction.width - Tokens.s3; text: !pg.shownModel ? (pg.modelError !== "" ? pg.modelError : I18n.tr("Checking the model catalogue…")) : !pg.shownInstalled ? I18n.tr("Download %1 to use this quality.").arg(pg.shownModel.size || I18n.tr("the required model")) : I18n.tr("Re-cut this wallpaper at the selected quality."); color: pg.modelError !== "" ? Tokens.alert : Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap; anchors.verticalCenter: parent.verticalCenter }
                                Btn { id: qualityAction; text: installProc.running ? I18n.tr("Downloading…") : pg.shownInstalled ? I18n.tr("Re-cut") : I18n.tr("Download"); primary: true; armed: !installProc.running && pg.shownModel !== null; onAct: pg.shownInstalled ? pg.applyQuality() : pg.installModel() }
                            }
                        }
                        Repeater { model: pg.layers.length; delegate: LayerCard { required property int index; layerIndex: index } }
                        Flow { width: parent.width; spacing: Tokens.s2
                            Btn { text: I18n.tr("Cut a picture…"); onAct: cutDialog.open() }
                            Btn { text: I18n.tr("Add a PNG…"); onAct: pngDialog.open() }
                            Btn { visible: pg.layers.length > 0 && !pg.clearArmed; text: I18n.tr("Clear cut-outs"); onAct: pg.clearArmed = true }
                        }
                        Rectangle { visible: pg.pickedCut !== ""; width: parent.width; implicitHeight: pickedRow.implicitHeight + Tokens.s3 * 2; radius: Tokens.radius; color: Tokens.tint5; border.width: Tokens.border; border.color: Tokens.line
                            Row { id: pickedRow; anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.margins: Tokens.s3; spacing: Tokens.s2
                                Text { width: parent.width - cutAction.width - Tokens.s2; text: pg.leaf(pg.pathFromUrl(pg.pickedCut)); color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; elide: Text.ElideMiddle; anchors.verticalCenter: parent.verticalCenter }
                                Btn { id: cutAction; text: I18n.tr("Cut"); primary: true; onAct: { pg.stageCall("cut-layer", pg.pathFromUrl(pg.pickedCut)); pg.pickedCut = ""; } }
                            }
                        }
                        Rectangle { visible: pg.clearArmed; width: parent.width; implicitHeight: clearRow.implicitHeight + Tokens.s3 * 2; radius: Tokens.radius; color: Qt.rgba(Tokens.alert.r, Tokens.alert.g, Tokens.alert.b, 0.08); border.width: Tokens.border; border.color: Tokens.alert
                            Row { id: clearRow; anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.margins: Tokens.s3; spacing: Tokens.s2
                                Text { width: parent.width - clearButtons.width - Tokens.s2; text: I18n.tr("Remove every cut-out for this wallpaper?"); color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap; anchors.verticalCenter: parent.verticalCenter }
                                Row {
                                    id: clearButtons
                                    spacing: Tokens.s2
                                    Btn { text: I18n.tr("Cancel"); compact: true; onAct: pg.clearArmed = false }
                                    Btn { text: I18n.tr("Clear"); compact: true; primary: true; onAct: { pg.stageCall("clear"); pg.clearArmed = false; } }
                                }
                            }
                        }
                    }
                }

                Column {
                    width: pg.twoColumns ? (pageBody.width - Tokens.s5) / 2 : pageBody.width; spacing: Tokens.s4
                    Sheet { title: I18n.tr("LOOK")
                        ValueRow { label: I18n.tr("Edge softness"); detail: Math.round(stageCfg.edge * 100) + "%"; Slid { width: parent.width; value: stageCfg.edge; from: 0; to: 1; onModified: value => pg.coalesce("stage.edge", "stage-settings", "setEdge", value, I18n.tr("Saving edge softness")) } }
                        ValueRow { label: I18n.tr("Shadow"); detail: Math.round(stageCfg.shadow * 100) + "%"; Slid { width: parent.width; value: stageCfg.shadow; from: 0; to: 1; onModified: value => pg.coalesce("stage.shadow", "stage-settings", "setShadow", value, I18n.tr("Saving layer shadow")) } }
                        ValueRow { label: I18n.tr("Shadow direction"); detail: stageCfg.shadowAngle + "°"; Slid { width: parent.width; value: ((stageCfg.shadowAngle % 360) + 360) % 360; from: 0; to: 360; onModified: value => pg.coalesce("stage.shadowAngle", "stage-settings", "setShadowAngle", value, I18n.tr("Saving shadow direction")) } }
                        Btn { text: I18n.tr("Reset look and motion"); compact: true; onAct: { pg.flushEdits(); pg.shellCall("stage-settings", "resetLook", undefined, I18n.tr("Resetting look and motion")); } }
                    }
                    Sheet { visible: pg.effect === "parallax"; title: I18n.tr("MOTION")
                        ValueRow { label: I18n.tr("Preset"); detail: I18n.tr("A starting point for the whole scene"); Seg { width: parent.width; options: ["soft", "cinematic", "beat"]; labels: ({ soft: I18n.tr("Soft"), cinematic: I18n.tr("Cinematic"), beat: I18n.tr("Beat") }); current: pg.motionPreset(); onChose: value => pg.applyMotionPreset(value) } }
                        ValueRow { label: I18n.tr("Amount"); detail: I18n.tr("How far the composition travels"); controlWidth: 260; Seg { width: parent.width; options: ["subtle", "normal", "strong"]; labels: ({ subtle: I18n.tr("Subtle"), normal: I18n.tr("Normal"), strong: I18n.tr("Strong") }); current: stageCfg.motion.amount || "normal"; onChose: value => pg.shellCall("stage-settings", "setAmount", value, I18n.tr("Saving motion amount")) } }
                        ValueRow { label: I18n.tr("Idle motion"); detail: I18n.tr("Movement while the pointer rests"); controlWidth: 300; Seg { width: parent.width; options: ["none", "float", "breathe", "sway"]; labels: ({ none: I18n.tr("Still"), float: I18n.tr("Float"), breathe: I18n.tr("Breathe"), sway: I18n.tr("Sway") }); current: stageCfg.motion.idle || "none"; onChose: value => pg.shellCall("stage-settings", "setIdle", value, I18n.tr("Saving idle motion")) } }
                        ValueRow { visible: pg.motionValue("idle", "none") !== "none"; label: I18n.tr("Idle speed"); detail: Math.round(pg.motionValue("speed", 1) * 100) + "%"; Slid { width: parent.width; value: pg.motionValue("speed", 1); from: 0.25; to: 2; onModified: value => pg.coalesce("stage.speed", "stage-settings", "setSpeed", value, I18n.tr("Saving idle speed")) } }
                        ValueRow { label: I18n.tr("React to music"); detail: I18n.tr("Near layers pulse with the beat"); controlWidth: 54; Sw { anchors.right: parent.right; on: stageCfg.motion.music === true; onToggled: value => pg.shellCall("stage-settings", "setMusic", value, I18n.tr("Saving music response")) } }
                        ValueRow { visible: pg.motionValue("music", false) === true; label: I18n.tr("Music intensity"); detail: Math.round(pg.motionValue("musicLevel", 0.6) * 100) + "%"; Slid { width: parent.width; value: pg.motionValue("musicLevel", 0.6); from: 0; to: 1; onModified: value => pg.coalesce("stage.musicLevel", "stage-settings", "setMusicLevel", value, I18n.tr("Saving music intensity")) } }
                        ValueRow { label: I18n.tr("Follow mouse"); detail: I18n.tr("Layers drift with the pointer"); controlWidth: 54; Sw { anchors.right: parent.right; on: stageCfg.motion.mouse !== false; onToggled: value => pg.shellCall("stage-settings", "setMouse", value, I18n.tr("Saving pointer motion")) } }
                    }
                    Sheet { visible: pg.effect === "parallax" && pg.motionValue("mouse", true) !== false; title: I18n.tr("POINTER")
                        Btn { text: pg.pointerDetails ? I18n.tr("Hide pointer controls") : I18n.tr("Fine-tune pointer"); compact: true; onAct: pg.pointerDetails = !pg.pointerDetails }
                        Column { visible: pg.pointerDetails; width: parent.width; spacing: Tokens.s3
                            ValueRow { label: I18n.tr("Sensitivity"); detail: Math.round(pg.motionValue("sensitivity", 1) * 100) + "%"; Slid { width: parent.width; value: pg.motionValue("sensitivity", 1); from: 0; to: 2; onModified: value => pg.coalesce("stage.sensitivity", "stage-settings", "setSensitivity", value, I18n.tr("Saving pointer sensitivity")) } }
                            ValueRow { label: I18n.tr("Range"); detail: Math.round(pg.motionValue("range", 1) * 100) + "%"; Slid { width: parent.width; value: pg.motionValue("range", 1); from: 0; to: 2; onModified: value => pg.coalesce("stage.range", "stage-settings", "setRange", value, I18n.tr("Saving pointer range")) } }
                            ValueRow { label: I18n.tr("Backdrop drift"); detail: Math.round(pg.motionValue("backdrop", 0) * 100) + "%"; Slid { width: parent.width; value: pg.motionValue("backdrop", 0); from: 0; to: 1; onModified: value => pg.coalesce("stage.backdrop", "stage-settings", "setBackdrop", value, I18n.tr("Saving backdrop drift")) } }
                        }
                    }
                    Sheet { title: I18n.tr("COMPOSITION")
                        Title { text: I18n.tr("Edit the whole desktop"); detail: I18n.tr("Place and style widgets against the real wallpaper, where overlap and scale are visible.") }
                        Btn { text: I18n.tr("Open widget editor"); primary: true; onAct: pg.launchEditor("widgets") }
                    }
                }
            }

            Grid {
                visible: pg.tab === "visualizer"; width: parent.width; columns: pg.twoColumns ? 2 : 1; columnSpacing: Tokens.s5; rowSpacing: Tokens.s5
                Column { width: pg.twoColumns ? (pageBody.width - Tokens.s5) / 2 : pageBody.width; spacing: Tokens.s4
                    Rectangle { width: parent.width; implicitHeight: 250; radius: Tokens.radius; color: vizCfg.enabled ? Tokens.bone : Tokens.tint5; border.width: Tokens.border; border.color: vizCfg.enabled ? Tokens.bone : Tokens.line
                        Column { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: Tokens.s5; spacing: Tokens.s2
                            Text { text: "graphic_eq"; color: vizCfg.enabled ? Tokens.inkOnBone : Tokens.inkDim; font.family: "Material Symbols Rounded"; font.pixelSize: 62 }
                            Text { width: parent.width; text: I18n.tr("Audio Visualizer"); color: vizCfg.enabled ? Tokens.inkOnBone : Tokens.ink; font.family: Tokens.display; font.pixelSize: Tokens.fHero }
                            Text { width: parent.width; text: I18n.tr("%1 · %2 fps · %3 visualizer").arg(vizCfg.style).arg(vizCfg.fps).arg(vizCfg.adaptive ? I18n.tr("adaptive") : I18n.tr("fixed")); color: vizCfg.enabled ? Qt.rgba(Tokens.inkOnBone.r, Tokens.inkOnBone.g, Tokens.inkOnBone.b, 0.72) : Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap }
                        }
                    }
                    ValueRow {
                        label: I18n.tr("Show visualizer")
                        detail: I18n.tr("Draw it on the desktop")
                        controlWidth: 54
                        Sw { anchors.right: parent.right; on: vizCfg.enabled; onToggled: value => pg.shellCall("visualizer", "setEnabled", value, I18n.tr("Saving visualizer state")) }
                    }
                    Sheet { title: I18n.tr("LOOK")
                        ValueRow {
                            label: I18n.tr("Style")
                            detail: vizCfg.style
                            Row {
                                width: parent.width
                                spacing: Tokens.s2
                                Btn { text: I18n.tr("Previous"); compact: true; onAct: pg.shellCall("visualizer", "cycleStyle", -1, I18n.tr("Changing visualizer style")) }
                                Btn { text: I18n.tr("Next"); compact: true; onAct: pg.shellCall("visualizer", "cycleStyle", 1, I18n.tr("Changing visualizer style")) }
                            }
                        }
                        ValueRow { label: I18n.tr("Depth"); detail: I18n.tr("Relative to wallpaper cut-outs"); Seg { width: parent.width; options: ["behind", "front"]; labels: ({ behind: I18n.tr("Behind"), front: I18n.tr("In front") }); current: (stageCfg.front || []).indexOf("visualizer") >= 0 ? "front" : "behind"; onChose: value => pg.shellCall("stage-settings", "setVisualizerFront", value === "front", I18n.tr("Saving visualizer depth")) } }
                    }
                }
                Column { width: pg.twoColumns ? (pageBody.width - Tokens.s5) / 2 : pageBody.width; spacing: Tokens.s4
                    Sheet { title: I18n.tr("PERFORMANCE & RESPONSE")
                        ValueRow { label: I18n.tr("Frame rate"); detail: I18n.tr("Target while the desktop is active"); Seg { width: parent.width; options: ["30", "45", "60"]; current: String(vizCfg.fps); onChose: value => pg.shellCall("visualizer", "setFps", Number(value), I18n.tr("Saving frame rate")) } }
                        ValueRow { label: I18n.tr("Adaptive quality"); detail: I18n.tr("Lower load when the desktop is busy"); controlWidth: 54; Sw { anchors.right: parent.right; on: vizCfg.adaptive; onToggled: value => pg.shellCall("visualizer", "setAdaptive", value, I18n.tr("Saving adaptive quality")) } }
                        ValueRow { label: I18n.tr("Gain"); detail: Math.round(vizCfg.gain * 100) + "%"; Slid { width: parent.width; value: vizCfg.gain; from: 0.5; to: 2; onModified: value => pg.coalesce("visualizer.gain", "visualizer", "setGain", value, I18n.tr("Saving visualizer gain")) } }
                        ValueRow { label: I18n.tr("Smoothing"); detail: Math.round(vizCfg.smoothing * 100) + "%"; Slid { width: parent.width; value: vizCfg.smoothing; from: 0; to: 1; onModified: value => pg.coalesce("visualizer.smoothing", "visualizer", "setSmoothing", value, I18n.tr("Saving visualizer smoothing")) } }
                    }
                    Sheet { title: I18n.tr("PLACEMENT")
                        Title { text: I18n.tr("Place it on the desktop"); detail: I18n.tr("Drag, resize, rotate, colour, duplicate, and tune the selected look against the real wallpaper.") }
                        Btn { text: I18n.tr("Open visualizer editor"); primary: true; onAct: pg.launchEditor("visualizer") }
                    }
                }
            }

            Column {
                visible: pg.tab === "widgets"; width: Math.min(parent.width, 780); anchors.horizontalCenter: parent.horizontalCenter; spacing: Tokens.s5
                Rectangle { width: parent.width; implicitHeight: widgetHero.implicitHeight + Tokens.s6 * 2; radius: Tokens.radius; color: Tokens.bone
                    Column { id: widgetHero; anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Tokens.s6; spacing: Tokens.s4
                        Text { text: "dashboard_customize"; color: Tokens.inkOnBone; font.family: "Material Symbols Rounded"; font.pixelSize: 68 }
                        Text { width: parent.width; text: I18n.tr("Edit the desktop where it lives"); color: Tokens.inkOnBone; font.family: Tokens.display; font.pixelSize: Tokens.fTitle; wrapMode: Text.WordWrap }
                        Text { width: parent.width; text: I18n.tr("The editor opens over the wallpaper so placement, overlap, depth, scale, colour, locking, and plugin widgets stay honest. Ryoku Settings closes after the hand-off."); color: Qt.rgba(Tokens.inkOnBone.r, Tokens.inkOnBone.g, Tokens.inkOnBone.b, 0.76); font.family: Tokens.ui; font.pixelSize: Tokens.fBody; wrapMode: Text.WordWrap }
                    }
                }
                Btn { text: I18n.tr("Open desktop widget editor"); primary: true; onAct: pg.launchEditor("widgets") }
            }

            Rectangle {
                visible: pg.error !== "" || pg.commandBusy || installProc.running || launchProc.running
                width: parent.width; implicitHeight: statusText.implicitHeight + Tokens.s3 * 2; radius: Tokens.radius
                color: pg.error !== "" ? Qt.rgba(Tokens.alert.r, Tokens.alert.g, Tokens.alert.b, 0.08) : Tokens.tint5
                border.width: Tokens.border; border.color: pg.error !== "" ? Tokens.alert : Tokens.line
                Text { id: statusText; anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.margins: Tokens.s3; text: pg.error !== "" ? pg.error : installProc.running ? I18n.tr("Downloading the cut model…") : launchProc.running ? I18n.tr("Opening the desktop editor…") : pg.commandLabel; color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap }
            }
        }
    }

    FileDialog { id: cutDialog; title: I18n.tr("Cut a layer from a picture"); nameFilters: [I18n.tr("Pictures (*.png *.jpg *.jpeg *.webp *.bmp)"), I18n.tr("All files (*)")]; onAccepted: pg.pickedCut = String(selectedFile) }
    FileDialog { id: pngDialog; title: I18n.tr("Add a PNG layer"); nameFilters: [I18n.tr("PNG images (*.png)"), I18n.tr("All files (*)")]; onAccepted: pg.stageCall("add-layer", pg.pathFromUrl(selectedFile)) }
}
