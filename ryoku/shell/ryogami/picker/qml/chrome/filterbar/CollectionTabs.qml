import QtQuick
import Ryoku.Ui.Singletons

// Switching is instant: it only reconfigures the one shared view.
Grid {
    id: tabs

    required property PickerState state
    property string barStyle: "straight"
    property real railWidth: 0
    readonly property real naturalWidth: {
        var w = 0
        for (var i = 0; i < tabs.children.length; ++i)
            w = Math.max(w, tabs.children[i].implicitWidth || 0)
        return w
    }

    columns: tabs.railWidth > 0 ? 1 : tabs._tabs.length
    spacing: (tabs.railWidth > 0 ? 3 : 4) * Theme.scale

    readonly property var _tabs: [
        { value: "wallpapers", label: I18n.tr("Wallpapers") },
        { value: "themes", label: I18n.tr("Themes") },
        { value: "rices", label: I18n.tr("Rices") },
        { value: "workshop", label: I18n.tr("Workshop") }
    ]

    Repeater {
        model: tabs._tabs
        delegate: BarButton {
            required property var modelData
            barStyle: tabs.barStyle
            railWidth: tabs.railWidth
            label: modelData.label
            active: tabs.state && tabs.state.collection === modelData.value
            onTriggered: if (tabs.state) tabs.state.setCollection(modelData.value)
        }
    }
}
