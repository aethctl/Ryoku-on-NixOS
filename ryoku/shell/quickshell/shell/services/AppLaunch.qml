pragma Singleton

import Quickshell
import Ryoku.Ui.Singletons

// One launcher for XDG desktop entries. Quickshell parses Terminal=true into
// runInTerminal but spawns no terminal for it, so a TUI (btop, yazi, nvim) gets
// routed through ryoku-app, which owns the user's selected terminal.
//
// Launching goes through Spawn rather than DesktopEntry.execute(): execute()
// hands the child the desktop's whole environment, and a Quickshell app that
// inherits the crash handle can relaunch the desktop instead of starting.
//
// On NixOS, RYOKU_SYSTEMD_RUN points at the generation-owned systemd-run binary.
// User applications are launched into independent app.slice scopes so they do
// not become part of ryoku-shell.service and survive shell reloads/restarts.
//
// Other platforms keep the existing detached-launch behaviour.
Singleton {
    id: root

    function launch(command, workingDirectory) {
        if (!command || command.length === 0)
            return;

        Spawn.runApp(command, workingDirectory || "");
    }

    // run(entry) launches the entry; run(entry, action) launches one of its
    // actions, which inherit Terminal= from the entry that declares them.
    function run(entry, action) {
        const target = action || entry;
        if (!target)
            return;

        const argv = entry && entry.runInTerminal
            ? (target.command || [])
            : [];

        if (argv.length === 0) {
            root.launch(
                target.command,
                entry ? entry.workingDirectory : ""
            );
            return;
        }

        const command = ["ryoku-app", "terminal", "--"];

        for (let i = 0; i < argv.length; i++)
            command.push(String(argv[i]));

        root.launch(command);
    }
}
