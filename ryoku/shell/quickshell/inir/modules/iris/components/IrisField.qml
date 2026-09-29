pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import inir.modules.common
import inir.modules.common.widgets
import inir.modules.iris.style

MaterialTextField {
    id: root

    enableSettingsSearch: false
    color: IrisStyle.text
    placeholderTextColor: "transparent"
    selectionColor: IrisStyle.accentContainer
    selectedTextColor: IrisStyle.onAccentContainer
    font.family: IrisStyle.fontTitle
    font.pixelSize: 15 * IrisStyle.typeScale
    leftPadding: 14 * IrisStyle.density
    rightPadding: 14 * IrisStyle.density

    IrisText {
        anchors.left: parent.left
        anchors.leftMargin: root.leftPadding
        anchors.right: parent.right
        anchors.rightMargin: root.rightPadding
        anchors.verticalCenter: parent.verticalCenter
        visible: root.text.length === 0 && root.placeholderText.length > 0
        text: root.placeholderText
        font.family: root.font.family
        font.pixelSize: root.font.pixelSize
        color: IrisStyle.subtext
        elide: Text.ElideRight
    }

    background: PanelSurface {
        surfaceDialect: "inir"
        elevation: root.activeFocus ? 2 : 1
        opaqueSurface: true
        radiusOverride: IrisStyle.radiusSmall
        cardStyle: false
        outlined: false
        borderless: true
        borderWidthOverride: root.activeFocus ? 1.5 : 1

        Rectangle {
            anchors.fill: parent
            radius: IrisStyle.radiusSmall
            color: IrisStyle.field
            border.width: root.activeFocus ? 1 : 0
            border.color: IrisStyle.hairlineStrong
        }
    }
}
