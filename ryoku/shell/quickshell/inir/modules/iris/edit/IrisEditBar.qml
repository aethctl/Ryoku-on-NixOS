pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import inir
import inir.services
import inir.modules.common
import inir.modules.common.widgets
import inir.modules.iris.frame
import inir.modules.iris.pieces
import inir.modules.iris.settings
import inir.modules.iris.style
import inir.modules.iris.components

Item {
    id: root

    property var screenData: null
    readonly property real d: IrisStyle.density
    readonly property bool bottomEdge: String(Config.options?.iris?.bar?.position ?? "top") !== "bottom"
    readonly property bool present: GlobalStates.irisEdit
    readonly property real presentation: presentSpring.value
    readonly property bool shown: root.presentation > 0.001
    readonly property bool editingDock: root.target === "dock" && (Config.options?.iris?.dock?.enable ?? true)
    readonly property real dockClearance: {
        if (!root.editingDock) return 0
        const dock = Config.options?.iris?.dock ?? ({})
        const icon = Math.max(28, Math.min(64, Number(dock?.iconSize ?? 40)))
        const air = (dock?.notch ?? false) ? 0 : 10
        return Math.round((icon + 28 + air) * root.d)
    }

    readonly property real bodyWidth: Math.min(root.width - IrisFrame.band * 2 - Math.round(24 * root.d),
        Math.round(780 * root.d))
    readonly property real bodyHeight: Math.round(body.implicitHeight + 24 * root.d)
    readonly property real restY: root.bottomEdge
        ? root.height - IrisFrame.band - root.dockClearance - root.bodyHeight
        : IrisFrame.band + root.dockClearance
    readonly property real hiddenY: root.bottomEdge ? root.height + Math.round(8 * root.d)
        : -root.bodyHeight - Math.round(8 * root.d)
    readonly property real bodyX: Math.round((root.width - root.bodyWidth) / 2)
    readonly property real bodyY: Math.round(root.hiddenY + (root.restY - root.hiddenY) * Math.min(1, root.presentation))
    readonly property real bodyRadius: IrisStyle.radiusPanel

    readonly property var hitRect: root.shown
        ? Qt.rect(root.bodyX, root.bodyY, root.bodyWidth, root.bodyHeight) : Qt.rect(0, 0, 0, 0)
    readonly property var inspectorRect: inspector.progress > 0.01
        ? Qt.rect(inspector.x, inspector.y, inspector.width, inspector.height) : Qt.rect(0, 0, 0, 0)
    readonly property real inspectorWidth: Math.min(root.width - IrisFrame.band * 2 - Math.round(24 * root.d),
        Math.max(Math.round(440 * root.d), Math.min(Math.round(560 * root.d), root.bodyWidth * 0.78)))
    readonly property real inspectorRoom: root.bottomEdge
        ? root.bodyY - IrisFrame.band - Math.round(16 * root.d)
        : root.height - root.bodyY - root.bodyHeight - IrisFrame.band - Math.round(16 * root.d)
    readonly property real inspectorDesiredHeight: Math.max(Math.round(180 * root.d),
        inspectorBody.implicitHeight + Math.round(20 * root.d))
    readonly property real inspectorHeight: Math.max(Math.round(100 * root.d),
        Math.min(Math.round(620 * root.d), Math.max(Math.round(100 * root.d), root.inspectorRoom),
            root.inspectorDesiredHeight))
    readonly property var fieldShapes: {
        if (!root.shown) return []
        const out = [{
            x: root.bodyX, y: root.bodyY, width: root.bodyWidth, height: root.bodyHeight,
            radius: root.bodyRadius, fuse: IrisStyle.fuse, paints: true,
            id: "editbar", joins: IrisFrame.framed ? "frame" : ""
        }]
        const body = inspector.bodyRect
        if (inspector.progress > 0.01 && body.width > 1 && body.height > 1)
            out.push({ x: body.x, y: body.y, width: body.width, height: body.height, radius: body.radius,
                paints: true, fuse: IrisStyle.fuseDeep, id: "editinspector", joins: "editbar" })
        return out
    }

    IrisSpring {
        id: presentSpring
        surface: "panels"
        to: root.present ? 1 : 0
        intent: "auto"
        minimum: 0
    }

    readonly property string selection: GlobalStates.irisEditSelection
    readonly property string target: GlobalStates.irisEditTarget
    onSelectionChanged: {
        if (root.selection.length > 0 && GlobalStates.irisEditTarget.length > 0)
            GlobalStates.irisEditTarget = ""
    }
    Connections {
        target: GlobalStates
        function onIrisEditTargetChanged(): void {
            if (GlobalStates.irisEditTarget.length === 0) return
            GlobalStates.irisEditSelection = ""
        }
    }
    readonly property bool inspecting: root.shown && (root.selection.length > 0 || root.target.length > 0)
    readonly property var targets: [
        { id: "material", label: "Material" }, { id: "colour", label: "Colour" },
        { id: "type", label: "Type" }, { id: "motion", label: "Motion" },
        { id: "island", label: "Island" }, { id: "pieces", label: "Pieces" },
        { id: "bodies", label: "Bodies" }, { id: "places", label: "Places" },
        { id: "transients", label: "Feedback" }, { id: "dock", label: "Dock" },
        { id: "desktop", label: "Desktop" }
    ]
    readonly property bool isExtra: root.selection.startsWith("extra:")
    readonly property bool isApp: IrisPieces.isApp(root.selection)
    readonly property string selectionKind: root.isExtra ? root.selection.slice(6) : root.selection
    readonly property string selectionLabel: root.selection.length === 0 ? ""
        : root.isApp ? IrisPieces.appIdOf(root.selection) : IrisPieces.labelOf(root.selectionKind)
    readonly property string selectionPath: root.isApp ? ""
        : IrisPieces.configPath(root.isExtra ? root.selectionKind : root.selection)
    function rowVisible(spec: var): bool {
        const when = String(spec.visibleWhen ?? "")
        if (when.length === 0) return true
        if (when.includes("=")) return String(Config.getNestedValue(when.split("=")[0], "")) === when.split("=")[1]
        const negated = when.startsWith("!")
        const on = Boolean(Config.getNestedValue(negated ? when.slice(1) : when, false))
        return negated ? !on : on
    }
    function behaviourFor(target: string): var {
        return IrisOptions.behaviour.filter(spec => {
            if (!root.rowVisible(spec)) return false
            const section = String(spec.section ?? "")
            const group = String(spec.group ?? "")
            if (target === "island") return section === "bar"
            if (target === "pieces") return section === "bubbles"
            if (target === "dock") return section === "dock"
            if (target === "desktop") return section === "desktop"
            if (target === "bodies") return section === "player"
                || (section === "surfaces" && group === "Control Center")
            if (target === "places") return section === "sidebars"
                || (section === "surfaces" && group === "Spotlight")
                || (section === "desktop" && group === "Wallpaper gallery")
            if (target === "transients") return section === "surfaces" && group === "Feedback"
            if (target === "material") return section === "appearance" && group === "Look"
            if (target === "motion") return section === "appearance" && group === "Motion"
            return false
        })
    }
    function targetRows(target: string): var {
        Config.revision
        const rows = IrisOptions.studio.filter(spec => spec.target === target && root.rowVisible(spec))
        const paths = new Set(rows.map(spec => String(spec.path ?? "")))
        return rows.concat(root.behaviourFor(target).filter(spec => !paths.has(String(spec.path ?? ""))))
    }
    readonly property var inspectorRows: {
        if (root.selection.length > 0) {
            const rows = []
            if (!root.isApp) {
                for (const spec of IrisOptions.behaviour)
                    if (spec.piece === root.selectionKind && root.rowVisible(spec)) rows.push(spec)
            }
            const paths = new Set(rows.map(spec => String(spec.path ?? "")))
            return rows.concat(IrisOptions.studio
                .filter(spec => spec.target === "pieces" && root.rowVisible(spec) && !paths.has(String(spec.path ?? ""))))
        }
        return root.targetRows(root.target)
    }

    readonly property var extras: IrisPieces.extras
    function extraOn(id: string): bool {
        return Config.options?.iris?.bubbles?.extras?.[id]?.enable ?? false
    }
    function toggleExtra(id: string): void {
        Config.setNestedValue("iris.bubbles.extras." + id + ".enable", !root.extraOn(id))
    }
    readonly property string preset: String(Config.options?.iris?.appearance?.preset ?? "iris")
    readonly property string morph: String(Config.options?.iris?.appearance?.morph ?? "direct")
    readonly property int bubbleScale: Config.options?.iris?.bubbles?.scale ?? 100
    readonly property int islandHeight: Config.options?.iris?.bar?.height ?? 42
    readonly property int clockScale: Config.options?.iris?.bar?.clockScale ?? 100
    readonly property int motionDuration: Config.options?.iris?.appearance?.motionDuration ?? 220
    readonly property var tabs: ["pieces", "look", "motion", "layout"]
    readonly property var tabLabels: ({ pieces: "Pieces", look: "Look", motion: "Motion", layout: "Layout" })
    readonly property var hints: ({
        pieces: "Tap to add or remove, drag to place",
        look: "Character and accent",
        motion: "How shapes open and settle",
        layout: "Sizes and the screen edge"
    })
    readonly property string tab: GlobalStates.irisEditTab

    Item {
        x: root.bodyX
        y: root.bodyY
        width: root.bodyWidth
        height: root.bodyHeight
        visible: root.shown
        opacity: IrisStyle.ramp(root.presentation, IrisStyle.contentRise, IrisStyle.contentSpan)

        MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons }

        ColumnLayout {
            id: body
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Math.round(16 * root.d)
            anchors.rightMargin: Math.round(16 * root.d)
            spacing: Math.round(12 * root.d)

            RowLayout {
                Layout.fillWidth: true
                spacing: Math.round(10 * root.d)
                Rectangle {
                    implicitWidth: Math.round(30 * root.d)
                    implicitHeight: implicitWidth
                    radius: width / 2
                    color: IrisStyle.tintFill(IrisStyle.accent)
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "edit"
                        fill: 1
                        iconSize: Math.round(16 * root.d)
                        color: IrisStyle.accent
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    IrisText {
                        text: Translation.tr("Editing iRiS")
                        font.weight: Font.DemiBold
                        font.pixelSize: 14 * IrisStyle.typeScale
                    }
                    IrisText {
                        Layout.fillWidth: true
                        text: Translation.tr(root.hints[root.tab] ?? "")
                        role: IrisText.Meta
                        elide: Text.ElideRight
                    }
                }
                Rectangle {
                    id: tabs
                    implicitWidth: tabRow.implicitWidth + 4
                    implicitHeight: Math.round(30 * root.d)
                    radius: height / 2
                    color: IrisStyle.fillQuiet
                    Rectangle {
                        readonly property Item current: tabRepeater.itemAt(root.tabs.indexOf(root.tab))
                        x: 2 + (current?.x ?? 0)
                        y: 2
                        width: current?.width ?? 0
                        height: tabs.height - 4
                        radius: height / 2
                        color: IrisStyle.fillActive
                        Behavior on x { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                        Behavior on width { NumberAnimation { duration: IrisStyle.moveDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
                    }
                    Row {
                        id: tabRow
                        x: 2
                        y: 2
                        Repeater {
                            id: tabRepeater
                            model: root.tabs
                            MouseArea {
                                id: tabButton
                                required property string modelData
                                width: tabLabel.implicitWidth + Math.round(24 * root.d)
                                height: tabs.height - 4
                                cursorShape: Qt.PointingHandCursor
                                Accessible.role: Accessible.PageTab
                                Accessible.name: Translation.tr(root.tabLabels[tabButton.modelData])
                                Accessible.checked: root.tab === tabButton.modelData
                                onClicked: GlobalStates.irisEditTab = tabButton.modelData
                                IrisText {
                                    id: tabLabel
                                    anchors.centerIn: parent
                                    text: Translation.tr(root.tabLabels[tabButton.modelData])
                                    color: root.tab === tabButton.modelData ? IrisStyle.text : IrisStyle.subtext
                                    font.pixelSize: 12 * IrisStyle.typeScale
                                    font.weight: root.tab === tabButton.modelData ? Font.DemiBold : Font.Normal
                                }
                            }
                        }
                    }
                }
                Item { Layout.fillWidth: true }
                IrisButton {
                    quiet: true
                    text: Translation.tr("Studio")
                    buttonRadius: height / 2
                    onClicked: GlobalStates.irisStudioOpen = true
                }
                IrisButton {
                    emphasized: true
                    text: Translation.tr("Done")
                    buttonRadius: height / 2
                    onClicked: GlobalStates.irisEdit = false
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: root.tab === "pieces" ? pieceSections.implicitHeight : Math.round(66 * root.d)

                ColumnLayout {
                    id: pieceSections
                    anchors.left: parent.left
                    anchors.right: parent.right
                    visible: root.tab === "pieces"
                    spacing: Math.round(8 * root.d)
                    Repeater {
                        model: [
                            { title: Translation.tr("On screen"), on: true, empty: Translation.tr("Nothing floating yet. Tap a piece below to add it.") },
                            { title: Translation.tr("Add"), on: false, empty: Translation.tr("Every piece is on screen.") }
                        ]
                        ColumnLayout {
                            id: pieceSection
                            required property var modelData
                            readonly property var members: {
                                Config.revision
                                return root.extras.filter(extra => root.extraOn(extra.id) === pieceSection.modelData.on)
                            }
                            Layout.fillWidth: true
                            spacing: Math.round(4 * root.d)
                            IrisText {
                                text: pieceSection.modelData.title + (pieceSection.members.length > 0 ? "  " + pieceSection.members.length : "")
                                role: IrisText.Meta
                                font.weight: Font.DemiBold
                            }
                            IrisText {
                                visible: pieceSection.members.length === 0
                                Layout.fillWidth: true
                                Layout.topMargin: Math.round(2 * root.d)
                                Layout.bottomMargin: Math.round(4 * root.d)
                                text: pieceSection.modelData.empty
                                color: IrisStyle.muted
                                font.pixelSize: 12 * IrisStyle.typeScale
                            }
                            Flow {
                                Layout.fillWidth: true
                                visible: pieceSection.members.length > 0
                                spacing: Math.round(4 * root.d)
                                Repeater {
                                    model: pieceSection.members
                                    PieceTile {
                                        required property var modelData
                                        kind: modelData.id
                                        label: modelData.label
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    visible: root.tab === "look"
                    spacing: Math.round(8 * root.d)
                    Repeater {
                        model: ["iris", "soft", "round", "crisp", "angular", "contrast"]
                        PresetMini {
                            required property string modelData
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            name: modelData
                        }
                    }
                    Rectangle { Layout.preferredWidth: 1; Layout.preferredHeight: Math.round(40 * root.d); color: IrisStyle.hairline }
                    Repeater {
                        model: ["blue", "mint", "rose", "lilac", "wallpaper"]
                        Swatch {
                            required property string modelData
                            accentName: modelData
                        }
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    visible: root.tab === "motion"
                    spacing: Math.round(14 * root.d)
                    Row {
                        spacing: Math.round(4 * root.d)
                        Repeater {
                            model: ["direct", "liquid", "glide", "snap", "elastic"]
                            Chip {
                                required property string modelData
                                text: Translation.tr(modelData.charAt(0).toUpperCase() + modelData.slice(1))
                                selected: root.morph === modelData
                                onClicked: Config.setNestedValue("iris.appearance.morph", modelData)
                            }
                        }
                    }
                    Sizer {
                        title: Translation.tr("Duration")
                        value: (root.motionDuration - 100) / 300
                        figure: root.motionDuration + " ms"
                        onPicked: next => Config.setNestedValue("iris.appearance.motionDuration", Math.round((100 + next * 300) / 10) * 10)
                    }
                }

                RowLayout {
                    anchors.fill: parent
                    visible: root.tab === "layout"
                    spacing: Math.round(14 * root.d)
                    Sizer {
                        title: Translation.tr("Island height")
                        value: (root.islandHeight - 32) / 32
                        figure: root.islandHeight + " px"
                        onPicked: next => Config.setNestedValue("iris.bar.height", Math.round(32 + next * 32))
                    }
                    Sizer {
                        title: Translation.tr("Clock size")
                        value: (root.clockScale - 80) / 70
                        figure: root.clockScale + " %"
                        onPicked: next => Config.setNestedValue("iris.bar.clockScale", Math.round((80 + next * 70) / 5) * 5)
                    }
                    Sizer {
                        title: Translation.tr("Bubbles")
                        value: (root.bubbleScale - 60) / 80
                        figure: root.bubbleScale + " %"
                        onPicked: next => Config.setNestedValue("iris.bubbles.scale", Math.round((60 + next * 80) / 5) * 5)
                    }
                    Column {
                        spacing: Math.round(4 * root.d)
                        Chip {
                            text: Translation.tr("Notch")
                            selected: Config.options?.iris?.bar?.notch ?? true
                            onClicked: Config.setNestedValue("iris.bar.notch", !(Config.options?.iris?.bar?.notch ?? true))
                        }
                        Chip {
                            text: Translation.tr("Frame")
                            selected: Config.options?.iris?.surround?.enable ?? true
                            onClicked: Config.setNestedValue("iris.surround.enable", !(Config.options?.iris?.surround?.enable ?? true))
                        }
                    }
                }
            }
        }
    }

    IrisMorphSurface {
        id: inspector
        open: root.inspecting
        motionSurface: "panels"
        color: IrisStyle.bodySurface
        fieldBacked: true
        radius: IrisStyle.radiusPlate
        light: IrisStyle.wallpaperLight
        lightFrom: root.bottomEdge ? "bottom" : "top"
        width: root.inspectorWidth
        height: root.inspectorHeight
        x: Math.round(Math.max(IrisFrame.band + 8 * root.d,
            Math.min(root.width - width - IrisFrame.band - 8 * root.d, root.bodyX + (root.bodyWidth - width) / 2)))
        y: root.bottomEdge ? root.bodyY - height - Math.round(8 * root.d)
            : root.bodyY + root.bodyHeight + Math.round(8 * root.d)
        origin: ({ x: root.bodyX, y: root.bodyY, width: root.bodyWidth, height: root.bodyHeight,
            radius: root.bodyRadius })
        visible: root.shown

        MouseArea { anchors.fill: parent }

        Flickable {
            id: inspectorScroll
            anchors.fill: parent
            anchors.margins: Math.round(10 * root.d)
            contentWidth: width
            contentHeight: inspectorBody.implicitHeight
            boundsBehavior: Flickable.StopAtBounds
            clip: true
            ColumnLayout {
                id: inspectorBody
                width: inspectorScroll.width
                spacing: 0
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: Math.round(6 * root.d)
                    Layout.bottomMargin: Math.round(4 * root.d)
                    spacing: Math.round(8 * root.d)
                    MaterialSymbol {
                        text: root.selection.length > 0 ? root.glyphOf(root.selectionKind) : "tune"
                        fill: 1
                        iconSize: Math.round(17 * root.d)
                        color: IrisStyle.accent
                    }
                    IrisText {
                        Layout.fillWidth: true
                        text: root.selection.length > 0 ? root.selectionLabel
                            : (root.targets.find(entry => entry.id === root.target)?.label ?? "")
                        font.weight: Font.DemiBold
                        font.pixelSize: 13.5 * IrisStyle.typeScale
                        elide: Text.ElideRight
                    }
                    IrisIconButton {
                        materialIcon: "close"
                        Accessible.name: Translation.tr("Close")
                        onClicked: { GlobalStates.irisEditSelection = ""; GlobalStates.irisEditTarget = "" }
                    }
                }
                Repeater {
                    model: root.inspectorRows
                    IrisSetting {
                        required property var modelData
                        Layout.fillWidth: true
                        spec: modelData
                    }
                }
            }
        }
    }

    component PieceTile: Item {
        id: tile
        property string kind: ""
        property string label: ""
        readonly property bool on: root.extraOn(tile.kind)
        readonly property bool ready: IrisPieces.available(tile.kind)
        width: Math.round(72 * root.d)
        height: Math.round(62 * root.d)
        opacity: tile.ready ? 1 : 0.45
        Rectangle {
            id: tileFace
            anchors.horizontalCenter: parent.horizontalCenter
            y: Math.round(4 * root.d)
            width: Math.round(38 * root.d)
            height: width
            radius: IrisStyle.iconRadius(width)
            color: tile.on ? IrisStyle.tintFill(IrisStyle.accent)
                : tileArea.containsMouse ? IrisStyle.fillHover : IrisStyle.fillQuiet
            border.width: tile.on ? 0 : 1
            border.color: IrisStyle.border
            scale: tileArea.pressed ? IrisStyle.pressScale(0.92) : 1
            Behavior on color { ColorAnimation { duration: IrisStyle.duration(120); easing.type: IrisStyle.feedbackEasing } }
            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration } }
            MaterialSymbol {
                anchors.centerIn: parent
                text: root.glyphOf(tile.kind)
                fill: tile.on ? 1 : 0
                iconSize: Math.round(19 * root.d)
                color: tile.on ? IrisStyle.accent : IrisStyle.text
            }
            Rectangle {
                opacity: tileArea.containsMouse || tile.on ? 1 : 0.85
                visible: tile.ready
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.rightMargin: -Math.round(4 * root.d)
                anchors.topMargin: -Math.round(4 * root.d)
                width: Math.round(15 * root.d)
                height: width
                radius: width / 2
                color: tile.on ? (tileArea.containsMouse ? IrisStyle.danger : IrisStyle.surfaceHighestOpaque)
                    : (tileArea.containsMouse ? IrisStyle.accent : IrisStyle.surfaceHighestOpaque)
                Behavior on color { ColorAnimation { duration: IrisStyle.duration(110) } }
                Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(110) } }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: tile.on ? "remove" : "add"
                    fill: 1
                    iconSize: Math.round(11 * root.d)
                    color: tileArea.containsMouse ? IrisStyle.onTint : IrisStyle.text
                }
            }
        }
        IrisText {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: tileFace.bottom
            anchors.topMargin: Math.round(4 * root.d)
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr(tile.label)
            color: tile.on ? IrisStyle.text : IrisStyle.muted
            font.pixelSize: 10 * IrisStyle.typeScale
            elide: Text.ElideRight
        }
        MouseArea {
            id: tileArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.CheckBox
            Accessible.name: tile.label
            Accessible.checked: tile.on
            onClicked: root.toggleExtra(tile.kind)
        }
    }

    component PresetMini: MouseArea {
        id: presetMini
        required property string name
        readonly property var values: IrisStyle.presets[presetMini.name] ?? IrisStyle.presets.iris
        readonly property bool selected: root.preset === presetMini.name
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.RadioButton
        Accessible.name: presetMini.name
        Accessible.checked: presetMini.selected
        onClicked: Config.setNestedValue("iris.appearance.preset", presetMini.name)
        Rectangle {
            id: presetFace
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: Math.round(42 * root.d)
            radius: Math.round(12 * presetMini.values.shape * root.d)
            color: IrisStyle.surfaceHighOpaque
            border.width: presetMini.selected ? 2 : 1
            border.color: presetMini.selected ? IrisStyle.accent : presetMini.containsMouse ? IrisStyle.borderStrong : IrisStyle.border
            Behavior on border.color { ColorAnimation { duration: IrisStyle.duration(110) } }
            Column {
                anchors.fill: parent
                anchors.margins: Math.round(7 * root.d)
                spacing: Math.round(4 * root.d)
                Rectangle {
                    width: parent.width
                    height: Math.round(12 * root.d)
                    radius: Math.round(6 * presetMini.values.shape * root.d)
                    color: Qt.alpha(IrisStyle.text, Math.min(0.5, 0.12 * presetMini.values.fill))
                }
                Row {
                    spacing: Math.round(4 * root.d)
                    Rectangle { width: Math.round(14 * root.d); height: Math.round(8 * root.d); radius: height / 2; color: IrisStyle.accent }
                    Rectangle { width: Math.round(20 * root.d); height: Math.round(8 * root.d); radius: height / 2; color: Qt.alpha(IrisStyle.text, presetMini.values.textTertiary) }
                }
            }
        }
        IrisText {
            anchors.top: presetFace.bottom
            anchors.topMargin: Math.round(4 * root.d)
            anchors.horizontalCenter: parent.horizontalCenter
            text: Translation.tr(presetMini.name.charAt(0).toUpperCase() + presetMini.name.slice(1))
            color: presetMini.selected ? IrisStyle.text : IrisStyle.subtext
            font.pixelSize: 10.5 * IrisStyle.typeScale
            font.weight: presetMini.selected ? Font.DemiBold : Font.Normal
        }
    }

    component Swatch: MouseArea {
        id: swatch
        required property string accentName
        readonly property bool selected: String(Config.options?.iris?.appearance?.accent ?? "blue") === swatch.accentName
        implicitWidth: Math.round(30 * root.d)
        implicitHeight: implicitWidth
        Layout.alignment: Qt.AlignVCenter
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        Accessible.role: Accessible.RadioButton
        Accessible.name: swatch.accentName
        Accessible.checked: swatch.selected
        onClicked: Config.setNestedValue("iris.appearance.accent", swatch.accentName)
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: swatch.selected ? 2 : 0
            border.color: IrisStyle.text
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - Math.round(8 * root.d)
            height: width
            radius: width / 2
            color: swatch.accentName === "wallpaper" ? IrisStyle.wallpaperLight : (IrisStyle.accents[swatch.accentName] ?? IrisStyle.accent)
            scale: swatch.containsMouse && !swatch.selected ? 1.08 : 1
            Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration } }
            MaterialSymbol {
                anchors.centerIn: parent
                visible: swatch.accentName === "wallpaper"
                text: "wallpaper"
                iconSize: Math.round(12 * root.d)
                color: IrisStyle.onTint
            }
        }
    }

    component Group: ColumnLayout {
        id: group
        property string title: ""
        default property alias chips: chipRow.data
        spacing: Math.round(3 * root.d)
        IrisText {
            text: group.title
            role: IrisText.Meta
            font.weight: Font.DemiBold
        }
        Row { id: chipRow; spacing: Math.round(4 * root.d) }
    }

    component Chip: IrisButton {
        quiet: !selected
        buttonRadius: height / 2
        implicitHeight: Math.round(28 * root.d)
    }

    component Sizer: ColumnLayout {
        id: sizer
        property string title: ""
        property string figure: ""
        property real value: 0
        signal picked(real value)
        Layout.fillWidth: true
        spacing: Math.round(3 * root.d)
        RowLayout {
            Layout.fillWidth: true
            IrisText { text: sizer.title; role: IrisText.Meta; font.weight: Font.DemiBold }
            Item { Layout.fillWidth: true }
            IrisText {
                text: sizer.figure
                font.family: IrisStyle.fontNumbers
                font.features: ({ "tnum": 1 })
                font.pixelSize: 12 * IrisStyle.typeScale
                color: IrisStyle.accent
            }
        }
        IrisScrubber {
            Layout.fillWidth: true
            value: Math.max(0, Math.min(1, sizer.value))
            fillColor: IrisStyle.accent
            onMoved: next => sizer.picked(next)
            onSeekRequested: next => sizer.picked(next)
        }
    }

    function glyphOf(kind: string): string {
        switch (kind) {
        case "weather": return "wb_sunny"
        case "notifications": return "notifications"
        case "controls": return "tune"
        case "sound": return "volume_up"
        case "mic": return "mic"
        case "tools": return "timer"
        case "media": return "play_circle"
        case "tray": return "widgets"
        case "calendar": return "calendar_month"
        case "clock": return "schedule"
        case "battery": return "battery_full"
        case "focus": return "bedtime"
        case "network": return "wifi"
        case "bluetooth": return "bluetooth"
        case "vitals": return "monitoring"
        case "workspaces": return "grid_view"
        case "updates": return "deployed_code_update"
        default: return "circle"
        }
    }
}
