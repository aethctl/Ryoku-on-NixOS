pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// The single source of truth for the qsbar's built-in widgets: it loads the
// shipped widgets.json (the same file the daemon reads) and hands out the id
// <-> gid mapping the rest of the bar needs. Everything that used to hand-list
// widgets - the layout migration, the settings catalogue, the daemon crib -
// reads this instead, so a widget is described in exactly one place.
//
// blockLoading is deliberate: the layout migration and the id<->gid lookups run
// during first load, so the array has to be present synchronously rather than a
// frame later.
Item {
    id: catalog

    // Parsed widgets.json: an array of { id, gid, label, gloss?, category?,
    // desc?, visKey?, settings? }. Empty until the file loads (it is shipped
    // beside this component, so the load never really fails in practice).
    property var entries: []

    // id -> entry, for the callers that want a whole row.
    property var _byId: ({})
    // gid -> id and id -> gid, the two lookups the layout core lives on.
    property var _idOfGid: ({})
    property var _gidOfId: ({})

    function _reindex(list) {
        var byId = ({})
        var idOfGid = ({})
        var gidOfId = ({})
        for (var i = 0; i < list.length; i++) {
            var e = list[i]
            if (!e || !e.id) continue
            byId[e.id] = e
            if (e.gid) { idOfGid[e.gid] = e.id; gidOfId[e.id] = e.gid }
        }
        catalog._byId = byId
        catalog._idOfGid = idOfGid
        catalog._gidOfId = gidOfId
        catalog.entries = list
    }

    function byId(id) { return catalog._byId[id] !== undefined ? catalog._byId[id] : null }
    function gidOf(id) { return catalog._gidOfId[id] !== undefined ? catalog._gidOfId[id] : "" }
    function idOf(gid) { return catalog._idOfGid[gid] !== undefined ? catalog._idOfGid[gid] : "" }

    FileView {
        id: file
        path: Qt.resolvedUrl("widgets.json")
        blockLoading: true
        printErrors: false
        onLoaded: {
            var parsed = []
            try { parsed = JSON.parse(file.text() || "[]") } catch (e) { parsed = [] }
            catalog._reindex(Array.isArray(parsed) ? parsed : [])
        }
    }
}
