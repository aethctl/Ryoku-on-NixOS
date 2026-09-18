import assert from "node:assert/strict";
import test from "node:test";
import { createRequire } from "node:module";

const require = createRequire(import.meta.url);
const { looksLikeAddress, label } = require("./bluetooth.js");

// The bug these pin: BlueZ defaults a device's alias to its own address, so the
// name slot filled with a MAC while the real name sat unused in `deviceName`.

test("a real user alias is kept", () => {
    assert.equal(
        label({ name: "My Headphones", deviceName: "WH-1000XM6", address: "80:99:E7:F7:25:1B" }),
        "My Headphones");
});

test("the device-reported name wins over an address-shaped alias", () => {
    assert.equal(
        label({ name: "73-EC-EF-CD-48-8C", deviceName: "Soundcore Mini", address: "73:EC:EF:CD:48:8C" }),
        "Soundcore Mini");
});

test("a colon-form address alias is skipped for the reported name", () => {
    assert.equal(
        label({ name: "80:99:E7:F7:25:1B", deviceName: "Vertuo", address: "80:99:E7:F7:25:1B" }),
        "Vertuo");
});

test("an empty alias takes the device-reported name", () => {
    assert.equal(
        label({ name: "", deviceName: "Dryer", address: "34:FC:99:2F:49:DC" }),
        "Dryer");
});

test("a plain name is used as-is", () => {
    assert.equal(
        label({ name: "WH-1000XM6", deviceName: "WH-1000XM6", address: "80:99:E7:F7:25:1B" }),
        "WH-1000XM6");
});

test("a device with no name at all falls back to its address", () => {
    assert.equal(
        label({ name: "4D-4A-54-1E-7B-B8", deviceName: "", address: "4D:4A:54:1E:7B:B8" }),
        "4D-4A-54-1E-7B-B8");
});

test("nothing to name reads as empty, and address detection is exact", () => {
    assert.equal(label(null), "");
    assert.equal(label({}), "");
    assert.ok(looksLikeAddress("73-EC-EF-CD-48-8C"));
    assert.ok(looksLikeAddress("73:EC:EF:CD:48:8C"));
    assert.ok(!looksLikeAddress("WH-1000XM6"));
    assert.ok(!looksLikeAddress("Washer"));
});
