import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: dl

    required property PickerState state
    property string barStyle: "straight"
    property real railWidth: 0
    // The list opens upward only when the bar sits along the bottom edge.
    property bool menuUp: false
    readonly property real naturalWidth: trigger.implicitWidth

    width: trigger.width
    implicitHeight: trigger.height

    property bool _menuOpen: false

    readonly property var _providers: [
        { key: "wallhaven", label: I18n.tr("Wallhaven"), glyph: "\uf03e" },
        { key: "steam", label: I18n.tr("Steam Workshop"), glyph: "\uf1b6" },
        { key: "unsplash", label: I18n.tr("Unsplash"), glyph: "\uf030" },
        { key: "pexels", label: I18n.tr("Pexels"), glyph: "\uf083" },
        { key: "youtube", label: I18n.tr("YouTube"), glyph: "\uf16a" },
        { key: "bing", label: I18n.tr("Bing Daily"), glyph: "\uf002" },
        { key: "moewalls", label: I18n.tr("MoeWalls"), glyph: "\uf008" },
        { key: "motionbgs", label: I18n.tr("MotionBGs"), glyph: "\uf008" },
        { key: "ryostore", label: I18n.tr("Ryostore"), glyph: "\uf290" }
    ]

    function _open(provider) {
        if (dl.state) dl.state.openBrowser(provider)
        dl._menuOpen = false
    }

    BarButton {
        id: trigger
        barStyle: dl.barStyle
        railWidth: dl.railWidth
        glyph: "\u{f01da}"
        label: I18n.tr("Download") + "  \u25be"
        prominent: true
        onTriggered: dl._menuOpen = !dl._menuOpen
    }

    Timer { id: closeTimer; interval: 350; onTriggered: dl._menuOpen = false }

    Rectangle {
        id: panel
        visible: opacity > 0.01
        opacity: dl._menuOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fast; easing.type: Theme.revealEasing } }
        z: 60
        x: trigger.x + (trigger.width - width) * 0.5
        y: dl.menuUp ? trigger.y - height - 6 * Theme.scale : trigger.y + trigger.height + 6 * Theme.scale
        width: 190 * Theme.scale
        height: list.implicitHeight + 8 * Theme.scale
        color: Theme.withAlpha(Theme.surface, 0.98)
        border.width: 1
        border.color: Theme.withAlpha(Theme.primary, 0.40)

        HoverHandler { id: panelHover }

        Column {
            id: list
            width: parent.width - 8 * Theme.scale
            x: 4 * Theme.scale
            y: 4 * Theme.scale
            spacing: 1 * Theme.scale

            Repeater {
                model: dl._providers
                delegate: Item {
                    id: row
                    required property var modelData
                    width: list.width
                    height: 28 * Theme.scale
                    readonly property bool hovered: rowMouse.containsMouse

                    Rectangle {
                        anchors.fill: parent
                        color: row.hovered ? Theme.withAlpha(Theme.primary, 0.10) : "transparent"
                    }
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10 * Theme.scale
                        anchors.right: parent.right
                        anchors.rightMargin: 8 * Theme.scale
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 9 * Theme.scale
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.glyph
                            font.family: Theme.icon
                            font.pixelSize: Theme.fontBody
                            color: row.hovered ? Theme.primary : Theme.withAlpha(Theme.surfaceText, 0.8)
                            renderType: Text.NativeRendering
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.label
                            font.family: Theme.ui
                            font.weight: Theme.uiWeight
                            font.pixelSize: Theme.fontBase
                            color: Theme.surfaceText
                            renderType: Text.NativeRendering
                        }
                    }
                    MouseArea {
                        id: rowMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dl._open(row.modelData.key)
                    }
                }
            }
        }
    }

    HoverHandler { id: triggerHover }

    Connections {
        target: triggerHover
        function onHoveredChanged() { dl._maybeClose() }
    }
    Connections {
        target: panelHover
        function onHoveredChanged() { dl._maybeClose() }
    }
    function _maybeClose() {
        if (!dl._menuOpen) return
        if (triggerHover.hovered || panelHover.hovered) closeTimer.stop()
        else closeTimer.restart()
    }
}
