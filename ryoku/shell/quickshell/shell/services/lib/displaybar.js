function styleFor(displays, output, fallback) {
    const styles = displays && displays.bar_style;
    const value = output && styles ? styles[output] : undefined;
    return typeof value === "string" && value.length > 0 ? value : fallback;
}

function widgetEnabled(displays, output, style, id, fallback) {
    const outputs = displays && displays.bar_widgets;
    const styles = output && outputs ? outputs[output] : undefined;
    const widgets = styles && style ? styles[style] : undefined;
    const value = widgets && id ? widgets[id] : undefined;
    return typeof value === "boolean" ? value : fallback;
}
