import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import "../../"
import "../../reusables"

Item {
    id: presetsTabRoot
    required property var rootObj
    required property int tabIndex
    property int subTabIndex: 1

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex && rootObj.currentSubTab === subTabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }
}
