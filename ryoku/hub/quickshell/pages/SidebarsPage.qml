pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import Ryoku.FrameBars as FrameModels
import "../schema/SidebarsPage.js" as Sidebars

Item {
    id: pg

    property var hub
    property string side: "left"
    property var plugins: []
    property var pluginQueue: []
    property var pluginAfter: null
    property string pluginError: ""
    readonly property bool pluginBusy: pluginProc.running || pluginQueue.length > 0
    readonly property bool busy: (writer && writer.busy) || pg.pluginBusy
    readonly property string error: writer && writer.error !== "" ? writer.error : pg.pluginError
    readonly property var config: writer ? writer.confirmed : null
    readonly property var current: pg.config && pg.config[pg.side] ? pg.config[pg.side] : null
    readonly property string sideName: pg.side === "left" ? I18n.tr("Controls") : I18n.tr("Companion")
    readonly property string otherName: pg.side === "left" ? I18n.tr("Companion") : I18n.tr("Controls")
    readonly property bool ready: pg.current !== null
    readonly property bool twoColumns: width >= 700

    function focusKey(key) {
        if (String(key).indexOf("sidebars.right") === 0) pg.side = "right";
        else if (String(key).indexOf("sidebars.left") === 0) pg.side = "left";
    }
    function clone(value) { return JSON.parse(JSON.stringify(value)); }
    function otherSide() { return pg.side === "left" ? "right" : "left"; }
    function pluginOf(id) {
        for (var i = 0; i < pg.plugins.length; ++i) if (pg.plugins[i].id === id) return pg.plugins[i];
        return null;
    }
    function entry(id) {
        var builtin = Sidebars.builtIn(id);
        if (builtin) return { id: id, label: I18n.tr(builtin.label), glyph: builtin.glyph, plugin: false };
        var p = pg.pluginOf(id);
        return { id: id, label: p ? p.label : id, glyph: p ? p.glyph : "extension", plugin: p !== null };
    }
    function selectedEntries() {
        if (!pg.current) return [];
        var cards = pg.current.cards || [], out = [], seen = ({});
        for (var i = 0; i < cards.length; ++i) { out.push(pg.entry(cards[i])); seen[cards[i]] = true; }
        for (var j = 0; j < pg.plugins.length; ++j) {
            var p = pg.plugins[j];
            if (!seen[p.id] && p.enabled && p.side === pg.side) out.push(pg.entry(p.id));
        }
        return out;
    }
    function availableEntries() {
        if (!pg.current) return [];
        var cards = pg.current.cards || [], out = [];
        for (var i = 0; i < Sidebars.builtIns.length; ++i)
            if (cards.indexOf(Sidebars.builtIns[i].id) < 0) out.push(pg.entry(Sidebars.builtIns[i].id));
        for (var j = 0; j < pg.plugins.length; ++j) {
            var p = pg.plugins[j];
            if (cards.indexOf(p.id) < 0 && (!p.enabled || p.side !== pg.side)) out.push(pg.entry(p.id));
        }
        return out;
    }
    function patch(path, value) { if (!pg.busy) writer.patch(path, value); }
    function patchAll(value) { if (!pg.busy) writer.patchAll(value); }
    function setCards(cards) { pg.patch("cards", cards); }
    function placeConfigured(id, target) {
        var all = FrameModels.Sidebars.normalize(pg.config), mode;
        for (var i = 0; i < 2; ++i) {
            var name = i === 0 ? "left" : "right", at = all[name].cards.indexOf(id);
            if (at >= 0) all[name].cards.splice(at, 1);
            if (all[name].presentations[id] !== undefined) mode = all[name].presentations[id];
            delete all[name].presentations[id];
        }
        all[target].cards.push(id);
        if (mode !== undefined) all[target].presentations[id] = mode;
        pg.patchAll(all);
    }
    function removeConfigured(id) {
        var all = FrameModels.Sidebars.normalize(pg.config);
        for (var i = 0; i < 2; ++i) {
            var name = i === 0 ? "left" : "right", at = all[name].cards.indexOf(id);
            if (at >= 0) all[name].cards.splice(at, 1);
            delete all[name].presentations[id];
        }
        pg.patchAll(all);
    }
    function add(id, plugin) {
        if (plugin) {
            var p = pg.pluginOf(id);
            pg.runPlugins([[id, "enabled", "true"], [id, "sidebarCard", pg.side, p ? p.tab : "Plugins", String(p ? p.order : 10)]], { kind: "place", id: id, side: pg.side });
        } else {
            var cards = pg.current.cards.slice();
            if (cards.indexOf(id) < 0) cards.push(id);
            pg.setCards(cards);
        }
    }
    function remove(id, plugin) {
        if (plugin) pg.runPlugins([[id, "enabled", "false"]], { kind: "remove", id: id });
        else {
            var cards = pg.current.cards.slice(), at = cards.indexOf(id);
            if (at >= 0) cards.splice(at, 1);
            pg.setCards(cards);
        }
    }
    function reorder(id, delta) {
        var cards = pg.current.cards.slice(), at = cards.indexOf(id), next = at + delta;
        if (at < 0 || next < 0 || next >= cards.length) return;
        var value = cards.splice(at, 1)[0];
        cards.splice(next, 0, value);
        pg.setCards(cards);
    }
    function reorderPlugin(id, delta) {
        var entries = pg.selectedEntries().filter(function(value) { return value.plugin; });
        var at = -1;
        for (var i = 0; i < entries.length; ++i)
            if (entries[i].id === id) { at = i; break; }
        var next = at + delta;
        if (at < 0 || next < 0 || next >= entries.length) return;
        var value = entries.splice(at, 1)[0];
        entries.splice(next, 0, value);
        var commands = [];
        for (var j = 0; j < entries.length; ++j) {
            var p = pg.pluginOf(entries[j].id);
            commands.push([entries[j].id, "sidebarCard", pg.side, p ? p.tab : "Plugins", String((j + 1) * 10)]);
        }
        pg.runPlugins(commands, null);
    }
    function reorderEntry(id, plugin, delta) {
        if (plugin && pg.current.cards.indexOf(id) < 0) pg.reorderPlugin(id, delta);
        else pg.reorder(id, delta);
    }
    function move(id, plugin) {
        if (plugin) {
            var p = pg.pluginOf(id), target = pg.otherSide();
            pg.runPlugins([[id, "sidebarCard", target, p ? p.tab : "Plugins", String(p ? p.order : 10)]], { kind: "place", id: id, side: target });
        } else pg.placeConfigured(id, pg.otherSide());
    }
    function setPresentation(id, value) {
        var map = pg.clone(pg.current.presentations || ({}));
        map[id] = value;
        pg.patch("presentations", map);
    }
    function preset(name) {
        var values = { compact: [720, 720], roomy: [1280, 1100] };
        if (!values[name]) return;
        var all = FrameModels.Sidebars.normalize(pg.config);
        all[pg.side].width = values[name][0];
        all[pg.side].height = values[name][1];
        all[pg.side].heightMode = "fixed";
        pg.patchAll(all);
    }
    function presetName() {
        if (!pg.current || pg.current.heightMode !== "fixed") return "custom";
        if (pg.current.width === 720 && pg.current.height === 720) return "compact";
        if (pg.current.width === 1280 && pg.current.height === 1100) return "roomy";
        return "custom";
    }
    function runPlugins(commands, after) {
        if (pg.busy || !commands.length) return;
        pg.pluginError = "";
        pg.pluginQueue = commands.slice();
        pg.pluginAfter = after || null;
        pg.runNextPlugin();
    }
    function runNextPlugin() {
        if (!pg.pluginQueue.length) {
            var after = pg.pluginAfter;
            pg.pluginAfter = null;
            if (after && after.kind === "place") pg.placeConfigured(after.id, after.side);
            else if (after && after.kind === "remove") pg.removeConfigured(after.id);
            discover.running = false; discover.running = true;
            return;
        }
        pluginProc.command = ["ryoku-plugins-place"].concat(pg.pluginQueue[0]);
        pluginProc.running = true;
    }
    function syncPlugins(value) {
        var out = [];
        for (var i = 0; i < value.length; ++i) {
            var p = value[i], placement = p && p.placement ? p.placement : ({});
            var manifest = p.manifest || ({}), hosts = Array.isArray(manifest.hosts) ? manifest.hosts : [];
            if (hosts.indexOf("sidebarCard") < 0 && placement.host !== "sidebarCard") continue;
            var card = placement.sidebarCard || ({}), defs = manifest.defaults || ({}), sideDefs = defs.sidebar || ({});
            var active = placement.enabled === true && placement.host === "sidebarCard";
            out.push({ id: p.id, label: card.label || defs.label || manifest.name || p.id, glyph: card.glyph || defs.glyph || defs.icon || "extension",
                enabled: active, side: (card.side || sideDefs.side) === "right" ? "right" : "left",
                tab: card.tab || sideDefs.tab || "Plugins", order: isFinite(Number(card.order !== undefined ? card.order : sideDefs.order)) ? Number(card.order !== undefined ? card.order : sideDefs.order) : 10 });
        }
        out.sort(function(a, b) { return a.order === b.order ? a.id.localeCompare(b.id) : a.order - b.order; });
        pg.plugins = out;
    }

    readonly property var writer: writerLoader.item
    Loader {
        id: writerLoader
        active: true
        source: Qt.resolvedUrl("SidebarWriter.qml")
        onLoaded: item.side = Qt.binding(function() { return pg.side; })
    }

    readonly property string shellDir: Quickshell.env("RYOKU_SHELL_DIR")
    readonly property string discoverScript: pg.shellDir !== "" ? pg.shellDir + "/quickshell/plugins/discover.sh"
        : (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/plugins/discover.sh"
    Process {
        id: discover
        command: ["bash", pg.discoverScript, "--all"]
        running: true
        stdout: StdioCollector { onStreamFinished: {
            var value = [];
            try { value = JSON.parse(text || "[]"); } catch (e) { value = []; }
            pg.syncPlugins(Array.isArray(value) ? value : []);
        } }
    }
    Process {
        id: pluginProc
        stderr: StdioCollector { id: pluginStderr }
        onExited: code => {
            if (code !== 0) {
                pg.pluginError = pluginStderr.text.trim() || I18n.tr("The plugin placement was not saved.");
                pg.pluginQueue = [];
                pg.pluginAfter = null;
                return;
            }
            pg.pluginQueue = pg.pluginQueue.slice(1);
            pg.runNextPlugin();
        }
    }
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/plugins.json"
        watchChanges: true
        printErrors: false
        onFileChanged: { discover.running = false; discover.running = true; }
    }

    component Copy: Column {
        property string title: ""
        property string detail: ""
        width: parent.width
        spacing: Tokens.s1
        Text { width: parent.width; text: parent.title; color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fRow; font.weight: Font.DemiBold; wrapMode: Text.WordWrap }
        Text { visible: text !== ""; width: parent.width; text: parent.detail; color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap }
    }
    component Metric: Item {
        id: metric
        property string label: ""
        property string detail: ""
        property int value: 0
        property int low: 0
        property int high: 100
        property int step: 20
        signal changed(int value)
        implicitHeight: Math.max(64, metricCopy.implicitHeight, metricControls.implicitHeight)
        Column {
            id: metricCopy
            anchors.left: parent.left; anchors.right: metricControls.left; anchors.rightMargin: Tokens.s4; anchors.verticalCenter: parent.verticalCenter
            Text { width: parent.width; text: metric.label; color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fRow; wrapMode: Text.WordWrap }
            Text { width: parent.width; text: metric.detail; color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap }
        }
        Row {
            id: metricControls
            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Tokens.s1
            Btn { text: "−"; compact: true; armed: !pg.busy && metric.value > metric.low; onAct: metric.changed(Math.max(metric.low, metric.value - metric.step)) }
            QQC.TextField {
                id: input
                width: 76; height: 40; text: String(metric.value); selectByMouse: true
                color: Tokens.ink; font.family: Tokens.mono; font.pixelSize: Tokens.fRow; horizontalAlignment: TextInput.AlignHCenter
                validator: IntValidator { bottom: metric.low; top: metric.high }
                Binding { target: input; property: "text"; value: String(metric.value); when: !input.activeFocus }
                onAccepted: focus = false
                onEditingFinished: { var n = Math.round(Number(text)); if (acceptableInput && isFinite(n) && n !== metric.value) metric.changed(n); }
                background: Rectangle { radius: Tokens.radius; color: Tokens.tint5; border.width: Tokens.border; border.color: input.activeFocus ? Tokens.bone : Tokens.line }
            }
            Btn { text: "+"; compact: true; armed: !pg.busy && metric.value < metric.high; onAct: metric.changed(Math.min(metric.high, metric.value + metric.step)) }
        }
    }
    component SectionCard: Rectangle {
        id: card
        required property var entryData
        required property int rowIndex
        readonly property string presentation: pg.current && pg.current.presentations[entryData.id] ? pg.current.presentations[entryData.id] : "expanded"
        width: parent.width
        implicitHeight: content.implicitHeight + Tokens.s4 * 2
        radius: Tokens.radius
        color: Tokens.paperLift
        border.width: Tokens.border
        border.color: Tokens.line
        Column {
            id: content
            anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Tokens.s4
            spacing: Tokens.s3
            Item {
                width: parent.width; implicitHeight: Math.max(nameRow.implicitHeight, reorderRow.implicitHeight)
                Row {
                    id: nameRow
                    anchors.left: parent.left; anchors.right: reorderRow.left; anchors.rightMargin: Tokens.s2; anchors.verticalCenter: parent.verticalCenter; spacing: Tokens.s2
                    Text { text: card.entryData.glyph; color: Tokens.inkDim; font.family: "Material Symbols Rounded"; font.pixelSize: 23 }
                    Text { id: sectionName; width: Math.max(0, nameRow.width - 34); text: card.entryData.label; color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fRow; font.weight: Font.DemiBold; elide: Text.ElideRight
                        HoverHandler { id: sectionNameHover }
                        QQC.ToolTip.visible: sectionNameHover.hovered && sectionName.truncated
                        QQC.ToolTip.text: sectionName.text
                    }
                }
                Row {
                    id: reorderRow
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; spacing: Tokens.s1
                    Btn { text: "↑"; compact: true; armed: !pg.busy && card.rowIndex > 0; Accessible.name: I18n.tr("Move up"); onAct: pg.reorderEntry(card.entryData.id, card.entryData.plugin, -1) }
                    Btn { text: "↓"; compact: true; armed: !pg.busy && card.rowIndex < pg.selectedEntries().length - 1; Accessible.name: I18n.tr("Move down"); onAct: pg.reorderEntry(card.entryData.id, card.entryData.plugin, 1) }
                    Btn { text: "×"; compact: true; armed: !pg.busy; Accessible.name: I18n.tr("Hide section"); onAct: pg.remove(card.entryData.id, card.entryData.plugin) }
                }
            }
            Flow {
                width: parent.width; spacing: Tokens.s2
                Seg { options: ["summary", "expanded"]; labels: ({ summary: I18n.tr("Summary"), expanded: I18n.tr("Full controls") }); current: card.presentation; onChose: value => pg.setPresentation(card.entryData.id, value) }
                Btn { text: I18n.tr("Move to %1").arg(pg.otherName); armed: !pg.busy; onAct: pg.move(card.entryData.id, card.entryData.plugin) }
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
        Text { text: I18n.tr("Sidebars"); color: Tokens.ink; font.family: Tokens.display; font.pixelSize: Tokens.fTitle }
        Text { width: Math.min(parent.width, 720); text: I18n.tr("Shape what each edge carries, then decide how much room it gets."); color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fBody; wrapMode: Text.WordWrap }
        Seg { options: ["left", "right"]; labels: ({ left: I18n.tr("Controls"), right: I18n.tr("Companion") }); current: pg.side; onChose: value => pg.side = value }
    }

    Flickable {
        anchors.left: parent.left; anchors.right: parent.right; anchors.top: head.bottom; anchors.bottom: parent.bottom
        anchors.leftMargin: Tokens.s6; anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s5
        contentWidth: width; contentHeight: body.implicitHeight + Tokens.s6; clip: true; boundsBehavior: Flickable.StopAtBounds
        QQC.ScrollBar.vertical: ScrollRail { policy: QQC.ScrollBar.AsNeeded }
        WheelScroll {}

        Column {
            id: body
            width: parent.width - Tokens.s2
            spacing: Tokens.s5

            Rectangle {
                width: parent.width; implicitHeight: summary.implicitHeight + Tokens.s4 * 2
                radius: Tokens.radius; color: Tokens.tint5; border.width: Tokens.border; border.color: Tokens.line
                Row {
                    id: summary
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top; anchors.margins: Tokens.s4; spacing: Tokens.s4
                    Text { text: pg.side === "left" ? "west" : "east"; color: Tokens.bone; font.family: "Material Symbols Rounded"; font.pixelSize: 36; anchors.verticalCenter: parent.verticalCenter }
                    Column { width: parent.width - enabledSwitch.width - 64; spacing: Tokens.s1
                        Text { width: parent.width; text: pg.sideName; color: Tokens.ink; font.family: Tokens.display; font.pixelSize: Tokens.fHero; elide: Text.ElideRight }
                        Text { width: parent.width; text: pg.ready ? I18n.tr("%1 sections · %2 × %3").arg(pg.selectedEntries().length).arg(pg.current.width).arg(pg.current.height) : I18n.tr("Waiting for the desktop service…"); color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap }
                    }
                    Sw { id: enabledSwitch; anchors.verticalCenter: parent.verticalCenter; on: pg.ready && pg.current.enabled; enabled: pg.ready && !pg.busy; onToggled: value => pg.patch("enabled", value) }
                }
            }

            Grid {
                width: parent.width; columns: pg.twoColumns ? 2 : 1; columnSpacing: Tokens.s5; rowSpacing: Tokens.s5
                Column {
                    width: pg.twoColumns ? (body.width - Tokens.s5) / 2 : body.width; spacing: Tokens.s4
                    Copy { title: I18n.tr("Visible sections"); detail: I18n.tr("Order the cards, choose summary or full controls, or send a card across the screen.") }
                    Repeater { model: pg.selectedEntries(); delegate: SectionCard { required property var modelData; required property int index; entryData: modelData; rowIndex: index } }
                    Text { visible: pg.ready && pg.selectedEntries().length === 0; width: parent.width; text: I18n.tr("This edge is empty. Add a section below to make it useful."); color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fBody; wrapMode: Text.WordWrap }
                    Copy { visible: pg.availableEntries().length > 0; title: I18n.tr("Add a section"); detail: I18n.tr("Built-ins and installed sidebar plugins appear together.") }
                    Flow {
                        width: parent.width; spacing: Tokens.s2
                        Repeater { model: pg.availableEntries(); delegate: Btn { required property var modelData; text: "+  " + modelData.label; armed: !pg.busy; onAct: pg.add(modelData.id, modelData.plugin) } }
                    }
                }

                Column {
                    width: pg.twoColumns ? (body.width - Tokens.s5) / 2 : body.width; spacing: Tokens.s4
                    Copy { title: I18n.tr("Frame"); detail: I18n.tr("Use a preset as a starting point, or tune the exact logical size.") }
                    Flow { width: parent.width; spacing: Tokens.s2
                        Btn { text: I18n.tr("Compact"); primary: pg.presetName() === "compact"; armed: pg.ready && !pg.busy; onAct: pg.preset("compact") }
                        Btn { text: I18n.tr("Roomy"); primary: pg.presetName() === "roomy"; armed: pg.ready && !pg.busy; onAct: pg.preset("roomy") }
                    }
                    Metric { width: parent.width; label: I18n.tr("Width"); detail: I18n.tr("Logical pixels"); value: pg.ready ? pg.current.width : 0; low: pg.side === "left" ? 300 : 380; high: 1440; onChanged: value => pg.patch("width", value) }
                    Item { width: parent.width; implicitHeight: 58
                        Copy { anchors.left: parent.left; anchors.right: heightMode.left; anchors.rightMargin: Tokens.s4; anchors.verticalCenter: parent.verticalCenter; title: I18n.tr("Panel height"); detail: I18n.tr("Fit the current section or hold a steady frame.") }
                        Seg { id: heightMode; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; options: ["fit", "fixed"]; labels: ({ fit: I18n.tr("Fit content"), fixed: I18n.tr("Fixed") }); current: pg.ready ? pg.current.heightMode : "fixed"; onChose: value => pg.patch("heightMode", value) }
                    }
                    Metric { visible: pg.ready && pg.current.heightMode === "fixed"; width: parent.width; label: I18n.tr("Height"); detail: I18n.tr("Logical pixels"); value: pg.ready ? pg.current.height : 0; low: 260; high: 1200; onChanged: value => pg.patch("height", value) }
                    Metric { width: parent.width; label: I18n.tr("Screen limit"); detail: I18n.tr("Maximum percent of display height"); value: pg.ready ? pg.current.maxHeight : 0; low: 40; high: 95; step: 5; onChanged: value => pg.patch("maxHeight", value) }
                    Rectangle { width: parent.width; height: Tokens.border; color: Tokens.line }
                    Copy { title: I18n.tr("Opening"); detail: I18n.tr("Alignment belongs to this edge. Tempo is shared by both sidebars.") }
                    Seg { options: ["top", "center", "bottom"]; labels: ({ top: I18n.tr("Top"), center: I18n.tr("Center"), bottom: I18n.tr("Bottom") }); current: pg.ready ? pg.current.position : "center"; onChose: value => pg.patch("position", value) }
                    SettingRow { width: parent.width; label: I18n.tr("Keep open"); desc: I18n.tr("Stay visible when focus moves away."); controlWidth: 54; Sw { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; on: pg.ready && pg.current.pinned; enabled: pg.ready && !pg.busy; onToggled: value => pg.patch("pinned", value) } }
                    SettingRow { width: parent.width; label: I18n.tr("Opening motion"); desc: I18n.tr("Reduced motion still takes priority."); controlWidth: 270; Seg { anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; options: ["quick", "standard", "calm"]; labels: ({ quick: I18n.tr("Quick"), standard: I18n.tr("Standard"), calm: I18n.tr("Calm") }); current: pg.config ? pg.config.motion : "standard"; onChose: value => pg.patch("sidebars.motion", value) } }
                }
            }

            Rectangle {
                visible: pg.busy || pg.error !== ""; width: parent.width; implicitHeight: status.implicitHeight + Tokens.s3 * 2
                radius: Tokens.radius; color: pg.error !== "" ? Qt.rgba(Tokens.alert.r, Tokens.alert.g, Tokens.alert.b, 0.08) : Tokens.tint5
                border.width: Tokens.border; border.color: pg.error !== "" ? Tokens.alert : Tokens.line
                Text { id: status; anchors.left: parent.left; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; anchors.margins: Tokens.s3; text: pg.error !== "" ? pg.error : I18n.tr("Saving changes…"); color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap }
            }
        }
    }
}
