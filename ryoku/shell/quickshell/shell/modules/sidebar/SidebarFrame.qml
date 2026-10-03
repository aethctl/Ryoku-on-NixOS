pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Ui.Singletons

Rectangle {
    property real s: 1
    radius: Tokens.radius * s * 3
    color: Tokens.paper
    border.width: Tokens.border
    border.color: Tokens.lineStrong
    antialiasing: true
}
