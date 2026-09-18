import QtQuick

// The wheel-to-scroller bridge. A plain Flickable does not answer the wheel on
// this stack -- the shell adds a WheelHandler wherever it scrolls, so a Hub page
// showed a ScrollRail and then ignored the wheel. Declare one of these INSIDE
// the scroller: a pointer handler only sees events over its own parent, so a
// handler buried in the rail would answer on the 4px strip alone.
//
// The wheel scrolls the scroller it sits in, clamped to its bounds, one notch
// per 120 units of angleDelta (the step the shell's menus use). A control that
// wants the wheel for itself keeps it: an inner handler accepts the event first.
WheelHandler {
    id: wheel

    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad

    // Qt reparents an item declared inside a Flickable (or ListView) to its
    // contentItem, and the contentItem is not what scrolls: walk up to the item
    // that owns contentHeight. Measured, not assumed -- the handler's own parent
    // is the contentItem.
    readonly property var scroller: {
        var p = wheel.parent;
        while (p && p.contentHeight === undefined)
            p = p.parent;
        return p || null;
    }

    onWheel: (event) => wheel.scrollBy(wheel.scroller, event.angleDelta.y)

    // true when the scroller actually moved, so a test can assert the scroll.
    function scrollBy(flick, dy) {
        if (!flick || flick.contentHeight === undefined)
            return false;
        var maxY = Math.max(0, flick.contentHeight - flick.height);
        if (maxY <= 0)
            return false;
        var next = Math.max(0, Math.min(maxY, flick.contentY - dy));
        if (next === flick.contentY)
            return false;
        flick.contentY = next;
        return true;
    }
}