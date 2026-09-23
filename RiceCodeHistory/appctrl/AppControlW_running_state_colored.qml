import QtQuick
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

    implicitWidth: 800
    implicitHeight: 650

    color: "transparent"

    surfaceFormat.opaque: false

    focusable: true
    visible: menuOpen

    // ============================================================
    // BACKGROUND
    // ============================================================

    Rectangle {
        id: background

        anchors.fill: parent

        color: Colors.black
        opacity: 0.96
    }

    // ============================================================
    // MODE RAIL
    // ============================================================

    Rectangle {
        id: modeRail

        width: 100

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom

        color: Colors.dark

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

                    color: modeButton.isPressed ? Colors.magenta : modeButton.isHovered ? Colors.yellow : modeButton.isSelected ? Colors.yellow : Colors.dark

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

                                radius: modeButton.isSelected ? 18 : 14
                                samples: modeButton.isSelected ? 31 : 15

                                z: 2

                                opacity: modeButton.isSelected
                                         ? 1.0
                                         : modeButton.isHovered
                                         ? 0.8
                                         : 0.0

                                color: modeButton.isSelected
                                       ? Colors.magenta
                                       : modeButton.isHovered
                                       ? Colors.orange
                                       : Colors.cyan

                                transparentBorder: true
                            }
                        }

                        GohuText {
                            anchors.horizontalCenter: parent.horizontalCenter

                            text: modelData.name

                            font.pixelSize: 11

                            color: modeButton.isPressed ? Colors.black : modeButton.isHovered ? Colors.orange : modeButton.isSelected ? Colors.orange : Colors.white
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
                            appControlWindow.selectedModeIndex = index;
                            appControlWindow.detailFocused = false;
                            appControlWindow.resetResultSelection();

                            searchInput.forceActiveFocus();
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 3
                        z: -1

                        opacity: modeButton.isSelected || modeButton.isHovered ? 0.5 : 0.0

                        color: Colors.orange
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 10
                        z: 1

                        opacity: modeButton.isSelected || modeButton.isHovered ? 0.09 : 0.0

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

        color: Colors.black

        // ========================================================
        // SEARCH HEADER
        // ========================================================

        Rectangle {
            id: searchHeader

            width: parent.width
            height: 80

            anchors.top: parent.top

            color: Colors.dark

            Column {
                anchors.fill: parent

                anchors.leftMargin: 15
                anchors.rightMargin: 15
                anchors.topMargin: 12
                anchors.bottomMargin: 10

                spacing: 8

                GohuText {
                    text: appControlWindow.modes[appControlWindow.selectedModeIndex].name

                    font.pixelSize: 19

                    color: appControlWindow.selectedModeIndex === 3 ? Colors.red : Colors.cyan
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

                    clip: true

                    Keys.onPressed: function (event) {
                        appControlWindow.handleKey(event);
                    }

                    onTextChanged: {
                        if (appControlWindow.selectedModeIndex === 0)
                            appControlWindow.resetResultSelection();
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                height: 2

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

            clip: true

            model: appControlWindow.selectedModeIndex === 0 ? filteredApps : appControlWindow.placeholderResults

            currentIndex: appControlWindow.selectedResultIndex

            delegate: Rectangle {
                id: resultButton

                required property int index
                required property var modelData

                property bool isSelected: index === appControlWindow.selectedResultIndex

                property bool isHovered: !appControlWindow.keyboardActive && resultMouse.containsMouse

                property bool isPressed: resultMouse.pressed

                width: resultList.width
                height: 42

                color: resultButton.isPressed ? Colors.magenta : resultButton.isHovered ? Colors.yellow : resultButton.isSelected ? Colors.yellow : Colors.black

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 14

                    spacing: 9

                    Image {
                        width: 22
                        height: 22

                        visible: appControlWindow.selectedModeIndex === 0 && source.toString().length > 0

                        source: appControlWindow.selectedModeIndex === 0 ? Quickshell.iconPath(modelData.icon, true) : ""

                        fillMode: Image.PreserveAspectFit
                        smooth: false
                    }

                    GohuText {
                        anchors.verticalCenter: parent.verticalCenter

                        text: appControlWindow.selectedModeIndex === 0 ? modelData.name : modelData.label

                        font.pixelSize: 17

                        color: resultButton.isPressed ? Colors.black : resultButton.isHovered ? Colors.orange : resultButton.isSelected ? Colors.orange : Colors.cyan
                    }
                }

                MouseArea {
                    id: resultMouse

                    anchors.fill: parent

                    hoverEnabled: true

                    onEntered: {
                        appControlWindow.keyboardActive = false;
                        appControlWindow.selectedResultIndex = index;
                    }

                    onClicked: {
                        appControlWindow.selectedResultIndex = index;
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

        color: Colors.black

        border.width: 1

        border.color: appControlWindow.detailFocused ? Colors.orange : Colors.cyan

        Column {
            anchors.fill: parent

            anchors.margins: 25

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
                        samples: 31

                        z: 2

                        opacity: 0.9

                        color: Colors.magenta

                        transparentBorder: true
                    }
                }

                GohuText {
                    anchors.verticalCenter: parent.verticalCenter

                    text: "APPLICATION CONTROL"

                    font.pixelSize: 20

                    color: Colors.cyan
                }
            }

            Rectangle {
                width: parent.width
                height: 2

                color: Colors.cyan
            }

            Row {
                id: selectedAppIdentity

                width: parent.width
                spacing: 14

                property var currentResult: appControlWindow.selectedResult()
                property bool showingApp: appControlWindow.selectedModeIndex === 0 && currentResult

                Item {
                    width: 52
                    height: 52

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

                    DropShadow {
                        anchors.fill: selectedAppIcon
                        source: selectedAppIcon

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 12
                        samples: 17

                        opacity: selectedAppIcon.status === Image.Ready ? 0.45 : 0.0

                        color: Colors.cyan

                        transparentBorder: true
                    }
                }

                Column {
                    width: parent.width - (selectedAppIdentity.showingApp ? 66 : 0)
                    spacing: 5

                    GohuText {
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

                    GohuText {
                        width: parent.width

                        text: selectedAppIdentity.showingApp
                              ? appControlWindow.appDisplayDescription(selectedAppIdentity.currentResult)
                              : "Phase 1 placeholder"

                        font.pixelSize: 15

                        color: Colors.white
                        opacity: 0.65

                        elide: Text.ElideRight
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

                GohuText {
                    text: "RUNNING STATE"

                    font.pixelSize: 13

                    color: Colors.cyan
                    opacity: 0.75
                }

                Rectangle {
                    width: parent.width
                    height: 1

                    color: Colors.cyan
                    opacity: 0.55
                }

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

                Row {
                    spacing: 5

                    visible: appControlWindow.windowDataReady
                             && appControlWindow.selectedAppWindows.length > 0

                    GohuText {
                        text: "RUNNING"

                        font.pixelSize: 15
                        color: Colors.magenta
                    }

                    GohuText {
                        text: "//"

                        font.pixelSize: 15
                        color: Colors.white
                    }

                    GohuText {
                        text: {
                            const count = appControlWindow.selectedAppWindows.length;

                            return count === 1
                                   ? "1 WINDOW"
                                   : count + " WINDOWS";
                        }

                        font.pixelSize: 15
                        color: Colors.magenta
                    }
                }

                Row {
                    spacing: 5

                    property var workspaceNames: appControlWindow.workspaceList(
                        appControlWindow.selectedAppWindows
                    )

                    visible: workspaceNames.length > 0

                    GohuText {
                        text: "WORKSPACE"

                        font.pixelSize: 13
                        color: Colors.cyan
                        opacity: 0.65
                    }

                    GohuText {
                        text: "//"

                        font.pixelSize: 13
                        color: Colors.white
                    }

                    Row {
                        spacing: 0

                        Repeater {
                            model: parent.parent.workspaceNames

                            Row {
                                required property int index
                                required property var modelData

                                spacing: 0

                                GohuText {
                                    text: modelData

                                    font.pixelSize: 13
                                    color: Colors.orange
                                }

                                GohuText {
                                    visible: index < parent.parent.parent.parent.workspaceNames.length - 1

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

                GohuText {
                    text: "ACTIONS"

                    font.pixelSize: 13

                    color: Colors.cyan

                    opacity: 0.75
                }

                Rectangle {
                    id: launchAction

                    width: parent.width
                    height: 38

                    property bool isHovered: launchMouse.containsMouse
                    property bool isPressed: launchMouse.pressed

                    color: isPressed
                           ? Colors.magenta
                           : isHovered
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: isHovered ? Colors.orange : Colors.cyan

                    GohuText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        text: "LAUNCH"

                        font.pixelSize: 15

                        color: launchAction.isPressed
                               ? Colors.black
                               : launchAction.isHovered
                               ? Colors.orange
                               : Colors.cyan
                    }

                    MouseArea {
                        id: launchMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            const entry = appControlWindow.selectedResult();

                            if (!entry)
                                return;

                            console.log("AppControl: launching", entry.name);
                            entry.execute();
                            appControlWindow.menuOpen = false;
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 3
                        z: -1

                        opacity: launchAction.isHovered ? 0.4 : 0.0

                        color: Colors.orange
                    }
                }

                GohuText {
                    property var currentResult: appControlWindow.selectedResult()

                    text: currentResult && currentResult.actions.length > 0
                          ? "DESKTOP ACTIONS"
                          : ""

                    visible: text.length > 0

                    font.pixelSize: 13

                    color: Colors.white

                    opacity: 0.55
                }

                Repeater {
                    model: {
                        const entry = appControlWindow.selectedResult();

                        if (appControlWindow.selectedModeIndex !== 0 || !entry)
                            return [];

                        return entry.actions;
                    }

                    Rectangle {
                        id: desktopActionButton

                        required property var modelData

                        width: appActionSection.width
                        height: 34

                        property bool isHovered: desktopActionMouse.containsMouse
                        property bool isPressed: desktopActionMouse.pressed

                        color: isPressed
                               ? Colors.magenta
                               : isHovered
                               ? Colors.yellow
                               : Colors.black

                        border.width: 1
                        border.color: isHovered ? Colors.orange : Colors.cyan

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

                            GohuText {
                                anchors.verticalCenter: parent.verticalCenter

                                text: modelData.name || "ACTION"

                                font.pixelSize: 14

                                color: desktopActionButton.isPressed
                                       ? Colors.black
                                       : desktopActionButton.isHovered
                                       ? Colors.orange
                                       : Colors.cyan
                            }
                        }

                        MouseArea {
                            id: desktopActionMouse

                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                console.log(
                                    "AppControl: desktop action",
                                    modelData.name
                                );

                                modelData.execute();
                                appControlWindow.menuOpen = false;
                            }
                        }

                        RectangularShadow {
                            anchors.fill: parent

                            spread: 3
                            z: -1

                            opacity: desktopActionButton.isHovered ? 0.35 : 0.0

                            color: Colors.orange
                        }
                    }
                }
            }

            GohuText {
                text: appControlWindow.detailFocused ? "DETAIL MODE ACTIVE" : "RIGHT → DETAILS"

                font.pixelSize: 15

                color: appControlWindow.detailFocused ? Colors.orange : Colors.cyan
            }
        }
    }

    // ============================================================
    // OUTER BORDER
    // ============================================================

    Rectangle {
        id: appControlBorder

        anchors.fill: parent

        color: "transparent"

        border.width: 1
        border.color: Colors.cyan

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
            } else {
                menuOpen = false;
            }

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Tab) {
            if (event.modifiers & Qt.ShiftModifier) {
                selectedModeIndex--;

                if (selectedModeIndex < 0)
                    selectedModeIndex = modes.length - 1;
            } else {
                selectedModeIndex++;

                if (selectedModeIndex >= modes.length)
                    selectedModeIndex = 0;
            }

            detailFocused = false;
            resetResultSelection();

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Up) {
            const count = resultCount();

            if (count === 0)
                return;

            selectedResultIndex--;

            if (selectedResultIndex < 0)
                selectedResultIndex = count - 1;

            resultList.positionViewAtIndex(selectedResultIndex, ListView.Contain);

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Down) {
            const count = resultCount();

            if (count === 0)
                return;

            selectedResultIndex++;

            if (selectedResultIndex >= count)
                selectedResultIndex = 0;

            resultList.positionViewAtIndex(selectedResultIndex, ListView.Contain);

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Right) {
            detailFocused = true;

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Left) {
            if (detailFocused) {
                detailFocused = false;
                searchInput.forceActiveFocus();
            }

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
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
            resetResultSelection();

            refreshWindowState();
            searchInput.forceActiveFocus();
        }
    }
}
