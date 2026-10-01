import QtQuick
import QtQuick.Layouts
import "../../"
import "../"

Item {
    id: root
    implicitWidth: 64
    implicitHeight: 64

    property color accentColor: "#89b4fa"
    property bool running: true
    property real morphSpeed: 1.0

    opacity: running ? 1.0 : 0.0
    Behavior on opacity { NumberAnimation { duration: 350; easing.type: Easing.InOutQuad } }

    property var shapeConfigs: [
        {p: 7, d: 0.08, ax: 1.0, ay: 1.0},
        {p: 9, d: 0.12, ax: 1.0, ay: 1.0},
        {p: 5, d: 0.15, ax: 1.0, ay: 1.0},
        {p: 2, d: 0.10, ax: 1.3, ay: 0.7},
        {p: 8, d: 0.18, ax: 1.0, ay: 1.0},
        {p: 4, d: 0.15, ax: 1.0, ay: 1.0},
        {p: 0, d: 0.00, ax: 1.2, ay: 0.8}
    ]

    property var precomputedShapes: []
    property int currentIndex: 0
    property int nextIndex: 1
    property real morphProgress: 0.0
    property real kickRotation: 0.0
    property real baseRotation: 0.0

    NumberAnimation on baseRotation {
        from: 0
        to: 360
        duration: 9100 / root.morphSpeed
        loops: Animation.Infinite
        running: root.running
    }

    Behavior on morphProgress {
        id: morphBehavior
        SpringAnimation {
            spring: 6.0
            damping: 0.5
            mass: 1.0
            epsilon: 0.001
        }
    }

    Behavior on kickRotation {
        SpringAnimation {
            spring: 6.0
            damping: 0.5
            mass: 1.0
            epsilon: 0.001
        }
    }

    Component.onCompleted: {
        let shapes = [];
        for (let s = 0; s < root.shapeConfigs.length; s++) {
            let config = root.shapeConfigs[s];
            let pts = [];
            for (let i = 0; i < 32; i++) {
                let theta = (i / 32) * Math.PI * 2;
                let r = 1.0 + config.d * Math.cos(config.p * theta);
                pts.push({ x: r * Math.cos(theta) * config.ax, y: r * Math.sin(theta) * config.ay });
            }
            shapes.push(pts);
        }
        root.precomputedShapes = shapes;
        root.morphProgress = 1.0;
        root.kickRotation = 45.0;
    }

    Timer {
        id: cycleTimer
        interval: 650 / root.morphSpeed
        running: root.running
        repeat: true
        onTriggered: {
            morphBehavior.enabled = false;
            root.morphProgress = 0.0;
            root.currentIndex = root.nextIndex;
            root.nextIndex = (root.nextIndex + 1) % 7;

            morphBehavior.enabled = true;
            root.morphProgress = 1.0;
            root.kickRotation += 45.0;
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        rotation: root.baseRotation + root.kickRotation
        antialiasing: true

        Connections {
            target: root
            function onMorphProgressChanged() { canvas.requestPaint(); }
        }

        onPaint: {
            if (!root.precomputedShapes || root.precomputedShapes.length === 0) return;

            var ctx = getContext("2d");
            ctx.reset();

            var cx = width / 2;
            var cy = height / 2;
            var radius = Math.min(cx, cy) * 0.72;

            var pts1 = root.precomputedShapes[root.currentIndex];
            var pts2 = root.precomputedShapes[root.nextIndex];
            var currentPts = [];

            for (var i = 0; i < 32; i++) {
                var nx = pts1[i].x + (pts2[i].x - pts1[i].x) * root.morphProgress;
                var ny = pts1[i].y + (pts2[i].y - pts1[i].y) * root.morphProgress;
                currentPts.push({ x: cx + nx * radius, y: cy + ny * radius });
            }

            ctx.beginPath();

            var xc1 = (currentPts[0].x + currentPts[31].x) / 2;
            var yc1 = (currentPts[0].y + currentPts[31].y) / 2;
            ctx.moveTo(xc1, yc1);

            for (var j = 0; j < 31; j++) {
                var xc = (currentPts[j].x + currentPts[j+1].x) / 2;
                var yc = (currentPts[j].y + currentPts[j+1].y) / 2;
                ctx.quadraticCurveTo(currentPts[j].x, currentPts[j].y, xc, yc);
            }

            ctx.quadraticCurveTo(currentPts[31].x, currentPts[31].y, xc1, yc1);
            ctx.closePath();

            ctx.fillStyle = root.accentColor.toString();
            ctx.fill();
        }
    }
}
