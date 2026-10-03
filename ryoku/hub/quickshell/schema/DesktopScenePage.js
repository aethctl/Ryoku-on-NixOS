.pragma library

var rows = [
    { tab: "Scene", group: "DEPTH", key: "stage.effect", label: "Wallpaper depth", desc: "Plain, depth, or parallax scene", src: "stage.json" },
    { tab: "Scene", group: "CUT", key: "stage.quality", label: "Cut quality", desc: "Download a model and rebuild wallpaper layers", src: "stage.json" },
    { tab: "Scene", group: "LAYERS", key: "stage.layers", label: "Scene layers", desc: "Add, remove, clear, place in front, and tune parallax drift", src: "stage registry" },
    { tab: "Scene", group: "LOOK", key: "stage.edge", label: "Edge softness", desc: "Blend the cut edge into the wallpaper", src: "stage.json" },
    { tab: "Scene", group: "LOOK", key: "stage.shadow", label: "Layer shadow", desc: "Separate the subject from the wallpaper", src: "stage.json" },
    { tab: "Scene", group: "MOTION", key: "stage.motion", label: "Parallax motion", desc: "Amount, idle motion, pointer following, and music reaction", src: "stage.json" },
    { tab: "Visualizer", group: "LOOK", key: "visualizer.style", label: "Visualizer look", desc: "Cycle the live audio visualizer style", src: "visualizer.json" },
    { tab: "Visualizer", group: "PERFORMANCE", key: "visualizer.fps", label: "Visualizer frame rate", desc: "Frame rate, adaptive quality, gain, and smoothing", src: "visualizer.json" },
    { tab: "Visualizer", group: "DEPTH", key: "visualizer.front", label: "Visualizer depth", desc: "Place the visualizer behind or in front of cut-out layers", src: "stage.json" },
    { tab: "Widgets", group: "PLACEMENT", key: "desktop.widgets", label: "Desktop widget editor", desc: "Place, resize, style, add, and remove widgets directly on the desktop", src: "widgets.json" }
];
