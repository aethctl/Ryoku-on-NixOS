pragma ComponentBehavior: Bound

import QtQuick
import shell.services
import shell.barkit as Pill
import Ryoku.Ui.Singletons
import "../kit" as K

Column {
    id: page

    property var host

    spacing: 12

    readonly property color fill: Theme.shadow
    readonly property color ink: Theme.ink(fill, 7)
    readonly property color accent: Theme.primary
    function dim(a) { return Qt.rgba(page.ink.r, page.ink.g, page.ink.b, a) }

    property string pendingSsid: ""
    property string pendingBssid: ""
    property string password: ""

    readonly property bool connected: Network.wifiConnectivity === "Connected"
    readonly property var aps: {
        var list = (Network.accessPoints || []).slice();
        var out = [];
        for (var i = 0; i < list.length; i++)
            if (list[i] && !list[i].active) out.push(list[i]);
        out.sort(function (a, b) {
            if (a.saved !== b.saved) return a.saved ? -1 : 1;
            return (b.strength || 0) - (a.strength || 0);
        });
        return out;
    }
    function isOpen(ap) {
        var s = String(ap.security || "").toLowerCase();
        return s === "" || s === "none";
    }
    function securityLabel(ap) {
        if (page.isOpen(ap)) return I18n.tr("Open");
        return String(ap.security || "").toUpperCase();
    }
    function connect(ap) {
        if (ap.saved || page.isOpen(ap)) {
            Network.connectWifi(ap.ssid, "", ap.bssid);
            page.cancelPassword();
            return;
        }
        page.pendingSsid = ap.ssid;
        page.pendingBssid = ap.bssid || "";
        page.password = "";
        Qt.callLater(function () { if (pwField) pwField.forceActiveFocus(); });
    }
    function submitPassword() {
        if (page.pendingSsid === "") return;
        Network.connectWifi(page.pendingSsid, page.password, page.pendingBssid);
        page.cancelPassword();
    }
    function cancelPassword() {
        page.pendingSsid = "";
        page.pendingBssid = "";
        page.password = "";
        if (pwField) pwField.focus = false;
    }

    Item {
        width: parent.width
        height: 36

        K.QsBack {
            id: back
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            onClicked: page.host.back()
        }
        Text {
            anchors { left: back.right; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: I18n.tr("Wi-Fi")
            color: page.ink
            font.family: Theme.fontPrimary
            font.pixelSize: 18
            font.weight: Font.DemiBold
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 10

            Item {
                width: 36
                height: 36
                Rectangle {
                    anchors.fill: parent
                    radius: 18
                    color: scanHover.hovered ? page.dim(0.12) : "transparent"
                }
                Pill.MaterialIcon {
                    anchors.centerIn: parent
                    text: "refresh"
                    color: page.dim(0.8)
                    font.pixelSize: 19
                }
                HoverHandler { id: scanHover }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Network.refresh()
                }
            }
            K.QsSwitch {
                anchors.verticalCenter: parent.verticalCenter
                value: Network.wifiRadio
                onToggled: (v) => Network.setWifiEnabled(v)
            }
        }
    }

    Text {
        visible: !Network.wifiRadio
        text: I18n.tr("Wi-Fi is off")
        color: page.dim(0.55)
        font.family: Theme.fontPrimary
        font.pixelSize: 13
    }

    Rectangle {
        id: connectedRow
        visible: Network.wifiRadio && page.connected
        width: parent.width
        height: 64
        radius: 18
        color: page.dim(0.06)

        Rectangle {
            id: connDisc
            anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
            width: 42
            height: 42
            radius: 21
            color: page.accent
            Pill.GlyphIcon {
                anchors.centerIn: parent
                width: 20
                height: 20
                name: "wifi"
                color: page.fill
            }
        }
        Column {
            anchors {
                left: connDisc.right; leftMargin: 12
                right: connAction.left; rightMargin: 10
                verticalCenter: parent.verticalCenter
            }
            spacing: 1
            Text {
                width: parent.width
                text: Network.activeSsid
                color: page.ink
                font.family: Theme.fontPrimary
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                text: I18n.tr("Connected")
                color: page.dim(0.6)
                font.family: Theme.fontPrimary
                font.pixelSize: 11
            }
        }
        K.QsAction {
            id: connAction
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: I18n.tr("Disconnect")
            onClicked: Network.disconnectWifi()
        }
    }

    Text {
        visible: Network.wifiRadio
        text: I18n.tr("Networks")
        color: page.dim(0.55)
        font.family: Theme.fontPrimary
        font.pixelSize: 12
    }

    Column {
        visible: Network.wifiRadio
        width: parent.width
        spacing: 8

        Repeater {
            model: page.aps
            delegate: Rectangle {
                id: apRow
                required property var modelData
                width: parent.width
                height: 58
                radius: 18
                color: apRow.modelData.saved
                    ? Qt.rgba(page.accent.r, page.accent.g, page.accent.b, 0.10)
                    : page.dim(0.05)

                Rectangle {
                    id: apDisc
                    anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    width: 38
                    height: 38
                    radius: 19
                    color: page.dim(0.10)
                    Pill.GlyphIcon {
                        anchors.centerIn: parent
                        width: 19
                        height: 19
                        name: "wifi"
                        color: page.dim(0.85)
                        opacity: 0.45 + 0.55 * Math.max(0, Math.min(1, (apRow.modelData.strength || 0) / 100))
                    }
                }
                Column {
                    anchors {
                        left: apDisc.right; leftMargin: 10
                        right: apAction.left; rightMargin: 10
                        verticalCenter: parent.verticalCenter
                    }
                    spacing: 1
                    Text {
                        width: parent.width
                        text: apRow.modelData.ssid || ""
                        color: page.ink
                        font.family: Theme.fontPrimary
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: page.securityLabel(apRow.modelData)
                            + (apRow.modelData.band ? "  \u00B7  " + apRow.modelData.band : "")
                        color: page.dim(0.6)
                        font.family: Theme.fontPrimary
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
                K.QsAction {
                    id: apAction
                    anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                    text: I18n.tr("Connect")
                    onClicked: page.connect(apRow.modelData)
                }
            }
        }

        Text {
            visible: page.aps.length === 0
            text: I18n.tr("No networks found")
            color: page.dim(0.5)
            font.family: Theme.fontPrimary
            font.pixelSize: 12
        }
    }

    Rectangle {
        id: pwCard
        visible: page.pendingSsid !== ""
        width: parent.width
        height: pwColumn.implicitHeight + 28
        radius: 18
        color: page.dim(0.08)

        Column {
            id: pwColumn
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 10

            Text {
                width: parent.width
                text: I18n.tr("Password for %1").replace("%1", page.pendingSsid)
                color: page.ink
                font.family: Theme.fontPrimary
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Rectangle {
                width: parent.width
                height: 40
                radius: 12
                color: page.dim(0.12)
                TextInput {
                    id: pwField
                    anchors {
                        left: parent.left; right: parent.right
                        leftMargin: 12; rightMargin: 12
                        verticalCenter: parent.verticalCenter
                    }
                    echoMode: TextInput.Password
                    color: page.ink
                    font.family: Theme.fontPrimary
                    font.pixelSize: 13
                    selectionColor: page.accent
                    selectedTextColor: page.fill
                    onAccepted: page.submitPassword()
                }
            }
            Row {
                spacing: 10
                K.QsAction {
                    text: I18n.tr("Connect")
                    onClicked: page.submitPassword()
                }
                K.QsAction {
                    text: I18n.tr("Cancel")
                    onClicked: page.cancelPassword()
                }
            }
        }
    }
}
