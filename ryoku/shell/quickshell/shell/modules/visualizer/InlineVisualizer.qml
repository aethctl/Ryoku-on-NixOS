pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// The visualiser stack without its own surface: the desktop hosts one at
// the visualizer's scene z while parallax owns the background, so the
// bars sit between the parallax layers.
Item {
    id: root

    Repeater {
        model: Config.count
        delegate: VisualizerView {
            id: vizView
            anchors.fill: parent
            cfg: VizItem { data: Config.dataAt(vizView.index) }
        }
    }
}
