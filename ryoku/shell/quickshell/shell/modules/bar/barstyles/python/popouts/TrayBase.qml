import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import shell.services
import "../reusables"
import "../"

PanelWindow {
    id: trayMenuWindow

    screen: TrayMenuController.screen

    WlrLayershell.namespace: "traymenu"
    WlrLayershell.layer: WlrLayer.Overlay
    focusable: false
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    mask: Region {
        Region {
            item: (trayMenuWindow.isVisible || menuContainer.animProgress > 0.001) ? menuContainer : null
        }
        Region {
            item: (trayMenuWindow.isVisible || menuContainer.animProgress > 0.001) && submenuRepeater.count > 0 && submenuRepeater.itemAt(0) ? submenuRepeater.itemAt(0) : null
        }
        Region {
            item: (trayMenuWindow.isVisible || menuContainer.animProgress > 0.001) && submenuRepeater.count > 1 && submenuRepeater.itemAt(1) ? submenuRepeater.itemAt(1) : null
        }
        Region {
            item: (trayMenuWindow.isVisible || menuContainer.animProgress > 0.001) && submenuRepeater.count > 2 && submenuRepeater.itemAt(2) ? submenuRepeater.itemAt(2) : null
        }
        Region {
            item: (trayMenuWindow.isVisible || menuContainer.animProgress > 0.001) && submenuRepeater.count > 3 && submenuRepeater.itemAt(3) ? submenuRepeater.itemAt(3) : null
        }
    }

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    function s(val) { return (typeof Scaler !== "undefined") ? Scaler.s(val) : val; }

    property bool isVisible: TrayMenuController.isVisible
    property string activeItemId: TrayMenuController.activeItemId
    property real targetX: TrayMenuController.targetX
    property real targetY: TrayMenuController.targetY
    property bool alignRight: TrayMenuController.alignRight
    property bool alignBottom: TrayMenuController.alignBottom
    property bool isSideBar: TrayMenuController.isSideBar

    property int configRevision: 0

    Connections {
        target: (typeof Config !== "undefined") ? Config : null
        function onSettingsLoaded() {
            TrayMenuController.hide();
            trayMenuWindow.configRevision++;
        }
    }

    property string barStyle: {
        let dummy = configRevision;
        if (typeof Config === "undefined" || !Config.rawSettings || !Config.rawSettings.bar) return "modular";
        let s = Config.rawSettings.bar.style;
        if (typeof s === "string") return s;
        if (s && typeof s === "object") {
            if (s.fill || s.mode === "fill") return "fill";
            if (s.solid || s.mode === "solid") return "solid";
        }
        return "modular";
    }

    onBarStyleChanged: {
        TrayMenuController.hide();
    }

    property bool isFill: barStyle === "fill"
    property bool isSolid: barStyle === "solid" || barStyle === "fill"

    property real barHeight: {
        let dummy = configRevision;
        return (typeof Config !== "undefined" && Config.rawSettings && Config.rawSettings.bar && Config.rawSettings.bar.height) ? s(Config.rawSettings.bar.height) : s(40);
    }

    property real cornerRadius: {
        let dummy = configRevision;
        let raw = (typeof ThemeBackend !== "undefined" && ThemeBackend.borderRadius !== undefined && ThemeBackend.borderRadius !== null)
            ? ThemeBackend.borderRadius
            : s(12);
        let threshold = s(32);
        let maxLimit = s(44);
        if (raw <= threshold) {
            return Math.max(0, raw);
        }
        let excess = raw - threshold;
        let range = maxLimit - threshold;
        return threshold + range * (1.0 - Math.exp(-excess / range));
    }

    property real menuMargin: isSolid ? 0 : s(20)

    visible: isVisible || menuContainer.animProgress > 0.001

    function closeMenu() {
        clearSubmenus();
        TrayMenuController.hide();
    }

    // Ryoku seam: the daemon (shell.services Tray) is the StatusNotifier host;
    // items and their dbusmenu trees arrive as JSON, keyed by service.
    property var activeItem: {
        if (!activeItemId && activeItemId !== 0) return null;
        let list = Tray.items;
        for (let i = 0; i < list.length; i++) {
            if (list[i] && String(list[i].service) === String(activeItemId))
                return list[i];
        }
        return null;
    }

    onActiveItemChanged: {
        clearSubmenus();
        if (!activeItem && isVisible) {
            TrayMenuController.hide();
        }
    }

    onIsVisibleChanged: {
        if (!isVisible) {
            clearSubmenus();
        } else if (!activeItem) {
            TrayMenuController.hide();
        } else {
            Tray.aboutToShow(activeItem.service);
        }
    }

    property var activeMenu: (trayMenuWindow.activeItem && trayMenuWindow.activeItem.menu) ? trayMenuWindow.activeItem.menu : null

    function cleanLabel(t) {
        if (!t) return "";
        return String(t).replace(/_([^_])/g, "$1").replace(/__/g, "_");
    }

    function rowsFor(node) {
        let out = [];
        let kids = (node && Array.isArray(node.children)) ? node.children : [];
        for (let i = 0; i < kids.length; i++) {
            let c = kids[i];
            if (!c || c.visible === false) continue;
            let sep = c.type === "separator";
            out.push({
                id: c.id,
                label: trayMenuWindow.cleanLabel(c.label),
                type: c.type || "",
                enabled: c.enabled !== false,
                hasChildren: !sep && Array.isArray(c.children) && c.children.length > 0,
                iconName: c.iconName || "",
                node: c
            });
        }
        return out;
    }

    property real menuWidth: s(200)
    property real itemHeight: s(32)

    readonly property var rootRows: activeMenu ? rowsFor(activeMenu) : []

    property real rawHeight: (rootRows.length * itemHeight) + s(16)
    property real targetMenuHeight: Math.max(s(40), rawHeight)
    property real menuHeight: targetMenuHeight

    Behavior on menuHeight {
        enabled: trayMenuWindow.isVisible && menuContainer.animProgress > 0.95
        NumberAnimation {
            duration: 220
            easing.type: Easing.OutCubic
        }
    }

    property real clampedX: {
        let w = menuWidth;
        let x = 0;
        if (isSideBar) {
            if (alignRight) {
                let barEdge = (targetX > trayMenuWindow.width / 2) ? targetX : (trayMenuWindow.width - barHeight);
                x = isSolid ? (trayMenuWindow.width - barHeight - w) : (barEdge - w - menuMargin);
            } else {
                let barEdge = (targetX > 0 && targetX < trayMenuWindow.width / 2) ? targetX : barHeight;
                x = isSolid ? barHeight : (barEdge + menuMargin);
            }
        } else {
            x = targetX - (w / 2);
        }
        let edgeBound = (isSolid && !isSideBar) ? (cornerRadius + s(4)) : s(8);
        return Math.max(edgeBound, Math.min(trayMenuWindow.width - w - edgeBound, x));
    }

    property real clampedY: {
        let h = menuHeight;
        let y = 0;
        if (isSideBar) {
            y = targetY - (h / 2);
        } else {
            if (alignBottom) {
                let barEdge = (targetY > trayMenuWindow.height / 2) ? targetY : (trayMenuWindow.height - barHeight);
                y = isSolid ? (trayMenuWindow.height - barHeight - h) : (barEdge - h - menuMargin);
            } else {
                let barEdge = (targetY > 0 && targetY < trayMenuWindow.height / 2) ? targetY : barHeight;
                y = isSolid ? barHeight : (barEdge + menuMargin);
            }
        }
        let edgeBound = (isSolid && isSideBar) ? (cornerRadius + s(4)) : s(8);
        return Math.max(edgeBound, Math.min(trayMenuWindow.height - h - edgeBound, y));
    }

    readonly property bool rootExpandRight: {
        if (isSideBar) {
            return !alignRight;
        }
        return (clampedX + menuWidth / 2) < (trayMenuWindow.width / 2);
    }

    property var submenuStack: []

    function openSubmenu(level, itemData, gx, gy, gw, gh) {
        if (!itemData) return;
        let newStack = submenuStack.slice(0, level);
        newStack.push({
            "menu": itemData,
            "node": itemData.node,
            "parentX": gx,
            "parentY": gy,
            "parentWidth": gw,
            "parentHeight": gh,
            "level": level
        });
        submenuStack = newStack;
    }

    function closeSubmenusFrom(level) {
        if (submenuStack.length > level) {
            submenuStack = submenuStack.slice(0, level);
        }
    }

    function clearSubmenus() {
        submenuStack = [];
    }

    Item {
        id: rootContainer
        anchors.fill: parent

        Item {
            id: menuContainer

            property real animProgress: trayMenuWindow.isVisible ? 1.0 : 0.0
            Behavior on animProgress {
                NumberAnimation {
                    duration: trayMenuWindow.isVisible ? 280 : 220
                    easing.type: Easing.OutCubic
                }
            }

            property real dynamicCornerRadius: trayMenuWindow.isSolid ? Math.max(0, Math.min(trayMenuWindow.cornerRadius, (trayMenuWindow.isSideBar ? width : height))) : 0

            x: {
                if (trayMenuWindow.isSolid) {
                    if (trayMenuWindow.isSideBar) {
                        if (trayMenuWindow.alignRight) {
                            return trayMenuWindow.clampedX + (trayMenuWindow.menuWidth - width);
                        }
                        return trayMenuWindow.clampedX;
                    }
                    return trayMenuWindow.clampedX;
                }
                let slideOffset = trayMenuWindow.s(16) * (1.0 - animProgress);
                if (trayMenuWindow.isSideBar) {
                    return trayMenuWindow.alignRight ? (trayMenuWindow.clampedX + slideOffset) : (trayMenuWindow.clampedX - slideOffset);
                }
                return trayMenuWindow.clampedX;
            }

            y: {
                if (trayMenuWindow.isSolid) {
                    if (!trayMenuWindow.isSideBar) {
                        if (trayMenuWindow.alignBottom) {
                            return trayMenuWindow.clampedY + (trayMenuWindow.menuHeight - height);
                        }
                        return trayMenuWindow.clampedY;
                    }
                    return trayMenuWindow.clampedY;
                }
                let slideOffset = trayMenuWindow.s(16) * (1.0 - animProgress);
                if (!trayMenuWindow.isSideBar) {
                    return trayMenuWindow.alignBottom ? (trayMenuWindow.clampedY + slideOffset) : (trayMenuWindow.clampedY - slideOffset);
                }
                return trayMenuWindow.clampedY;
            }

            width: {
                if (trayMenuWindow.isSolid && trayMenuWindow.isSideBar) {
                    return trayMenuWindow.menuWidth * animProgress;
                }
                return trayMenuWindow.menuWidth;
            }

            height: {
                if (trayMenuWindow.isSolid && !trayMenuWindow.isSideBar) {
                    return trayMenuWindow.menuHeight * animProgress;
                }
                return trayMenuWindow.menuHeight;
            }

            opacity: animProgress
            scale: !trayMenuWindow.isSolid ? (0.92 + (0.08 * animProgress)) : 1.0

            transformOrigin: {
                if (trayMenuWindow.isSideBar) {
                    return trayMenuWindow.alignRight ? Item.Right : Item.Left;
                }
                return trayMenuWindow.alignBottom ? Item.Bottom : Item.Top;
            }

            Shape {
                visible: trayMenuWindow.isSolid && !trayMenuWindow.isSideBar && !trayMenuWindow.alignBottom && menuContainer.dynamicCornerRadius > 0.5
                x: -menuContainer.dynamicCornerRadius
                y: 0
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: ThemeBackend.base
                    strokeColor: "transparent"
                    startX: 0
                    startY: 0
                    PathLine { x: menuContainer.dynamicCornerRadius; y: 0 }
                    PathLine { x: menuContainer.dynamicCornerRadius; y: menuContainer.dynamicCornerRadius }
                    PathArc {
                        x: 0
                        y: 0
                        radiusX: menuContainer.dynamicCornerRadius
                        radiusY: menuContainer.dynamicCornerRadius
                        direction: PathArc.Counterclockwise
                    }
                }
            }

            Shape {
                visible: trayMenuWindow.isSolid && !trayMenuWindow.isSideBar && !trayMenuWindow.alignBottom && menuContainer.dynamicCornerRadius > 0.5
                x: parent.width
                y: 0
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: ThemeBackend.base
                    strokeColor: "transparent"
                    startX: menuContainer.dynamicCornerRadius
                    startY: 0
                    PathLine { x: 0; y: 0 }
                    PathLine { x: 0; y: menuContainer.dynamicCornerRadius }
                    PathArc {
                        x: menuContainer.dynamicCornerRadius
                        y: 0
                        radiusX: menuContainer.dynamicCornerRadius
                        radiusY: menuContainer.dynamicCornerRadius
                        direction: PathArc.Clockwise
                    }
                }
            }

            Shape {
                visible: trayMenuWindow.isSolid && !trayMenuWindow.isSideBar && trayMenuWindow.alignBottom && menuContainer.dynamicCornerRadius > 0.5
                x: -menuContainer.dynamicCornerRadius
                y: parent.height - menuContainer.dynamicCornerRadius
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: ThemeBackend.base
                    strokeColor: "transparent"
                    startX: 0
                    startY: menuContainer.dynamicCornerRadius
                    PathLine { x: menuContainer.dynamicCornerRadius; y: menuContainer.dynamicCornerRadius }
                    PathLine { x: menuContainer.dynamicCornerRadius; y: 0 }
                    PathArc {
                        x: 0
                        y: menuContainer.dynamicCornerRadius
                        radiusX: menuContainer.dynamicCornerRadius
                        radiusY: menuContainer.dynamicCornerRadius
                        direction: PathArc.Clockwise
                    }
                }
            }

            Shape {
                visible: trayMenuWindow.isSolid && !trayMenuWindow.isSideBar && trayMenuWindow.alignBottom && menuContainer.dynamicCornerRadius > 0.5
                x: parent.width
                y: parent.height - menuContainer.dynamicCornerRadius
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: ThemeBackend.base
                    strokeColor: "transparent"
                    startX: menuContainer.dynamicCornerRadius
                    startY: menuContainer.dynamicCornerRadius
                    PathLine { x: 0; y: menuContainer.dynamicCornerRadius }
                    PathLine { x: 0; y: 0 }
                    PathArc {
                        x: menuContainer.dynamicCornerRadius
                        y: menuContainer.dynamicCornerRadius
                        radiusX: menuContainer.dynamicCornerRadius
                        radiusY: menuContainer.dynamicCornerRadius
                        direction: PathArc.Counterclockwise
                    }
                }
            }

            Shape {
                visible: trayMenuWindow.isSolid && trayMenuWindow.isSideBar && !trayMenuWindow.alignRight && menuContainer.dynamicCornerRadius > 0.5
                x: 0
                y: -menuContainer.dynamicCornerRadius
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: ThemeBackend.base
                    strokeColor: "transparent"
                    startX: 0
                    startY: 0
                    PathLine { x: 0; y: menuContainer.dynamicCornerRadius }
                    PathLine { x: menuContainer.dynamicCornerRadius; y: menuContainer.dynamicCornerRadius }
                    PathArc {
                        x: 0
                        y: 0
                        radiusX: menuContainer.dynamicCornerRadius
                        radiusY: menuContainer.dynamicCornerRadius
                        direction: PathArc.Clockwise
                    }
                }
            }

            Shape {
                visible: trayMenuWindow.isSolid && trayMenuWindow.isSideBar && !trayMenuWindow.alignRight && menuContainer.dynamicCornerRadius > 0.5
                x: 0
                y: parent.height
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: ThemeBackend.base
                    strokeColor: "transparent"
                    startX: 0
                    startY: menuContainer.dynamicCornerRadius
                    PathLine { x: 0; y: 0 }
                    PathLine { x: menuContainer.dynamicCornerRadius; y: 0 }
                    PathArc {
                        x: 0
                        y: menuContainer.dynamicCornerRadius
                        radiusX: menuContainer.dynamicCornerRadius
                        radiusY: menuContainer.dynamicCornerRadius
                        direction: PathArc.Counterclockwise
                    }
                }
            }

            Shape {
                visible: trayMenuWindow.isSolid && trayMenuWindow.isSideBar && trayMenuWindow.alignRight && menuContainer.dynamicCornerRadius > 0.5
                x: parent.width - menuContainer.dynamicCornerRadius
                y: -menuContainer.dynamicCornerRadius
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: ThemeBackend.base
                    strokeColor: "transparent"
                    startX: menuContainer.dynamicCornerRadius
                    startY: 0
                    PathLine { x: menuContainer.dynamicCornerRadius; y: menuContainer.dynamicCornerRadius }
                    PathLine { x: 0; y: menuContainer.dynamicCornerRadius }
                    PathArc {
                        x: menuContainer.dynamicCornerRadius
                        y: 0
                        radiusX: menuContainer.dynamicCornerRadius
                        radiusY: menuContainer.dynamicCornerRadius
                        direction: PathArc.Counterclockwise
                    }
                }
            }

            Shape {
                visible: trayMenuWindow.isSolid && trayMenuWindow.isSideBar && trayMenuWindow.alignRight && menuContainer.dynamicCornerRadius > 0.5
                x: parent.width - menuContainer.dynamicCornerRadius
                y: parent.height
                width: menuContainer.dynamicCornerRadius
                height: menuContainer.dynamicCornerRadius
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: ThemeBackend.base
                    strokeColor: "transparent"
                    startX: menuContainer.dynamicCornerRadius
                    startY: menuContainer.dynamicCornerRadius
                    PathLine { x: menuContainer.dynamicCornerRadius; y: 0 }
                    PathLine { x: 0; y: 0 }
                    PathArc {
                        x: menuContainer.dynamicCornerRadius
                        y: menuContainer.dynamicCornerRadius
                        radiusX: menuContainer.dynamicCornerRadius
                        radiusY: menuContainer.dynamicCornerRadius
                        direction: PathArc.Clockwise
                    }
                }
            }

            Rectangle {
                id: menuBox
                anchors.fill: parent
                color: ThemeBackend.base
                radius: trayMenuWindow.cornerRadius
                border.width: 0
                border.color: "transparent"
                clip: true

                Rectangle {
                    visible: trayMenuWindow.isSolid && !trayMenuWindow.isSideBar && !trayMenuWindow.alignBottom && menuContainer.dynamicCornerRadius > 0.5
                    x: 0
                    y: 0
                    width: menuContainer.dynamicCornerRadius
                    height: menuContainer.dynamicCornerRadius
                    color: ThemeBackend.base
                }

                Rectangle {
                    visible: trayMenuWindow.isSolid && !trayMenuWindow.isSideBar && !trayMenuWindow.alignBottom && menuContainer.dynamicCornerRadius > 0.5
                    x: parent.width - menuContainer.dynamicCornerRadius
                    y: 0
                    width: menuContainer.dynamicCornerRadius
                    height: menuContainer.dynamicCornerRadius
                    color: ThemeBackend.base
                }

                Rectangle {
                    visible: trayMenuWindow.isSolid && !trayMenuWindow.isSideBar && trayMenuWindow.alignBottom && menuContainer.dynamicCornerRadius > 0.5
                    x: 0
                    y: parent.height - menuContainer.dynamicCornerRadius
                    width: menuContainer.dynamicCornerRadius
                    height: menuContainer.dynamicCornerRadius
                    color: ThemeBackend.base
                }

                Rectangle {
                    visible: trayMenuWindow.isSolid && !trayMenuWindow.isSideBar && trayMenuWindow.alignBottom && menuContainer.dynamicCornerRadius > 0.5
                    x: parent.width - menuContainer.dynamicCornerRadius
                    y: parent.height - menuContainer.dynamicCornerRadius
                    width: menuContainer.dynamicCornerRadius
                    height: menuContainer.dynamicCornerRadius
                    color: ThemeBackend.base
                }

                Rectangle {
                    visible: trayMenuWindow.isSolid && trayMenuWindow.isSideBar && !trayMenuWindow.alignRight && menuContainer.dynamicCornerRadius > 0.5
                    x: 0
                    y: 0
                    width: menuContainer.dynamicCornerRadius
                    height: menuContainer.dynamicCornerRadius
                    color: ThemeBackend.base
                }

                Rectangle {
                    visible: trayMenuWindow.isSolid && trayMenuWindow.isSideBar && !trayMenuWindow.alignRight && menuContainer.dynamicCornerRadius > 0.5
                    x: 0
                    y: parent.height - menuContainer.dynamicCornerRadius
                    width: menuContainer.dynamicCornerRadius
                    height: menuContainer.dynamicCornerRadius
                    color: ThemeBackend.base
                }

                Rectangle {
                    visible: trayMenuWindow.isSolid && trayMenuWindow.isSideBar && trayMenuWindow.alignRight && menuContainer.dynamicCornerRadius > 0.5
                    x: parent.width - menuContainer.dynamicCornerRadius
                    y: 0
                    width: menuContainer.dynamicCornerRadius
                    height: menuContainer.dynamicCornerRadius
                    color: ThemeBackend.base
                }

                Rectangle {
                    visible: trayMenuWindow.isSolid && trayMenuWindow.isSideBar && trayMenuWindow.alignRight && menuContainer.dynamicCornerRadius > 0.5
                    x: parent.width - menuContainer.dynamicCornerRadius
                    y: parent.height - menuContainer.dynamicCornerRadius
                    width: menuContainer.dynamicCornerRadius
                    height: menuContainer.dynamicCornerRadius
                    color: ThemeBackend.base
                }

                HoverHandler {
                    id: menuHoverHandler
                    onHoveredChanged: {
                        TrayMenuController.menuHovered = hovered;
                        if (hovered) {
                            TrayMenuController.cancelHide();
                        } else {
                            TrayMenuController.requestHide();
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    preventStealing: true
                }

                ListView {
                    id: menuList
                    anchors.fill: parent
                    anchors.margins: trayMenuWindow.s(8)
                    model: trayMenuWindow.rootRows
                    clip: true
                    spacing: 0
                    cacheBuffer: 3000
                    interactive: contentHeight > height

                    delegate: Item {
                        id: rootItemDelegate
                        width: menuList.width
                        height: trayMenuWindow.itemHeight

                        property bool isSep: modelData ? modelData.type === "separator" : false
                        property bool hasChildren: modelData ? (modelData.hasChildren === true) : false

                        Rectangle {
                            anchors.fill: parent
                            visible: !rootItemDelegate.isSep
                            radius: trayMenuWindow.s(4)
                            color: itemMouse.containsMouse ? ThemeBackend.surface0 : "transparent"
                            opacity: (modelData && modelData.enabled) ? 1.0 : 0.4

                            Image {
                                id: itemIcon
                                anchors.left: parent.left
                                anchors.leftMargin: trayMenuWindow.s(8)
                                anchors.verticalCenter: parent.verticalCenter
                                width: (modelData && modelData.iconName && modelData.iconName !== "") ? trayMenuWindow.s(16) : 0
                                height: trayMenuWindow.s(16)
                                source: (modelData && modelData.iconName) ? Icons.path(modelData.iconName, true) : ""
                                sourceSize: Qt.size(trayMenuWindow.s(16), trayMenuWindow.s(16))
                                visible: width > 0
                            }

                            Text {
                                anchors.left: itemIcon.visible ? itemIcon.right : parent.left
                                anchors.leftMargin: trayMenuWindow.s(8)
                                anchors.right: arrowText.visible ? arrowText.left : parent.right
                                anchors.rightMargin: trayMenuWindow.s(8)
                                anchors.verticalCenter: parent.verticalCenter
                                text: (modelData && modelData.label) ? modelData.label : ""
                                color: ThemeBackend.text
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: trayMenuWindow.s(13)
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignVCenter
                            }

                            Text {
                                id: arrowText
                                anchors.right: parent.right
                                anchors.rightMargin: trayMenuWindow.s(8)
                                anchors.verticalCenter: parent.verticalCenter
                                visible: rootItemDelegate.hasChildren
                                text: trayMenuWindow.rootExpandRight ? "›" : "‹"
                                color: ThemeBackend.subtext0
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: trayMenuWindow.s(13)
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: modelData ? modelData.enabled : false
                                cursorShape: Qt.PointingHandCursor
                                onEntered: {
                                    TrayMenuController.cancelHide();
                                    TrayMenuController.menuHovered = true;
                                    if (rootItemDelegate.hasChildren) {
                                        let pos = rootItemDelegate.mapToItem(rootContainer, 0, 0);
                                        trayMenuWindow.openSubmenu(0, modelData, menuContainer.x, pos.y, menuContainer.width, rootItemDelegate.height);
                                    } else {
                                        trayMenuWindow.closeSubmenusFrom(0);
                                    }
                                }
                                onExited: {
                                    TrayMenuController.requestHide();
                                }
                                onClicked: {
                                    if (modelData && !modelData.hasChildren) {
                                        if (trayMenuWindow.activeItem)
                                            Tray.menuEvent(trayMenuWindow.activeItem.service, modelData.id);
                                        trayMenuWindow.closeMenu();
                                    } else if (modelData && modelData.hasChildren) {
                                        let pos = rootItemDelegate.mapToItem(rootContainer, 0, 0);
                                        trayMenuWindow.openSubmenu(0, modelData, menuContainer.x, pos.y, menuContainer.width, rootItemDelegate.height);
                                    }
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width - trayMenuWindow.s(16)
                            height: 1
                            color: ThemeBackend.surface0
                            anchors.centerIn: parent
                            visible: rootItemDelegate.isSep
                        }
                    }
                }
            }
        }

        Repeater {
            id: submenuRepeater
            model: trayMenuWindow.submenuStack.length

            Item {
                id: submenuPopout
                property int stackIndex: index
                property var stackData: (trayMenuWindow.submenuStack && trayMenuWindow.submenuStack.length > index) ? trayMenuWindow.submenuStack[index] : null

                property real parentItemX: stackData ? stackData.parentX : 0
                property real parentItemY: stackData ? stackData.parentY : 0
                property real parentItemWidth: stackData ? stackData.parentWidth : trayMenuWindow.menuWidth
                property real parentItemHeight: stackData ? stackData.parentHeight : trayMenuWindow.itemHeight

                property real subCornerRadius: trayMenuWindow.cornerRadius

                readonly property bool shouldExpandRight: {
                    if (trayMenuWindow.isSideBar) {
                        return !trayMenuWindow.alignRight;
                    }
                    return (parentItemX + parentItemWidth / 2) < (trayMenuWindow.width / 2);
                }

                readonly property bool expandRight: {
                    let w = trayMenuWindow.menuWidth;
                    let rightX = parentItemX + parentItemWidth;
                    let leftX = parentItemX - w;
                    if (shouldExpandRight) {
                        if (rightX + w > trayMenuWindow.width - trayMenuWindow.s(8) && leftX >= trayMenuWindow.s(8)) {
                            return false;
                        }
                        return true;
                    } else {
                        if (leftX < trayMenuWindow.s(8) && rightX + w <= trayMenuWindow.width - trayMenuWindow.s(8)) {
                            return true;
                        }
                        return false;
                    }
                }

                readonly property var subRows: (stackData && stackData.node) ? trayMenuWindow.rowsFor(stackData.node) : []

                property real subMenuRawHeight: (subRows.length * trayMenuWindow.itemHeight) + trayMenuWindow.s(16)
                property real subMenuTargetHeight: Math.max(trayMenuWindow.s(40), subMenuRawHeight)
                property real subMenuHeight: subMenuTargetHeight

                width: trayMenuWindow.menuWidth
                height: subMenuHeight

                property real popoutProgress: (trayMenuWindow.isVisible && menuContainer.animProgress > 0.001) ? 1.0 : 0.0
                Behavior on popoutProgress {
                    NumberAnimation {
                        duration: (trayMenuWindow.isVisible && menuContainer.animProgress > 0.001) ? 220 : 160
                        easing.type: Easing.OutCubic
                    }
                }

                visible: (trayMenuWindow.isVisible || menuContainer.animProgress > 0.001) && popoutProgress > 0.001

                x: {
                    let base = expandRight ? (parentItemX + parentItemWidth) : (parentItemX - width);
                    let slide = trayMenuWindow.s(10) * (1.0 - popoutProgress);
                    return expandRight ? (base - slide) : (base + slide);
                }

                y: {
                    let h = height;
                    let target = parentItemY - trayMenuWindow.s(8);
                    return Math.max(trayMenuWindow.s(8), Math.min(trayMenuWindow.height - h - trayMenuWindow.s(8), target));
                }

                opacity: popoutProgress * menuContainer.animProgress
                scale: 0.94 + (0.06 * popoutProgress)
                transformOrigin: expandRight ? Item.Left : Item.Right

                Shape {
                    visible: submenuPopout.expandRight && submenuPopout.subCornerRadius > 0.5
                    x: 0
                    y: -submenuPopout.subCornerRadius
                    width: submenuPopout.subCornerRadius
                    height: submenuPopout.subCornerRadius
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: ThemeBackend.base
                        strokeColor: "transparent"
                        startX: 0
                        startY: 0
                        PathLine { x: 0; y: submenuPopout.subCornerRadius }
                        PathLine { x: submenuPopout.subCornerRadius; y: submenuPopout.subCornerRadius }
                        PathArc {
                            x: 0
                            y: 0
                            radiusX: submenuPopout.subCornerRadius
                            radiusY: submenuPopout.subCornerRadius
                            direction: PathArc.Clockwise
                        }
                    }
                }

                Shape {
                    visible: submenuPopout.expandRight && submenuPopout.subCornerRadius > 0.5
                    x: 0
                    y: parent.height
                    width: submenuPopout.subCornerRadius
                    height: submenuPopout.subCornerRadius
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: ThemeBackend.base
                        strokeColor: "transparent"
                        startX: 0
                        startY: submenuPopout.subCornerRadius
                        PathLine { x: 0; y: 0 }
                        PathLine { x: submenuPopout.subCornerRadius; y: 0 }
                        PathArc {
                            x: 0
                            y: submenuPopout.subCornerRadius
                            radiusX: submenuPopout.subCornerRadius
                            radiusY: submenuPopout.subCornerRadius
                            direction: PathArc.Counterclockwise
                        }
                    }
                }

                Shape {
                    visible: !submenuPopout.expandRight && submenuPopout.subCornerRadius > 0.5
                    x: parent.width - submenuPopout.subCornerRadius
                    y: -submenuPopout.subCornerRadius
                    width: submenuPopout.subCornerRadius
                    height: submenuPopout.subCornerRadius
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: ThemeBackend.base
                        strokeColor: "transparent"
                        startX: submenuPopout.subCornerRadius
                        startY: 0
                        PathLine { x: submenuPopout.subCornerRadius; y: submenuPopout.subCornerRadius }
                        PathLine { x: 0; y: submenuPopout.subCornerRadius }
                        PathArc {
                            x: submenuPopout.subCornerRadius
                            y: 0
                            radiusX: submenuPopout.subCornerRadius
                            radiusY: submenuPopout.subCornerRadius
                            direction: PathArc.Counterclockwise
                        }
                    }
                }

                Shape {
                    visible: !submenuPopout.expandRight && submenuPopout.subCornerRadius > 0.5
                    x: parent.width - submenuPopout.subCornerRadius
                    y: parent.height
                    width: submenuPopout.subCornerRadius
                    height: submenuPopout.subCornerRadius
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: ThemeBackend.base
                        strokeColor: "transparent"
                        startX: submenuPopout.subCornerRadius
                        startY: submenuPopout.subCornerRadius
                        PathLine { x: submenuPopout.subCornerRadius; y: 0 }
                        PathLine { x: 0; y: 0 }
                        PathArc {
                            x: submenuPopout.subCornerRadius
                            y: submenuPopout.subCornerRadius
                            radiusX: submenuPopout.subCornerRadius
                            radiusY: submenuPopout.subCornerRadius
                            direction: PathArc.Clockwise
                        }
                    }
                }

                Rectangle {
                    id: subMenuBox
                    anchors.fill: parent
                    color: ThemeBackend.base
                    radius: trayMenuWindow.cornerRadius
                    border.width: 0
                    border.color: "transparent"
                    clip: true

                    Rectangle {
                        visible: submenuPopout.expandRight && submenuPopout.subCornerRadius > 0.5
                        x: 0
                        y: 0
                        width: submenuPopout.subCornerRadius
                        height: submenuPopout.subCornerRadius
                        color: ThemeBackend.base
                    }

                    Rectangle {
                        visible: submenuPopout.expandRight && submenuPopout.subCornerRadius > 0.5
                        x: 0
                        y: parent.height - submenuPopout.subCornerRadius
                        width: submenuPopout.subCornerRadius
                        height: submenuPopout.subCornerRadius
                        color: ThemeBackend.base
                    }

                    Rectangle {
                        visible: !submenuPopout.expandRight && submenuPopout.subCornerRadius > 0.5
                        x: parent.width - submenuPopout.subCornerRadius
                        y: 0
                        width: submenuPopout.subCornerRadius
                        height: submenuPopout.subCornerRadius
                        color: ThemeBackend.base
                    }

                    Rectangle {
                        visible: !submenuPopout.expandRight && submenuPopout.subCornerRadius > 0.5
                        x: parent.width - submenuPopout.subCornerRadius
                        y: parent.height - submenuPopout.subCornerRadius
                        width: submenuPopout.subCornerRadius
                        height: submenuPopout.subCornerRadius
                        color: ThemeBackend.base
                    }

                    HoverHandler {
                        id: subHoverHandler
                        onHoveredChanged: {
                            TrayMenuController.menuHovered = hovered;
                            if (hovered) {
                                TrayMenuController.cancelHide();
                            } else {
                                TrayMenuController.requestHide();
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        preventStealing: true
                    }

                    ListView {
                        id: subListView
                        anchors.fill: parent
                        anchors.margins: trayMenuWindow.s(8)
                        model: submenuPopout.subRows
                        clip: true
                        spacing: 0
                        cacheBuffer: 3000
                        interactive: contentHeight > height

                        delegate: Item {
                            id: subItemDelegate
                            width: subListView.width
                            height: trayMenuWindow.itemHeight

                            property bool isSep: modelData ? modelData.type === "separator" : false
                            property bool hasChildren: modelData ? (modelData.hasChildren === true) : false

                            Rectangle {
                                anchors.fill: parent
                                visible: !subItemDelegate.isSep
                                radius: trayMenuWindow.s(4)
                                color: subItemMouse.containsMouse ? ThemeBackend.surface0 : "transparent"
                                opacity: (modelData && modelData.enabled) ? 1.0 : 0.4

                                Image {
                                    id: subItemIcon
                                    anchors.left: parent.left
                                    anchors.leftMargin: trayMenuWindow.s(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: (modelData && modelData.icon && modelData.icon !== "") ? trayMenuWindow.s(16) : 0
                                    height: trayMenuWindow.s(16)
                                    source: (modelData && modelData.icon) ? modelData.icon : ""
                                    sourceSize: Qt.size(trayMenuWindow.s(16), trayMenuWindow.s(16))
                                    visible: width > 0
                                }

                                Text {
                                    anchors.left: subItemIcon.visible ? subItemIcon.right : parent.left
                                    anchors.leftMargin: trayMenuWindow.s(8)
                                    anchors.right: subArrowText.visible ? subArrowText.left : parent.right
                                    anchors.rightMargin: trayMenuWindow.s(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: (modelData && modelData.text) ? modelData.text : ""
                                    color: ThemeBackend.text
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: trayMenuWindow.s(13)
                                    elide: Text.ElideRight
                                    verticalAlignment: Text.AlignVCenter
                                }

                                Text {
                                    id: subArrowText
                                    anchors.right: parent.right
                                    anchors.rightMargin: trayMenuWindow.s(8)
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: subItemDelegate.hasChildren
                                    text: submenuPopout.expandRight ? "›" : "‹"
                                    color: ThemeBackend.subtext0
                                    font.family: ThemeBackend.fontFamily
                                    font.pixelSize: trayMenuWindow.s(13)
                                }

                                MouseArea {
                                    id: subItemMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    enabled: modelData ? modelData.enabled : false
                                    cursorShape: Qt.PointingHandCursor
                                    onEntered: {
                                        TrayMenuController.cancelHide();
                                        TrayMenuController.menuHovered = true;
                                        if (subItemDelegate.hasChildren) {
                                            let pos = subItemDelegate.mapToItem(rootContainer, 0, 0);
                                            trayMenuWindow.openSubmenu(submenuPopout.stackIndex + 1, modelData, submenuPopout.x, pos.y, submenuPopout.width, subItemDelegate.height);
                                        } else {
                                            trayMenuWindow.closeSubmenusFrom(submenuPopout.stackIndex + 1);
                                        }
                                    }
                                    onExited: {
                                        TrayMenuController.requestHide();
                                    }
                                    onClicked: {
                                        if (modelData && !modelData.hasChildren) {
                                            if (trayMenuWindow.activeItem)
                                                Tray.menuEvent(trayMenuWindow.activeItem.service, modelData.id);
                                            trayMenuWindow.closeMenu();
                                        } else if (modelData && modelData.hasChildren) {
                                            let pos = subItemDelegate.mapToItem(rootContainer, 0, 0);
                                            trayMenuWindow.openSubmenu(submenuPopout.stackIndex + 1, modelData, submenuPopout.x, pos.y, submenuPopout.width, subItemDelegate.height);
                                        }
                                    }
                                }
                            }

                            Rectangle {
                                width: parent.width - trayMenuWindow.s(16)
                                height: 1
                                color: ThemeBackend.surface0
                                anchors.centerIn: parent
                                visible: subItemDelegate.isSep
                            }
                        }
                    }
                }
            }
        }
    }
}
