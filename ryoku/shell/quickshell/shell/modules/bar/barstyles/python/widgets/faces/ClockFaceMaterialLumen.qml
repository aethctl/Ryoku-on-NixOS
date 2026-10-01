import QtQuick
import "../../"

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 100
    property real minHeight: 100
    property real maxWidth: 800
    property real maxHeight: 800
    property real minAspect: 1.0
    property real maxAspect: 1.0
    property bool isRound: true

    property bool showSeconds: true

    property var currentTime: new Date()

    Timer {
        interval: 16
        running: true
        repeat: true
        onTriggered: {
            root.currentTime = new Date();
            dialCanvas.requestPaint();
        }
    }

    function resolveColor(token, fallback) {
        if (typeof ThemeBackend !== "undefined" && ThemeBackend.matugenColors) {
            var val = ThemeBackend.matugenColors[token];
            if (val) {
                if (typeof val === "string") return Qt.color(val);
                if (typeof val === "object") {
                    if (val.hex) return Qt.color(val.hex);
                    if (val.color) return Qt.color(val.color);
                    if (val.default && val.default.hex) return Qt.color(val.default.hex);
                }
            }
        }
        return fallback;
    }

    readonly property color dialColor: resolveColor("primary_container", ThemeBackend.surface0)
    readonly property color hourHandColor: resolveColor("secondary", ThemeBackend.peach)
    readonly property color minuteHandColor: resolveColor("primary", ThemeBackend.mauve)
    readonly property color secondHandColor: resolveColor("tertiary", ThemeBackend.teal)
    readonly property color numberColor: resolveColor("on_primary_container", ThemeBackend.text)

    readonly property real handWidth: Math.min(root.width, root.height) * 0.054
    readonly property real secondHandWidth: root.handWidth

    function normDeg(deg) {
        return ((deg % 360) + 360) % 360;
    }

    function angleDiff(a, b) {
        var diff = Math.abs(normDeg(a) - normDeg(b));
        return diff > 180 ? 360 - diff : diff;
    }

    function beam(handAngle, targetAngle, spread) {
        var diff = angleDiff(handAngle, targetAngle);
        if (diff >= spread) return 0;
        var rad = (diff / spread) * (Math.PI / 2);
        var c = Math.cos(rad);
        return c * c;
    }

    function getIllumination(targetAngle) {
        var iHour = beam(hourPivot.rotation, targetAngle, 45);
        var iMin = beam(minutePivot.rotation, targetAngle, 40);
        var iSec = root.showSeconds ? beam(secondPivot.rotation, targetAngle, 32) * 0.85 : 0;

        var maxI = Math.max(iHour, Math.max(iMin, iSec));
        var activeCol = root.hourHandColor;
        if (iSec >= iHour && iSec >= iMin) {
            activeCol = root.secondHandColor;
        } else if (iMin >= iHour) {
            activeCol = root.minuteHandColor;
        }

        return {
            intensity: maxI,
            color: activeCol
        };
    }

    Item {
        anchors.fill: parent

        Canvas {
            id: dialCanvas
            anchors.fill: parent
            antialiasing: true

            property color fillColor: root.dialColor

            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            onFillColorChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d");
                ctx.reset();
                var cx = width / 2;
                var cy = height / 2;
                var size = Math.min(width, height);
                var rBase = size * 0.435;
                var rAmp = size * 0.042;
                var steps = 240;

                var w = new Array(12);
                for (var k = 0; k < 12; k++) {
                    var degTarget = (k === 0 ? 12 : k) * 30;
                    w[k] = root.getIllumination(degTarget).intensity;
                }

                ctx.beginPath();
                for (var i = 0; i <= steps; i++) {
                    var a = (i / steps) * Math.PI * 2;
                    var deg = (a * 180 / Math.PI) % 360;
                    var h = Math.round(deg / 30) % 12;
                    var diff = Math.abs(deg - (h * 30));
                    if (diff > 180) diff = 360 - diff;
                    var bump = 0.5 * (1 + Math.cos((diff / 15) * Math.PI));
                    var bumpScale = 0.28 + 0.72 * w[h];
                    var r = rBase + (rAmp * bumpScale) * bump;
                    var x = cx + r * Math.sin(a);
                    var y = cy - r * Math.cos(a);

                    if (i === 0) {
                        ctx.moveTo(x, y);
                    } else {
                        ctx.lineTo(x, y);
                    }
                }
                ctx.closePath();
                ctx.fillStyle = fillColor;
                ctx.fill();
            }
        }

        Item {
            id: numbersLayer
            anchors.fill: parent

            Repeater {
                model: 12

                Item {
                    id: numDelegate
                    required property int index

                    readonly property int hourVal: index + 1
                    readonly property real angleDeg: (hourVal % 12) * 30
                    readonly property real angleRad: angleDeg * (Math.PI / 180)

                    readonly property var illum: root.getIllumination(angleDeg)
                    readonly property real intensity: illum.intensity
                    readonly property color activeColor: illum.color

                    readonly property real rDist: Math.min(root.width, root.height) * (0.382 + 0.028 * intensity)

                    width: Math.min(root.width, root.height) * 0.11
                    height: width
                    x: (root.width / 2) + rDist * Math.sin(angleRad) - width / 2
                    y: (root.height / 2) - rDist * Math.cos(angleRad) - height / 2
                    visible: intensity > 0.001

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width * 0.92
                        height: width
                        radius: width / 2
                        color: numDelegate.activeColor
                        opacity: numDelegate.intensity * 0.24
                        antialiasing: true
                    }

                    Text {
                        anchors.centerIn: parent
                        text: numDelegate.hourVal
                        font.family: ThemeBackend.fontFamily
                        font.pixelSize: Math.min(root.width, root.height) * 0.054
                        font.weight: Font.Bold
                        color: numDelegate.intensity > 0.5 ? root.numberColor : numDelegate.activeColor
                        opacity: numDelegate.intensity
                    }
                }
            }
        }

        Item {
            id: hourPivot
            anchors.centerIn: parent
            z: 1
            rotation: (root.currentTime.getHours() % 12) * 30 + root.currentTime.getMinutes() * 0.5 + root.currentTime.getSeconds() * (0.5 / 60)

            Rectangle {
                width: root.handWidth
                height: Math.min(root.width, root.height) * 0.22
                radius: width / 2
                color: root.hourHandColor
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: -width / 2
                antialiasing: true
            }
        }

        Item {
            id: minutePivot
            anchors.centerIn: parent
            z: 2
            rotation: root.currentTime.getMinutes() * 6 + root.currentTime.getSeconds() * 0.1

            Rectangle {
                width: root.handWidth
                height: Math.min(root.width, root.height) * 0.32
                radius: width / 2
                color: root.minuteHandColor
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: -width / 2
                antialiasing: true
            }
        }

        Item {
            id: secondPivot
            visible: root.showSeconds
            anchors.centerIn: parent
            z: 3
            rotation: (root.currentTime.getSeconds() + root.currentTime.getMilliseconds() / 1000) * 6

            Rectangle {
                width: root.secondHandWidth
                height: Math.min(root.width, root.height) * 0.38
                radius: width / 2
                color: root.secondHandColor
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.top
                anchors.bottomMargin: -width / 2
                antialiasing: true
            }
        }
    }
}
