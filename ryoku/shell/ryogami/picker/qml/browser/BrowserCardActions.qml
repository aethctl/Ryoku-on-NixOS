import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: actions

    property var item: null
    property var sources: null
    property bool showApply: false
    property bool applying: false
    property real reveal: 1
    // A running download can be stopped from its own button, except Workshop transfers.
    property bool cancellable: false

    signal save()
    signal apply()
    signal cancel()

    readonly property bool hovering: saveHover.containsMouse || applyHover.containsMouse
    readonly property bool _downloaded: !!item && item.downloaded === true
    readonly property bool _downloading: !!sources && sources.isDownloading(item)

    Rectangle {
        visible: actions._downloaded
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: 6 * Theme.scale
        anchors.topMargin: 6 * Theme.scale
        width: 70 * Theme.scale
        height: 22 * Theme.scale
        radius: Theme.radius
        color: Theme.withAlpha(Theme.surfaceText, 0.96 * actions.reveal)

        Text {
            anchors.centerIn: parent
            text: I18n.tr("\u2713 Saved")
            font.family: Theme.sans
            font.weight: Font.DemiBold
            font.pixelSize: Theme.fontSmall
            color: Theme.withAlpha(Theme.surface, actions.reveal)
            renderType: Text.NativeRendering
        }
    }

    Row {
        id: bar
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        width: Math.min(158 * Theme.scale, parent.width)
        height: Math.min(30 * Theme.scale, parent.height)
        spacing: 0

        Rectangle {
            id: saveBtn
            width: Math.round(bar.width * 0.56)
            height: bar.height
            radius: Theme.radius
            color: Theme.withAlpha(Theme.surfaceText, 0.05 * actions.reveal)
            border.width: 1
            border.color: Theme.withAlpha(Theme.outline, 0.4 * actions.reveal)

            Text {
                anchors.centerIn: parent
                width: parent.width - 8 * Theme.scale
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: actions._downloaded
                    ? I18n.tr("\u2713 Saved")
                    : actions._downloading
                        ? (actions.cancellable && saveHover.containsMouse
                            ? I18n.tr("Cancel")
                            : (actions.sources ? actions.sources.progressLabel(I18n.tr("Saving"), actions.item) : I18n.tr("Saving")))
                        : I18n.tr("Save")
                font.family: Theme.sans
                font.weight: Font.Medium
                font.pixelSize: Theme.fontSmall
                color: Theme.withAlpha(Theme.surfaceText,
                    (actions._downloaded || actions._downloading ? 0.56 : 0.96) * actions.reveal)
                renderType: Text.NativeRendering
            }
            MouseArea {
                id: saveHover
                anchors.fill: parent
                hoverEnabled: true
                enabled: !actions._downloaded && (!actions._downloading || actions.cancellable)
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: actions._downloading ? actions.cancel() : actions.save()
            }
        }

        Rectangle {
            id: applyBtn
            visible: actions.showApply
            width: bar.width - saveBtn.width
            height: bar.height
            radius: Theme.radius
            color: Theme.withAlpha(Theme.surfaceText, 0.97 * actions.reveal)

            Text {
                anchors.centerIn: parent
                width: parent.width - 8 * Theme.scale
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: actions.applying ? I18n.tr("Applying") : I18n.tr("Apply")
                font.family: Theme.sans
                font.weight: Font.DemiBold
                font.pixelSize: Theme.fontSmall
                color: Theme.withAlpha(Theme.surface, (actions.applying ? 0.62 : 1.0) * actions.reveal)
                renderType: Text.NativeRendering
            }
            MouseArea {
                id: applyHover
                anchors.fill: parent
                hoverEnabled: true
                enabled: !actions.applying
                cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
                onClicked: actions.apply()
            }
        }
    }
}
