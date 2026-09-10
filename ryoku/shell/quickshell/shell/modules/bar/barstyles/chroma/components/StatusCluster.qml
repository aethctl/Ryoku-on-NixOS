pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services
import "." as C

Rectangle {
    id: root

    required property var colors

    readonly property real outputVolume: Audio.sink && Audio.sink.audio
        ? Math.max(0, Math.min(1, Audio.sink.audio.volume))
        : 0
    readonly property bool outputMuted: !!(Audio.sink && Audio.sink.audio && Audio.sink.audio.muted)
    readonly property int notificationCount: Notifs.history.length

    implicitWidth: row.implicitWidth + Theme.paddingMd * 2
    implicitHeight: Theme.iconLg + Theme.paddingLg

    radius: Theme.radiusWidget
    color: root.colors.backgroundAlt
    border.width: 0

    Row {
        id: row
        anchors {
            left: parent.left
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: Theme.paddingMd
            rightMargin: Theme.paddingMd
        }
        height: parent.height
        spacing: Theme.paddingSm

        C.UtilityButton {
            height: parent.height
            colors: root.colors
            icon: root.notificationCount > 0 ? "notifications_active" : "notifications_none"
            label: root.notificationCount > 0 ? String(root.notificationCount) : ""
            active: root.notificationCount > 0
            accentIndex: 0
            onClicked: ShellState.requestSurfaceActive("quick-settings#notifications", undefined)
        }

        C.UtilityButton {
            height: parent.height
            colors: root.colors
            icon: "palette"
            accentIndex: 2
            onClicked: ShellState.requestSurfaceActive("wallpaper", undefined)
        }

        C.UtilityButton {
            height: parent.height
            colors: root.colors
            icon: Network.kind === "ethernet" ? "lan" : Network.kind === "wifi" ? "wifi" : "wifi_off"
            active: Network.kind !== ""
            accentIndex: 3
            onClicked: ShellState.requestSurfaceActive("network", undefined)
        }

        C.UtilityButton {
            height: parent.height
            colors: root.colors
            icon: root.outputMuted || root.outputVolume <= 0.001
                ? "volume_off"
                : root.outputVolume > 0.66
                    ? "volume_up"
                    : "volume_down"
            label: Math.round(root.outputVolume * 100) + "%"
            scrollable: true
            accentIndex: 5
            onClicked: ShellState.requestSurfaceActive("audio", undefined)
            onScrolled: steps => Quickshell.execDetached(["ryoku-shell", "audio", steps > 0 ? "up" : "down"])
        }

        C.UtilityButton {
            visible: Battery.present
            height: parent.height
            colors: root.colors
            icon: Battery.charging || Battery.full ? "battery_charging_full" : "battery_full"
            label: Battery.pct + "%"
            active: Battery.low
            accentIndex: 0
            onClicked: ShellState.requestSurfaceActive("battery", undefined)
        }

        C.UtilityButton {
            height: parent.height
            colors: root.colors
            icon: "tune"
            accentIndex: 4
            onClicked: ShellState.requestSurfaceActive("quick-settings", undefined)
        }
    }
}
