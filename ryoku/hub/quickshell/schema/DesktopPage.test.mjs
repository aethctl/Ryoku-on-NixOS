import fs from "node:fs";
import vm from "node:vm";
import assert from "node:assert/strict";
import test from "node:test";

const source = fs.readFileSync(new URL("./DesktopPage.js", import.meta.url), "utf8").replace(/^\.pragma library\s*/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);
const rows = context.rows;

test("reload cover is a brand-backed General setting after Brand", () => {
    const index = rows.findIndex(row => row.key === "reloadCover");
    assert.ok(index >= 0);
    const row = rows[index];
    // what the Hub acts on: the row is a brand-backed reload-cover control on
    // General, worded for a user and short enough to read as one line
    assert.equal(row.tab, "General");
    assert.equal(row.group, "SHELL RELOAD");
    assert.equal(row.ctl, "reload-cover");
    assert.equal(row.src, "brand");
    assert.ok(row.label.length > 0);
    assert.ok(row.desc.length > 0 && row.desc.length <= 60, `desc is ${row.desc.length} chars`);
    // and where it sits: the account for marking, and the end of the tab
    assert.equal(rows[index - 1].key, "markTint");
    assert.equal(rows[index + 1].tab, "Visualizer");
});
