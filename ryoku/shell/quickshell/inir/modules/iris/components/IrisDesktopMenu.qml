pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import inir
import inir.services
import inir.modules.common
import inir.modules.common.functions
import inir.modules.common.widgets
import inir.modules.iris.style

Loader {
    id: root

    property var model: []
    property Item anchorItem: parent
    readonly property real d: IrisStyle.density

    function requestOpen(): void {
        if (GlobalStates.activeContextMenu && GlobalStates.activeContextMenu !== root)
            GlobalStates.activeContextMenu.active = false
        if (root.active && root.item) root.item.reopen()
        root.active = true
    }
    function close(): void {
        if (root.item) root.item.dismiss()
        else root.active = false
    }

    active: false
    onActiveChanged: {
        if (active) {
            GlobalStates.activeContextMenu = root
            GlobalStates.activeContextMenuCount++
        } else {
            if (GlobalStates.activeContextMenu === root) GlobalStates.activeContextMenu = null
            GlobalStates.activeContextMenuCount--
        }
    }

    sourceComponent: PopupWindow {
        id: popup
        visible: true
        grabFocus: CompositorService.nativeOverview
        color: "transparent"
        onClosed: if (root.active) root.active = false

        readonly property real margin: Math.round(10 * root.d)
        implicitWidth: Math.round(menu.width + popup.margin * 2)
        implicitHeight: Math.round(menu.height + popup.margin * 2)
        mask: Region { item: menu }

        anchor {
            item: root.anchorItem
            rect.width: 1
            rect.height: 1
            edges: Edges.Top | Edges.Left
            gravity: Edges.Bottom | Edges.Right
            adjustment: PopupAdjustment.FlipX | PopupAdjustment.FlipY | PopupAdjustment.SlideX | PopupAdjustment.SlideY
        }

        readonly property var stops: {
            const list = []
            ;(root.model ?? []).forEach((entry, index) => {
                if (entry?.type === "quick") (entry.items ?? []).forEach((tile, t) => list.push({ entry: index, tile: t }))
                else if (entry?.type !== "separator" && entry?.type !== "place" && entry?.enabled !== false) list.push({ entry: index, tile: -1 })
            })
            return list
        }
        property int stop: -1
        function isStop(entry: int, tile: int): bool {
            const s = popup.stops[popup.stop]
            return s !== undefined && s.entry === entry && s.tile === tile
        }
        function focusStop(entry: int, tile: int): void {
            popup.stop = popup.stops.findIndex(s => s.entry === entry && s.tile === tile)
        }
        function run(action): void {
            popup.dismiss()
            if (action) action()
        }
        function runStop(): void {
            const s = popup.stops[popup.stop]
            if (!s) return
            const entry = root.model[s.entry]
            popup.run(s.tile >= 0 ? entry.items[s.tile].action : entry.action)
        }

        function reopen(): void { menu.open = false; Qt.callLater(() => { menu.open = true; popup.stop = -1 }) }
        function dismiss(): void { menu.open = false }

        Item {
            id: keys
            anchors.fill: parent
            focus: true
            Component.onCompleted: Qt.callLater(() => keys.forceActiveFocus())
            Keys.onPressed: event => {
                const count = popup.stops.length
                if (event.key === Qt.Key_Escape) popup.dismiss()
                else if (count > 0 && (event.key === Qt.Key_Down || event.key === Qt.Key_Tab || event.key === Qt.Key_Right))
                    popup.stop = (popup.stop + 1) % count
                else if (count > 0 && (event.key === Qt.Key_Up || event.key === Qt.Key_Backtab || event.key === Qt.Key_Left))
                    popup.stop = (popup.stop - 1 + count) % count
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) popup.runStop()
                else return
                event.accepted = true
            }
        }

        IrisMorphSurface {
            motionSurface: "menus"
            id: menu
            open: true
            origin: ({ x: popup.margin, y: popup.margin, width: Math.round(28 * root.d), height: Math.round(28 * root.d), radius: IrisStyle.radiusTile })
            contentReady: column.implicitHeight > 0
            radius: IrisStyle.surfaceRadius("menus", IrisStyle.radiusCard)
            x: popup.margin
            y: popup.margin
            width: Math.round(Math.max(236 * root.d, column.implicitWidth + 12 * root.d))
            height: Math.round(column.implicitHeight + 12 * root.d)
            onClosed: if (!menu.open) root.active = false

            Rectangle {
                anchors.fill: parent
                radius: menu.radius
                color: "transparent"
                border.width: 1
                border.color: IrisStyle.border
                z: 10
            }

            ColumnLayout {
                id: column
                x: Math.round(6 * root.d)
                y: Math.round(6 * root.d)
                width: menu.width - Math.round(12 * root.d)
                spacing: Math.round(2 * root.d)

                Repeater {
                    model: root.model
                    delegate: Loader {
                        id: row
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        sourceComponent: row.modelData?.type === "separator" ? separatorComponent
                            : row.modelData?.type === "quick" ? quickComponent
                            : row.modelData?.type === "place" ? placeComponent : itemComponent

                        Component {
                            id: placeComponent
                            Item {
                                implicitHeight: picker.height + Math.round(10 * root.d)
                                IrisPlacePicker {
                                    id: picker
                                    anchors.centerIn: parent
                                    place: String(row.modelData?.place ?? "")
                                    fx: Number(row.modelData?.fx ?? 0.5)
                                    fy: Number(row.modelData?.fy ?? 0.5)
                                    hasIsland: row.modelData?.hasIsland === true
                                    label: String(row.modelData?.label ?? "")
                                    onPlaced: zone => popup.run(() => row.modelData.action(zone))
                                    onPlacedFree: (x, y) => popup.run(() => row.modelData.freeAction(x, y))
                                }
                            }
                        }

                        Component {
                            id: separatorComponent
                            Item {
                                implicitHeight: Math.round(13 * root.d)
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: Math.round(12 * root.d)
                                    width: parent.width - Math.round(24 * root.d)
                                    height: 1
                                    color: IrisStyle.hairlineStrong
                                }
                            }
                        }

                        Component {
                            id: quickComponent
                            RowLayout {
                                spacing: Math.round(6 * root.d)
                                Repeater {
                                    model: row.modelData.items ?? []
                                    MouseArea {
                                        id: tile
                                        required property var modelData
                                        required property int index
                                        readonly property bool accent: tile.modelData.accent === true
                                        readonly property bool lit: popup.isStop(row.index, tile.index)
                                        readonly property string image: String(tile.modelData.image ?? "")
                                        Layout.fillWidth: true
                                        implicitWidth: Math.round(70 * root.d)
                                        implicitHeight: Math.round(62 * root.d)
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        Accessible.role: Accessible.Button
                                        Accessible.name: tile.modelData.text ?? ""
                                        onContainsMouseChanged: if (containsMouse) popup.focusStop(row.index, tile.index)
                                        onClicked: popup.run(tile.modelData.action)
                                        ClippingRectangle {
                                            anchors.fill: parent
                                            radius: IrisStyle.radiusTile
                                            scale: tile.pressed ? IrisStyle.pressScale(0.95) : 1
                                            color: tile.accent
                                                ? (tile.lit ? Qt.lighter(IrisStyle.accent, 1.08) : IrisStyle.accent)
                                                : (tile.lit ? IrisStyle.fillHover : IrisStyle.fillQuiet)
                                            Behavior on color { ColorAnimation { duration: IrisStyle.duration(110) } }
                                            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration } }
                                            Image {
                                                anchors.fill: parent
                                                visible: tile.image.length > 0 && status === Image.Ready
                                                source: tile.image.length > 0 ? "file://" + tile.image.replace(/^file:\/\//, "") : ""
                                                sourceSize.width: Math.round(parent.width * 2)
                                                fillMode: Image.PreserveAspectCrop
                                                asynchronous: true
                                                cache: false
                                            }
                                            Rectangle {
                                                anchors.fill: parent
                                                visible: tile.image.length > 0
                                                color: IrisStyle.mediaScrim
                                            }
                                        }
                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            width: parent.width - Math.round(8 * root.d)
                                            spacing: Math.round(4 * root.d)
                                            MaterialSymbol {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: tile.modelData.iconName ?? ""
                                                fill: 1
                                                iconSize: Math.round(20 * root.d)
                                                color: tile.accent ? IrisStyle.onAccent : tile.image.length > 0 ? IrisStyle.onMedia : IrisStyle.text
                                            }
                                            IrisText {
                                                Layout.fillWidth: true
                                                horizontalAlignment: Text.AlignHCenter
                                                text: tile.modelData.text ?? ""
                                                color: tile.accent ? IrisStyle.onAccent : tile.image.length > 0 ? IrisStyle.onMedia : IrisStyle.text
                                                font.pixelSize: 11 * IrisStyle.typeScale
                                                font.weight: Font.DemiBold
                                                elide: Text.ElideRight
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Component {
                            id: itemComponent
                            MouseArea {
                                id: menuItem
                                readonly property bool usable: row.modelData?.enabled !== false
                                readonly property bool lit: menuItem.usable && popup.isStop(row.index, -1)
                                readonly property bool danger: row.modelData?.danger === true
                                implicitWidth: itemRow.implicitWidth + Math.round(24 * root.d)
                                implicitHeight: Math.round(34 * root.d)
                                enabled: menuItem.usable
                                opacity: menuItem.usable ? 1 : 0.4
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                Accessible.role: Accessible.MenuItem
                                Accessible.name: row.modelData?.text ?? ""
                                onContainsMouseChanged: if (containsMouse) popup.focusStop(row.index, -1)
                                onClicked: popup.run(row.modelData?.action)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: IrisStyle.radiusRow
                                    color: menuItem.danger
                                        ? (menuItem.lit ? IrisStyle.tintFill(IrisStyle.danger) : ColorUtils.applyAlpha(IrisStyle.danger, 0))
                                        : (menuItem.lit ? IrisStyle.tintFill(IrisStyle.accent) : ColorUtils.applyAlpha(IrisStyle.accent, 0))
                                    Behavior on color { ColorAnimation { duration: IrisStyle.duration(90) } }
                                }
                                RowLayout {
                                    id: itemRow
                                    anchors.fill: parent
                                    anchors.leftMargin: Math.round(10 * root.d)
                                    anchors.rightMargin: Math.round(12 * root.d)
                                    spacing: Math.round(10 * root.d)
                                    MaterialSymbol {
                                        Layout.preferredWidth: Math.round(20 * root.d)
                                        horizontalAlignment: Text.AlignHCenter
                                        text: row.modelData?.iconName ?? ""
                                        iconSize: Math.round(17 * root.d)
                                        color: menuItem.danger ? IrisStyle.danger : menuItem.lit ? IrisStyle.text : IrisStyle.subtext
                                    }
                                    IrisText {
                                        Layout.fillWidth: true
                                        text: row.modelData?.text ?? ""
                                        color: menuItem.danger ? IrisStyle.danger : IrisStyle.text
                                        font.pixelSize: 13 * IrisStyle.typeScale
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                    }
                                    IrisText {
                                        visible: text.length > 0
                                        text: String(row.modelData?.detail ?? "")
                                        color: IrisStyle.muted
                                        font.pixelSize: 12 * IrisStyle.typeScale
                                        font.weight: Font.DemiBold
                                        font.family: IrisStyle.fontNumbers
                                        font.features: ({ "tnum": 1 })
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
