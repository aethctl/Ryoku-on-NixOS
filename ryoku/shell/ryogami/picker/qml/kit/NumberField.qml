import QtQuick
import Ryoku.Ui.Singletons

// A blank field means Auto and reads as null.
Item {
    id: numberField

    property var value: null
    property string unit: ""
    property real min: NaN
    property real max: NaN
    property string placeholder: I18n.tr("Auto")
    readonly property bool editing: input.activeFocus

    signal committed(var value)

    implicitHeight: input.implicitHeight + 12 * Theme.scale
    implicitWidth: 118 * Theme.scale

    // Reflect an external value change into the text unless the user is typing.
    onValueChanged: if (!input.activeFocus) input.text = numberField._fmt(numberField.value)
    Component.onCompleted: input.text = numberField._fmt(numberField.value)

    function _fmt(v) { return (v === null || v === undefined || isNaN(Number(v))) ? "" : String(v) }
    function _clamp(v) {
        if (!isNaN(numberField.min)) v = Math.max(numberField.min, v)
        if (!isNaN(numberField.max)) v = Math.min(numberField.max, v)
        return v
    }
    function _commit() {
        var t = input.text.trim()
        if (t.length === 0) { numberField.value = null; numberField.committed(null); return }
        var n = Number(t)
        if (isNaN(n)) { input.text = numberField._fmt(numberField.value); return }
        n = numberField._clamp(n)
        numberField.value = n
        input.text = String(n)
        numberField.committed(n)
    }

    Rectangle {
        anchors.fill: parent
        radius: Theme.radius
        color: Qt.rgba(0, 0, 0, 0.58)
        border.width: input.activeFocus ? 2 : 1
        border.color: input.activeFocus ? Theme.withAlpha(Theme.primary, 0.9)
                    : numberField.enabled ? Theme.withAlpha(Theme.surfaceText, 0.28)
                    : Theme.withAlpha(Theme.outline, 0.18)
    }

    TextInput {
        id: input
        anchors.left: parent.left
        anchors.leftMargin: 7 * Theme.scale
        anchors.right: unitLabel.left
        anchors.rightMargin: 4 * Theme.scale
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        enabled: numberField.enabled
        font.family: Theme.ui
        font.weight: Theme.uiWeight
        font.pixelSize: Theme.fontHead
        color: numberField.enabled ? Theme.surfaceText : Theme.withAlpha(Theme.surfaceText, 0.4)
        selectionColor: Theme.withAlpha(Theme.primary, 0.45)
        selectedTextColor: Theme.surfaceText
        selectByMouse: true
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        renderType: Text.NativeRendering
        onEditingFinished: numberField._commit()
        Keys.onReturnPressed: numberField._commit()
        Keys.onEnterPressed: numberField._commit()

        Text {
            anchors.fill: parent
            visible: input.text.length === 0
            verticalAlignment: Text.AlignVCenter
            text: numberField.placeholder
            font: input.font
            color: Theme.withAlpha(Theme.surfaceText, 0.48)
            renderType: Text.NativeRendering
        }
    }

    Text {
        id: unitLabel
        visible: numberField.unit.length > 0
        anchors.right: parent.right
        anchors.rightMargin: 7 * Theme.scale
        anchors.verticalCenter: parent.verticalCenter
        text: numberField.unit
        font.family: Theme.ui
        font.weight: Theme.uiWeight
        font.pixelSize: Theme.fontBase
        color: Theme.withAlpha(Theme.surfaceText, 0.56)
        renderType: Text.NativeRendering
    }
}
