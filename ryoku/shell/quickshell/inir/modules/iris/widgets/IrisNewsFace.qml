pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import inir.services
import inir.services.deferred
import inir.modules.iris.style

IrisWidgetFace {
    id: root

    readonly property int capacity: root.small ? 1 : root.medium ? 2 : 4
    readonly property var stories: {
        const all = Array.from(NewsService.articles ?? [])
        if (all.length === 0)
            return []
        const start = root.widget.headlineIndex % all.length
        return all.slice(start).concat(all.slice(0, start)).slice(0, root.capacity)
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: root.dp(8)

        FaceHeader {
            face: root
            Layout.fillWidth: true
            glyph: "newspaper"
            text: Translation.tr("News")
            tint: IrisStyle.identity.red
        }

        FaceText {
            face: root
            visible: root.stories.length === 0
            Layout.fillWidth: true
            text: Translation.tr("Fetching headlines…")
            color: root.inkTertiary
            size: 12.5
        }

        Repeater {
            model: root.stories
            ColumnLayout {
                id: story
                required property var modelData
                required property int index
                readonly property bool lead: story.index === 0
                Layout.fillWidth: true
                Layout.fillHeight: story.lead
                spacing: root.dp(2)
                Rectangle {
                    visible: !story.lead
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    Layout.bottomMargin: root.dp(6)
                    color: IrisStyle.hairline
                }
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    visible: root.widget.showMeta
                    text: String(story.modelData.source ?? "")
                    color: IrisStyle.identity.red
                    size: 11
                    weight: Font.Bold
                }
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    text: String(story.modelData.title ?? "")
                    size: story.lead && !root.small ? 15.5 : 13
                    weight: Font.Bold
                    wrapMode: Text.WordWrap
                    maximumLineCount: story.lead ? (root.small ? 4 : 3) : 2
                    lineHeight: 1.08
                    color: storyHover.hovered ? root.accent : root.ink
                }
                FaceText {
                    face: root
                    Layout.fillWidth: true
                    visible: root.widget.showMeta
                    text: NewsService.formatTime(story.modelData.timestamp)
                    color: root.inkTertiary
                    size: 11
                }
                HoverHandler { id: storyHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: NewsService.openArticle(story.modelData) }
            }
        }
        Item { Layout.fillHeight: true; visible: root.stories.length > 1 }
    }
}
