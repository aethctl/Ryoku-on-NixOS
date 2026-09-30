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
    // The compositor's native overview is open, so the backdrop is on screen.
    property bool overviewOpen: false
    // The live wallpaper source the desktop paints (file url + revision), reused
    // so a wallpaper change carries straight into the backdrop with no second
    // pipeline to keep in sync.
    property string wallpaperUrl: ""

    readonly property bool shown: root.available && OverviewBackdropConfig.enabled
    // The gaussian pass runs only while the overview is open: that is the only
    // moment the compositor shows this surface, and a full-screen blur every
    // frame otherwise taxes recording and gaming for pixels nobody sees.
    readonly property bool blurWanted: root.overviewOpen && OverviewBackdropConfig.blurEnabled

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
                // The sharp copy shows only while the blur is off (overview
                // closed, or the user turned blur off); the blurred copy rides
                // above it once the pass engages.
                visible: !blurFx.visible
            }

            // The gaussian pass engages only while the overview is open: that is
            // the only moment the compositor shows this surface, and a full-screen
            // blur every frame otherwise taxes recording and gaming for pixels
            // nobody sees. The node stays mounted so opening the overview eases
            // the blur in through niri's own animation instead of popping a fresh
            // render target at the worst instant.
            MultiEffect {
                id: blurFx
                anchors.fill: img
                source: img
                // Keep the pass alive through the fade-out so blur eases to zero
                // rather than snapping when the overview closes.
                blur: root.blurWanted ? Math.min(1, OverviewBackdropConfig.blur / 100) : 0.0
                blurMax: 64
                visible: img.status === Image.Ready && blurFx.blurEnabled

                Behavior on blur {
                    enabled: !Motion.reduce
                    NumberAnimation { duration: Motion.wallpaperFade; easing.type: Easing.OutCubic }
                }
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
