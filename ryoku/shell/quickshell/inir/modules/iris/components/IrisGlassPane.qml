pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import inir.services
import inir.modules.iris.style

Item {
    id: root

    property point sceneOffset: Qt.point(0, 0)
    property point windowOffset: Qt.point(0, 0)
    property color tint: IrisStyle.placeSurface
    readonly property var screen: root.QsWindow.window?.screen ?? null
    readonly property real screenWidth: root.screen?.width ?? 1920
    readonly property real screenHeight: root.screen?.height ?? 1080
    readonly property bool ready: wallpaper.status === Image.Ready

    Image {
        id: wallpaper
        x: -(root.sceneOffset.x + root.windowOffset.x)
        y: -(root.sceneOffset.y + root.windowOffset.y)
        width: root.screenWidth
        height: root.screenHeight
        visible: false
        source: WallpaperListener.wallpaperUrlForScreen(root.screen)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: Math.max(1, Math.round(root.screenWidth / 2))
        sourceSize.height: Math.max(1, Math.round(root.screenHeight / 2))
    }

    MultiEffect {
        x: wallpaper.x
        y: wallpaper.y
        width: wallpaper.width
        height: wallpaper.height
        visible: root.ready
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blur: IrisStyle.glassBlurAmount
        blurMax: IrisStyle.glassBlurMax
        saturation: IrisStyle.glassSaturation
    }

    Rectangle {
        anchors.fill: parent
        color: root.ready ? root.tint : IrisStyle.surfaceOpaque
    }
}
