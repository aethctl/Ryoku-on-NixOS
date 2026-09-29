import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: root

    property string current: ""
    // Span is a paper-engine placement; a sheet can grey it out where unsupported.
    property bool spanEnabled: true

    signal picked(string mode)

    implicitWidth: chips.implicitWidth
    implicitHeight: chips.implicitHeight

    ChoiceButtons {
        id: chips
        width: root.width > 0 ? root.width : implicitWidth
        value: root.current
        options: [
            { value: "fill", label: I18n.tr("Fill") },
            { value: "fit", label: I18n.tr("Fit") },
            { value: "stretch", label: I18n.tr("Stretch") },
            { value: "center", label: I18n.tr("Centre") },
            { value: "tile", label: I18n.tr("Tile") },
            { value: "span", label: I18n.tr("Span"), enabled: root.spanEnabled }
        ]
        onSelected: (v) => root.picked(v)
    }
}
