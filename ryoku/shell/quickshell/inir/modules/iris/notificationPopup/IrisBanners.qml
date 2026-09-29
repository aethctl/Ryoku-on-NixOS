pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import inir
import inir.services
import inir.modules.common
import inir.modules.common.functions
import inir.modules.common.widgets
import inir.modules.iris.frame
import inir.modules.iris.style
import inir.modules.iris.components

Item {
    id: root
    property var screenData: null
    readonly property string screenName: root.screenData?.name ?? ""
    readonly property bool fullscreenHere: CompositorService.nativeOverview && GameMode.hasFullscreenOnOutput(root.screenName) && !WorkspaceService.inOverview
    readonly property bool present: root.screenName === (GlobalStates.focusedScreen?.name ?? "") && !root.fullscreenHere
        && (root.popups.length > 0 || exitLinger.running)
    readonly property var hitRect: root.present && popupColumn.contentHeight > 0
        ? { x: popupColumn.x, y: popupColumn.y, width: popupColumn.width, height: popupColumn.height } : null
    readonly property var options: Config.options?.iris?.notifications ?? ({})
    readonly property var barOptions: Config.options?.iris?.bar ?? ({})
    readonly property string islandEdge: IrisFrame.islandEdge
    readonly property bool barTop: root.islandEdge !== "bottom"
    readonly property bool islandSide: root.islandEdge === "left" || root.islandEdge === "right"
    readonly property real sideGap: IrisFrame.clear(root.islandEdge) + Math.round(12 * root.d)
    readonly property var popups: (Notifications.popupList ?? []).slice(-3).reverse()
    readonly property real d: IrisStyle.density
    readonly property real edgeOffset: (Number(root.barOptions?.height ?? 42)
        + ((root.barOptions?.notch ?? false) ? 0 : Number(root.barOptions?.margin ?? 8) * 2) + 10) * root.d

    visible: root.present
    onPopupsChanged: if (root.popups.length === 0) exitLinger.restart()
    Timer { id: exitLinger; interval: IrisStyle.settleDuration * 2 + 80 }
    readonly property real popupWidth: Math.min(Math.max(260, root.width - 2 * IrisFrame.band - 16),
        Math.max(340, Number(root.options?.width ?? 380) * root.d) + 16)
    readonly property var island: GlobalStates.irisIslandGeometry?.[root.screenName] ?? null
    readonly property real bubbleSize: Math.round(44 * root.d)

    property real now: Date.now()
    Timer { interval: 30000; repeat: true; running: root.visible; onTriggered: root.now = Date.now() }

    function activate(notification): void {
        const actions = notification?.actions ?? []
        const preferred = actions.find(action => action.identifier === "default")
        if (preferred) {
            Notifications.attemptInvokeAction(notification.notificationId, preferred.identifier)
            return
        }
        const key = String(notification?.appName ?? "").toLowerCase()
        if (key.length > 0 && CompositorService.nativeOverview) {
            const window = (WorkspaceService.windows ?? []).find(w => String(w.app_id ?? "").toLowerCase().includes(key))
            if (window) WorkspaceService.focusWindow(window.id)
        }
        Notifications.timeoutNotification(notification.notificationId)
    }

    ListView {
        id: popupColumn
        x: Math.round(root.islandEdge === "left" ? root.sideGap
            : root.islandEdge === "right" ? parent.width - width - root.sideGap : (parent.width - width) / 2)
        y: Math.round(root.islandSide ? IrisFrame.inset("top") + Math.round(12 * root.d)
            : root.barTop ? root.edgeOffset + IrisFrame.band
            : parent.height - height - root.edgeOffset - IrisFrame.band)
        verticalLayoutDirection: root.barTop ? ListView.TopToBottom : ListView.BottomToTop
        width: Math.min(root.popupWidth - 16, parent.width - 16)
        height: Math.max(1, popupColumn.contentHeight)
        spacing: 8 * root.d
        interactive: false
        model: ScriptModel {
            objectProp: "notificationId"
            values: root.popups
        }
        delegate: bannerComponent
        remove: Transition {
            NumberAnimation {
                property: "leave"
                from: 0
                to: 1
                duration: IrisStyle.recedeDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: IrisStyle.recedeCurve
            }
        }
        displaced: Transition {
            NumberAnimation { property: "y"; duration: IrisStyle.morphDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.morphCurve }
        }
    }

    Component {
        id: bannerComponent

        Item {
            id: banner
            required property var modelData
            readonly property var notification: banner.modelData
            readonly property var actions: (banner.notification?.actions ?? []).filter(action => action.identifier !== "default")
            readonly property bool critical: String(banner.notification?.urgency ?? "") === "critical"
            readonly property bool hovered: bannerHover.hovered
            width: popupColumn.width
            height: plate.height

            onHoveredChanged: if (banner.hovered) Notifications.cancelTimeout(banner.notification.notificationId)
            HoverHandler { id: bannerHover }

            property real appear: 0
            Component.onCompleted: banner.appear = 1
            Behavior on appear { NumberAnimation { duration: IrisStyle.emergeDuration; easing.type: Easing.BezierSpline; easing.bezierCurve: IrisStyle.emergeCurve } }
            property real leave: 0
            readonly property bool swiped: Math.abs(banner.swipe) > 1
            readonly property real bloom: Math.min(banner.appear, banner.swiped ? 1 : 1 - banner.leave)
            readonly property bool meltsIntoIsland: root.island !== null && !root.islandSide
            readonly property real fullHeight: content.implicitHeight + 24 * root.d

            property real swipe: 0
            Behavior on swipe {
                enabled: !swipeDrag.active
                NumberAnimation { duration: IrisStyle.duration(180); easing.type: IrisStyle.feedbackEasing }
            }

            RectangularShadow {
                x: plate.x
                y: plate.y + 4 * root.d
                width: plate.width
                height: plate.height
                radius: plate.radius
                blur: 18 * root.d
                spread: -3 * root.d
                color: IrisStyle.shadow
                opacity: plate.opacity * IrisStyle.shadowAt(banner.bloom)
            }
            Rectangle {
                id: plate
                width: Math.round(root.bubbleSize + (banner.width - root.bubbleSize) * banner.bloom)
                height: Math.round(root.bubbleSize + (banner.fullHeight - root.bubbleSize) * banner.bloom)
                clip: true
                x: Math.round((banner.width - width) / 2 + banner.swipe)
                readonly property real islandLift: {
                    void (banner.y + popupColumn.y + popupColumn.contentY + popupColumn.height)
                    if (!banner.meltsIntoIsland) return root.barTop ? -18 * root.d : 18 * root.d
                    const at = banner.mapToItem(root, 0, 0)
                    return (root.island.y + root.island.height / 2) - (at.y + root.bubbleSize / 2)
                }
                y: Math.round(plate.islandLift * (1 - banner.bloom))
                opacity: Math.min(1, banner.bloom * 3)
                    * (1 - Math.min(1, Math.abs(banner.swipe) / (banner.width * 0.6)))
                radius: Math.min(height / 2, root.bubbleSize / 2 + (Math.round(22 * root.d) - root.bubbleSize / 2) * banner.bloom)
                color: IrisStyle.bodySurface
                border.width: 1
                border.color: banner.critical ? IrisStyle.tintBorder(IrisStyle.danger)
                    : ColorUtils.applyAlpha(IrisStyle.border, IrisStyle.border.a * banner.bloom)

                DragHandler {
                    id: swipeDrag
                    target: null
                    xAxis.enabled: true
                    yAxis.enabled: false
                    onTranslationChanged: banner.swipe = translation.x
                    onActiveChanged: {
                        if (active) return
                        if (Math.abs(banner.swipe) > banner.width * 0.3) {
                            banner.swipe = banner.swipe > 0 ? banner.width : -banner.width
                            dismissLater.restart()
                        } else {
                            banner.swipe = 0
                        }
                    }
                }
                Timer {
                    id: dismissLater
                    interval: IrisStyle.duration(180)
                    onTriggered: Notifications.timeoutNotification(banner.notification.notificationId)
                }
                TapHandler {
                    onTapped: root.activate(banner.notification)
                }

                RowLayout {
                    id: content
                    x: 14 * root.d
                    y: 12 * root.d
                    width: banner.width - 26 * root.d
                    spacing: 12 * root.d

                    IrisNotificationIcon {
                        Layout.alignment: Qt.AlignTop
                        Layout.topMargin: 2 * root.d
                        transform: Translate {
                            x: ((root.bubbleSize - 38 * root.d) / 2 - 14 * root.d) * (1 - banner.bloom)
                            y: ((root.bubbleSize - 38 * root.d) / 2 - 14 * root.d) * (1 - banner.bloom)
                        }
                        size: Math.round(38 * root.d)
                        appName: String(banner.notification?.appName ?? "")
                        appIcon: String(banner.notification?.appIcon ?? "")
                        image: String(banner.notification?.image ?? "")
                        summary: String(banner.notification?.summary ?? "")
                        critical: banner.critical
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        opacity: IrisStyle.contentAt(banner.bloom)

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8 * root.d
                            IrisText {
                                Layout.fillWidth: true
                                text: String(banner.notification?.summary || banner.notification?.appName || "")
                                font.pixelSize: 13.5 * IrisStyle.typeScale
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            IrisText {
                                text: {
                                    void root.now
                                    const seconds = Math.max(0, Math.floor((root.now - Number(banner.notification?.time ?? root.now)) / 1000))
                                    return seconds < 60 ? Translation.tr("now")
                                        : seconds < 3600 ? Translation.tr("%1m").arg(Math.floor(seconds / 60))
                                        : Translation.tr("%1h").arg(Math.floor(seconds / 3600))
                                }
                                color: IrisStyle.muted
                                font.pixelSize: 11.5 * IrisStyle.typeScale
                            }
                        }
                        IrisText {
                            Layout.fillWidth: true
                            visible: text.length > 0
                            text: String(banner.notification?.body ?? "").replace(/<[^>]*>/g, "")
                            color: IrisStyle.subtext
                            font.pixelSize: 12.5 * IrisStyle.typeScale
                            wrapMode: Text.Wrap
                            maximumLineCount: banner.hovered ? 8 : 2
                            elide: Text.ElideRight
                        }
                        IrisText {
                            Layout.fillWidth: true
                            visible: text.length > 0 && text !== String(banner.notification?.summary ?? "")
                            text: String(banner.notification?.appName ?? "")
                            color: IrisStyle.muted
                            font.pixelSize: 11 * IrisStyle.typeScale
                            elide: Text.ElideRight
                        }

                        Flow {
                            Layout.fillWidth: true
                            Layout.topMargin: 8 * root.d
                            visible: banner.actions.length > 0
                            spacing: 6 * root.d
                            Repeater {
                                model: banner.actions
                                IrisButton {
                                    id: actionButton
                                    required property var modelData
                                    implicitHeight: Math.round(28 * root.d)
                                    implicitWidth: actionLabel.implicitWidth + 24 * root.d
                                    buttonRadius: height / 2
                                    buttonRadiusPressed: height / 2
                                    colBackground: IrisStyle.fill
                                    colBackgroundHover: IrisStyle.fillHover
                                    Accessible.name: String(actionButton.modelData.text ?? "")
                                    onClicked: Notifications.attemptInvokeAction(banner.notification.notificationId, actionButton.modelData.identifier)
                                    IrisText {
                                        id: actionLabel
                                        anchors.centerIn: parent
                                        text: String(actionButton.modelData.text ?? "")
                                        font.pixelSize: 12 * IrisStyle.typeScale
                                        font.weight: Font.Medium
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    x: 5 * root.d
                    y: 5 * root.d
                    width: Math.round(22 * root.d)
                    height: width
                    radius: width / 2
                    color: closeArea.containsMouse ? IrisStyle.surfaceHighest : IrisStyle.surfaceHigh
                    border.width: 1
                    border.color: IrisStyle.hairlineStrong
                    opacity: banner.hovered ? 1 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: IrisStyle.duration(120) } }
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "close"
                        iconSize: Math.round(13 * root.d)
                        color: IrisStyle.text
                    }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        Accessible.role: Accessible.Button
                        Accessible.name: Translation.tr("Dismiss")
                        onClicked: Notifications.timeoutNotification(banner.notification.notificationId)
                    }
                }
            }
        }
    }

}
