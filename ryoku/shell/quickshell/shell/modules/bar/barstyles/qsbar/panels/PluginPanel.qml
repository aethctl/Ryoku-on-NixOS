import QtQuick
import "../modules"
import Quickshell
import Quickshell.Wayland
import Ryoku.PluginKit

// The bar panel a plugin may open under its glyph: one shared window, one plugin
// at a time, drawn on the same connected surface the built-in panels use so a
// community widget's panel is indistinguishable from Network's or Battery's.
// The plugin ships `entryPoints.panel` (docs/plugins.md "A bar panel"); the slot
// that hosts its glyph hands over its api (the service instance, settings, dir)
// when the plugin asks to open, so the panel reads the same service the glyph
// does. Escape, a click outside, or any other panel opening closes it.
PanelWindow {
    id: pp
    required property var root

    screen: root.activePopupScreen
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "ryoku-plugin-panel"

    readonly property int barBottom: root.v2BarHeight
    readonly property int gap: 6

    // keep the last plugin while the panel fades, so the content does not
    // vanish a frame before the card does.
    property string shownId: ""
    property var shownApi: null
    readonly property string pid: root.pluginPanelId
    onPidChanged: if (pid !== "") { shownApi = root.pluginPanelApi; shownId = pid }

    readonly property var entry: shownId !== "" ? root.barPluginEntryFor(shownId) : null
    readonly property var man: (entry && entry.manifest) ? entry.manifest : ({})
    readonly property string panelRel: (man.entryPoints && man.entryPoints.panel) ? String(man.entryPoints.panel) : ""
    readonly property string versionQuery: (entry && entry.version) ? "?v=" + encodeURIComponent(entry.version) : ""
    readonly property real cardW: Math.max(240, Math.min(520, (man.panel && man.panel.width > 0) ? man.panel.width : 320))
    readonly property real anchorX: (root.pluginBarX && root.pluginBarX[shownId] !== undefined) ? root.pluginBarX[shownId] : 0
    readonly property real maxCardH: Math.max(120, height - barBottom - gap * 2 - 12)

    property real reveal: root.pluginPanelVisible ? 1 : 0
    Behavior on reveal {
        NumberAnimation {
            duration: root.pluginPanelVisible ? 160 : 120
            easing.type: root.pluginPanelVisible ? Easing.OutCubic : Easing.InCubic
        }
    }
    visible: reveal > 0.001
    WlrLayershell.keyboardFocus: root.pluginPanelVisible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    MouseArea { anchors.fill: parent; onClicked: root.closePluginPanel() }

    Rectangle {
        id: card
        width: pp.cardW
        height: Math.min(pp.maxCardH, (content.item ? content.item.implicitHeight : 0) + 24)
        radius: pp.reveal > 0.001 ? root.panelRadius : 0
        color: "transparent"
        border.color: root.panelBorder
        border.width: 0
        clip: true
        PillShadow { theme: root }
        ConnectedPanelSurface {
            root: pp.root
            ownerActive: pp.root.pluginPanelVisible
            targetX: pp.anchorX
            reveal: pp.reveal
        }

        x: Math.round(Math.max(6, Math.min(pp.anchorX - width / 2, parent.width - width - 6)))
        y: root.barPosition === "bottom"
            ? (parent.height - pp.barBottom - pp.gap - height) + 2 * (1 - pp.reveal)
            : (pp.barBottom + pp.gap) - 2 * (1 - pp.reveal)
        opacity: pp.reveal
        focus: root.pluginPanelVisible

        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
                root.closePluginPanel()
                event.accepted = true
            }
        }
        MouseArea { anchors.fill: parent; onClicked: {} }

        // the plugin's panel, at full density, as wide as the card's inside.
        PluginObjectSlot {
            id: content
            fill: true
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 12
            height: item ? item.implicitHeight : 0
            source: (pp.entry && pp.panelRel !== "")
                ? "file://" + pp.entry.dir + "/" + pp.panelRel + pp.versionQuery : ""
            configure: (c) => {
                c.pluginApi = Qt.binding(() => pp.shownApi)
                if ("density" in c) c.density = "full"
                if ("s" in c) c.s = 1
                if ("widthBudget" in c) c.widthBudget = pp.cardW - 24
                if ("active" in c) c.active = true
            }
        }
    }
}
