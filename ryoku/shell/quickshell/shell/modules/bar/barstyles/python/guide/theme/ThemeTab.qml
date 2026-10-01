import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Effects
import Quickshell
import Quickshell.Io
import "../../"
import "../../reusables"

Item {
    id: themeTabRoot
    required property var rootObj
    required property int tabIndex

    anchors.fill: parent
    visible: rootObj.currentTab === tabIndex
    opacity: visible ? 1.0 : 0.0
    property real slideY: visible ? 0 : rootObj.s(10)

    Behavior on slideY { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    transform: Translate { y: themeTabRoot.slideY }
    Behavior on opacity { NumberAnimation { duration: 250 } }

    property var defaultThemeSettings: {
        "fontFamily": ThemeBackend.fontFamily,
        "borderRadius": ThemeBackend.borderRadius,
        "activePreset": "Matugen",
        "matugen": true,
        "colors": {}
    }

    property var themeSettings: Config.getSetting("theme", defaultThemeSettings)
    property string currentFontFamily: Config.globalFontFamily
    property int currentBorderRadius: themeSettings.borderRadius !== undefined ? themeSettings.borderRadius : ThemeBackend.borderRadius
    property string currentPreset: themeSettings.activePreset !== undefined ? themeSettings.activePreset : "Matugen"

    readonly property var curatedFonts: ["Iosevka Nerd Font", "JetBrainsMono Nerd Font", "JetBrains Mono"]
    property var blockedFontPatterns: [".notdef", "cursor", "emoji", "symbol", "pcf"]
    property var availableFonts: []

    function loadAvailableFonts() {
        if (availableFonts.length > 0) return;
        let curated = themeTabRoot.curatedFonts;
        let dedupedCurated = [];
        let seen = new Set();

        for (let i = 0; i < curated.length; i++) {
            let key = curated[i].toLowerCase().trim();
            if (!seen.has(key)) {
                seen.add(key);
                dedupedCurated.push(curated[i]);
            }
        }

        let rest = [];
        let raw = Qt.fontFamilies();
        for (let i = 0; i < raw.length; i++) {
            let name = raw[i];
            let key = name.toLowerCase().trim();

            if (seen.has(key)) continue;

            let blocked = false;
            for (let j = 0; j < themeTabRoot.blockedFontPatterns.length; j++) {
                if (key.indexOf(themeTabRoot.blockedFontPatterns[j]) !== -1) {
                    blocked = true;
                    break;
                }
            }
            if (blocked) continue;

            seen.add(key);
            rest.push(name);
        }
        rest.sort(function(a, b) { return a.localeCompare(b); });
        let combined = dedupedCurated.concat(rest);
        if (themeTabRoot.currentFontFamily && combined.indexOf(themeTabRoot.currentFontFamily) === -1) {
            combined.push(themeTabRoot.currentFontFamily);
        }
        themeTabRoot.availableFonts = combined;
    }

    property var systemPresets: []
    property var userPresets: []
    property string themeSearchText: ""
    property string _lastPresetsStr: ""
    property bool _needsReload: true

    property var filteredUserPresets: {
        let txt = themeSearchText.trim().toLowerCase();
        if (txt === "") return themeTabRoot.userPresets;
        let res = [];
        for (let i = 0; i < themeTabRoot.userPresets.length; i++) {
            let p = themeTabRoot.userPresets[i];
            if (p && p.name && p.name.toLowerCase().indexOf(txt) !== -1) {
                res.push(p);
            }
        }
        return res;
    }

    property var filteredSystemPresets: {
        let txt = themeSearchText.trim().toLowerCase();
        let result = [];
        let pendingDivider = false;
        for (let i = 0; i < themeTabRoot.systemPresets.length; i++) {
            let p = themeTabRoot.systemPresets[i];
            if (p.isDivider) {
                pendingDivider = true;
            } else {
                if (txt === "" || (p.name && p.name.toLowerCase().indexOf(txt) !== -1)) {
                    if (pendingDivider) {
                        result.push({ isDivider: true });
                        pendingDivider = false;
                    }
                    result.push(p);
                }
            }
        }
        return result;
    }


    property string activeScreenName: (Quickshell.screens && Quickshell.screens.length > 0 && Quickshell.screens[0].name) ? Quickshell.screens[0].name : ""
    property string currentWallpaperPath: ""
    property int wallpaperRevision: 0
    property bool wallpaperIsLive: false
    readonly property bool isWallpaperVideo: wallpaperIsLive

    property real tileWidth: (typeof themesSectionCol !== "undefined" && themesSectionCol && themesSectionCol.width > 0) ? Math.max(0, (themesSectionCol.width - rootObj.s(20)) / 3) : Math.max(0, (themeTabRoot.width - rootObj.s(72)) / 3)

    Timer {
        id: borderRadiusDebounceTimer
        interval: 250
        repeat: false
        onTriggered: {
            themeTabRoot.updateBorderRadiusSetting();
        }
    }

    function getSnappedRadius(rawVal) {
        let snapPoints = [0, 2, 4, 8, 10, 16, 24, 32, 48, 52, 58, 64];
        let rounded = Math.round(rawVal);
        let closest = snapPoints[0];
        let minDiff = Math.abs(rounded - snapPoints[0]);
        for (let i = 1; i < snapPoints.length; i++) {
            let diff = Math.abs(rounded - snapPoints[i]);
            if (diff < minDiff) {
                minDiff = diff;
                closest = snapPoints[i];
            }
        }
        if (minDiff <= 2) {
            return closest;
        }
        return rounded;
    }

    // Ryoku seam: ryogami owns the wallpaper. The preview reads its `wallpaper`
    // topic frame straight off the daemon socket (the same retained frame the
    // shell's own backdrop bridge subscribes to), instead of serpantinum's
    // cache files and its private `ipc call wallpaper` fetcher.
    readonly property string ryogamiSock: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryogami.sock"

    Socket {
        id: wallpaperFeed
        path: themeTabRoot.ryogamiSock
        property string screenName: themeTabRoot.activeScreenName
        parser: SplitParser {
            splitMarker: ""
            onRead: data => {
                try {
                    let state = JSON.parse(data);
                    let entry = (state.outputs && state.outputs[wallpaperFeed.screenName]) || state.default;
                    if (!entry) return;
                    let p = entry.path || "";
                    let live = entry.live === true;
                    if (p !== themeTabRoot.currentWallpaperPath || live !== themeTabRoot.wallpaperIsLive) {
                        themeTabRoot.currentWallpaperPath = p;
                        themeTabRoot.wallpaperIsLive = live;
                        themeTabRoot.wallpaperRevision++;
                    }
                } catch (e) {}
            }
        }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) {
                write("subscribe wallpaper\n");
                flush();
            }
        }
    }

    function activateTab() {
        themeTabRoot.loadAvailableFonts();
        if (themeTabRoot._needsReload) {
            themeTabRoot._needsReload = false;
            themeTabRoot.reloadThemes();
        }
    }

    onVisibleChanged: {
        if (visible) {
            activateTab();
        } else {
            if (fontDropdown.isOpen) fontDropdown.closePopup();
            themeEditorPopup.close();
        }
    }

    // Ryoku seam: the dynamic tile ("Matugen" in serpantinum) is Ryoku's live
    // wallpaper palette itself, so it previews straight off ThemeBackend.
    function getCardBase(m) { return m.isMatugen ? ThemeBackend.base : (m.colors && m.colors.base ? m.colors.base : ThemeBackend.base); }
    function getCardText(m) { return m.isMatugen ? ThemeBackend.text : (m.colors && m.colors.text ? m.colors.text : ThemeBackend.text); }
    function getCardDots(m) {
        if (m.isMatugen) return [ThemeBackend.base, ThemeBackend.blue, ThemeBackend.mauve, ThemeBackend.peach, ThemeBackend.green, ThemeBackend.red];
        if (m.colors) return [m.colors.text || ThemeBackend.text, m.colors.blue || ThemeBackend.blue, m.colors.mauve || ThemeBackend.mauve, m.colors.peach || ThemeBackend.peach, m.colors.green || ThemeBackend.green, m.colors.red || ThemeBackend.red];
        return [];
    }

    function reloadThemes() {
        themesLoader.running = false;
        themesLoader.running = true;
    }

    Process {
        id: themesLoader
        running: false
        command: {
            let assetsPath = Caching.serpantinumDir ? (Caching.assetsPath + "/themes") : "";
            let userPath = Caching.stateDir ? (Caching.stateDir + "/themes") : (Caching.home + "/.local/state/serpantinum/themes");
            let cachePath = Caching.getCacheDir("themes") + "/theme_sort_cache.json";
            let scriptPath = Caching.qsDir ? (Caching.qsDir + "/guide/theme/theme_sorter.py") : "theme_sorter.py";
            return ["python3", scriptPath, assetsPath, userPath, cachePath];
        }
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let txt = this.text.trim();
                    if (txt === "" || txt === themeTabRoot._lastPresetsStr) return;
                    themeTabRoot._lastPresetsStr = txt;
                    let data = JSON.parse(txt);
                    if (Array.isArray(data) && data.length > 0) {
                        let sys = [];
                        let usr = [];
                        let len = data.length;
                        for (let i = 0; i < len; i++) {
                            let item = data[i];
                            if (item.isCustom === true || item.category === "user") {
                                usr.push(item);
                            } else {
                                sys.push(item);
                            }
                        }
                        if (themeTabRoot.systemPresets.length === 0) {
                            themeTabRoot.systemPresets = sys;
                        }
                        themeTabRoot.userPresets = usr;
                    }
                } catch(e) {}
            }
        }
    }

    Timer {
        id: reloadThemesTimer
        interval: 150
        repeat: false
        onTriggered: themeTabRoot.reloadThemes()
    }

    Component.onCompleted: {
        activateTab();
    }

    function saveCustomTheme(themeObj) {
        let userPath = Caching.stateDir ? (Caching.stateDir + "/themes") : (Caching.home + "/.local/state/serpantinum/themes");
        let sanitizeName = themeObj.name.replace(/[^a-zA-Z0-9_\- ]/g, "").trim();
        if (sanitizeName === "") sanitizeName = "CustomTheme";
        themeObj.name = sanitizeName;
        themeObj.isCustom = true;
        themeObj.category = "user";
        let jsonStr = JSON.stringify(themeObj, null, 2);
        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
        let filePath = userPath + "/" + sanitizeName + ".json";
        let cmd = "mkdir -p \"" + escapeBash(userPath) + "\" && echo \"" + escapeBash(jsonStr) + "\" > \"" + escapeBash(filePath) + "\"";
        Quickshell.execDetached(["bash", "-c", cmd]);

        let arr = themeTabRoot.userPresets.filter(t => t.name !== themeObj.name);
        arr.push(themeObj);
        themeTabRoot.userPresets = arr;
    }

    function deleteCustomTheme(themeName) {
        let userPath = Caching.stateDir ? (Caching.stateDir + "/themes") : (Caching.home + "/.local/state/serpantinum/themes");
        let sanitizeName = themeName.replace(/[^a-zA-Z0-9_\- ]/g, "").trim();
        let filePath = userPath + "/" + sanitizeName + ".json";
        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
        let cmd = "rm -f \"" + escapeBash(filePath) + "\"";
        Quickshell.execDetached(["bash", "-c", cmd]);

        themeTabRoot.userPresets = themeTabRoot.userPresets.filter(t => t.name !== themeName);
    }

    Connections {
        target: Config
        function onSettingsLoaded() {
            let ts = Config.getSetting("theme", themeTabRoot.defaultThemeSettings);
            themeTabRoot.currentFontFamily = Config.globalFontFamily;
            themeTabRoot.currentBorderRadius = ts.borderRadius !== undefined ? ts.borderRadius : ThemeBackend.borderRadius;
            themeTabRoot.currentPreset = ts.activePreset !== undefined ? ts.activePreset : "Matugen";
            themeTabRoot.themeSettings = ts;
        }
    }

    // Ryoku keeps one system font; the style's picker writes that global key
    // through the daemon (the same write the Hub's Personalization page makes),
    // so the desktop retunes as a whole instead of the style drifting alone.
    function updateFontSetting() {
        Config.setGlobalFontFamily(themeTabRoot.currentFontFamily);
    }

    function updateBorderRadiusSetting() {
        let current = Config.getSetting("theme", themeTabRoot.defaultThemeSettings);
        current.borderRadius = themeTabRoot.currentBorderRadius;
        Config.setSetting("theme", current);
        if (typeof ThemeBackend !== "undefined") {
            ThemeBackend.reloadColors();
        }
    }

    function applyPreset(modelData) {
        if (!modelData) return;

        let isMatugen = modelData.isMatugen === true;
        themeTabRoot.currentPreset = modelData.name;

        // The style's palette override lives under its own shell.json key;
        // an empty colours object means follow Ryoku's live wallpaper palette.
        let current = Config.getSetting("theme", themeTabRoot.defaultThemeSettings);
        current.activePreset = modelData.name;
        current.colors = isMatugen ? ({}) : (modelData.colors || ({}));
        Config.setSetting("theme", current);

        if (typeof ThemeBackend !== "undefined") {
            ThemeBackend.reloadColors();
        }
    }

    Component {
        id: presetDelegateComp
        Loader {
            id: delegateLoader
            asynchronous: true
            Layout.columnSpan: modelData.isDivider === true ? 3 : 1
            Layout.fillWidth: modelData.isDivider === true
            Layout.preferredWidth: modelData.isDivider === true ? -1 : themeTabRoot.tileWidth
            Layout.maximumWidth: modelData.isDivider === true ? -1 : themeTabRoot.tileWidth
            Layout.preferredHeight: modelData.isDivider === true ? rootObj.s(17) : rootObj.s(44)
            sourceComponent: modelData.isDivider === true ? dividerComp : tileComp
            property var themeData: modelData
            property int itemIndex: index
        }
    }

    Component {
        id: dividerComp
        Item {
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: 1
                color: Qt.alpha(ThemeBackend.surface1, 0.4)
            }
        }
    }

    Component {
        id: tileComp
        Rectangle {
            id: delegateContainer
            property var modelData: parent.themeData
            property int itemIndex: parent.itemIndex

            radius: ThemeBackend.borderRadius
            color: delegateContainer.baseC

            opacity: 0.0
            scale: (presetMouse.pressed ? 0.96 : (delegateContainer.isHovered ? 1.03 : 1.0)) * popScale

            property bool isSelected: themeTabRoot.currentPreset === modelData.name
            property real flashOpacity: 0.0
            property real popScale: 1.0

            property color baseC: themeTabRoot.getCardBase(modelData)
            property color textC: themeTabRoot.getCardText(modelData)

            HoverHandler {
                id: delegateHover
            }

            property bool isHovered: delegateHover.hovered

            Component.onCompleted: {
                popInTimer.start();
            }

            Timer {
                id: popInTimer
                interval: Math.min(delegateContainer.itemIndex * 10, 200)
                onTriggered: delegateContainer.opacity = 1.0
            }

            Behavior on opacity { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }
            Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutQuint } }

            Loader {
                anchors.fill: parent
                active: modelData.isMatugen === true && themeTabRoot.currentWallpaperPath !== ""
                sourceComponent: Item {
                    anchors.fill: parent

                    Rectangle {
                        id: matugenMask
                        anchors.fill: parent
                        radius: ThemeBackend.borderRadius
                        color: "black"
                        visible: false
                        layer.enabled: true
                    }

                    Item {
                        id: matugenContent
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true

                        Image {
                            id: matugenWall
                            anchors.fill: parent
                            source: "file://" + themeTabRoot.currentWallpaperPath
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            smooth: true
                            mipmap: true
                            cache: false
                            sourceSize.width: delegateContainer.width
                            sourceSize.height: delegateContainer.height
                        }

                        MultiEffect {
                            anchors.fill: parent
                            source: matugenWall
                            blurEnabled: true
                            blurMax: 4
                            blur: 0.4
                            colorizationColor: delegateContainer.baseC
                            colorization: 0.35
                            opacity: 0.85
                        }

                        Rectangle {
                            anchors.fill: parent
                            radius: ThemeBackend.borderRadius
                            gradient: Gradient {
                                GradientStop { position: 0.0; color: "transparent" }
                                GradientStop { position: 0.35; color: "transparent" }
                                GradientStop { position: 1.0; color: Qt.alpha(delegateContainer.baseC, 0.55) }
                            }
                        }
                    }

                    MultiEffect {
                        anchors.fill: parent
                        source: matugenContent
                        maskEnabled: true
                        maskSource: matugenMask
                    }
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
                color: delegateContainer.textC
                opacity: delegateContainer.isSelected ? 0.15 : (delegateContainer.isHovered ? 0.08 : 0.0)
                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            Rectangle {
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
                color: "#ffffff"
                opacity: delegateContainer.flashOpacity
                PropertyAnimation on opacity { id: btnFlashAnim; to: 0; duration: 350; easing.type: Easing.OutExpo }
            }

            Rectangle {
                anchors.fill: parent
                radius: ThemeBackend.borderRadius
                color: "transparent"
                border.color: delegateContainer.isSelected ? delegateContainer.textC : "transparent"
                border.width: delegateContainer.isSelected ? 2 : 0
                Behavior on border.color { ColorAnimation { duration: 150 } }
            }

            SequentialAnimation {
                id: btnPopAnim
                NumberAnimation { target: delegateContainer; property: "popScale"; to: 1.04; duration: 100; easing.type: Easing.OutQuad }
                NumberAnimation { target: delegateContainer; property: "popScale"; to: 1.0; duration: 350; easing.type: Easing.OutQuint }
            }

            MouseArea {
                id: presetMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    btnPopAnim.start();
                    delegateContainer.flashOpacity = 0.15;
                    btnFlashAnim.start();
                    if (typeof Sounds !== "undefined") {
                        Sounds.playSfx("reusables/clickbutton/click.wav");
                    }
                    themeTabRoot.applyPreset(delegateContainer.modelData);
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: rootObj.s(10)
                anchors.rightMargin: rootObj.s(modelData.isCustom === true ? 6 : 10)
                spacing: rootObj.s(6)

                Text {
                    text: modelData.name
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: rootObj.s(11)
                    font.weight: delegateContainer.isSelected ? Font.Bold : Font.Medium
                    color: delegateContainer.textC
                    Layout.alignment: Qt.AlignVCenter
                    Layout.fillWidth: true
                    Layout.minimumWidth: 0
                    elide: Text.ElideRight
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                Row {
                    Layout.alignment: Qt.AlignVCenter
                    spacing: rootObj.s(4)

                    Repeater {
                        model: themeTabRoot.getCardDots(delegateContainer.modelData)
                        Rectangle {
                            width: rootObj.s(8)
                            height: rootObj.s(8)
                            radius: rootObj.s(4)
                            color: modelData
                        }
                    }
                }

                DeleteButton {
                    visible: modelData.isCustom === true
                    size: rootObj.s(24)
                    cornerRadius: Math.min(ThemeBackend.borderRadius, rootObj.s(6))
                    iconFontSize: rootObj.s(12)
                    Layout.alignment: Qt.AlignVCenter
                    onClicked: {
                        themeTabRoot.deleteCustomTheme(delegateContainer.modelData.name);
                    }
                }
            }
        }
    }

    ThemeEditor {
        id: themeEditorPopup
        rootObj: themeTabRoot.rootObj
        tileWidth: themeTabRoot.tileWidth
        onSaveRequested: function(themeObj) {
            themeTabRoot.saveCustomTheme(themeObj);
            themeTabRoot.applyPreset(themeObj);
        }
    }

    property var currentPreviewLoader: null

    Component {
        id: dynamicFontLoaderComp
        FontLoader {}
    }

    Timer {
        id: fontLoadDelay
        interval: 100
        property string targetPath: ""
        onTriggered: {
            if (themeTabRoot.currentPreviewLoader) {
                themeTabRoot.currentPreviewLoader.destroy();
                themeTabRoot.currentPreviewLoader = null;
            }

            if (targetPath !== "") {
                themeTabRoot.currentPreviewLoader = dynamicFontLoaderComp.createObject(themeTabRoot, { source: "file://" + targetPath });
            }

            fontPickerPopup.close();
        }
    }

    Process {
        id: fontInstallProcess
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                let out = this.text.trim();
                if (out !== "") {
                    let idx = out.indexOf('|');
                    if (idx !== -1) {
                        let fName = out.substring(0, idx).trim();
                        let fPath = out.substring(idx + 1).trim();

                        Quickshell.execDetached(["fc-cache", "-f"]);

                        themeTabRoot.currentFontFamily = fName;
                        themeTabRoot.updateFontSetting();

                        if (themeTabRoot.availableFonts.indexOf(fName) === -1) {
                            let arr = themeTabRoot.availableFonts.slice();
                            arr.push(fName);
                            themeTabRoot.availableFonts = arr;
                        }

                        fontLoadDelay.targetPath = fPath;
                        fontLoadDelay.start();
                    }
                }
            }
        }
    }

    function installFont(filePath, fileName) {
        if (!filePath || filePath.trim() === "" || !fileName || fileName.trim() === "") {
            return;
        }

        let userFontsPath = (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/fonts";
        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };

        let script =
            "D=\"" + escapeBash(userFontsPath) + "\"; " +
            "B=\"" + escapeBash(fileName) + "\"; " +
            "S=\"" + escapeBash(filePath) + "\"; " +
            "mkdir -p \"$D\"; " +
            "if [ ! -f \"$D/$B\" ]; then cp \"$S\" \"$D/$B\"; fi; " +
            "F=\"$D/$B\"; " +
            "FAM=$(fc-query -f \"%{family}\" \"$F\" 2>/dev/null | cut -d, -f1); " +
            "if [ -z \"$FAM\" ]; then FAM=$(basename \"$F\" | sed 's/\\.[^.]*$//'); fi; " +
            "STL=$(fc-query -f \"%{style}\" \"$F\" 2>/dev/null | cut -d, -f1); " +
            "if [ -n \"$STL\" ] && [ \"$STL\" != \"Regular\" ]; then " +
                "echo \"$FAM $STL|$F\"; " +
            "else " +
                "echo \"$FAM|$F\"; " +
            "fi;";

        fontInstallProcess.command = ["bash", "-c", script];
        fontInstallProcess.running = true;
    }

    FontPicker {
        id: fontPickerPopup
        rootObj: themeTabRoot.rootObj
        onFontSelected: function(filePath, fileName) {
            if (filePath && filePath.trim() !== "" && fileName && fileName.trim() !== "") {
                themeTabRoot.installFont(filePath, fileName);
            }
        }
    }

    Flickable {
        anchors.fill: parent
        anchors.topMargin: rootObj.s(4)
        anchors.leftMargin: rootObj.s(8)
        anchors.rightMargin: rootObj.s(8)
        anchors.bottomMargin: rootObj.s(4)
        contentHeight: settingsCol.implicitHeight
        contentWidth: width
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: settingsCol
            x: rootObj.s(6)
            width: parent.width - rootObj.s(12)
            spacing: rootObj.s(6)

            Item {
                id: wpPreviewContainer
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.preferredHeight: rootObj.s(220)
                Layout.topMargin: rootObj.s(6)
                Layout.bottomMargin: rootObj.s(4)

                Rectangle {
                    id: wpCardMask
                    anchors.fill: parent
                    radius: ThemeBackend.borderRadius
                    color: "black"
                    visible: false
                    layer.enabled: true
                }

                Item {
                    id: wpCardContent
                    anchors.fill: parent
                    visible: false
                    layer.enabled: true

                    Rectangle {
                        id: wpCardBg
                        anchors.fill: parent
                        radius: ThemeBackend.borderRadius
                        color: ThemeBackend.surface0
                    }

                    Image {
                        id: wpCardImage
                        anchors.fill: parent
                        source: themeTabRoot.currentWallpaperPath ? "file://" + themeTabRoot.currentWallpaperPath : ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        smooth: true
                        mipmap: true
                        cache: false
                        visible: source !== ""
                    }

                    Rectangle {
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: rootObj.s(64)
                        radius: ThemeBackend.borderRadius
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.25; color: Qt.rgba(0, 0, 0, 0.35) }
                            GradientStop { position: 1.0; color: Qt.rgba(0, 0, 0, 0.8) }
                        }
                    }
                }

                MultiEffect {
                    anchors.fill: parent
                    source: wpCardContent
                    maskEnabled: true
                    maskSource: wpCardMask
                }

                IconButton {
                    id: videoIndicator
                    visible: themeTabRoot.isWallpaperVideo
                    anchors.centerIn: parent
                    size: rootObj.s(50)
                    cornerRadius: rootObj.s(16)
                    iconFontSize: rootObj.s(20)
                    buttonIcon: "󰐊"
                    accentColor: ThemeBackend.surface0
                    textColor: ThemeBackend.text
                    opacity: 1.0
                    enabled: false
                }

                RowLayout {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: rootObj.s(12)
                    spacing: rootObj.s(12)

                    ClickButton {
                        id: wpSelectBtn
                        Layout.preferredHeight: rootObj.s(32)
                        cornerRadius: ThemeBackend.borderRadius
                        horizontalPadding: rootObj.s(14)
                        buttonIcon: "󰸉"
                        iconFontSize: rootObj.s(15)
                        buttonText: "Select wallpaper"
                        textFontSize: rootObj.s(11)
                        accentColor: ThemeBackend.mauve
                        textColor: ThemeBackend.base
                        contentAlignment: Qt.AlignHCenter
                        onClicked: {
                            Quickshell.execDetached(["bash", Caching.scriptsPath + "/qs_manager.sh", "toggle", "wallpaper"]);
                        }
                    }

                    Item { Layout.fillWidth: true }

                    MouseArea {
                        id: wpPathMa
                        Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                        implicitWidth: wpPathCol.implicitWidth
                        implicitHeight: wpPathCol.implicitHeight
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (themeTabRoot.currentWallpaperPath && themeTabRoot.currentWallpaperPath !== "") {
                                let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
                                Quickshell.execDetached(["bash", "-c", "xdg-open \"$(dirname \"" + escapeBash(themeTabRoot.currentWallpaperPath) + "\")\""]);
                            }
                        }

                        ColumnLayout {
                            id: wpPathCol
                            anchors.right: parent.right
                            spacing: rootObj.s(1)

                            Text {
                                text: {
                                    if (!themeTabRoot.currentWallpaperPath) return "No Wallpaper Selected";
                                    let fn = themeTabRoot.currentWallpaperPath.split("/").pop();
                                    return fn || themeTabRoot.currentWallpaperPath;
                                }
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(12)
                                font.weight: Font.Bold
                                color: "#ffffff"
                                Layout.alignment: Qt.AlignRight
                                elide: Text.ElideLeft
                                Layout.maximumWidth: rootObj.s(320)
                            }

                            Text {
                                text: themeTabRoot.currentWallpaperPath ? themeTabRoot.currentWallpaperPath.replace(Quickshell.env("HOME"), "~") : ""
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(10)
                                color: Qt.rgba(1, 1, 1, 0.75)
                                Layout.alignment: Qt.AlignRight
                                elide: Text.ElideLeft
                                Layout.maximumWidth: rootObj.s(320)
                                visible: text !== ""
                            }
                        }
                    }
                }
            }

            SettingsRow {
                rootObj: themeTabRoot.rootObj
                icon: "󰛖"
                title: I18n.t("guide.theme.font.title")
                description: I18n.t("guide.theme.font.desc")

                IconButton {
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    cornerRadius: rootObj.s(6)
                    buttonIcon: "󰉋"
                    iconOffsetX: -2
                    iconFontSize: rootObj.s(14)
                    accentColor: ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                    onClicked: {
                        let userFontsPath = (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/fonts";
                        let escapeBash = function(str) { return String(str).replace(/(["\\$`])/g, '\\$1'); };
                        Quickshell.execDetached(["bash", "-c", "mkdir -p \"" + escapeBash(userFontsPath) + "\" && xdg-open \"" + escapeBash(userFontsPath) + "\""]);
                    }
                }

                IconButton {
                    Layout.preferredWidth: rootObj.s(32)
                    Layout.preferredHeight: rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    cornerRadius: rootObj.s(6)
                    buttonIcon: "󰐕"
                    iconFontSize: rootObj.s(14)
                    accentColor: ThemeBackend.surface0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                    onClicked: fontPickerPopup.openPicker()
                }

                Dropdown {
                    id: fontDropdown
                    Layout.preferredWidth: rootObj.s(220)
                    Layout.preferredHeight: rootObj.s(32)
                    Layout.alignment: Qt.AlignVCenter
                    options: themeTabRoot.availableFonts
                    currentIndex: options.indexOf(themeTabRoot.currentFontFamily) >= 0 ? options.indexOf(themeTabRoot.currentFontFamily) : 0
                    placeholderText: I18n.t("guide.theme.font.select")
                    fontFamily: ThemeBackend.fontFamily
                    useOptionAsFontFamily: true
                    accentColor: ThemeBackend.mauve
                    baseColor: ThemeBackend.surface0
                    hoverColor: ThemeBackend.surface1
                    dropdownColor: ThemeBackend.surface0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    textColor: ThemeBackend.text
                    activeTextColor: ThemeBackend.crust
                    cornerRadius: ThemeBackend.borderRadius
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: function(index, value) {
                        themeTabRoot.currentFontFamily = value;
                        themeTabRoot.updateFontSetting();
                    }
                    onClicked: {
                        themeTabRoot.loadAvailableFonts();
                    }
                }
            }

            SettingsRow {
                rootObj: themeTabRoot.rootObj
                icon: "󰞁"
                title: I18n.t("guide.theme.radius.title")
                description: I18n.t("guide.theme.radius.desc")

                NumberSelector {
                    id: radiusSelector
                    implicitWidth: rootObj.s(150)
                    implicitHeight: rootObj.s(32)
                    from: 0
                    to: 64
                    stepSize: 1
                    decimals: 0
                    suffix: "px"
                    value: themeTabRoot.currentBorderRadius
                    baseColor: ThemeBackend.surface0
                    accentColor: ThemeBackend.mauve
                    buttonColor: ThemeBackend.surface1
                    buttonTextColor: ThemeBackend.text
                    textColor: ThemeBackend.text
                    subTextColor: ThemeBackend.subtext0
                    borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                    cornerRadius: ThemeBackend.borderRadius
                    fontFamily: ThemeBackend.fontFamily
                    fontPixelSize: rootObj.s(11)
                    onValueChanged: function(val) {
                        let num = (typeof val === "number" && !isNaN(val)) ? val : value;
                        let rounded = Math.round(num);
                        let snapped = themeTabRoot.getSnappedRadius(rounded);
                        if (!isNaN(snapped) && snapped >= 0 && snapped <= 64 && themeTabRoot.currentBorderRadius !== snapped) {
                            themeTabRoot.currentBorderRadius = snapped;
                            borderRadiusDebounceTimer.restart();
                        }
                    }
                    onTriggered: {
                        let rounded = Math.round(radiusSelector.value);
                        let snapped = themeTabRoot.getSnappedRadius(rounded);
                        themeTabRoot.currentBorderRadius = snapped;
                        themeTabRoot.updateBorderRadiusSetting();
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: themesSectionCol.implicitHeight + rootObj.s(24)
                radius: ThemeBackend.borderRadius
                color: Qt.alpha(ThemeBackend.surface0, 0.4)
                border.width: 0

                ColumnLayout {
                    id: themesSectionCol
                    anchors.fill: parent
                    anchors.margins: rootObj.s(12)
                    spacing: rootObj.s(14)

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: rootObj.s(12)

                        IconButton {
                            enabled: false
                            size: rootObj.s(32)
                            Layout.preferredWidth: rootObj.s(32)
                            Layout.preferredHeight: rootObj.s(32)
                            Layout.alignment: Qt.AlignVCenter
                            cornerRadius: ThemeBackend.borderRadius
                            buttonIcon: "󰏘"
                            iconFontSize: rootObj.s(16)
                            accentColor: ThemeBackend.surface0
                            textColor: "#ffffff"
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: rootObj.s(2)

                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.theme.colors.title")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(13)
                                color: ThemeBackend.text
                            }
                            Text {
                                Layout.fillWidth: true
                                text: I18n.t("guide.theme.colors.desc")
                                font.family: ThemeBackend.fontFamily
                                font.pixelSize: rootObj.s(11)
                                color: ThemeBackend.subtext0
                                wrapMode: Text.WordWrap
                            }
                        }

                        RowLayout {
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            spacing: rootObj.s(8)

                            IconButton {
                                Layout.alignment: Qt.AlignVCenter
                                size: rootObj.s(32)
                                Layout.preferredWidth: rootObj.s(32)
                                Layout.preferredHeight: rootObj.s(32)
                                cornerRadius: rootObj.s(8)
                                buttonIcon: "󰐕"
                                iconFontSize: rootObj.s(14)
                                accentColor: ThemeBackend.surface0
                                textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                                onClicked: {
                                    if (typeof Sounds !== "undefined") Sounds.playSfx("reusables/clickbutton/click.wav");
                                    themeEditorPopup.openForNew();
                                }
                            }

                            Input {
                                id: themeSearchInput
                                Layout.alignment: Qt.AlignVCenter
                                implicitWidth: rootObj.s(180)
                                placeholderText: I18n.t("guide.theme.colors.search")
                                baseColor: ThemeBackend.surface0
                                accentColor: ThemeBackend.mauve
                                textColor: ThemeBackend.text
                                subTextColor: ThemeBackend.subtext0
                                borderColor: Qt.alpha(ThemeBackend.surface2, 0.6)
                                cornerRadius: ThemeBackend.borderRadius
                                fontPixelSize: rootObj.s(11)
                                charSpacing: 1
                                onTextEdited: newText => themeTabRoot.themeSearchText = newText
                            }
                        }
                    }

                    GridLayout {
                        id: themesGrid
                        Layout.fillWidth: true
                        columns: 3
                        rowSpacing: rootObj.s(10)
                        columnSpacing: rootObj.s(10)

                        Repeater {
                            model: themeTabRoot.filteredUserPresets
                            delegate: presetDelegateComp
                        }

                        Repeater {
                            model: themeTabRoot.filteredSystemPresets
                            delegate: presetDelegateComp
                        }
                    }
                }
            }
        }
    }
}
