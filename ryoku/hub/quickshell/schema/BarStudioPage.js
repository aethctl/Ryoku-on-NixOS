.pragma library

// Bar Studio renders its own cards from BarStudioPage.qml, so this schema exists
// only to feed the Hub's global search (Hub.qml searchIndex). Bar Studio now
// carries just the bar-style gallery and the built-in style editors (Sumi's
// frame and rails, Obi, Nacre); QS Bar's own layout, widgets, form and dock moved
// to QS Bar Settings and the picker style moved to the Desktop page, so none of
// those keys are offered from here any more. No searchable rows are left.
var rows = [];
