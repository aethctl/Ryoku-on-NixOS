import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
const require = createRequire(import.meta.url);
const { CATALOG, CATEGORIES, validate } = require("./catalog.js");

let failed = 0;
function ok(cond, msg) {
    if (cond) console.log("PASS " + msg);
    else { failed++; console.log("FAIL " + msg); }
}

ok(CATALOG.length > 0, "catalog is non-empty");
ok(validate(CATALOG).length === 0, "catalog validates clean: " + JSON.stringify(validate(CATALOG)));

// every category tab (except All) has at least one action.
for (let i = 1; i < CATEGORIES.length; i++) {
    const cat = CATEGORIES[i];
    ok(CATALOG.some(a => a.category === cat), "category has actions: " + cat);
}

// validate catches a duplicate id.
ok(validate(CATALOG.concat([CATALOG[0]])).some(p => p.indexOf("duplicate") !== -1), "validate flags duplicate id");
// validate catches a missing exec.
ok(validate([{ id: "x", name: "X", category: "System", exec: [] }]).some(p => p.indexOf("empty exec") !== -1), "validate flags empty exec");
// validate catches an unknown category.
ok(validate([{ id: "y", name: "Y", category: "Nope", exec: ["a"] }]).some(p => p.indexOf("unknown category") !== -1), "validate flags unknown category");

const execFor = id => CATALOG.find(action => action.id === id)?.exec;
ok(
    JSON.stringify(execFor("open-clipboard")) === JSON.stringify(["ryoku-shell", "menu", "quick-settings#clipboard"]),
    "Clipboard History uses the supported quick-settings clipboard route"
);
ok(
    JSON.stringify(execFor("open-sysinfo")) === JSON.stringify(["ryoku-shell", "menu", "quick-settings"]),
    "System Info uses the supported quick-settings route"
);
ok(
    JSON.stringify(execFor("open-toolkit")) === JSON.stringify(["ryoku-shell", "menu", "quick-settings"]),
    "Control Deck uses the supported quick-settings route"
);
ok(
    CATALOG.filter(action => String(action.exec?.[0] || "").startsWith("ryoku-cmd-"))
        .every(action => !String(action.exec[0]).includes("/")),
    "Ryoku command helpers resolve through the packaged PATH"
);

const providerSource = readFileSync(new URL("./Actions.qml", import.meta.url), "utf8");
ok(
    !providerSource.includes("Config.scriptsDir"),
    "action helpers use PATH instead of the obsolete Hyprland scripts directory"
);

if (failed > 0) { console.log("\n" + failed + " test(s) FAILED"); process.exit(1); }
console.log("\nAll tests PASSED");
