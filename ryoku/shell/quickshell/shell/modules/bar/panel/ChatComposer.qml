pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import shell.services
import "../../../components"
import Ryoku.Ui.Singletons

// The composer: a growing input with image attach (paperclip, Ctrl+V, drop), a
// slash-command palette over the session's built-in commands, Enter to send,
// Shift+Enter for a newline, and a Stop button while the shared turn is busy.
Item {
    id: root

    property real s: 1
    property var pendingImages: []
    readonly property int maxImages: 3

    readonly property real minInputH: 20 * root.s
    readonly property real maxInputH: 132 * root.s

    implicitHeight: inputWrap.implicitHeight

    function forceFocus() { Qt.callLater(input.forceActiveFocus); }
    function setText(t) {
        input.text = String(t);
        input.cursorPosition = input.text.length;
        input.forceActiveFocus();
    }
    function isImagePath(p) {
        return /\.(png|jpe?g|webp|gif|bmp|avif|svg)$/i.test(String(p));
    }
    function addImage(p) {
        var path = String(p).replace(/^file:\/\//, "");
        if (path.length === 0 || root.pendingImages.length >= root.maxImages)
            return;
        if (root.pendingImages.indexOf(path) >= 0)
            return;
        root.pendingImages = root.pendingImages.concat([path]);
    }
    function addDropUrl(url) {
        if (root.isImagePath(url))
            root.addImage(url);
    }
    function removeImage(i) {
        root.pendingImages = root.pendingImages.filter((_, idx) => idx !== i);
    }
    function submit() {
        var q = input.text.trim();
        if ((q.length === 0 && root.pendingImages.length === 0) || Needle.busy)
            return;
        Needle.send(q, root.pendingImages);
        input.text = "";
        root.pendingImages = [];
    }

    // ── slash palette ──
    property int paletteIdx: 0
    property bool paletteDismissed: false
    readonly property bool slashMode: input.text.length > 0 && input.text.charAt(0) === "/"
        && input.text.indexOf(" ") === -1 && !root.paletteDismissed
    readonly property var slashMatches: {
        if (!root.slashMode)
            return [];
        var pre = input.text.slice(1).toLowerCase();
        var cmds = (Needle.commands || []).map(c => ({ name: String(c.name), description: String(c.description || "") }));
        if (pre === "")
            return cmds;
        return cmds.filter(e => e.name.toLowerCase().indexOf(pre) === 0);
    }
    readonly property bool paletteOpen: root.slashMode && root.slashMatches.length > 0
    function acceptSlash() {
        if (root.slashMatches.length === 0)
            return;
        var idx = Math.max(0, Math.min(root.paletteIdx, root.slashMatches.length - 1));
        input.text = "/" + root.slashMatches[idx].name + " ";
        input.cursorPosition = input.text.length;
    }

    // File picker (paperclip): zenity returns the chosen path on stdout.
    Process {
        id: pickProc
        command: ["zenity", "--file-selection", "--title=Attach an image",
            "--file-filter=Images | *.png *.jpg *.jpeg *.webp *.gif *.bmp *.avif",
            "--file-filter=All files | *"]
        stdout: StdioCollector {
            id: pickOut
            onStreamFinished: {
                var p = ("" + pickOut.text).trim();
                if (p.length > 0 && root.isImagePath(p))
                    root.addImage(p);
            }
        }
    }

    // Ctrl+V image: if the clipboard holds an image, save it and attach it. Text
    // paste is left to the TextArea (this prints nothing then).
    Process {
        id: pasteImgProc
        command: ["sh", "-c",
            't=$(wl-paste --list-types 2>/dev/null | grep -m1 -E "^image/"); [ -z "$t" ] && exit 0; ' +
            'd="${XDG_RUNTIME_DIR:-/tmp}/ryoku-chat"; mkdir -p "$d"; ext=${t#image/}; ' +
            'case "$ext" in jpeg) ext=jpg;; svg+xml) ext=svg;; esac; ' +
            'f="$d/paste-$(date +%s%N).$ext"; wl-paste --type "$t" > "$f" 2>/dev/null && printf "%s" "$f"']
        stdout: StdioCollector {
            id: pasteOut
            onStreamFinished: {
                var p = ("" + pasteOut.text).trim();
                if (p.length > 0)
                    root.addImage(p);
            }
        }
    }

    Rectangle {
        id: palette
        visible: root.paletteOpen
        clip: true
        anchors.left: inputWrap.left
        anchors.right: inputWrap.right
        anchors.bottom: inputWrap.top
        anchors.bottomMargin: 6 * root.s
        height: Math.min(root.slashMatches.length * 30 * root.s, 180 * root.s) + 8 * root.s
        radius: 10 * root.s
        color: Qt.rgba(Theme.effectiveSurface.r, Theme.effectiveSurface.g, Theme.effectiveSurface.b, 0.98)
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.4)
        ListView {
            id: paletteList
            anchors.fill: parent
            anchors.margins: 4 * root.s
            clip: true
            model: root.slashMatches
            currentIndex: root.paletteIdx
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
            onCurrentIndexChanged: paletteList.positionViewAtIndex(paletteList.currentIndex, ListView.Contain)
            delegate: Rectangle {
                id: pRow
                required property var modelData
                required property int index
                width: paletteList.width
                height: 30 * root.s
                radius: 6 * root.s
                color: root.paletteIdx === pRow.index ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.16) : "transparent"
                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 8 * root.s
                    anchors.rightMargin: 8 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8 * root.s
                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "bolt"
                        font.pixelSize: 12 * root.s
                        color: Theme.primary
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "/" + pRow.modelData.name
                        color: Theme.primary
                        font.family: Theme.mono
                        font.pixelSize: 11 * root.s
                        width: 82 * root.s
                        elide: Text.ElideRight
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: pRow.modelData.description || ""
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                        font.family: Theme.fontPrimary
                        font.pixelSize: 10.5 * root.s
                        width: paletteList.width - 128 * root.s
                        elide: Text.ElideRight
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.paletteIdx = pRow.index
                    onClicked: {
                        root.paletteIdx = pRow.index;
                        root.acceptSlash();
                        input.forceActiveFocus();
                    }
                }
            }
        }
    }

    Rectangle {
        id: inputWrap
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        radius: Theme.radiusWidget
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: input.activeFocus ? Theme.primary : Theme.outline
        Behavior on border.color { ColorAnimation { duration: Motion.fast } }
        implicitHeight: inputCol.implicitHeight + 14 * root.s
        SumiEdge { radius: Theme.radiusWidget }

        Column {
            id: inputCol
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 7 * root.s
            spacing: 7 * root.s

            Flow {
                width: parent.width
                spacing: 6 * root.s
                visible: root.pendingImages.length > 0
                Repeater {
                    model: root.pendingImages
                    delegate: Rectangle {
                        id: pend
                        required property int index
                        required property string modelData
                        width: 46 * root.s
                        height: 46 * root.s
                        radius: 6 * root.s
                        color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.06)
                        clip: true
                        Image {
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            source: "file://" + pend.modelData
                            asynchronous: true
                        }
                        Rectangle {
                            anchors.top: parent.top
                            anchors.right: parent.right
                            width: 16 * root.s
                            height: 16 * root.s
                            radius: width / 2
                            color: Qt.rgba(0, 0, 0, 0.6)
                            MaterialIcon {
                                anchors.centerIn: parent
                                text: "close"
                                font.pixelSize: 11 * root.s
                                color: "white"
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.removeImage(pend.index)
                            }
                        }
                    }
                }
            }

            Item {
                width: parent.width
                height: Math.max(26 * root.s, inputScroll.height)

                Rectangle {
                    id: attachBtn
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    width: 26 * root.s
                    height: 26 * root.s
                    radius: width / 2
                    enabled: root.pendingImages.length < root.maxImages
                    opacity: enabled ? 1 : 0.4
                    color: attachArea.containsMouse
                        ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
                        : "transparent"
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    MaterialIcon {
                        anchors.centerIn: parent
                        text: "add_photo_alternate"
                        font.pixelSize: 15 * root.s
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    }
                    MouseArea {
                        id: attachArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (attachBtn.enabled) pickProc.running = true
                    }
                }

                ScrollView {
                    id: inputScroll
                    anchors.left: attachBtn.right
                    anchors.right: sendBtn.left
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 6 * root.s
                    anchors.rightMargin: 6 * root.s
                    height: Math.min(root.maxInputH, Math.max(root.minInputH, input.implicitHeight))
                    clip: true

                    TextArea {
                        id: input
                        background: null
                        padding: 0
                        wrapMode: TextArea.Wrap
                        placeholderText: I18n.tr("Message the needle")
                        placeholderTextColor: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                        selectionColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                        selectByMouse: true
                        font.family: Theme.fontPrimary
                        font.pixelSize: 12.5 * root.s
                        onTextChanged: {
                            root.paletteIdx = 0;
                            root.paletteDismissed = false;
                        }
                        Keys.onPressed: (e) => {
                            if (root.paletteOpen && e.key === Qt.Key_Down) {
                                root.paletteIdx = Math.min(root.paletteIdx + 1, root.slashMatches.length - 1);
                                e.accepted = true;
                            } else if (root.paletteOpen && e.key === Qt.Key_Up) {
                                root.paletteIdx = Math.max(root.paletteIdx - 1, 0);
                                e.accepted = true;
                            } else if (root.paletteOpen && (e.key === Qt.Key_Tab || e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !(e.modifiers & Qt.ShiftModifier)) {
                                root.acceptSlash();
                                e.accepted = true;
                            } else if (root.slashMode && e.key === Qt.Key_Escape) {
                                root.paletteDismissed = true;
                                e.accepted = true;
                            } else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !(e.modifiers & Qt.ShiftModifier)) {
                                root.submit();
                                e.accepted = true;
                            } else if (e.key === Qt.Key_Escape && Needle.busy) {
                                Needle.cancel();
                                e.accepted = true;
                            } else if (e.key === Qt.Key_V && (e.modifiers & Qt.ControlModifier)) {
                                pasteImgProc.running = true;
                            }
                        }
                    }
                }

                Rectangle {
                    id: sendBtn
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    width: 26 * root.s
                    height: 26 * root.s
                    radius: width / 2
                    readonly property bool ready: input.text.trim().length > 0 || root.pendingImages.length > 0
                    color: Needle.busy ? Qt.rgba(Theme.vermLit.r, Theme.vermLit.g, Theme.vermLit.b, 0.18)
                        : ready ? Theme.primary
                        : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.08)
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                    MaterialIcon {
                        anchors.centerIn: parent
                        font.pixelSize: 15 * root.s
                        text: Needle.busy ? "stop" : "arrow_upward"
                        color: Needle.busy ? Theme.vermLit
                            : sendBtn.ready ? Theme.inkOn(Theme.primary, Theme.onPrimary)
                            : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Needle.busy ? Needle.cancel() : root.submit()
                    }
                }
            }
        }
    }
}
