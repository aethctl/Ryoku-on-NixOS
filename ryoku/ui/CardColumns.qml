import QtQuick
import "Singletons"

// A page body of cards, laid into balanced columns.
//
// A settings page used to hand-place one column of cards, which on a page-wide
// window leaves a label at one edge and its control at the other. This takes the
// same children, measures them, and lays them into as many columns as the measure
// holds -- splitting them so the columns end level -- while a child marked
// `fullWidth: true` takes a band across the columns and splits the flow.
//
// Children stay where they were declared (this only positions them), so a page
// keeps owning its ids and bindings; the width of one column is published as
// `colWidth` for a delegate that sizes itself to its column.
Item {
    id: root

    property real spacing: Tokens.s4          // between cards down a column
    property real columnSpacing: Tokens.s5    // between columns
    property int maxColumns: 2
    property real minColumnWidth: 460
    default property alias content: stage.data

    readonly property int columns: width >= maxColumns * minColumnWidth + (maxColumns - 1) * columnSpacing
        ? maxColumns : 1
    readonly property real colWidth: Math.max(200, Math.floor((width - (columns - 1) * columnSpacing) / columns))

    implicitHeight: layoutHeight
    height: implicitHeight
    property real layoutHeight: 0

    // The coordinate space the children were declared into; they are positioned
    // in place, so nothing has to be reparented to be laid out.
    Item {
        id: stage
        anchors.fill: parent
    }

    function childrenInOrder() {
        var list = [];
        for (var i = 0; i < stage.children.length; i++) {
            var c = stage.children[i];
            if (c && c.visible !== false && c.width !== 0)
                list.push(c);
        }
        return list;
    }

    // Which column each card takes. Within a run of cards (a band ends the run),
    // every achievable load for the first column is reachable, so the pair whose
    // taller side is smallest is the assignment used: a greedy fill leaves one
    // column visibly short whenever a tall card lands early.
    function splitRun(heights) {
        var n = heights.length;
        var out = [];
        for (var z0 = 0; z0 < n; z0++) out.push(1);
        if (n === 0 || root.columns <= 1)
            return out;

        var units = [];
        var total = 0;
        for (var i = 0; i < n; i++) {
            var u = Math.max(1, Math.round(heights[i] / 8));
            units.push(u);
            total += u;
        }
        // reach[i][l]: the first i cards can put exactly l in the first column
        var reach = [];
        for (var r = 0; r <= n; r++) {
            var row = [];
            for (var l = 0; l <= total; l++) row.push(false);
            reach.push(row);
        }
        reach[0][0] = true;
        for (var c = 0; c < n; c++) {
            for (var load = 0; load <= total; load++) {
                if (!reach[c][load]) continue;
                reach[c + 1][load] = true;                       // card c goes right
                if (load + units[c] <= total)
                    reach[c + 1][load + units[c]] = true;         // card c goes left
            }
        }
        var bestL = 0, bestMax = -1;
        for (var cand = 0; cand <= total; cand++) {
            if (!reach[n][cand]) continue;
            var m = Math.max(cand, total - cand);
            if (bestMax < 0 || m < bestMax) { bestMax = m; bestL = cand; }
        }
        // walk back: a card is on the left when the load without it is reachable
        var left = bestL;
        for (var k = n - 1; k >= 0; k--) {
            if (left >= units[k] && reach[k][left - units[k]]) {
                out[k] = 0;
                left -= units[k];
            }
        }
        return out;
    }

    property bool _laying: false
    function lay() {
        if (root._laying || root.width <= 0)
            return;
        root._laying = true;
        try {
            layInner();
        } catch (e) {
            console.warn("CardColumns: layout failed: " + e);
        }
        root._laying = false;
    }

    function layInner() {

        var kids = root.childrenInOrder();
        var heights = [];
        for (var m = 0; m < kids.length; m++) {
            var kk = kids[m];
            var full = kk.fullWidth === true;
            var w = full ? root.width : root.colWidth;
            if (Math.abs(kk.width - w) > 0.5)
                kk.width = w;
            heights.push(kk.height);
        }

        // runs of cards, split by the bands between them
        var assign = [];
        var i = 0;
        while (i < kids.length) {
            if (kids[i].fullWidth === true) {
                assign[i] = -1;
                i++;
                continue;
            }
            var run = [];
            var start = i;
            while (i < kids.length && kids[i].fullWidth !== true) {
                run.push(heights[i]);
                i++;
            }
            var picks = root.splitRun(run);
            for (var r = 0; r < run.length; r++)
                assign[start + r] = picks[r];
        }

        // place: one cursor per column, bands flush both to the same line
        var cursors = [];
        for (var c = 0; c < root.columns; c++) cursors.push(0);
        var lowest = 0;
        for (var j = 0; j < kids.length; j++) {
            var kid = kids[j];
            if (assign[j] === -1) {
                var floorY = 0;
                for (var f = 0; f < cursors.length; f++) floorY = Math.max(floorY, cursors[f]);
                kid.x = 0;
                kid.y = floorY;
                for (var g = 0; g < cursors.length; g++) cursors[g] = floorY + kid.height + root.spacing;
                lowest = Math.max(lowest, floorY + kid.height);
            } else {
                var col = Math.min(assign[j], root.columns - 1);
                kid.x = col * (root.colWidth + root.columnSpacing);
                kid.y = cursors[col];
                cursors[col] += kid.height + root.spacing;
                lowest = Math.max(lowest, cursors[col] - root.spacing);
            }
        }
        root.layoutHeight = kids.length === 0 ? 0 : lowest;
        root._laying = false;
    }

    onWidthChanged: Qt.callLater(root.lay)
    onColumnsChanged: Qt.callLater(root.lay)
    Component.onCompleted: {
        Qt.callLater(root.lay);
        ladder.restart();
    }

    // A card's height is only known once its own text has wrapped at the column
    // width, and a wrapped line can change a column's height again. A ladder of
    // passes over the first second converges instead of laying out against
    // half-measured cards, which stacks them on top of each other.
    Timer {
        id: ladder
        interval: 90
        repeat: true
        property int passes: 0
        running: false
        onTriggered: {
            passes++;
            root.lay();
            if (passes >= 8)
                running = false;
        }
    }

    Timer {
        id: settle
        interval: 16
        repeat: false
        onTriggered: root.lay()
    }

    // A card that grows (a group unfolds, a row appears) re-lays the page. A
    // delegate declared under `pragma ComponentBehavior: Bound` refuses a dynamic
    // property, so which children are already wired is tracked here.
    property var _wired: []
    Connections {
        target: stage
        function onChildrenChanged() {
            for (var i = 0; i < stage.children.length; i++) {
                var c = stage.children[i];
                if (!c || root._wired.indexOf(c) !== -1)
                    continue;
                root._wired.push(c);
                c.heightChanged.connect(settle.restart);
                c.visibleChanged.connect(settle.restart);
            }
            settle.restart();
        }
    }
}
