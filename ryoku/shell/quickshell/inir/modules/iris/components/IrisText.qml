import QtQuick
import inir.modules.common.widgets
import inir.modules.iris.style

StyledText {
    id: root

    enum Role { Body, Meta, Eyebrow, Title, Display, Metric }
    property int role: IrisText.Body

    color: role === IrisText.Meta ? IrisStyle.subtext
        : role === IrisText.Eyebrow ? IrisStyle.accent : IrisStyle.text
    defaultFont: (role === IrisText.Title || role === IrisText.Display)
        ? IrisStyle.fontTitle
        : role === IrisText.Eyebrow || role === IrisText.Metric ? IrisStyle.fontNumbers
        : IrisStyle.fontMain
    font.family: defaultFont
    font.pixelSize: (role === IrisText.Meta ? 12
        : role === IrisText.Eyebrow ? 10
        : role === IrisText.Title ? 18
        : role === IrisText.Display ? 27
        : role === IrisText.Metric ? 22 : 14) * IrisStyle.typeScale
    font.weight: role === IrisText.Meta ? Font.Normal
        : role === IrisText.Eyebrow ? Font.Bold
        : role === IrisText.Title ? Font.DemiBold
        : role === IrisText.Display || role === IrisText.Metric ? Font.Bold : Font.Medium
    font.letterSpacing: role === IrisText.Eyebrow ? 1.0
        : role === IrisText.Meta ? 0.15 : 0
}
