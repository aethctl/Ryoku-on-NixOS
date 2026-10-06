pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC
import Ryoku.Blobs
import Ryoku.Ui.Singletons
import shell.services
import "cards" as Cards

Item {
    id: root

    required property real s
    required property var screen
    required property bool active
    property string page: "controls"
    signal requestClose()

    readonly property string currentPage: ["wifi", "bluetooth"].indexOf(page) >= 0 ? page : "controls"
    readonly property bool overviewActive: active && currentPage === "controls"
    readonly property bool motionAllowed: !Tokens.reduceMotion && !Motion.reduce

    implicitHeight: currentPage === "controls" ? overview.implicitHeight : Tokens.cellH * 4 * s

    function showPage(value): void {
        SidebarState.selectTab(root.screen, value);
    }

    function session(action): void {
        root.requestClose();
        SessionActions.run(action);
    }

    function settleSections(value): void {
        heroSection.opacity = value;
        connectionsSection.opacity = value;
        profileSection.opacity = value;
        levelsSection.opacity = value;
        barSection.opacity = value;
        heroShift.y = value ? 0 : Tokens.s2 * root.s;
        connectionsShift.y = value ? 0 : Tokens.s2 * root.s;
        profileShift.y = value ? 0 : Tokens.s2 * root.s;
        levelsShift.y = value ? 0 : Tokens.s2 * root.s;
        barShift.y = value ? 0 : Tokens.s2 * root.s;
    }

    function updateReveal(): void {
        heroReveal.stop();
        connectionsReveal.stop();
        profileReveal.stop();
        levelsReveal.stop();
        barReveal.stop();
        if (!root.overviewActive) {
            root.settleSections(0);
        } else if (!root.motionAllowed) {
            root.settleSections(1);
        } else {
            root.settleSections(0);
            heroReveal.start();
            connectionsReveal.start();
            profileReveal.start();
            levelsReveal.start();
            barReveal.start();
        }
    }

    onOverviewActiveChanged: root.updateReveal()
    onMotionAllowedChanged: root.updateReveal()
    Component.onCompleted: root.updateReveal()

    Connections {
        target: SidebarState
        function onSpeedScaleChanged() { root.updateReveal(); }
    }

    SystemMonitor {
        id: monitor
        active: root.overviewActive
    }

    SequentialAnimation {
        id: heroReveal
        ParallelAnimation {
            NumberAnimation {
                target: heroSection
                property: "opacity"
                from: 0
                to: 1
                duration: SidebarState.motionDuration(Tokens.swap)
                easing.type: Tokens.ease
            }
            NumberAnimation {
                target: heroShift
                property: "y"
                from: Tokens.s2 * root.s
                to: 0
                duration: SidebarState.motionDuration(Tokens.swap)
                easing.type: Tokens.ease
            }
        }
    }
    SequentialAnimation {
        id: connectionsReveal
        PauseAnimation { duration: SidebarState.motionDuration(Tokens.snap / 3) }
        ParallelAnimation {
            NumberAnimation {
                target: connectionsSection
                property: "opacity"
                from: 0
                to: 1
                duration: SidebarState.motionDuration(Tokens.swap)
                easing.type: Tokens.ease
            }
            NumberAnimation {
                target: connectionsShift
                property: "y"
                from: Tokens.s2 * root.s
                to: 0
                duration: SidebarState.motionDuration(Tokens.swap)
                easing.type: Tokens.ease
            }
        }
    }
    SequentialAnimation {
        id: profileReveal
        PauseAnimation { duration: SidebarState.motionDuration(Tokens.snap * 2 / 3) }
        ParallelAnimation {
            NumberAnimation {
                target: profileSection
                property: "opacity"
                from: 0
                to: 1
                duration: SidebarState.motionDuration(Tokens.swap)
                easing.type: Tokens.ease
            }
            NumberAnimation {
                target: profileShift
                property: "y"
                from: Tokens.s2 * root.s
                to: 0
                duration: SidebarState.motionDuration(Tokens.swap)
                easing.type: Tokens.ease
            }
        }
    }
    SequentialAnimation {
        id: levelsReveal
        PauseAnimation { duration: SidebarState.motionDuration(Tokens.snap) }
        ParallelAnimation {
            NumberAnimation {
                target: levelsSection
                property: "opacity"
                from: 0
                to: 1
                duration: SidebarState.motionDuration(Tokens.swap)
                easing.type: Tokens.ease
            }
            NumberAnimation {
                target: levelsShift
                property: "y"
                from: Tokens.s2 * root.s
                to: 0
                duration: SidebarState.motionDuration(Tokens.swap)
                easing.type: Tokens.ease
            }
        }
    }
    SequentialAnimation {
        id: barReveal
        PauseAnimation { duration: SidebarState.motionDuration(Tokens.snap * 4 / 3) }
        ParallelAnimation {
            NumberAnimation {
                target: barSection
                property: "opacity"
                from: 0
                to: 1
                duration: SidebarState.motionDuration(Tokens.swap)
                easing.type: Tokens.ease
            }
            NumberAnimation {
                target: barShift
                property: "y"
                from: Tokens.s2 * root.s
                to: 0
                duration: SidebarState.motionDuration(Tokens.swap)
                easing.type: Tokens.ease
            }
        }
    }

    Column {
        id: overview
        anchors.left: parent.left
        anchors.right: parent.right
        visible: root.currentPage === "controls"
        spacing: Tokens.s3 * root.s

        Item {
            id: heroSection
            width: parent.width
            implicitHeight: hero.implicitHeight
            height: implicitHeight
            opacity: 0
            transform: Translate { id: heroShift; y: Tokens.s2 * root.s }

            ControlsHero {
                id: hero
                width: parent.width
                height: implicitHeight
                s: root.s
                active: root.overviewActive
                monitor: monitor
            }
        }

        Item {
            id: connectionsSection
            width: parent.width
            implicitHeight: connections.implicitHeight
            height: implicitHeight
            opacity: 0
            transform: Translate { id: connectionsShift; y: Tokens.s2 * root.s }

            ControlsConnections {
                id: connections
                width: parent.width
                height: implicitHeight
                s: root.s
                screen: root.screen
                active: root.overviewActive
                onOpenPage: page => root.showPage(page)
            }
        }

        Item {
            id: profileSection
            width: parent.width
            implicitHeight: powerProfile.implicitHeight
            height: implicitHeight
            opacity: 0
            transform: Translate { id: profileShift; y: Tokens.s2 * root.s }

            PowerProfileControl {
                id: powerProfile
                width: parent.width
                height: implicitHeight
                s: root.s
                active: root.overviewActive
            }
        }

        Item {
            id: levelsSection
            width: parent.width
            implicitHeight: levels.implicitHeight
            height: implicitHeight
            opacity: 0
            transform: Translate { id: levelsShift; y: Tokens.s2 * root.s }

            ControlsLevels {
                id: levels
                width: parent.width
                height: implicitHeight
                s: root.s
                screen: root.screen
                active: root.overviewActive
            }
        }

        Item {
            id: barSection
            width: parent.width
            implicitHeight: controlsBar.implicitHeight
            height: implicitHeight
            opacity: 0
            transform: Translate { id: barShift; y: Tokens.s2 * root.s }

            ControlsBar {
                id: controlsBar
                width: parent.width
                height: implicitHeight
                s: root.s
                screen: root.screen
                active: root.overviewActive
                onSession: action => root.session(action)
                onOpenExtensions: root.showPage("plugins")
                onRequestClose: root.requestClose()
            }
        }
    }

    QQC.ScrollView {
        id: detailScroll
        anchors.fill: parent
        visible: root.currentPage !== "controls"
        clip: true
        contentWidth: availableWidth
        QQC.ScrollBar.horizontal.policy: QQC.ScrollBar.AlwaysOff

        Loader {
            width: detailScroll.availableWidth
            active: root.currentPage !== "controls"
            sourceComponent: root.currentPage === "wifi" ? wifiPage : bluetoothPage
        }
    }

    Component {
        id: wifiPage
        Cards.SystemWifiPage {
            s: root.s
            active: root.active && root.currentPage === "wifi"
            onBackRequested: root.showPage("controls")
        }
    }
    Component {
        id: bluetoothPage
        Cards.SystemBluetoothPage {
            s: root.s
            active: root.active && root.currentPage === "bluetooth"
            onBackRequested: root.showPage("controls")
        }
    }
}
