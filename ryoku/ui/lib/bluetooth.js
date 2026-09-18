// How a Bluetooth device should read on screen, shared by every Ryoku surface
// (the shell bars, the launcher, the Hub). BlueZ leaves a device's alias equal
// to its own address -- dashed, like "73-EC-EF-CD-48-8C" -- until it learns a
// name, and Quickshell exposes that alias as `name` while the name the device
// itself reports is `deviceName`. A MAC-shaped alias is therefore not a name:
// keep a real user alias, otherwise take the device-reported name, and only
// fall back to the address when there is nothing better.

var ADDRESS = /^([0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}$/;

function looksLikeAddress(value) {
    return ADDRESS.test(String(value || "").trim());
}

function label(device) {
    if (!device)
        return "";
    var alias = String(device.name || "");
    if (alias.length > 0 && !looksLikeAddress(alias))
        return alias;
    var reported = String(device.deviceName || "");
    if (reported.length > 0)
        return reported;
    if (alias.length > 0)
        return alias;
    return String(device.address || "");
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { looksLikeAddress, label };
