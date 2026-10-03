pragma Singleton
import QtQuick
import "Sidebars.js" as Lib

QtObject {
    function normalize(raw) { return Lib.normalize(FrameBars.rehydrate(raw)); }
}
