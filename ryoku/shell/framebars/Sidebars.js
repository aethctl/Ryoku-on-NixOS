.pragma library

const leftIds = ["system", "notifications", "weather", "media", "capture", "stage"];
const rightIds = ["usage", "tools", "chat"];
const positions = ["top", "center", "bottom"];
const heightModes = ["fit", "fixed"];
const presentations = ["summary", "expanded"];

function defaultSide(side) {
    var left = side === "left";
    return {
        enabled: true,
        cards: left ? leftIds.slice() : rightIds.slice(),
        width: 1040,
        height: 1000,
        heightMode: "fixed",
        maxHeight: 85,
        position: "center",
        pinned: false,
        presentations: {}
    };
}

function defaultConfig() {
    return {
        motion: "standard",
        left: defaultSide("left"),
        right: defaultSide("right")
    };
}

function finiteNumber(value, fallback) {
    var number = Number(value);
    return isFinite(number) ? number : fallback;
}

function clamp(value, low, high) {
    return Math.max(low, Math.min(high, value));
}

function validId(id) {
    return typeof id === "string"
        && /^[a-z0-9][a-z0-9-]*$/.test(id);
}

function cardList(value, fallback) {
    if (!Array.isArray(value))
        return fallback.slice();
    var result = [];
    for (var i = 0; i < value.length; ++i) {
        var id = typeof value[i] === "string" ? value[i] : "";
        if (!validId(id) || result.indexOf(id) >= 0)
            continue;
        result.push(id);
    }
    return result;
}

function presentationMap(value) {
    var source = value && typeof value === "object" && !Array.isArray(value) ? value : {};
    var result = {};
    var keys = Object.keys(source);
    for (var i = 0; i < keys.length; ++i) {
        var id = keys[i];
        if (validId(id) && presentations.indexOf(source[id]) >= 0)
            result[id] = source[id];
    }
    return result;
}


function sideConfig(raw, side, fallback, legacyWidth) {
    var value = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {};
    var minWidth = side === "left" ? 300 : 380;
    var maxWidth = 1440;
    var widthFallback = side === "left" && value.width === undefined
        ? finiteNumber(legacyWidth, fallback.width) : fallback.width;
    var mode = heightModes.indexOf(value.heightMode) >= 0
        ? value.heightMode : fallback.heightMode;
    var position = positions.indexOf(value.position) >= 0
        ? value.position : fallback.position;
    return {
        enabled: typeof value.enabled === "boolean" ? value.enabled : fallback.enabled,
        cards: cardList(value.cards, fallback.cards),
        width: Math.round(clamp(finiteNumber(value.width, widthFallback), minWidth, maxWidth)),
        height: Math.round(clamp(finiteNumber(value.height, fallback.height), 260, 1200)),
        heightMode: mode,
        maxHeight: Math.round(clamp(finiteNumber(value.maxHeight, fallback.maxHeight), 40, 95)),
        position: position,
        pinned: typeof value.pinned === "boolean" ? value.pinned : fallback.pinned,
        presentations: presentationMap(value.presentations)
    };
}

function normalize(raw) {
    var defaults = defaultConfig();
    var value = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : {};
    var motion = ["quick", "standard", "calm"].indexOf(value.motion) >= 0
        ? value.motion : defaults.motion;
    return {
        motion: motion,
        left: sideConfig(value.left, "left", defaults.left, value.width),
        right: sideConfig(value.right, "right", defaults.right, undefined)
    };
}
