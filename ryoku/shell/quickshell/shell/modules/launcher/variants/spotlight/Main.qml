// The iRiS launcher: the frame's morphing-glass Spotlight, opened with Super+Space
// or the dock's nine-dot. When the iRiS bar style is active the frame itself hosts
// the palette, so this variant is a thin bridge: it drives the frame's own
// searchOpen flag and the spotlight morphs out of the island exactly as the frame
// drew it. Under any other bar style nothing hosts the palette, so the variant
// mounts the frame's IrisPalette component itself; the same glass, minus the
// island it usually morphs from.
//
// The palette's search is the shared provider pipeline (LauncherSearch): apps,
// actions, commands, math and web all answer, and launching an app or running an
// action closes the palette, which closes the launcher through the controller.

//@ pragma UseQApplication

import QtQuick
import Quickshell
import shell.services
import inir
import inir.services.deferred
import inir.modules.common as Iris
import inir.modules.iris.palette

Scope {
    id: root

    // ── launcher contract (docs/launcher.md) ─────────────────────────────────
    readonly property bool shown: GlobalStates.searchOpen
    // The frame hosts the palette only while its own bar style is on screen and
    // the palette module is switched on; otherwise this variant hosts it.
    readonly property bool frameHosts: Config.barStyle === "iris"
        && (Iris.Config.options?.iris?.modules?.palette ?? true)

    function show(mon) {
        GlobalStates.searchOpen = true
    }
    function hide() {
        GlobalStates.searchOpen = false
    }
    function toggle(mon) {
        root.shown ? root.hide() : root.show(mon)
    }
    function stateDump() {
        return {
            open: GlobalStates.searchOpen,
            query: LauncherSearch.query ?? "",
            resultCount: (LauncherSearch.results ?? []).length
        }
    }

    Loader {
        active: GlobalStates.searchOpen && !root.frameHosts
        sourceComponent: Component { IrisPalette {} }
    }
}
