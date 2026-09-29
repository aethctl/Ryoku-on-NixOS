import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: root

    required property PickerState state
    readonly property LibraryView view: root.state ? root.state.view : null

    anchors.fill: parent

    readonly property bool shown: root.state ? root.state.searchOpen : false
    readonly property string mode: root.state ? (root.state.searchMode || "tags") : "tags"
    readonly property bool describe: root.mode === "describe"

    readonly property bool lensAvailable: {
        var s = Settings.schema
        return !!(s && s.availability && s.availability.lens)
    }

    property SettingValue svRows: SettingValue { key: "components.wallpaperSelector.tagCloudRows" }
    property SettingValue svWidth: SettingValue { key: "components.wallpaperSelector.tagCloudWidth" }
    property SettingValue svHeight: SettingValue { key: "components.wallpaperSelector.tagCloudHeight" }
    property SettingValue svOffX: SettingValue { key: "components.wallpaperSelector.tagCloudOffsetX" }
    property SettingValue svOffY: SettingValue { key: "components.wallpaperSelector.tagCloudOffsetY" }
    property SettingValue svDefaultMode: SettingValue { key: "tagging.defaultSearchMode" }

    function _num(sv, def) { var v = Number(sv.value); return (isNaN(v) || v <= 0) ? def : v }
    readonly property int cloudRows: Math.max(1, Math.min(3, root._num(svRows, 3)))
    readonly property real panelWidth: root._num(svWidth, 720) * Theme.scale
    readonly property real panelHeight: root._num(svHeight, 300) * Theme.scale
    readonly property rect stage: root.state && root.state.field
        ? root.state.field.stageRect : Qt.rect(0, 0, root.width, root.height)

    property real reveal: 0
    states: State { name: "open"; when: root.shown; PropertyChanges { target: root; reveal: 1 } }
    Behavior on reveal { NumberAnimation { duration: Theme.standard; easing.type: Theme.revealEasing } }
    visible: reveal > 0.01

    Keys.onEscapePressed: if (root.state) root.state.searchOpen = false

    onShownChanged: {
        if (!root.shown || !root.state) return
        if (root.describe && !root.lensAvailable) root.state.searchMode = "tags"
        else if (!root.state.searchMode) root.state.searchMode = (root.svDefaultMode.value || "tags")
        root._aggregate()
    }

    // The cloud is the whole-collection histogram, rebuilt only when the library changes.
    property var tagCounts: ({})
    function _aggregate() {
        root.tagCounts = (root.view) ? Library.tagHistogram(root.view.collection) : ({})
    }
    Connections {
        target: Library
        function onChanged(collection) {
            if (root.view && collection === root.view.collection) root._aggregate()
        }
    }
    Connections {
        target: root.view
        ignoreUnknownSignals: true
        function onCollectionChanged() { root._aggregate() }
    }

    property bool orderPopular: true
    readonly property var tagList: {
        var out = []
        for (var k in root.tagCounts) out.push({ tag: k, count: root.tagCounts[k] })
        if (root.orderPopular) out.sort(function (a, b) { return b.count - a.count || (a.tag < b.tag ? -1 : 1) })
        else out.sort(function (a, b) { return a.tag < b.tag ? -1 : (a.tag > b.tag ? 1 : 0) })
        return out.slice(0, 400)
    }

    property var selected: []
    property bool multi: false
    property bool matchAny: false
    // A tag is "include", "exclude" (stored as "-tag") or "".
    function _tagState(tag) {
        if (root.selected.indexOf(tag) >= 0) return "include"
        if (root.selected.indexOf("-" + tag) >= 0) return "exclude"
        return ""
    }
    function _removeForms(s, tag) {
        var i = s.indexOf(tag); if (i >= 0) s.splice(i, 1)
        var j = s.indexOf("-" + tag); if (j >= 0) s.splice(j, 1)
        return s
    }
    // Left-click toggles include, right-click toggles exclude; single mode replaces the selection.
    function _toggle(tag, exclude) {
        var token = exclude ? "-" + tag : tag
        var already = root.selected.indexOf(token) >= 0
        var s = root.multi ? root.selected.slice() : []
        if (root.multi) s = root._removeForms(s, tag)
        if (!already) s.push(token)
        root.selected = s
        root._applyTags()
    }
    function _clear() { root.selected = []; root._applyTags() }
    function _applyTags() {
        if (!root.view) return
        root.view.tagsMatchAny = root.matchAny
        root.view.tags = root.selected.slice()
    }

    // status: "" idle, searching, ready, error or unavailable.
    property string semanticStatus: ""
    property int semanticMs: 0
    property string describeText: ""
    Timer {
        id: describeDebounce
        interval: 260
        onTriggered: root._runSemantic()
    }
    function _runSemantic() {
        if (!root.view) return
        var q = root.describeText.trim()
        if (q.length === 0) { root.view.keyOrder = []; root.semanticStatus = ""; return }
        root.semanticStatus = "searching"
        var t0 = Date.now()
        Daemon.call("semantic.query", { query: q }, function (r, e) {
            if (e) { root.semanticStatus = "error"; return }
            var keys = r && r.keys ? r.keys : (Array.isArray(r) ? r : [])
            root.view.keyOrder = keys
            root.semanticMs = (r && r.ms) ? r.ms : (Date.now() - t0)
            root.semanticStatus = "ready"
        })
    }
    function _refreshSemanticStatus() {
        if (!root.lensAvailable) { root.semanticStatus = "unavailable"; return }
        Daemon.call("semantic.status", {}, function (r, e) {
            if (r && r.ready === false) root.semanticStatus = "indexing"
        })
    }

    function _statusText() {
        if (root.semanticStatus === "unavailable") return I18n.tr("Not available")
        if (root.semanticStatus === "searching") return I18n.tr("Searching")
        if (root.semanticStatus === "error") return I18n.tr("Error")
        if (root.semanticStatus === "indexing") return I18n.tr("Indexing")
        if (root.semanticStatus === "ready") return root.semanticMs + " " + I18n.tr("ms")
        return I18n.tr("Ready")
    }
    function _statusColor() {
        if (root.semanticStatus === "error" || root.semanticStatus === "unavailable")
            return Theme.tertiary
        if (root.semanticStatus === "searching" || root.semanticStatus === "indexing")
            return Theme.primary
        return Theme.withAlpha(Theme.surfaceText, 0.62)
    }

    Component.onCompleted: root._refreshSemanticStatus()

    function _setMode(m) {
        if (m === "describe" && !root.lensAvailable) return
        if (root.state) root.state.searchMode = m
    }

    Rectangle {
        id: panel
        width: root.panelWidth
        height: root.panelHeight
        x: Math.max((root.width - width) * 0.5 + Number(root.svOffX.value || 0), 0)
        y: {
            var oy = Number(root.svOffY.value || 0)
            if (root.state && root.state.mode === "sandy")
                return Math.max(root.stage.y - 12 - height + oy, 0)
            return Math.max(Math.min(root.stage.y + root.stage.height + 14 + oy, root.height - height - 16), 0)
        }
        opacity: root.reveal
        transform: Translate { y: (1 - root.reveal) * 12 * Theme.scale }

        color: Theme.withAlpha(Theme.surface, 0.97)
        border.width: 1
        border.color: Theme.withAlpha(Theme.primary, 0.48)

        MouseArea { anchors.fill: parent }

        Column {
            id: body
            anchors.fill: parent
            anchors.topMargin: 10 * Theme.scale
            anchors.bottomMargin: 10 * Theme.scale
            anchors.leftMargin: 18 * Theme.scale
            anchors.rightMargin: 18 * Theme.scale
            spacing: 8 * Theme.scale

            Item {
                width: parent.width
                height: 22 * Theme.scale

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10 * Theme.scale
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Tag filter")
                        font.family: Theme.ui
                        font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontXSmall
                        color: Theme.withAlpha(Theme.surfaceText, 0.82)
                        renderType: Text.NativeRendering
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: (root.view ? root.view.count : 0) + " " + I18n.tr("wallpapers")
                        font.family: Theme.ui
                        font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontXSmall
                        color: Theme.withAlpha(Theme.surfaceText, 0.6)
                        renderType: Text.NativeRendering
                    }
                    Text {
                        visible: root.describe
                        anchors.verticalCenter: parent.verticalCenter
                        text: root._statusText()
                        font.family: Theme.ui
                        font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontXSmall
                        color: root._statusColor()
                        renderType: Text.NativeRendering
                    }
                }

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6 * Theme.scale

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Multi")
                        font.family: Theme.ui; font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontFine
                        color: Theme.withAlpha(Theme.surfaceText, 0.6)
                        renderType: Text.NativeRendering
                    }
                    ControlChip { label: I18n.tr("On"); active: root.multi; onPicked: root.multi = true }
                    ControlChip { label: I18n.tr("Off"); active: !root.multi; onPicked: { root.multi = false; if (root.selected.length > 1) root._clear() } }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Match")
                        font.family: Theme.ui; font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontFine
                        color: Theme.withAlpha(Theme.surfaceText, 0.6)
                        renderType: Text.NativeRendering
                    }
                    ControlChip { label: I18n.tr("All"); active: !root.matchAny; onPicked: { root.matchAny = false; root._applyTags() } }
                    ControlChip { label: I18n.tr("Any"); active: root.matchAny; onPicked: { root.matchAny = true; root._applyTags() } }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Order")
                        font.family: Theme.ui; font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontFine
                        color: Theme.withAlpha(Theme.surfaceText, 0.6)
                        renderType: Text.NativeRendering
                    }
                    ControlChip { label: I18n.tr("Popular"); active: root.orderPopular; onPicked: root.orderPopular = true }
                    ControlChip { label: I18n.tr("A-Z"); active: !root.orderPopular; onPicked: root.orderPopular = false }
                }
            }

            Rectangle {
                width: parent.width
                height: 46 * Theme.scale
                color: Theme.withAlpha(Theme.surfaceVariant, 0.94)
                border.width: 1
                border.color: Theme.withAlpha(Theme.primary, 0.5)

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12 * Theme.scale
                    anchors.rightMargin: 5 * Theme.scale
                    spacing: 8 * Theme.scale

                    ControlChip {
                        anchors.verticalCenter: parent.verticalCenter
                        label: I18n.tr("Tags")
                        active: !root.describe
                        onPicked: root._setMode("tags")
                    }
                    ControlChip {
                        anchors.verticalCenter: parent.verticalCenter
                        label: I18n.tr("Describe")
                        active: root.describe
                        enabled: root.lensAvailable
                        onPicked: root._setMode("describe")
                    }
                    Text {
                        visible: root.describe
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("SigLIP2 B/16")
                        font.family: Theme.ui; font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontMini
                        color: Theme.withAlpha(Theme.surfaceText, 0.5)
                        renderType: Text.NativeRendering
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "\u{f0349}"
                        font.family: Theme.icon
                        font.pixelSize: Theme.fontHead
                        color: Theme.tertiary
                        renderType: Text.NativeRendering
                    }

                    TextInput {
                        id: queryInput
                        width: parent.width - x - 8 * Theme.scale
                        anchors.verticalCenter: parent.verticalCenter
                        enabled: !root.describe || root.lensAvailable
                        font.family: Theme.ui; font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontLabel
                        color: Theme.surfaceText
                        selectionColor: Theme.withAlpha(Theme.primary, 0.4)
                        selectByMouse: true
                        clip: true
                        renderType: Text.NativeRendering

                        onTextEdited: {
                            if (root.describe) {
                                root.describeText = text
                                describeDebounce.restart()
                            } else if (root.view) {
                                root.view.query = text
                            }
                        }
                        Keys.onTabPressed: function (event) {
                            if (root.describe) { event.accepted = false; return }
                            var frag = queryInput.text.trim().toLowerCase()
                            if (frag.length > 0) {
                                for (var i = 0; i < root.tagList.length; ++i) {
                                    var t = root.tagList[i].tag
                                    if (t.toLowerCase().indexOf(frag) === 0) {
                                        queryInput.text = t
                                        queryInput.cursorPosition = t.length
                                        if (root.view) root.view.query = t
                                        break
                                    }
                                }
                            }
                            event.accepted = true
                        }

                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: queryInput.text.length === 0
                            text: root.describe ? I18n.tr("Describe the wallpaper you want…")
                                                : I18n.tr("Search tags and metadata…")
                            font: queryInput.font
                            color: Theme.withAlpha(Theme.surfaceText, 0.42)
                            elide: Text.ElideRight
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: !root.describe
                text: I18n.tr("Ranges: width:1920..3840 · duration:<30s · size:>=10MiB · | means OR · - excludes")
                font.family: Theme.ui; font.weight: Theme.uiWeight
                font.pixelSize: Theme.fontTiny
                color: Theme.withAlpha(Theme.surfaceText, 0.62)
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }

            Flickable {
                visible: !root.describe
                width: parent.width
                height: root.cloudRows * 27 * Theme.scale + (root.cloudRows - 1) * 6 * Theme.scale
                contentHeight: cloud.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Flow {
                    id: cloud
                    width: parent.width
                    spacing: 6 * Theme.scale

                    Repeater {
                        model: root.tagList
                        delegate: Rectangle {
                            id: chip
                            required property var modelData
                            readonly property string tagState: root._tagState(modelData.tag)
                            readonly property bool included: tagState === "include"
                            readonly property bool excluded: tagState === "exclude"
                            readonly property bool hovered: chipMouse.containsMouse
                            height: 27 * Theme.scale
                            implicitWidth: chipText.implicitWidth + 22 * Theme.scale
                            width: implicitWidth
                            color: chip.included ? Theme.primary
                                 : chip.excluded ? Theme.withAlpha(Theme.tertiary, 0.16)
                                 : hovered ? Theme.withAlpha(Theme.surfaceVariant, 0.8)
                                 : Theme.withAlpha(Theme.surfaceContainer, 0.9)
                            border.width: 1
                            border.color: chip.included ? Theme.withAlpha(Theme.outline, 0.7)
                                        : chip.excluded ? Theme.withAlpha(Theme.tertiary, 0.72)
                                        : Theme.withAlpha(Theme.outline, 0.38)
                            Text {
                                id: chipText
                                anchors.centerIn: parent
                                text: (chip.excluded ? "\u2212" : "") + chip.modelData.tag.toUpperCase() + "  "
                                    + (chip.modelData.count >= 1000
                                        ? (Math.round(chip.modelData.count / 100) / 10) + "k"
                                        : chip.modelData.count)
                                font.family: Theme.ui; font.weight: Theme.uiWeight
                                font.pixelSize: Theme.fontBase
                                color: chip.included ? Theme.primaryText
                                     : chip.excluded ? Theme.tertiary
                                     : Theme.withAlpha(Theme.surfaceText, 0.84)
                                renderType: Text.NativeRendering
                            }
                            MouseArea {
                                id: chipMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                cursorShape: Qt.PointingHandCursor
                                onClicked: function (mouse) {
                                    root._toggle(chip.modelData.tag, mouse.button === Qt.RightButton)
                                }
                            }
                        }
                    }

                    Text {
                        visible: root.tagList.length === 0
                        text: I18n.tr("No tags yet")
                        font.family: Theme.ui; font.weight: Theme.uiWeight
                        font.pixelSize: Theme.fontLabel
                        color: Theme.withAlpha(Theme.surfaceText, 0.72)
                        renderType: Text.NativeRendering
                    }
                }
            }

            Row {
                visible: !root.describe && root.selected.length > 0
                width: parent.width
                spacing: 10 * Theme.scale
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.selected.length + " " + I18n.tr("selected")
                    font.family: Theme.ui; font.weight: Theme.uiWeight
                    font.pixelSize: Theme.fontFine
                    color: Theme.primary
                    renderType: Text.NativeRendering
                }
                ControlChip { label: I18n.tr("Clear"); onPicked: root._clear() }
            }

            Text {
                visible: root.describe && !root.lensAvailable
                width: parent.width
                text: I18n.tr("Describe search is not available. Enable semantic search in settings to search by describing a wallpaper.")
                wrapMode: Text.WordWrap
                font.family: Theme.ui; font.weight: Theme.uiWeight
                font.pixelSize: Theme.fontBase
                color: Theme.withAlpha(Theme.surfaceText, 0.6)
                renderType: Text.NativeRendering
            }
        }
    }

    component ControlChip: Rectangle {
        id: cc
        property string label: ""
        property bool active: false
        signal picked()
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        height: 26 * Theme.scale
        implicitWidth: ccText.implicitWidth + 20 * Theme.scale
        width: implicitWidth
        color: !cc.enabled ? Theme.withAlpha(Theme.surfaceContainer, 0.4)
             : cc.active ? Theme.primary
             : ccMouse.containsMouse ? Theme.withAlpha(Theme.surfaceVariant, 0.8)
             : Theme.withAlpha(Theme.surfaceContainer, 0.9)
        border.width: 1
        border.color: cc.active ? Theme.withAlpha(Theme.outline, 0.7) : Theme.withAlpha(Theme.outline, 0.4)
        Text {
            id: ccText
            anchors.centerIn: parent
            text: cc.label
            font.family: Theme.ui; font.weight: Theme.uiWeight
            font.pixelSize: Theme.fontMini
            color: !cc.enabled ? Theme.withAlpha(Theme.surfaceText, 0.34)
                 : cc.active ? Theme.primaryText : Theme.surfaceText
            renderType: Text.NativeRendering
        }
        MouseArea {
            id: ccMouse
            anchors.fill: parent
            hoverEnabled: true
            enabled: cc.enabled
            cursorShape: Qt.PointingHandCursor
            onClicked: cc.picked()
        }
    }
}
