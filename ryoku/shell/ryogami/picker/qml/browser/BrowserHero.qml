import QtQuick
import Ryoku.Ui.Singletons

Rectangle {
    id: hero

    property string sourceLabel: ""
    property int count: 0
    property int page: 1
    property string artSource: ""
    property real reveal: 1

    implicitHeight: 132 * Theme.scale
    clip: true
    color: Theme.withAlpha(Theme.background, 0.72)
    border.width: 1
    border.color: Theme.withAlpha(Theme.outline, 0.42)

    function _pad2(n) { n = Math.max(0, Math.floor(n)); return n < 10 ? "0" + n : "" + n }
    readonly property real _bigScale: Math.max(0.9, Math.min(1.08, Theme.scale))

    Image {
        anchors.fill: parent
        visible: hero.artSource.length > 0
        source: hero.artSource
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        opacity: hero.reveal
    }

    Rectangle {
        id: identity
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 18 * Theme.scale
        anchors.bottomMargin: 18 * Theme.scale
        width: Math.min(430 * Theme.scale, parent.width - 36 * Theme.scale)
        height: idCol.implicitHeight + 32 * Theme.scale
        color: Theme.background

        Column {
            id: idCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 24 * Theme.scale
            anchors.rightMargin: 24 * Theme.scale
            spacing: 6 * Theme.scale

            Text {
                text: I18n.tr("Online sources / current result")
                font.family: Theme.ui
                font.weight: Theme.uiWeight
                font.pixelSize: Theme.fontFine
                color: Theme.withAlpha(Theme.primary, 0.94 * hero.reveal)
                renderType: Text.NativeRendering
            }
            Text {
                width: parent.width
                text: hero.sourceLabel
                elide: Text.ElideRight
                lineHeight: 0.94
                font.family: Theme.ui
                font.weight: Theme.uiWeight
                font.pixelSize: 34 * hero._bigScale
                color: Theme.withAlpha(Theme.surfaceText, 0.99 * hero.reveal)
                renderType: Text.NativeRendering
            }
            Text {
                width: parent.width
                text: I18n.tr("Open a result to check its full resolution, source, and download options.")
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
                font.family: Theme.ui
                font.weight: Theme.uiWeight
                font.pixelSize: Theme.fontBase
                color: Theme.withAlpha(Theme.surfaceText, 0.64 * hero.reveal)
                renderType: Text.NativeRendering
            }
        }
    }

    Rectangle {
        id: counter
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 18 * Theme.scale
        anchors.topMargin: 18 * Theme.scale
        width: 144 * Theme.scale
        height: 76 * Theme.scale
        color: Theme.surfaceVariant

        Column {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.rightMargin: 14 * Theme.scale
            spacing: 4 * Theme.scale

            Text {
                anchors.right: parent.right
                text: hero._pad2(hero.count)
                lineHeight: 0.86
                font.family: Theme.ui
                font.weight: Theme.uiWeight
                font.pixelSize: 34 * hero._bigScale
                color: Theme.withAlpha(Theme.surfaceText, 0.98 * hero.reveal)
                renderType: Text.NativeRendering
            }
            Text {
                anchors.right: parent.right
                text: I18n.tr("Results / page %1").arg(hero._pad2(hero.page))
                font.family: Theme.ui
                font.weight: Theme.uiWeight
                font.pixelSize: Theme.fontFine
                color: Theme.withAlpha(Theme.primary, 0.9 * hero.reveal)
                renderType: Text.NativeRendering
            }
        }
    }
}
