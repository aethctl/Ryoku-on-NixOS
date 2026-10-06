pragma Singleton
import Quickshell
import shell.services as RWeather

// The Stage Editor's weather view for its clock faces. Ryoku owns the weather
// engine (the daemon's `weather` topic, polled and unit-converted in Go), so
// this does not fetch: it re-exposes the daemon's current reading in the shape
// the reference's clock widgets read (a WMO code, a display temperature string,
// and a sunset time). The faces fall back on their own defaults when the daemon
// has no data yet. See docs/stage.md.
Singleton {
    id: root

    readonly property var data: ({
        "wCode": RWeather.Weather.current ? RWeather.Weather.current.code : 113,
        "temp": RWeather.Weather.temp,
        "sunset": ""
    })
}
