import QtQuick
import Ryoku.Ui.Singletons

FolioTabData {
    tabKey: "performance"
    title: I18n.tr("Performance")
    note: I18n.tr("Resource limits for this machine and its displays.")
    sections: [
        {
            title: I18n.tr("Power"),
            subtitle: "",
            controls: [
                { id: "performance.powerSource.info",
                  key: null,
                  kind: "static",
                  label: I18n.tr("Current power source"),
                  help: I18n.tr("[dynamic] 'Battery (automatic limits are active)' | 'Battery (automatic limits are disabled)' | 'External power, desktop, or unavailable (automatic limits are inactive)'"),
                  search: ["current", "power", "source", "static"] },
                { id: "performance.gpuDevice",
                  key: "performance.gpuDevice",
                  kind: "dropdown",
                  label: I18n.tr("Wallpaper GPU"),
                  help: I18n.tr("Choose the GPU for skwd-paper wallpaper rendering. An unavailable card falls back to Automatic."),
                  options: [{ value: "auto", label: I18n.tr("Automatic") }],
                  dynamic: "gpus",
                  search: ["performance.gpuDevice", "wallpaper", "gpu", "automatic", "dropdown"] },
                { id: "performance.batterySaver",
                  key: "performance.batterySaver",
                  kind: "toggle",
                  label: I18n.tr("Automatic battery saver"),
                  help: I18n.tr("Apply the FPS and video-idle limits below while the battery is discharging. Power changes are picked up automatically."),
                  search: ["performance.batterySaver", "automatic", "battery", "saver", "toggle"] },
                { id: "performance.gpuPreference",
                  key: "performance.gpuPreference",
                  kind: "dropdown",
                  label: I18n.tr("Picker GPU"),
                  help: I18n.tr("Auto prefers a low-power GPU while the battery saver is active. Low power asks for an integrated GPU, High performance a discrete one. Applies the next time the picker opens. A DRI_PRIME set in the session wins."),
                  options: [{ value: "auto", label: I18n.tr("Auto (recommended)") }, { value: "low", label: I18n.tr("Low power") }, { value: "high", label: I18n.tr("High performance") }, { value: "none", label: I18n.tr("Driver default") }],
                  search: ["performance.gpuPreference", "picker", "gpu", "auto", "low", "power", "high", "performance", "none", "driver", "default", "dropdown"] },
                { id: "performance.batteryFps",
                  key: "performance.batteryFps",
                  kind: "number",
                  label: I18n.tr("On-battery picker FPS"),
                  help: I18n.tr("Cap picker animation while discharging. The normal Max FPS still applies if lower; 0 disables this cap."),
                  unit: I18n.tr("fps"),
                  search: ["performance.batteryFps", "on", "battery", "picker", "fps", "number"] },
                { id: "performance.batteryVideoIdleSeconds",
                  key: "performance.batteryVideoIdleSeconds",
                  kind: "number",
                  label: I18n.tr("On-battery video idle pause"),
                  help: I18n.tr("Pause video rendering, decode, and audio after this many idle seconds while discharging. The shorter of this and the Paper idle pause wins; 0 disables it."),
                  unit: I18n.tr("s"),
                  search: ["performance.batteryVideoIdleSeconds", "on", "battery", "video", "idle", "pause", "s", "number"] },
                { id: "performance.batteryWallpaperPerformance",
                  key: "performance.batteryWallpaperPerformance",
                  kind: "toggle",
                  label: I18n.tr("Wallpaper performance mode on battery"),
                  help: I18n.tr("While discharging, use direct NV12 video, hard cuts, and a 30 fps, 2048 px limit for native scenes. Less detail, much less work per frame."),
                  search: ["performance.batteryWallpaperPerformance", "wallpaper", "performance", "mode", "battery", "toggle"] }
            ]
        },
        {
            title: I18n.tr("Picker rendering"),
            subtitle: "",
            controls: [
                { id: "performance.weRenderer.info",
                  key: null,
                  kind: "static",
                  label: I18n.tr("Wallpaper Engine scene renderer"),
                  help: I18n.tr("skwd-paper renders Wallpaper Engine scenes with Vulkan."),
                  search: ["wallpaper", "engine", "scene", "renderer", "static"] },
                { id: "general.maxFps",
                  key: "general.maxFps",
                  kind: "number",
                  label: I18n.tr("Max FPS"),
                  help: I18n.tr("Normal animation frame-rate cap. Set it to the display refresh rate for maximum smoothness, or 60 for a cooler laptop."),
                  unit: I18n.tr("fps"),
                  search: ["general.maxFps", "max", "fps", "number"] },
                { id: "performance.releaseAfterHideSeconds",
                  key: "performance.releaseAfterHideSeconds",
                  kind: "number",
                  label: I18n.tr("Keep loaded after closing"),
                  help: I18n.tr("How long the closed picker stays in memory so it reopens instantly. Lower frees memory sooner; the next open then rebuilds the scene."),
                  unit: I18n.tr("s"),
                  search: ["performance.releaseAfterHideSeconds", "keep", "loaded", "memory", "release", "reopen", "number"] }
            ]
        },
        {
            title: I18n.tr("Wallpaper efficiency"),
            subtitle: "",
            visibleWhen: "paper.engine == skwd-paper || paper.videoEngine in {skwd-paper, tinier}",
            controls: [
                { id: "paper.videoMultiProcess",
                  key: "paper.videoMultiProcess",
                  kind: "toggle",
                  label: I18n.tr("Shared video process"),
                  help: I18n.tr("Run all video wallpapers in one renderer and Vulkan device. Identical videos share decoding. Disable only for troubleshooting."),
                  search: ["paper.videoMultiProcess", "shared", "video", "process", "toggle"] },
                { id: "paper.performanceMode",
                  key: "paper.performanceMode",
                  kind: "toggle",
                  label: I18n.tr("Performance mode"),
                  help: I18n.tr("Changes become hard cuts. Cover-fill video walls hand decoded NV12 frames straight to the compositor, saving roughly 45% of video VRAM. Fit and centre keep the standard renderer."),
                  search: ["paper.performanceMode", "performance", "mode", "toggle"] },
                { id: "resource_tier",
                  key: "resource_tier",
                  kind: "chips",
                  label: I18n.tr("Video decode budget"),
                  help: I18n.tr("How much memory and CPU Ryoku's own video engine may use."),
                  options: [{ value: "low", label: I18n.tr("Low") }, { value: "medium", label: I18n.tr("Medium") }, { value: "high", label: I18n.tr("High") }],
                  search: ["resource", "tier", "memory", "video"] }
            ]
        },
        {
            title: I18n.tr("Bug report"),
            subtitle: "",
            controls: [
                { id: "performance.bugReport.action",
                  key: null,
                  kind: "action",
                  label: I18n.tr("Generate bug report"),
                  help: I18n.tr("Bundle version, environment, and recent logs into one file to attach to an issue."),
                  action: "GenerateBugReport",
                  search: ["generate", "bug", "report", "action"] }
            ]
        }
    ]
}
