pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import shell.services
import "../../../components"
import Ryoku.Ui.Singletons

// The "what's answering" picker: the agents from `agent --json` up top (a live
// backend switch), then that agent's models. A backend like omp can advertise
// hundreds of models, so the model list is a search field over a virtualised
// ListView with the current model pinned first and the provider prefix shown as
// a dim tag.
Item {
    id: root

    property real s: 1
    signal closed()

    anchors.fill: parent

    MouseArea {
        anchors.fill: parent
        onClicked: root.closed()
    }

    Rectangle {
        id: panel
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.topMargin: 4 * root.s
        anchors.rightMargin: 14 * root.s
        width: 260 * root.s
        height: Math.min(420 * root.s, parent.height - 12 * root.s)
        radius: Theme.radiusWidget
        color: Qt.rgba(Theme.effectiveSurface.r, Theme.effectiveSurface.g, Theme.effectiveSurface.b, 0.99)
        border.width: Theme.borderWidth
        border.color: Theme.outline
        SumiEdge { radius: Theme.radiusWidget }

        readonly property string q: search.text.trim().toLowerCase()
        readonly property var filteredModels: {
            var all = Needle.models || [];
            var cur = Needle.currentModel;
            var query = panel.q;
            var out = [];
            var pinned = null;
            for (var i = 0; i < all.length; i++) {
                var m = all[i];
                var name = String(m.name || m.id).toLowerCase();
                var id = String(m.id).toLowerCase();
                if (query.length > 0 && name.indexOf(query) < 0 && id.indexOf(query) < 0)
                    continue;
                if (m.id === cur) pinned = m;
                else out.push(m);
            }
            if (pinned) out.unshift(pinned);
            return out;
        }
        function provider(id) {
            var t = String(id);
            var c = t.indexOf("/");
            return c >= 0 ? t.slice(0, c) : "";
        }

        // Click anywhere on the panel must not fall through to the scrim.
        MouseArea { anchors.fill: parent }

        Column {
            anchors.fill: parent
            anchors.margins: 6 * root.s
            spacing: 3 * root.s

            // AGENT
            Text {
                leftPadding: 6 * root.s
                text: I18n.tr("AGENT")
                color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                font.family: Theme.mono
                font.pixelSize: 8 * root.s
                font.letterSpacing: 1.0
            }
            Repeater {
                model: Needle.backends
                delegate: Rectangle {
                    id: arow
                    required property var modelData
                    width: parent.width
                    height: 28 * root.s
                    radius: 6 * root.s
                    readonly property bool active: arow.modelData.active === true
                    readonly property bool avail: arow.modelData.available === true
                    color: aArea.containsMouse && arow.avail
                        ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
                        : arow.active ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                        : "transparent"
                    MaterialIcon {
                        anchors.left: parent.left
                        anchors.leftMargin: 6 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: "check"
                        font.pixelSize: 12 * root.s
                        visible: arow.active
                        color: Theme.primary
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.right: availTag.left
                        anchors.leftMargin: 24 * root.s
                        anchors.rightMargin: 6 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: arow.modelData.name || arow.modelData.id
                        elide: Text.ElideRight
                        color: arow.active ? Theme.primary
                            : arow.avail ? Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                            : Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                        font.family: Theme.fontPrimary
                        font.pixelSize: 10.5 * root.s
                    }
                    Text {
                        id: availTag
                        anchors.right: parent.right
                        anchors.rightMargin: 8 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !arow.avail
                        text: I18n.tr("needs adapter")
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                        font.family: Theme.mono
                        font.pixelSize: 8 * root.s
                    }
                    MouseArea {
                        id: aArea
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: arow.avail
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Needle.setBackend(arow.modelData.id); root.closed(); }
                    }
                }
            }

            Rectangle {
                x: 4 * root.s
                width: parent.width - 8 * root.s
                height: Theme.borderWidth
                color: Theme.outline
                visible: Needle.models.length > 0
            }

            // MODEL search
            Rectangle {
                width: parent.width
                height: 28 * root.s
                radius: 6 * root.s
                visible: Needle.models.length > 0
                color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.06)
                border.width: 1
                border.color: search.activeFocus ? Theme.primary : "transparent"
                Row {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 7 * root.s
                    anchors.rightMargin: 7 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 5 * root.s
                    MaterialIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "search"
                        font.pixelSize: 13 * root.s
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                    }
                    TextField {
                        id: search
                        width: parent.width - 20 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        background: null
                        padding: 0
                        placeholderText: I18n.tr("Filter models")
                        placeholderTextColor: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                        font.family: Theme.fontPrimary
                        font.pixelSize: 11 * root.s
                        selectByMouse: true
                    }
                }
            }

            ListView {
                id: mlist
                width: parent.width
                height: parent.height - y
                visible: Needle.models.length > 0
                clip: true
                model: panel.filteredModels
                boundsBehavior: Flickable.StopAtBounds
                cacheBuffer: 800
                ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: Rectangle {
                    id: mrow
                    required property var modelData
                    width: mlist.width
                    height: 34 * root.s
                    radius: 6 * root.s
                    readonly property bool current: Needle.currentModel === mrow.modelData.id
                    color: mArea.containsMouse
                        ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
                        : mrow.current ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                        : "transparent"
                    MaterialIcon {
                        id: mcheck
                        anchors.left: parent.left
                        anchors.leftMargin: 6 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: "check"
                        font.pixelSize: 12 * root.s
                        visible: mrow.current
                        color: Theme.primary
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.right: provTag.left
                        anchors.leftMargin: 24 * root.s
                        anchors.rightMargin: 6 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: mrow.modelData.name || mrow.modelData.id
                        elide: Text.ElideRight
                        color: mrow.current ? Theme.primary : Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                        font.family: Theme.fontPrimary
                        font.pixelSize: 10.5 * root.s
                    }
                    Text {
                        id: provTag
                        anchors.right: parent.right
                        anchors.rightMargin: 8 * root.s
                        anchors.verticalCenter: parent.verticalCenter
                        text: panel.provider(mrow.modelData.id)
                        visible: text.length > 0
                        color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
                        font.family: Theme.mono
                        font.pixelSize: 8 * root.s
                        opacity: 0.8
                    }
                    MouseArea {
                        id: mArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: { Needle.setModel(mrow.modelData.id); root.closed(); }
                    }
                }
            }
        }
    }
}
