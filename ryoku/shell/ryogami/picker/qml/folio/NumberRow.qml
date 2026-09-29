import QtQuick
import Ryoku.Ui.Singletons

Item {
    id: row

    property var control: ({})
    property var state
    property var options
    property real reveal: 1
    property bool bound: true
    property string keyOverride: ""
    property var boundValue: undefined
    signal edited(var value)

    readonly property string rk: row.keyOverride !== "" ? row.keyOverride : (row.control.key ? row.control.key : "")
    readonly property var _spec: row.bound ? sv.spec : ({})
    readonly property var _val: row.bound ? sv.value : row.boundValue
    readonly property bool atDefault: row.bound ? sv.isDefault : true

    readonly property real _min: (row._spec && row._spec.min !== undefined && row._spec.min !== null) ? Number(row._spec.min) : NaN
    readonly property real _max: (row._spec && row._spec.max !== undefined && row._spec.max !== null) ? Number(row._spec.max) : NaN

    implicitHeight: col.implicitHeight
    function resetValue() { if (row.bound) sv.reset() }
    function _apply(v) { if (row.bound) sv.set(v); else row.edited(v) }

    function _rangeHint() {
        var hasMin = !isNaN(row._min), hasMax = !isNaN(row._max);
        if (hasMin && hasMax) return row._min + "\u2013" + row._max;
        if (hasMin) return "\u2265 " + row._min;
        if (hasMax) return "\u2264 " + row._max;
        return "";
    }

    SettingValue { id: sv; key: row.bound ? row.rk : "" }

    Column {
        id: col
        width: row.width
        spacing: 3 * Theme.scale

        Item {
            width: parent.width
            height: Math.max(title.implicitHeight, field.height)

            Text {
                id: title
                anchors.left: parent.left
                anchors.right: rightGroup.left
                anchors.rightMargin: 10 * Theme.scale
                anchors.verticalCenter: parent.verticalCenter
                text: row.control.label ? row.control.label : ""
                font.family: Theme.ui
                font.weight: Theme.uiWeight
                font.pixelSize: Theme.fontField
                color: Theme.withAlpha(Theme.surfaceText, row.enabled ? row.reveal : 0.4 * row.reveal)
                elide: Text.ElideRight
                wrapMode: Text.WordWrap
            }

            Row {
                id: rightGroup
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8 * Theme.scale

                ResetChip {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: row.bound && !row.atDefault && row.enabled
                    onTriggered: row.resetValue()
                }
                NumberField {
                    id: field
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: row.enabled
                    unit: row.control.unit ? row.control.unit : ""
                    min: row._min
                    max: row._max
                    placeholder: row.control.placeholder ? row.control.placeholder : I18n.tr("Auto")
                    value: (row._val === undefined || row._val === null || row._val === "") ? null : Number(row._val)
                    onCommitted: (v) => row._apply(v)
                }
            }
        }

        Text {
            width: parent.width
            visible: text.length > 0
            text: {
                var h = row.control.help ? row.control.help : "";
                var r = row._rangeHint();
                if (h.length > 0 && r.length > 0) return h + "  \u00b7  " + r;
                return h.length > 0 ? h : r;
            }
            font.family: Theme.ui
            font.weight: Theme.uiWeight
            font.pixelSize: Theme.fontBase
            color: Theme.withAlpha(Theme.surfaceText, 0.56 * row.reveal)
            lineHeight: 1.38
            wrapMode: Text.WordWrap
            renderType: Text.NativeRendering
        }
    }
}
