pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import shell.services
import Ryoku.Ui
import "../../../services/lib/weather.js" as WeatherModel
import Ryoku.Ui.Singletons
import ".."

Item {
    id: root

    required property real s
    required property bool open
    required property real reveal
    required property bool tabActive
    property int index: 0
    property bool compact: false
    readonly property bool motionAllowed: !Tokens.reduceMotion && !Motion.reduce
    signal requestClose()

    readonly property var cur: Weather.current
    readonly property bool hasForecast: Weather.hasData && root.cur !== null
    readonly property int updateAgeMinutes: root.ageFromClock(Weather.updatedAt)
    readonly property bool stale: root.hasForecast
        && (Weather.status !== "loaded" || root.updateAgeMinutes > 30)
    readonly property bool wide: root.width >= 560 * root.s
    readonly property real gap: Tokens.s3 * root.s
    readonly property real sectionGap: Tokens.s4 * root.s
    readonly property real pad: Tokens.s4 * root.s
    readonly property int hourSlots: root.width >= 720 * root.s ? 8 : root.wide ? 6 : 4
    readonly property int shownHours: Math.min(root.hourSlots, Weather.hourly.length)
    readonly property int shownDays: Math.min(7, Weather.daily.length)
    readonly property bool airAvailable: Weather.air !== null && Weather.air.available === true

    implicitHeight: shell.implicitHeight

    function stateTitle(): string {
        if (Weather.status === "loading")
            return I18n.tr("Reading the forecast");
        if (Weather.status === "error")
            return I18n.tr("Weather is unavailable");
        return I18n.tr("No forecast yet");
    }

    function stateDetail(): string {
        if (Weather.status === "loading")
            return I18n.tr("Current conditions and the next few days will appear here.");
        if (Weather.status === "error" && Weather.errorText.length > 0)
            return Weather.errorText;
        return I18n.tr("Choose a location in Ryoku Hub, then refresh the forecast.");
    }

    function windText(): string {
        if (!root.cur)
            return "";
        const direction = root.cur.windDir || "";
        const speed = String(root.cur.wind || "") + String(root.cur.windUnits || "");
        return direction.length > 0 ? direction + " · " + speed : speed;
    }

    function precipitationText(): string {
        if (!root.cur)
            return "";
        return String(root.cur.precip || "") + " · " + I18n.tr("%1% chance").arg(root.cur.precipProb);
    }

    function daylightDuration(): string {
        if (!root.cur)
            return "";
        const sunrise = String(root.cur.sunrise || "").match(/^(\d{1,2}):(\d{2})$/);
        const sunset = String(root.cur.sunset || "").match(/^(\d{1,2}):(\d{2})$/);
        if (!sunrise || !sunset)
            return "";
        const start = Number(sunrise[1]) * 60 + Number(sunrise[2]);
        const end = Number(sunset[1]) * 60 + Number(sunset[2]);
        const minutes = end >= start ? end - start : end + 24 * 60 - start;
        return I18n.tr("%1h %2m daylight").arg(Math.floor(minutes / 60)).arg(minutes % 60);
    }

    function ageFromClock(value): int {
        const parts = String(value || "").match(/^(\d{1,2}):(\d{2})$/);
        if (!parts)
            return -1;
        const updated = Number(parts[1]) * 60 + Number(parts[2]);
        const now = clock.date.getHours() * 60 + clock.date.getMinutes();
        const elapsed = now - updated;
        return elapsed >= 0 ? elapsed : elapsed + 24 * 60;
    }

    function staleDetail(): string {
        if (Weather.errorText.length > 0)
            return I18n.tr("Showing the last forecast. %1").arg(Weather.errorText);
        if (root.updateAgeMinutes > 30)
            return I18n.tr("This forecast was updated %1 minutes ago.").arg(root.updateAgeMinutes);
        return I18n.tr("Showing the last forecast while weather reconnects.");
    }

    function moonText(): string {
        if (!Weather.moon)
            return I18n.tr("Moon data unavailable");
        const movement = Weather.moon.waxing ? I18n.tr("Waxing") : I18n.tr("Waning");
        return I18n.tr("%1 · %2% lit · %3")
            .arg(Weather.moon.name)
            .arg(Weather.moon.illumination)
            .arg(movement);
    }

    function airSummary(): string {
        if (!root.airAvailable)
            return I18n.tr("Air quality data unavailable");
        return I18n.tr("European AQI %1 · %2").arg(Weather.air.eaqi).arg(Weather.air.verdict);
    }

    function pollutantSummary(): string {
        if (!root.airAvailable)
            return "";
        return I18n.tr("PM2.5 %1   PM10 %2   O₃ %3")
            .arg(Weather.air.pm25)
            .arg(Weather.air.pm10)
            .arg(Weather.air.ozone);
    }

    component SectionHeading: Text {
        color: Tokens.ink
        font.family: Tokens.ui
        font.pixelSize: Tokens.fRow * root.s
        font.weight: Font.DemiBold
        wrapMode: Text.Wrap
    }

    component QuietLabel: Text {
        color: Tokens.inkMuted
        font.family: Tokens.ui
        font.pixelSize: Tokens.fSmall * root.s
        wrapMode: Text.Wrap
    }

    component MetricReadout: Item {
        id: metric
        required property string glyph
        required property string label
        required property string value
        property bool divider: false

        implicitHeight: Math.max(58 * root.s, metricColumn.implicitHeight + Tokens.s2 * root.s)
        height: implicitHeight

        Text {
            id: metricGlyph
            anchors.left: parent.left
            anchors.top: parent.top
            width: 24 * root.s
            text: metric.glyph
            color: Tokens.inkMuted
            font.family: "Material Symbols Rounded"
            font.pixelSize: 19 * root.s
            horizontalAlignment: Text.AlignHCenter
        }
        Column {
            id: metricColumn
            anchors.left: metricGlyph.right
            anchors.right: parent.right
            anchors.leftMargin: Tokens.s2 * root.s
            spacing: 2 * root.s
            Text {
                width: parent.width
                text: metric.label
                color: Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall * root.s
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: metric.value
                color: Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: Tokens.fRow * root.s
                font.weight: Font.Medium
                wrapMode: Text.Wrap
            }
        }
        Rectangle {
            visible: metric.divider
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Tokens.border
            color: Tokens.line
        }
    }

    component HourReadout: Item {
        id: hourCell
        required property var hourData
        property bool divider: false

        implicitHeight: 112 * root.s
        height: implicitHeight

        Column {
            anchors.fill: parent
            anchors.leftMargin: Tokens.s2 * root.s
            anchors.rightMargin: Tokens.s2 * root.s
            spacing: Tokens.s1 * root.s

            QuietLabel {
                width: parent.width
                text: hourCell.hourData.time
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: WeatherModel.symbolFor(hourCell.hourData.code, hourCell.hourData.isDay)
                color: Tokens.sun
                font.family: "Material Symbols Rounded"
                font.pixelSize: 24 * root.s
                horizontalAlignment: Text.AlignHCenter
            }
            Text {
                width: parent.width
                text: hourCell.hourData.temperature
                color: Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: Tokens.fRow * root.s
                font.weight: Font.DemiBold
                horizontalAlignment: Text.AlignHCenter
            }
            QuietLabel {
                width: parent.width
                text: I18n.tr("%1% rain").arg(hourCell.hourData.precip)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
            }
        }
        Rectangle {
            visible: hourCell.divider
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: Tokens.border
            color: Tokens.line
        }
    }

    component DailyForecastRow: Item {
        id: dayRow
        required property var dayData
        property bool divider: false

        implicitHeight: 44 * root.s
        height: implicitHeight

        Text {
            id: weekday
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 58 * root.s
            text: dayRow.dayData.weekday || dayRow.dayData.day
            color: Tokens.inkDim
            font.family: Tokens.ui
            font.pixelSize: Tokens.fSmall * root.s
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        Text {
            id: dayGlyph
            anchors.left: weekday.right
            anchors.verticalCenter: parent.verticalCenter
            width: 30 * root.s
            text: WeatherModel.symbolFor(dayRow.dayData.code, true)
            color: Tokens.sun
            font.family: "Material Symbols Rounded"
            font.pixelSize: 19 * root.s
            horizontalAlignment: Text.AlignHCenter
        }
        Text {
            id: lowTemp
            anchors.left: dayGlyph.right
            anchors.leftMargin: Tokens.s2 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: 42 * root.s
            text: dayRow.dayData.low
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: Tokens.fSmall * root.s
            horizontalAlignment: Text.AlignRight
        }
        Text {
            id: highTemp
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 42 * root.s
            text: dayRow.dayData.high
            color: Tokens.ink
            font.family: Tokens.ui
            font.pixelSize: Tokens.fSmall * root.s
            font.weight: Font.DemiBold
            horizontalAlignment: Text.AlignRight
        }
        Rectangle {
            id: rangeTrack
            anchors.left: lowTemp.right
            anchors.right: highTemp.left
            anchors.leftMargin: Tokens.s2 * root.s
            anchors.rightMargin: Tokens.s2 * root.s
            anchors.verticalCenter: parent.verticalCenter
            height: 5 * root.s
            radius: height / 2
            color: Tokens.tint10

            Rectangle {
                x: Math.round(rangeTrack.width * dayRow.dayData.loFrac)
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(5 * root.s, Math.min(rangeTrack.width - x, rangeTrack.width * (dayRow.dayData.hiFrac - dayRow.dayData.loFrac)))
                height: parent.height
                radius: height / 2
                color: Tokens.sun
            }
        }
        Rectangle {
            visible: dayRow.divider
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Tokens.border
            color: Tokens.line
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: root.open && root.tabActive
    }

    SidebarCardShell {
        id: shell
        width: root.width
        s: root.s
        index: root.index
        open: root.open
        reveal: root.reveal
        tabActive: root.tabActive
        compact: root.compact
        title: I18n.tr("Weather")
        glyph: "cloud"
        eyebrow: Weather.location.length > 0 ? Weather.location : I18n.tr("Local forecast")

        Column {
            width: parent.width
            height: implicitHeight
            spacing: root.sectionGap

            Rectangle {
                visible: !root.hasForecast
                width: parent.width
                implicitHeight: stateColumn.implicitHeight + root.pad * 2
                height: implicitHeight
                radius: Tokens.radius * root.s * 1.5
                color: Tokens.paperLift
                border.width: Tokens.border
                border.color: Weather.status === "error" ? Tokens.alert : Tokens.line

                Column {
                    id: stateColumn
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: root.pad
                    anchors.rightMargin: root.pad
                    spacing: Tokens.s3 * root.s

                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: Weather.status === "error" ? "cloud_off" : "partly_cloudy_day"
                        color: Weather.status === "error" ? Tokens.alert : Tokens.sun
                        font.family: "Material Symbols Rounded"
                        font.pixelSize: 38 * root.s
                    }
                    SectionHeading {
                        width: parent.width
                        text: root.stateTitle()
                        horizontalAlignment: Text.AlignHCenter
                    }
                    QuietLabel {
                        width: parent.width
                        text: root.stateDetail()
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Row {
                        visible: Weather.status !== "loading"
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Tokens.s2 * root.s
                        SidebarButton {
                            s: root.s
                            text: I18n.tr("Location settings")
                            glyph: "location_on"
                            motionEnabled: root.motionAllowed
                            onAct: {
                                root.requestClose();
                                Spawn.run(["ryoku-shell", "hub", "open", "global"]);
                            }
                        }
                        SidebarButton {
                            s: root.s
                            text: I18n.tr("Retry")
                            glyph: "refresh"
                            primary: true
                            motionEnabled: root.motionAllowed
                            onAct: Weather.retry()
                        }
                    }
                }
            }

            Column {
                visible: root.hasForecast
                width: parent.width
                height: implicitHeight
                spacing: root.sectionGap

                Rectangle {
                    visible: root.stale
                    width: parent.width
                    implicitHeight: staleRow.implicitHeight + Tokens.s3 * root.s * 2
                    height: implicitHeight
                    radius: Tokens.radius * root.s
                    color: Tokens.tint5
                    border.width: Tokens.border
                    border.color: Tokens.alert

                    Row {
                        id: staleRow
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.s3 * root.s
                        anchors.rightMargin: Tokens.s3 * root.s
                        spacing: Tokens.s2 * root.s
                        Text {
                            text: "sync_problem"
                            color: Tokens.alert
                            font.family: "Material Symbols Rounded"
                            font.pixelSize: 19 * root.s
                        }
                        QuietLabel {
                            width: parent.width - retryStale.implicitWidth - 19 * root.s - parent.spacing * 2
                            text: root.staleDetail()
                        }
                        SidebarButton {
                            id: retryStale
                            s: root.s
                            compact: true
                            text: I18n.tr("Retry")
                            glyph: "refresh"
                            motionEnabled: root.motionAllowed
                            onAct: Weather.retry()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    implicitHeight: heroColumn.implicitHeight + root.pad * 2
                    height: implicitHeight
                    radius: Tokens.radius * root.s * 1.5
                    color: Tokens.paperLift
                    border.width: Tokens.border
                    border.color: Tokens.line

                    Column {
                        id: heroColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: root.pad
                        spacing: root.gap

                        Item {
                            width: parent.width
                            implicitHeight: Math.max(placeColumn.implicitHeight, heroActions.implicitHeight)
                            height: implicitHeight

                            Column {
                                id: placeColumn
                                anchors.left: parent.left
                                anchors.right: heroActions.left
                                anchors.rightMargin: Tokens.s3 * root.s
                                spacing: 2 * root.s
                                Text {
                                    width: parent.width
                                    text: Weather.location.length > 0 ? Weather.location : I18n.tr("Local forecast")
                                    color: Tokens.ink
                                    font.family: Tokens.ui
                                    font.pixelSize: Tokens.fRow * root.s
                                    font.weight: Font.DemiBold
                                    wrapMode: Text.Wrap
                                }
                                QuietLabel {
                                    width: parent.width
                                    text: Weather.updatedAt.length > 0
                                        ? I18n.tr("Updated %1").arg(Weather.updatedAt)
                                        : I18n.tr("Location and units are managed in Ryoku Hub")
                                }
                            }
                            Row {
                                id: heroActions
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Tokens.s2 * root.s
                                SidebarButton {
                                    visible: root.wide && !root.compact
                                    s: root.s
                                    compact: true
                                    text: I18n.tr("Weather settings")
                                    glyph: "tune"
                                    motionEnabled: root.motionAllowed
                                    onAct: {
                                        root.requestClose();
                                        Spawn.run(["ryoku-shell", "hub", "open", "global"]);
                                    }
                                }
                                SidebarButton {
                                    id: refreshForecast
                                    s: root.s
                                    compact: true
                                    text: root.compact ? "" : I18n.tr("Refresh")
                                    Accessible.name: I18n.tr("Refresh weather")
                                    glyph: "refresh"
                                    motionEnabled: root.motionAllowed
                                    onAct: Weather.retry()
                                }
                            }
                        }

                        Rectangle {
                            width: parent.width
                            height: Tokens.border
                            color: Tokens.line
                        }

                        Flow {
                            id: heroFlow
                            width: parent.width
                            spacing: root.gap

                            Column {
                                width: root.wide ? (heroFlow.width - heroFlow.spacing) * 0.58 : heroFlow.width
                                height: implicitHeight
                                spacing: Tokens.s2 * root.s

                                Row {
                                    spacing: Tokens.s3 * root.s
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.cur ? WeatherModel.symbolFor(root.cur.code, root.cur.isDay) : "cloud"
                                        color: Tokens.sun
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: (root.compact ? 48 : 62) * root.s
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: root.cur ? root.cur.temperature : ""
                                        color: Tokens.ink
                                        font.family: Tokens.display
                                        font.pixelSize: Tokens.fValue * (root.compact ? 2.0 : 2.7) * root.s
                                        font.weight: Font.Medium
                                        font.features: ({ "tnum": 1 })
                                    }
                                }
                                Text {
                                    width: parent.width
                                    text: root.cur ? root.cur.condition : ""
                                    color: Tokens.inkDim
                                    font.family: Tokens.display
                                    font.pixelSize: Tokens.fValue * 0.9 * root.s
                                    font.weight: Font.Medium
                                    wrapMode: Text.Wrap
                                }
                            }

                            Column {
                                width: root.wide ? heroFlow.width - heroFlow.spacing - (heroFlow.width - heroFlow.spacing) * 0.58 : heroFlow.width
                                height: implicitHeight
                                spacing: Tokens.s3 * root.s

                                Column {
                                    width: parent.width
                                    spacing: 2 * root.s
                                    QuietLabel {
                                        width: parent.width
                                        text: I18n.tr("Feels like")
                                    }
                                    Text {
                                        width: parent.width
                                        text: root.cur ? root.cur.feelsLike : ""
                                        color: Tokens.ink
                                        font.family: Tokens.ui
                                        font.pixelSize: Tokens.fValue * root.s
                                        font.weight: Font.DemiBold
                                    }
                                }
                                Row {
                                    width: parent.width
                                    spacing: Tokens.s5 * root.s
                                    Column {
                                        spacing: 2 * root.s
                                        QuietLabel { text: I18n.tr("High") }
                                        Text {
                                            text: root.cur ? root.cur.high : ""
                                            color: Tokens.ink
                                            font.family: Tokens.ui
                                            font.pixelSize: Tokens.fRow * root.s
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                    Column {
                                        spacing: 2 * root.s
                                        QuietLabel { text: I18n.tr("Low") }
                                        Text {
                                            text: root.cur ? root.cur.low : ""
                                            color: Tokens.inkDim
                                            font.family: Tokens.ui
                                            font.pixelSize: Tokens.fRow * root.s
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: root.shownHours > 0
                    width: parent.width
                    implicitHeight: hourlyColumn.implicitHeight + root.pad * 2
                    height: implicitHeight
                    radius: Tokens.radius * root.s * 1.5
                    color: Tokens.tint5
                    border.width: Tokens.border
                    border.color: Tokens.line

                    Column {
                        id: hourlyColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: root.pad
                        spacing: root.gap

                        Row {
                            width: parent.width
                            SectionHeading {
                                width: parent.width - (hourCaption.visible ? hourCaption.implicitWidth : 0)
                                text: I18n.tr("Next hours")
                            }
                            QuietLabel {
                                id: hourCaption
                                visible: root.wide
                                text: I18n.tr("Temperature · precipitation")
                            }
                        }
                        Rectangle {
                            width: parent.width
                            height: Tokens.border
                            color: Tokens.line
                        }
                        Row {
                            width: parent.width
                            Repeater {
                                model: root.shownHours
                                delegate: HourReadout {
                                    required property int index
                                    width: parent.width / root.shownHours
                                    hourData: Weather.hourly[index]
                                    divider: index < root.shownHours - 1
                                }
                            }
                        }
                    }
                }

                Flow {
                    id: detailsFlow
                    visible: !root.compact
                    width: parent.width
                    height: implicitHeight
                    spacing: root.sectionGap

                    Rectangle {
                        width: root.wide ? (detailsFlow.width - detailsFlow.spacing) * 0.48 : detailsFlow.width
                        implicitHeight: dailyColumn.implicitHeight + root.pad * 2
                        height: implicitHeight
                        radius: Tokens.radius * root.s * 1.5
                        color: Tokens.paperLift
                        border.width: Tokens.border
                        border.color: Tokens.line

                        Column {
                            id: dailyColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: root.pad
                            spacing: Tokens.s2 * root.s

                            SectionHeading {
                                width: parent.width
                                text: I18n.tr("Seven-day range")
                            }
                            QuietLabel {
                                width: parent.width
                                text: I18n.tr("Low and high temperatures")
                            }
                            Rectangle {
                                width: parent.width
                                height: Tokens.border
                                color: Tokens.line
                            }
                            Repeater {
                                model: root.shownDays
                                delegate: DailyForecastRow {
                                    required property int index
                                    width: dailyColumn.width
                                    dayData: Weather.daily[index]
                                    divider: index < root.shownDays - 1
                                }
                            }
                            QuietLabel {
                                visible: root.shownDays === 0
                                width: parent.width
                                text: I18n.tr("Daily forecast unavailable")
                            }
                        }
                    }

                    Rectangle {
                        width: root.wide ? detailsFlow.width - detailsFlow.spacing - (detailsFlow.width - detailsFlow.spacing) * 0.48 : detailsFlow.width
                        implicitHeight: atmosphereColumn.implicitHeight + root.pad * 2
                        height: implicitHeight
                        radius: Tokens.radius * root.s * 1.5
                        color: Tokens.paperLift
                        border.width: Tokens.border
                        border.color: Tokens.line

                        Column {
                            id: atmosphereColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: root.pad
                            spacing: Tokens.s2 * root.s

                            SectionHeading {
                                width: parent.width
                                text: I18n.tr("In the air")
                            }
                            QuietLabel {
                                width: parent.width
                                text: I18n.tr("Conditions at the last update")
                            }
                            Rectangle {
                                width: parent.width
                                height: Tokens.border
                                color: Tokens.line
                            }
                            Grid {
                                id: metricGrid
                                width: parent.width
                                columns: 2
                                columnSpacing: Tokens.s3 * root.s
                                rowSpacing: Tokens.s2 * root.s

                                MetricReadout {
                                    width: (metricGrid.width - metricGrid.columnSpacing) / 2
                                    glyph: "humidity_percentage"
                                    label: I18n.tr("Humidity")
                                    value: root.cur ? root.cur.humidity + "%" : ""
                                    divider: true
                                }
                                MetricReadout {
                                    width: (metricGrid.width - metricGrid.columnSpacing) / 2
                                    glyph: "air"
                                    label: I18n.tr("Wind")
                                    value: root.windText()
                                    divider: true
                                }
                                MetricReadout {
                                    width: (metricGrid.width - metricGrid.columnSpacing) / 2
                                    glyph: "rainy"
                                    label: I18n.tr("Precipitation")
                                    value: root.precipitationText()
                                    divider: true
                                }
                                MetricReadout {
                                    width: (metricGrid.width - metricGrid.columnSpacing) / 2
                                    glyph: "visibility"
                                    label: I18n.tr("Visibility")
                                    value: root.cur ? root.cur.visibility : ""
                                    divider: true
                                }
                                MetricReadout {
                                    width: (metricGrid.width - metricGrid.columnSpacing) / 2
                                    glyph: "sunny"
                                    label: I18n.tr("UV index")
                                    value: root.cur ? String(root.cur.uvIndex) : ""
                                }
                                MetricReadout {
                                    width: (metricGrid.width - metricGrid.columnSpacing) / 2
                                    glyph: "compress"
                                    label: I18n.tr("Pressure")
                                    value: root.cur ? root.cur.pressure : ""
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: !root.compact
                    width: parent.width
                    implicitHeight: skyColumn.implicitHeight + root.pad * 2
                    height: implicitHeight
                    radius: Tokens.radius * root.s * 1.5
                    color: Tokens.tint5
                    border.width: Tokens.border
                    border.color: Tokens.line

                    Column {
                        id: skyColumn
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: root.pad
                        spacing: root.gap

                        SectionHeading {
                            width: parent.width
                            text: I18n.tr("Sky and air")
                        }
                        Rectangle {
                            width: parent.width
                            height: Tokens.border
                            color: Tokens.line
                        }
                        Flow {
                            id: skyFlow
                            width: parent.width
                            spacing: root.gap

                            Item {
                                width: root.wide ? (skyFlow.width - skyFlow.spacing * 2) * 0.28 : skyFlow.width
                                implicitHeight: sunColumn.implicitHeight
                                height: implicitHeight
                                Column {
                                    id: sunColumn
                                    width: parent.width
                                    spacing: Tokens.s2 * root.s
                                    Text {
                                        text: "wb_twilight"
                                        color: Tokens.sun
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 25 * root.s
                                    }
                                    QuietLabel {
                                        width: parent.width
                                        text: I18n.tr("Daylight")
                                    }
                                    Text {
                                        width: parent.width
                                        text: root.cur
                                            ? I18n.tr("Sunrise %1\nSunset %2\n%3")
                                                .arg(root.cur.sunrise)
                                                .arg(root.cur.sunset)
                                                .arg(root.daylightDuration())
                                            : ""
                                        color: Tokens.ink
                                        font.family: Tokens.ui
                                        font.pixelSize: Tokens.fRow * root.s
                                        font.weight: Font.Medium
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }

                            Item {
                                width: root.wide ? (skyFlow.width - skyFlow.spacing * 2) * 0.30 : skyFlow.width
                                implicitHeight: moonColumn.implicitHeight
                                height: implicitHeight
                                Column {
                                    id: moonColumn
                                    width: parent.width
                                    spacing: Tokens.s2 * root.s
                                    Text {
                                        text: "dark_mode"
                                        color: Tokens.inkDim
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 25 * root.s
                                    }
                                    QuietLabel {
                                        width: parent.width
                                        text: I18n.tr("Moon")
                                    }
                                    Text {
                                        width: parent.width
                                        text: root.moonText()
                                        color: Tokens.ink
                                        font.family: Tokens.ui
                                        font.pixelSize: Tokens.fRow * root.s
                                        font.weight: Font.Medium
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }

                            Item {
                                width: root.wide ? skyFlow.width - skyFlow.spacing * 2
                                    - (skyFlow.width - skyFlow.spacing * 2) * 0.28
                                    - (skyFlow.width - skyFlow.spacing * 2) * 0.30 : skyFlow.width
                                implicitHeight: airColumn.implicitHeight
                                height: implicitHeight
                                Column {
                                    id: airColumn
                                    width: parent.width
                                    spacing: Tokens.s2 * root.s
                                    Text {
                                        text: "eco"
                                        color: root.airAvailable ? Tokens.bone : Tokens.inkMuted
                                        font.family: "Material Symbols Rounded"
                                        font.pixelSize: 25 * root.s
                                    }
                                    QuietLabel {
                                        width: parent.width
                                        text: I18n.tr("Air quality")
                                    }
                                    Text {
                                        width: parent.width
                                        text: root.airSummary()
                                        color: Tokens.ink
                                        font.family: Tokens.ui
                                        font.pixelSize: Tokens.fRow * root.s
                                        font.weight: Font.Medium
                                        wrapMode: Text.Wrap
                                    }
                                    QuietLabel {
                                        visible: root.airAvailable
                                        width: parent.width
                                        text: root.pollutantSummary()
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible: root.compact && root.shownDays > 0
                    width: parent.width
                    implicitHeight: compactDays.implicitHeight + root.pad * 2
                    height: implicitHeight
                    radius: Tokens.radius * root.s * 1.5
                    color: Tokens.tint5
                    border.width: Tokens.border
                    border.color: Tokens.line

                    Column {
                        id: compactDays
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: root.pad
                        spacing: Tokens.s2 * root.s
                        SectionHeading {
                            width: parent.width
                            text: I18n.tr("Next days")
                        }
                        Rectangle {
                            width: parent.width
                            height: Tokens.border
                            color: Tokens.line
                        }
                        Repeater {
                            model: Math.min(4, root.shownDays)
                            delegate: DailyForecastRow {
                                required property int index
                                width: compactDays.width
                                dayData: Weather.daily[index]
                                divider: index < Math.min(4, root.shownDays) - 1
                            }
                        }
                    }
                }
            }
        }
    }
}
