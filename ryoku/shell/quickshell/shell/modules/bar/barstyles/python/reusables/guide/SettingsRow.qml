import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import "../../"
import "../"

Rectangle {
    id: root
    Layout.fillWidth: true

    property var rootObj: null

    function s(val) {
        let dummy = rootObj;
        return (dummy && typeof dummy.s === "function") ? dummy.s(val) : val;
    }

    property real cornerRadius: ThemeBackend.borderRadius
    property color baseColor: Qt.alpha(ThemeBackend.surface0, 0.4)
    property color hoverColor: Qt.alpha(ThemeBackend.surface1, 0.4)
    property color borderColor: "transparent"
    property int borderWidth: 0

    property real horizontalPadding: root.s(14)
    property real verticalPadding: root.s(12)
    property real spacing: root.s(12)
    property real innerSpacing: root.s(12)
    property real textSpacing: root.s(2)
    property real controlSpacing: root.s(8)
    property real bottomSpacing: root.s(12)

    property string icon: ""
    property bool showIcon: icon !== ""
    property int iconSize: 32
    property int iconFontSize: 16
    property int iconOffsetX: 0
    property int iconOffsetY: 0
    property real iconCornerRadius: ThemeBackend.borderRadius
    property color iconAccentColor: ThemeBackend.surface0
    property color iconTextColor: "#ffffff"
    property bool iconInteractive: false

    property string title: ""
    property string description: ""
    property string fontFamily: ThemeBackend.fontFamily
    property int titlePixelSize: 13
    property int descriptionPixelSize: 11
    property bool titleBold: false
    property color titleColor: ThemeBackend.text
    property color descriptionColor: ThemeBackend.subtext0
    property bool wrapText: false

    property Component titleBadge: null
    property Component customLeftContent: null

    property bool fillControlWidth: false
    property bool showDivider: false
    property color dividerColor: Qt.alpha(ThemeBackend.surface1, 0.3)

    property bool clickable: false
    property bool animateHeight: false
    property int animationDuration: 250

    signal clicked()
    signal rightClicked()
    signal iconClicked()

    default property alias content: controlRow.data
    property alias bottomContent: bottomCol.data

    radius: root.cornerRadius
    color: (root.clickable && cardMa.containsMouse) ? root.hoverColor : root.baseColor
    border.color: root.borderColor
    border.width: root.borderWidth
    clip: true

    implicitHeight: contentCol.implicitHeight + root.verticalPadding * 2

    Behavior on color { ColorAnimation { duration: 180 } }
    Behavior on border.color { ColorAnimation { duration: 180 } }
    Behavior on implicitHeight {
        enabled: root.animateHeight
        NumberAnimation { duration: root.animationDuration; easing.type: Easing.OutCubic }
    }

    MouseArea {
        id: cardMa
        anchors.fill: parent
        enabled: root.clickable && root.enabled
        hoverEnabled: root.clickable && root.enabled
        cursorShape: (root.clickable && root.enabled) ? Qt.PointingHandCursor : Qt.ArrowCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: -1
        onClicked: function(mouse) {
            if (mouse.button === Qt.RightButton) {
                root.rightClicked();
            } else {
                root.clicked();
            }
        }
    }

    ColumnLayout {
        id: contentCol
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.horizontalPadding
        anchors.rightMargin: root.horizontalPadding
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.innerSpacing

        RowLayout {
            id: mainRow
            Layout.fillWidth: true
            spacing: root.spacing

            IconButton {
                id: iconBtn
                visible: root.showIcon && root.icon !== ""
                enabled: root.iconInteractive
                size: root.s(root.iconSize)
                Layout.preferredWidth: visible ? root.s(root.iconSize) : 0
                Layout.preferredHeight: visible ? root.s(root.iconSize) : 0
                Layout.alignment: Qt.AlignVCenter
                cornerRadius: root.iconCornerRadius
                buttonIcon: root.icon
                iconFontSize: root.s(root.iconFontSize)
                iconOffsetX: root.s(root.iconOffsetX)
                iconOffsetY: root.s(root.iconOffsetY)
                accentColor: root.iconAccentColor
                textColor: root.iconTextColor
                onClicked: root.iconClicked()
            }

            Loader {
                id: leftCustomLoader
                active: root.customLeftContent !== null
                sourceComponent: root.customLeftContent
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                visible: active
            }

            ColumnLayout {
                id: textCol
                visible: !leftCustomLoader.active && (root.title !== "" || root.description !== "" || titleBadgeLoader.active)
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                Layout.alignment: Qt.AlignVCenter
                spacing: root.textSpacing

                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.s(6)
                    visible: root.title !== "" || titleBadgeLoader.active

                    Text {
                        Layout.fillWidth: !titleBadgeLoader.active
                        text: root.title
                        font.family: root.fontFamily
                        font.pixelSize: root.s(root.titlePixelSize)
                        font.bold: root.titleBold
                        color: root.titleColor
                        elide: root.wrapText ? Text.ElideNone : Text.ElideRight
                        wrapMode: root.wrapText ? Text.WordWrap : Text.NoWrap
                        visible: text !== ""
                    }

                    Loader {
                        id: titleBadgeLoader
                        active: root.titleBadge !== null
                        sourceComponent: root.titleBadge
                        Layout.alignment: Qt.AlignVCenter
                        visible: active
                    }

                    Item {
                        Layout.fillWidth: true
                        visible: titleBadgeLoader.active
                    }
                }

                Text {
                    Layout.fillWidth: true
                    text: root.description
                    font.family: root.fontFamily
                    font.pixelSize: root.s(root.descriptionPixelSize)
                    color: root.descriptionColor
                    elide: root.wrapText ? Text.ElideNone : Text.ElideRight
                    wrapMode: root.wrapText ? Text.WordWrap : Text.NoWrap
                    visible: text !== ""
                }
            }

            Item {
                Layout.fillWidth: true
                visible: !root.fillControlWidth && !textCol.visible && !leftCustomLoader.active
            }

            RowLayout {
                id: controlRow
                Layout.fillWidth: root.fillControlWidth
                Layout.alignment: root.fillControlWidth ? Qt.AlignVCenter : (Qt.AlignRight | Qt.AlignVCenter)
                spacing: root.controlSpacing
            }
        }

        Rectangle {
            id: dividerLine
            Layout.fillWidth: true
            height: 1
            color: root.dividerColor
            visible: root.showDivider && bottomCol.children.length > 0
        }

        ColumnLayout {
            id: bottomCol
            Layout.fillWidth: true
            spacing: root.bottomSpacing
            visible: children.length > 0
        }
    }
}
