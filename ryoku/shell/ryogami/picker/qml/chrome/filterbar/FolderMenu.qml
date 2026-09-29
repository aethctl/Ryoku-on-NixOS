import QtQuick
import Ryoku.Ui.Singletons

// folder is prefix-matched: "*" all, "" the root, "a/b" that branch.
Item {
    id: fm

    required property LibraryView view
    property string barStyle: "straight"
    property real railWidth: 0
    // The list opens upward only when the bar sits along the bottom edge.
    property bool menuUp: false
    readonly property real naturalWidth: trigger.implicitWidth

    readonly property bool engaged: fm.view && fm.view.folder !== "*" && fm.view.folder !== undefined
    visible: fm._folders.length > 0
    width: visible ? trigger.width : 0
    implicitHeight: trigger.height

    property var _folders: []
    property bool _menuOpen: false

    function _rebuild() {
        fm._folders = (fm.view) ? Library.folders(fm.view.collection) : []
    }
    Component.onCompleted: fm._rebuild()
    onVisibleChanged: if (!visible) fm._menuOpen = false
    Connections {
        target: fm.view
        ignoreUnknownSignals: true
        function onCollectionChanged() { fm._rebuild() }
    }
    Connections {
        target: Library
        function onChanged(collection) {
            if (fm.view && collection === fm.view.collection) fm._rebuild()
        }
    }

    function _label() {
        if (!fm.view) return I18n.tr("Main")
        var f = fm.view.folder
        if (f === "*") return I18n.tr("All folders")
        if (f === "" || f === undefined) return I18n.tr("Main")
        return f
    }

    function _pick(value) {
        if (fm.view) fm.view.folder = value
        fm._menuOpen = false
    }

    BarButton {
        id: trigger
        barStyle: fm.barStyle
        railWidth: fm.railWidth
        glyph: "\u{f024b}"
        label: fm._label() + "  \u25be"
        active: fm.engaged
        onTriggered: fm._menuOpen = !fm._menuOpen
    }

    Timer { id: closeTimer; interval: 350; onTriggered: fm._menuOpen = false }

    Rectangle {
        id: panel
        visible: opacity > 0.01
        opacity: fm._menuOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.fast; easing.type: Theme.revealEasing } }
        z: 60
        x: trigger.x + (trigger.width - width) * 0.5
        y: fm.menuUp ? trigger.y - height - 6 * Theme.scale : trigger.y + trigger.height + 6 * Theme.scale
        width: 180 * Theme.scale
        height: Math.min(list.implicitHeight + 8 * Theme.scale, 12 * 26 * Theme.scale + 8 * Theme.scale)
        clip: true
        color: Theme.withAlpha(Theme.surface, 0.98)
        border.width: 1
        border.color: Theme.withAlpha(Theme.primary, 0.40)

        HoverHandler { id: panelHover }
        onVisibleChanged: if (visible) closeTimer.stop()

        Flickable {
            anchors.fill: parent
            anchors.margins: 4 * Theme.scale
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list
                width: parent.width
                spacing: 1 * Theme.scale

                Repeater {
                    model: {
                        var base = [{ label: I18n.tr("All folders"), value: "*" },
                                    { label: I18n.tr("Main"), value: "" }]
                        for (var i = 0; i < fm._folders.length; ++i)
                            base.push({ label: fm._folders[i], value: fm._folders[i] })
                        return base
                    }
                    delegate: Item {
                        id: row
                        required property var modelData
                        width: list.width
                        height: 26 * Theme.scale
                        readonly property bool selected: fm.view && fm.view.folder === modelData.value
                        readonly property bool hovered: rowMouse.containsMouse

                        Rectangle {
                            anchors.fill: parent
                            color: row.selected ? Theme.withAlpha(Theme.primary, 0.16)
                                 : row.hovered ? Theme.withAlpha(Theme.primary, 0.08)
                                 : "transparent"
                        }
                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 10 * Theme.scale
                            anchors.right: parent.right
                            anchors.rightMargin: 8 * Theme.scale
                            anchors.verticalCenter: parent.verticalCenter
                            text: row.modelData.label
                            elide: Text.ElideLeft
                            font.family: Theme.ui
                            font.weight: Theme.uiWeight
                            font.pixelSize: Theme.fontBase
                            color: row.selected ? Theme.primary : Theme.surfaceText
                            renderType: Text.NativeRendering
                        }
                        MouseArea {
                            id: rowMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: fm._pick(row.modelData.value)
                        }
                    }
                }
            }
        }
    }

    HoverHandler { id: triggerHover }

    Connections {
        target: triggerHover
        function onHoveredChanged() { fm._maybeClose() }
    }
    Connections {
        target: panelHover
        function onHoveredChanged() { fm._maybeClose() }
    }
    function _maybeClose() {
        if (!fm._menuOpen) return
        if (triggerHover.hovered || panelHover.hovered) closeTimer.stop()
        else closeTimer.restart()
    }
}
