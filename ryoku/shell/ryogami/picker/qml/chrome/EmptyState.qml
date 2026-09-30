import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: root

    required property PickerState state

    readonly property bool filtered: {
        var v = root.state.view
        return !!v && (v.typeFilter !== "" || v.hueFilter !== -1 || v.favouritesOnly
            || v.query !== "" || v.tags.length > 0 || v.orientation !== ""
            || (v.folder !== "" && v.folder !== "*"))
    }
    readonly property string message: {
        if (root.filtered)
            return I18n.tr("Nothing matches these filters.")
        switch (root.state.collection) {
        case "rices": return I18n.tr("No rices yet. Capture one from Ryoku Hub to see it here.")
        case "workshop": return I18n.tr("No Wallpaper Engine scenes yet. Find some with Download, Steam Workshop.")
        case "themes": return I18n.tr("No themes installed.")
        }
        return I18n.tr("No wallpapers yet. Add some to your wallpaper folder or use Download.")
    }

    visible: !!root.state.view && root.state.view.count === 0

    // The picker has no backdrop of its own, so the message carries one to read on any wallpaper.
    Rectangle {
        anchors.centerIn: parent
        width: label.width + 44 * Theme.scale
        height: label.implicitHeight + 26 * Theme.scale
        radius: Theme.radius
        color: Theme.withAlpha(Theme.surfaceContainer, 0.92)
        border.width: 1
        border.color: Theme.withAlpha(Theme.outline, 0.4)

        Text {
            id: label
            anchors.centerIn: parent
            width: Math.min(implicitWidth, Math.min(root.width - 124 * Theme.scale, 596 * Theme.scale))
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.message
            font.family: Theme.ui
            font.weight: Theme.uiWeight
            font.pixelSize: Theme.fs(16)
            color: Theme.surfaceText
            renderType: Text.NativeRendering
        }
    }
}
