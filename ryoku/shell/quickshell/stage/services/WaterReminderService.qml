pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import stage
import stage.modules.common

// Water Reminder background widget service.
// Tracks daily glasses drunk and periodically sends a system notification
// every `intervalHours` until the daily goal is reached. The counter resets
// each day and persists across restarts via Persistent.state.
Singleton {
    id: root

    readonly property bool configured: Config.ready
    readonly property bool enabled: configured && (Config.options.background.widgets.water_reminder.enable ?? false)
    readonly property int dailyGoal: configured ? (Config.options.background.widgets.water_reminder.dailyGoal || 8) : 8
    readonly property int intervalHours: configured ? (Config.options.background.widgets.water_reminder.intervalHours || 2) : 2

    // Current glasses drunk this day (0..dailyGoal), reactive for the widget UI.
    property int glassesDrunk: 0
    property bool goalReached: dailyGoal > 0 && glassesDrunk >= dailyGoal
    property string _lastDate: ""
    property real _lastNotify: 0

    function _todayKey() {
        const d = new Date();
        return d.getFullYear() + "-" + (d.getMonth() + 1) + "-" + d.getDate();
    }

    function _save() {
        if (!Persistent.ready) return;
        const w = Persistent.states.water;
        w.glassesDrunk = root.glassesDrunk;
        w.lastDate = root._lastDate;
        w.lastNotify = root._lastNotify;
    }

    function _load() {
        if (!Persistent.ready) return;
        const w = Persistent.states.water || {};
        root._lastDate = w.lastDate || "";
        root._lastNotify = w.lastNotify || 0;
        if (root._lastDate !== root._todayKey()) {
            // New day: reset counter.
            root.glassesDrunk = 0;
            root._lastDate = root._todayKey();
            root._save();
        } else {
            root.glassesDrunk = Math.max(0, w.glassesDrunk || 0);
        }
    }

    // Called by the widget action button.
    function addGlass() {
        const goal = root.dailyGoal;
        if (goal <= 0) return;
        if (root.glassesDrunk >= goal) {
            root.resetCounter();
            return;
        }
        root.glassesDrunk = Math.min(goal, root.glassesDrunk + 1);
        root._save();
        if (root.goalReached) {
            Quickshell.execDetached([
                "notify-send",
                "-a", "Water Reminder",
                Translation.tr("Daily water goal reached!"),
                Translation.tr("You drank %1 glasses today.").arg(String(goal))
            ]);
        }
    }

    // Reset the current day's counter (used from the settings page).
    function resetCounter() {
        root.glassesDrunk = 0;
        root._save();
    }

    function _notify() {
        const note = Config.options.background.widgets.water_reminder.reminderText || "Time to hydrate! 💧";
        Quickshell.execDetached([
            "notify-send",
            "-a", "Water Reminder",
            "-i", "water_drop",
            note
        ]);
    }

    function _check() {
        if (!root.enabled) return;
        // Day rollover reset (also covered by _load on boot).
        if (root._lastDate !== root._todayKey()) {
            root.glassesDrunk = 0;
            root._lastDate = root._todayKey();
            root._save();
        }
        if (root.dailyGoal > 0 && root.glassesDrunk >= root.dailyGoal) return;

        const intervalMs = Math.max(1, root.intervalHours) * 3600 * 1000;
        const now = Date.now();
        if (root._lastNotify <= 0 || (now - root._lastNotify) >= intervalMs) {
            root._lastNotify = now;
            root._save();
            root._notify();
        }
    }

    Timer {
        id: checkTimer
        interval: 60000
        repeat: true
        running: true
        onTriggered: root._check()
    }

    Connections {
        target: Config
        function onReadyChanged() { if (Config.ready) root._load(); }
    }
    Connections {
        target: Persistent
        function onReadyChanged() { if (Persistent.ready) root._load(); }
    }

    Component.onCompleted: {
        if (Config.ready && Persistent.ready) root._load();
    }
}
