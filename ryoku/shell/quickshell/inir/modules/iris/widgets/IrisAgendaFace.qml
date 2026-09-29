pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import inir.services
import inir.modules.iris.style

IrisWidgetFace {
    id: root

    readonly property var today: DateTime.clock.date
    readonly property var events: Array.from(root.widget.upcomingEvents ?? [])
    readonly property int capacity: root.small ? 1 : root.medium ? 3 : 6
    readonly property var shown: root.events.slice(0, root.capacity)

    function dayLabel(event: var): string {
        const when = IrisFaceData.eventDate(event)
        const start = new Date(root.today)
        start.setHours(0, 0, 0, 0)
        const day = new Date(when)
        day.setHours(0, 0, 0, 0)
        const days = Math.round((day.getTime() - start.getTime()) / 86400000)
        if (days === 0) return Translation.tr("Today")
        if (days === 1) return Translation.tr("Tomorrow")
        return IrisFaceData.capitalized(Qt.locale().toString(when, "dddd d"))
    }

    component DateHero: ColumnLayout {
        spacing: 0
        FaceText {
            face: root
            Layout.fillWidth: true
            text: IrisFaceData.capitalized(Qt.locale().toString(root.today, "dddd"))
            color: root.highlight
            size: 13
            weight: Font.DemiBold
        }
        FaceFigure {
            face: root
            Layout.fillWidth: true
            text: root.today.getDate()
            size: 40
        }
    }

    component EventRow: RowLayout {
        id: row
        property var event: null
        spacing: root.dp(8)
        Rectangle {
            Layout.preferredWidth: root.dp(3)
            Layout.fillHeight: true
            radius: width / 2
            color: IrisFaceData.eventTint(row.event, root.accent)
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            FaceText {
                face: root
                Layout.fillWidth: true
                text: IrisFaceData.eventTitle(row.event)
                size: 13
                weight: Font.DemiBold
            }
            FaceText {
                face: root
                Layout.fillWidth: true
                text: {
                    const when = IrisFaceData.eventWhen(row.event, root.today)
                    const place = root.widget.showLocation ? String(row.event?.location ?? "") : ""
                    return place.length > 0 ? when + " · " + place : when
                }
                color: root.inkSecondary
                size: 11.5
            }
        }
    }

    component Empty: FaceText {
        face: root
        text: Translation.tr("Nothing scheduled")
        color: root.inkTertiary
        size: 12.5
        wrapMode: Text.WordWrap
        maximumLineCount: 2
    }

    ColumnLayout {
        visible: root.small
        anchors.fill: parent
        spacing: root.dp(6)
        DateHero { Layout.fillWidth: true }
        Item { Layout.fillHeight: true }
        EventRow {
            visible: root.shown.length > 0
            Layout.fillWidth: true
            event: root.shown[0] ?? null
        }
        Empty { visible: root.shown.length === 0; Layout.fillWidth: true }
    }

    RowLayout {
        visible: root.medium
        anchors.fill: parent
        spacing: root.dp(14)
        DateHero {
            Layout.fillWidth: false
            Layout.preferredWidth: root.contentWidth * 0.28
            Layout.alignment: Qt.AlignTop
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.dp(8)
            Repeater {
                model: root.shown
                EventRow {
                    required property var modelData
                    Layout.fillWidth: true
                    event: modelData
                }
            }
            Empty { visible: root.shown.length === 0; Layout.fillWidth: true }
            Item { Layout.fillHeight: true }
        }
    }

    ColumnLayout {
        visible: root.large
        anchors.fill: parent
        spacing: root.dp(8)
        DateHero { Layout.fillWidth: true }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: IrisStyle.hairline
        }
        Repeater {
            model: root.large ? root.shown : []
            ColumnLayout {
                id: entry
                required property var modelData
                required property int index
                readonly property string day: root.dayLabel(entry.modelData)
                readonly property bool heading: entry.index === 0 || root.dayLabel(root.shown[entry.index - 1]) !== entry.day
                Layout.fillWidth: true
                spacing: root.dp(4)
                FaceText {
                    face: root
                    visible: entry.heading && root.widget.groupByDay
                    Layout.fillWidth: true
                    Layout.topMargin: entry.index === 0 ? 0 : root.dp(4)
                    text: entry.day
                    color: root.inkTertiary
                    size: 11.5
                    weight: Font.DemiBold
                }
                EventRow {
                    Layout.fillWidth: true
                    event: entry.modelData
                }
            }
        }
        Empty { visible: root.shown.length === 0; Layout.fillWidth: true }
        Item { Layout.fillHeight: true }
    }
}
