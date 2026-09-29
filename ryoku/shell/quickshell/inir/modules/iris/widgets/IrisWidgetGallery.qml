pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import inir
import inir.services
import inir.modules.common
import inir.modules.common.widgets
import inir.modules.iris.style
import inir.modules.iris.components

ColumnLayout {
    id: root

    readonly property real d: IrisStyle.density
    readonly property string outputName: GlobalStates.focusedScreen?.name ?? ""
    readonly property var entries: [
        { key: "clock", glyph: "schedule", label: Translation.tr("Clock"), tint: IrisStyle.identity.orange },
        { key: "weather", glyph: "partly_cloudy_day", label: Translation.tr("Weather"), tint: IrisStyle.identity.blue },
        { key: "mediaControls", glyph: "music_note", label: Translation.tr("Now Playing"), tint: IrisStyle.identity.pink },
        { key: "controls", glyph: "toggle_on", label: Translation.tr("Controls"), tint: IrisStyle.identity.blue },
        { key: "monthCalendar", glyph: "calendar_month", label: Translation.tr("Calendar"), tint: IrisStyle.identity.red },
        { key: "calendarUpcoming", glyph: "event_upcoming", label: Translation.tr("Up next"), tint: IrisStyle.identity.red },
        { key: "todo", glyph: "checklist", label: Translation.tr("Tasks"), tint: IrisStyle.identity.orange },
        { key: "notes", glyph: "sticky_note_2", label: Translation.tr("Notes"), tint: IrisStyle.identity.yellow },
        { key: "timers", glyph: "timer", label: Translation.tr("Timers"), tint: IrisStyle.identity.orange },
        { key: "screenTime", glyph: "hourglass_bottom", label: Translation.tr("Screen Time"), tint: IrisStyle.identity.indigo },
        { key: "systemMonitor", glyph: "monitor_heart", label: Translation.tr("Vitals"), tint: IrisStyle.identity.green },
        { key: "battery", glyph: "battery_full", label: Translation.tr("Batteries"), tint: IrisStyle.identity.green },
        { key: "worldClock", glyph: "public", label: Translation.tr("World clock"), tint: IrisStyle.identity.orange },
        { key: "dayProgress", glyph: "wb_twilight", label: Translation.tr("Day"), tint: IrisStyle.identity.orange },
        { key: "dateBadge", glyph: "today", label: Translation.tr("Date"), tint: IrisStyle.identity.red },
        { key: "userCard", glyph: "account_circle", label: Translation.tr("Profile"), tint: IrisStyle.identity.blue },
        { key: "uptime", glyph: "timelapse", label: Translation.tr("Uptime"), tint: IrisStyle.identity.indigo },
        { key: "newsTicker", glyph: "newspaper", label: Translation.tr("News"), tint: IrisStyle.identity.teal }
    ]
    readonly property int placed: {
        Config.revision
        return root.entries.filter(entry => root.isOn(entry.key)).length
    }

    function isOn(key: string): bool {
        Config.revision
        return DesktopWidgetLayout.enabled(root.outputName, key, Config.getNestedValue("background.widgets." + key + ".enable", false))
    }

    spacing: Math.round(12 * root.d)

    GridLayout {
        id: grid
        Layout.fillWidth: true
        readonly property real tile: Math.round(76 * root.d)
        columns: Math.max(3, Math.floor((width + columnSpacing) / (tile + columnSpacing)))
        columnSpacing: Math.round(6 * root.d)
        rowSpacing: Math.round(10 * root.d)

        Repeater {
            model: root.entries

            Item {
                id: entry
                required property var modelData
                readonly property bool on: { Config.revision; return root.isOn(entry.modelData.key) }
                Layout.fillWidth: true
                Layout.preferredHeight: icon.height + name.implicitHeight + Math.round(8 * root.d)

                Rectangle {
                    id: icon
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: Math.round(46 * root.d)
                    height: width
                    radius: IrisStyle.iconRadius(width)
                    color: entry.on ? entry.modelData.tint : hover.hovered ? IrisStyle.fillHover : IrisStyle.fill
                    scale: tap.pressed ? IrisStyle.pressScale(0.92) : hover.hovered ? 1.04 : 1
                    Behavior on color { ColorAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }
                    Behavior on scale { NumberAnimation { duration: IrisStyle.feedbackDuration; easing.type: IrisStyle.feedbackEasing } }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: entry.modelData.glyph
                        fill: 1
                        iconSize: Math.round(22 * root.d)
                        color: entry.on ? IrisStyle.onTint : IrisStyle.textSecondary
                    }
                    Rectangle {
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: -Math.round(5 * root.d)
                        width: Math.round(18 * root.d)
                        height: width
                        radius: width / 2
                        color: entry.on ? IrisStyle.surfaceHighest : IrisStyle.accent
                        border.width: 1
                        border.color: IrisStyle.surface
                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: entry.on ? "remove" : "add"
                            iconSize: Math.round(13 * root.d)
                            font.weight: Font.Bold
                            color: entry.on ? IrisStyle.text : IrisStyle.onAccent
                        }
                    }
                }
                IrisText {
                    id: name
                    anchors.top: icon.bottom
                    anchors.topMargin: Math.round(6 * root.d)
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: entry.modelData.label
                    color: entry.on ? IrisStyle.text : IrisStyle.subtext
                    font.pixelSize: 11.5 * IrisStyle.typeScale
                    elide: Text.ElideRight
                }
                HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
                TapHandler { id: tap; onTapped: DesktopWidgetLayout.setGloballyEnabled(entry.modelData.key, !entry.on) }
                Accessible.role: Accessible.CheckBox
                Accessible.name: entry.modelData.label
                Accessible.checked: entry.on
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Math.round(10 * root.d)

        IrisText {
            Layout.fillWidth: true
            text: root.placed === 1 ? Translation.tr("1 widget on this screen") : Translation.tr("%1 widgets on this screen").arg(root.placed)
            color: IrisStyle.muted
            font.pixelSize: 11.5 * IrisStyle.typeScale
        }
        IrisButton {
            implicitHeight: Math.round(30 * root.d)
            implicitWidth: arrangeRow.implicitWidth + Math.round(24 * root.d)
            onClicked: {
                GlobalStates.settingsOverlayOpen = false
                // The desktop-widget editor lives in the Ryoku shell now; enter it
                // over IPC (this tree has no in-process handle to the stage session).
                Quickshell.execDetached(["qs", "-c", "shell", "ipc", "call", "desktop", "editWidgets", root.outputName])
            }
            Accessible.name: Translation.tr("Arrange on the desktop")
            RowLayout {
                id: arrangeRow
                anchors.centerIn: parent
                spacing: Math.round(6 * root.d)
                MaterialSymbol { text: "open_with"; iconSize: Math.round(15 * root.d); color: IrisStyle.text }
                IrisText { text: Translation.tr("Arrange on the desktop"); font.pixelSize: 12.5 * IrisStyle.typeScale; font.weight: Font.DemiBold }
            }
        }
    }
}
