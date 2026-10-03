pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import Ryoku.Ui
import Ryoku.Ui.Singletons
import shell.services
import "SidebarCatalog.js" as SidebarCatalog

Item {
    id: root
    required property var screen
    required property string side
    property real reveal: 0
    property bool open: false
    property real maximumHeight: 0
    property string selectedTab: ""
    property var tabs: []
    property string contentSignature: ""
    property real currentContentHeight: 0
    readonly property real s: Tokens.uiScaleFor(screen ? screen.name : "")
    readonly property real pad: Tokens.s5 * s
    readonly property bool narrow: width < 520 * s
    readonly property string requestedTab: SidebarState.activeTab(screen, side)
    readonly property var options: Config.sidebars[side]
    readonly property var pluginCards: pluginHost.cards(side)
    readonly property real chromeHeight: header.height + footer.height + root.pad * 2 + Tokens.s5 * s * 2
    readonly property real fittedHeight: chromeHeight + Math.max(currentContentHeight, sectionList.implicitHeight)
    signal closeRequested()

    LayoutMirroring.enabled: I18n.rtl
    LayoutMirroring.childrenInherit: true

    function refreshTabs() {
        const configured = root.options.cards;
        const signature = JSON.stringify([configured, root.pluginCards.map(p => [p.id, p.tab, p.entry])]);
        if (signature === root.contentSignature) return;
        root.contentSignature = signature;
        const groups = [];
        const ordered = configured.length === 0 ? [] : configured.concat(
            root.pluginCards.filter(card => configured.indexOf(card.id) < 0).map(card => card.id));
        for (const id of ordered) {
            const builtin = SidebarCatalog.byId(id);
            const plugin = builtin ? null : root.pluginCards.find(card => card.id === id);
            if (!builtin && !plugin) continue;
            const label = builtin ? builtin.label : plugin.tab || I18n.tr("Plugins");
            const matching = builtin || SidebarCatalog.byTab(label.toLowerCase());
            const key = matching ? matching.tab : "plugin-" + label.toLowerCase().replace(/[^a-z0-9]+/g, "-");
            let group = groups.find(g => g.id === key);
            if (!group) {
                group = { id: key, label: matching ? matching.label : label,
                    glyph: matching ? matching.glyph : "extension", cards: [] };
                groups.push(group);
            }
            group.cards.push({id: id, entry: plugin ? plugin.entry : null});
        }
        root.tabs = groups;
        root.syncSelection();
    }
    function syncSelection() {
        let requested = root.requestedTab;
        if (requested === "compress" || requested === "install") requested = "tools";
        const match = root.tabs.find(g => g.id === requested || g.cards.some(c => c.id === requested || c.id === "plugin:" + requested));
        root.selectedTab = match ? match.id : root.tabs.length ? root.tabs[0].id : "";
        root.updateHeight();
    }
    function activeIndex() { return Math.max(0, root.tabs.findIndex(g => g.id === root.selectedTab)); }
    function choose(index) {
        if (index < 0 || index >= root.tabs.length) return;
        SidebarState.selectTab(root.side, root.screen, root.tabs[index].id);
    }
    function updateHeight() {
        const page = pageRepeater.itemAt(root.activeIndex());
        root.currentContentHeight = page ? page.contentHeight : Tokens.rowH * s * 3;
    }
    function openSettings() {
        root.closeRequested();
        Spawn.run(["ryoku-shell", "hub", "open", root.side === "right" ? "sidebars-right" : "sidebars-left"]);
    }
    onRequestedTabChanged: syncSelection()
    onPluginCardsChanged: refreshTabs()
    onSelectedTabChanged: Qt.callLater(updateHeight)
    Component.onCompleted: refreshTabs()
    Connections { target: Config; function onSidebarsChanged() { root.refreshTabs(); } }
    SidebarPlugins { id: pluginHost }

    Item {
        id: header
        x: root.pad; y: root.pad
        width: parent.width - root.pad * 2
        height: Math.max(titleCopy.implicitHeight, headerActions.height)
        Column {
            id: titleCopy
            anchors { left: parent.left; right: headerActions.left; rightMargin: Tokens.s3 * root.s; verticalCenter: parent.verticalCenter }
            spacing: Tokens.s1 * root.s
            Text {
                width: parent.width
                text: root.side === "left" ? I18n.tr("Control center") : I18n.tr("Companion")
                color: Tokens.ink
                font.family: Tokens.display
                font.pixelSize: Tokens.fTitle * root.s
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.side === "left" ? I18n.tr("Your desktop at a glance") : I18n.tr("Usage, downloads and chat")
                color: Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall * root.s
                elide: Text.ElideRight
            }
        }
        Row {
            id: headerActions
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: Tokens.s2 * root.s
            SidebarButton {
                s: root.s
                glyph: "tune"
                text: root.narrow ? "" : I18n.tr("Customize in Hub")
                Accessible.name: I18n.tr("Customize sidebars in Ryoku Hub")
                onAct: root.openSettings()
            }
            SidebarButton {
                s: root.s
                glyph: "close"
                text: ""
                Accessible.name: I18n.tr("Close sidebar")
                onAct: root.closeRequested()
            }
        }
    }
    Rectangle {
        x: root.pad; y: header.y + header.height + Tokens.s4 * root.s
        width: parent.width - root.pad * 2; height: Tokens.border
        color: Tokens.lineSoft
    }
    Item {
        id: body
        x: root.pad; y: header.y + header.height + Tokens.s5 * root.s
        width: parent.width - root.pad * 2
        height: Math.max(0, footer.y - y - Tokens.s4 * root.s)
        Rectangle {
            id: navigation
            visible: root.tabs.length > 0
            width: (root.narrow ? 48 : 148) * root.s
            height: parent.height
            radius: Tokens.radius * root.s * 2
            color: Tokens.paperLift
            QQC.ScrollView {
                anchors.fill: parent
                clip: true
                contentWidth: availableWidth
                QQC.ScrollBar.horizontal.policy: QQC.ScrollBar.AlwaysOff
                Column {
                    id: sectionList
                    width: navigation.width
                    spacing: Tokens.s1 * root.s
                    Repeater {
                        model: root.tabs
                        delegate: QQC.AbstractButton {
                            id: tab
                            required property var modelData
                            required property int index
                            readonly property bool selected: root.selectedTab === modelData.id
                            width: sectionList.width
                            height: Math.max(52 * root.s, tabLabel.implicitHeight + Tokens.s3 * root.s * 2)
                            text: I18n.tr(modelData.label)
                            hoverEnabled: true
                            Accessible.role: Accessible.PageTab
                            Accessible.name: text
                            Accessible.selected: selected
                            onClicked: root.choose(index)
                            Keys.onUpPressed: root.choose((index + root.tabs.length - 1) % root.tabs.length)
                            Keys.onDownPressed: root.choose((index + 1) % root.tabs.length)
                            background: Rectangle {
                                radius: Tokens.radius * root.s * 1.5
                                color: tab.selected ? Tokens.bone : tab.down ? Tokens.tint16 : tab.hovered ? Tokens.tint10 : "transparent"
                                border.width: Tokens.border
                                border.color: tab.visualFocus ? Tokens.bone : "transparent"
                            }
                            contentItem: Item {
                                Text {
                                    id: tabGlyph
                                    anchors { left: parent.left; leftMargin: Tokens.s3 * root.s; verticalCenter: parent.verticalCenter }
                                    width: 22 * root.s
                                    text: tab.modelData.glyph
                                    color: tab.selected ? Tokens.inkOnBone : Tokens.inkDim
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: 21 * root.s
                                    Accessible.ignored: true
                                }
                                Text {
                                    id: tabLabel
                                    visible: !root.narrow
                                    anchors { left: tabGlyph.right; right: parent.right; leftMargin: Tokens.s2 * root.s; rightMargin: Tokens.s2 * root.s; verticalCenter: parent.verticalCenter }
                                    text: tab.text
                                    color: tab.selected ? Tokens.inkOnBone : Tokens.inkDim
                                    font.family: Tokens.ui
                                    font.pixelSize: Tokens.fRow * root.s
                                    font.weight: tab.selected ? Font.DemiBold : Font.Medium
                                    wrapMode: Text.Wrap
                                }
                            }
                            QQC.ToolTip.visible: hovered && root.narrow
                            QQC.ToolTip.text: text
                            HoverHandler { cursorShape: Qt.PointingHandCursor }
                        }
                    }
                }
            }
        }
        Item {
            id: pages
            x: navigation.visible ? navigation.width + Tokens.s4 * root.s : 0
            width: parent.width - x
            height: parent.height
            clip: true
            Repeater {
                id: pageRepeater
                model: root.tabs
                delegate: Item {
                    id: page
                    required property var modelData
                    required property int index
                    readonly property bool active: root.selectedTab === modelData.id
                    property bool visited: false
                    readonly property real contentHeight: cardColumn.height
                    anchors.fill: parent
                    visible: active || opacity > 0.001
                    enabled: active
                    opacity: active ? 1 : 0
                    onActiveChanged: if (active) visited = true
                    onContentHeightChanged: if (active) root.updateHeight()
                    Component.onCompleted: { if (active) visited = true; Qt.callLater(root.updateHeight); }
                    Behavior on opacity { enabled: !Motion.reduce && !Tokens.reduceMotion; NumberAnimation { duration: Tokens.swap; easing.type: Tokens.ease } }
                    Flickable {
                        id: contentFlick
                        anchors.fill: parent
                        contentHeight: cardColumn.height
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        QQC.ScrollBar.vertical: ScrollRail {
                            policy: QQC.ScrollBar.AsNeeded
                            motionEnabled: !Motion.reduce && !Tokens.reduceMotion
                        }
                        WheelScroll {}
                        Column {
                            id: cardColumn
                            width: Math.max(0, contentFlick.width - Tokens.s2 * root.s)
                            spacing: Tokens.s5 * root.s
                            Repeater {
                                model: page.visited ? page.modelData.cards : []
                                delegate: SidebarCardHost {
                                    required property var modelData
                                    required property int index
                                    width: cardColumn.width
                                    viewportHeight: root.options.heightMode === "fit"
                                        ? Math.max(0, root.maximumHeight - root.chromeHeight) : contentFlick.height
                                    cardIndex: index
                                    cardId: modelData.id
                                    pluginEntry: modelData.entry
                                    compact: (root.options.presentations[modelData.id] || "expanded") === "summary"
                                    page: root.requestedTab
                                    s: root.s * 1.12
                                    open: root.open
                                    reveal: root.reveal
                                    tabActive: page.active
                                    onRequestClose: root.closeRequested()
                                }
                            }
                        }
                    }
                }
            }
            Column {
                anchors.centerIn: parent
                width: parent.width
                spacing: Tokens.s4 * root.s
                visible: root.tabs.length === 0
                Text { width: parent.width; text: I18n.tr("Choose what appears here"); color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fRow * root.s; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap }
                SidebarButton { s: root.s; anchors.horizontalCenter: parent.horizontalCenter; text: I18n.tr("Choose sections in Hub"); onAct: root.openSettings() }
            }
        }
    }
    Item {
        id: footer
        x: root.pad; y: parent.height - root.pad - height
        width: parent.width - root.pad * 2
        height: 32 * root.s
        Rectangle { width: parent.width; height: Tokens.border; color: Tokens.lineSoft }
        Text {
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
            text: root.options.pinned ? I18n.tr("Kept open until you close it") : I18n.tr("Esc to close")
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: Tokens.fSmall * root.s
        }
    }
    Shortcut { sequence: "Ctrl+E"; enabled: root.open; onActivated: root.openSettings() }
    Shortcut { sequence: "Escape"; enabled: root.open; onActivated: root.closeRequested() }
}
