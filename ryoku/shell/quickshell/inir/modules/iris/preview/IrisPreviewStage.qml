pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import inir
import inir.services
import inir.modules.iris.style

ClippingRectangle {
    id: root
    radius: IrisStyle.radiusCard
    color: IrisStyle.fillQuiet
    Image {
        anchors.fill: parent
        source: WallpaperListener.wallpaperUrlForScreen(GlobalStates.focusedScreen)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: Math.round(Math.max(1, root.width) * 1.2)
        opacity: status === Image.Ready ? 1 : 0
    }
}
