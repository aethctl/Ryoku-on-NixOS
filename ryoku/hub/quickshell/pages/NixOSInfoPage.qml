pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons

// NixOS information: Musubi's built-in field guide for running Ryoku on NixOS.
// Read-only by design. It teaches the declarative workflow, shows the live Nix
// generation, and builds every command from the detected flake/host instead of
// assuming the user's machine is called "nixos".
Item {
    id: pg

    property var hub
    readonly property bool fullBleed: true

    readonly property string flakeRoot: Quickshell.env("RYOKU_NIX_FLAKE") || "/etc/nixos"

    property string host: "detecting…"
    property string nixosVersion: "detecting…"
    property string nixVersion: "detecting…"
    property string kernelVersion: "detecting…"
    property string generation: "detecting…"
    property string nixpkgsRevision: "detecting…"
    property string ryokuVersion: "detecting…"
    property string ryokuLatest: ""
    property string ryokuSource: "detecting…"
    property string ryokuChannel: "nix"
    property bool ryokuCanUpdate: false

    readonly property string shellName: {
        var s = Quickshell.env("SHELL") || "";
        var bits = s.split("/");
        return bits.length > 0 && bits[bits.length - 1].length > 0 ? bits[bits.length - 1] : "shell";
    }
    readonly property string shellRc: pg.shellName === "zsh" ? "~/.zshrc"
        : pg.shellName === "bash" ? "~/.bashrc"
        : pg.shellName === "fish" ? "~/.config/fish/config.fish"
        : "your shell config";
    readonly property string hostSafe: pg.host.indexOf("detecting") === 0 || pg.host.length === 0 ? "<host>" : pg.host
    readonly property string flakeRef: pg.flakeRoot + "#" + pg.hostSafe

    readonly property string rebuildCommand:
        "sudo nixos-rebuild switch --flake " + pg.flakeRef
    readonly property string testCommand:
        "sudo nixos-rebuild test --flake " + pg.flakeRef
    readonly property string packageUpdateCommand:
        "cd " + pg.flakeRoot + " && sudo nix flake update nixpkgs && sudo nixos-rebuild switch --flake " + pg.flakeRef
    readonly property string aliasBlock:
        "alias rebuild='sudo nixos-rebuild switch --flake " + pg.flakeRef + "'\n" +
        "alias nixtest='sudo nixos-rebuild test --flake " + pg.flakeRef + "'\n" +
        "alias nixup='cd " + pg.flakeRoot + " && sudo nix flake update nixpkgs && sudo nixos-rebuild switch --flake " + pg.flakeRef + "'\n" +
        "alias nixconf='cd " + pg.flakeRoot + "'\n" +
        "alias gens='nixos-rebuild list-generations'";

    readonly property var guideModel: [
        {
            "num": "01",
            "title": I18n.tr("Add packages"),
            "summary": I18n.tr("Declare software in your NixOS configuration, then rebuild."),
            "body": I18n.tr("Find the environment.systemPackages block used by your configuration and add the package name inside it. On Musubi, prefer this declarative route over nix-env so the package remains reproducible and survives clean rebuilds."),
            "code": "environment.systemPackages = with pkgs; [\n  firefox\n  kitty\n  <package>\n];"
        },
        {
            "num": "02",
            "title": I18n.tr("Find a package"),
            "summary": I18n.tr("Search nixpkgs before editing your package list."),
            "body": I18n.tr("Use nix search to find the exact nixpkgs attribute. Once you know the package name, add it to the appropriate package list and rebuild."),
            "code": "nix search nixpkgs <package>"
        },
        {
            "num": "03",
            "title": I18n.tr("Rebuild safely"),
            "summary": I18n.tr("Turn your configuration into a new NixOS generation."),
            "body": I18n.tr("switch builds the configuration and activates it immediately. test activates it without making it the default boot generation, which is useful when experimenting."),
            "code": pg.rebuildCommand + "\n\n# Temporary test\n" + pg.testCommand
        },
        {
            "num": "04",
            "title": I18n.tr("Update system packages"),
            "summary": I18n.tr("Move nixpkgs without unexpectedly moving every flake input."),
            "body": I18n.tr("Updating only nixpkgs refreshes normal system packages, NixOS, kernels and drivers while leaving separately pinned inputs alone. The rebuild then creates and activates the new generation."),
            "code": pg.packageUpdateCommand
        },
        {
            "num": "05",
            "title": I18n.tr("Update Ryoku"),
            "summary": I18n.tr("Use Ryoku's Nix updater for the Ryoku input itself."),
            "body": I18n.tr("On a normal GitHub flake input this advances only the Ryoku input and rebuilds. On a clean local Git checkout, Musubi can fast-forward the checkout, refresh its local flake hash and rebuild. A dirty or diverged checkout is refused so development work is never overwritten."),
            "code": "ryoku update"
        },
        {
            "num": "06",
            "title": I18n.tr("Edit flakes"),
            "summary": I18n.tr("flake.nix describes inputs and outputs; flake.lock pins exact revisions."),
            "body": I18n.tr("Edit flake.nix when adding or changing inputs and modules. Let Nix update flake.lock rather than hand-editing lock JSON. For a single input, target that input by name instead of updating everything."),
            "code": "sudoedit " + pg.flakeRoot + "/flake.nix\n\n# Update one input only\ncd " + pg.flakeRoot + " && sudo nix flake update <input>"
        },
        {
            "num": "07",
            "title": I18n.tr("Create useful aliases"),
            "summary": I18n.tr("Shorten the commands you use every day."),
            "body": I18n.tr("Add aliases to ") + pg.shellRc + I18n.tr(" and start a new shell. These examples are generated from this machine's detected flake target, so they do not assume the host is named nixos."),
            "code": pg.aliasBlock
        },
        {
            "num": "08",
            "title": I18n.tr("Generations and rollback"),
            "summary": I18n.tr("Every successful rebuild gives you a recovery point."),
            "body": I18n.tr("List generations to see what is installed. If a newly activated generation causes trouble, switch back to the previous generation or select an older generation from the boot menu."),
            "code": "nixos-rebuild list-generations\n\n# Return to the previous generation\nsudo nixos-rebuild switch --rollback"
        },
        {
            "num": "09",
            "title": I18n.tr("Kernel and driver updates"),
            "summary": I18n.tr("A rebuild can install a new kernel while the old kernel is still running."),
            "body": I18n.tr("If the configured kernel changed, reboot before diagnosing a kernel-module or NVIDIA library mismatch. The first command shows the running kernel; the second points at the kernel selected by the active generation."),
            "code": "uname -r\nreadlink -f /run/current-system/kernel"
        }
    ]

    Process {
        running: true
        command: ["nixos-version"]
        stdout: StdioCollector { onStreamFinished: pg.nixosVersion = text.trim() || "unknown" }
    }

    Process {
        running: true
        command: ["sh", "-c", "nix --version 2>/dev/null | sed 's/^nix (Nix) //'" ]
        stdout: StdioCollector { onStreamFinished: pg.nixVersion = text.trim() || "unknown" }
    }

    Process {
        running: true
        command: ["uname", "-r"]
        stdout: StdioCollector { onStreamFinished: pg.kernelVersion = text.trim() || "unknown" }
    }

    Process {
        running: true
        command: ["sh", "-c", "readlink /nix/var/nix/profiles/system 2>/dev/null | sed -n 's/.*system-\\([0-9][0-9]*\\)-link.*/\\1/p'" ]
        stdout: StdioCollector { onStreamFinished: pg.generation = text.trim() || "unknown" }
    }

    Process {
        running: true
        command: ["sh", "-c",
            "root=\"$1\"; cur=$(hostname); " +
            "hosts=$(nix eval --json \"$root#nixosConfigurations\" --apply builtins.attrNames 2>/dev/null | jq -r '.[]' 2>/dev/null || true); " +
            "for h in $hosts; do cfg=$(nix eval --raw \"$root#nixosConfigurations.$h.config.networking.hostName\" 2>/dev/null || true); " +
            "if [ \"$cfg\" = \"$cur\" ]; then printf '%s\\n' \"$h\"; exit 0; fi; done; " +
            "set -- $hosts; if [ -n \"${1:-}\" ]; then printf '%s\\n' \"$1\"; else printf '%s\\n' \"$cur\"; fi",
            "sh", pg.flakeRoot]
        stdout: StdioCollector { onStreamFinished: pg.host = text.trim() || "unknown" }
    }

    Process {
        running: true
        command: ["sh", "-c",
            "lock=\"$1/flake.lock\"; [ -r \"$lock\" ] || exit 0; " +
            "node=$(jq -r '.nodes.root.inputs.nixpkgs | if type == \"string\" then . elif type == \"array\" then .[-1] else empty end' \"$lock\" 2>/dev/null); " +
            "[ -n \"$node\" ] || exit 0; rev=$(jq -r --arg n \"$node\" '.nodes[$n].locked.rev // empty' \"$lock\"); " +
            "ts=$(jq -r --arg n \"$node\" '.nodes[$n].locked.lastModified // empty' \"$lock\"); " +
            "short=$(printf '%s' \"$rev\" | cut -c1-12); " +
            "if [ -n \"$ts\" ]; then d=$(date -d \"@$ts\" +%Y-%m-%d 2>/dev/null || true); else d=; fi; " +
            "if [ -n \"$short\" ] && [ -n \"$d\" ]; then printf '%s · %s\\n' \"$short\" \"$d\"; elif [ -n \"$short\" ]; then printf '%s\\n' \"$short\"; fi",
            "sh", pg.flakeRoot]
        stdout: StdioCollector { onStreamFinished: pg.nixpkgsRevision = text.trim() || "unknown" }
    }

    Process {
        running: true
        command: ["ryoku-nix-update", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(text);
                    pg.ryokuVersion = o.installedVersion || "unknown";
                    pg.ryokuLatest = o.latestVersion || "";
                    pg.ryokuSource = o.source || "unknown";
                    pg.ryokuChannel = o.channel || "nix";
                    pg.ryokuCanUpdate = o.canUpdate === true;
                } catch (e) {
                    pg.ryokuVersion = "unknown";
                }
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        color: Tokens.paper
    }

    Text {
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: Tokens.s7
        anchors.topMargin: -Tokens.s6
        text: "雪"
        color: Qt.rgba(Tokens.ink.r, Tokens.ink.g, Tokens.ink.b, 0.045)
        font.family: Tokens.jp
        font.pixelSize: 360
        z: 0
    }

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: content.implicitHeight + Tokens.s7 * 2
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        ScrollBar.vertical: ScrollRail {}

        Column {
            id: content
            x: Tokens.s7
            y: Tokens.s7
            width: Math.max(0, flick.width - Tokens.s7 * 2)
            spacing: Tokens.s7

            Grid {
                id: heroGrid
                width: parent.width
                columns: width >= 900 ? 2 : 1
                columnSpacing: Tokens.s7
                rowSpacing: Tokens.s4

                Column {
                    id: intro
                    width: heroGrid.columns === 1
                        ? heroGrid.width
                        : Math.max(320, heroGrid.width * 0.54 - heroGrid.columnSpacing / 2)
                    spacing: Tokens.s3

                    Row {
                        spacing: Tokens.s2
                        Rectangle { width: 18; height: 1; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
                        Text {
                            text: "雪"
                            color: Tokens.ink
                            font.family: Tokens.jp
                            font.pixelSize: Tokens.fMicro
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: I18n.tr("· NIXOS / MUSUBI")
                            color: Tokens.inkMuted
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fTiny
                            font.weight: Font.Medium
                            font.letterSpacing: Tokens.trackMark
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        width: parent.width
                        text: I18n.tr("NixOS information")
                        color: Tokens.ink
                        font.family: Tokens.display
                        font.pixelSize: Tokens.fHero
                        font.weight: Font.Medium
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        width: parent.width * 0.9
                        text: I18n.tr("A field guide for the declarative side of Ryoku — packages, flakes, rebuilds, updates, aliases and recovery, with commands generated for this machine.")
                        color: Tokens.inkMuted
                        font.family: Tokens.display
                        font.italic: true
                        font.pixelSize: Tokens.fBody + 2
                        wrapMode: Text.WordWrap
                    }
                }

                Rectangle {
                    width: heroGrid.columns === 1
                        ? heroGrid.width
                        : Math.max(300, heroGrid.width - intro.width - heroGrid.columnSpacing)
                    height: statusCol.implicitHeight + Tokens.s4 * 2
                    radius: Tokens.radius
                    color: "transparent"
                    border.width: Tokens.border
                    border.color: Tokens.line

                    Column {
                        id: statusCol
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: Tokens.s4
                        anchors.rightMargin: Tokens.s4
                        spacing: 0

                        InfoRow { label: I18n.tr("NIXOS"); value: pg.nixosVersion }
                        InfoRow { label: I18n.tr("NIX"); value: pg.nixVersion }
                        InfoRow { label: I18n.tr("KERNEL"); value: pg.kernelVersion }
                        InfoRow { label: I18n.tr("GENERATION"); value: pg.generation }
                        InfoRow { label: I18n.tr("HOST"); value: pg.host }
                        InfoRow { label: I18n.tr("NIXPKGS"); value: pg.nixpkgsRevision }
                        InfoRow { label: I18n.tr("RYOKU"); value: pg.ryokuVersion }
                        InfoRow { label: I18n.tr("SOURCE"); value: pg.ryokuSource; last: true }
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Tokens.line
            }

            Column {
                width: parent.width
                spacing: Tokens.s2
                Text {
                    text: I18n.tr("THE HANDBOOK")
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fTiny
                    font.weight: Font.Medium
                    font.letterSpacing: Tokens.trackMark
                }
                Text {
                    text: I18n.tr("Everyday NixOS")
                    color: Tokens.ink
                    font.family: Tokens.display
                    font.pixelSize: Tokens.fTitle
                }
                Text {
                    width: parent.width
                    text: I18n.tr("Open only what you need. Every command is safe to copy and uses the detected flake target where possible.")
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall
                    wrapMode: Text.WordWrap
                }
            }

            Column {
                id: guides
                width: parent.width
                spacing: Tokens.s3

                Repeater {
                    model: pg.guideModel
                    delegate: GuideCard {
                        required property var modelData
                        width: guides.width
                        num: modelData.num
                        title: modelData.title
                        summary: modelData.summary
                        body: modelData.body
                        code: modelData.code
                    }
                }
            }

            Rectangle {
                width: parent.width
                height: footer.implicitHeight + Tokens.s4 * 2
                radius: Tokens.radius
                color: Tokens.bone

                Row {
                    id: footer
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Tokens.s4
                    anchors.rightMargin: Tokens.s4
                    spacing: Tokens.s4

                    Text {
                        text: "雪"
                        color: Tokens.inkOnBone
                        font.family: Tokens.jp
                        font.pixelSize: Tokens.fValue
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Column {
                        width: parent.width - Tokens.fValue - Tokens.s4
                        spacing: Tokens.s1
                        Text {
                            text: I18n.tr("DECLARATIVE FIRST")
                            color: Tokens.inkOnBone
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fSmall
                            font.weight: Font.DemiBold
                            font.letterSpacing: Tokens.trackLabel
                        }
                        Text {
                            width: parent.width
                            text: I18n.tr("If a change belongs to the system, describe it in Nix and rebuild it. That is the rule that keeps Musubi reproducible instead of slowly turning into an imperative mystery box.")
                            color: Tokens.inkOnBoneDim
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fSmall
                            wrapMode: Text.WordWrap
                        }
                    }
                }
            }
        }
    }

    component InfoRow: Item {
        id: ir
        property string label: ""
        property string value: ""
        property bool last: false
        width: parent ? parent.width : 0
        height: Tokens.rowH - Tokens.s2

        Text {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: ir.label
            color: Tokens.inkMuted
            font.family: Tokens.ui
            font.pixelSize: Tokens.fMicro
            font.letterSpacing: Tokens.trackLabel
        }
        Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(100, parent.width * 0.66)
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideMiddle
            text: ir.value
            color: Tokens.ink
            font.family: Tokens.mono
            font.pixelSize: Tokens.fSmall
        }
        Rectangle {
            visible: !ir.last
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Tokens.border
            color: Tokens.lineSoft
        }
    }

    component GuideCard: Rectangle {
        id: card
        property string num: ""
        property string title: ""
        property string summary: ""
        property string body: ""
        property string code: ""
        property bool expanded: false

        readonly property int closedH: 76
        readonly property int openH: closedH + details.implicitHeight + Tokens.s4

        height: card.expanded ? card.openH : card.closedH
        radius: Tokens.radius
        color: cardHover.hovered ? Qt.rgba(Tokens.ink.r, Tokens.ink.g, Tokens.ink.b, 0.035) : "transparent"
        border.width: Tokens.border
        border.color: card.expanded || cardHover.hovered ? Tokens.lineStrong : Tokens.line
        clip: true

        HoverHandler { id: cardHover; cursorShape: Qt.ArrowCursor }

        Row {
            id: cardHead
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: card.closedH
            anchors.leftMargin: Tokens.s4
            anchors.rightMargin: Tokens.s4
            spacing: Tokens.s4

            HoverHandler { cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: card.expanded = !card.expanded }

            Text {
                width: 34
                anchors.verticalCenter: parent.verticalCenter
                text: card.num
                color: Tokens.inkFaint
                font.family: Tokens.mono
                font.pixelSize: Tokens.fSmall
            }
            Column {
                width: parent.width - 34 - 46 - parent.spacing * 2
                anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.s1
                Text {
                    width: parent.width
                    text: card.title
                    color: Tokens.ink
                    font.family: Tokens.display
                    font.pixelSize: Tokens.fRow
                    font.weight: Font.Medium
                }
                Text {
                    width: parent.width
                    text: card.summary
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall
                    elide: Text.ElideRight
                }
            }
            Text {
                width: 46
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: card.expanded ? "−" : "+"
                color: Tokens.ink
                font.family: Tokens.mono
                font.pixelSize: Tokens.fValue
            }
        }

        Column {
            id: details
            visible: card.expanded
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: cardHead.bottom
            anchors.leftMargin: Tokens.s4
            anchors.rightMargin: Tokens.s4
            spacing: Tokens.s3

            Rectangle {
                width: parent.width
                height: Tokens.border
                color: Tokens.lineSoft
            }

            Text {
                width: parent.width
                text: card.body
                color: Tokens.inkDim
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall
                lineHeight: 1.25
                wrapMode: Text.WordWrap
            }

            CodeBlock {
                width: parent.width
                code: card.code
            }
        }
    }

    component CodeBlock: Rectangle {
        id: block
        property string code: ""
        property bool copied: false

        height: Math.max(58, codeText.implicitHeight + Tokens.s4 * 2)
        radius: Tokens.radius
        color: Qt.rgba(Tokens.ink.r, Tokens.ink.g, Tokens.ink.b, 0.045)
        border.width: Tokens.border
        border.color: Tokens.lineSoft

        TextEdit {
            id: codeText
            anchors.left: parent.left
            anchors.right: copy.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: Tokens.s4
            anchors.rightMargin: Tokens.s3
            anchors.topMargin: Tokens.s3
            anchors.bottomMargin: Tokens.s3
            text: block.code
            color: Tokens.ink
            font.family: Tokens.mono
            font.pixelSize: Tokens.fSmall
            readOnly: true
            selectByMouse: true
            wrapMode: TextEdit.Wrap
            verticalAlignment: TextEdit.AlignVCenter
        }

        Rectangle {
            id: copy
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: Tokens.s3
            anchors.topMargin: Tokens.s3
            width: copyLabel.implicitWidth + Tokens.s3 * 2
            height: 28
            radius: Tokens.radius
            color: copyHover.hovered || block.copied ? Tokens.bone : "transparent"
            border.width: Tokens.border
            border.color: copyHover.hovered || block.copied ? Tokens.bone : Tokens.lineStrong

            Text {
                id: copyLabel
                anchors.centerIn: parent
                text: block.copied ? I18n.tr("COPIED") : I18n.tr("COPY")
                color: copyHover.hovered || block.copied ? Tokens.inkOnBone : Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: Tokens.fMicro
                font.weight: Font.Medium
                font.letterSpacing: Tokens.trackLabel
            }
            HoverHandler { id: copyHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
                onTapped: {
                    codeText.forceActiveFocus();
                    codeText.selectAll();
                    codeText.copy();
                    codeText.deselect();
                    block.copied = true;
                    copiedReset.restart();
                }
            }
            Timer {
                id: copiedReset
                interval: 1200
                onTriggered: block.copied = false
            }
        }
    }
}
