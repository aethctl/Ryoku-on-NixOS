pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.Ui
import Ryoku.Ui.Singletons
import shell.services
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

    implicitHeight: card.implicitHeight

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
        enabled: root.open && root.tabActive
    }

    SidebarCardShell {
        id: card
        width: root.width
        s: root.s
        index: root.index
        open: root.open
        reveal: root.reveal
        tabActive: root.tabActive
        compact: root.compact
        title: I18n.tr("Screen time")
        glyph: "monitor_heart"
        eyebrow: Qt.formatDate(clock.date, "ddd, MMM d")

        Column {
            width: parent.width
            spacing: (root.compact ? Tokens.s3 : Tokens.s5) * root.s

            Item {
                width: parent.width
                height: Math.max(activeLabel.implicitHeight, activeValue.implicitHeight)

                Text {
                    id: activeLabel
                    anchors.left: parent.left
                    anchors.right: activeValue.left
                    anchors.rightMargin: Tokens.s3 * root.s
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("Active today")
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall * root.s
                    font.weight: Font.Medium
                    elide: Text.ElideRight
                }

                Text {
                    id: activeValue
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: ScreenTime.fmtDuration(ScreenTime.activeToday)
                    color: Tokens.ink
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fBody * root.s
                    font.weight: Font.DemiBold
                    font.features: ({ "tnum": 1 })
                }
            }

            Column {
                visible: !root.compact
                width: parent.width
                spacing: Tokens.s3 * root.s

                Text {
                    width: parent.width
                    text: I18n.tr("This week")
                    color: Tokens.ink
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall * root.s
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Item {
                    width: parent.width
                    height: 104 * root.s

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: weekRow.bottom
                        anchors.bottomMargin: 22 * root.s
                        height: Tokens.border
                        color: Tokens.lineSoft
                    }

                    Row {
                        id: weekRow
                        anchors.fill: parent
                        spacing: 0
                        readonly property real cellW: width / 7
                        readonly property real maxBarH: height - 30 * root.s

                        Repeater {
                            model: ScreenTime.weekly

                            delegate: Item {
                                id: day
                                required property var modelData
                                width: weekRow.cellW
                                height: weekRow.height

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.bottom: dayLabel.top
                                    anchors.bottomMargin: Tokens.s2 * root.s
                                    width: Math.max(4 * root.s, Math.min(7 * root.s, day.width * 0.26))
                                    height: day.modelData.total > 0
                                        ? Math.max(3 * root.s, weekRow.maxBarH * day.modelData.total / Math.max(1, ScreenTime.weeklyMax))
                                        : 0
                                    radius: width / 2
                                    color: day.modelData.isToday ? Tokens.bone : Tokens.inkMuted
                                    opacity: day.modelData.isToday ? 1 : 0.52

                                    Behavior on height {
                                        enabled: root.motionAllowed
                                        NumberAnimation {
                                            duration: Tokens.move
                                            easing.type: Tokens.ease
                                        }
                                    }
                                }

                                Text {
                                    id: dayLabel
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.bottom: parent.bottom
                                    height: 14 * root.s
                                    verticalAlignment: Text.AlignVCenter
                                    text: I18n.tr(day.modelData.label)
                                    horizontalAlignment: Text.AlignHCenter
                                    elide: Text.ElideRight
                                    color: day.modelData.isToday ? Tokens.bone : Tokens.inkMuted
                                    font.family: Tokens.ui
                                    font.pixelSize: Tokens.fSmall * root.s
                                    font.weight: day.modelData.isToday ? Font.DemiBold : Font.Normal
                                }
                            }
                        }
                    }
                }
            }

            Column {
                width: parent.width
                spacing: Tokens.s2 * root.s

                Text {
                    width: parent.width
                    text: I18n.tr("Most used")
                    color: Tokens.ink
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall * root.s
                    font.weight: Font.DemiBold
                    elide: Text.ElideRight
                }

                Column {
                    width: parent.width
                    spacing: 0

                    Text {
                        width: parent.width
                        visible: ScreenTime.topApps.length === 0
                        text: I18n.tr("Nothing tracked yet. Usage builds as you work.")
                        wrapMode: Text.WordWrap
                        color: Tokens.inkMuted
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall * root.s
                    }

                    Repeater {
                        model: root.compact ? ScreenTime.topApps.slice(0, 3) : ScreenTime.topApps

                        delegate: Item {
                            id: appRow
                            required property var modelData
                            required property int index
                            width: parent.width
                            height: (root.compact ? 46 : 54) * root.s
                            readonly property real usageRatio: Math.max(0, Math.min(1,
                                modelData.seconds / Math.max(1, ScreenTime.topSeconds)))

                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.top: parent.top
                                height: Tokens.border
                                visible: appRow.index > 0
                                color: Tokens.lineSoft
                            }

                            Image {
                                id: appIcon
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24 * root.s
                                height: width
                                visible: appRow.modelData.icon !== ""
                                source: appRow.modelData.icon
                                sourceSize.width: width * 2
                                sourceSize.height: height * 2
                                smooth: true
                            }

                            Rectangle {
                                anchors.fill: appIcon
                                visible: appRow.modelData.icon === ""
                                radius: Tokens.radius * root.s
                                color: Tokens.tint10

                                Text {
                                    anchors.centerIn: parent
                                    text: String(appRow.modelData.name).charAt(0).toUpperCase()
                                    color: Tokens.inkDim
                                    font.family: Tokens.ui
                                    font.pixelSize: Tokens.fSmall * root.s
                                    font.weight: Font.Medium
                                }
                            }

                            Text {
                                id: appName
                                anchors.left: appIcon.right
                                anchors.right: appTime.left
                                anchors.leftMargin: Tokens.s3 * root.s
                                anchors.rightMargin: Tokens.s2 * root.s
                                anchors.top: parent.top
                                anchors.topMargin: 9 * root.s
                                text: appRow.modelData.name
                                elide: Text.ElideMiddle
                                color: Tokens.ink
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fSmall * root.s
                                font.weight: Font.Medium
                            }

                            Text {
                                id: appTime
                                anchors.right: parent.right
                                anchors.baseline: appName.baseline
                                text: ScreenTime.fmtDuration(appRow.modelData.seconds)
                                color: Tokens.inkMuted
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fSmall * root.s
                                font.features: ({ "tnum": 1 })
                            }

                            Rectangle {
                                anchors.left: appName.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.bottomMargin: 9 * root.s
                                height: 2 * root.s
                                radius: height / 2
                                color: Tokens.lineSoft

                                Rectangle {
                                    width: parent.width * appRow.usageRatio
                                    height: parent.height
                                    radius: parent.radius
                                    color: Tokens.inkMuted

                                    Behavior on width {
                                        enabled: root.motionAllowed
                                        NumberAnimation {
                                            duration: Tokens.move
                                            easing.type: Tokens.ease
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
