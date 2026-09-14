pragma Singleton

import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: root

    visible: false

    // Thin view of the active keyboard layout, sourced from the window-manager facade.
    readonly property string variant: Wm.keyboardLayout
}
