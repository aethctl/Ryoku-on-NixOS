pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import inir.services
import inir.modules.common.widgets
import inir.modules.iris.style
import inir.modules.iris.bar.island

IrisWidgetFace {
    id: root

    readonly property var resources: Array.from(root.widget._resourceModel ?? []).slice(0, root.large ? 6 : 4)

    function level(key: string): real {
        return Math.max(0, Math.min(1, Number(root.widget._getValue(key)) || 0))
    }
    function tint(key: string): color {
        if (root.level(key) >= 0.85)
            return IrisStyle.danger
        return key === "mem" ? IrisStyle.identity.green
            : key === "gpu" ? IrisStyle.identity.purple
            : key === "temp" || key === "gpuTemp" ? IrisStyle.identity.orange
            : key === "disk" ? IrisStyle.identity.teal : root.accent
    }
    function history(key: string): var {
        const values = key === "cpu" ? ResourceUsage.cpuUsageHistory
            : key === "mem" ? ResourceUsage.memoryUsageHistory
            : key === "gpu" ? ResourceUsage.gpuUsageHistory
            : key === "gpuTemp" ? ResourceUsage.gpuTempHistory : []
        return Array.from(values ?? []).slice(-40)
    }
    function name(entry: var): string {
        return entry.key === "temp" || entry.key === "gpuTemp" ? entry.label + " " + Translation.tr("heat") : entry.label
    }

    component Gauge: ColumnLayout {
        id: gauge
        required property var entry
        property real diameter: root.dp(48)
        spacing: root.dp(4)
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: gauge.diameter
            Layout.preferredHeight: gauge.diameter
            ProgressRing {
                anchors.fill: parent
                progress: root.level(gauge.entry.key)
                tint: root.tint(gauge.entry.key)
                stroke: Math.max(3, gauge.diameter * 0.1)
                Behavior on progress { NumberAnimation { duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.moveCurve } }
            }
            MaterialSymbol {
                anchors.centerIn: parent
                text: gauge.entry.icon
                fill: 1
                iconSize: gauge.diameter * 0.36
                color: root.tint(gauge.entry.key)
            }
        }
        FaceText {
            face: root
            Layout.alignment: Qt.AlignHCenter
            text: root.widget._getDisplayText(gauge.entry.key)
            size: 13
            weight: Font.DemiBold
            font.family: root.fontNumbers
            font.features: ({ "tnum": 1 })
        }
        FaceText {
            face: root
            visible: root.widget.showLabels && !root.small
            Layout.alignment: Qt.AlignHCenter
            text: root.name(gauge.entry)
            color: root.inkTertiary
            size: 11
        }
    }

    FaceText {
        face: root
        visible: root.resources.length === 0
        anchors.centerIn: parent
        text: Translation.tr("Choose what to watch")
        color: root.inkTertiary
        size: 12.5
    }

    GridLayout {
        visible: !root.large && root.resources.length > 0
        anchors.centerIn: parent
        columns: root.small ? 2 : 4
        columnSpacing: root.small ? root.dp(18) : root.dp(24)
        rowSpacing: root.dp(8)
        Repeater {
            model: root.large ? [] : root.resources
            Gauge {
                required property var modelData
                entry: modelData
                diameter: root.small ? root.dp(42) : root.dp(52)
            }
        }
    }

    ColumnLayout {
        visible: root.large
        anchors.fill: parent
        spacing: root.dp(6)
        Repeater {
            model: root.large ? root.resources : []
            ColumnLayout {
                id: metric
                required property var modelData
                required property int index
                readonly property var points: root.history(metric.modelData.key)
                readonly property color tint: root.tint(metric.modelData.key)
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: root.dp(4)
                RowLayout {
                    Layout.fillWidth: true
                    spacing: root.dp(6)
                    MaterialSymbol {
                        text: metric.modelData.icon
                        fill: 1
                        iconSize: root.px(16)
                        color: metric.tint
                    }
                    FaceText {
                        face: root
                        Layout.fillWidth: true
                        text: root.name(metric.modelData)
                        size: 13
                        weight: Font.DemiBold
                    }
                    FaceText {
                        face: root
                        text: root.widget._getDisplayText(metric.modelData.key)
                        size: 13
                        weight: Font.DemiBold
                        color: metric.tint
                        font.family: root.fontNumbers
                        font.features: ({ "tnum": 1 })
                    }
                }
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: root.dp(6)
                    Rectangle {
                        visible: metric.points.length < 2
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        height: root.dp(5)
                        radius: height / 2
                        color: IrisStyle.fill
                        Rectangle {
                            width: Math.max(parent.height, parent.width * root.level(metric.modelData.key))
                            height: parent.height
                            radius: height / 2
                            color: metric.tint
                        }
                    }
                    Shape {
                        id: spark
                        visible: metric.points.length >= 2
                        anchors.fill: parent
                        preferredRendererType: Shape.CurveRenderer
                        readonly property var line: metric.points.map((value, i) => Qt.point(
                            spark.width * i / Math.max(1, metric.points.length - 1),
                            spark.height - Math.max(0, Math.min(1, Number(value) || 0)) * (spark.height - 2) - 1))
                        ShapePath {
                            strokeColor: "transparent"
                            fillColor: IrisStyle.tintFill(metric.tint)
                            PathPolyline { path: [Qt.point(0, spark.height)].concat(spark.line, [Qt.point(spark.width, spark.height)]) }
                        }
                        ShapePath {
                            strokeColor: metric.tint
                            strokeWidth: Math.max(1.5, root.dp(2))
                            joinStyle: ShapePath.RoundJoin
                            capStyle: ShapePath.RoundCap
                            fillColor: "transparent"
                            PathPolyline { path: spark.line }
                        }
                    }
                }
            }
        }
    }
}
