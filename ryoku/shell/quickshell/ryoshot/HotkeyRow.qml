import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "lib/keymap.js" as Keymap
import "Singletons"
import Ryoku.Ui.Singletons

// The launch-key rebind. ryoku-hub owns desktop.json, so the chosen chord is
// written there as a keybind rebind and the provider emits it; this row only
// reads the store to show the current chord.
Item {
    id: hk

    // The shipped chord desktop.keybindRebinds is keyed by.
    property string defaultChord: ""
    property string hotkey: "-"
    property bool listening: false

    signal rebound()
    signal closeRequested()

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    readonly property string desktopPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/desktop.json"

    FileView {
        id: store
        path: hk.desktopPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: hk.refresh()
        onLoadFailed: hk.hotkey = hk.defaultChord
    }

    function refresh() {
        var chosen = "";
        try {
            var o = JSON.parse(store.text() || "{}");
            var r = o && o.desktop && o.desktop.keybindRebinds;
            if (r && typeof r[hk.defaultChord] === "string")
                chosen = r[hk.defaultChord];
        } catch (e) {}
        hk.hotkey = chosen !== "" ? chosen : hk.defaultChord;
    }
    onDefaultChordChanged: hk.refresh()
    Component.onCompleted: hk.refresh()

    function applyBind(bind) {
        hk.hotkey = bind;
        hk.listening = false;
        Quickshell.execDetached(["ryoku-hub", "desktop", "set-rebind", hk.defaultChord, bind]);
        hk.rebound();
    }

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 10

        Text {
            text: hk.hotkey
            color: Theme.inkDim
            font.family: Theme.mono
            font.pixelSize: 13
            verticalAlignment: Text.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        Rectangle {
            id: recBtn
            Layout.preferredHeight: 28
            Layout.preferredWidth: recLabel.implicitWidth + 24
            radius: 6
            color: hk.listening ? Theme.accent : (recHover.hovered ? Theme.press : Theme.hover)
            border.color: hk.listening ? Theme.accent : Theme.hair
            border.width: 1

            Text {
                id: recLabel
                anchors.centerIn: parent
                text: hk.listening ? I18n.tr("Press a key…") : I18n.tr("Record")
                color: hk.listening ? Theme.accentInk : Theme.inkDim
                font.family: Theme.mono
                font.pixelSize: 13
            }

            HoverHandler { id: recHover }
            TapHandler {
                onTapped: {
                    hk.listening = !hk.listening;
                    if (hk.listening) keyCatcher.forceActiveFocus();
                }
            }
        }
    }

    Item {
        id: keyCatcher
        focus: hk.visible
        Keys.onPressed: (e) => {
            e.accepted = true;
            if (e.key === Qt.Key_Escape) {
                if (hk.listening) hk.listening = false;
                else hk.closeRequested();
                return;
            }
            if (!hk.listening) return;
            var bind = Keymap.bindString(e.key, e.modifiers, e.text);
            if (bind !== null) hk.applyBind(bind);
        }
    }
}
