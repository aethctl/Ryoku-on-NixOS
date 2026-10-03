import fs from "node:fs";
import vm from "node:vm";
import assert from "node:assert/strict";
import test from "node:test";

const source = fs.readFileSync(new URL("./Sidebars.js", import.meta.url), "utf8")
    .replace(/^\.pragma library\s*/, "");
const context = {};
vm.createContext(context);
vm.runInContext(source, context);

test("legacy width moves to Controls without reviving empty content", () => {
    const value = context.normalize({
        width: 512,
        left: { cards: [] },
        right: { cards: [] }
    });

    assert.equal(value.left.width, 512);
    assert.deepEqual(Array.from(value.left.cards), []);
    assert.deepEqual(Array.from(value.right.cards), []);
    assert.equal(Object.hasOwn(value, "width"), false);
});

test("all built-ins may move between surfaces while layout bounds stay side-specific", () => {
    const all = ["system", "notifications", "weather", "media", "capture", "stage", "usage", "tools", "chat"];
    const value = context.normalize({
        left: { cards: all, width: 10, height: 2000, maxHeight: 10 },
        right: { cards: all, width: 2000, height: 10, maxHeight: 100 }
    });

    assert.deepEqual(Array.from(value.left.cards), all);
    assert.deepEqual(Array.from(value.right.cards), all);
    assert.deepEqual([value.left.width, value.left.height, value.left.maxHeight], [300, 1200, 40]);
    assert.deepEqual([value.right.width, value.right.height, value.right.maxHeight], [1440, 260, 95]);
});

test("presentation rejects invalid modes and retired native geometry is discarded", () => {
    const value = context.normalize({
        left: {
            presentations: { media: "summary", tools: "expanded", chat: "tiny" },
            geometry: {
                "DP-1": { x: 10.2, y: 20.8, width: 440.4, height: 510.6 }
            }
        }
    });

    assert.deepEqual(JSON.parse(JSON.stringify(value.left.presentations)), { media: "summary", tools: "expanded" });
    assert.equal(Object.hasOwn(value.left, "geometry"), false);
});
