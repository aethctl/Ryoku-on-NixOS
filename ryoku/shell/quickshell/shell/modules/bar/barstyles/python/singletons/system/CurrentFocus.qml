pragma Singleton
import QtQuick
import Quickshell
import Ryoku.Ui.Singletons
import "../../"

// Ryoku seam: serpantinum ran a compositor-probing focus daemon writing a
// state file. The window-manager seam already streams the focused window
// (identity from the daemon, activation from the toplevel handle), so the
// widget reads Wm.focusedWindow directly and works on either compositor.
Item {
    id: root

    readonly property string appClass: {
        const w = Wm.focusedWindow;
        return w && w.appId ? w.appId : "";
    }
    readonly property string appTitle: {
        const w = Wm.focusedWindow;
        return w && w.title ? w.title : "";
    }
    readonly property string displayText: appTitle !== "" ? appTitle : appClass
    readonly property bool isFocused: displayText !== ""
}
