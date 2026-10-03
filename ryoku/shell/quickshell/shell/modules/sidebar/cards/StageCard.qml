pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import shell.services
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "../../desktop/Singletons" as DesktopCfg
import "../../desktop/iris/IrisRoster.js" as IrisRoster
import "../../desktop/python/PythonRoster.js" as PythonRoster
import "../../stage/Singletons" as StageCfg
import "../../visualizer/Singletons" as VizCfg
import ".."

Item {
    id: root

    required property real s
    required property bool open
    required property real reveal
    required property bool tabActive
    property int index: 0
    property bool compact: false
    property real viewportHeight: 0
    signal requestClose()

    readonly property var backend: StageCfg.StageBackend
    readonly property var visualizer: VizCfg.Config
    readonly property var widgets: DesktopCfg.Config
    readonly property string wallpaper: Session.wallpaper !== "" ? Session.wallpaper : root.backend.current
    readonly property bool wallpaperIsVideo: /\.(mp4|webm|mkv|mov)$/i.test(root.wallpaper)
    readonly property string previewPath: root.wallpaperIsVideo ? Session.livePoster : root.wallpaper
    readonly property string effect: root.backend.effectFor(root.wallpaper)
    readonly property int layerCount: root.backend.layerCountFor(root.wallpaper)
    readonly property real gap: Tokens.s3 * root.s
    readonly property real pad: Tokens.s4 * root.s
    readonly property var enabledWidgets: {
        const builtins = [
            { prefix: "clock", label: "Clock" }, { prefix: "calendar", label: "Calendar" },
            { prefix: "music", label: "Music" }, { prefix: "aio", label: "All-in-one" },
            { prefix: "stats", label: "System stats" }, { prefix: "weather", label: "Weather" },
            { prefix: "notes", label: "Notes" }, { prefix: "dayprogress", label: "Day progress" },
            { prefix: "shape", label: "Shape" }
        ];
        const roster = builtins.concat(IrisRoster.faces, PythonRoster.faces);
        const labels = [];
        for (const entry of roster)
            if (root.widgets[entry.prefix + "Enabled"] === true)
                labels.push(I18n.tr(entry.label));
        for (const plugin of DesktopCfg.Registry.plugins)
            if (plugin.placement && plugin.placement.host === "desktopWidget")
                labels.push(plugin.manifest && plugin.manifest.name ? plugin.manifest.name : plugin.id);
        return labels;
    }
    readonly property int widgetCount: root.enabledWidgets.length
    readonly property var activeWidgets: root.enabledWidgets.slice(0, 4)

    implicitHeight: shell.implicitHeight

    function effectLabel() {
        if (root.effect === "parallax") return I18n.tr("Parallax");
        if (root.effect === "depth") return I18n.tr("Depth");
        return I18n.tr("Plain");
    }
    function wallName() {
        var parts = String(root.wallpaper || "").split("/");
        return parts.length && parts[parts.length - 1] !== "" ? parts[parts.length - 1] : I18n.tr("No wallpaper selected");
    }
    function openHub(route) {
        root.requestClose();
        Spawn.run(["ryoku-shell", "hub", "open", route]);
    }

    component Stat: Rectangle {
        id: stat
        property string glyph: ""
        property string value: ""
        property string label: ""
        width: parent.width
        implicitHeight: statBody.implicitHeight + Tokens.s3 * root.s * 2
        radius: Tokens.radius * root.s
        color: Tokens.tint5
        border.width: Tokens.border
        border.color: Tokens.line
        Column {
            id: statBody
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.s3 * root.s
            spacing: Tokens.s1 * root.s
            Text { text: stat.glyph; color: Tokens.inkDim; font.family: "Material Symbols Rounded"; font.pixelSize: 22 * root.s }
            Text { id: statValue; width: parent.width; text: stat.value; color: Tokens.ink; font.family: Tokens.display; font.pixelSize: Tokens.fValue * root.s; font.weight: Font.Medium; elide: Text.ElideRight
                HoverHandler { id: statValueHover }
                QQC.ToolTip.visible: statValueHover.hovered && statValue.truncated
                QQC.ToolTip.text: statValue.text
            }
            Text { width: parent.width; text: stat.label; color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall * root.s; wrapMode: Text.WordWrap }
        }
    }

    SidebarCardShell {
        id: shell
        width: root.width
        s: root.s
        index: root.index
        open: root.open
        reveal: root.reveal
        tabActive: root.tabActive
        compact: root.compact
        title: I18n.tr("Stage")
        glyph: "layers"
        eyebrow: root.effect === "off" && !root.visualizer.enabled ? I18n.tr("Quiet desktop") : I18n.tr("Live composition")

        Column {
            width: parent.width
            spacing: root.gap

            Rectangle {
                width: parent.width
                implicitHeight: (root.compact ? 150 : 238) * root.s
                radius: Tokens.radius * root.s
                clip: true
                color: Tokens.tint5
                border.width: Tokens.border
                border.color: Tokens.line

                Image {
                    id: wallpaperPreview
                    anchors.fill: parent
                    source: root.previewPath !== "" ? "file://" + root.previewPath : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 0.78 : 0
                }
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        orientation: Gradient.Vertical
                        GradientStop { position: 0; color: Qt.rgba(Tokens.paper.r, Tokens.paper.g, Tokens.paper.b, 0.02) }
                        GradientStop { position: 1; color: Qt.rgba(Tokens.paper.r, Tokens.paper.g, Tokens.paper.b, 0.94) }
                    }
                }
                Image {
                    visible: root.effect !== "off" && root.layerCount > 0
                    anchors.fill: parent
                    source: root.backend.layerUrlFor(root.wallpaper, 0)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: status === Image.Ready ? 0.86 : 0
                }
                Text { visible: wallpaperPreview.status !== Image.Ready; anchors.centerIn: parent; text: "landscape"; color: Tokens.inkFaint; font.family: "Material Symbols Rounded"; font.pixelSize: (root.compact ? 48 : 70) * root.s }
                Column {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: root.pad
                    spacing: Tokens.s1 * root.s
                    Text {
                        width: parent.width
                        text: root.effectLabel() + (root.layerCount > 0 ? I18n.tr(" · %1 layers").arg(root.layerCount) : "")
                        color: Tokens.ink
                        font.family: Tokens.display
                        font.pixelSize: (root.compact ? Tokens.fValue : Tokens.fHero) * root.s
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                    Text {
                        id: wallFile
                        width: parent.width
                        text: root.backend.busy ? I18n.tr("Building the scene · %1%").arg(root.backend.percent) : root.wallName()
                        color: Tokens.inkMuted
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall * root.s
                        elide: Text.ElideMiddle
                        HoverHandler { id: wallFileHover }
                        QQC.ToolTip.visible: wallFileHover.hovered && wallFile.truncated
                        QQC.ToolTip.text: wallFile.text
                    }
                }
            }

            Grid {
                width: parent.width
                columns: root.compact ? 1 : 3
                columnSpacing: root.gap
                rowSpacing: root.gap
                Stat { width: root.compact ? parent.width : (parent.width - root.gap * 2) / 3; glyph: "layers"; value: root.effectLabel(); label: root.layerCount > 0 ? I18n.tr("%1 cut layers").arg(root.layerCount) : I18n.tr("Wallpaper scene") }
                Stat { width: root.compact ? parent.width : (parent.width - root.gap * 2) / 3; glyph: "widgets"; value: String(root.widgetCount); label: root.widgetCount === 1 ? I18n.tr("Widget enabled") : I18n.tr("Widgets enabled") }
                Stat {
                    width: root.compact ? parent.width : (parent.width - root.gap * 2) / 3
                    glyph: "graphic_eq"
                    value: root.visualizer.enabled ? root.visualizer.styleId : I18n.tr("Off")
                    label: root.visualizer.enabled ? I18n.tr("%1 fps visualizer").arg(root.visualizer.fps) : I18n.tr("Audio visualizer")
                }
            }

            Rectangle {
                visible: !root.compact
                width: parent.width
                implicitHeight: widgetBody.implicitHeight + root.pad * 2
                radius: Tokens.radius * root.s
                color: Tokens.paperLift
                border.width: Tokens.border
                border.color: Tokens.line
                Column {
                    id: widgetBody
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: root.pad
                    spacing: Tokens.s2 * root.s
                    Text { width: parent.width; text: I18n.tr("Enabled widgets"); color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fRow * root.s; font.weight: Font.DemiBold }
                    Flow {
                        visible: root.activeWidgets.length > 0
                        width: parent.width
                        spacing: Tokens.s2 * root.s
                        Repeater {
                            model: root.activeWidgets
                            delegate: Rectangle {
                                required property var modelData
                                implicitWidth: widgetName.implicitWidth + Tokens.s3 * root.s * 2
                                implicitHeight: widgetName.implicitHeight + Tokens.s2 * root.s * 2
                                radius: height / 2
                                color: Tokens.tint5
                                border.width: Tokens.border
                                border.color: Tokens.line
                                Text { id: widgetName; anchors.centerIn: parent; text: modelData; color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall * root.s }
                            }
                        }
                    }
                    Text { visible: root.activeWidgets.length === 0; width: parent.width; text: I18n.tr("Desktop widgets are switched off."); color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall * root.s; wrapMode: Text.WordWrap }
                    Text { visible: root.widgetCount > root.activeWidgets.length; width: parent.width; text: I18n.tr("+ %1 more").arg(root.widgetCount - root.activeWidgets.length); color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall * root.s }
                }
            }

            Flow {
                width: parent.width
                spacing: Tokens.s2 * root.s
                SidebarButton { s: root.s; text: I18n.tr("Edit scene"); glyph: "layers"; primary: true; onAct: root.openHub("desktop-scene") }
                SidebarButton { s: root.s; text: I18n.tr("Visualizer"); glyph: "graphic_eq"; onAct: root.openHub("desktop-scene-visualizer") }
                SidebarButton { s: root.s; text: I18n.tr("Widgets"); glyph: "widgets"; onAct: root.openHub("desktop-scene-widgets") }
            }
        }
    }
}
