pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import shell.services
import "../../../components"
import Ryoku.Ui.Singletons

// Chat: the Super+S sidebar's live view of the one shared agent session, held in
// the Needle singleton. The header picks the agent and model and toggles
// approvals; the transcript streams thinking, tool activity, approvals and
// Markdown answers; the composer attaches images and sends. This file is the
// composition; each row type and the overlays are their own Chat* component.
Item {
    id: root

    property real s: 1
    property bool open: false

    property bool modelPickerOpen: false
    property bool historyOpen: false

    implicitHeight: 648 * root.s

    function scrollEnd() {
        if (list.stick)
            Qt.callLater(list.positionViewAtEnd);
    }

    Component.onCompleted: {
        Needle.noteOpened();
        composer.forceFocus();
        root.scrollEnd();
    }
    Component.onDestruction: Needle.noteClosed()
    onOpenChanged: if (root.open) composer.forceFocus()

    Connections {
        target: Needle
        function onTouched() { root.scrollEnd(); }
    }

    // Drop image files anywhere on the panel to attach them.
    DropArea {
        anchors.fill: parent
        onDropped: (drop) => {
            if (!drop.hasUrls)
                return;
            for (var i = 0; i < drop.urls.length; i++)
                composer.addDropUrl(drop.urls[i]);
            drop.accept();
        }
    }

    ChatHeader {
        id: header
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 14 * root.s
        s: root.s
        onRequestModelPicker: root.modelPickerOpen = true
        onRequestHistory: {
            root.historyOpen = true;
            Needle.loadSessions();
        }
        onRequestNewChat: {
            Needle.newChat();
            composer.pendingImages = [];
            composer.forceFocus();
        }
    }

    // ── transcript ──
    ListView {
        id: list
        anchors.top: header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: workingStrip.top
        anchors.leftMargin: 14 * root.s
        anchors.rightMargin: 14 * root.s
        anchors.topMargin: 8 * root.s
        anchors.bottomMargin: 6 * root.s
        clip: true
        spacing: 12 * root.s
        model: Needle.convo
        boundsBehavior: Flickable.StopAtBounds
        cacheBuffer: 6000

        // Stay pinned to the newest content unless the user scrolled up.
        property bool stick: true
        onCountChanged: if (stick) Qt.callLater(positionViewAtEnd)
        onContentHeightChanged: if (stick) Qt.callLater(positionViewAtEnd)
        onMovementEnded: stick = atYEnd

        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        delegate: Item {
            id: row
            required property int index
            required property string kind
            required property string role
            required property string body
            required property string thought
            required property bool open
            required property bool live
            required property bool cont
            required property bool failed
            required property string imagesJson
            required property string toolId
            required property string title
            required property string tkind
            required property string status
            required property string input
            required property string output
            required property string diffsJson
            required property bool auto
            required property string permJson

            width: ListView.view ? ListView.view.width : 0
            implicitHeight: content.implicitHeight

            Loader {
                id: content
                width: row.width
                sourceComponent: row.kind === "tool" ? toolC : msgC
            }
            Component {
                id: msgC
                ChatMessage {
                    s: root.s; width: row.width
                    role: row.role; body: row.body; thought: row.thought
                    open: row.open; live: row.live; cont: row.cont; failed: row.failed; imagesJson: row.imagesJson
                }
            }
            Component {
                id: toolC
                ChatToolRow {
                    s: root.s; width: row.width
                    toolId: row.toolId; title: row.title; tkind: row.tkind; status: row.status
                    input: row.input; output: row.output; diffsJson: row.diffsJson
                    auto: row.auto; permJson: row.permJson
                }
            }
        }

        // Approvals with no tool row yet sit at the end of the stream.
        footer: Column {
            width: list.width
            spacing: 8 * root.s
            bottomPadding: 4 * root.s
            Repeater {
                model: Needle.standalonePerms
                delegate: ChatApproval {
                    required property var modelData
                    width: list.width
                    s: root.s
                    perm: modelData
                }
            }
        }
    }

    // ── empty state ──
    Column {
        anchors.centerIn: list
        width: Math.min(list.width - 32 * root.s, 300 * root.s)
        spacing: 9 * root.s
        visible: Needle.convo.count === 0

        MaterialIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "cognition"
            font.pixelSize: 32 * root.s
            fill: 0
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.6)
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Needle.ready ? I18n.tr("Ask the needle") : I18n.tr("Connect an AI")
            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
            font.family: Theme.display
            font.pixelSize: 21 * root.s
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: Needle.ready
                ? I18n.tr("It knows this machine, your desktop, and the Ryoku source. Drop in an image to ask about it.")
                : I18n.tr("Rashin needs an AI to answer. Set it up once and the needle is ready.")
            wrapMode: Text.WordWrap
            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
            font.family: Theme.fontPrimary
            font.pixelSize: 11 * root.s
            lineHeight: 1.3
        }
        Column {
            visible: Needle.ready
            width: parent.width
            spacing: 6 * root.s
            topPadding: 4 * root.s
            Repeater {
                model: [
                    { icon: "bolt", text: I18n.tr("Why is my battery draining?") },
                    { icon: "wallpaper", text: I18n.tr("How do I change my wallpaper?") },
                    { icon: "terminal", text: I18n.tr("Where does the shell config live?") }
                ]
                delegate: Rectangle {
                    id: ex
                    required property var modelData
                    width: parent.width
                    height: 34 * root.s
                    radius: 8 * root.s
                    color: exArea.containsMouse
                        ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)
                        : "transparent"
                    border.width: 1
                    border.color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.14)
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 10 * root.s
                        anchors.right: parent.right
                        anchors.rightMargin: 10 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 9 * root.s
                        MaterialIcon {
                            anchors.verticalCenter: parent.verticalCenter
                            text: ex.modelData.icon
                            font.pixelSize: 14 * root.s
                            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.85)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            width: parent.width - 23 * root.s
                            text: ex.modelData.text
                            elide: Text.ElideRight
                            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                            font.family: Theme.fontPrimary
                            font.pixelSize: 11.5 * root.s
                        }
                    }
                    MouseArea {
                        id: exArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: composer.setText(ex.modelData.text)
                    }
                }
            }
        }
        Column {
            width: parent.width
            spacing: 8 * root.s
            topPadding: 4 * root.s
            visible: !Needle.ready
            Rectangle {
                width: parent.width
                height: 36 * root.s
                radius: 8 * root.s
                color: setupArea.containsMouse ? Theme.vermLit : Theme.primary
                Behavior on color { ColorAnimation { duration: Motion.fast } }
                Row {
                    anchors.centerIn: parent
                    spacing: 7 * root.s
                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "auto_awesome"
                        font.pixelSize: 15 * root.s
                        color: Theme.inkOn(Theme.primary, Theme.onPrimary)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("Open setup")
                        color: Theme.inkOn(Theme.primary, Theme.onPrimary)
                        font.family: Theme.fontPrimary
                        font.pixelSize: 12 * root.s
                        font.weight: Font.Medium
                    }
                }
                MouseArea {
                    id: setupArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["ryoku-shell", "hub", "open", "rashin"])
                }
            }
            Text {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: I18n.tr("Or add an API key to ~/.config/ryoku/rashin.env")
                wrapMode: Text.WordWrap
                color: Theme.inkOn(Theme.effectiveSurface, Theme.outlineVariant, 3.0)
                font.family: Theme.mono
                font.pixelSize: 9 * root.s
            }
        }
    }

    // ── working strip: what the agent is doing right now ──
    Item {
        id: workingStrip
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: composer.top
        anchors.leftMargin: 16 * root.s
        anchors.rightMargin: 16 * root.s
        anchors.bottomMargin: visible ? 6 * root.s : 0
        visible: Needle.busy
        height: visible ? 20 * root.s : 0

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 7 * root.s
            Rectangle {
                width: 6 * root.s
                height: 6 * root.s
                radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.primary
                SequentialAnimation on opacity {
                    running: workingStrip.visible
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.3; to: 1; duration: 520 }
                    NumberAnimation { from: 1; to: 0.3; duration: 520 }
                }
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: Needle.activity.length > 0 ? Needle.activity : I18n.tr("working")
                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                font.family: Theme.fontPrimary
                font.pixelSize: 11 * root.s
                elide: Text.ElideRight
                width: workingStrip.width - 20 * root.s
            }
        }
    }

    ChatComposer {
        id: composer
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12 * root.s
        s: root.s
    }

    // ── overlays ──
    ChatModelPicker {
        s: root.s
        visible: root.modelPickerOpen
        onClosed: root.modelPickerOpen = false
    }

    // session history drawer
    MouseArea {
        anchors.fill: parent
        visible: root.historyOpen
        z: 22
        onClicked: root.historyOpen = false
    }
    Rectangle {
        id: historyDrawer
        visible: root.historyOpen
        z: 23
        anchors.top: header.bottom
        anchors.right: parent.right
        anchors.topMargin: 4 * root.s
        anchors.rightMargin: 14 * root.s
        width: 260 * root.s
        height: Math.min((Needle.sessions.length + 1) * 34 * root.s + 8 * root.s, 340 * root.s)
        radius: Theme.radiusWidget
        color: Qt.rgba(Theme.effectiveSurface.r, Theme.effectiveSurface.g, Theme.effectiveSurface.b, 0.99)
        border.width: Theme.borderWidth
        border.color: Theme.outline
        clip: true
        SumiEdge { radius: Theme.radiusWidget }
        Column {
            anchors.fill: parent
            anchors.margins: 4 * root.s
            Rectangle {
                width: parent.width
                height: 32 * root.s
                radius: 6 * root.s
                color: ncArea.containsMouse ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : "transparent"
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6 * root.s
                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "add_comment"
                        font.pixelSize: 12 * root.s
                        color: Theme.primary
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("New chat")
                        color: Theme.primary
                        font.family: Theme.mono
                        font.pixelSize: 9.5 * root.s
                    }
                }
                MouseArea {
                    id: ncArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Needle.newChat();
                        composer.pendingImages = [];
                        root.historyOpen = false;
                        composer.forceFocus();
                    }
                }
            }
            ListView {
                width: parent.width
                height: parent.height - 34 * root.s
                clip: true
                model: Needle.sessions
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                    id: sRow
                    required property var modelData
                    width: ListView.view ? ListView.view.width : 0
                    height: 32 * root.s
                    radius: 6 * root.s
                    color: sArea.containsMouse ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10) : "transparent"
                    Text {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.leftMargin: 10 * root.s
                        anchors.rightMargin: 8 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: (sRow.modelData.title && sRow.modelData.title.length) ? sRow.modelData.title : I18n.tr("untitled")
                        elide: Text.ElideRight
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                        font.family: Theme.fontPrimary
                        font.pixelSize: 10.5 * root.s
                    }
                    MouseArea {
                        id: sArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            Needle.switchSession(sRow.modelData.id);
                            root.historyOpen = false;
                        }
                    }
                }
            }
        }
    }
}
