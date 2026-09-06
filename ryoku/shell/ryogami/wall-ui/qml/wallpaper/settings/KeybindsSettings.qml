import QtQuick
import "../.."

// Slim keybind cheat-sheet for the settings panel's persistent left column:
// stacked sections, each a compact list of mono key chips beside a short label.
Column {
    id: root
    property var colors

    readonly property color _ink:    colors ? colors.surfaceText : "#e0e2e8"
    readonly property color _inkDim: colors ? colors.surfaceVariantText : "#c2c7cf"
    readonly property color _line:   colors ? colors.outline : Qt.rgba(1, 1, 1, 0.22)

    width: parent ? parent.width : 0
    spacing: 16 * Config.uiScale

    Repeater {
        model: [
            {
                title: "NAVIGATION",
                binds: [
                    { key: "← →",  action: "Navigate items" },
                    { key: "↑ ↓",  action: "Navigate rows" },
                    { key: "Enter", action: "Apply wallpaper" },
                    { key: "Esc",   action: "Close panel" },
                    { key: "RMB",   action: "Flip card" },
                    { key: "Scroll", action: "Browse" }
                ]
            },
            {
                title: "FILTERS",
                binds: [
                    { key: "⇧ ← →", action: "Colour filters" },
                    { key: "⇧ ↑",   action: "Toggle bar" },
                    { key: "Esc",    action: "Close" }
                ]
            }
        ]

        delegate: Column {
            width: root.width
            spacing: 7 * Config.uiScale

            Text {
                text: "//" + modelData.title + "_"
                font.family: Style.fontFamilyMono; font.pixelSize: 10 * Config.uiScale
                font.letterSpacing: 1.2
                color: Qt.rgba(root._inkDim.r, root._inkDim.g, root._inkDim.b, 0.7)
            }

            Repeater {
                model: modelData.binds
                delegate: Row {
                    width: parent.width
                    spacing: 8 * Config.uiScale

                    Rectangle {
                        id: chip
                        width: Math.max(34 * Config.uiScale, keyText.implicitWidth + 12 * Config.uiScale)
                        height: keyText.implicitHeight + 6 * Config.uiScale
                        radius: Style.radiusSmall
                        color: root.colors ? Qt.rgba(root.colors.surfaceContainer.r, root.colors.surfaceContainer.g, root.colors.surfaceContainer.b, 0.9) : Qt.rgba(0.15, 0.15, 0.2, 0.9)
                        border.width: 1
                        border.color: Qt.rgba(root._line.r, root._line.g, root._line.b, 0.5)
                        Text {
                            id: keyText
                            anchors.centerIn: parent
                            text: modelData.key
                            font.family: Style.fontFamilyMono; font.pixelSize: 10 * Config.uiScale
                            color: root._ink
                        }
                    }

                    Text {
                        anchors.verticalCenter: chip.verticalCenter
                        width: root.width - chip.width - 8 * Config.uiScale
                        text: modelData.action
                        wrapMode: Text.WordWrap
                        elide: Text.ElideRight
                        font.family: Style.fontFamily; font.pixelSize: 10 * Config.uiScale
                        color: root._inkDim
                    }
                }
            }
        }
    }
}
