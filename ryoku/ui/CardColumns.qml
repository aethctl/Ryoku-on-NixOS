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
    // The Hub opens page-wide, so the body uses the width it is given: three
    // columns once the measure holds them, in step with the schema sheet's own
    // grid, so a hand-built page and a data page read at the same card width.
    property int maxColumns: 3
    property real minColumnWidth: 460
    // The height of the body this grid sits in. A page whose cards nearly fill it
    // centres them in the space rather than hanging them off the top of a
    // half-empty window: a composed page, not a queue that ran out. A page whose
    // cards are genuinely thin stays at the top -- a small block floated into the
    // middle of a void reads as lost, not composed.
    property real fillTo: 0
    default property alias content: stage.data

    // A page with two blocks does not get three columns: the grid takes as many
    // columns as it has blocks (up to what the measure holds) and the cards share
    // the space left over, so a short page fills the window instead of hugging
    // its left edge.
    readonly property int capacity: width >= maxColumns * minColumnWidth + (maxColumns - 1) * columnSpacing
        ? maxColumns : 1
    readonly property int blocks: childrenInOrder().length
    readonly property int columns: Math.max(1, Math.min(capacity, blocks))
    readonly property real colWidth: Math.min(Tokens.cardWide,
        Math.max(200, Math.floor((width - (columns - 1) * columnSpacing) / columns)))

    implicitHeight: layoutHeight
    height: implicitHeight
    property real layoutHeight: 0
    // what the cards actually need, before `fillTo` pads the body out. A page
    // measuring its own spare room wants this number, not the padded one.
    property real contentHeight: 0

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

    // Which column each card takes. A run of cards keeps its order and is cut
    // into as many contiguous columns as there are cards to spread, choosing the
    // cuts that make the tallest column the shortest -- the law the two-column
    // page used, solved for any number of columns, so three columns balance like
    // two did and none is left empty while another stacks.
    function splitRun(heights) {
        var n = heights.length;
        var out = [];
        for (var z0 = 0; z0 < n; z0++) out.push(0);
        if (n === 0 || root.columns <= 1)
            return out;

        var units = [];
        for (var i = 0; i < n; i++)
            units.push(Math.max(1, Math.round(heights[i] / 8)));
        var prefix = [0];
        for (var p = 0; p < n; p++)
            prefix.push(prefix[p] + units[p]);
        var load = function (a, b) { return prefix[b] - prefix[a]; };

        // a column with no card in it is not a column: a run of two cards gets two
        var cols = Math.min(root.columns, n);
        var INF = 1e9;
        var best = [], from = [];
        for (var c = 0; c <= cols; c++) {
            var row = [], back = [];
            for (var q = 0; q <= n; q++) { row.push(INF); back.push(0); }
            best.push(row); from.push(back);
        }
        best[0][0] = 0;
        for (var col = 1; col <= cols; col++) {
            for (var end = 1; end <= n; end++) {
                for (var cut = 0; cut < end; cut++) {         // this column holds [cut, end)
                    if (best[col - 1][cut] >= INF) continue;
                    var cand = Math.max(best[col - 1][cut], load(cut, end));
                    if (cand < best[col][end]) {
                        best[col][end] = cand;
                        from[col][end] = cut;
                    }
                }
            }
        }
        var c2 = cols, e = n;
        while (c2 > 0) {
            var s = from[c2][e];
            for (var x = s; x < e; x++)
                out[x] = c2 - 1;
            e = s;
            c2--;
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
        // A block that comes up short of the body is centred in it: a page reads
        // composed rather than hanging from the top of an empty window.
        var content = kids.length === 0 ? 0 : lowest;
        root.contentHeight = content;
        var body = Math.max(0, root.fillTo);
        if (body > content && content >= body * 0.45) {
            var lift = Math.round((body - content) / 2);
            for (var l = 0; l < kids.length; l++)
                kids[l].y += lift;
        }
        root.layoutHeight = Math.max(content, body);
        root._laying = false;
    }

    onWidthChanged: Qt.callLater(root.lay)
    onColumnsChanged: Qt.callLater(root.lay)
    onFillToChanged: Qt.callLater(root.lay)
    Component.onCompleted: {
        Qt.callLater(root.lay);
        ladder.restart();
    }

    // A card's height is only known once its own rows exist and its text has
    // wrapped at the column width, and the page it belongs to loads
    // asynchronously -- so a fixed number of passes stops too early (laying out
    // against half-measured cards, which stacks them) while the cards can still
    // be placeholders. This watches the cards' heights and re-lays while they are
    // still changing, with a minimum run and a long stop: a page's rows arrive a
    // few frames after its cards do.
    function signature() {
        var kids = childrenInOrder();
        var out = [];
        for (var i = 0; i < kids.length; i++)
            out.push(Math.round(kids[i].height));
        return out.join(",");
    }
    Timer {
        id: ladder
        interval: 120
        repeat: true
        running: false
        property int passes: 0
        property string last: ""
        property bool settled: false
        onTriggered: {
            passes++;
            root.lay();
            var sig = root.signature();
            settled = (sig === last && sig !== "");
            last = sig;
            if ((settled && passes >= 8) || passes >= 30)
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
