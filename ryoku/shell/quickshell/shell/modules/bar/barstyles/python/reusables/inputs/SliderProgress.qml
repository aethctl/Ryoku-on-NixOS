import QtQuick
import QtQuick.Effects
import "../"

Item {
    id: root
    implicitWidth: 200
    implicitHeight: 24

    property real from: 0.0
    property real to: 100.0
    property real value: 0.0

    property color backgroundColor: "#1e1e2e"
    property color gradColor1: "#89b4fa"
    property color gradColor2: Qt.lighter(gradColor1, 1.05)
    property color gradColor3: Qt.lighter(gradColor1, 1.10)

    property color glowColor: gradColor1
    property real glowRadius: 0.6
    property real glowOpacity: 0.5

    property real cornerRadius: height / 2
    property bool enabled: true

    property bool isDragging: false

    signal moved(real val)
    signal dragStarted()
    signal dragFinished()

    property real visualPosition: Math.max(0.0, Math.min(1.0, (value - from) / Math.max(0.0001, to - from)))
    property real animPosition: visualPosition

    Behavior on animPosition {
        enabled: !root.isDragging
        NumberAnimation { duration: 250; easing.type: Easing.OutQuint }
    }

    Rectangle {
        id: bgTrack
        anchors.fill: parent
        radius: root.cornerRadius
        color: root.backgroundColor
        opacity: root.enabled ? 1.0 : 0.5
        clip: true

        Behavior on opacity { NumberAnimation { duration: 180 } }

        Item {
            id: fillContainer
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Math.max(0, Math.min(parent.width, parent.width * root.animPosition))
            opacity: root.animPosition > 0.001 ? 1.0 : 0.0
            clip: true

            Behavior on opacity { NumberAnimation { duration: 180 } }

            Rectangle {
                width: root.width
                height: parent.height
                radius: root.cornerRadius

                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: root.gradColor1; Behavior on color { ColorAnimation { duration: 500 } } }
                    GradientStop { position: 0.5; color: root.gradColor2; Behavior on color { ColorAnimation { duration: 500 } } }
                    GradientStop { position: 1.0; color: root.gradColor3; Behavior on color { ColorAnimation { duration: 500 } } }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: root.cornerRadius
                color: root.glowColor
                opacity: root.glowOpacity * 0.2
                visible: root.glowOpacity > 0
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.cornerRadius
        color: "transparent"
        border.color: Qt.rgba(1, 1, 1, 0.06)
        border.width: 1
    }

    MouseArea {
        id: sliderMa
        anchors.fill: parent
        hoverEnabled: root.enabled
        enabled: root.enabled
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

        onPressed: mouse => {
            if (!root.enabled) return;
            root.isDragging = true;
            root.dragStarted();
            updateVal(mouse.x);
        }
        onPositionChanged: mouse => {
            if (pressed && root.enabled) {
                updateVal(mouse.x);
            }
        }
        onReleased: {
            if (!root.enabled) return;
            root.isDragging = false;
            root.dragFinished();
        }

        function updateVal(mx) {
            let pct = Math.max(0.0, Math.min(1.0, mx / width));
            root.value = root.from + pct * (root.to - root.from);
            root.moved(root.value);
        }
    }
}
