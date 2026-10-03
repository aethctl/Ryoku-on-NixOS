pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.Ui.Singletons
import "lib/screens.js" as Screens
import "../modules/sidebar/SidebarCatalog.js" as Catalog

Singleton {
    id: root

    property int intentRevision: 0

    readonly property real motionMultiplier: Config.sidebars.motion === "quick" ? 0.6
        : Config.sidebars.motion === "calm" ? 1.5 : 1.0
    readonly property int enterDuration: (Motion.reduce || Tokens.reduceMotion)
        ? 0 : Math.round(Tokens.swap * motionMultiplier)
    readonly property int exitDuration: (Motion.reduce || Tokens.reduceMotion)
        ? 0 : Math.round(Tokens.move * motionMultiplier)
    readonly property var enterCurve: [0.16, 1, 0.3, 1, 1, 1]
    readonly property var exitCurve: [0, 0, 0.58, 1, 1, 1]

    function motionOpening(screen) {
        var slice = root.sliceFor(screen);
        return slice ? slice.openingIntent : false;
    }

    function motionDuration(screen) {
        return root.motionOpening(screen) ? root.enterDuration : root.exitDuration;
    }

    function motionCurve(screen) {
        return root.motionOpening(screen) ? root.enterCurve : root.exitCurve;
    }

    readonly property bool anyOpen: {
        var revision = root.intentRevision;
        var list = states.instances;
        for (var i = 0; i < list.length; ++i) {
            if (list[i].leftOpen || list[i].rightOpen
                    || list[i].leftProgress > 0.001 || list[i].rightProgress > 0.001)
                return true;
        }
        return false;
    }

    function screenName(screen) {
        if (typeof screen === "string")
            return screen;
        return screen && screen.name ? screen.name : "";
    }

    function sliceFor(screen) {
        var name = root.screenName(screen);
        if (name !== "")
            return Screens.sliceForName(states.instances, name);
        var focused = Screens.sliceForName(states.instances, Wm.focusedOutput);
        if (focused)
            return focused;
        return states.instances.length > 0 ? states.instances[0] : null;
    }

    function validSide(side) {
        return side === "left" || side === "right";
    }


    function sideEnabled(side) {
        return root.validSide(side) && Config.sidebars[side].enabled;
    }
    function isOpen(screen, side) {
        var slice = root.sliceFor(screen);
        if (!slice || !root.validSide(side))
            return false;
        return side === "left" ? slice.leftOpen : slice.rightOpen;
    }

    function progress(screen, side) {
        var slice = root.sliceFor(screen);
        if (!slice || !root.validSide(side))
            return 0;
        return side === "left" ? slice.leftProgress : slice.rightProgress;
    }


    function railClearances(screen) {
        var slice = root.sliceFor(screen);
        if (!slice)
            return { top: 0, left: 0, bottom: 0, right: 0 };
        return {
            top: slice.railTop,
            left: slice.railLeft,
            bottom: slice.railBottom,
            right: slice.railRight
        };
    }

    function setRailClearances(screen, clearances) {
        var slice = root.sliceFor(screen);
        if (!slice || !clearances)
            return;
        slice.railTop = Math.max(0, Number(clearances.top) || 0);
        slice.railLeft = Math.max(0, Number(clearances.left) || 0);
        slice.railBottom = Math.max(0, Number(clearances.bottom) || 0);
        slice.railRight = Math.max(0, Number(clearances.right) || 0);
    }

    function activeTab(screen, side) {
        var slice = root.sliceFor(screen);
        if (!slice || !root.validSide(side))
            return "";
        return side === "left" ? slice.leftTab : slice.rightTab;
    }

    function selectTab(side, screen, tab) {
        var slice = root.sliceFor(screen);
        if (!slice || !root.validSide(side) || !tab)
            return;
        if (side === "left")
            slice.leftTab = tab;
        else
            slice.rightTab = tab;
    }
    function closeSide(side, screen) {
        const slice = root.sliceFor(screen);
        if (!slice || !root.validSide(side)) return;
        slice.openingIntent = false;
        if (side === "left") slice.leftOpen = false;
        else slice.rightOpen = false;
        root.intentRevision++;
    }

    function setProgress(screen, side, value) {
        var slice = root.sliceFor(screen);
        if (!slice || !root.validSide(side))
            return;
        var next = Math.max(0, Math.min(1, Number(value) || 0));
        if (side === "left")
            slice.leftProgress = next;
        else
            slice.rightProgress = next;
    }

    function sideForTab(side, tab) {
        const entry = Catalog.byTab(tab);
        if (!entry) return side;
        const other = side === "left" ? "right" : "left";
        if (Config.sidebars[side].cards.indexOf(entry.id) >= 0) return side;
        return Config.sidebars[other].cards.indexOf(entry.id) >= 0 && root.sideEnabled(other) ? other : side;
    }

    function open(side, screen, tab) {
        side = root.sideForTab(side, tab);
        var slice = root.sliceFor(screen);
        if (!slice || !root.sideEnabled(side))
            return;
        slice.openingIntent = true;
        if (side === "left") {
            if (!Config.sidebars.right.pinned) slice.rightOpen = false;
            if (tab)
                slice.leftTab = tab;
            slice.leftOpen = true;
        } else {
            if (!Config.sidebars.left.pinned) slice.leftOpen = false;
            if (tab)
                slice.rightTab = tab;
            slice.rightOpen = true;
        }
        root.intentRevision++;
    }

    function toggle(side, screen, tab) {
        side = root.sideForTab(side, tab);
        var slice = root.sliceFor(screen);
        if (!slice || !root.sideEnabled(side))
            return;
        var opened = side === "left" ? slice.leftOpen : slice.rightOpen;
        var currentTab = side === "left" ? slice.leftTab : slice.rightTab;
        if (opened && tab && tab !== currentTab) {
            root.selectTab(side, screen, tab);
            return;
        }
        if (opened) {
            slice.openingIntent = false;
            if (side === "left")
                slice.leftOpen = false;
            else
                slice.rightOpen = false;
            root.intentRevision++;
            return;
        }
        root.open(side, screen, tab);
    }

    function closeAll(screen) {
        var slice = root.sliceFor(screen);
        if (!slice)
            return;
        if (!slice.leftOpen && !slice.rightOpen)
            return;
        slice.openingIntent = false;
        slice.leftOpen = false;
        slice.rightOpen = false;
        root.intentRevision++;
    }


    function consumeRequest(requestedId, monitor, context) {
        var value = requestedId || "";
        var split = value.indexOf("#");
        var id = split >= 0 ? value.substring(0, split) : value;
        var tab = split >= 0 ? value.substring(split + 1) : "";
        if (!tab && typeof context === "string")
            tab = context.charAt(0) === "#" ? context.substring(1) : context;
        else if (!tab && context && typeof context === "object")
            tab = context.tab || context.page || "";
        if (id !== "sidebar-left" && id !== "sidebar-right")
            return;
        root.toggle(id === "sidebar-left" ? "left" : "right", monitor, tab);
    }

    Connections {
        target: ShellState
        function onSurfaceRequested(id, mon, context) {
            root.consumeRequest(id, mon, context);
        }
        function onSurfaceClosed(id, mon) {
            var base = (id || "").split("#")[0];
            if (base === "sidebar-left" || base === "sidebar-right")
                root.closeSide(base === "sidebar-left" ? "left" : "right", mon);
        }
    }

    Connections {
        target: Config
        function onSidebarsChanged() {
            var changed = false;
            var list = states.instances;
            for (var i = 0; i < list.length; ++i) {
                if (!Config.sidebars.left.enabled && list[i].leftOpen) {
                    list[i].leftOpen = false;
                    changed = true;
                }
                if (!Config.sidebars.right.enabled && list[i].rightOpen) {
                    list[i].rightOpen = false;
                    changed = true;
                }
            }
            if (changed)
                root.intentRevision++;
        }
    }

    Variants {
        id: states
        model: ShellState.screens

        PersistentProperties {
            required property var modelData
            property bool leftOpen: false
            property bool rightOpen: false
            property bool openingIntent: false
            property real leftProgress: 0
            property real rightProgress: 0
            property string leftTab: "controls"
            property string rightTab: "tools"
            property real railTop: 0
            property real railLeft: 0
            property real railBottom: 0
            property real railRight: 0
        }
    }
}
