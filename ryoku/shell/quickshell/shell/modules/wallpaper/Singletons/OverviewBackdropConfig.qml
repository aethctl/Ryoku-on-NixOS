pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The overview-backdrop knobs, read straight from ryogami's wallpaper config
// (~/.config/ryogami-wall/config.json), the same overviewBackdrop.* block the
// picker's "Overview backdrop" panel writes. Those settings had no consumer:
// nothing rendered a backdrop, so the picker wrote them into a void. The shell
// paints the surface itself now (modules/wallpaper -> OverviewBackdrop) and
// reads its shape here, so the one place the user sets this drives it.
Singleton {
    id: root

    readonly property string configPath: {
        const override = Quickshell.env("RYOGAMI_WALL_CONFIG");
        if (override && override.length > 0)
            return override + "/config.json";
        const base = Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config");
        return base + "/ryogami-wall/config.json";
    }

    // The overviewBackdrop sub-object, refreshed on every file write below.
    property var _ob: ({})

    // Map the blurred wallpaper into the overview backdrop at all. Off by default,
    // so a user who never opened the panel gets no extra surface.
    readonly property bool enabled: root._ob.enabled === true
    // A sharp copy when off; a Gaussian blur when on (the picker's default).
    readonly property bool blurEnabled: root._ob.blurEnabled !== false
    // Blur radius, matching the picker's 1..200 range and 30 default.
    readonly property int blur: {
        const v = root._ob.blur;
        return Math.max(1, Math.min(200, (typeof v === "number") ? v : 30));
    }
    // Track the live wallpaper, or paint a per-card backdrop image the user
    // pinned instead (path below). Following is the common case; a pinned image
    // wins only when the user turned following off and set one.
    readonly property bool followWallpaper: root._ob.followWallpaper === true
    readonly property string customPath: root._ob.path || ""
    // How far to darken the backdrop, as the picker's percentage.
    readonly property int dim: {
        const v = root._ob.dim;
        return Math.max(0, Math.min(100, (typeof v === "number") ? v : 0));
    }

    function _reparse() {
        let data = {};
        try {
            data = JSON.parse(file.text() || "{}");
        } catch (e) {
            data = {};
        }
        root._ob = (data && typeof data.overviewBackdrop === "object" && data.overviewBackdrop)
            ? data.overviewBackdrop : ({});
    }

    FileView {
        id: file
        path: root.configPath
        watchChanges: true
        printErrors: false
        onLoaded: root._reparse()
        onFileChanged: {
            reload();
            root._reparse();
        }
    }
}
