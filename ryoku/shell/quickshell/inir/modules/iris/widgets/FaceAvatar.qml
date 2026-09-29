pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import inir.services
import inir.modules.common
import inir.modules.common.widgets
import inir.modules.iris.style

ClippingRectangle {
    id: root

    property int sourceIndex: 0
    readonly property string primarySource: Directories.userAvatarSourcePrimary
    onPrimarySourceChanged: root.sourceIndex = 0

    radius: width / 2
    color: IrisStyle.fill

    Image {
        id: picture
        anchors.fill: parent
        source: Directories.avatarSourceAt(root.sourceIndex)
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        smooth: true
        sourceSize.width: root.width * 2
        sourceSize.height: root.height * 2
        onStatusChanged: {
            if (status === Image.Error && root.sourceIndex + 1 < Directories.userAvatarPaths.length)
                Qt.callLater(() => root.sourceIndex++)
        }
    }
    StyledText {
        anchors.centerIn: parent
        visible: picture.status !== Image.Ready
        text: (SystemInfo.displayName || SystemInfo.username || "?").charAt(0).toUpperCase()
        color: IrisStyle.text
        font.family: IrisStyle.fontTitle
        font.pixelSize: root.height * 0.42
        font.weight: Font.DemiBold
    }
}
