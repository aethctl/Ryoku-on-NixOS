pragma Singleton

import QtQuick
import Quickshell
import shell.services as Ryoku

// Night-light bridge. Ryoku's daemon owns the colour temperature state; the
// frame reads and toggles it through the same two-member surface the
// reference used, so the control tile and the quick panel stay untouched.
Singleton {
    id: root

    readonly property bool active: Ryoku.Nightlight.on
    function toggle(): void { Ryoku.Nightlight.toggle(); }
}
