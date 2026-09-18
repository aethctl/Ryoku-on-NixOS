import QtQuick
import Quickshell
import "modules/bar/barstyles/qsbar" as QsBar
import "modules/bar/barstyles/qsbar/controlcenter/routes" as Routes

ShellRoot {
    QsBar.Theme {
        id: theme
    }

    Routes.BarsRoute {
        width: 800
        height: 600
        root: theme
    }

    Timer {
        interval: 900
        running: true
        onTriggered: {
            if (theme.barScale !== 1.5) {
                console.error("QSBAR-SIZE-PROBE-FAIL barScale=" + theme.barScale)
                Qt.quit()
                return
            }
            if (theme.v2BarHeight !== 50) {
                console.error("QSBAR-SIZE-PROBE-FAIL v2BarHeight=" + theme.v2BarHeight)
                Qt.quit()
                return
            }
            console.log("QSBAR-SIZE-PROBE-PASS")
            Qt.quit()
        }
    }
}
