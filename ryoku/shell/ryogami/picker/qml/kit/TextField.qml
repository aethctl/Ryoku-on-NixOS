import QtQuick

// variant: "workbench" (default), "field" or "ghost"; committed fires on Enter or focus-out.
// A focus scope, so forceActiveFocus() on the field lands in the text input.
FocusScope {
    id: field

    property alias text: input.text
    property string placeholder: ""
    property string variant: "workbench"
    property string glyph: ""
    readonly property bool editing: input.activeFocus

    signal edited(string text)
    signal committed(string text)

    implicitHeight: input.implicitHeight + 12 * Theme.scale
    implicitWidth: 160 * Theme.scale

    readonly property bool _ghost: field.variant === "ghost"
    readonly property color _bg: field.variant === "field"
        ? Theme.withAlpha(Theme.surfaceContainer, 0.88)
        : field._ghost ? "transparent"
        : Qt.rgba(0, 0, 0, 0.58)
    readonly property color _border: field.variant === "field"
        ? Theme.withAlpha(Theme.outline, 0.48)
        : field._ghost ? "transparent"
        : Theme.withAlpha(Theme.surfaceText, 0.28)
    readonly property color _placeholder: field.variant === "field"
        ? Theme.withAlpha(Theme.surfaceText, 0.35)
        : field._ghost ? Theme.withAlpha(Theme.surfaceText, 0.42)
        : Theme.withAlpha(Theme.surfaceText, 0.48)
    readonly property color _selection: field.variant === "field"
        ? Theme.withAlpha(Theme.primary, 0.40)
        : field._ghost ? Theme.withAlpha(Theme.primary, 0.35)
        : Theme.withAlpha(Theme.primary, 0.45)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: field._bg
        border.width: input.activeFocus ? 2 : 1
        border.color: input.activeFocus ? Theme.withAlpha(Theme.primary, 0.9)
                    : field.enabled ? field._border
                    : Theme.withAlpha(Theme.outline, 0.18)
    }

    Text {
        visible: field.glyph.length > 0
        id: leadGlyph
        anchors.left: parent.left
        anchors.leftMargin: 7 * Theme.scale
        anchors.verticalCenter: parent.verticalCenter
        text: field.glyph
        font.family: Theme.icon
        font.pixelSize: Theme.fontLabel
        color: Theme.tertiary
        renderType: Text.NativeRendering
    }

    TextInput {
        id: input
        focus: true
        anchors.fill: parent
        anchors.leftMargin: (field.glyph.length > 0 ? 26 : 7) * Theme.scale
        anchors.rightMargin: 7 * Theme.scale
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        enabled: field.enabled
        font.family: Theme.ui
        font.weight: Theme.uiWeight
        font.pixelSize: Theme.fontLabel
        color: field.enabled ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceText, 0.4)
        selectionColor: field._selection
        selectedTextColor: Theme.surfaceText
        selectByMouse: true
        renderType: Text.NativeRendering
        onTextEdited: field.edited(text)
        onEditingFinished: field.committed(text)
        Keys.onReturnPressed: field.committed(text)
        Keys.onEnterPressed: field.committed(text)

        Text {
            anchors.fill: parent
            visible: input.text.length === 0
            verticalAlignment: Text.AlignVCenter
            text: field.placeholder
            font: input.font
            color: field._placeholder
            renderType: Text.NativeRendering
            elide: Text.ElideRight
        }
    }
}
