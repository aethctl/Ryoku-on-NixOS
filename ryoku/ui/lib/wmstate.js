// Snapshot sections have independent lifetimes. Preserve unchanged array/object
// identities so QML does not rebuild workspace and output consumers on focus.
function applyFrame(target, frame) {
    const defaults = {
        ready: false, caps: {}, workspaceModel: "fixed", focusedOutput: "",
        outputs: [], configFiles: [], keyboardLayout: "", keyboardLayouts: [],
        windows: [], workspaces: []
    };
    for (const key of Object.keys(defaults)) {
        const value = frame[key] === undefined ? defaults[key] : frame[key];
        if (JSON.stringify(target[key]) !== JSON.stringify(value))
            target[key] = value;
    }
}

function workspaceRows(residue, sets, dynamic) {
    if (dynamic) {
        return residue.map(w => ({
            id: String(w.id), name: String(w.name), output: w.output || "",
            active: w.active === true, windows: Number(w.windows || 0),
            occupied: Number(w.windows || 0) > 0, fullscreen: w.fullscreen === true,
            special: w.special === true, layout: w.layout || ""
        }));
    }
    const byName = {};
    for (const w of residue) byName[w.name] = w;
    return Array.from(sets).map(s => {
        const w = byName[s.name] || {};
        return {
            id: String(w.id || s.name), name: s.name, output: w.output || "",
            active: s.active === true, urgent: s.urgent === true,
            canActivate: s.canActivate === true, windows: Number(w.windows || 0),
            occupied: Number(w.windows || 0) > 0, fullscreen: w.fullscreen === true,
            special: w.special === true, layout: w.layout || ""
        };
    });
}
