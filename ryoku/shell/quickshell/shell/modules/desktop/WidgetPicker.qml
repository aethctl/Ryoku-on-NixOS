pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import "Singletons"
import "../../components"
import Ryoku.Ui
import Ryoku.Ui.Singletons

// The Widgets picker: an attached panel that grows out of the Edit widgets bar,
// listing the whole roster as one row per widget. It replaces the bar's old
// horizontal chip rail, which read as a cramped filmstrip you had to scrub. Same
// paper-and-ink surface as the bar; the host hands it the free work area above the
// bar (maxWidth / maxPanelHeight) and it scrolls when the roster overflows, so a
// name or hint never truncates.
//
// Rows keep the roster's own contiguous grouping: the built-ins as "Ryoku
// widgets", the vendored faces as "iRiS widgets", each plugin set under its own
// caption. A search field filters as you type; the wheel scrolls the list; and a
// keyboard highlight moves with Up/Down, Space toggles it, Esc closes -- keyboard
// the host grants by taking focus on click (WlrKeyboardFocus.OnDemand). The list
// is a Repeater, not a virtualised view, so the panel sizes to real content.
Rectangle {
    id: panel

    // The flat roster from Desktop.addItems: [{ id, label, icon, enabled, group }].
    property var items: []
    // Geometry the host allows: the free work area above the bar.
    property real maxWidth: 460
    property real maxPanelHeight: 600

    signal toggle(string id)
    signal requestClose()
    // Open the widget inspector (Customize sheet) for an enabled row.
    signal customize(string id)

    // Short descriptions under each name. The labels and icons live in the roster;
    // these one-line hints are presentation copy, so they live with the surface
    // that shows them, keyed by widget id (a built-in id or an iRiS prefix). A
    // plugin carries none, so its row is glyph + name + switch, nothing missing.
    readonly property var hints: ({
        "clock": "Time and date on the wallpaper",
        "calendar": "A month at a glance",
        "music": "Now playing, with controls",
        "aio": "Time, weather and media together",
        "stats": "Live CPU, memory and network",
        "weather": "Local conditions and forecast",
        "notes": "A quick scratch pad",
        "dayprogress": "How much of the day is left",
        "shape": "A plain decorative accent",
        "visualizer": "Audio spectrum on the desktop",
        "irisClock": "A clea Shima clock face",
        "irisWeather": "A Shima weather face",
        "irisMedia": "A Shima now-playing face",
        "irisControls": "Quick toggles as a face",
        "irisMonth": "A full month calendar",
        "irisAgenda": "Your next few events",
        "irisTodo": "Tasks and checklists",
        "irisNotes": "Shima sticky notes",
        "irisTimers": "Countdowns and a stopwatch",
        "irisScreen": "Time spent on screen today",
        "irisVitals": "CPU, memory and temperatures",
        "irisBattery": "Battery levels at a glance",
        "irisWorld": "Clocks around the world",
        "irisDate": "Just today's date",
        "irisProfile": "Your profile card",
        "irisUptime": "Time since last boot",
        "irisNews": "Scrolling headlines",
        "irisCustomImage": "A picture of your own",
        "irisEditorial": "A magazine-style headline",
        "irisConverter": "Convert image formats",
        "irisJp": "Vertical Japanese type",
        "irisVisualizer": "A Shima audio spectrum"
    })

    // The live on/off for an id, read from `items` rather than a row's snapshot so
    // a toggle re-tints its row (and flips its switch) without rebuilding the list.
    function isOn(id) {
        const it = panel.items || [];
        for (var i = 0; i < it.length; i++)
            if (it[i].id === id)
                return it[i].enabled === true;
        return false;
    }
    function hintFor(id) { return panel.hints[id] || ""; }
    // The section caption for a roster group: the built-ins read as Ryoku's own,
    // every other group keeps its roster caption (the iRiS set, a plugin set).
    function captionFor(g) { return g === "" ? "Ryoku widgets" : g; }
    function glossFor(g) { return g === "" ? "\u90e8\u54c1" : ""; }

    // Build the display list from the roster and the query: a header whenever the
    // group changes, then one row per matching widget. The roster is already
    // grouped contiguously, so a change of group is a new section.
    function buildRows(src, q) {
        const ql = (q || "").trim().toLowerCase();
        const out = [];
        var group = null;
        var opened = false;
        for (var i = 0; i < src.length; i++) {
            const e = src[i];
            const name = I18n.tr(e.label || e.id);
            if (ql.length > 0) {
                const hay = (name + " " + (e.id || "") + " " + panel.hintFor(e.id)).toLowerCase();
                if (hay.indexOf(ql) < 0)
                    continue;
            }
            const g = e.group || "";
            if (!opened || g !== group) {
                group = g;
                opened = true;
                out.push({ header: true, group: g });
            }
            out.push({ header: false, entry: e });
        }
        return out;
    }

    // The display list is recomputed on any roster or query change, but the array
    // reference only swaps when its *shape* changes (a widget added/removed, the
    // query narrowing the set). A plain on/off toggle leaves the shape untouched,
    // so the Repeater keeps its delegates, the scroll position and the highlight.
    property var _rows: []
    property string _sig: ""
    function recompute() {
        const r = panel.buildRows(panel.items || [], panel.query);
        var sig = "";
        for (var i = 0; i < r.length; i++)
            sig += (r[i].header ? "H:" + r[i].group : r[i].entry.id) + "|";
        if (sig !== panel._sig) {
            panel._sig = sig;
            panel._rows = r;
        }
    }
    readonly property var rows: panel._rows
    // The row indices that are selectable, so the keyboard highlight skips headers.
    readonly property var navIndices: {
        const a = [];
        for (var i = 0; i < panel._rows.length; i++)
            if (!panel._rows[i].header)
                a.push(i);
        return a;
    }
    property int curNav: -1
    readonly property int curModelIndex: (panel.curNav >= 0 && panel.curNav < panel.navIndices.length)
        ? panel.navIndices[panel.curNav] : -1

    property string query: ""
    onQueryChanged: {
        panel.recompute();
        panel.curNav = -1;
        list.contentY = 0;
    }
    onItemsChanged: panel.recompute()
    Component.onCompleted: panel.recompute()

    function toggleCurrent() {
        const idx = panel.curModelIndex;
        if (idx >= 0 && !panel._rows[idx].header)
            panel.toggle(panel._rows[idx].entry.id);
    }
    // Keep the highlighted row inside the viewport when the keyboard moves it.
    function keepVisible() {
        if (panel.curModelIndex < 0)
            return;
        const it = rep.itemAt(panel.curModelIndex);
        if (!it)
            return;
        if (it.y < list.contentY)
            list.contentY = it.y;
        else if (it.y + it.height > list.contentY + list.height)
            list.contentY = it.y + it.height - list.height;
    }
    // Focus the search field for a fresh session whenever the panel appears.
    onVisibleChanged: {
        if (panel.visible) {
            search.text = "";
            panel.curNav = -1;
            list.contentY = 0;
            search.forceActiveFocus();
        }
    }

    readonly property int pad: Theme.s3
    readonly property int searchH: 34

    width: Math.min(460, panel.maxWidth)
    // An empty result still needs room for the "no match" line, so the body floors
    // at one row's height when nothing is listed.
    readonly property real bodyHeight: panel.navIndices.length === 0 ? Theme.s7 : col.height
    height: Math.min(panel.pad + panel.searchH + Theme.s2 + panel.bodyHeight + panel.pad, panel.maxPanelHeight)
    radius: Theme.menuRadius
    color: Theme.surface
    border.width: 1
    border.color: Theme.line

    // ── search: filters as you type; Down drops into the list, Esc closes ──
    Rectangle {
        id: searchBox
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: panel.pad }
        height: panel.searchH
        radius: Theme.menuTileRadius
        color: "transparent"
        border.width: search.activeFocus ? 2 : 1
        border.color: search.activeFocus ? Theme.ink : (searchHover.hovered ? Theme.lineStrong : Theme.line)
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }

        HoverHandler { id: searchHover; cursorShape: Qt.IBeamCursor }

        MaterialIcon {
            id: sIcon
            anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
            text: "search"
            font.pixelSize: 18
            color: search.activeFocus ? Theme.ink : Theme.inkDim
        }
        TextInput {
            id: search
            anchors {
                left: sIcon.right; leftMargin: Theme.s2
                right: clearBtn.visible ? clearBtn.left : parent.right; rightMargin: Theme.s2
                verticalCenter: parent.verticalCenter
            }
            verticalAlignment: Text.AlignVCenter
            color: Theme.ink
            font.family: Theme.font
            font.pixelSize: Theme.fSmall
            selectByMouse: true
            clip: true
            onTextChanged: panel.query = text
            Keys.onDownPressed: e => {
                if (panel.navIndices.length > 0) {
                    panel.curNav = 0;
                    list.forceActiveFocus();
                    panel.keepVisible();
                }
                e.accepted = true;
            }
            Keys.onEscapePressed: e => { panel.requestClose(); e.accepted = true; }

            Text {
                anchors.fill: parent
                visible: search.text === ""
                text: I18n.tr("Search widgets")
                color: Theme.inkDim
                font: search.font
                verticalAlignment: Text.AlignVCenter
                elide: Text.ElideRight
            }
        }
        // A quiet clear affordance so the mouse-only path can reset the filter.
        MaterialIcon {
            id: clearBtn
            visible: search.text.length > 0
            anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
            text: "close"
            font.pixelSize: 16
            color: clearMa.containsMouse ? Theme.ink : Theme.inkDim
            MouseArea {
                id: clearMa
                anchors.fill: parent
                anchors.margins: -Theme.s1
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: { search.text = ""; search.forceActiveFocus(); }
            }
        }
    }

    // ── the roster list: natural vertical scroll, no arrow buttons ──
    Flickable {
        id: list
        anchors {
            top: searchBox.bottom; topMargin: Theme.s2
            left: parent.left; right: parent.right; bottom: parent.bottom
            leftMargin: panel.pad; rightMargin: panel.pad; bottomMargin: panel.pad
        }
        clip: true
        contentWidth: width
        contentHeight: col.height
        boundsBehavior: Flickable.StopAtBounds

        WheelScroll {}
        ScrollBar.vertical: ScrollRail {}

        // The list holds keyboard nav; the search field hands focus down with Down.
        Keys.onUpPressed: e => {
            if (panel.curNav > 0) {
                panel.curNav -= 1;
                panel.keepVisible();
            } else {
                panel.curNav = -1;
                search.forceActiveFocus();
            }
            e.accepted = true;
        }
        Keys.onDownPressed: e => {
            if (panel.curNav < panel.navIndices.length - 1) {
                panel.curNav += 1;
                panel.keepVisible();
            }
            e.accepted = true;
        }
        Keys.onSpacePressed: e => { panel.toggleCurrent(); e.accepted = true; }
        Keys.onReturnPressed: e => { panel.toggleCurrent(); e.accepted = true; }
        Keys.onEnterPressed: e => { panel.toggleCurrent(); e.accepted = true; }
        Keys.onEscapePressed: e => { panel.requestClose(); e.accepted = true; }

        Column {
            id: col
            width: list.width

            Repeater {
                id: rep
                model: panel.rows

                delegate: Item {
                    id: dg
                    required property var modelData
                    required property int index
                    readonly property bool isHeader: dg.modelData.header === true
                    readonly property var entry: dg.isHeader ? null : dg.modelData.entry
                    readonly property bool on: dg.entry ? panel.isOn(dg.entry.id) : false
                    readonly property bool active: !dg.isHeader && dg.index === panel.curModelIndex
                    width: col.width
                    height: dg.isHeader
                        ? headerRow.implicitHeight + Theme.s4
                        : Math.max(Theme.s7, textCol.implicitHeight + Theme.s3)

                    // ── section header: Latin caption, a kanji seal when we have one ──
                    Row {
                        id: headerRow
                        visible: dg.isHeader
                        anchors {
                            left: parent.left; right: parent.right
                            bottom: parent.bottom; bottomMargin: Theme.s2
                        }
                        spacing: Theme.s2
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: dg.isHeader ? I18n.tr(panel.captionFor(dg.modelData.group)).toUpperCase() : ""
                            color: Theme.inkDim
                            font.family: Theme.font
                            font.pixelSize: Theme.fMicro
                            font.weight: Font.DemiBold
                            font.letterSpacing: Theme.trackMark
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: dg.isHeader && panel.glossFor(dg.modelData.group).length > 0
                            text: dg.isHeader ? panel.glossFor(dg.modelData.group) : ""
                            color: Theme.faint
                            font.family: Theme.fontJp
                            font.pixelSize: Theme.fSmall
                        }
                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, headerRow.width - x)
                            height: 1
                            color: Theme.line
                        }
                    }

                    // ── a widget row: glyph, name over hint, a switch on the right ──
                    Rectangle {
                        visible: !dg.isHeader
                        anchors.fill: parent
                        radius: Theme.menuTileRadius
                        color: (dg.active || rowMa.containsMouse) ? Theme.tileHover : "transparent"
                        Behavior on color { ColorAnimation { duration: Theme.quick } }
                    }
                    MaterialIcon {
                        id: rowGlyph
                        visible: !dg.isHeader
                        anchors { left: parent.left; leftMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                        text: dg.entry ? (dg.entry.icon || "widgets") : ""
                        font.pixelSize: 20
                        fill: dg.on ? 1 : 0
                        color: dg.on ? Theme.ink : (rowMa.containsMouse ? Theme.ink : Theme.inkDim)
                    }
                    Column {
                        id: textCol
                        visible: !dg.isHeader
                        anchors {
                            left: rowGlyph.right; leftMargin: Theme.s3
                            right: custBtn.visible ? custBtn.left : rowSwitch.left; rightMargin: Theme.s3
                            verticalCenter: parent.verticalCenter
                        }
                        spacing: 1
                        Text {
                            width: parent.width
                            text: dg.entry ? I18n.tr(dg.entry.label || dg.entry.id) : ""
                            color: dg.on ? Theme.ink : Theme.inkSoft
                            font.family: Theme.font
                            font.pixelSize: Theme.fBody
                            font.weight: dg.on ? Font.DemiBold : Font.Medium
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            width: parent.width
                            visible: text.length > 0
                            text: dg.entry ? I18n.tr(panel.hintFor(dg.entry.id)) : ""
                            color: Theme.inkDim
                            font.family: Theme.font
                            font.pixelSize: Theme.fSmall
                            wrapMode: Text.WordWrap
                        }
                    }
                    Sw {
                        id: rowSwitch
                        visible: !dg.isHeader
                        anchors { right: parent.right; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                        on: dg.on
                        onToggled: v => { if (dg.entry) panel.toggle(dg.entry.id); }
                    }
                    // A quiet Customize affordance: open the widget inspector for
                    // an enabled row, so a face can be tuned from the picker too.
                    MaterialIcon {
                        id: custBtn
                        visible: !dg.isHeader && dg.on
                        anchors { right: rowSwitch.left; rightMargin: Theme.s3; verticalCenter: parent.verticalCenter }
                        text: "tune"
                        font.pixelSize: 18
                        color: custMa.containsMouse ? Theme.ink : Theme.inkDim
                        MouseArea {
                            id: custMa
                            anchors.fill: parent
                            anchors.margins: -Theme.s1
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: if (dg.entry) panel.customize(dg.entry.id)
                        }
                    }
                    // Click anywhere left of the switch toggles the row and moves
                    // the highlight there.
                    MouseArea {
                        id: rowMa
                        visible: !dg.isHeader
                        anchors { left: parent.left; right: custBtn.visible ? custBtn.left : rowSwitch.left; top: parent.top; bottom: parent.bottom }
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!dg.entry)
                                return;
                            panel.curNav = panel.navIndices.indexOf(dg.index);
                            panel.toggle(dg.entry.id);
                        }
                    }
                }
            }
        }
    }

    // Nothing matched the search: honest empty paper, not a blank panel.
    Text {
        anchors.centerIn: list
        visible: panel.navIndices.length === 0
        text: I18n.tr("No widgets match")
        color: Theme.inkDim
        font.family: Theme.font
        font.pixelSize: Theme.fSmall
    }
}
