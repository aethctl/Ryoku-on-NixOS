pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Ryoku.Ui
import Ryoku.Ui.Singletons
import shell.services

Item {
    id: root

    required property real s
    property bool active: false
    property string query: ""
    property string tool: ""
    property real maximumHeight: 520 * s
    property int selectedIndex: 0
    property bool pickerOpen: false
    property string pickerMode: "compress"
    property bool recentOpen: false
    property bool engineOpen: false
    readonly property bool motionAllowed: active && !Tokens.reduceMotion && !Motion.reduce
    readonly property var commands: [
        { id: "download", glyph: "download", name: I18n.tr("Download URL"), hint: I18n.tr("Video, audio, or mute") },
        { id: "compress", glyph: "folder_zip", name: I18n.tr("Compress files"), hint: I18n.tr("Pick videos or images") },
        { id: "install", glyph: "deployed_code", name: I18n.tr("Install package files"), hint: I18n.tr("AppImage, package, or archive") },
        { id: "recent", glyph: "history", name: I18n.tr("Recent downloads"), hint: I18n.tr("Open the Stash folder") },
        { id: "clear", glyph: "delete_sweep", name: I18n.tr("Clear recent"), hint: I18n.tr("Remove downloaded files") },
        { id: "dashboard", glyph: "dashboard", name: I18n.tr("Rashin dashboard"), hint: I18n.tr("Open setup and usage") }
    ]
    readonly property var filteredCommands: {
        const needle = query.trim().toLowerCase();
        if (needle.length === 0 || needle.indexOf("://") >= 0)
            return commands;
        return commands.filter(command => (command.name + " " + command.hint).toLowerCase().indexOf(needle) >= 0);
    }

    implicitHeight: pickerOpen ? picker.implicitHeight : toolColumn.implicitHeight

    onToolChanged: if (active && (tool === "compress" || tool === "install")) openPicker(tool)
    onActiveChanged: {
        if (active && (tool === "compress" || tool === "install"))
            Qt.callLater(() => openPicker(tool));
    }
    onFilteredCommandsChanged: selectedIndex = Math.max(0, Math.min(selectedIndex, filteredCommands.length - 1))

    function openPicker(mode) {
        pickerMode = mode;
        pickerOpen = true;
    }

    function move(delta) {
        selectedIndex = Math.max(0, Math.min(filteredCommands.length - 1, selectedIndex + delta));
    }

    function activate(value) {
        const text = value === undefined ? query : String(value);
        if (text.trim().length > 0 && /^(https?:\/\/|www\.)/i.test(text.trim())) {
            Stash.enqueueDownload(text.trim(), Stash.dlMode);
            return;
        }
        const command = filteredCommands[selectedIndex];
        if (command)
            run(command.id);
    }

    function run(id) {
        if (id === "download") {
            if (query.trim().length > 0)
                Stash.enqueueDownload(query.trim(), Stash.dlMode);
        } else if (id === "compress" || id === "install") {
            openPicker(id);
        } else if (id === "recent") {
            recentOpen = !recentOpen;
        } else if (id === "clear") {
            Stash.clearAll();
        } else if (id === "dashboard") {
            Spawn.run(["ryoku-shell", "hub", "open", "rashin"]);
        }
    }

    AskFilePicker {
        id: picker
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        s: root.s
        open: root.pickerOpen
        mode: root.pickerMode
        onCancelled: root.pickerOpen = false
        onConfirmed: paths => {
            if (root.pickerMode === "install") Stash.install(paths);
            else Stash.compress(paths);
            root.pickerOpen = false;
        }
    }

    Column {
        id: toolColumn
        width: parent.width
        visible: !root.pickerOpen
        spacing: Tokens.s3 * root.s

        Rectangle {
            width: parent.width
            height: 42 * root.s
            radius: Tokens.radius * root.s
            color: Tokens.tint5
            border.width: Tokens.border
            border.color: Tokens.lineSoft

            Row {
                anchors.left: parent.left
                anchors.leftMargin: Tokens.s3 * root.s
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.s2 * root.s
                Repeater {
                    model: [
                        { id: "auto", label: I18n.tr("Auto") },
                        { id: "audio", label: I18n.tr("Audio") },
                        { id: "mute", label: I18n.tr("Mute") }
                    ]
                    delegate: Rectangle {
                        id: modeChip
                        required property var modelData
                        width: modeLabel.implicitWidth + Tokens.s3 * root.s
                        height: Tokens.ctlH * root.s
                        radius: Tokens.radius * root.s
                        color: Stash.dlMode === modeChip.modelData.id ? Tokens.bone
                            : modeTap.pressed ? Tokens.tint16
                            : modeHover.hovered ? Tokens.tint10 : "transparent"
                        Text {
                            id: modeLabel
                            anchors.centerIn: parent
                            text: modeChip.modelData.label
                            color: Stash.dlMode === modeChip.modelData.id ? Tokens.inkOnBone : Tokens.inkDim
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fTiny * root.s
                        }
                        HoverHandler { id: modeHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { id: modeTap; onTapped: Stash.dlMode = modeChip.modelData.id }
                    }
                }
            }
            Text {
                anchors.right: parent.right
                anchors.rightMargin: Tokens.s3 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: I18n.tr("Download mode")
                color: Tokens.inkMuted
                font.family: Tokens.mono
                font.pixelSize: Tokens.fTiny * root.s
            }
        }

        Column {
            width: parent.width
            spacing: Tokens.s1 * root.s
            Repeater {
                model: root.filteredCommands
                delegate: Rectangle {
                    id: commandRow
                    required property var modelData
                    required property int index
                    width: parent.width
                    height: 48 * root.s
                    radius: Tokens.radius * root.s
                    readonly property bool current: index === root.selectedIndex
                    color: current ? Tokens.bone
                        : commandTap.pressed ? Tokens.tint16
                        : commandHover.hovered ? Tokens.tint10 : "transparent"
                    border.width: Tokens.border
                    border.color: current ? Tokens.bone : Tokens.lineSoft
                    Text {
                        id: commandGlyph
                        anchors.left: parent.left
                        anchors.leftMargin: Tokens.s3 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: commandRow.modelData.glyph
                        color: commandRow.current ? Tokens.inkOnBone : Tokens.inkMuted
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: Tokens.fBody * root.s
                    }
                    Column {
                        anchors.left: commandGlyph.right
                        anchors.right: keyHint.left
                        anchors.leftMargin: Tokens.s3 * root.s
                        anchors.rightMargin: Tokens.s2 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 0
                        Text {
                            width: parent.width
                            text: commandRow.modelData.name
                            color: commandRow.current ? Tokens.inkOnBone : Tokens.ink
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fSmall * root.s
                            font.weight: Font.Medium
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: commandRow.modelData.hint
                            color: commandRow.current ? Tokens.inkOnBone : Tokens.inkMuted
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fTiny * root.s
                            elide: Text.ElideRight
                        }
                    }
                    Text {
                        id: keyHint
                        anchors.right: parent.right
                        anchors.rightMargin: Tokens.s3 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: commandRow.current ? I18n.tr("Enter") : ""
                        color: commandRow.current ? Tokens.inkOnBone : Tokens.inkFaint
                        font.family: Tokens.mono
                        font.pixelSize: Tokens.fTiny * root.s
                    }
                    HoverHandler { id: commandHover; cursorShape: Qt.PointingHandCursor; onHoveredChanged: if (hovered) root.selectedIndex = commandRow.index }
                    TapHandler { id: commandTap; onTapped: root.run(commandRow.modelData.id) }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 44 * root.s
            radius: Tokens.radius * root.s
            color: engineTap.pressed ? Tokens.tint16 : engineHover.hovered ? Tokens.tint10 : Tokens.tint5
            border.width: Tokens.border
            border.color: Stash.cobaltState === "error" ? Tokens.lineStrong : Tokens.lineSoft
            Text {
                anchors.left: parent.left
                anchors.leftMargin: Tokens.s3 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: "memory"
                color: Stash.cobaltState === "error" ? Tokens.inkDim : Tokens.inkMuted
                font.family: "Material Symbols Rounded"
                font.pixelSize: Tokens.fBody * root.s
            }
            Column {
                anchors.left: parent.left
                anchors.right: engineToggle.left
                anchors.leftMargin: 42 * root.s
                anchors.rightMargin: Tokens.s3 * root.s
                anchors.verticalCenter: parent.verticalCenter
                Text {
                    text: I18n.tr("Download engine")
                    color: Tokens.ink
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall * root.s
                    font.weight: Font.Medium
                }
                Text {
                    text: Stash.setupState === "running" ? I18n.tr("Setting up…")
                        : Stash.cobaltState === "running" ? I18n.tr("Cobalt is on")
                        : Stash.cobaltState === "starting" ? I18n.tr("Starting Cobalt…")
                        : Stash.cobaltState === "error" ? (Stash.cobaltMsg || I18n.tr("Failed to start"))
                        : I18n.tr("Using yt-dlp")
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fTiny * root.s
                }
            }
            Rectangle {
                id: engineToggle
                anchors.right: parent.right
                anchors.rightMargin: Tokens.s3 * root.s
                anchors.verticalCenter: parent.verticalCenter
                width: 38 * root.s
                height: 22 * root.s
                radius: height / 2
                color: Stash.cobaltState === "running" || Stash.cobaltState === "starting" ? Tokens.bone : Tokens.tint10
                Rectangle {
                    width: 16 * root.s
                    height: width
                    radius: width / 2
                    x: Stash.cobaltState === "running" || Stash.cobaltState === "starting" ? parent.width - width - 3 * root.s : 3 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    color: Stash.cobaltState === "running" || Stash.cobaltState === "starting" ? Tokens.inkOnBone : Tokens.inkMuted
                    Behavior on x { enabled: root.motionAllowed; NumberAnimation { duration: Tokens.move; easing.type: Tokens.ease } }
                }
            }
            HoverHandler { id: engineHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                id: engineTap
                onTapped: {
                    if (Stash.cobaltState === "running" || Stash.cobaltState === "starting") {
                        Stash.setEngine(false);
                    } else if (Stash.dockerState === "ready") {
                        Stash.setEngine(true);
                    } else {
                        root.engineOpen = !root.engineOpen;
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            visible: root.engineOpen
            implicitHeight: visible ? engineDetails.implicitHeight + Tokens.s3 * root.s * 2 : 0
            radius: Tokens.radius * root.s
            color: Tokens.paperLift
            border.width: Tokens.border
            border.color: Tokens.lineSoft
            Column {
                id: engineDetails
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: Tokens.s3 * root.s
                spacing: Tokens.s2 * root.s
                Text {
                    width: parent.width
                    text: Stash.dockerState === "missing" ? I18n.tr("Docker is missing. Ryoku Update installs it.")
                        : Stash.dockerState === "denied" ? I18n.tr("The container helper is unavailable.")
                        : I18n.tr("Set up the local Rashin engine once.")
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall * root.s
                    wrapMode: Text.WordWrap
                }
                Repeater {
                    model: Stash.setupSteps
                    delegate: Row {
                        id: setupRow
                        required property string label
                        required property string stepState
                        required property string msg
                        spacing: Tokens.s2 * root.s
                        Text {
                            text: setupRow.stepState === "done" ? "check_circle" : setupRow.stepState === "failed" ? "error" : setupRow.stepState === "running" ? "progress_activity" : "circle"
                            color: setupRow.stepState === "pending" ? Tokens.inkFaint : Tokens.inkDim
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: Tokens.fBody * root.s
                        }
                        Text {
                            text: setupRow.msg.length > 0 ? I18n.tr(setupRow.label) + " · " + setupRow.msg : I18n.tr(setupRow.label)
                            color: Tokens.inkDim
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fTiny * root.s
                        }
                    }
                }
                Rectangle {
                    width: setupLabel.implicitWidth + Tokens.s4 * root.s
                    height: Tokens.ctlH * root.s
                    radius: Tokens.radius * root.s
                    color: Tokens.bone
                    visible: Stash.setupState !== "running" && Stash.setupState !== "done"
                    Text { id: setupLabel; anchors.centerIn: parent; text: Stash.setupState === "failed" ? I18n.tr("Retry setup") : I18n.tr("Set up"); color: Tokens.inkOnBone; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall * root.s }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: Stash.startSetup() }
                }
            }
        }

        Column {
            width: parent.width
            visible: Stash.queueModel.count > 0
            spacing: Tokens.s1 * root.s
            Text {
                text: I18n.tr("ACTIVE JOBS")
                color: Tokens.inkMuted
                font.family: Tokens.mono
                font.pixelSize: Tokens.fTiny * root.s
                font.letterSpacing: Tokens.trackLabel
            }
            Repeater {
                model: Stash.queueModel
                delegate: Rectangle {
                    id: queueRow
                    required property var model
                    required property int index
                    width: parent.width
                    implicitHeight: queueColumn.implicitHeight + Tokens.s3 * root.s * 2
                    radius: Tokens.radius * root.s
                    color: Tokens.tint5
                    border.width: Tokens.border
                    border.color: queueRow.model.state === "error" ? Tokens.lineStrong : Tokens.lineSoft
                    Column {
                        id: queueColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: Tokens.s3 * root.s
                        spacing: Tokens.s2 * root.s
                        Row {
                            width: parent.width
                            spacing: Tokens.s2 * root.s
                            Text {
                                width: parent.width - queueAction.width - parent.spacing
                                text: queueRow.model.name || queueRow.model.arg
                                color: Tokens.ink
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fSmall * root.s
                                elide: Text.ElideMiddle
                            }
                            Rectangle {
                                id: queueAction
                                width: 28 * root.s
                                height: width
                                radius: Tokens.radius * root.s
                                color: queueTap.pressed ? Tokens.tint16 : Tokens.tint10
                                Text {
                                    anchors.centerIn: parent
                                    text: queueRow.model.state === "error" ? "refresh" : "close"
                                    color: Tokens.inkMuted
                                    font.family: "Material Symbols Rounded"
                                    font.pixelSize: Tokens.fBody * root.s
                                }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                                TapHandler { id: queueTap; onTapped: queueRow.model.state === "error" ? Stash.retryJob(queueRow.index) : Stash.dismissJob(queueRow.index) }
                            }
                        }
                        Rectangle {
                            visible: queueRow.model.state === "running" || queueRow.model.state === "queued"
                            width: parent.width
                            height: 3 * root.s
                            radius: height / 2
                            color: Tokens.tint10
                            Rectangle {
                                width: parent.width * Math.max(0, Math.min(1, Number(queueRow.model.pct || 0) / 100))
                                height: parent.height
                                radius: parent.radius
                                color: Tokens.bone
                                Behavior on width { enabled: root.motionAllowed; NumberAnimation { duration: Tokens.move; easing.type: Tokens.ease } }
                            }
                        }
                        Text {
                            width: parent.width
                            text: queueRow.model.state === "running" ? queueRow.model.pct + "%"
                                : queueRow.model.state === "error" ? (queueRow.model.msg || I18n.tr("Failed"))
                                : queueRow.model.state === "done" ? I18n.tr("Done") : I18n.tr("Queued")
                            color: Tokens.inkMuted
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fTiny * root.s
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }

        Column {
            width: parent.width
            visible: root.recentOpen
            spacing: Tokens.s1 * root.s
            Text {
                visible: Stash.recentFiles.length === 0
                text: I18n.tr("No recent downloads")
                color: Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall * root.s
            }
            Repeater {
                model: Stash.recentFiles
                delegate: Rectangle {
                    id: recentRow
                    required property var modelData
                    width: parent.width
                    height: 38 * root.s
                    radius: Tokens.radius * root.s
                    color: recentTap.pressed ? Tokens.tint16 : recentHover.hovered ? Tokens.tint10 : "transparent"
                    Text {
                        anchors.left: parent.left
                        anchors.right: removeRecent.left
                        anchors.leftMargin: Tokens.s3 * root.s
                        anchors.rightMargin: Tokens.s2 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: recentRow.modelData.name
                        color: Tokens.ink
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall * root.s
                        elide: Text.ElideMiddle
                    }
                    Text {
                        id: removeRecent
                        anchors.right: parent.right
                        anchors.rightMargin: Tokens.s3 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: "close"
                        color: Tokens.inkMuted
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: Tokens.fBody * root.s
                        TapHandler { onTapped: Stash.removeFile(recentRow.modelData.path) }
                    }
                    HoverHandler { id: recentHover; cursorShape: Qt.PointingHandCursor }
                    TapHandler { id: recentTap; onTapped: Stash.openFile(recentRow.modelData.path) }
                }
            }
        }
    }
}
