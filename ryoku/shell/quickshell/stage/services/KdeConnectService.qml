pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// The Stage Editor does not edit a paired phone, so the reference's KDE-Connect
// integration is held inert here: the members the copied clock faces and the
// notification store read resolve to "no device connected", which is the honest
// default and keeps the editor free of the compositor and phone coupling the
// reference's full service carried. Ryoku pairs phones through its own Hub.
Singleton {
    id: root

    property bool _enabled: false
    readonly property bool available: false
    readonly property bool ready: false
    readonly property bool activeReachable: false
    readonly property bool scrcpyAvailable: false
    readonly property int notificationCount: 0
    readonly property string activeDeviceId: ""
    readonly property var activeDevice: null
    readonly property var devices: []

    function isIgnoredNotification(notification) {
        return false;
    }

    function considerTransferNotification(notification) {
        return false;
    }

    function dispatchActionFeedback(notification) {
    }

    function sendPing() {
    }

    function shareUrl(url) {
    }
}
