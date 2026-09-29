pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import inir.modules.common.widgets
import inir.modules.iris.style

Item {
    id: root
    property string source: ""
    property bool circular: true
    property real radius: circular ? width / 2 : 12 * IrisStyle.density
    property real decodeSize: 0
    implicitWidth: 64 * IrisStyle.density
    implicitHeight: implicitWidth
    Image {
        id: cover
        anchors.fill: parent
        source: root.source
        sourceSize: root.decodeSize > 0 ? Qt.size(Math.ceil(root.decodeSize), Math.ceil(root.decodeSize))
            : Qt.size(Math.ceil(root.width * 2), Math.ceil(root.height * 2))
        asynchronous: true
        fillMode: Image.PreserveAspectCrop
        visible: false
    }
    Item {
        id: roundMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        Rectangle {
            anchors.fill: parent
            radius: root.radius
        }
    }
    MultiEffect {
        anchors.fill: parent
        source: cover
        autoPaddingEnabled: false
        maskEnabled: true
        maskSource: roundMask
        maskThresholdMin: 0.5
        maskSpreadAtMin: 1
        visible: cover.status === Image.Ready
    }
    MaterialSymbol {
        anchors.centerIn: parent
        visible: cover.status !== Image.Ready
        text: "music_note"
        iconSize: root.width * 0.55
        color: IrisStyle.subtext
    }
}
