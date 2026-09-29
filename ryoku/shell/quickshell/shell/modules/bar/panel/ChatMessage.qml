pragma ComponentBehavior: Bound

import QtQuick
import shell.services
import "../../../components"
import Ryoku.Ui.Singletons

// One turn's message. A user turn is a compact right-aligned bubble; the agent's
// turn is a left-aligned column: its live reasoning (ChatThinking), any produced
// images, the Markdown answer split into text and copyable code blocks, and a
// copy action once the turn settles. The block split mirrors iNiR's AiMessage.
Item {
    id: root

    property real s: 1
    property string role: "agent"
    property string body: ""
    property string thought: ""
    property bool open: false
    property bool live: false
    property bool cont: false
    property bool failed: false
    property string imagesJson: "[]"

    readonly property bool isUser: root.role === "user"
    readonly property var images: {
        try { return JSON.parse(root.imagesJson) || []; } catch (e) { return []; }
    }

    implicitHeight: colWrap.implicitHeight

    // Markdown collapses single newlines, so line-structured output renders as
    // one run-on paragraph. Turn each non-blank newline into a hard break so the
    // line structure survives; blank-line paragraph breaks stay.
    function hardBreaks(t) {
        return String(t).replace(/([^\n])\n(?!\n)/g, "$1  \n");
    }
    // Split an answer into text and fenced-code segments so code renders in a
    // wrapped, copyable box instead of overflowing.
    function msgBlocks(md) {
        if (!md) return [];
        var re = /```(\w+)?\n([\s\S]*?)```/g;
        var out = [];
        var last = 0, m;
        function pushText(t) { if (t && t.trim().length) out.push({ type: "text", content: t }); }
        while ((m = re.exec(md)) !== null) {
            if (m.index > last) pushText(md.slice(last, m.index));
            if (m[2] && m[2].trim().length)
                out.push({ type: "code", lang: m[1] || "", content: m[2].replace(/\n+$/, "") });
            last = re.lastIndex;
        }
        if (last < md.length) {
            var tail = md.slice(last);
            var cs = tail.indexOf("```");
            if (cs !== -1) {
                pushText(tail.slice(0, cs));
                var after = tail.slice(cs + 3);
                var lm = after.match(/^(\w+)?\n/);
                var lang = "", cstart = 0;
                if (lm) { lang = lm[1] || ""; cstart = lm[0].length; }
                var code = after.slice(cstart);
                if (code.trim().length) out.push({ type: "code", lang: lang, content: code.replace(/\n+$/, "") });
            } else {
                pushText(tail);
            }
        }
        if (out.length === 0) pushText(md);
        return out;
    }

    Column {
        id: colWrap
        width: parent.width
        spacing: 5 * root.s

        // role tag
        Text {
            // a continuation segment belongs to the reply above, so it carries no
            // second header and sits tight under whatever streamed before it
            visible: !root.cont
            text: root.isUser ? I18n.tr("YOU") : I18n.tr("NEEDLE")
            color: root.isUser
                ? Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                : Theme.primary
            font.family: Theme.mono
            font.pixelSize: 7.5 * root.s
            font.letterSpacing: 1.2
            font.weight: Font.DemiBold
            anchors.right: root.isUser ? parent.right : undefined
        }

        // ── user bubble ──
        Rectangle {
            visible: root.isUser
            anchors.right: parent.right
            width: Math.min(parent.width, Math.max(uText.implicitWidth + 24 * root.s, uImgs.implicitWidth + 16 * root.s))
            implicitHeight: uCol.implicitHeight + 16 * root.s
            radius: Theme.radiusWidget
            color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
            border.width: 1
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.28)

            Column {
                id: uCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8 * root.s
                spacing: 6 * root.s

                Column {
                    id: uImgs
                    width: parent.width
                    spacing: 6 * root.s
                    Repeater {
                        model: root.isUser ? root.images : []
                        delegate: ChatImageThumb { required property string modelData; s: root.s; path: modelData; maxW: 200 * root.s }
                    }
                }

                TextEdit {
                    id: uText
                    width: parent.width
                    visible: root.body.length > 0
                    text: root.body
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                    selectionColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                    selectedTextColor: color
                    font.family: Theme.fontPrimary
                    font.pixelSize: 12.5 * root.s
                }
            }
        }

        // ── agent content ──
        Column {
            id: agentCol
            visible: !root.isUser
            width: parent.width
            spacing: 6 * root.s

            ChatThinking {
                width: parent.width
                s: root.s
                thought: root.thought
                live: root.live && root.body.length === 0
            }

            Column {
                width: parent.width
                spacing: 6 * root.s
                Repeater {
                    model: root.isUser ? [] : root.images
                    delegate: ChatImageThumb { required property string modelData; s: root.s; path: modelData; maxW: 200 * root.s }
                }
            }

            Column {
                id: blockCol
                width: parent.width
                spacing: 6 * root.s
                visible: root.body.length > 0
                Repeater {
                    model: root.msgBlocks(root.body)
                    delegate: Item {
                        id: blk
                        required property var modelData
                        readonly property bool isCode: blk.modelData.type === "code"
                        width: blockCol.width
                        implicitHeight: blk.isCode ? code.implicitHeight : txt.implicitHeight

                        TextEdit {
                            id: txt
                            visible: !blk.isCode
                            width: blk.width
                            text: blk.isCode ? "" : root.hardBreaks(blk.modelData.content)
                            readOnly: true
                            selectByMouse: true
                            wrapMode: TextEdit.Wrap
                            textFormat: TextEdit.MarkdownText
                            color: root.failed ? Theme.vermLit : Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                            selectionColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
                            selectedTextColor: color
                            font.family: Theme.fontPrimary
                            font.pixelSize: 12.5 * root.s
                            onLinkActivated: (url) => Spawn.run(["xdg-open", url])
                        }
                        ChatCodeBlock {
                            id: code
                            visible: blk.isCode
                            width: blk.width
                            s: root.s
                            lang: blk.isCode ? (blk.modelData.lang || "") : ""
                            content: blk.isCode ? blk.modelData.content : ""
                        }
                    }
                }
            }

            // copy the whole answer, once the turn has settled
            Rectangle {
                visible: !root.open && root.body.length > 0
                height: 20 * root.s
                width: copyRow.implicitWidth + 12 * root.s
                radius: 5 * root.s
                color: copyArea.containsMouse ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.12) : "transparent"
                Row {
                    id: copyRow
                    anchors.centerIn: parent
                    spacing: 3 * root.s
                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "content_copy"
                        font.pixelSize: 11 * root.s
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("COPY")
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                        font.family: Theme.mono
                        font.pixelSize: 7.5 * root.s
                        font.letterSpacing: 0.8
                    }
                }
                MouseArea {
                    id: copyArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Needle.copyText(root.body)
                }
            }
        }
    }
}
