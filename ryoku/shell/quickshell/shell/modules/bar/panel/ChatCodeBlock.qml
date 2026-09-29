import QtQuick
import shell.services
import "../../../components"
import Ryoku.Ui.Singletons

// A fenced code block inside an agent answer: a mono, wrapped, copyable body
// under a language label and a copy button. Pattern taken from iNiR's
// aiChat/MessageCodeBlock.qml (end-4 illogical-impulse, GPL-3.0), restyled to
// Ryoku's paper-and-ink tokens.
Rectangle {
    id: root

    property real s: 1
    property string lang: ""
    property string content: ""

    property bool copied: false

    implicitHeight: inner.implicitHeight
    radius: 6 * root.s
    color: Qt.rgba(0, 0, 0, 0.30)
    border.width: 1
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.35)

    Column {
        id: inner
        width: parent.width

        Item {
            width: parent.width
            height: 24 * root.s

            Text {
                anchors.left: parent.left
                anchors.leftMargin: 10 * root.s
                anchors.verticalCenter: parent.verticalCenter
                text: root.lang.length > 0 ? root.lang : I18n.tr("code")
                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                font.family: Theme.mono
                font.pixelSize: 8 * root.s
                font.letterSpacing: 0.8
            }

            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 5 * root.s
                anchors.verticalCenter: parent.verticalCenter
                height: 18 * root.s
                width: copyRow.implicitWidth + 10 * root.s
                radius: 5 * root.s
                color: cpArea.containsMouse ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.12) : "transparent"

                Row {
                    id: copyRow
                    anchors.centerIn: parent
                    spacing: 3 * root.s
                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.copied ? "check" : "content_copy"
                        font.pixelSize: 11 * root.s
                        color: root.copied ? Theme.primary : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: root.copied ? I18n.tr("COPIED") : I18n.tr("COPY")
                        color: root.copied ? Theme.primary : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                        font.family: Theme.mono
                        font.pixelSize: 7.5 * root.s
                        font.letterSpacing: 0.8
                    }
                }
                MouseArea {
                    id: cpArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        Needle.copyText(root.content);
                        root.copied = true;
                        copiedTimer.restart();
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)
        }

        TextEdit {
            id: codeText
            width: parent.width
            leftPadding: 10 * root.s
            rightPadding: 10 * root.s
            topPadding: 6 * root.s
            bottomPadding: 8 * root.s
            text: root.content
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            textFormat: TextEdit.PlainText
            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
            selectionColor: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.35)
            selectedTextColor: color
            font.family: Theme.mono
            font.pixelSize: 11 * root.s
            Loader {
                source: "../../../components/CodeHighlight.qml"
                onLoaded: {
                    item.textEdit = codeText;
                    item.lang = root.lang.length > 0 ? root.lang : "plaintext";
                }
            }
        }
    }

    Timer { id: copiedTimer; interval: 1400; onTriggered: root.copied = false }
}
