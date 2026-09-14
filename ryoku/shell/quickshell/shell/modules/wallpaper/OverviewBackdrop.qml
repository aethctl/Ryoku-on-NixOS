pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "Singletons"

// An extra Background-layer surface that draws the current wallpaper, blurred,
// for the compositor to lift into the backdrop the user sees behind the
// workspaces in its overview. The provider routes this exact namespace into that
// backdrop region, so the surface is composited there.
//
// It sits BELOW the desktop's own opaque wallpaper (modules/desktop, the
// ryoku-widgets Bottom-layer surface), so with the overview closed it is
// completely covered and the desktop reads exactly as before; only the overview,
// which exposes the backdrop, reveals it.
//
// Mapped only when the compositor advertises the overviewBackdrop capability and
// the user enabled it in ryogami's picker. On a compositor with no backdrop to
// place a surface in, a second full-screen wallpaper would just paint over the
// desktop, so nothing maps there.
Item {
    id: root

    required property var screen
    // The active compositor can host a surface inside its overview backdrop.
    property bool available: false
    // The live wallpaper source the desktop paints (file url + revision), reused
    // so a wallpaper change carries straight into the backdrop with no second
    // pipeline to keep in sync.
    property string wallpaperUrl: ""

    readonly property bool shown: root.available && OverviewBackdropConfig.enabled

    // Follow the live wallpaper, or paint a per-card backdrop image the user
    // pinned when they turned following off and set one.
    readonly property string source: {
        const custom = OverviewBackdropConfig.customPath;
        if (!OverviewBackdropConfig.followWallpaper && custom.length > 0)
            return custom.indexOf("file://") === 0 ? custom : "file://" + custom;
        return root.wallpaperUrl;
    }

    PanelWindow {
        id: win
        // Unmapped unless the surface is both possible and wanted, so the
        // Background layer never carries an idle full-screen wallpaper.
        visible: root.shown && root.source.length > 0
        screen: root.screen
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "ryoku-overview-backdrop"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        anchors {
            top: true
            left: true
            right: true
            bottom: true
        }

        // Clip the blurred, oversized media back to the exact screen bounds: a
        // MultiEffect gaussian fades at the item edge (no pixels beyond it), so
        // the source is grown by blurMax on every side and this parent trims it.
        Item {
            anchors.fill: parent
            clip: true

            Image {
                id: img
                anchors.fill: parent
                anchors.margins: -64
                source: root.source
                fillMode: Image.PreserveAspectCrop
                cache: false
                asynchronous: true
                // A blurred full-screen copy carries no pixel-level detail, so a
                // screen-sized decode is plenty.
                sourceSize.width: win.screen ? win.screen.width : 0
                sourceSize.height: win.screen ? win.screen.height : 0
                // Hidden whenever the blur is drawing; shown as the sharp
                // backdrop when the user turned blur off (or before it decodes).
                visible: !blurFx.visible
            }

            MultiEffect {
                id: blurFx
                anchors.fill: img
                source: img
                visible: img.status === Image.Ready && OverviewBackdropConfig.blurEnabled
                blurEnabled: true
                blur: Math.min(1, OverviewBackdropConfig.blur / 100)
                blurMax: 64
            }

            // Dimming rides above the blur so the picker's percentage means the
            // same thing sharp or blurred: 0 leaves the wallpaper alone, 100 is
            // black.
            Rectangle {
                anchors.fill: parent
                color: "black"
                opacity: OverviewBackdropConfig.dim / 100
                visible: opacity > 0
            }
        }
    }
}
