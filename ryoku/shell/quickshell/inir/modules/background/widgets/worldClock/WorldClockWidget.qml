pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import inir.services
import inir.modules.common
import inir.modules.common.functions
import inir.modules.common.widgets
import inir.modules.background.widgets
import inir.modules.iris.widgets

AbstractBackgroundWidget {
    id: root

    configEntryName: "worldClock"
    defaultConfig: ({
            placementStrategy: "free",
            contentWidth: 300,
            contentHeight: 210,
            widgetScale: 100,
            widgetOpacity: 100,
            colorMode: "auto",
            dim: 0,
            showBackground: true,
            showBorder: true,
            backgroundOpacity: 0.16,
            borderWidth: 1,
            borderOpacity: 0.2,
            cornerRadius: -1,
            useBlur: false,
            style: "cards",
            instrumentLayout: "grid",
            showNames: true,
            showOffsets: true,
            showDate: true,
            showDayState: true,
            pulseSeparator: false,
            timezones: ["Asia/Tokyo", "Europe/London", "America/New_York"],
            x: 80,
            y: 200
        })

    readonly property int listWidth: Math.round(Number(root._readConfigKey("contentWidth") ?? 300) * scaleFactor)
    readonly property int listHeight: Math.round(Number(root._readConfigKey("contentHeight") ?? 210) * scaleFactor)
    implicitWidth: root.irisFaced ? root.irisFaceWidth : root.listWidth
    implicitHeight: root.irisFaced ? root.irisFaceHeight : root.instrument
        ? Math.max(root.listHeight, root.instrumentHeightTarget)
        : root.listHeight
    irisFace: Component { IrisWorldClockFace { widget: root } }
    irisSizes: ["small", "medium", "large"]
    irisDefaultSize: "medium"
    irisOptions: [
        { key: "showNames", raw: true, label: Translation.tr("City names"), icon: "label", fallback: true },
        { key: "showOffsets", raw: true, label: Translation.tr("Time difference"), icon: "schedule", fallback: true }
    ]
    resizableAxes: ({
            width: "contentWidth",
            height: "contentHeight"
        })
    resizeMinWidth: 240
    resizeMinHeight: root.instrument ? root.instrumentHeightTarget : 170
    needsColText: true
    widgetSurfaceEnabled: !root.instrument

    readonly property color surfaceInk: root.widgetInk
    readonly property string localCity: Weather.visibleCity
    readonly property var cities: WorldClock.entries
    readonly property bool instrument: String(root._readConfigKey("style") ?? "cards") === "instrument"
    readonly property string instrumentLayout: String(root._readConfigKey("instrumentLayout") ?? "grid")
    readonly property bool showNames: Boolean(root._readConfigKey("showNames") ?? true)
    readonly property bool showOffsets: Boolean(root._readConfigKey("showOffsets") ?? true)
    readonly property bool showDate: Boolean(root._readConfigKey("showDate") ?? true)
    readonly property bool showDayState: Boolean(root._readConfigKey("showDayState") ?? true)
    readonly property bool pulseSeparator: Boolean(root._readConfigKey("pulseSeparator") ?? false)
    readonly property int instrumentHeightTarget: {
        const headerHeight = Math.round(26 * root.scaleFactor)
        const count = Math.max(1, root.cities.length)
        if (root.instrumentLayout === "rows")
            return headerHeight + Math.round(count * 52 * root.scaleFactor)
        const heroHeight = Math.round(94 * root.scaleFactor)
        const comparisonHeight = Math.round(Math.max(0, count - 1) * 48 * root.scaleFactor)
        return headerHeight + heroHeight + comparisonHeight
    }

    function cityDayDelta(index: int): int {
        const cityDate = WorldClock.cityDisplayDate(index)
        if (!cityDate)
            return 0
        return Math.round((
            Date.UTC(cityDate.getFullYear(), cityDate.getMonth(), cityDate.getDate())
            - Date.UTC(WorldClock.now.getFullYear(), WorldClock.now.getMonth(), WorldClock.now.getDate())
        ) / 86400000)
    }

    function cityDateText(index: int): string {
        const cityDate = WorldClock.cityDisplayDate(index)
        return cityDate ? root.widgetCase(Qt.locale().toString(cityDate, "ddd d MMM")) : ""
    }

    editPopoverContent: Component {
        ColumnLayout {
            property var availableTimezones: WorldClock.comboModel.filter(
                entry => !WorldClock.timezones.includes(entry.tz))
            spacing: 6

            RowLayout {
                spacing: 4
                Layout.alignment: Qt.AlignHCenter

                Repeater {
                    model: [
                        { label: Translation.tr("List"), icon: "view_list", value: "cards" },
                        { label: Translation.tr("Instrument"), icon: "avg_pace", value: "instrument" }
                    ]
                    WidgetChoiceButton {
                        required property var modelData
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: root.instrument === (modelData.value === "instrument")
                        onClicked: root._setOutputValue("style", modelData.value)
                    }
                }
            }

            RowLayout {
                spacing: 4
                Layout.alignment: Qt.AlignHCenter
                visible: root.instrument

                Repeater {
                    model: [
                        { label: Translation.tr("Atlas"), icon: "travel_explore", value: "grid" },
                        { label: Translation.tr("Strip"), icon: "view_agenda", value: "rows" }
                    ]
                    WidgetChoiceButton {
                        required property var modelData
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: root.instrumentLayout === modelData.value
                        onClicked: root._setOutputValue("instrumentLayout", modelData.value)
                    }
                }
            }

            GridLayout {
                columns: 3
                columnSpacing: 4
                rowSpacing: 4
                Layout.alignment: Qt.AlignHCenter
                visible: root.instrument

                Repeater {
                    model: [
                        { label: Translation.tr("Offsets"), icon: "schedule", key: "showOffsets", fallback: true },
                        { label: Translation.tr("Date"), icon: "calendar_today", key: "showDate", fallback: true },
                        { label: Translation.tr("Day/Night"), icon: "routine", key: "showDayState", fallback: true }
                    ]
                    WidgetChoiceButton {
                        required property var modelData
                        Layout.fillWidth: true
                        leftmost: true; rightmost: true
                        buttonIcon: modelData.icon
                        buttonText: modelData.label
                        toggled: Boolean(root._readConfigKey(modelData.key) ?? modelData.fallback)
                        onClicked: root._setOutputValue(modelData.key, !toggled)
                    }
                }
            }

            Repeater {
                model: WorldClock.timezones.length
                delegate: RowLayout {
                    required property int index
                    Layout.fillWidth: true
                    spacing: 6

                    StyledText {
                        text: Translation.tr("City %1").arg(index + 1)
                        font.pixelSize: Appearance.font.pixelSize.smaller
                    }

                    StyledComboBox {
                        Layout.fillWidth: true
                        model: WorldClock.comboModel
                        textRole: "label"
                        currentIndex: Math.max(0, WorldClock.comboModel.findIndex(o => o.tz === WorldClock.timezones[index]))
                        onActivated: idx => WorldClock.setTimezone(index, WorldClock.comboModel[idx].tz)
                    }

                    RippleButton {
                        Layout.preferredWidth: 30
                        Layout.preferredHeight: 30
                        enabled: WorldClock.timezones.length > 1
                        opacity: enabled ? 1 : 0.32
                        buttonRadius: root.widgetControlRadius
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.applyAlpha(root.widgetInk, 0.10)
                        colRipple: ColorUtils.applyAlpha(root.widgetInk, 0.16)
                        releaseAction: () => WorldClock.removeTimezone(index)
                        contentItem: MaterialSymbol {
                            anchors.centerIn: parent
                            text: "close"
                            color: root.widgetInkMuted
                            iconSize: 16
                        }
                        StyledToolTip { text: Translation.tr("Remove city") }
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                visible: WorldClock.timezones.length < WorldClock.maxTimezones
                    && parent.availableTimezones.length > 0

                StyledComboBox {
                    id: addTimezoneCombo
                    Layout.fillWidth: true
                    model: parent.parent.availableTimezones
                    textRole: "label"
                }
                RippleButton {
                    Layout.preferredWidth: 32
                    Layout.preferredHeight: 30
                    buttonRadius: root.widgetControlRadius
                    colBackground: ColorUtils.applyAlpha(root.widgetAccentVisible, 0.12)
                    colBackgroundHover: ColorUtils.applyAlpha(root.widgetAccentVisible, 0.20)
                    colRipple: ColorUtils.applyAlpha(root.widgetAccentVisible, 0.28)
                    releaseAction: () => {
                        const entry = parent.parent.availableTimezones[addTimezoneCombo.currentIndex]
                        if (entry)
                            WorldClock.addTimezone(entry.tz)
                    }
                    contentItem: MaterialSymbol {
                        anchors.centerIn: parent
                        text: "add"
                        color: root.widgetAccentVisible
                        iconSize: 17
                    }
                    StyledToolTip { text: Translation.tr("Add city") }
                }
            }
        }
    }

    WidgetSurface {
        irisPresentation: root.widgetIris
        regionBrightness: root.regionBrightness
        anchors.fill: parent
        surfaceRadius: root.cornerRadiusOverride >= 0 ? root.cornerRadiusOverride : root.widgetCardRadius
        surfaceOpacity: root.backgroundOpacity
        surfaceBorderWidth: root.borderWidth
        surfaceBorderOpacity: root.borderOpacity
        surfaceColor: root.surfaceInk
        colorMode: root.colorMode
        surfaceAccent: root.widgetAccent3
        surfaceFill: root.widgetPlateColor
        surfaceUseBlur: root.effectiveBlur
        screenX: root.x
        screenY: root.y
        screenWidth: root.scaledScreenWidth
        screenHeight: root.scaledScreenHeight
        shown: !root.irisFaced && !root.instrument
            && (root.backgroundOpacity > 0 || root.borderWidth > 0 || root.effectiveBlur)
    }

    // ── Instrument: world-time atlas ────────────────────────
    // The first zone is the reference city. Additional zones are comparisons,
    // not cloned cards: hierarchy communicates what the user is comparing.
    ColumnLayout {
        anchors.fill: parent
        opacity: root.instrument ? 1 : 0
        visible: !root.irisFaced && opacity > 0
        enabled: root.instrument
        spacing: Math.round(5 * root.scaleFactor)

        Behavior on opacity {
            enabled: root.animationsActive
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(20, Math.round(24 * root.scaleFactor))
            spacing: Math.round(7 * root.scaleFactor)

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("World time")
                color: root.widgetInk
                font.family: root.widgetTitleFamily
                font.pixelSize: Math.max(15, Math.round(17 * root.widgetTitleScale * root.scaleFactor))
                font.weight: root.widgetTitleWeight
                font.letterSpacing: root.widgetTitleTracking
            }
            StyledText {
                visible: root.cities.length > 1
                text: Translation.tr("%1 zones").arg(root.cities.length)
                color: root.widgetInkMuted
                font.family: root.widgetBodyFamily
                font.pixelSize: Math.max(10, Math.round(10 * root.scaleFactor))
                font.weight: Font.Medium
                font.letterSpacing: root.widgetMetadataTracking
                font.capitalization: root.widgetIris ? Font.MixedCase : Font.AllUppercase
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.instrumentLayout === "grid"
            spacing: Math.round(4 * root.scaleFactor)

            Item {
                id: referenceZone
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredHeight: root.cities.length > 1
                    ? Math.max(78, Math.round(92 * root.scaleFactor))
                    : Math.max(118, Math.round(132 * root.scaleFactor))
                readonly property var modelData: root.cities.length > 0 ? root.cities[0] : null
                readonly property int dayDelta: root.cityDayDelta(0)
                readonly property color accent: root.widgetAccentVisible

                ColumnLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Math.round(6 * root.scaleFactor)
                    anchors.rightMargin: anchors.leftMargin
                    spacing: Math.round(2 * root.scaleFactor)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Math.round(6 * root.scaleFactor)

                        Rectangle {
                            id: referenceMark
                            Layout.preferredWidth: Math.max(2, Math.round(3 * root.scaleFactor))
                            Layout.preferredHeight: Math.round(14 * root.scaleFactor)
                            radius: height / 2
                            color: referenceZone.accent
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: referenceZone.modelData
                            text: referenceZone.modelData ? root.widgetCase(String(referenceZone.modelData.name)) : ""
                            color: root.widgetInkMuted
                            elide: Text.ElideRight
                            font.family: root.widgetBodyFamily
                            font.pixelSize: Math.max(9, Math.round(10 * root.scaleFactor))
                            font.weight: root.widgetLabelWeight
                            font.letterSpacing: root.widgetMetadataTracking
                            font.capitalization: root.widgetIris ? Font.MixedCase : Font.AllUppercase
                        }
                        StyledText {
                            visible: root.showOffsets && referenceZone.modelData
                            text: referenceZone.modelData ? referenceZone.modelData.offset : ""
                            color: root.widgetInkMuted
                            font.family: root.widgetNumbersFamily
                            font.pixelSize: Math.max(8, Math.round(9 * root.scaleFactor))
                            font.weight: Font.Medium
                            font.features: ({ "tnum": 1 })
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        verticalAlignment: Text.AlignVCenter
                        text: referenceZone.modelData ? referenceZone.modelData.time : "--:--"
                        color: root.widgetInk
                        fontSizeMode: Text.Fit
                        minimumPixelSize: Math.max(26, Math.round(26 * root.scaleFactor))
                        font.family: root.widgetNumbersFamily
                        font.pixelSize: Math.round(48 * root.scaleFactor)
                        font.weight: root.widgetEditorial ? Appearance.editorial.titleWeight : Font.Bold
                        font.features: ({ "tnum": 1 })
                        font.letterSpacing: -1
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        visible: root.showDate || root.showDayState
                        spacing: Math.round(5 * root.scaleFactor)

                        MaterialSymbol {
                            visible: root.showDayState && referenceZone.modelData
                            text: referenceZone.modelData && referenceZone.modelData.isDay ? "light_mode" : "bedtime"
                            color: referenceZone.accent
                            iconSize: Math.max(10, Math.round(11 * root.scaleFactor))
                        }
                        StyledText {
                            visible: root.showDate && referenceZone.dayDelta !== 0
                            text: (referenceZone.dayDelta > 0 ? "+" : "") + referenceZone.dayDelta + "D"
                            color: referenceZone.accent
                            font.family: root.widgetNumbersFamily
                            font.pixelSize: Math.max(8, Math.round(9 * root.scaleFactor))
                            font.weight: Font.Bold
                        }
                        StyledText {
                            Layout.fillWidth: true
                            visible: root.showDate
                            text: root.cityDateText(0)
                            color: root.widgetInkMuted
                            font.family: root.widgetBodyFamily
                            font.pixelSize: Math.max(8, Math.round(9 * root.scaleFactor))
                            font.weight: Font.Medium
                            font.letterSpacing: root.widgetMetadataTracking
                            font.capitalization: root.widgetIris ? Font.MixedCase : Font.AllUppercase
                        }
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                visible: root.cities.length > 1
                spacing: 0

                Repeater {
                    model: Math.max(0, root.cities.length - 1)

                    Item {
                        id: comparisonZone
                        required property int index
                        readonly property int cityIndex: index + 1
                        readonly property var modelData: root.cities[cityIndex]
                        readonly property int dayDelta: root.cityDayDelta(cityIndex)
                        readonly property string role: cityIndex % 2 === 0
                            ? root.widgetTertiaryRole : root.widgetSecondaryRole
                        readonly property color accent: root.widgetSemanticForeground(role)

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        Layout.minimumHeight: Math.max(42, Math.round(46 * root.scaleFactor))

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: Math.round(6 * root.scaleFactor)
                            anchors.rightMargin: anchors.leftMargin
                            spacing: Math.round(6 * root.scaleFactor)

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: -1
                                StyledText {
                                    Layout.fillWidth: true
                                    visible: true
                                    text: String(comparisonZone.modelData.name)
                                    color: root.widgetInk
                                    elide: Text.ElideRight
                                    font.family: root.widgetBodyFamily
                                    font.pixelSize: Math.max(11, Math.round(11 * root.scaleFactor))
                                    font.weight: root.widgetLabelWeight
                                    font.letterSpacing: root.widgetMetadataTracking
                                    font.capitalization: root.widgetIris ? Font.MixedCase : Font.AllUppercase
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: root.showDate || root.showOffsets
                                    spacing: Math.round(4 * root.scaleFactor)
                                    StyledText {
                                        visible: root.showDate && comparisonZone.dayDelta !== 0
                                        text: (comparisonZone.dayDelta > 0 ? "+" : "") + comparisonZone.dayDelta + "D"
                                        color: comparisonZone.accent
                                        font.family: root.widgetNumbersFamily
                                        font.pixelSize: Math.max(7, Math.round(8 * root.scaleFactor))
                                        font.weight: Font.Bold
                                    }
                                    StyledText {
                                        Layout.fillWidth: true
                                        visible: root.showDate
                                        text: root.cityDateText(comparisonZone.cityIndex)
                                        color: root.widgetInkMuted
                                        elide: Text.ElideRight
                                        font.family: root.widgetBodyFamily
                                        font.pixelSize: Math.max(10, Math.round(10 * root.scaleFactor))
                                        font.weight: Font.Medium
                                        font.letterSpacing: root.widgetMetadataTracking
                                        font.capitalization: root.widgetIris ? Font.MixedCase : Font.AllUppercase
                                    }
                                    StyledText {
                                        visible: root.showOffsets
                                        text: comparisonZone.modelData.offset
                                        color: root.widgetInkMuted
                                        font.family: root.widgetNumbersFamily
                                        font.pixelSize: Math.max(10, Math.round(10 * root.scaleFactor))
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                            MaterialSymbol {
                                visible: root.showDayState
                                text: comparisonZone.modelData.isDay ? "light_mode" : "bedtime"
                                color: comparisonZone.accent
                                iconSize: Math.max(9, Math.round(10 * root.scaleFactor))
                            }
                            StyledText {
                                text: comparisonZone.modelData.time
                                color: root.widgetInk
                                font.family: root.widgetNumbersFamily
                                font.pixelSize: Math.max(20, Math.round(24 * root.scaleFactor))
                                font.weight: root.widgetEditorial ? Appearance.editorial.titleWeight : Font.DemiBold
                                font.features: ({ "tnum": 1 })
                                font.letterSpacing: -0.6
                            }
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.instrumentLayout === "rows"
            spacing: 0

            Repeater {
                model: root.cities.length

                Item {
                    id: ledgerZone
                    required property int index
                    readonly property var modelData: root.cities[index]
                    readonly property int dayDelta: root.cityDayDelta(index)
                    readonly property string role: index === 0 ? root.widgetPrimaryRole
                        : index % 2 === 0 ? root.widgetTertiaryRole : root.widgetSecondaryRole
                    readonly property color accent: root.widgetSemanticForeground(role)

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: Math.max(40, Math.round(44 * root.scaleFactor))

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Math.round(5 * root.scaleFactor)
                        anchors.rightMargin: anchors.leftMargin
                        spacing: Math.round(7 * root.scaleFactor)

                        Rectangle {
                            Layout.preferredWidth: index === 0
                                ? Math.max(18, Math.round(24 * root.scaleFactor))
                                : Math.max(10, Math.round(14 * root.scaleFactor))
                            Layout.preferredHeight: Math.max(2, Math.round(2 * root.scaleFactor))
                            radius: height / 2
                            color: ledgerZone.accent
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -1
                            StyledText {
                                Layout.fillWidth: true
                                visible: true
                                text: root.widgetCase(String(ledgerZone.modelData.name))
                                color: index === 0 ? root.widgetInk : root.widgetInkMuted
                                elide: Text.ElideRight
                                font.family: root.widgetBodyFamily
                                font.pixelSize: Math.max(8, Math.round(9 * root.scaleFactor))
                                font.weight: index === 0 ? root.widgetLabelWeight : Font.Medium
                                font.letterSpacing: root.widgetMetadataTracking
                                font.capitalization: root.widgetIris ? Font.MixedCase : Font.AllUppercase
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                visible: root.showDate || root.showOffsets
                                spacing: Math.round(4 * root.scaleFactor)
                                StyledText {
                                    visible: root.showDate && ledgerZone.dayDelta !== 0
                                    text: (ledgerZone.dayDelta > 0 ? "+" : "") + ledgerZone.dayDelta + "D"
                                    color: ledgerZone.accent
                                    font.family: root.widgetNumbersFamily
                                    font.pixelSize: Math.max(7, Math.round(8 * root.scaleFactor))
                                    font.weight: Font.Bold
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    visible: root.showDate
                                    text: root.cityDateText(index)
                                    color: root.widgetInkMuted
                                    elide: Text.ElideRight
                                    font.family: root.widgetBodyFamily
                                    font.pixelSize: Math.max(7, Math.round(8 * root.scaleFactor))
                                    font.weight: Font.Medium
                                    font.letterSpacing: root.widgetMetadataTracking
                                    font.capitalization: root.widgetIris ? Font.MixedCase : Font.AllUppercase
                                }
                                StyledText {
                                    visible: root.showOffsets
                                    text: ledgerZone.modelData.offset
                                    color: root.widgetInkMuted
                                    font.family: root.widgetNumbersFamily
                                    font.pixelSize: Math.max(7, Math.round(8 * root.scaleFactor))
                                    font.weight: Font.Medium
                                }
                            }
                        }
                        MaterialSymbol {
                            visible: root.showDayState
                            text: ledgerZone.modelData.isDay ? "light_mode" : "bedtime"
                            color: ledgerZone.accent
                            iconSize: Math.max(9, Math.round(10 * root.scaleFactor))
                        }
                        StyledText {
                            text: ledgerZone.modelData.time
                            color: root.widgetInk
                            font.family: root.widgetNumbersFamily
                            font.pixelSize: index === 0
                                ? Math.max(22, Math.round(27 * root.scaleFactor))
                                : Math.max(20, Math.round(24 * root.scaleFactor))
                            font.weight: index === 0 && root.widgetEditorial
                                ? Appearance.editorial.titleWeight : Font.DemiBold
                            font.features: ({ "tnum": 1 })
                            font.letterSpacing: -0.6
                        }
                    }
                }
            }
        }
    }
    ColumnLayout {
        opacity: root.instrument ? 0 : 1
        visible: !root.irisFaced && opacity > 0
        enabled: !root.instrument
        Behavior on opacity {
            enabled: root.animationsActive
            NumberAnimation { duration: Appearance.animation.elementMoveFast.duration }
        }
        anchors.fill: parent
        anchors.margins: Math.round(14 * root.scaleFactor)
        spacing: Math.round(8 * root.scaleFactor)

        Rectangle {
            Layout.alignment: Qt.AlignLeft
            visible: Weather.showVisibleCity
            implicitWidth: localChip.implicitWidth + Math.round(18 * root.scaleFactor)
            implicitHeight: localChip.implicitHeight + Math.round(8 * root.scaleFactor)
            radius: root.widgetEditorial ? root.widgetControlRadius : height / 2
            color: root.widgetSemanticContainer(root.widgetPrimaryRole)

            RowLayout {
                id: localChip
                anchors.centerIn: parent
                spacing: Math.round(5 * root.scaleFactor)

                MaterialSymbol {
                    text: "place"
                    fill: 1
                    iconSize: Math.round(Appearance.font.pixelSize.small * root.scaleFactor)
                    color: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
                }

                StyledText {
                    text: root.localCity || Translation.tr("Local")
                    elide: Text.ElideRight
                    color: root.widgetSemanticOnContainer(root.widgetPrimaryRole)
                    font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
                    font.weight: root.widgetLabelWeight
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: DateTime.time || "--:--"
            color: root.surfaceInk
            elide: Text.ElideRight
            font {
                family: root.widgetNumbersFamily
                pixelSize: Math.round(Appearance.font.pixelSize.huge * root.scaleFactor)
                weight: Font.DemiBold
            }
        }

        StyledText {
            Layout.fillWidth: true
            text: Qt.locale().toString(WorldClock.now, "dddd, MMMM d yyyy")
            color: ColorUtils.applyAlpha(root.surfaceInk, 0.6)
            elide: Text.ElideRight
            font.pixelSize: Math.round(Appearance.font.pixelSize.smaller * root.scaleFactor)
        }

        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            columnSpacing: Math.round(6 * root.scaleFactor)
            rowSpacing: Math.round(6 * root.scaleFactor)

            Repeater {
                model: root.cities

                delegate: Rectangle {
                    id: cityCell
                    required property var modelData
                    required property int index
                    readonly property bool alternate: (index % 2) === (Math.floor(index / 2) % 2)
                    readonly property string cellRole: cityCell.alternate
                        ? root.widgetSecondaryRole : root.widgetTertiaryRole
                    readonly property color cellColor: root.widgetSemanticContainer(cityCell.cellRole)
                    readonly property color cellInk: root.widgetSemanticOnContainer(cityCell.cellRole)
                    readonly property color cellAccent: root.widgetSemanticColor(cityCell.cellRole)

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: Math.round(44 * root.scaleFactor)
                    radius: root.widgetCardRadius * 0.72
                    color: cityCell.cellColor

                    Behavior on color {
                        enabled: Appearance.animationsEnabled
                        ColorAnimation {
                            duration: Appearance.animation.elementMoveFast.duration
                            easing.type: Appearance.animation.elementMoveFast.type
                            easing.bezierCurve: Appearance.animation.elementMoveFast.bezierCurve
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: Math.round(8 * root.scaleFactor)
                        spacing: Math.round(6 * root.scaleFactor)

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: -Math.round(2 * root.scaleFactor)

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: Math.round(4 * root.scaleFactor)

                                StyledText {
                                    Layout.fillWidth: true
                                    text: cityCell.modelData.name
                                    elide: Text.ElideRight
                                    color: ColorUtils.applyAlpha(cityCell.cellInk, 0.7)
                                    font.pixelSize: Math.round(Appearance.font.pixelSize.smallest * root.scaleFactor)
                                }

                                StyledText {
                                    text: cityCell.modelData.offset
                                    color: ColorUtils.applyAlpha(cityCell.cellInk, 0.5)
                                    font.pixelSize: Math.round(Appearance.font.pixelSize.smallest * root.scaleFactor)
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: cityCell.modelData.time
                                elide: Text.ElideRight
                                color: cityCell.cellInk
                                font {
                                    family: root.widgetNumbersFamily
                                    pixelSize: Math.round(Appearance.font.pixelSize.large * root.scaleFactor)
                                    weight: Font.Bold
                                }
                            }
                        }

                        MaterialShape {
                            Layout.alignment: Qt.AlignVCenter
                            visible: cityCell.height >= Math.round(46 * root.scaleFactor)
                            implicitSize: Math.round(24 * root.scaleFactor)
                            shape: cityCell.modelData.isDay
                                ? MaterialShape.Shape.Sunny
                                : MaterialShape.Shape.ClamShell
                            color: ColorUtils.applyAlpha(cityCell.cellAccent, 0.9)

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: cityCell.modelData.isDay ? "light_mode" : "dark_mode"
                                fill: 1
                                iconSize: Math.round(13 * root.scaleFactor)
                                color: root.widgetSemanticOnColor(cityCell.cellRole)
                            }
                        }
                    }
                }
            }
        }
    }
}
