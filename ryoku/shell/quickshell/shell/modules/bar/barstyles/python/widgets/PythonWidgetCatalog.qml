import QtQml
import Quickshell

QtObject {
    readonly property var types: ({
        "visualizer": {
            name: "Visualizer",
            icon: "󱑽",
            defaultWidth: Math.round((Quickshell.screens && Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1920) / 2),
            defaultHeight: 180,
            defaultVariant: "bars",
            variants: {
                "bars": { file: "faces/VisualizerFace.qml", label: "Bars" },
                "continuous": { file: "faces/VisualizerFaceContinuous.qml", label: "Continuous" }
            }
        },
        "time": {
            name: "Clock",
            icon: "󰥔",
            defaultWidth: 250,
            defaultHeight: 120,
            defaultVariant: "digital",
            variants: {
                "digital": { file: "faces/ClockFaceDigital.qml", label: "Digital" },
                "analog": { file: "faces/ClockFaceAnalog.qml", label: "Analog" },
                "minimal": { file: "faces/ClockFaceMinimal.qml", label: "Minimal" },
                "material": { file: "faces/ClockFaceMaterial.qml", label: "Material" },
                "materialAnalog": { file: "faces/ClockFaceMaterialAnalog.qml", label: "Material Analog" },
                "lumen": { file: "faces/ClockFaceMaterialLumen.qml", label: "Lumen" }
            }
        },
        "music": {
            name: "Music",
            icon: "󰎈",
            defaultWidth: 340,
            defaultHeight: 120,
            defaultVariant: "full",
            variants: {
                "full": { file: "faces/MusicFace.qml", label: "Full" },
                "round": { file: "faces/MusicFaceRound.qml", label: "Round" },
                "lyrics": { file: "faces/MusicFaceLyrics.qml", label: "Lyrics" }
            }
        },
        "weather": {
            name: "Weather",
            icon: "󰖐",
            defaultWidth: 250,
            defaultHeight: 120,
            defaultVariant: "compact",
            variants: {
                "compact": { file: "faces/WeatherFaceCompact.qml", label: "Compact" },
                "full": { file: "faces/WeatherFaceFull.qml", label: "Full" },
                "round": { file: "faces/WeatherFaceRound.qml", label: "Round" }
            }
        },
        "image": {
            name: "Image",
            icon: "󰋩",
            defaultWidth: 300,
            defaultHeight: 200,
            defaultVariant: "rect",
            variants: {
                "rect": { file: "faces/ImageFaceRect.qml", label: "Rect" },
                "rounded": { file: "faces/ImageFaceRounded.qml", label: "Rounded" },
                "round": { file: "faces/ImageFaceRound.qml", label: "Round" }
            }
        },
        "user": {
            name: "User",
            icon: "",
            defaultWidth: 260,
            defaultHeight: 140,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/UserFace.qml", label: "Default" }
            }
        },
        "cpu": {
            name: "CPU",
            icon: "\uF2DB",
            defaultWidth: 180,
            defaultHeight: 130,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/usage/CpuFace.qml", label: "Default" }
            }
        },
        "ram": {
            name: "RAM",
            icon: "\uF538",
            defaultWidth: 180,
            defaultHeight: 130,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/usage/RamFace.qml", label: "Default" }
            }
        },
        "temp": {
            name: "Temp",
            icon: "\uF2C9",
            defaultWidth: 180,
            defaultHeight: 130,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/usage/TempFace.qml", label: "Default" }
            }
        },
        "disk": {
            name: "Disk",
            icon: "\uF0A0",
            defaultWidth: 180,
            defaultHeight: 130,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/usage/DiskFace.qml", label: "Default" }
            }
        },
        "battery": {
            name: "Battery",
            icon: "󰁹",
            defaultWidth: 260,
            defaultHeight: 90,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/BatteryFace.qml", label: "Default" }
            }
        },
        "github": {
            name: "GitHub",
            icon: "󰊤",
            defaultWidth: 540,
            defaultHeight: 180,
            defaultVariant: "default",
            variants: {
                "default": { file: "faces/GithubFace.qml", label: "Default" }
            }
        }
    })
}
