import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.I3
import Quickshell.Io
import "../components"
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: appControlWindow

    // ============================================================
    // STATE
    // ============================================================

    property bool menuOpen: false

    property int selectedModeIndex: 0
    property int selectedResultIndex: 0

    property bool keyboardActive: false
    property bool detailFocused: false
    property int selectedDetailActionIndex: 0
    property int hoveredResultIndex: -1

    // Exact visible spacing between app rows and their neighboring edges.
    property int appSelectorRowGap: 6


    // Keep the selected application stable while cycling through modes.
    property string rememberedAppKey: ""

    // Live Sway window snapshot used by APPS mode.
    property var swayWindows: []
    property bool windowDataReady: false
    property string windowDataError: ""

    property var selectedAppWindows: {
        if (selectedModeIndex !== 0)
            return [];

        return windowsForApp(selectedResult());
    }

    // ============================================================
    // MODE DATA
    // ============================================================

    property var modes: [
        {
            name: "APPS",
            symbol: "-⋆♱⋆-"
        },
        {
            name: "RUN",
            symbol: "⌯✎﹏﹏"
        },
        {
            name: "WINDOWS",
            symbol: "🃁🂡🂱🃑"
        },
        {
            name: "KILL",
            symbol: "(-_•)︻デ═一"
        }
    ]

    // Temporary Phase 1 placeholder content.
    property var placeholderResults: [
        {
            label: "OPTION 01"
        },
        {
            label: "OPTION 02"
        },
        {
            label: "OPTION 03"
        },
        {
            label: "OPTION 04"
        },
        {
            label: "OPTION 05"
        }
    ]

    // ============================================================
    // REAL APPLICATION MODEL
    // ============================================================

    ScriptModel {
        id: filteredApps

        values: {
            const query = searchInput.text.trim().toLowerCase();

            const apps = [...DesktopEntries.applications.values];

            const filtered = apps.filter(function (entry) {
                if (query.length === 0)
                    return true;

                const haystack = ((entry.name || "") + " " + (entry.genericName || "") + " " + (entry.comment || "") + " " + (entry.keywords || "")).toLowerCase();

                return haystack.indexOf(query) !== -1;
            });

            filtered.sort(function (a, b) {
                return (a.name || "").localeCompare(b.name || "");
            });

            return filtered;
        }
    }

    function resultCount() {
        return selectedModeIndex === 0 ? filteredApps.values.length : placeholderResults.length;
    }

    function selectedResult() {
        if (selectedResultIndex < 0 || selectedResultIndex >= resultCount())
            return null;

        return selectedModeIndex === 0 ? filteredApps.values[selectedResultIndex] : placeholderResults[selectedResultIndex];
    }

    function resetResultSelection() {
        selectedResultIndex = resultCount() > 0 ? 0 : -1;

        if (selectedResultIndex >= 0)
            resultList.positionViewAtIndex(selectedResultIndex, ListView.Beginning);
    }


    function appEntryKey(entry) {
        if (!entry)
            return "";

        if (entry.id)
            return String(entry.id);

        return String(entry.name || "");
    }

    function rememberCurrentAppSelection() {
        if (selectedModeIndex !== 0)
            return;

        const entry = selectedResult();

        if (entry)
            rememberedAppKey = appEntryKey(entry);
    }

    function restoreRememberedAppSelection() {
        const apps = filteredApps.values;

        if (apps.length === 0) {
            selectedResultIndex = -1;
            return;
        }

        let restoredIndex = -1;

        if (rememberedAppKey.length > 0) {
            for (let i = 0; i < apps.length; i++) {
                if (appEntryKey(apps[i]) === rememberedAppKey) {
                    restoredIndex = i;
                    break;
                }
            }
        }

        if (restoredIndex < 0)
            restoredIndex = 0;

        selectedResultIndex = restoredIndex;

        Qt.callLater(function () {
            resultList.positionViewAtIndex(
                appControlWindow.selectedResultIndex,
                ListView.Center
            );
        });
    }

    function switchMode(newModeIndex, preservePane) {
        const wasDetailFocused = detailFocused;

        hoveredResultIndex = -1;

        if (selectedModeIndex === 0)
            rememberCurrentAppSelection();

        selectedModeIndex = newModeIndex;

        if (selectedModeIndex === 0)
            restoreRememberedAppSelection();
        else
            resetResultSelection();

        detailFocused = preservePane ? wasDetailFocused : false;
        resetDetailActionSelection();
    }

    function moveResultSelection(direction) {
        keyboardActive = true;
        hoveredResultIndex = -1;

        // Use the ListView's actual count. This avoids model/count timing
        // mismatches and gives keyboard navigation one authoritative source.
        const count = resultList.count;

        if (count <= 0) {
            selectedResultIndex = -1;
            return;
        }

        let next = selectedResultIndex;

        if (next < 0 || next >= count)
            next = direction > 0 ? 0 : count - 1;
        else
            next += direction;

        let wrappedToTop = false;
        let wrappedToBottom = false;

        if (next < 0) {
            next = count - 1;
            wrappedToBottom = true;
        } else if (next >= count) {
            next = 0;
            wrappedToTop = true;
        }

        selectedResultIndex = next;

        if (selectedModeIndex === 0)
            rememberCurrentAppSelection();

        // Keep ordinary movement stable: only scroll when the selected
        // delegate would leave the visible viewport. Wrapping still jumps
        // explicitly to the opposite edge.
        if (wrappedToTop)
            resultList.positionViewAtIndex(next, ListView.Beginning);
        else if (wrappedToBottom)
            resultList.positionViewAtIndex(next, ListView.End);
        else
            resultList.positionViewAtIndex(next, ListView.Contain);
    }


    function detailActionCount() {
        if (selectedModeIndex !== 0)
            return 0;

        const entry = selectedResult();

        if (!entry)
            return 0;

        return 1 + entry.actions.length;
    }

    function resetDetailActionSelection() {
        selectedDetailActionIndex = detailActionCount() > 0 ? 0 : -1;

        if (detailFocused && selectedModeIndex === 0)
            detailFlickable.contentY = 0;

        ensureDetailActionVisible();
    }

    function detailActionItem(actionIndex) {
        if (actionIndex === 0)
            return launchAction;

        const desktopIndex = actionIndex - 1;

        if (desktopIndex < 0)
            return null;

        return desktopActionsRepeater.itemAt(desktopIndex);
    }

    function ensureDetailActionVisible() {
        if (!detailFocused || selectedModeIndex !== 0)
            return;

        Qt.callLater(function () {
            const item = detailActionItem(selectedDetailActionIndex);

            if (!item || detailFlickable.height <= 0)
                return;

            const point = item.mapToItem(detailContent, 0, 0);
            const margin = 8;

            const itemTop = point.y - margin;
            const itemBottom = point.y + item.height + margin;

            let targetY = detailFlickable.contentY;

            if (itemTop < targetY)
                targetY = itemTop;
            else if (itemBottom > targetY + detailFlickable.height)
                targetY = itemBottom - detailFlickable.height;

            const maxY = Math.max(
                0,
                detailFlickable.contentHeight - detailFlickable.height
            );

            detailFlickable.contentY = Math.max(
                0,
                Math.min(maxY, targetY)
            );
        });
    }

    function activateSelectedDetailAction() {
        if (selectedModeIndex !== 0)
            return;

        const entry = selectedResult();

        if (!entry)
            return;

        if (selectedDetailActionIndex === 0) {
            console.log("AppControl: launching", entry.name);
            entry.execute();
            menuOpen = false;
            return;
        }

        const desktopActionIndex = selectedDetailActionIndex - 1;

        if (desktopActionIndex < 0 || desktopActionIndex >= entry.actions.length)
            return;

        const action = entry.actions[desktopActionIndex];

        console.log("AppControl: desktop action", action.name);
        action.execute();
        menuOpen = false;
    }


    // ============================================================
    // OPTIONAL PER-APP PRESENTATION OVERRIDES
    // ============================================================
    //
    // Add entries here later when you want AppControlW to present an
    // application differently from its .desktop metadata.
    //
    // Example:
    //
    // "Firefox": {
    //     name: "FIREFOX",
    //     description: "WEB / RESEARCH",
    //     icon: "/absolute/path/to/custom-firefox.svg"
    // }
    //
    // Any field you leave out falls back to the real desktop entry.
    property var appOverrides: ({})

    function appOverride(entry) {
        if (!entry || !entry.name)
            return null;

        return appOverrides[entry.name] || null;
    }

    function appDisplayName(entry) {
        if (!entry)
            return "NO SELECTION";

        const override = appOverride(entry);

        return override && override.name
            ? override.name
            : (entry.name || "APPLICATION");
    }

    function appDisplayDescription(entry) {
        if (!entry)
            return "";

        const override = appOverride(entry);

        if (override && override.description)
            return override.description;

        return entry.genericName || entry.comment || "APPLICATION";
    }

    function appLongDescription(entry) {
        if (!entry)
            return "";

        const override = appOverride(entry);

        if (override && override.longDescription)
            return override.longDescription;

        return entry.comment || "";
    }

    function appDisplayIcon(entry) {
        if (!entry)
            return "";

        const override = appOverride(entry);

        return override && override.icon
            ? override.icon
            : (entry.icon || "");
    }

    function appIconSource(entry) {
        const icon = appDisplayIcon(entry);

        if (!icon)
            return "";

        if (icon.indexOf("/") === 0 || icon.indexOf("file:") === 0)
            return icon;

        return Quickshell.iconPath(icon, true);
    }


    function classifyIconGlow(pixelData) {
        if (!pixelData || pixelData.length < 4)
            return Colors.orange;

        // Prefer a real chromatic accent over neutral white/black mass.
        // This matters for icons such as Calendar (mostly white with a
        // purple header) and Mullvad (dark blue field + yellow M).
        let redAccent = 0;
        let orangeAccent = 0;
        let magentaAccent = 0;
        let cyanAccent = 0;
        let greenAccent = 0;

        let totalVisibleWeight = 0;
        let totalAccentWeight = 0;

        let lightNeutralWeight = 0;
        let darkNeutralWeight = 0;
        let midNeutralWeight = 0;

        for (let i = 0; i < pixelData.length; i += 4) {
            const alpha = pixelData[i + 3] / 255.0;

            if (alpha < 0.12)
                continue;

            const r = pixelData[i] / 255.0;
            const g = pixelData[i + 1] / 255.0;
            const b = pixelData[i + 2] / 255.0;

            const maxValue = Math.max(r, g, b);
            const minValue = Math.min(r, g, b);
            const delta = maxValue - minValue;

            const saturation = maxValue <= 0.0001
                               ? 0.0
                               : delta / maxValue;

            totalVisibleWeight += alpha;

            // IMPORTANT: classify saturated dark colors by hue BEFORE
            // treating them as "black". A dark navy background is still
            // blue, not neutral black.
            if (saturation >= 0.18 && delta >= 0.035) {
                let hue = 0.0;

                if (maxValue === r) {
                    hue = 60.0 * (((g - b) / delta) % 6.0);
                } else if (maxValue === g) {
                    hue = 60.0 * (((b - r) / delta) + 2.0);
                } else {
                    hue = 60.0 * (((r - g) / delta) + 4.0);
                }

                if (hue < 0.0)
                    hue += 360.0;

                // Strongly favor saturated accent pixels. Bright colors
                // get a slight boost, but dark saturated colors still count.
                const accentWeight =
                    alpha
                    * (0.55 + saturation * 1.45)
                    * (0.65 + maxValue * 0.35);

                totalAccentWeight += accentWeight;

                // Red gets its own family now.
                if (hue < 15.0 || hue >= 345.0) {
                    redAccent += accentWeight;
                // Orange / yellow.
                } else if (hue < 75.0) {
                    orangeAccent += accentWeight;
                // Green.
                } else if (hue < 170.0) {
                    greenAccent += accentWeight;
                // Cyan / blue. Keep this range narrower so indigo/violet
                // icons such as Obsidian land in magenta instead of cyan.
                } else if (hue < 245.0) {
                    cyanAccent += accentWeight;
                // Indigo / purple / pink.
                } else {
                    magentaAccent += accentWeight;
                }

                continue;
            }

            // Only genuinely low-saturation pixels reach this fallback.
            if (maxValue > 0.72) {
                lightNeutralWeight += alpha;
            } else if (maxValue < 0.26) {
                darkNeutralWeight += alpha;
            } else {
                midNeutralWeight += alpha;
            }
        }

        // A relatively small colored region should be allowed to define
        // the glow. ~4% is enough for a colored header/mark to beat a
        // mostly white or black icon body.
        const accentPresence =
            totalVisibleWeight > 0.0
            ? totalAccentWeight / totalVisibleWeight
            : 0.0;

        if (accentPresence >= 0.04) {
            const bestAccent = Math.max(
                redAccent,
                orangeAccent,
                magentaAccent,
                cyanAccent,
                greenAccent
            );

            if (bestAccent === redAccent)
                return Colors.red;

            if (bestAccent === greenAccent)
                return Colors.omnitrix;

            if (bestAccent === cyanAccent)
                return Colors.cyan;

            if (bestAccent === magentaAccent)
                return Colors.magenta;

            return Colors.orange;
        }

        // Truly monochrome icons keep the original neutral mapping.
        // White/light -> cyan, black/dark -> magenta.
        if (darkNeutralWeight > lightNeutralWeight
                && darkNeutralWeight > midNeutralWeight)
            return Colors.magenta;

        return Colors.cyan;
    }


    // ============================================================
    // SWAY WINDOW STATE
    // ============================================================

    function normalizeAppToken(value) {
        if (!value)
            return "";

        let token = String(value).toLowerCase();

        if (token.endsWith(".desktop"))
            token = token.slice(0, -8);

        return token.replace(/[^a-z0-9]/g, "");
    }

    function commandBaseName(entry) {
        if (!entry || !entry.command || entry.command.length === 0)
            return "";

        const command = String(entry.command[0]);
        const parts = command.split("/");

        return parts[parts.length - 1];
    }

    function appMatchTokens(entry) {
        if (!entry)
            return [];

        const rawTokens = [
            entry.startupClass || "",
            entry.id || "",
            entry.name || "",
            commandBaseName(entry)
        ];

        // Reverse-DNS desktop ids often end in the useful app identifier.
        if (entry.id) {
            const idWithoutDesktop = String(entry.id).replace(/\.desktop$/i, "");
            const idParts = idWithoutDesktop.split(".");

            if (idParts.length > 1)
                rawTokens.push(idParts[idParts.length - 1]);
        }

        const tokens = [];

        for (let i = 0; i < rawTokens.length; i++) {
            const normalized = normalizeAppToken(rawTokens[i]);

            if (normalized.length > 0 && tokens.indexOf(normalized) === -1)
                tokens.push(normalized);
        }

        return tokens;
    }

    function windowMatchTokens(windowInfo) {
        if (!windowInfo)
            return [];

        const rawTokens = [
            windowInfo.appId || "",
            windowInfo.className || "",
            windowInfo.instance || ""
        ];

        const tokens = [];

        for (let i = 0; i < rawTokens.length; i++) {
            const normalized = normalizeAppToken(rawTokens[i]);

            if (normalized.length > 0 && tokens.indexOf(normalized) === -1)
                tokens.push(normalized);
        }

        return tokens;
    }

    function tokensMatch(appToken, windowToken) {
        if (!appToken || !windowToken)
            return false;

        if (appToken === windowToken)
            return true;

        // Helps with reverse-DNS ids such as org.mozilla.firefox vs firefox,
        // while avoiding very short accidental matches.
        const shorterLength = Math.min(appToken.length, windowToken.length);

        if (shorterLength < 4)
            return false;

        return appToken.endsWith(windowToken)
                || windowToken.endsWith(appToken);
    }

    function windowMatchesApp(windowInfo, entry) {
        const appTokens = appMatchTokens(entry);
        const windowTokens = windowMatchTokens(windowInfo);

        for (let i = 0; i < appTokens.length; i++) {
            for (let j = 0; j < windowTokens.length; j++) {
                if (tokensMatch(appTokens[i], windowTokens[j]))
                    return true;
            }
        }

        return false;
    }

    function windowsForApp(entry) {
        if (!entry)
            return [];

        return swayWindows.filter(function (windowInfo) {
            return windowMatchesApp(windowInfo, entry);
        });
    }

    function workspaceSummary(windows) {
        return workspaceList(windows).join(", ");
    }

    function workspaceList(windows) {
        if (!windows || windows.length === 0)
            return [];

        const names = [];

        for (let i = 0; i < windows.length; i++) {
            const workspace = windows[i].workspace || "";

            if (workspace.length > 0 && names.indexOf(workspace) === -1)
                names.push(workspace);
        }

        return names;
    }

    function collectSwayWindows(node, currentWorkspace, output) {
        if (!node)
            return;

        let workspace = currentWorkspace || "";

        if (node.type === "workspace")
            workspace = node.name || workspace;

        const properties = node.window_properties || {};
        const appId = node.app_id || "";
        const className = properties.class || "";
        const instance = properties.instance || "";

        // A leaf/container with application identity is a window we care about.
        if (node.type === "con" && (appId || className || instance)) {
            output.push({
                id: node.id || 0,
                name: node.name || "",
                appId: appId,
                className: className,
                instance: instance,
                pid: node.pid || 0,
                focused: !!node.focused,
                workspace: workspace
            });
        }

        const children = node.nodes || [];

        for (let i = 0; i < children.length; i++)
            collectSwayWindows(children[i], workspace, output);

        const floatingChildren = node.floating_nodes || [];

        for (let i = 0; i < floatingChildren.length; i++)
            collectSwayWindows(floatingChildren[i], workspace, output);
    }

    function consumeSwayTree(rawText) {
        if (!rawText || rawText.trim().length === 0)
            return;

        try {
            const tree = JSON.parse(rawText);
            const windows = [];

            collectSwayWindows(tree, "", windows);

            swayWindows = windows;
            windowDataReady = true;
            windowDataError = "";

            console.log("AppControl: Sway window snapshot:", windows.length, "windows");
        } catch (error) {
            windowDataReady = false;
            windowDataError = String(error);

            console.log("AppControl: failed to parse Sway tree:", error);
        }
    }

    function refreshWindowState() {
        swayTreeProcess.exec(["swaymsg", "-t", "get_tree"]);
    }

    Process {
        id: swayTreeProcess

        stdout: StdioCollector {
            onStreamFinished: {
                appControlWindow.consumeSwayTree(text);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) {
                    appControlWindow.windowDataError = text.trim();
                    console.log("AppControl: swaymsg:", text.trim());
                }
            }
        }
    }

    I3IpcListener {
        subscriptions: ["window", "workspace"]

        onIpcEvent: function (event) {
            // Refresh from the authoritative tree after create/close/focus/move/
            // title/workspace changes rather than trying to reconstruct state
            // from individual events.
            appControlWindow.refreshWindowState();
        }
    }

    // ============================================================
    // WINDOW
    // ============================================================

    implicitWidth: 834
    implicitHeight: 674

    color: "transparent"

    surfaceFormat.opaque: false

    focusable: true
    visible: menuOpen

    // ============================================================
    // BACKGROUND / OUTER GLOW
    // ============================================================

    RectangularShadow {
        anchors.fill: background

        spread: 6
        z: -20

        opacity: 0.38
        color: Colors.orange
    }

    RectangularShadow {
        anchors.fill: background

        spread: 12
        z: -21

        opacity: 0.12
        color: Colors.orange
    }

    Rectangle {
        id: background

        anchors.fill: parent
        anchors.margins: 12

        // Geometry anchor for the outer border/glow only.
        // Individual panels provide their own backgrounds.
        // Keeping this transparent is what allows the right-side
        // app-control panel alpha to actually show through.
        color: "transparent"
        opacity: 1.0
    }

    // ============================================================
    // MODE RAIL
    // ============================================================

    Rectangle {
        id: modeRail

        width: 110

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        anchors.leftMargin: 12
        anchors.topMargin: 12
        anchors.bottomMargin: 12

        color: Colors.black

        Column {
            id: modeColumn

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right

            anchors.topMargin: 20

            spacing: 8

            Repeater {
                model: appControlWindow.modes

                Rectangle {
                    id: modeButton

                    property bool isSelected: index === appControlWindow.selectedModeIndex

                    property bool isHovered: !appControlWindow.keyboardActive && modeMouse.containsMouse

                    property bool isPressed: modeMouse.pressed

                    width: parent.width
                    height: 55

                    color: modeButton.isPressed ? Colors.magenta : modeButton.isHovered ? Colors.yellow : modeButton.isSelected ? Colors.yellow : Colors.black

                    Column {
                        anchors.centerIn: parent

                        spacing: 2

                        Item {
                            width: modeSymbol.implicitWidth
                            height: modeSymbol.implicitHeight

                            anchors.horizontalCenter: parent.horizontalCenter

                            GohuText {
                                id: modeSymbol

                                anchors.centerIn: parent

                                text: modelData.symbol

                                font.pixelSize: 17

                                color: modeButton.isPressed
                                       ? Colors.black
                                       : modeButton.isSelected
                                       ? Colors.magenta
                                       : modeButton.isHovered
                                       ? Colors.orange
                                       : Colors.cyan
                            }

                            DropShadow {
                                anchors.fill: modeSymbol
                                source: modeSymbol

                                horizontalOffset: 0
                                verticalOffset: 0

                                radius: modeButton.isSelected
                                        ? 18
                                        : modeButton.isHovered
                                        ? 14
                                        : 10

                                samples: modeButton.isSelected
                                         ? 17
                                         : modeButton.isHovered
                                         ? 9
                                         : 7

                                z: 2

                                opacity: modeButton.isSelected
                                         ? 1.0
                                         : modeButton.isHovered
                                         ? 0.8
                                         : 0.42

                                color: modeButton.isSelected
                                       ? Colors.magenta
                                       : modeButton.isHovered
                                       ? Colors.orange
                                       : Colors.cyan

                                transparentBorder: true
                            }
                        }

                        Item {
                            width: modeLabel.implicitWidth
                            height: modeLabel.implicitHeight

                            anchors.horizontalCenter: parent.horizontalCenter

                            GohuText {
                                id: modeLabel

                                anchors.centerIn: parent

                                text: modelData.name

                                font.pixelSize: 11

                                color: modeButton.isPressed
                                       ? Colors.black
                                       : modeButton.isHovered
                                       ? Colors.orange
                                       : modeButton.isSelected
                                       ? Colors.orange
                                       : Colors.white
                            }

                            DropShadow {
                                anchors.fill: modeLabel
                                source: modeLabel

                                horizontalOffset: 0
                                verticalOffset: 0

                                radius: 5
                                samples: 7

                                z: 2

                                opacity: !modeButton.isPressed
                                         && !modeButton.isHovered
                                         && !modeButton.isSelected
                                         ? 0.10
                                         : 0.0

                                color: Colors.white
                                transparentBorder: true
                            }
                        }
                    }

                    MouseArea {
                        id: modeMouse

                        anchors.fill: parent

                        hoverEnabled: true

                        onEntered: {
                            appControlWindow.keyboardActive = false;
                        }

                        onClicked: {
                            appControlWindow.switchMode(index, false);

                            searchInput.forceActiveFocus();
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 3
                        z: -1

                        // No idle rectangle glow. Inactive glow belongs to
                        // the glyph and label themselves, not the button box.
                        opacity: modeButton.isSelected || modeButton.isHovered
                                 ? 0.5
                                 : 0.0

                        color: Colors.orange
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 10
                        z: 1

                        opacity: modeButton.isSelected || modeButton.isHovered
                                 ? 0.09
                                 : 0.0

                        color: Colors.orange
                    }
                }
            }
        }
    }

    // ============================================================
    // SEARCH / RESULTS PANE
    // ============================================================

    Rectangle {
        id: resultsPane

        width: 310

        anchors.left: modeRail.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        anchors.topMargin: 12
        anchors.bottomMargin: 12

        color: Colors.dark

        // ========================================================
        // SEARCH HEADER
        // ========================================================

        Rectangle {
            id: searchHeader

            width: parent.width
            height: 70

            anchors.top: parent.top

            color: Colors.dark

            Column {
                anchors.fill: parent

                anchors.leftMargin: 15
                anchors.rightMargin: 15
                anchors.topMargin: 12
                anchors.bottomMargin: 10

                spacing: 8

                Item {
                    width: selectorModeHeaderText.implicitWidth
                    height: selectorModeHeaderText.implicitHeight

                    GohuText {
                        id: selectorModeHeaderText

                        anchors.centerIn: parent

                        text: appControlWindow.modes[
                            appControlWindow.selectedModeIndex
                        ].name

                        font.pixelSize: 19

                        color: appControlWindow.selectedModeIndex === 3
                               ? Colors.red
                               : appControlWindow.selectedModeIndex === 0
                               ? Colors.magenta
                               : Colors.cyan
                    }

                    DropShadow {
                        anchors.fill: selectorModeHeaderText
                        source: selectorModeHeaderText

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 10
                        samples: 9

                        z: 2

                        opacity: appControlWindow.selectedModeIndex === 0
                                 ? 0.52
                                 : 0.38

                        color: appControlWindow.selectedModeIndex === 3
                               ? Colors.red
                               : appControlWindow.selectedModeIndex === 0
                               ? Colors.magenta
                               : Colors.cyan

                        transparentBorder: true
                    }
                }

                TextInput {
                    id: searchInput

                    width: parent.width

                    font.family: "GohuFont 11 Nerd Font Mono"
                    font.pixelSize: 18

                    color: Colors.magenta

                    selectionColor: Colors.yellow
                    selectedTextColor: Colors.black

                    cursorVisible: activeFocus

                    cursorDelegate: Rectangle {
                        width: 2
                        color: Colors.cyan
                    }

                    clip: true

                    layer.enabled: true
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 7
                        samples: 9

                        opacity: 0.30
                        color: Colors.magenta

                        transparentBorder: true
                    }

                    Keys.onPressed: function (event) {
                        appControlWindow.handleKey(event);
                    }

                    onTextChanged: {
                        if (appControlWindow.selectedModeIndex === 0) {
                            appControlWindow.resetResultSelection();
                            appControlWindow.rememberCurrentAppSelection();
                            appControlWindow.resetDetailActionSelection();
                        }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                height: 1

                color: appControlWindow.selectedModeIndex === 3 ? Colors.red : Colors.cyan
            }
        }

        // ========================================================
        // RESULTS
        // ========================================================

        ListView {
            id: resultList

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: searchHeader.bottom
            anchors.bottom: parent.bottom

            // Content has an 8px top breathing space, but the viewport begins
            // at the header divider. This lets the first row's orange glow
            // extend upward into that gap instead of being clipped there.
            topMargin: 8

            clip: true

            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            highlightResizeDuration: 0

            model: appControlWindow.selectedModeIndex === 0 ? filteredApps : appControlWindow.placeholderResults

            footer: Item {
                width: resultList.width
                height: 10
            }

            delegate: Item {
                id: resultDelegate

                required property int index
                required property var modelData

                width: resultList.width
                height: 42

                z: resultButton.isSelected || resultButton.isHovered ? 10 : 0

                Rectangle {
                    id: resultButton

                    property bool isSelected: resultDelegate.index === appControlWindow.selectedResultIndex

                    property bool isHovered: !appControlWindow.keyboardActive
                                             && appControlWindow.hoveredResultIndex === resultDelegate.index

                    property bool isPressed: resultMouse.pressed

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    // ONE shared value controls both visible side gaps.
                    //
                    // Left:
                    //   panel divider -> gap -> button
                    //
                    // Right:
                    //   button -> same gap -> scrollbar
                    anchors.leftMargin: appControlWindow.appSelectorRowGap
                    anchors.rightMargin:
                        (resultList.width - resultScrollTrack.x)
                        + appControlWindow.appSelectorRowGap

                    color: resultButton.isPressed
                           ? Colors.magenta
                           : resultButton.isHovered
                           ? Colors.yellow
                           : resultButton.isSelected
                           ? Colors.yellow
                           : Colors.dark

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 14

                    spacing: 9

                    Item {
                        id: selectorAppIconBox

                        width: 22
                        height: 22

                        property color sampledGlowColor: Colors.orange

                        visible: appControlWindow.selectedModeIndex === 0
                                 && selectorAppIcon.source.toString().length > 0

                        Image {
                            id: selectorAppIcon

                            anchors.fill: parent

                            source: appControlWindow.selectedModeIndex === 0
                                    ? appControlWindow.appIconSource(modelData)
                                    : ""

                            fillMode: Image.PreserveAspectFit
                            smooth: false
                        }

                        // Tiny invisible sampler. Visible ListView delegates only,
                        // so this does not scan the entire application database.
                        Canvas {
                            id: selectorIconColorSampler

                            width: 16
                            height: 16

                            opacity: 0.001
                            z: -100

                            property string sampleSource:
                                selectorAppIcon.source.toString()

                            function prepareSample() {
                                if (sampleSource.length === 0) {
                                    selectorAppIconBox.sampledGlowColor =
                                        Colors.orange;
                                    return;
                                }

                                loadImage(sampleSource);

                                if (isImageLoaded(sampleSource))
                                    requestPaint();
                            }

                            onSampleSourceChanged: prepareSample()

                            onImageLoaded: {
                                requestPaint();
                            }

                            onPaint: {
                                if (sampleSource.length === 0
                                        || !isImageLoaded(sampleSource))
                                    return;

                                const ctx = getContext("2d");

                                ctx.clearRect(0, 0, width, height);
                                ctx.drawImage(
                                    sampleSource,
                                    0,
                                    0,
                                    width,
                                    height
                                );

                                const pixels =
                                    ctx.getImageData(
                                        0,
                                        0,
                                        width,
                                        height
                                    ).data;

                                selectorAppIconBox.sampledGlowColor =
                                    appControlWindow.classifyIconGlow(pixels);
                            }

                            Component.onCompleted: prepareSample()
                        }

                        DropShadow {
                            anchors.fill: selectorAppIcon
                            source: selectorAppIcon

                            horizontalOffset: 0
                            verticalOffset: 0

                            radius: resultButton.isPressed ? 10 : 8
                            samples: resultButton.isPressed ? 8 : 6

                            opacity: selectorAppIcon.status === Image.Ready
                                     ? (resultButton.isPressed ? 0.85 : 0.52)
                                     : 0.0

                            color: resultButton.isPressed
                                   ? Colors.magenta
                                   : selectorAppIconBox.sampledGlowColor

                            transparentBorder: true
                        }
                    }

                    GohuText {
                        anchors.verticalCenter: parent.verticalCenter

                        text: appControlWindow.selectedModeIndex === 0 ? modelData.name : modelData.label

                        font.pixelSize: 17

                        color: resultButton.isPressed
                               ? Colors.black
                               : resultButton.isHovered
                               ? Colors.orange
                               : resultButton.isSelected
                               ? Colors.orange
                               : Colors.cyan

                        layer.enabled: !resultButton.isPressed
                                       && !resultButton.isHovered
                                       && !resultButton.isSelected

                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0

                            radius: 4
                            samples: 5

                            opacity: 0.12
                            color: Colors.cyan

                            transparentBorder: true
                        }
                    }
                }

                MouseArea {
                    id: resultMouse

                    anchors.fill: parent

                    acceptedButtons: Qt.LeftButton

                    onClicked: {
                        // A click is always an intentional mouse selection.
                        appControlWindow.keyboardActive = false;
                        appControlWindow.hoveredResultIndex = resultDelegate.index;
                        appControlWindow.selectedResultIndex = resultDelegate.index;

                        if (appControlWindow.selectedModeIndex === 0)
                            appControlWindow.rememberCurrentAppSelection();

                        appControlWindow.resetDetailActionSelection();
                        appControlWindow.activateSelectedResult();
                    }
                }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 3
                        z: -1

                        opacity: resultButton.isSelected || resultButton.isHovered ? 0.45 : 0.0

                        color: appControlWindow.selectedModeIndex === 3 ? Colors.red : Colors.orange
                    }
                }
            }

            // Fixed viewport hover tracker.
            //
            // This lives on the ListView viewport rather than inside a delegate.
            // Its coordinates do not move when content scrolls underneath a
            // stationary pointer, so only real pointer movement can steal
            // selection from keyboard navigation.
            MouseArea {
                id: resultViewportMouse

                anchors.fill: parent
                z: 100

                hoverEnabled: true
                acceptedButtons: Qt.NoButton

                onPositionChanged: function(mouse) {
                    if (resultList.moving)
                        return;

                    const rowLeft = appControlWindow.appSelectorRowGap;
                    const rowRight =
                        resultScrollTrack.x
                        - appControlWindow.appSelectorRowGap;

                    const hoveredIndex =
                        mouse.x >= rowLeft && mouse.x <= rowRight
                        ? resultList.indexAt(
                              mouse.x,
                              mouse.y + resultList.contentY
                          )
                        : -1;

                    appControlWindow.hoveredResultIndex = hoveredIndex;

                    if (hoveredIndex < 0)
                        return;

                    appControlWindow.keyboardActive = false;
                    appControlWindow.selectedResultIndex = hoveredIndex;

                    if (appControlWindow.selectedModeIndex === 0)
                        appControlWindow.rememberCurrentAppSelection();

                    appControlWindow.resetDetailActionSelection();
                }

                onExited: {
                    appControlWindow.hoveredResultIndex = -1;
                }

                onWheel: function(wheel) {
                    // Preserve normal ListView wheel/trackpad scrolling.
                    wheel.accepted = false;
                }
            }
        }

        // ========================================================
        // APP SELECTOR SCROLLBAR
        // ========================================================

        Rectangle {
            id: resultScrollTrack

            width: 10

            anchors.top: searchHeader.bottom
            anchors.bottom: parent.bottom
            anchors.right: parent.right

            anchors.topMargin: 0
            anchors.bottomMargin: 4
            anchors.rightMargin: 3

            color: Colors.cyan

            opacity: resultList.contentHeight > resultList.height ? 0.9 : 0.0
            visible: opacity > 0.0

            z: 300

            property real maxContentY: Math.max(
                0,
                resultList.contentHeight - resultList.height
            )

            property real handleTravel: Math.max(
                0,
                height - resultScrollHandle.height
            )

            function setScrollFromHandleY(handleY) {
                if (maxContentY <= 0 || handleTravel <= 0)
                    return;

                const clampedY = Math.max(
                    0,
                    Math.min(handleTravel, handleY)
                );

                resultList.contentY =
                    (clampedY / handleTravel) * maxContentY;
            }

            Rectangle {
                id: resultScrollHandle

                width: 6
                anchors.horizontalCenter: parent.horizontalCenter

                height: Math.max(
                    30,
                    parent.height * Math.min(
                        1.0,
                        resultList.visibleArea.heightRatio
                    )
                )

                y: {
                    if (resultScrollTrack.maxContentY <= 0
                            || resultScrollTrack.handleTravel <= 0)
                        return 0;

                    const clampedContentY = Math.max(
                        0,
                        Math.min(
                            resultScrollTrack.maxContentY,
                            resultList.contentY
                        )
                    );

                    return (clampedContentY / resultScrollTrack.maxContentY)
                            * resultScrollTrack.handleTravel;
                }

                color: Colors.magenta

                RectangularShadow {
                    anchors.fill: parent

                    spread: 2
                    z: -1

                    opacity: 0.16
                    color: Colors.magenta
                }
            }

            MouseArea {
                id: resultScrollMouse

                anchors.fill: parent

                hoverEnabled: true
                acceptedButtons: Qt.LeftButton

                property real dragOffset: 0

                onPressed: function(mouse) {
                    const handleTop = resultScrollHandle.y;
                    const handleBottom =
                        resultScrollHandle.y + resultScrollHandle.height;

                    if (mouse.y >= handleTop && mouse.y <= handleBottom) {
                        // Dragging directly from the magenta handle.
                        dragOffset = mouse.y - resultScrollHandle.y;
                    } else {
                        // Clicking the cyan track jumps the handle toward
                        // that location and immediately allows dragging.
                        dragOffset = resultScrollHandle.height / 2;
                        resultScrollTrack.setScrollFromHandleY(
                            mouse.y - dragOffset
                        );
                    }

                    mouse.accepted = true;
                }

                onPositionChanged: function(mouse) {
                    if (!pressed)
                        return;

                    resultScrollTrack.setScrollFromHandleY(
                        mouse.y - dragOffset
                    );
                }

                onWheel: function(wheel) {
                    // Wheel/trackpad scrolling still belongs to the ListView.
                    wheel.accepted = false;
                }
            }
        }
    }

    // ============================================================
    // DETAIL / CONTROL PANE
    // ============================================================

    Rectangle {
        id: detailPane

        anchors.left: resultsPane.right
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        anchors.rightMargin: 12
        anchors.topMargin: 12
        anchors.bottomMargin: 12

        color: Qt.rgba(Colors.black.r, Colors.black.g, Colors.black.b, 0.60)

        border.width: 1

        border.color: appControlWindow.detailFocused ? Colors.orange : Colors.cyan

        Rectangle {
            id: detailTopBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            anchors.leftMargin: 5
            anchors.rightMargin: 5
            anchors.topMargin: 8

            height: 2

            color: Colors.cyan
        }

        // Everything above the RUNNING STATE divider stays fixed.
        Column {
            id: detailStaticHeader

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top

            anchors.leftMargin: 25
            anchors.rightMargin: 25
            anchors.topMargin: 25

            spacing: 18

            Row {
                id: appControlHeader

                spacing: 10

                Item {
                    width: controlModeIcon.implicitWidth
                    height: controlModeIcon.implicitHeight

                    anchors.verticalCenter: parent.verticalCenter

                    GohuText {
                        id: controlModeIcon

                        anchors.centerIn: parent

                        text: appControlWindow.modes[appControlWindow.selectedModeIndex].symbol

                        font.pixelSize: 20

                        color: Colors.magenta
                    }

                    DropShadow {
                        anchors.fill: controlModeIcon
                        source: controlModeIcon

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 18
                        samples: 9

                        z: 2

                        opacity: 0.9

                        color: Colors.magenta

                        transparentBorder: true
                    }
                }

                Item {
                    width: applicationControlTitle.implicitWidth
                    height: applicationControlTitle.implicitHeight

                    anchors.verticalCenter: parent.verticalCenter

                    GohuText {
                        id: applicationControlTitle

                        anchors.centerIn: parent

                        text: "APPLICATION CONTROL"

                        font.pixelSize: 20

                        color: Colors.cyan
                    }

                    DropShadow {
                        anchors.fill: applicationControlTitle
                        source: applicationControlTitle

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 14
                        samples: 11

                        z: 2

                        opacity: 0.75
                        color: Colors.cyan

                        transparentBorder: true
                    }
                }
            }

            Rectangle {
                width: parent.width + 40
                height: 2

                x: -20

                color: Colors.cyan
            }

            Row {
                id: selectedAppIdentity

                width: parent.width
                spacing: 14

                property var currentResult: appControlWindow.selectedResult()
                property bool showingApp: appControlWindow.selectedModeIndex === 0 && currentResult

                Item {
                    id: selectedAppIconBox

                    width: 52
                    height: 52

                    property color sampledGlowColor: Colors.orange

                    visible: selectedAppIdentity.showingApp

                    Image {
                        id: selectedAppIcon

                        anchors.fill: parent

                        source: selectedAppIdentity.showingApp
                                ? appControlWindow.appIconSource(selectedAppIdentity.currentResult)
                                : ""

                        fillMode: Image.PreserveAspectFit
                        smooth: false
                    }

                    Canvas {
                        id: selectedIconColorSampler

                        width: 18
                        height: 18

                        opacity: 0.001
                        z: -100

                        property string sampleSource:
                            selectedAppIcon.source.toString()

                        function prepareSample() {
                            if (sampleSource.length === 0) {
                                selectedAppIconBox.sampledGlowColor =
                                    Colors.orange;
                                return;
                            }

                            loadImage(sampleSource);

                            if (isImageLoaded(sampleSource))
                                requestPaint();
                        }

                        onSampleSourceChanged: prepareSample()

                        onImageLoaded: {
                            requestPaint();
                        }

                        onPaint: {
                            if (sampleSource.length === 0
                                    || !isImageLoaded(sampleSource))
                                return;

                            const ctx = getContext("2d");

                            ctx.clearRect(0, 0, width, height);
                            ctx.drawImage(
                                sampleSource,
                                0,
                                0,
                                width,
                                height
                            );

                            const pixels =
                                ctx.getImageData(
                                    0,
                                    0,
                                    width,
                                    height
                                ).data;

                            selectedAppIconBox.sampledGlowColor =
                                appControlWindow.classifyIconGlow(pixels);
                        }

                        Component.onCompleted: prepareSample()
                    }

                    DropShadow {
                        anchors.fill: selectedAppIcon
                        source: selectedAppIcon

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 12
                        samples: 8

                        opacity: selectedAppIcon.status === Image.Ready
                                 ? 0.50
                                 : 0.0

                        color: selectedAppIconBox.sampledGlowColor

                        transparentBorder: true
                    }
                }

                Column {
                    width: parent.width - (selectedAppIdentity.showingApp ? 66 : 0)
                    spacing: 5

                    Item {
                        width: parent.width
                        height: selectedAppName.implicitHeight

                        GohuText {
                            id: selectedAppName

                            width: parent.width

                            text: selectedAppIdentity.showingApp
                                  ? appControlWindow.appDisplayName(selectedAppIdentity.currentResult)
                                  : (selectedAppIdentity.currentResult
                                     ? selectedAppIdentity.currentResult.label
                                     : "NO SELECTION")

                            font.pixelSize: 22

                            color: Colors.orange

                            elide: Text.ElideRight
                        }

                        DropShadow {
                            anchors.fill: selectedAppName
                            source: selectedAppName

                            horizontalOffset: 0
                            verticalOffset: 0

                            radius: 14
                            samples: 11

                            z: 2

                            opacity: 0.7
                            color: Colors.orange

                            transparentBorder: true
                        }
                    }

                    GohuText {
                        width: parent.width

                        text: selectedAppIdentity.showingApp
                              ? appControlWindow.appDisplayDescription(selectedAppIdentity.currentResult)
                              : "Phase 1 placeholder"

                        font.pixelSize: 15

                        color: Colors.white
                        opacity: 1.0

                        elide: Text.ElideRight

                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0

                            radius: 6
                            samples: 7

                            opacity: 0.24
                            color: Colors.cyan

                            transparentBorder: true
                        }
                    }
                }
            }

            GohuText {
                property var currentResult: appControlWindow.selectedResult()

                width: parent.width

                text: appControlWindow.selectedModeIndex === 0 && currentResult
                      ? appControlWindow.appLongDescription(currentResult)
                      : ""

                visible: text.length > 0

                wrapMode: Text.Wrap

                font.pixelSize: 14

                color: Colors.white

                opacity: 0.5
            }

            Column {
                id: runningStateSection

                width: parent.width
                spacing: 6

                visible: appControlWindow.selectedModeIndex === 0
                         && appControlWindow.selectedResult() !== null

                Item {
                    width: runningStateHeaderText.implicitWidth
                    height: runningStateHeaderText.implicitHeight

                    GohuText {
                        id: runningStateHeaderText

                        text: "RUNNING STATE"

                        font.pixelSize: 13

                        color: Colors.cyan
                        opacity: 0.75
                    }

                    DropShadow {
                        anchors.fill: runningStateHeaderText
                        source: runningStateHeaderText

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 5
                        samples: 5

                        z: 2

                        opacity: 0.20
                        color: Colors.cyan

                        transparentBorder: true
                    }
                }

                Rectangle {
                    id: runningStateDivider

                    width: parent.width + 20
                    height: 1

                    x: -10

                    color: Colors.cyan
                    opacity: 0.55

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 2
                        z: -1

                        opacity: 0.10
                        color: Colors.cyan
                    }
                }
            }
        }

        // Only content BELOW the RUNNING STATE divider scrolls.
        Flickable {
            id: detailFlickable

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: detailStaticHeader.bottom
            anchors.bottom: detailBottomBar.top

            anchors.leftMargin: 25
            anchors.rightMargin: 25
            anchors.topMargin: 8
            anchors.bottomMargin: 8

            clip: true

            contentWidth: width
            contentHeight: detailContent.implicitHeight

            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            Column {
                id: detailContent

                width: detailFlickable.width
                spacing: 18

                Column {
                    id: runningStateBody

                    width: parent.width
                    spacing: 6

                    visible: appControlWindow.selectedModeIndex === 0
                             && appControlWindow.selectedResult() !== null

                GohuText {
                    width: parent.width

                    visible: !appControlWindow.windowDataReady

                    text: appControlWindow.windowDataError.length > 0
                          ? "SWAY STATE UNAVAILABLE"
                          : "CHECKING..."

                    font.pixelSize: 15
                    color: Colors.white
                    opacity: 0.6
                }

                GohuText {
                    width: parent.width

                    visible: appControlWindow.windowDataReady
                             && appControlWindow.selectedAppWindows.length === 0

                    text: "NOT RUNNING"

                    font.pixelSize: 15
                    color: Colors.white
                    opacity: 0.6
                }

                GridLayout {
                    id: runningStateGrid

                    width: parent.width

                    columns: 3
                    columnSpacing: 6
                    rowSpacing: 4

                    visible: appControlWindow.windowDataReady
                             && appControlWindow.selectedAppWindows.length > 0

                    property var workspaceNames: appControlWindow.workspaceList(
                        appControlWindow.selectedAppWindows
                    )

                    // ------------------------------------------------
                    // ROW 1: RUNNING : <count> WINDOWS
                    // ------------------------------------------------

                    Item {
                        Layout.preferredWidth: 92
                        Layout.preferredHeight: 24

                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0

                            radius: 7
                            samples: 7

                            opacity: 0.38
                            color: Colors.magenta

                            transparentBorder: true
                        }

                        GohuText {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter

                            text: "RUNNING"

                            font.pixelSize: 15
                            color: Colors.magenta
                        }
                    }

                    GohuText {
                        Layout.preferredWidth: 10
                        Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignVCenter

                        text: ":"

                        font.pixelSize: 15
                        color: Colors.white

                        verticalAlignment: Text.AlignVCenter
                    }

                    Row {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignVCenter

                        spacing: 5

                        GohuText {
                            anchors.verticalCenter: parent.verticalCenter

                            text: appControlWindow.selectedAppWindows.length

                            font.pixelSize: 15
                            color: Colors.magenta

                            layer.enabled: true
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0

                                radius: 7
                                samples: 7

                                opacity: 0.38
                                color: Colors.magenta

                                transparentBorder: true
                            }
                        }

                        GohuText {
                            anchors.verticalCenter: parent.verticalCenter

                            text: appControlWindow.selectedAppWindows.length === 1
                                  ? "WINDOW"
                                  : "WINDOWS"

                            font.pixelSize: 15
                            color: Colors.cyan

                            layer.enabled: true
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0

                                radius: 7
                                samples: 7

                                opacity: 0.38
                                color: Colors.cyan

                                transparentBorder: true
                            }
                        }
                    }

                    // ------------------------------------------------
                    // ROW 2: WORKSPACE : 1, 4, 6
                    // ------------------------------------------------

                    Item {
                        Layout.preferredWidth: 92
                        Layout.preferredHeight: 24

                        GohuText {
                            anchors.left: parent.left
                            anchors.leftMargin: 6
                            anchors.verticalCenter: parent.verticalCenter

                            text: runningStateGrid.workspaceNames.length === 1
                                  ? "WORKSPACE"
                                  : "WORKSPACES"

                            font.pixelSize: 13
                            color: Colors.white
                            opacity: 1.0

                            layer.enabled: true
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0

                                radius: 7
                                samples: 7

                                opacity: 0.38
                                color: Colors.cyan

                                transparentBorder: true
                            }
                        }
                    }

                    GohuText {
                        Layout.preferredWidth: 10
                        Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignVCenter

                        text: ":"

                        font.pixelSize: 13
                        color: Colors.white

                        verticalAlignment: Text.AlignVCenter
                    }

                    Row {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 24
                        Layout.alignment: Qt.AlignVCenter

                        spacing: 0

                        Repeater {
                            model: runningStateGrid.workspaceNames

                            Row {
                                required property int index
                                required property var modelData

                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 0

                                GohuText {
                                    text: modelData

                                    font.pixelSize: 13
                                    color: Colors.orange

                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        horizontalOffset: 0
                                        verticalOffset: 0

                                        radius: 7
                                        samples: 7

                                        opacity: 0.38
                                        color: Colors.orange

                                        transparentBorder: true
                                    }
                                }

                                GohuText {
                                    visible: index < runningStateGrid.workspaceNames.length - 1

                                    text: ", "

                                    font.pixelSize: 13
                                    color: Colors.white
                                }
                            }
                        }
                    }
                }
            }

            Column {
                id: appActionSection

                width: parent.width
                spacing: 8

                visible: appControlWindow.selectedModeIndex === 0
                         && appControlWindow.selectedResult() !== null

                Item {
                    width: actionsHeaderText.implicitWidth
                    height: actionsHeaderText.implicitHeight

                    GohuText {
                        id: actionsHeaderText

                        text: "ACTIONS"

                        font.pixelSize: 13

                        color: Colors.cyan
                        opacity: 0.75
                    }

                    DropShadow {
                        anchors.fill: actionsHeaderText
                        source: actionsHeaderText

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 5
                        samples: 5

                        z: 2

                        opacity: 0.20
                        color: Colors.cyan

                        transparentBorder: true
                    }
                }

                Rectangle {
                    id: launchAction

                    width: parent.width - 10
                    height: 38

                    anchors.horizontalCenter: parent.horizontalCenter

                    property bool isHovered: !appControlWindow.keyboardActive && launchMouse.containsMouse
                    property bool isPressed: launchMouse.pressed
                    property bool isSelected: appControlWindow.detailFocused
                                              && appControlWindow.selectedDetailActionIndex === 0

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: isHovered || isSelected ? Colors.orange : Colors.cyan

                    GohuText {
                        id: launchActionText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        text: "LAUNCH"

                        font.pixelSize: 15

                        color: launchAction.isPressed
                               ? Colors.black
                               : launchAction.isHovered || launchAction.isSelected
                               ? Colors.orange
                               : Colors.cyan
                    }

                    DropShadow {
                        anchors.fill: launchActionText
                        source: launchActionText

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 7
                        samples: 5

                        z: 2

                        opacity: !launchAction.isPressed
                                 && !launchAction.isHovered
                                 && !launchAction.isSelected
                                 ? 0.26
                                 : 0.0

                        color: Colors.cyan
                        transparentBorder: true
                    }

                    MouseArea {
                        id: launchMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onEntered: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.selectedDetailActionIndex = 0;
                        }

                        onClicked: {
                            appControlWindow.selectedDetailActionIndex = 0;
                            appControlWindow.activateSelectedDetailAction();
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 4
                        z: -1

                        opacity: launchAction.isHovered || launchAction.isSelected
                                 ? 0.42
                                 : 0.10

                        color: launchAction.isHovered || launchAction.isSelected
                               ? Colors.orange
                               : Colors.cyan
                    }
                }

                GohuText {
                    property var currentResult: appControlWindow.selectedResult()

                    text: currentResult && currentResult.actions.length > 0
                          ? "DESKTOP ACTIONS"
                          : ""

                    visible: text.length > 0

                    font.pixelSize: 13

                    color: Colors.orange
                    opacity: 0.75

                    layer.enabled: visible
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 5
                        samples: 5

                        opacity: 0.20
                        color: Colors.orange

                        transparentBorder: true
                    }
                }

                Repeater {
                    id: desktopActionsRepeater

                    model: {
                        const entry = appControlWindow.selectedResult();

                        if (appControlWindow.selectedModeIndex !== 0 || !entry)
                            return [];

                        return entry.actions;
                    }

                    Rectangle {
                        id: desktopActionButton

                        required property int index
                        required property var modelData

                        width: appActionSection.width - 10
                        height: 34

                        anchors.horizontalCenter: parent.horizontalCenter

                        property bool isHovered: !appControlWindow.keyboardActive && desktopActionMouse.containsMouse
                        property bool isPressed: desktopActionMouse.pressed
                        property bool isSelected: appControlWindow.detailFocused
                                                  && appControlWindow.selectedDetailActionIndex === index + 1

                        color: isPressed
                               ? Colors.magenta
                               : isHovered || isSelected
                               ? Colors.yellow
                               : Colors.black

                        border.width: 1
                        border.color: Colors.orange

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10

                            spacing: 8

                            Image {
                                width: 18
                                height: 18

                                source: modelData.icon
                                        ? Quickshell.iconPath(modelData.icon, true)
                                        : ""

                                visible: source.toString().length > 0

                                fillMode: Image.PreserveAspectFit
                                smooth: false
                            }

                            Item {
                                width: desktopActionText.implicitWidth
                                height: desktopActionText.implicitHeight

                                anchors.verticalCenter: parent.verticalCenter

                                GohuText {
                                    id: desktopActionText

                                    anchors.centerIn: parent

                                    text: modelData.name || "ACTION"

                                    font.pixelSize: 14

                                    color: desktopActionButton.isPressed
                                           ? Colors.black
                                           : Colors.orange
                                }

                                DropShadow {
                                    anchors.fill: desktopActionText
                                    source: desktopActionText

                                    horizontalOffset: 0
                                    verticalOffset: 0

                                    radius: 7
                                    samples: 5

                                    z: 2

                                    opacity: !desktopActionButton.isPressed
                                             && !desktopActionButton.isHovered
                                             && !desktopActionButton.isSelected
                                             ? 0.26
                                             : 0.0

                                    color: Colors.orange
                                    transparentBorder: true
                                }
                            }
                        }

                        MouseArea {
                            id: desktopActionMouse

                            anchors.fill: parent
                            hoverEnabled: true

                            onEntered: {
                                appControlWindow.keyboardActive = false;
                                appControlWindow.selectedDetailActionIndex = index + 1;
                            }

                            onClicked: {
                                appControlWindow.selectedDetailActionIndex = index + 1;
                                appControlWindow.activateSelectedDetailAction();
                            }
                        }

                        RectangularShadow {
                            anchors.fill: parent

                            spread: 4
                            z: -1

                            opacity: desktopActionButton.isHovered || desktopActionButton.isSelected
                                     ? 0.38
                                     : 0.10

                            color: Colors.orange
                        }
                    }
                }
            }

                Item {
                    id: detailHintGlowBox

                    width: detailHintText.implicitWidth + 24
                    height: detailHintText.implicitHeight + 16

                    property color hintColor: appControlWindow.detailFocused
                                              ? Colors.orange
                                              : Colors.cyan

                    layer.enabled: true
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 7
                        samples: 7

                        opacity: 0.38

                        color: detailHintGlowBox.hintColor

                        transparentBorder: true
                    }

                    GohuText {
                        id: detailHintText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        text: appControlWindow.detailFocused
                              ? "DETAIL MODE ACTIVE"
                              : "RIGHT → DETAILS"

                        font.pixelSize: 15

                        color: detailHintGlowBox.hintColor
                    }
                }
            }
        }

        // ========================================================
        // APP CONTROL SCROLLBAR
        // ========================================================

        Rectangle {
            id: detailScrollTrack

            width: 10

            anchors.top: detailStaticHeader.bottom
            anchors.bottom: detailFlickable.bottom
            anchors.right: parent.right

            anchors.topMargin: -1
            anchors.rightMargin: 7

            color: Colors.cyan

            opacity: detailFlickable.contentHeight > detailFlickable.height + 1
                     ? 0.9
                     : 0.0

            visible: opacity > 0.0

            z: 300

            property real maxContentY: Math.max(
                0,
                detailFlickable.contentHeight - detailFlickable.height
            )

            property real handleTravel: Math.max(
                0,
                height - detailScrollHandle.height
            )

            function setScrollFromHandleY(handleY) {
                if (maxContentY <= 0 || handleTravel <= 0)
                    return;

                const clampedY = Math.max(
                    0,
                    Math.min(handleTravel, handleY)
                );

                detailFlickable.contentY =
                    (clampedY / handleTravel) * maxContentY;
            }

            Rectangle {
                id: detailScrollHandle

                width: 6
                anchors.horizontalCenter: parent.horizontalCenter

                height: Math.max(
                    30,
                    parent.height * Math.min(
                        1.0,
                        detailFlickable.visibleArea.heightRatio
                    )
                )

                y: {
                    if (detailScrollTrack.maxContentY <= 0
                            || detailScrollTrack.handleTravel <= 0)
                        return 0;

                    const clampedContentY = Math.max(
                        0,
                        Math.min(
                            detailScrollTrack.maxContentY,
                            detailFlickable.contentY
                        )
                    );

                    return (clampedContentY / detailScrollTrack.maxContentY)
                            * detailScrollTrack.handleTravel;
                }

                color: Colors.magenta

                RectangularShadow {
                    anchors.fill: parent

                    spread: 2
                    z: -1

                    opacity: 0.16
                    color: Colors.magenta
                }
            }

            MouseArea {
                id: detailScrollMouse

                anchors.fill: parent

                hoverEnabled: true
                acceptedButtons: Qt.LeftButton

                property real dragOffset: 0

                onPressed: function(mouse) {
                    const handleTop = detailScrollHandle.y;
                    const handleBottom =
                        detailScrollHandle.y + detailScrollHandle.height;

                    if (mouse.y >= handleTop && mouse.y <= handleBottom) {
                        dragOffset = mouse.y - detailScrollHandle.y;
                    } else {
                        dragOffset = detailScrollHandle.height / 2;

                        detailScrollTrack.setScrollFromHandleY(
                            mouse.y - dragOffset
                        );
                    }

                    mouse.accepted = true;
                }

                onPositionChanged: function(mouse) {
                    if (!pressed)
                        return;

                    detailScrollTrack.setScrollFromHandleY(
                        mouse.y - dragOffset
                    );
                }

                onWheel: function(wheel) {
                    // Keep wheel/trackpad scrolling available to the Flickable.
                    wheel.accepted = false;
                }
            }
        }

        Rectangle {
            id: detailBottomBar

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            anchors.leftMargin: 5
            anchors.rightMargin: 5
            anchors.bottomMargin: 10

            height: 2

            color: Colors.cyan
        }
    }

    // ============================================================
    // APP SELECTOR / CONTROL PANE DIVIDER
    // ============================================================

    Rectangle {
        id: resultsDetailDivider

        width: 1

        anchors.left: detailPane.left
        anchors.top: background.top
        anchors.bottom: background.bottom

        color: appControlWindow.detailFocused
               && appControlWindow.selectedModeIndex === 0
               ? Colors.orange
               : Colors.cyan

        z: 1002
    }

    // ============================================================
    // MODE / APP SELECTOR DIVIDER
    // ============================================================

    Rectangle {
        id: modeResultsDivider

        width: 1

        anchors.left: resultsPane.left
        anchors.top: background.top
        anchors.bottom: background.bottom

        color: Colors.orange

        z: 1001
    }

    // ============================================================
    // OUTER BORDER
    // ============================================================

    Rectangle {
        id: appControlBorder

        anchors.fill: background

        color: "transparent"

        border.width: 1
        border.color: Colors.orange

        z: 1000
    }

    // ============================================================
    // KEYBOARD
    // ============================================================

    function handleKey(event) {
        keyboardActive = true;

        if (event.key === Qt.Key_Escape) {
            if (detailFocused) {
                detailFocused = false;
                resetDetailActionSelection();
                searchInput.forceActiveFocus();
            } else {
                menuOpen = false;
            }

            event.accepted = true;
            return;
        }

        // Tab is contextual:
        //
        // APP SELECTOR:
        //   Tab       -> next mode
        //   Shift+Tab -> previous mode
        //
        // APPS CONTROL PANE:
        //   Tab       -> next application
        //   Shift+Tab -> previous application
        //
        // This lets you inspect/control neighboring apps without first
        // pressing Left to return to the selector.
        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            const backwards = event.key === Qt.Key_Backtab
                              || (event.modifiers & Qt.ShiftModifier);

            if (detailFocused && selectedModeIndex === 0) {
                moveResultSelection(backwards ? -1 : 1);
                resetDetailActionSelection();

                // moveResultSelection() intentionally marks keyboard control
                // as active; stay in the right-hand control pane.
                detailFocused = true;

                event.accepted = true;
                return;
            }

            let newModeIndex = selectedModeIndex;

            if (backwards) {
                newModeIndex--;

                if (newModeIndex < 0)
                    newModeIndex = modes.length - 1;
            } else {
                newModeIndex++;

                if (newModeIndex >= modes.length)
                    newModeIndex = 0;
            }

            switchMode(newModeIndex, true);

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Up) {
            if (detailFocused) {
                const count = detailActionCount();

                if (count === 0) {
                    event.accepted = true;
                    return;
                }

                selectedDetailActionIndex--;

                if (selectedDetailActionIndex < 0)
                    selectedDetailActionIndex = count - 1;

                ensureDetailActionVisible();

                event.accepted = true;
                return;
            }

            moveResultSelection(-1);

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Down) {
            if (detailFocused) {
                const count = detailActionCount();

                if (count === 0) {
                    event.accepted = true;
                    return;
                }

                selectedDetailActionIndex++;

                if (selectedDetailActionIndex >= count)
                    selectedDetailActionIndex = 0;

                ensureDetailActionVisible();

                event.accepted = true;
                return;
            }

            moveResultSelection(1);

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Right) {
            if (!detailFocused) {
                detailFocused = true;
                resetDetailActionSelection();
            }

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Left) {
            if (detailFocused) {
                detailFocused = false;
                resetDetailActionSelection();
                searchInput.forceActiveFocus();
            }

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (detailFocused)
                activateSelectedDetailAction();
            else
                activateSelectedResult();

            event.accepted = true;
            return;
        }
    }

    // ============================================================
    // PLACEHOLDER ACTIVATION
    // ============================================================

    function activateSelectedResult() {
        const result = selectedResult();

        if (!result)
            return;

        if (selectedModeIndex === 0) {
            console.log("AppControl: launching", result.name);
            result.execute();
            menuOpen = false;
            return;
        }

        console.log("AppControl:", modes[selectedModeIndex].name, result.label);
    }

    // ============================================================
    // OPEN / FOCUS
    // ============================================================

    onMenuOpenChanged: {
        if (menuOpen) {
            detailFocused = false;
            keyboardActive = false;
            hoveredResultIndex = -1;
            resetResultSelection();
            rememberCurrentAppSelection();
            resetDetailActionSelection();

            refreshWindowState();
            searchInput.forceActiveFocus();
        }
    }
}
