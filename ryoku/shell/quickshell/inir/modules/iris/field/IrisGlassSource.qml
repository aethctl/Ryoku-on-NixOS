pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell
import inir.services
import inir.modules.iris.style

Item {
    id: root

    property var screen: null
    readonly property bool ready: wallpaper.status === Image.Ready
    readonly property Item texture: blurred

    visible: false

    Image {
        id: wallpaper
        anchors.fill: parent
        visible: false
        source: WallpaperListener.wallpaperUrlForScreen(root.screen)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: Math.max(1, Math.round((root.screen?.width ?? root.width) / 2))
        sourceSize.height: Math.max(1, Math.round((root.screen?.height ?? root.height) / 2))
    }

    MultiEffect {
        id: blurred
        anchors.fill: parent
        visible: false
        layer.enabled: true
        layer.textureSize: Qt.size(Math.max(1, Math.round(root.width / 2)), Math.max(1, Math.round(root.height / 2)))
        source: wallpaper
        autoPaddingEnabled: false
        blurEnabled: true
        blur: IrisStyle.glassBlurAmount
        blurMax: IrisStyle.glassBlurMax
        saturation: IrisStyle.glassSaturation
    }
}
