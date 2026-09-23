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

    // ============================================================
    // IPC / SWAY GLOBAL TOGGLE
    // ============================================================
    //
    // Sway owns the global Mod+D keybind. It calls:
    //
    //     qs ipc call appControl toggle
    //
    // Keep the function/return types explicit: Quickshell only exposes
    // typed IPC functions.
    IpcHandler {
        target: "appControl"

        function toggle(): void {
            appControlWindow.menuOpen = !appControlWindow.menuOpen;
        }

        function open(): void {
            appControlWindow.menuOpen = true;
        }

        function close(): void {
            appControlWindow.menuOpen = false;
        }

        function isOpen(): bool {
            return appControlWindow.menuOpen;
        }
    }

    readonly property int favoritesModeIndex: 0
    readonly property int appsModeIndex: 1
    readonly property int runModeIndex: 2
    readonly property int windowsModeIndex: 3
    readonly property int thermalModeIndex: 4
    readonly property int killModeIndex: 5
    readonly property int systemModeIndex: 6

    // FAVORITES has two scopes:
    //   FAVORITES -> only explicitly starred/watched rows.
    //   COMBI     -> the same source filters over the full cross-mode catalog.
    readonly property int favoritesScopeFavorites: 0
    readonly property int favoritesScopeCombi: 1
    property int favoritesScopeMode: favoritesScopeFavorites

    // COMBI is cached so fast task/monitor updates do not rebuild thousands
    // of cross-mode wrapper rows on the UI thread every refresh.
    property var combiStaticCatalog: []
    property var combiTaskCatalog: []
    property bool combiStaticCatalogDirty: true
    property string combiStaticStructureSignature: ""
    property string combiTaskIdentitySignature: ""

    onRunAllCommandsChanged: scheduleCombiStaticCatalogRefresh()
    onRunHistoryChanged: scheduleCombiStaticCatalogRefresh()
    onSwayWindowsChanged: scheduleCombiStaticCatalogRefresh()
    onAppTabsChanged: scheduleCombiStaticCatalogRefresh()
    onThermalRowsChanged: scheduleCombiStaticCatalogRefresh()
    onFanRowsChanged: scheduleCombiStaticCatalogRefresh()
    onSystemRowsChanged: scheduleCombiStaticCatalogRefresh()
    onTaskRowsChanged: scheduleCombiTaskCatalogRefresh()

    // Source filter shared by both FAVORITES and COMBI. -1 means every mode.
    readonly property int favoritesFilterAll: -1
    property int favoritesFilterMode: favoritesFilterAll

    // FAVORITES is visually first, but APPS is the default focus.
    property int selectedModeIndex: appsModeIndex
    property int selectedResultIndex: 0

    property bool keyboardActive: false
    property bool detailFocused: false
    property int selectedDetailActionIndex: 0
    property int hoveredResultIndex: -1

    // Explicit keyboard focus for the left mode rail.
    property bool modeRailFocused: false
    property int modeRailCursorIndex: appsModeIndex
    property int modeRailHoveredIndex: -1

    function enterModeRail() {
        modeRailFocused = true;
        detailFocused = false;
        keyboardActive = true;
        modeRailCursorIndex = selectedModeIndex;
        modeRailHoveredIndex = -1;
    }

    function moveModeRailCursor(direction) {
        modeRailFocused = true;
        keyboardActive = true;
        modeRailHoveredIndex = -1;

        let next = modeRailCursorIndex;

        if (next < 0 || next >= modes.length)
            next = selectedModeIndex;

        next += direction;

        if (next < 0)
            next = modes.length - 1;
        else if (next >= modes.length)
            next = 0;

        modeRailCursorIndex = next;
    }

    function activateModeRailCursor() {
        let target = modeRailHoveredIndex >= 0
                     ? modeRailHoveredIndex
                     : modeRailCursorIndex;

        if (target < 0 || target >= modes.length)
            target = selectedModeIndex;

        modeRailFocused = false;
        modeRailHoveredIndex = -1;

        switchMode(target, false);
        searchInput.forceActiveFocus();
    }

    onSelectedResultIndexChanged: {
        scheduleRunKillProbe();
        scheduleWindowAudioProbe();

        // The TASK MANAGER detail panel is also used for KILL-sourced rows
        // selected through FAVORITES/COMBI. Keep its large CPU/MEM histories
        // bound to the task that is actually selected, rather than leaving the
        // last KILL-mode process frozen in the panel.
        if (!taskRestoringSelection && selectedResultIsTask()) {
            resetTaskHistoryForSelection();
            Qt.callLater(function() {
                appControlWindow.refreshSelectedTaskGraph();
            });
        }
    }

    onSelectedModeIndexChanged: {
        scheduleRunKillProbe();
        scheduleWindowAudioProbe();

        // FAVORITES task graphs must be self-starting. Do not require a prior
        // visit to KILL mode to seed taskRows / identity histories.
        if (menuOpen
                && selectedModeIndex === favoritesModeIndex
                && hasTaskFavorites()) {
            Qt.callLater(function() {
                appControlWindow.refreshTaskManager();
            });
        }
    }

    // FAVORITES rail-face state.
    property bool favoritesFaceClickPulse: false
    property bool favoritesFaceBlinking: false
    property bool favoritesFaceDoubleBlinkPending: false

    // KITTY prefix-face state.
    //
    // This deliberately has its OWN random schedule and timers so it never
    // locks to the FAVORITES face rhythm.
    property bool kittyFaceClickPulse: false
    property bool kittyFaceBlinking: false
    property bool kittyFaceDoubleBlinkPending: false

    // HIDDEN source-face state. Independent from KITTY/FAVORITES.
    property bool hiddenFaceBlinking: false
    property bool hiddenFaceDoubleBlinkPending: false

    function scheduleFavoritesFaceBlink() {
        if (!menuOpen)
            return;

        favoritesFaceBlinkTimer.interval =
            6500 + Math.floor(Math.random() * 6000);

        favoritesFaceBlinkTimer.restart();
    }

    Timer {
        id: favoritesFaceBlinkTimer

        repeat: false

        onTriggered: {
            // Most blinks are single. Occasionally queue a second blink.
            appControlWindow.favoritesFaceDoubleBlinkPending =
                Math.random() < 0.38;

            appControlWindow.favoritesFaceBlinking = true;
            favoritesFaceBlinkEndTimer.restart();
        }
    }

    Timer {
        id: favoritesFaceBlinkEndTimer

        interval: 170
        repeat: false

        onTriggered: {
            appControlWindow.favoritesFaceBlinking = false;

            if (appControlWindow.favoritesFaceDoubleBlinkPending) {
                appControlWindow.favoritesFaceDoubleBlinkPending = false;
                favoritesFaceSecondBlinkGapTimer.restart();
            } else {
                appControlWindow.scheduleFavoritesFaceBlink();
            }
        }
    }

    Timer {
        id: favoritesFaceSecondBlinkGapTimer

        interval: 125
        repeat: false

        onTriggered: {
            appControlWindow.favoritesFaceBlinking = true;
            favoritesFaceSecondBlinkEndTimer.restart();
        }
    }

    Timer {
        id: favoritesFaceSecondBlinkEndTimer

        interval: 170
        repeat: false

        onTriggered: {
            appControlWindow.favoritesFaceBlinking = false;
            appControlWindow.scheduleFavoritesFaceBlink();
        }
    }

    Timer {
        id: favoritesFaceClickPulseTimer

        interval: 420
        repeat: false

        onTriggered: {
            appControlWindow.favoritesFaceClickPulse = false;
        }
    }

    function scheduleKittyFaceBlink() {
        if (!menuOpen)
            return;

        // A different timing range plus independent random choices prevents
        // the two faces from behaving like synchronized indicators.
        kittyFaceBlinkTimer.interval =
            8000 + Math.floor(Math.random() * 7500);

        kittyFaceBlinkTimer.restart();
    }

    Timer {
        id: kittyFaceBlinkTimer

        repeat: false

        onTriggered: {
            appControlWindow.kittyFaceDoubleBlinkPending =
                Math.random() < 0.42;

            appControlWindow.kittyFaceBlinking = true;
            kittyFaceBlinkEndTimer.restart();
        }
    }

    Timer {
        id: kittyFaceBlinkEndTimer

        interval: 155
        repeat: false

        onTriggered: {
            appControlWindow.kittyFaceBlinking = false;

            if (appControlWindow.kittyFaceDoubleBlinkPending) {
                appControlWindow.kittyFaceDoubleBlinkPending = false;
                kittyFaceSecondBlinkGapTimer.restart();
            } else {
                appControlWindow.scheduleKittyFaceBlink();
            }
        }
    }

    Timer {
        id: kittyFaceSecondBlinkGapTimer

        interval: 140
        repeat: false

        onTriggered: {
            appControlWindow.kittyFaceBlinking = true;
            kittyFaceSecondBlinkEndTimer.restart();
        }
    }

    Timer {
        id: kittyFaceSecondBlinkEndTimer

        interval: 155
        repeat: false

        onTriggered: {
            appControlWindow.kittyFaceBlinking = false;
            appControlWindow.scheduleKittyFaceBlink();
        }
    }

    Timer {
        id: kittyFaceClickPulseTimer

        interval: 420
        repeat: false

        onTriggered: {
            appControlWindow.kittyFaceClickPulse = false;
        }
    }

    function scheduleHiddenFaceBlink() {
        if (!menuOpen)
            return;

        // HIDDEN deliberately blinks less often than KITTY/FAVORITES.
        // Keep its cadence independent so the face feels occasional rather
        // than like a synchronized status indicator.
        hiddenFaceBlinkTimer.interval =
            14000 + Math.floor(Math.random() * 10000);

        hiddenFaceBlinkTimer.restart();
    }

    Timer {
        id: hiddenFaceBlinkTimer
        repeat: false

        onTriggered: {
            appControlWindow.hiddenFaceDoubleBlinkPending =
                Math.random() < 0.40;
            appControlWindow.hiddenFaceBlinking = true;
            hiddenFaceBlinkEndTimer.restart();
        }
    }

    Timer {
        id: hiddenFaceBlinkEndTimer
        interval: 165
        repeat: false

        onTriggered: {
            appControlWindow.hiddenFaceBlinking = false;

            if (appControlWindow.hiddenFaceDoubleBlinkPending) {
                appControlWindow.hiddenFaceDoubleBlinkPending = false;
                hiddenFaceSecondBlinkGapTimer.restart();
            } else {
                appControlWindow.scheduleHiddenFaceBlink();
            }
        }
    }

    Timer {
        id: hiddenFaceSecondBlinkGapTimer
        interval: 135
        repeat: false

        onTriggered: {
            appControlWindow.hiddenFaceBlinking = true;
            hiddenFaceSecondBlinkEndTimer.restart();
        }
    }

    Timer {
        id: hiddenFaceSecondBlinkEndTimer
        interval: 165
        repeat: false

        onTriggered: {
            appControlWindow.hiddenFaceBlinking = false;
            appControlWindow.scheduleHiddenFaceBlink();
        }
    }

    // ============================================================
    // KILL MODE / BASIC TASK MANAGER
    // ============================================================

    // ============================================================
    // THERMAL MODE SUB-VIEWS
    // ============================================================

    readonly property int thermalViewThermal: 0
    readonly property int thermalViewFans: 1
    property int thermalViewMode: thermalViewThermal

    property var taskRows: []
    property bool taskSnapshotLoading: false
    property string taskSnapshotError: ""
    property int taskProcessCount: 0

    property var thermalRows: []
    property var fanRows: []
    property var systemRows: []
    property bool killMonitorLoading: false
    property string killMonitorError: ""

    function setThermalViewMode(mode) {
        thermalViewMode =
            mode === thermalViewFans
            ? thermalViewFans
            : thermalViewThermal;

        keyboardActive = true;
        hoveredResultIndex = -1;
        detailFocused = false;

        refreshKillMonitor();
        resetResultSelection();
        resetDetailActionSelection();
    }

    function selectedResultIsThermal() {
        const entry = selectedResult();
        const source = favoriteSourceItem(entry) || entry;

        return !!entry
               && resultSourceMode(entry, selectedModeIndex)
                  === thermalModeIndex
               && !!source
               && !!source._thermalRecord;
    }

    function selectedResultIsSystemComponent() {
        const entry = selectedResult();
        const source = favoriteSourceItem(entry) || entry;

        return !!entry
               && resultSourceMode(entry, selectedModeIndex)
                  === systemModeIndex
               && !!source
               && !!source._systemRecord;
    }

    function celsiusToFahrenheit(value) {
        return (Number(value || 0) * 9 / 5) + 32;
    }

    function formatThermalMenuTemp(value) {
        const c = Number(value || 0);
        const f = celsiusToFahrenheit(c);

        return f.toFixed(1) + "°F / " + c.toFixed(1) + "°C";
    }

    function thermalColorForCelsius(value) {
        const temp = Number(value || 0);

        if (temp < 30)
            return Colors.white;
        if (temp < 40)
            return Colors.yellow;
        if (temp < 50)
            return Colors.omnitrix;
        if (temp < 60)
            return Colors.cyan;
        if (temp < 70)
            return Colors.orange;
        if (temp < 80)
            return Colors.magenta;

        return Colors.red;
    }

    function thermalAccent(entry) {
        if (entry && entry.sensorKind === "fan")
            return Colors.omnitrix;

        return thermalColorForCelsius(
            Number(entry && entry.tempC || 0)
        );
    }

    function systemAccent(entry) {
        const category =
            String(entry && entry.category || "").toUpperCase();

        if (category === "CPU")
            return Colors.orange;
        if (category === "MEMORY")
            return Colors.magenta;
        if (category === "GPU")
            return Colors.omnitrix;
        if (category === "STORAGE")
            return Colors.cyan;
        if (category === "NETWORK")
            return Colors.blue;
        if (category === "SWAP")
            return Colors.yellow;

        return Colors.white;
    }

    function systemIconFor(entry) {
        const category =
            String(entry && entry.category || "").toUpperCase();

        if (category === "CPU")
            return "▣";
        if (category === "MEMORY")
            return "▤";
        if (category === "GPU")
            return "▧";
        if (category === "STORAGE")
            return "◫";
        if (category === "NETWORK")
            return "⌁";
        if (category === "SWAP")
            return "⇄";

        return "🖳";
    }

    function monitorResultIcon(entry) {
        if (!entry)
            return "";

        if (entry._taskRecord)
            return "(╭ರ_•́)";

        if (entry._thermalRecord)
            return entry.sensorKind === "fan" ? "✇" : "🌡";

        if (entry._systemRecord)
            return systemIconFor(entry);

        return "";
    }

    property bool systemRebootArmed: false

    // Shared confirmation state for destructive global actions. The default
    // keyboard choice is always CANCEL.
    property bool destructiveConfirmOpen: false
    property string destructiveConfirmKind: ""
    property string destructiveConfirmTitle: ""
    property string destructiveConfirmMessage: ""
    property string destructiveConfirmActionLabel: "CONFIRM"
    property int destructiveConfirmChoice: 0 // 0=CANCEL, 1=CONFIRM
    property var destructiveConfirmTargetPids: []

    function openDestructiveConfirm(kind, title, message, actionLabel) {
        destructiveConfirmKind = String(kind || "");
        destructiveConfirmTitle = String(title || "CONFIRM ACTION");
        destructiveConfirmMessage = String(message || "");
        destructiveConfirmActionLabel = String(actionLabel || "CONFIRM");
        destructiveConfirmChoice = 0;
        destructiveConfirmTargetPids = [];
        destructiveConfirmOpen = true;
        detailFocused = false;
        modeRailFocused = false;
        keyboardActive = true;
    }

    function cancelDestructiveConfirm() {
        destructiveConfirmOpen = false;
        destructiveConfirmKind = "";
        destructiveConfirmChoice = 0;
        destructiveConfirmTargetPids = [];
        Qt.callLater(function() { searchInput.forceActiveFocus(); });
    }

    function executeDestructiveConfirm() {
        const kind = destructiveConfirmKind;
        const targetPids = destructiveConfirmTargetPids.slice();
        destructiveConfirmOpen = false;
        destructiveConfirmKind = "";
        destructiveConfirmChoice = 0;
        destructiveConfirmTargetPids = [];

        if (kind === "kill-all")
            executeKillAllEligibleTasks(targetPids);
        else if (kind === "reboot")
            Quickshell.execDetached(["systemctl", "reboot"]);
    }

    function systemComponentWarning(entry) {
        if (!entry)
            return "";

        if (entry.controlKind === "network" && entry.canReboot)
            return "⚠ DISCONNECT MAY DROP NETWORK • REBOOT RESTARTS PC";

        if (entry.controlKind === "network")
            return "⚠ DISCONNECT MAY DROP NETWORK";

        if (entry.canReboot)
            return "⚠ REBOOT RESTARTS THIS PC";

        return "";
    }

    function runSystemComponentAction(entry, action) {
        if (!entry || !action)
            return;

        if (action === "disconnect") {
            if (entry.controlKind !== "network"
                    || !entry.canDisconnect
                    || !entry.controlTarget)
                return;

            Quickshell.execDetached([
                "nmcli",
                "device",
                "disconnect",
                String(entry.controlTarget)
            ]);

            systemControlRefreshTimer.restart();
            return;
        }

        if (action === "reconnect") {
            if (entry.controlKind !== "network"
                    || !entry.canReconnect
                    || !entry.controlTarget)
                return;

            Quickshell.execDetached([
                "nmcli",
                "device",
                "connect",
                String(entry.controlTarget)
            ]);

            systemControlRefreshTimer.restart();
            return;
        }

        if (action === "reboot") {
            if (!entry.canReboot)
                return;

            openDestructiveConfirm(
                "reboot",
                "⚠ CONFIRM REBOOT ⚠",
                "REBOOT THE SYSTEM?\nUNSAVED WORK MAY BE LOST.",
                "REBOOT"
            );
        }
    }

    function terminateSystemContributor(entry) {
        if (!entry
                || !entry.killable
                || Number(entry.pid || 0) <= 1)
            return;

        Quickshell.execDetached([
            "kill",
            "-TERM",
            String(entry.pid)
        ]);

        systemControlRefreshTimer.restart();
    }

    Timer {
        id: systemRebootArmTimer

        interval: 5000
        repeat: false

        onTriggered: {
            appControlWindow.systemRebootArmed = false;
        }
    }

    Timer {
        id: systemControlRefreshTimer

        interval: 450
        repeat: false

        onTriggered: {
            appControlWindow.refreshKillMonitor();
        }
    }

    function contributorRows(entry) {
        if (!entry || !Array.isArray(entry.contributors))
            return [];

        return entry.contributors;
    }

    property int taskHistoryPid: 0
    property bool taskRestoringSelection: false
    property var taskCpuHistory: []
    property var taskMemHistory: []
    readonly property int taskHistoryLimit: 132

    property var taskMiniCpuHistories: ({})
    // Raw /proc CPU tick snapshots used to turn the task-list mini graphs into
    // recent CPU activity rather than ps's lifetime-average %CPU value.
    property var taskMiniCpuTickSamples: ({})
    // FAVORITES task rows are persistent-identity based rather than PID based.
    // Keep a second history keyed by that identity so their graphs survive
    // live row replacement / PID changes and do not render as empty boxes.
    property var taskMiniCpuIdentityHistories: ({})
    // Explicit revision signal for mini-graph canvases. QML does not always
    // invalidate a Canvas binding when a nested JS-array stored in an object
    // is replaced, so bump this on every task snapshot and repaint directly.
    property int taskMiniHistoryRevision: 0
    readonly property int taskMiniHistoryLimit: 48

    // Graph geometry is generated as ordinary QML points and rendered with
    // Rectangle segments below. This deliberately avoids Qt Canvas for the
    // live task graphs: Canvas contexts can survive PanelWindow hide/show with
    // stale paint state, which was producing black traces and invisible
    // FAVORITES graphs after closing/reopening AppControl.
    function graphLinePoints(values, graphWidth, graphHeight, requiredRange, slotCount, topInset, bottomInset) {
        const source = Array.isArray(values) ? values.slice() : [];

        if (source.length === 0)
            return [];

        if (source.length === 1)
            source.unshift(source[0]);

        let minimum = Number(source[0] || 0);
        let maximum = minimum;

        for (let i = 1; i < source.length; i++) {
            const value = Number(source[i] || 0);
            minimum = Math.min(minimum, value);
            maximum = Math.max(maximum, value);
        }

        const wantedRange = Math.max(0.0001, Number(requiredRange || 1));
        let range = Math.max(wantedRange, maximum - minimum);
        let lower = Math.max(0, minimum - range * 0.24);
        let upper = maximum + range * 0.24;

        if (upper - lower < wantedRange) {
            const center = (upper + lower) / 2;
            lower = Math.max(0, center - wantedRange / 2);
            upper = lower + wantedRange;
        }

        const width = Math.max(1, Number(graphWidth || 1));
        const height = Math.max(1, Number(graphHeight || 1));
        const top = Math.max(0, Number(topInset === undefined ? 2 : topInset));
        const bottom = Math.max(top + 1, height - Math.max(0, Number(bottomInset === undefined ? 2 : bottomInset)));
        const slots = Math.max(2, Number(slotCount || source.length));
        const step = width / Math.max(1, slots - 1);
        const startX = width - step * (source.length - 1);
        const points = [];

        for (let i = 0; i < source.length; i++) {
            const normalized = Math.max(0, Math.min(1,
                (Number(source[i] || 0) - lower)
                / Math.max(0.0001, upper - lower)
            ));
            points.push(Qt.point(
                startX + i * step,
                bottom - normalized * Math.max(1, bottom - top)
            ));
        }

        return points;
    }

    function canvasCssColor(colorValue, alphaMultiplier) {
        const alpha = Math.max(
            0,
            Math.min(
                1,
                Number(colorValue.a)
                * (alphaMultiplier === undefined
                   ? 1.0
                   : Number(alphaMultiplier))
            )
        );

        return "rgba("
               + String(Math.round(Number(colorValue.r) * 255)) + ","
               + String(Math.round(Number(colorValue.g) * 255)) + ","
               + String(Math.round(Number(colorValue.b) * 255)) + ","
               + String(alpha) + ")";
    }

    function taskIdentityForEntry(entry) {
        if (!entry)
            return "";

        // FAVORITES task wrappers already persist the canonical identity in
        // their favorite key. Prefer that over the wrapper's _sourceItem: the
        // source can be an offline placeholder created before the next live
        // task snapshot arrives.
        if (entry._favoriteRecord
                && String(entry._favoriteType || "") === "task") {
            const stored = taskIdentityFromFavoriteKey(entry._favoriteKey);
            if (stored)
                return String(stored).trim().toLowerCase();
        }

        return taskPersistentIdentity(entry);
    }

    function liveTaskForMiniGraph(entry) {
        const source = favoriteSourceItem(entry) || entry;
        if (!source || !source._taskRecord)
            return null;

        // Always try the newest task snapshot first, not only for wrappers.
        // This makes FAVORITES use the exact same live values/PID history as
        // KILL and prevents offline favorite records from showing all zeroes.
        const identity = taskIdentityForEntry(entry);
        if (identity) {
            let best = null;

            for (let i = 0; i < taskRows.length; i++) {
                const candidate = taskRows[i];
                if (taskPersistentIdentity(candidate) !== identity)
                    continue;
                if (Number(candidate.pid || 0) <= 0)
                    continue;
                if (!best || Number(candidate.cpu || 0) > Number(best.cpu || 0))
                    best = candidate;
            }

            if (best)
                return best;
        }

        return source;
    }

    function taskMiniCpuHistoryByIdentity(identity, liveEntry) {
        const normalized = String(identity || "").trim().toLowerCase();
        const source = liveEntry || null;
        const pid = Number(source && source.pid || 0);

        // If the process is live, use the exact PID history first. This is the
        // same series the KILL row uses and avoids a favorite being flattened
        // by the identity-level aggregate when multiple processes share comm.
        if (pid > 0) {
            const pidHistory = taskMiniCpuHistories["pid:" + String(pid)];
            if (Array.isArray(pidHistory) && pidHistory.length >= 2)
                return pidHistory;
            if (Array.isArray(pidHistory) && pidHistory.length === 1)
                return [pidHistory[0], pidHistory[0]];
        }

        // Identity history remains the persistence fallback across PID churn.
        if (normalized) {
            const identityHistory =
                taskMiniCpuIdentityHistories["identity:" + normalized];

            if (Array.isArray(identityHistory) && identityHistory.length >= 2)
                return identityHistory;
            if (Array.isArray(identityHistory) && identityHistory.length === 1)
                return [identityHistory[0], identityHistory[0]];
        }

        // Keep the graph visible even before the first snapshot. If the process
        // is live this becomes its current CPU level; otherwise it sits at zero
        // until the identity history receives its first real sample.
        const current = Math.max(
            0,
            Math.min(100, Number(source && source.cpu || 0))
        );
        return [current, current];
    }

    function taskMiniCpuHistory(entry) {
        const source = liveTaskForMiniGraph(entry)
                       || favoriteSourceItem(entry)
                       || entry;
        if (!source || !source._taskRecord)
            return [];

        return taskMiniCpuHistoryByIdentity(
            taskPersistentIdentity(entry),
            source
        );
    }

    function updateTaskMiniCpuHistories(rows) {
        const previous = taskMiniCpuHistories;
        const next = ({});
        const previousIdentity = taskMiniCpuIdentityHistories;
        const nextIdentity = ({});
        const identitySamples = ({});

        for (let i = 0; i < rows.length; i++) {
            const entry = rows[i];
            const pid = Number(entry.pid || 0);
            if (pid <= 0)
                continue;

            const cpu = Math.max(
                0,
                Math.min(
                    100,
                    Number(
                        entry.cpuInstant !== undefined
                        ? entry.cpuInstant
                        : entry.cpu || 0
                    )
                )
            );
            const key = "pid:" + String(pid);
            const history = Array.isArray(previous[key])
                            ? previous[key].slice() : [];
            history.push(cpu);
            while (history.length > taskMiniHistoryLimit)
                history.shift();
            next[key] = history;

            const identity = taskPersistentIdentity(entry);
            if (identity) {
                if (identitySamples[identity] === undefined
                        || cpu > identitySamples[identity])
                    identitySamples[identity] = cpu;
            }
        }

        for (const identity in identitySamples) {
            const key = "identity:" + identity;
            const history = Array.isArray(previousIdentity[key])
                            ? previousIdentity[key].slice() : [];
            history.push(identitySamples[identity]);
            while (history.length > taskMiniHistoryLimit)
                history.shift();
            nextIdentity[key] = history;
        }

        taskMiniCpuHistories = next;
        taskMiniCpuIdentityHistories = nextIdentity;
    }

    property int taskGraphProbePid: 0
    property real taskGraphProbeLastTicks: -1
    property real taskGraphProbeLastMs: 0
    property bool taskGraphProbeLoading: false

    function killMonitorScript() {
        return "import glob\nimport json\nimport os\nimport platform\nimport re\nimport shutil\nimport subprocess\nimport time\n\ndef read_text(path, default=\"\"):\n    try:\n        with open(path, \"r\", encoding=\"utf-8\", errors=\"ignore\") as handle:\n            return handle.read().strip()\n    except Exception:\n        return default\n\ndef read_num(path, default=0.0):\n    try:\n        return float(read_text(path, str(default)))\n    except Exception:\n        return float(default)\n\ndef human_bytes(value):\n    value = float(value or 0)\n    units = [\"B\", \"KiB\", \"MiB\", \"GiB\", \"TiB\"]\n    index = 0\n    while value >= 1024.0 and index < len(units) - 1:\n        value /= 1024.0\n        index += 1\n    if index == 0:\n        return \"%d %s\" % (int(value), units[index])\n    return \"%.1f %s\" % (value, units[index])\n\ndef cpu_sample():\n    raw = read_text(\"/proc/stat\")\n    first = raw.splitlines()[0].split() if raw else []\n    nums = [int(v) for v in first[1:]] if len(first) > 1 else [0] * 10\n    while len(nums) < 8:\n        nums.append(0)\n    idle = nums[3] + nums[4]\n    return sum(nums), idle\n\ndef net_sample():\n    rows = {}\n    raw = read_text(\"/proc/net/dev\")\n    for line in raw.splitlines()[2:]:\n        if \":\" not in line:\n            continue\n        name, data = line.split(\":\", 1)\n        fields = data.split()\n        if len(fields) >= 9:\n            rows[name.strip()] = (int(fields[0]), int(fields[8]))\n    return rows\n\ndef disk_sample():\n    rows = {}\n    for line in read_text(\"/proc/diskstats\").splitlines():\n        fields = line.split()\n        if len(fields) < 14:\n            continue\n        name = fields[2]\n        if name.startswith((\"loop\", \"ram\", \"zram\")):\n            continue\n        try:\n            rows[name] = (int(fields[5]), int(fields[9]))\n        except Exception:\n            pass\n    return rows\n\ndef ps_rows():\n    rows = []\n    try:\n        proc = subprocess.run(\n            [\"ps\", \"-eo\", \"pid=,comm=,pcpu=,pmem=,rss=,args=\"],\n            stdout=subprocess.PIPE,\n            stderr=subprocess.DEVNULL,\n            text=True,\n            timeout=2.0\n        )\n        for raw in proc.stdout.splitlines():\n            line = raw.strip()\n            if not line:\n                continue\n            fields = line.split(None, 5)\n            if len(fields) < 5:\n                continue\n            pid = int(fields[0])\n\n            if pid == os.getpid():\n                continue\n\n            killable = True\n\n            try:\n                os.kill(pid, 0)\n            except PermissionError:\n                killable = False\n            except ProcessLookupError:\n                continue\n            except Exception:\n                killable = False\n\n            rows.append({\n                \"pid\": pid,\n                \"killable\": killable,\n                \"name\": fields[1],\n                \"cpu\": float(fields[2] or 0),\n                \"mem\": float(fields[3] or 0),\n                \"rss\": int(fields[4] or 0) * 1024,\n                \"args\": fields[5] if len(fields) > 5 else fields[1]\n            })\n    except Exception:\n        pass\n    return rows\n\ndef proc_swap_bytes(pid):\n    total = 0\n    for line in read_text(\"/proc/%d/status\" % pid).splitlines():\n        if line.startswith(\"VmSwap:\"):\n            try:\n                total = int(line.split()[1]) * 1024\n            except Exception:\n                pass\n            break\n    return total\n\ndef proc_io(pid):\n    result = {\"read\": 0, \"write\": 0}\n    for line in read_text(\"/proc/%d/io\" % pid).splitlines():\n        if \":\" not in line:\n            continue\n        key, value = line.split(\":\", 1)\n        try:\n            number = int(value.strip())\n        except Exception:\n            continue\n        if key == \"read_bytes\":\n            result[\"read\"] = number\n        elif key == \"write_bytes\":\n            result[\"write\"] = number\n    return result\n\ndef parse_size_value(text):\n    parts = str(text or \"\").split()\n    if not parts:\n        return 0\n    try:\n        value = float(parts[0])\n    except Exception:\n        return 0\n    unit = parts[1].lower() if len(parts) > 1 else \"b\"\n    if unit.startswith(\"k\"):\n        value *= 1024\n    elif unit.startswith(\"m\"):\n        value *= 1024 ** 2\n    elif unit.startswith(\"g\"):\n        value *= 1024 ** 3\n    return int(value)\n\ndef proc_gpu(pid):\n    engine_ns = 0\n    vram = 0\n    for fdinfo in glob.glob(\"/proc/%d/fdinfo/*\" % pid):\n        content = read_text(fdinfo)\n        if \"drm-\" not in content:\n            continue\n        for line in content.splitlines():\n            if line.startswith(\"drm-engine-\") and \":\" in line:\n                try:\n                    value = line.split(\":\", 1)[1].strip().split()[0]\n                    engine_ns += int(value)\n                except Exception:\n                    pass\n            elif line.startswith(\"drm-memory-vram:\"):\n                vram += parse_size_value(line.split(\":\", 1)[1].strip())\n    return {\"engine\": engine_ns, \"vram\": vram}\n\ndef contributor(row, value, value_text):\n    return {\n        \"pid\": row.get(\"pid\", 0),\n        \"name\": row.get(\"name\", \"PROCESS\"),\n        \"args\": row.get(\"args\", \"\"),\n        \"cpu\": row.get(\"cpu\", 0.0),\n        \"mem\": row.get(\"mem\", 0.0),\n        \"killable\": bool(row.get(\"killable\", False)),\n        \"value\": float(value or 0),\n        \"valueText\": value_text\n    }\n\nps0 = ps_rows()\nps0.sort(key=lambda r: r.get(\"cpu\", 0), reverse=True)\ncandidate_pids = [row[\"pid\"] for row in ps0[:140]]\n\nio0 = {}\ngpu0 = {}\nfor pid in candidate_pids:\n    io0[pid] = proc_io(pid)\n    gpu0[pid] = proc_gpu(pid)\n\ncpu0 = cpu_sample()\nnet0 = net_sample()\ndisk0 = disk_sample()\ntime.sleep(0.16)\ndt = 0.16\ncpu1 = cpu_sample()\nnet1 = net_sample()\ndisk1 = disk_sample()\n\nps1 = ps_rows()\nps_by_pid = {row[\"pid\"]: row for row in ps1}\n\nfor row in ps1:\n    row[\"swapBytes\"] = proc_swap_bytes(row[\"pid\"])\n    row[\"ioReadRate\"] = 0.0\n    row[\"ioWriteRate\"] = 0.0\n    row[\"gpuPercent\"] = 0.0\n    row[\"gpuVram\"] = 0\n\nfor pid in candidate_pids:\n    row = ps_by_pid.get(pid)\n    if not row:\n        continue\n\n    io_after = proc_io(pid)\n    before = io0.get(pid, {\"read\": 0, \"write\": 0})\n    row[\"ioReadRate\"] = max(0.0, (io_after[\"read\"] - before[\"read\"]) / dt)\n    row[\"ioWriteRate\"] = max(0.0, (io_after[\"write\"] - before[\"write\"]) / dt)\n\n    gpu_after = proc_gpu(pid)\n    gpu_before = gpu0.get(pid, {\"engine\": 0, \"vram\": 0})\n    engine_delta = max(0, gpu_after[\"engine\"] - gpu_before[\"engine\"])\n    row[\"gpuPercent\"] = max(\n        0.0,\n        min(999.0, (engine_delta / (dt * 1_000_000_000.0)) * 100.0)\n    )\n    row[\"gpuVram\"] = gpu_after[\"vram\"]\n\ntotal_delta = max(1, cpu1[0] - cpu0[0])\nidle_delta = max(0, cpu1[1] - cpu0[1])\ncpu_usage = max(0.0, min(100.0, 100.0 * (total_delta - idle_delta) / total_delta))\n\ncpu_contributors = [\n    contributor(row, row[\"cpu\"], \"%.1f%% CPU\" % row[\"cpu\"])\n    for row in sorted(ps1, key=lambda r: r.get(\"cpu\", 0), reverse=True)\n    if row.get(\"cpu\", 0) > 0\n]\n\nmem_contributors = [\n    contributor(row, row[\"rss\"], \"%s RSS\" % human_bytes(row[\"rss\"]))\n    for row in sorted(ps1, key=lambda r: r.get(\"rss\", 0), reverse=True)\n    if row.get(\"rss\", 0) > 0\n]\n\nswap_contributors = [\n    contributor(row, row[\"swapBytes\"], \"%s SWAP\" % human_bytes(row[\"swapBytes\"]))\n    for row in sorted(ps1, key=lambda r: r.get(\"swapBytes\", 0), reverse=True)\n    if row.get(\"swapBytes\", 0) > 0\n]\n\nio_contributors = [\n    contributor(\n        row,\n        row.get(\"ioReadRate\", 0) + row.get(\"ioWriteRate\", 0),\n        \"R %s/s \u2022 W %s/s\"\n        % (human_bytes(row.get(\"ioReadRate\", 0)), human_bytes(row.get(\"ioWriteRate\", 0)))\n    )\n    for row in sorted(\n        ps1,\n        key=lambda r: r.get(\"ioReadRate\", 0) + r.get(\"ioWriteRate\", 0),\n        reverse=True\n    )\n    if row.get(\"ioReadRate\", 0) + row.get(\"ioWriteRate\", 0) > 0\n]\n\ngpu_contributors = [\n    contributor(\n        row,\n        row.get(\"gpuPercent\", 0),\n        (\"%.1f%% GPU\" % row.get(\"gpuPercent\", 0))\n        + ((\" \u2022 %s VRAM\" % human_bytes(row.get(\"gpuVram\", 0)))\n           if row.get(\"gpuVram\", 0) > 0 else \"\")\n    )\n    for row in sorted(\n        ps1,\n        key=lambda r: (r.get(\"gpuPercent\", 0), r.get(\"gpuVram\", 0)),\n        reverse=True\n    )\n    if row.get(\"gpuPercent\", 0) > 0 or row.get(\"gpuVram\", 0) > 0\n]\n\nsystemctl_available = shutil.which(\"systemctl\") is not None\nnmcli_available = shutil.which(\"nmcli\") is not None\n\nthermal = []\nfans = []\nseen_thermal = set()\nseen_fans = set()\n\nfor hwmon in sorted(glob.glob(\"/sys/class/hwmon/hwmon*\")):\n    chip = read_text(os.path.join(hwmon, \"name\"), os.path.basename(hwmon))\n\n    for input_path in sorted(glob.glob(os.path.join(hwmon, \"temp*_input\"))):\n        base = input_path[:-6]\n        label = read_text(base + \"label\", \"\")\n        if not label:\n            label = os.path.basename(base).replace(\"temp\", \"SENSOR \")\n\n        temp = read_num(input_path, 0.0) / 1000.0\n        high = read_num(base + \"max\", 0.0) / 1000.0\n        crit = read_num(base + \"crit\", 0.0) / 1000.0\n\n        key = (chip, label)\n        if key in seen_thermal:\n            continue\n        seen_thermal.add(key)\n\n        identity = (chip + \" \" + label).lower()\n\n        if any(token in identity for token in (\"gpu\", \"amdgpu\", \"nvidia\")):\n            contributors = gpu_contributors[:24]\n            contributor_note = \"ESTIMATED FROM GPU ENGINE/VRAM ACTIVITY; THE SENSOR DOES NOT ATTRIBUTE HEAT TO A PID.\"\n        elif any(token in identity for token in (\"nvme\", \"ssd\", \"drive\", \"disk\")):\n            contributors = io_contributors[:24]\n            contributor_note = \"ESTIMATED FROM LIVE PROCESS STORAGE I/O; THE SENSOR DOES NOT ATTRIBUTE HEAT TO A PID.\"\n        else:\n            contributors = cpu_contributors[:24]\n            contributor_note = \"ESTIMATED FROM PROCESS CPU ACTIVITY; HARDWARE TEMPERATURE SENSORS DO NOT DIRECTLY ATTRIBUTE HEAT TO A PID.\"\n\n        thermal.append({\n            \"_thermalRecord\": True,\n            \"sensorKind\": \"temperature\",\n            \"id\": \"thermal:%s:%s\" % (chip, label),\n            \"name\": label,\n            \"label\": label,\n            \"chip\": chip,\n            \"tempC\": temp,\n            \"highC\": high,\n            \"critC\": crit,\n            \"source\": input_path,\n            \"role\": \"HARDWARE TEMPERATURE SENSOR\",\n            \"contributors\": contributors,\n            \"contributorNote\": contributor_note\n        })\n\n    for input_path in sorted(glob.glob(os.path.join(hwmon, \"fan*_input\"))):\n        base = input_path[:-6]\n        label = read_text(base + \"label\", \"\")\n        if not label:\n            label = os.path.basename(base).replace(\"fan\", \"FAN \")\n\n        rpm = read_num(input_path, 0.0)\n        minimum = read_num(base + \"min\", 0.0)\n        maximum = read_num(base + \"max\", 0.0)\n\n        match = re.search(r\"fan(\\d+)_input$\", input_path)\n        channel = match.group(1) if match else \"\"\n        pwm_path = os.path.join(hwmon, \"pwm\" + channel) if channel else \"\"\n        enable_path = pwm_path + \"_enable\" if pwm_path else \"\"\n\n        pwm_exists = bool(pwm_path and os.path.exists(pwm_path))\n        enable_exists = bool(enable_path and os.path.exists(enable_path))\n        pwm_value = read_num(pwm_path, -1.0) if pwm_exists else -1.0\n        enable_value = read_num(enable_path, -1.0) if enable_exists else -1.0\n\n        key = (chip, label)\n        if key in seen_fans:\n            continue\n        seen_fans.add(key)\n\n        fans.append({\n            \"_thermalRecord\": True,\n            \"sensorKind\": \"fan\",\n            \"id\": \"fan:%s:%s\" % (chip, label),\n            \"name\": label,\n            \"label\": label,\n            \"chip\": chip,\n            \"rpm\": rpm,\n            \"minRpm\": minimum,\n            \"maxRpm\": maximum,\n            \"source\": input_path,\n            \"role\": \"COOLING FAN SPEED SENSOR\",\n            \"pwmPath\": pwm_path if pwm_exists else \"\",\n            \"pwmEnablePath\": enable_path if enable_exists else \"\",\n            \"pwmValue\": pwm_value,\n            \"pwmPercent\": (pwm_value / 255.0 * 100.0) if pwm_value >= 0 else -1.0,\n            \"pwmEnable\": enable_value,\n            \"controlAvailable\": pwm_exists and enable_exists,\n            \"controlWritable\": (\n                pwm_exists\n                and enable_exists\n                and os.access(pwm_path, os.W_OK)\n                and os.access(enable_path, os.W_OK)\n            ),\n            \"contributors\": cpu_contributors[:24],\n            \"contributorNote\": \"FAN DEMAND IS CONTROLLED BY FIRMWARE/HARDWARE. PROCESS CONTRIBUTIONS BELOW ARE ONLY ESTIMATED FROM ACTIVE CPU LOAD.\"\n        })\n\nif not thermal:\n    for zone in sorted(glob.glob(\"/sys/class/thermal/thermal_zone*\")):\n        name = read_text(os.path.join(zone, \"type\"), os.path.basename(zone))\n        temp = read_num(os.path.join(zone, \"temp\"), 0.0) / 1000.0\n\n        thermal.append({\n            \"_thermalRecord\": True,\n            \"sensorKind\": \"temperature\",\n            \"id\": \"thermal:\" + os.path.basename(zone),\n            \"name\": name,\n            \"label\": name,\n            \"chip\": os.path.basename(zone),\n            \"tempC\": temp,\n            \"highC\": 0.0,\n            \"critC\": 0.0,\n            \"source\": zone,\n            \"role\": \"KERNEL THERMAL ZONE\",\n            \"contributors\": cpu_contributors[:24],\n            \"contributorNote\": \"ESTIMATED FROM PROCESS CPU ACTIVITY; THIS THERMAL ZONE DOES NOT DIRECTLY ATTRIBUTE HEAT TO A PID.\"\n        })\n\nthermal.sort(key=lambda row: row.get(\"tempC\", 0.0), reverse=True)\nfans.sort(key=lambda row: row.get(\"rpm\", 0.0), reverse=True)\n\nsystem = []\n\ncpu_model = \"\"\nfor line in read_text(\"/proc/cpuinfo\").splitlines():\n    if line.lower().startswith(\"model name\") and \":\" in line:\n        cpu_model = line.split(\":\", 1)[1].strip()\n        break\nif not cpu_model:\n    cpu_model = platform.processor() or platform.machine() or \"CPU\"\n\nload1, load5, load15 = os.getloadavg()\n\nsystem.append({\n    \"_systemRecord\": True,\n    \"id\": \"system:cpu\",\n    \"name\": \"CPU\",\n    \"label\": \"CPU\",\n    \"category\": \"CPU\",\n    \"role\": \"EXECUTING USER + KERNEL WORKLOADS\",\n    \"usage\": cpu_usage,\n    \"metric\": \"%.1f%% BUSY\" % cpu_usage,\n    \"secondary\": \"%d LOGICAL CPUS\" % (os.cpu_count() or 1),\n    \"detail\": \"%s \u2022 LOAD %.2f / %.2f / %.2f\" % (cpu_model, load1, load5, load15),\n    \"controlKind\": \"system-reboot\",\n    \"controlTarget\": \"\",\n    \"canDisconnect\": False,\n    \"canReconnect\": False,\n    \"canReboot\": systemctl_available,\n    \"contributors\": cpu_contributors,\n    \"contributorNote\": \"ALL PROCESSES REPORTING NON-ZERO CPU IN THIS SNAPSHOT.\"\n})\n\nmeminfo = {}\nfor line in read_text(\"/proc/meminfo\").splitlines():\n    if \":\" not in line:\n        continue\n    key, value = line.split(\":\", 1)\n    try:\n        meminfo[key] = int(value.strip().split()[0]) * 1024\n    except Exception:\n        pass\n\nmem_total = meminfo.get(\"MemTotal\", 0)\nmem_available = meminfo.get(\"MemAvailable\", meminfo.get(\"MemFree\", 0))\nmem_used = max(0, mem_total - mem_available)\nmem_usage = (100.0 * mem_used / mem_total) if mem_total else 0.0\n\nsystem.append({\n    \"_systemRecord\": True,\n    \"id\": \"system:memory\",\n    \"name\": \"MEMORY\",\n    \"label\": \"MEMORY\",\n    \"category\": \"MEMORY\",\n    \"role\": \"ACTIVE RAM ALLOCATION + CACHE\",\n    \"usage\": mem_usage,\n    \"metric\": \"%.1f%% USED\" % mem_usage,\n    \"secondary\": \"%s / %s\" % (human_bytes(mem_used), human_bytes(mem_total)),\n    \"detail\": \"AVAILABLE %s\" % human_bytes(mem_available),\n    \"controlKind\": \"system-reboot\",\n    \"controlTarget\": \"\",\n    \"canDisconnect\": False,\n    \"canReconnect\": False,\n    \"canReboot\": systemctl_available,\n    \"contributors\": mem_contributors,\n    \"contributorNote\": \"PROCESSES SORTED BY RESIDENT MEMORY (RSS). SHARED PAGES MEAN SUMS DO NOT EQUAL TOTAL RAM.\"\n})\n\nswap_total = meminfo.get(\"SwapTotal\", 0)\nswap_free = meminfo.get(\"SwapFree\", 0)\nswap_used = max(0, swap_total - swap_free)\nswap_usage = (100.0 * swap_used / swap_total) if swap_total else 0.0\n\nsystem.append({\n    \"_systemRecord\": True,\n    \"id\": \"system:swap\",\n    \"name\": \"SWAP\",\n    \"label\": \"SWAP\",\n    \"category\": \"SWAP\",\n    \"role\": \"MEMORY PRESSURE OVERFLOW\",\n    \"usage\": swap_usage,\n    \"metric\": \"%.1f%% USED\" % swap_usage,\n    \"secondary\": \"%s / %s\" % (human_bytes(swap_used), human_bytes(swap_total)),\n    \"detail\": \"INACTIVE\" if not swap_total else \"KERNEL SWAP SPACE\",\n    \"controlKind\": \"system-reboot\",\n    \"controlTarget\": \"\",\n    \"canDisconnect\": False,\n    \"canReconnect\": False,\n    \"canReboot\": systemctl_available,\n    \"contributors\": swap_contributors,\n    \"contributorNote\": \"PROCESSES WITH NON-ZERO VmSwap.\"\n})\n\ntry:\n    du = shutil.disk_usage(\"/\")\n    root_percent = 100.0 * du.used / du.total if du.total else 0.0\n    system.append({\n        \"_systemRecord\": True,\n        \"id\": \"system:rootfs\",\n        \"name\": \"ROOT FILESYSTEM\",\n        \"label\": \"ROOT FILESYSTEM\",\n        \"category\": \"STORAGE\",\n        \"role\": \"FILESYSTEM CAPACITY + LIVE PROCESS I/O\",\n        \"usage\": root_percent,\n        \"metric\": \"%.1f%% USED\" % root_percent,\n        \"secondary\": \"%s / %s\" % (human_bytes(du.used), human_bytes(du.total)),\n        \"detail\": \"FREE %s \u2022 MOUNT /\" % human_bytes(du.free),\n        \"controlKind\": \"system-reboot\",\n        \"controlTarget\": \"\",\n        \"canDisconnect\": False,\n        \"canReconnect\": False,\n        \"canReboot\": systemctl_available,\n        \"contributors\": io_contributors,\n        \"contributorNote\": \"ACTIVE PROCESS I/O IS ATTRIBUTED FROM /proc/PID/io. PAGE-CACHE ACTIVITY MAY NOT APPEAR AS PHYSICAL I/O.\"\n    })\nexcept Exception:\n    pass\n\nfor block_path in sorted(glob.glob(\"/sys/block/*\")):\n    dev = os.path.basename(block_path)\n    if dev.startswith((\"loop\", \"ram\", \"zram\")):\n        continue\n\n    size_bytes = read_num(os.path.join(block_path, \"size\"), 0) * 512.0\n    model = read_text(os.path.join(block_path, \"device/model\"), \"\")\n    r0, w0 = disk0.get(dev, (0, 0))\n    r1, w1 = disk1.get(dev, (r0, w0))\n    read_rate = max(0.0, (r1 - r0) * 512.0 / dt)\n    write_rate = max(0.0, (w1 - w0) * 512.0 / dt)\n\n    system.append({\n        \"_systemRecord\": True,\n        \"id\": \"system:disk:\" + dev,\n        \"name\": dev.upper(),\n        \"label\": dev.upper(),\n        \"category\": \"STORAGE\",\n        \"role\": \"BLOCK STORAGE I/O\",\n        \"usage\": -1.0,\n        \"metric\": \"R %s/s \u2022 W %s/s\" % (human_bytes(read_rate), human_bytes(write_rate)),\n        \"secondary\": human_bytes(size_bytes),\n        \"detail\": model or \"BLOCK DEVICE\",\n        \"controlKind\": \"system-reboot\",\n        \"controlTarget\": \"/dev/\" + dev,\n        \"canDisconnect\": False,\n        \"canReconnect\": False,\n        \"canReboot\": systemctl_available,\n        \"contributors\": io_contributors,\n        \"contributorNote\": \"PROCESS I/O IS SYSTEM-WIDE; GENERIC procfs DOES NOT RELIABLY MAP EACH I/O TO ONE PHYSICAL BLOCK DEVICE.\"\n    })\n\nfor card in sorted(glob.glob(\"/sys/class/drm/card[0-9]*\")):\n    device = os.path.join(card, \"device\")\n    if not os.path.exists(device):\n        continue\n\n    name = os.path.basename(card).upper()\n    vendor = read_text(os.path.join(device, \"vendor\"), \"\")\n    dev_id = read_text(os.path.join(device, \"device\"), \"\")\n    busy = read_num(os.path.join(device, \"gpu_busy_percent\"), -1.0)\n    vram_total = read_num(os.path.join(device, \"mem_info_vram_total\"), 0.0)\n    vram_used = read_num(os.path.join(device, \"mem_info_vram_used\"), 0.0)\n\n    details = []\n    if vram_total > 0:\n        details.append(\"VRAM %s / %s\" % (human_bytes(vram_used), human_bytes(vram_total)))\n    if vendor or dev_id:\n        details.append(\"%s %s\" % (vendor, dev_id))\n\n    system.append({\n        \"_systemRecord\": True,\n        \"id\": \"system:gpu:\" + name,\n        \"name\": name,\n        \"label\": name,\n        \"category\": \"GPU\",\n        \"role\": \"GRAPHICS + COMPUTE WORKLOADS\",\n        \"usage\": busy,\n        \"metric\": (\"%.0f%% BUSY\" % busy) if busy >= 0 else \"BUSY N/A\",\n        \"secondary\": \"GPU\",\n        \"detail\": \" \u2022 \".join(details) if details else \"DRM GRAPHICS DEVICE\",\n        \"controlKind\": \"system-reboot\",\n        \"controlTarget\": name,\n        \"canDisconnect\": False,\n        \"canReconnect\": False,\n        \"canReboot\": systemctl_available,\n        \"contributors\": gpu_contributors,\n        \"contributorNote\": \"GPU PROCESS DATA COMES FROM DRM fdinfo WHEN THE DRIVER EXPOSES IT; OTHER DRIVERS MAY SHOW NO PER-PROCESS DATA.\"\n    })\n\nfor iface in sorted(net1):\n    if iface == \"lo\":\n        continue\n\n    rx0, tx0 = net0.get(iface, net1[iface])\n    rx1, tx1 = net1[iface]\n    rx_rate = max(0.0, (rx1 - rx0) / dt)\n    tx_rate = max(0.0, (tx1 - tx0) / dt)\n    oper = read_text(\"/sys/class/net/%s/operstate\" % iface, \"unknown\").upper()\n\n    system.append({\n        \"_systemRecord\": True,\n        \"id\": \"system:net:\" + iface,\n        \"name\": iface.upper(),\n        \"label\": iface.upper(),\n        \"category\": \"NETWORK\",\n        \"role\": \"NETWORK RECEIVE + TRANSMIT\",\n        \"usage\": -1.0,\n        \"metric\": \"\u2193 %s/s \u2022 \u2191 %s/s\" % (human_bytes(rx_rate), human_bytes(tx_rate)),\n        \"secondary\": oper,\n        \"detail\": \"NETWORK INTERFACE\",\n        \"controlKind\": \"network\",\n        \"controlTarget\": iface,\n        \"canDisconnect\": nmcli_available,\n        \"canReconnect\": nmcli_available,\n        \"canReboot\": systemctl_available,\n        \"contributors\": [],\n        \"contributorNote\": \"GENERIC procfs DOES NOT PROVIDE RELIABLE PER-PROCESS NETWORK BYTE ACCOUNTING. eBPF/nethogs-STYLE TELEMETRY WOULD BE NEEDED FOR THAT.\"\n    })\n\nprint(json.dumps({\n    \"thermal\": thermal,\n    \"fans\": fans,\n    \"system\": system,\n    \"error\": \"\"\n}))\n";
    }

    function refreshKillMonitor() {
        if (killMonitorLoading)
            return;

        killMonitorLoading = true;
        killMonitorError = "";

        killMonitorProcess.exec([
            "/usr/bin/python3",
            "-c",
            killMonitorScript()
        ]);
    }

    Process {
        id: killMonitorProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text || "{}");
                    appControlWindow.thermalRows =
                        Array.isArray(payload.thermal)
                        ? payload.thermal
                        : [];
                    appControlWindow.fanRows =
                        Array.isArray(payload.fans)
                        ? payload.fans
                        : [];
                    appControlWindow.systemRows =
                        Array.isArray(payload.system)
                        ? payload.system
                        : [];
                    appControlWindow.killMonitorError =
                        String(payload.error || "");
                } catch (error) {
                    appControlWindow.thermalRows = [];
                    appControlWindow.fanRows = [];
                    appControlWindow.systemRows = [];
                    appControlWindow.killMonitorError =
                        "MONITOR PARSE: " + String(error);
                }

                appControlWindow.killMonitorLoading = false;

                if (appControlWindow.selectedModeIndex
                        === appControlWindow.thermalModeIndex
                        || appControlWindow.selectedModeIndex
                           === appControlWindow.systemModeIndex) {
                    Qt.callLater(function() {
                        const count =
                            appControlWindow.selectedModeIndex
                            === appControlWindow.thermalModeIndex
                            ? thermalResults.values.length
                            : systemResults.values.length;

                        if (count <= 0) {
                            appControlWindow.selectedResultIndex = -1;
                            return;
                        }

                        if (appControlWindow.selectedResultIndex < 0
                                || appControlWindow.selectedResultIndex >= count)
                            appControlWindow.selectedResultIndex = 0;
                    });
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = String(text || "").trim();

                if (message.length > 0)
                    appControlWindow.killMonitorError = message;

                appControlWindow.killMonitorLoading = false;
            }
        }
    }

    Timer {
        id: killMonitorRefreshTimer

        interval:
            appControlWindow.menuOpen
            && (appControlWindow.selectedModeIndex
                === appControlWindow.thermalModeIndex
                || appControlWindow.selectedModeIndex
                   === appControlWindow.systemModeIndex)
            ? 1900
            : 10000
        repeat: true

        running:
            (appControlWindow.menuOpen
             && (appControlWindow.selectedModeIndex
                 === appControlWindow.thermalModeIndex
                 || appControlWindow.selectedModeIndex
                    === appControlWindow.systemModeIndex))
            || appControlWindow.hasMonitorFavorites()

        onTriggered: appControlWindow.refreshKillMonitor()
    }

    function fanControlScript() {
        return "import json\nimport os\nimport re\nimport sys\n\npayload = json.loads(sys.argv[1] if len(sys.argv) > 1 else \"{}\")\naction = str(payload.get(\"action\") or \"\")\npwm_path = str(payload.get(\"pwmPath\") or \"\")\nenable_path = str(payload.get(\"pwmEnablePath\") or \"\")\n\ndef valid(path, suffix):\n    return bool(\n        re.match(r\"^/sys/class/hwmon/hwmon[0-9]+/\" + suffix + r\"$\", path)\n    )\n\nif not valid(pwm_path, r\"pwm[0-9]+\"):\n    raise SystemExit(\"invalid pwm path\")\n\nif not valid(enable_path, r\"pwm[0-9]+_enable\"):\n    raise SystemExit(\"invalid enable path\")\n\nif not (os.path.exists(pwm_path) and os.path.exists(enable_path)):\n    raise SystemExit(\"fan control files unavailable\")\n\nif not (os.access(pwm_path, os.W_OK) and os.access(enable_path, os.W_OK)):\n    raise SystemExit(\"fan control files are not writable by this user\")\n\ndef read_int(path, default):\n    try:\n        return int(open(path, \"r\", encoding=\"utf-8\").read().strip())\n    except Exception:\n        return default\n\ndef write_int(path, value):\n    with open(path, \"w\", encoding=\"utf-8\") as handle:\n        handle.write(str(int(value)))\n\ncurrent = max(0, min(255, read_int(pwm_path, 255)))\n\nif action == \"auto\":\n    # hwmon convention: 1 manual, 2 automatic/closed-loop on many drivers.\n    write_int(enable_path, 2)\nelif action == \"manual\":\n    # Enter manual mode at a conservative boosted duty rather than lowering it.\n    write_int(enable_path, 1)\n    write_int(pwm_path, max(current, 180))\nelif action == \"boost\":\n    write_int(enable_path, 1)\n    write_int(pwm_path, min(255, max(current, 180) + 26))\nelif action == \"max\":\n    write_int(enable_path, 1)\n    write_int(pwm_path, 255)\nelif action == \"set\":\n    percent_raw = payload.get(\"percent\", None)\n    if percent_raw is None:\n        raise SystemExit(\"missing fan percent\")\n    percent = max(0.0, min(100.0, float(percent_raw)))\n    pwm = int(round((percent / 100.0) * 255.0))\n    write_int(enable_path, 1)\n    write_int(pwm_path, pwm)\nelse:\n    raise SystemExit(\"unknown action\")\n";
    }

    function writeFanControl(entry, action, percent) {
        if (!entry
                || entry.sensorKind !== "fan"
                || !entry.controlWritable)
            return;

        fanControlProcess.exec([
            "/usr/bin/python3",
            "-c",
            fanControlScript(),
            JSON.stringify({
                action: String(action || ""),
                percent:
                    percent === undefined || percent === null
                    ? null
                    : Math.max(0, Math.min(100, Number(percent))),
                pwmPath: String(entry.pwmPath || ""),
                pwmEnablePath: String(entry.pwmEnablePath || "")
            })
        ]);
    }

    function writeFanPercent(entry, percent) {
        writeFanControl(
            entry,
            "set",
            Math.max(0, Math.min(100, Number(percent || 0)))
        );
    }

    Process {
        id: fanControlProcess

        stdout: StdioCollector {
            onStreamFinished: {
                Qt.callLater(function() {
                    appControlWindow.refreshKillMonitor();
                });
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = String(text || "").trim();

                if (message.length > 0) {
                    appControlWindow.killMonitorError = message;
                    console.log("AppControl: fan control:", message);
                }

                Qt.callLater(function() {
                    appControlWindow.refreshKillMonitor();
                });
            }
        }
    }

    function selectedTask() {
        const entry = selectedResult();
        const source = favoriteSourceItem(entry) || entry;
        if (!source || !source._taskRecord)
            return null;

        // FAVORITES/COMBI task rows are persistent identity wrappers. Resolve
        // them against the newest task snapshot so the detail panel can stay
        // live even when the COMBI catalog itself is intentionally kept
        // stable to avoid ListView jumps.
        if (entry && entry._favoriteRecord
                && resultSourceMode(entry, selectedModeIndex) === killModeIndex) {
            const live = liveTaskForMiniGraph(entry);
            if (live)
                return live;
        }

        return source;
    }

    function selectedResultIsTask() {
        const entry = selectedResult();
        const source = favoriteSourceItem(entry) || entry;
        return !!entry
               && resultSourceMode(entry, selectedModeIndex) === killModeIndex
               && !!source
               && !!source._taskRecord;
    }

    function formatTaskMemory(kib) {
        const value = Number(kib || 0);

        if (value >= 1048576)
            return (value / 1048576).toFixed(1) + " GiB";

        if (value >= 1024)
            return (value / 1024).toFixed(1) + " MiB";

        return Math.round(value) + " KiB";
    }

    function resetTaskHistoryForSelection() {
        const entry = selectedTask();

        if (!entry) {
            taskHistoryPid = 0;
            taskCpuHistory = [];
            taskMemHistory = [];
            return;
        }

        if (taskHistoryPid === Number(entry.pid || 0))
            return;

        taskHistoryPid = Number(entry.pid || 0);
        taskCpuHistory = [Math.max(0, Math.min(100, Number(entry.cpu || 0)))];
        taskMemHistory = [Number(entry.mem || 0)];

        taskGraphProbePid = taskHistoryPid;
        taskGraphProbeLastTicks = -1;
        taskGraphProbeLastMs = 0;
        taskGraphProbeLoading = false;
    }

    function appendTaskHistoryValues(cpuValue, memValue) {
        const cpu = taskCpuHistory.slice();
        const mem = taskMemHistory.slice();

        cpu.push(Math.max(0, Math.min(100, Number(cpuValue || 0))));
        mem.push(Math.max(0, Number(memValue || 0)));

        while (cpu.length > taskHistoryLimit)
            cpu.shift();

        while (mem.length > taskHistoryLimit)
            mem.shift();

        taskCpuHistory = cpu;
        taskMemHistory = mem;

        // Canvas bindings can lag behind fast ScriptModel refreshes. Request
        // the repaint explicitly after replacing the history arrays.
        Qt.callLater(function() {
            if (taskCpuCanvas)
                taskCpuCanvas.requestPaint();

            if (taskMemCanvas)
                taskMemCanvas.requestPaint();
        });
    }

    function appendTaskHistory(entry) {
        if (!entry || Number(entry.pid || 0) !== taskHistoryPid)
            return;

        appendTaskHistoryValues(Number(entry.cpu || 0), Number(entry.mem || 0));
    }

    function refreshSelectedTaskGraph() {
        const entry = selectedTask();

        if (!entry || Number(entry.pid || 0) <= 1 || taskGraphProbeLoading)
            return;

        const pid = Number(entry.pid || 0);
        taskGraphProbeLoading = true;

        taskGraphProbeProcess.exec([
            "/bin/sh",
            "-lc",
            "pid=" + String(pid) + "; "
            + "[ -r /proc/$pid/stat ] || exit 0; "
            + "ticks=$(awk '{print $14+$15}' /proc/$pid/stat 2>/dev/null) || exit 0; "
            + "rss=$(awk '/^VmRSS:/{print $2; exit}' /proc/$pid/status 2>/dev/null); "
            + "total=$(awk '/^MemTotal:/{print $2; exit}' /proc/meminfo 2>/dev/null); "
            + "clk=$(getconf CLK_TCK 2>/dev/null || printf 100); "
            + "cores=$(getconf _NPROCESSORS_ONLN 2>/dev/null || printf 1); "
            + "printf '%s %s %s %s %s %s\\n' "
            + "\"$pid\" \"$ticks\" \"${rss:-0}\" \"${total:-1}\" \"$clk\" \"$cores\""
        ]);
    }

    function consumeTaskGraphProbe(output) {
        taskGraphProbeLoading = false;

        const fields = String(output || "").trim().split(/\s+/);

        if (fields.length < 6)
            return;

        const pid = Number(fields[0] || 0);
        const ticks = Number(fields[1] || 0);
        const rssKiB = Number(fields[2] || 0);
        const totalKiB = Math.max(1, Number(fields[3] || 1));
        const tickRate = Math.max(1, Number(fields[4] || 100));
        const cores = Math.max(1, Number(fields[5] || 1));
        const nowMs = Date.now();

        if (pid !== taskHistoryPid)
            return;

        let cpuPercent = 0;

        if (taskGraphProbePid === pid
                && taskGraphProbeLastTicks >= 0
                && taskGraphProbeLastMs > 0) {
            const elapsedSeconds = Math.max(0.001, (nowMs - taskGraphProbeLastMs) / 1000.0);
            const tickDelta = Math.max(0, ticks - taskGraphProbeLastTicks);

            // /proc task ticks are already this process's consumed CPU time.
            // Dividing by the machine's core count made the live history much
            // smaller than the %CPU shown by the task list. Keep the same
            // per-process scale as ps, then clamp to this graph's 0..100 range.
            cpuPercent = ((tickDelta / tickRate) / elapsedSeconds) * 100.0;
        } else {
            const task = selectedTask();
            cpuPercent = task ? Math.max(0, Math.min(100, Number(task.cpu || 0))) : 0;
        }

        cpuPercent = Math.max(0, Math.min(100, cpuPercent));
        const memPercent = Math.max(0, (rssKiB / totalKiB) * 100.0);

        taskGraphProbePid = pid;
        taskGraphProbeLastTicks = ticks;
        taskGraphProbeLastMs = nowMs;

        appendTaskHistoryValues(cpuPercent, memPercent);
    }

    Process {
        id: taskGraphProbeProcess

        stdout: StdioCollector {
            onStreamFinished: { appControlWindow.consumeTaskGraphProbe(text); }
        }

        stderr: StdioCollector {
            onStreamFinished: { appControlWindow.taskGraphProbeLoading = false; }
        }
    }

    Timer {
        id: taskGraphProbeTimer
        interval: 450
        repeat: true
        running:
            appControlWindow.menuOpen
            && appControlWindow.selectedResultIsTask()
        onTriggered: appControlWindow.refreshSelectedTaskGraph()
    }

    function refreshTaskManager() {
        if (taskSnapshotLoading)
            return;

        taskSnapshotLoading = true;
        taskSnapshotError = "";

        taskSnapshotProcess.exec([
            "/bin/sh",
            "-lc",
            "clk=$(getconf CLK_TCK 2>/dev/null || printf 100); "
            + "LC_ALL=C ps -eo "
            + "pid=,ppid=,user=,stat=,pcpu=,pmem=,rss=,vsz=,nlwp=,etime=,comm=,args= "
            + "--sort=-pcpu | "
            + "while read -r pid rest; do "
            + "[ -n \"$pid\" ] || continue; "
            + "ticks=$(sed 's/^[^)]*) //' /proc/$pid/stat 2>/dev/null "
            + "| awk '{print $12+$13}'); "
            + "printf '%s %s %s %s\\n' \"$clk\" \"${ticks:-0}\" \"$pid\" \"$rest\"; "
            + "done"
        ]);
    }

    function consumeTaskSnapshot(output) {
        const lines = String(output || "").split("\n");
        const rows = [];
        const nowMs = Date.now();
        const previousTickSamples = taskMiniCpuTickSamples;
        const nextTickSamples = ({});

        let preservedPid = 0;

        if (selectedModeIndex === killModeIndex
                && selectedResultIsTask()) {
            preservedPid = Number(selectedResult().pid || 0);
        }

        for (let i = 0; i < lines.length; i++) {
            const line = String(lines[i] || "").trim();

            if (!line)
                continue;

            const fields = line.split(/\s+/);

            if (fields.length < 13)
                continue;

            const tickRate = Math.max(1, Number(fields[0] || 100));
            const cpuTicks = Math.max(0, Number(fields[1] || 0));
            const pid = Number(fields[2] || 0);

            if (!pid)
                continue;

            const args =
                fields.length > 13
                ? fields.slice(13).join(" ")
                : String(fields[12] || "");

            const comm = String(fields[12] || "").trim();
            const tickKey = "pid:" + String(pid);
            const previousTick = previousTickSamples[tickKey];
            let cpuInstant = Math.max(0, Number(fields[6] || 0));

            if (previousTick
                    && cpuTicks >= Number(previousTick.ticks || 0)
                    && nowMs > Number(previousTick.ms || 0)) {
                const elapsedSeconds = Math.max(
                    0.001,
                    (nowMs - Number(previousTick.ms || 0)) / 1000.0
                );
                const tickDelta = Math.max(
                    0,
                    cpuTicks - Number(previousTick.ticks || 0)
                );
                cpuInstant = ((tickDelta / tickRate) / elapsedSeconds) * 100.0;
            }

            cpuInstant = Math.max(0, Math.min(100, cpuInstant));
            nextTickSamples[tickKey] = {
                ticks: cpuTicks,
                ms: nowMs
            };

            // refreshTaskManager() itself runs `ps -eo ...`. That `ps`
            // process can appear in its own snapshot with a large one-shot CPU
            // value, but it exits immediately and therefore can never produce a
            // meaningful continuous history graph. Do not present that probe as
            // a user task.
            if (comm === "ps"
                    && args.indexOf("pid=,ppid=,user=,stat=,pcpu=") !== -1)
                continue;

            rows.push({
                _taskRecord: true,
                id: "task:" + String(pid),
                pid: pid,
                ppid: Number(fields[3] || 0),
                user: String(fields[4] || ""),
                state: String(fields[5] || ""),
                cpu: Number(fields[6] || 0),
                cpuInstant: cpuInstant,
                mem: Number(fields[7] || 0),
                rss: Number(fields[8] || 0),
                vsz: Number(fields[9] || 0),
                threads: Number(fields[10] || 0),
                elapsed: String(fields[11] || ""),
                comm: String(fields[12] || ""),
                args: args,
                name: String(fields[12] || "PROCESS"),
                label: String(fields[12] || "PROCESS")
            });
        }

        taskMiniCpuTickSamples = nextTickSamples;
        updateTaskMiniCpuHistories(rows);
        taskRows = rows;

        // Publish one graph revision only after BOTH the identity histories and
        // the live task rows are current. FAVORITES delegates use this as their
        // atomic sample tick; previously it fired before taskRows changed, which
        // could leave their local graph snapshot stuck on the first sample.
        taskMiniHistoryRevision += 1;

        checkTaskMetricAlerts(rows);
        taskProcessCount = rows.length;
        taskSnapshotLoading = false;
        taskSnapshotError = "";

        Qt.callLater(function() {
            if (selectedModeIndex !== killModeIndex)
                return;

            let targetIndex = 0;

            if (preservedPid > 0) {
                for (let i = 0; i < killTaskResults.values.length; i++) {
                    if (Number(killTaskResults.values[i].pid || 0)
                            === preservedPid) {
                        targetIndex = i;
                        break;
                    }
                }
            }

            taskRestoringSelection = true;

            selectedResultIndex =
                killTaskResults.values.length > 0
                ? Math.min(targetIndex, killTaskResults.values.length - 1)
                : -1;

            taskRestoringSelection = false;

            // First sample for a newly selected task.
            if (taskHistoryPid <= 0)
                resetTaskHistoryForSelection();
        });
    }

    // ============================================================
    // KILL MODE / GLOBAL TASK ACTIONS
    // ============================================================

    property int killHogArmedPid: 0
    property var taskSoftLimitPids: ({})

    function taskProtectedFromKillAll(entry) {
        if (!entry)
            return true;

        const name = String(entry.comm || entry.name || "")
                     .trim().toLowerCase();
        const protectedNames = [
            "quickshell", "sway", "systemd", "dbus-broker",
            "pipewire", "pipewire-pulse", "wireplumber",
            "xdg-desktop-portal", "xdg-document-portal",
            "xdg-permission-store", "at-spi-bus-launcher",
            "at-spi2-registryd", "gpg-agent", "ssh-agent"
        ];

        return protectedNames.indexOf(name) !== -1;
    }

    function taskEligibleForKillAll(entry) {
        if (!entry || !entry._taskRecord || Number(entry.pid || 0) <= 1)
            return false;

        const currentUser = String(Quickshell.env("USER") || "").trim();
        const taskUser = String(entry.user || "").trim();

        if (currentUser.length > 0
                && taskUser.length > 0
                && taskUser !== currentUser)
            return false;

        if (String(entry.state || "").indexOf("Z") !== -1)
            return false;

        return !taskProtectedFromKillAll(entry);
    }

    function killAllEligibleTasks() {
        const rows = [];

        for (let i = 0; i < taskRows.length; i++) {
            if (taskEligibleForKillAll(taskRows[i]))
                rows.push(taskRows[i]);
        }

        return rows;
    }

    function requestKillAllEligibleTasks() {
        const rows = killAllEligibleTasks();

        if (rows.length === 0)
            return;

        openDestructiveConfirm(
            "kill-all",
            "⚠ CONFIRM KILL ALL ⚠",
            "TERMINATE " + String(rows.length)
            + " ELIGIBLE USER PROCESSES?\n"
            + "SWAY, QUICKSHELL, AUDIO, DBUS AND SESSION SERVICES ARE PROTECTED.",
            "KILL ALL"
        );
        destructiveConfirmTargetPids = rows.map(function(entry) {
            return Number(entry.pid || 0);
        });
    }

    function executeKillAllEligibleTasks(targetPids) {
        const wanted = Array.isArray(targetPids) ? targetPids : [];
        const rows = killAllEligibleTasks().filter(function(entry) {
            return wanted.length === 0
                   || wanted.indexOf(Number(entry.pid || 0)) !== -1;
        });
        if (rows.length === 0)
            return;

        const command = ["kill", "-TERM"];
        for (let i = 0; i < rows.length; i++)
            command.push(String(rows[i].pid));

        console.log("AppControl: KILL ALL eligible count", rows.length);
        Quickshell.execDetached(command);
        taskRefreshAfterKillTimer.restart();
    }

    function selectTaskByPid(pid) {
        const targetPid = Number(pid || 0);
        if (targetPid <= 0)
            return false;

        const rows = killTaskResults.values;
        for (let i = 0; i < rows.length; i++) {
            if (Number(rows[i].pid || 0) !== targetPid)
                continue;

            selectedResultIndex = i;
            hoveredResultIndex = -1;
            keyboardActive = true;
            detailFocused = false;
            resetTaskHistoryForSelection();
            resetDetailActionSelection();

            Qt.callLater(function() {
                resultList.positionViewAtIndex(
                    appControlWindow.selectedResultIndex,
                    ListView.Center
                );
            });
            return true;
        }

        return false;
    }

    function mostDemandingVisibleTask() {
        const rows = killTaskResults.values;
        let best = null;
        let bestScore = -1;

        for (let i = 0; i < rows.length; i++) {
            const entry = rows[i];
            if (!taskEligibleForKillAll(entry))
                continue;

            // A single HOG button combines CPU and memory pressure. RAM is
            // weighted so a memory runaway can outrank an otherwise idle task.
            const score = Math.max(
                Number(entry.cpu || 0),
                Number(entry.mem || 0) * 4.0
            );

            if (!best || score > bestScore) {
                best = entry;
                bestScore = score;
            }
        }

        return best;
    }

    function triggerKillHog() {
        if (killHogArmedPid > 0) {
            let armed = null;
            for (let i = 0; i < taskRows.length; i++) {
                if (Number(taskRows[i].pid || 0) === killHogArmedPid) {
                    armed = taskRows[i];
                    break;
                }
            }

            if (armed && taskEligibleForKillAll(armed)) {
                console.log("AppControl: KILL HOG", armed.pid, armed.comm);
                Quickshell.execDetached([
                    "kill", "-TERM", String(armed.pid)
                ]);
                taskRefreshAfterKillTimer.restart();
            }

            killHogArmedPid = 0;
            killHogArmTimer.stop();
            return;
        }

        const candidate = mostDemandingVisibleTask();
        if (!candidate)
            return;

        killHogArmedPid = Number(candidate.pid || 0);
        selectTaskByPid(killHogArmedPid);
        killHogArmTimer.restart();
    }

    Timer {
        id: killHogArmTimer
        interval: 5000
        repeat: false
        onTriggered: appControlWindow.killHogArmedPid = 0
    }

    function selectedTaskIsFrozen() {
        const entry = selectedTask();
        return !!entry && String(entry.state || "").indexOf("T") !== -1;
    }

    function toggleSelectedTaskFreeze() {
        const entry = selectedTask();
        if (!entry || Number(entry.pid || 0) <= 1)
            return;

        const frozen = selectedTaskIsFrozen();
        Quickshell.execDetached([
            "kill", frozen ? "-CONT" : "-STOP", String(entry.pid)
        ]);
        taskRefreshAfterKillTimer.restart();
    }

    function selectedTaskHasSoftLimit() {
        const entry = selectedTask();
        if (!entry)
            return false;
        return !!taskSoftLimitPids["pid:" + String(entry.pid || 0)];
    }

    function toggleSelectedTaskLimit() {
        const entry = selectedTask();
        if (!entry || Number(entry.pid || 0) <= 1)
            return;

        const pid = Number(entry.pid || 0);
        const key = "pid:" + String(pid);
        const next = Object.assign({}, taskSoftLimitPids);

        if (next[key]) {
            // Only the soft RLIMIT_AS is changed; the process hard limit is
            // left untouched so removing AppControl's cap remains possible.
            Quickshell.execDetached([
                "prlimit", "--pid", String(pid), "--as=unlimited:"
            ]);
            delete next[key];
        } else {
            const currentKiB = Math.max(1, Number(entry.vsz || 0));
            const capKiB = Math.ceil(
                Math.max(
                    currentKiB * 1.5,
                    currentKiB + (512 * 1024)
                )
            );
            const capBytes = Math.floor(capKiB * 1024);

            Quickshell.execDetached([
                "prlimit",
                "--pid", String(pid),
                "--as=" + String(capBytes) + ":"
            ]);
            next[key] = capBytes;
        }

        taskSoftLimitPids = next;
        taskRefreshAfterKillTimer.restart();
    }

    function terminateSelectedTask() {
        const entry = selectedTask();

        if (!entry || Number(entry.pid || 0) <= 1)
            return;

        console.log(
            "AppControl: TASK TERM",
            entry.pid,
            entry.comm
        );

        Quickshell.execDetached([
            "kill",
            "-TERM",
            String(entry.pid)
        ]);

        taskRefreshAfterKillTimer.restart();
    }

    Process {
        id: taskSnapshotProcess

        stdout: StdioCollector {
            onStreamFinished: {
                appControlWindow.consumeTaskSnapshot(text);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = String(text || "").trim();

                if (message.length > 0) {
                    appControlWindow.taskSnapshotError = message;
                    console.log("AppControl: task manager:", message);
                }

                appControlWindow.taskSnapshotLoading = false;
            }
        }
    }

    Timer {
        id: taskManagerRefreshTimer

        interval:
            appControlWindow.menuOpen
            && appControlWindow.selectedModeIndex === appControlWindow.killModeIndex
            ? 850
            : appControlWindow.menuOpen
              && appControlWindow.selectedModeIndex === appControlWindow.favoritesModeIndex
              && appControlWindow.favoritesScopeMode === appControlWindow.favoritesScopeFavorites
              && appControlWindow.hasTaskFavorites()
            ? 850
            : appControlWindow.menuOpen
              && appControlWindow.selectedModeIndex === appControlWindow.favoritesModeIndex
              && appControlWindow.favoritesScopeMode === appControlWindow.favoritesScopeCombi
            ? 2800
            : 10000

        repeat: true

        running:
            (appControlWindow.menuOpen
             && (appControlWindow.selectedModeIndex
                 === appControlWindow.killModeIndex
                 || (appControlWindow.selectedModeIndex
                     === appControlWindow.favoritesModeIndex
                     && appControlWindow.favoritesScopeMode
                        === appControlWindow.favoritesScopeCombi)))
            || appControlWindow.hasTaskFavorites()

        onTriggered: appControlWindow.refreshTaskManager()
    }

    Timer {
        id: taskRefreshAfterKillTimer

        interval: 320
        repeat: false

        onTriggered: appControlWindow.refreshTaskManager()
    }

    // Exact visible spacing between app rows and their neighboring edges.
    property int appSelectorRowGap: 6


    // Keep the selected application stable while cycling through modes.
    property string rememberedAppKey: ""

    // APPS source selector.
    readonly property int appSourceNative: 0
    readonly property int appSourceFlatpak: 1
    readonly property int appSourceHidden: 2
    property int appSourceMode: appSourceNative

    // APPS launch selector.
    readonly property int appLaunchNormal: 0
    readonly property int appLaunchToolbox: 1
    readonly property int appLaunchBottle: 2
    property int appLaunchMode: appLaunchNormal

    // Bottles integration. The first discovered bottle is the current target;
    // this gives the selector a useful default without inventing a bottle name.
    property var bottleNames: []
    property string selectedBottleName: ""
    property bool bottlesLoading: false
    property string bottlesError: ""

    // WINDOWS selector sub-mode.
    //
    // WINDOWS = every live Sway client.
    // TABS    = only clients living underneath a Sway tabbed-layout
    //           container.
    readonly property int windowListWindows: 0
    readonly property int windowListTabs: 1
    property int windowListMode: windowListWindows

    function setWindowListMode(mode) {
        windowListMode =
            mode === windowListTabs
            ? windowListTabs
            : windowListWindows;

        keyboardActive = true;
        hoveredResultIndex = -1;

        if (windowListMode === windowListTabs) {
            refreshAppTabs();
            appTabsWarmRefreshTimer.restart();
            appTabsSecondWarmRefreshTimer.restart();
        }

        resetResultSelection();
        resetDetailActionSelection();
    }

    // Live Sway window snapshot used by APPS/WINDOWS modes.
    property var swayWindows: []
    property var swayOutputNames: []
    property bool windowDataReady: false
    property string windowDataError: ""

    // Real cross-application tab discovery through AT-SPI.
    //
    // Sway only knows top-level windows. AT-SPI is what lets AppControl ask
    // GUI apps for actual PAGE_TAB accessibility objects (Brave/Chromium,
    // Electron apps such as VS Code, Kitty tab bars when exposed, etc.).
    property var appTabs: []
    property var appTabControls: []
    property bool appTabsLoading: false
    property string appTabsError: ""
    property var appTabsDiagnostics: []
    property string appTabsDiagnosticsSignature: ""
    property string appTabsDataSignature: ""

    // Persistent accessibility client used while the TABS selector is open.
    // Keeping the registration alive is important on newer at-spi2-core,
    // where org.a11y.Status.IsEnabled follows live AT registrations.
    property bool appTabsBridgeReady: false
    property string appTabsBridgeError: ""

    function appTabBridgeScript() {
        return "import ctypes\nimport ctypes.util\nimport json\nimport os\nimport re\nimport signal\nimport subprocess\nimport sys\nimport time\nimport urllib.request\n\nrunning = True\ndirty = True\n\nROLE_DIALOG = 16\nROLE_FRAME = 23\nROLE_PAGE_TAB = 37\nROLE_PAGE_TAB_LIST = 38\nROLE_LIST_ITEM = 32\nROLE_PUSH_BUTTON = 43\nROLE_RADIO_BUTTON = 44\nROLE_TOGGLE_BUTTON = 62\nROLE_WINDOW = 69\nROLE_APPLICATION = 75\n\nSTATE_ACTIVE = 1\nSTATE_FOCUSED = 12\nSTATE_SELECTED = 23\n\ndef stop(*_args):\n    global running\n    running = False\n\nsignal.signal(signal.SIGTERM, stop)\nsignal.signal(signal.SIGINT, stop)\n\ndef run_cmd(argv, timeout=1.0):\n    try:\n        proc = subprocess.run(\n            argv,\n            stdout=subprocess.PIPE,\n            stderr=subprocess.PIPE,\n            text=True,\n            timeout=timeout\n        )\n        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()\n    except Exception as exc:\n        return 1, \"\", str(exc)\n\ndef process_provider_tabs():\n    rows = []\n    diagnostics = []\n\n    # Kitty remote control.\n    kitty_addresses = []\n    kitty_errors = []\n\n    try:\n        for pid in os.listdir(\"/proc\"):\n            if not pid.isdigit():\n                continue\n\n            try:\n                env = open(\n                    \"/proc/%s/environ\" % pid,\n                    \"rb\"\n                ).read().split(b\"\\0\")\n            except Exception:\n                continue\n\n            for item in env:\n                if item.startswith(b\"KITTY_LISTEN_ON=\"):\n                    address = item.split(\n                        b\"=\",\n                        1\n                    )[1].decode(\n                        \"utf-8\",\n                        \"ignore\"\n                    ).strip()\n\n                    if address and address not in kitty_addresses:\n                        kitty_addresses.append(address)\n    except Exception as exc:\n        kitty_errors.append(\"DISCOVERY: \" + str(exc))\n\n    for address in kitty_addresses:\n        try:\n            proc = subprocess.run(\n                [\n                    \"kitty\",\n                    \"@\",\n                    \"--to\",\n                    address,\n                    \"ls\"\n                ],\n                stdout=subprocess.PIPE,\n                stderr=subprocess.PIPE,\n                text=True,\n                timeout=0.8\n            )\n\n            if proc.returncode != 0 or not proc.stdout.strip():\n                raw_error = str(proc.stderr or \"\").strip()\n                kitty_errors.append(\n                    (\"%s: %s\" % (address, raw_error))\n                    if raw_error\n                    else (\"%s: kitty @ ls returned %d\" % (\n                        address,\n                        proc.returncode\n                    ))\n                )\n                continue\n\n            payload = json.loads(proc.stdout)\n\n            for os_window in (\n                payload\n                if isinstance(payload, list)\n                else []\n            ):\n                for tab in os_window.get(\"tabs\", []) or []:\n                    tab_id = tab.get(\"id\")\n                    title = str(tab.get(\"title\") or \"\").strip()\n\n                    if not title:\n                        wins = tab.get(\"windows\", []) or []\n                        active = next(\n                            (\n                                w for w in wins\n                                if w.get(\"is_active\")\n                            ),\n                            None\n                        )\n                        active = active or (wins[0] if wins else {})\n                        title = str(\n                            active.get(\"title\")\n                            or active.get(\"cwd\")\n                            or (\"KITTY TAB \" + str(tab_id))\n                        )\n\n                    rows.append({\n                        \"_tabRecord\": True,\n                        \"id\": \"kitty:\" + str(tab_id),\n                        \"path\": \"\",\n                        \"name\": title,\n                        \"tabTitle\": title,\n                        \"appName\": \"Kitty\",\n                        \"windowName\": str(os_window.get(\"id\") or \"\"),\n                        \"selected\": bool(tab.get(\"is_active\")),\n                        \"provider\": \"KITTY\",\n                        \"kittyAddress\": address,\n                        \"kittyTabId\": tab_id\n                    })\n        except Exception as exc:\n            kitty_errors.append(\"%s: %s\" % (address, str(exc)))\n\n    kitty_tab_count = sum(\n        1 for item in rows\n        if item.get(\"provider\") == \"KITTY\"\n    )\n\n    diagnostics.append(\n        \"KITTY SOCKETS:%d\" % len(kitty_addresses)\n    )\n    diagnostics.append(\n        \"KITTY TABS:%d\" % kitty_tab_count\n    )\n    diagnostics.append(\n        \"KITTY ERROR:%s\"\n        % (\n            \" | \".join(kitty_errors[:3])\n            if kitty_errors\n            else \"NONE\"\n        )\n    )\n\n    # Chromium / Electron DevTools when a debug port exists.\n    ports = {}\n    devtools_errors = []\n\n    try:\n        for pid in os.listdir(\"/proc\"):\n            if not pid.isdigit():\n                continue\n\n            try:\n                raw = open(\n                    \"/proc/%s/cmdline\" % pid,\n                    \"rb\"\n                ).read()\n\n                argv = [\n                    part.decode(\"utf-8\", \"ignore\")\n                    for part in raw.split(b\"\\0\")\n                    if part\n                ]\n            except Exception:\n                continue\n\n            if not argv:\n                continue\n\n            exe = os.path.basename(argv[0]).lower()\n\n            app_name = (\n                \"Brave\"\n                if \"brave\" in exe\n                else \"Chrome\"\n                if \"chrome\" in exe\n                else \"Chromium\"\n                if \"chromium\" in exe\n                else \"VS Code\"\n                if exe in (\"code\", \"code-oss\", \"codium\")\n                else \"Electron\"\n                if \"electron\" in exe\n                else \"\"\n            )\n\n            if not app_name:\n                continue\n\n            port = None\n\n            for index, arg in enumerate(argv):\n                if arg.startswith(\"--remote-debugging-port=\"):\n                    try:\n                        port = int(arg.split(\"=\", 1)[1])\n                    except Exception:\n                        port = None\n                    break\n\n                if arg == \"--remote-debugging-port\" and index + 1 < len(argv):\n                    try:\n                        port = int(argv[index + 1])\n                    except Exception:\n                        port = None\n                    break\n\n            if port and port > 0:\n                ports[port] = app_name\n\n    except Exception as exc:\n        devtools_errors.append(\"DISCOVERY: \" + str(exc))\n\n    devtools_target_count = 0\n\n    for port, app_name in ports.items():\n        try:\n            with urllib.request.urlopen(\n                \"http://127.0.0.1:%d/json/list\" % port,\n                timeout=0.55\n            ) as response:\n                targets = json.loads(\n                    response.read().decode(\"utf-8\", \"ignore\")\n                )\n        except Exception as exc:\n            devtools_errors.append(\n                \"PORT %d: %s\" % (port, str(exc))\n            )\n            continue\n\n        for target in targets:\n            if str(target.get(\"type\", \"\")).lower() not in (\"page\", \"webview\"):\n                continue\n\n            devtools_target_count += 1\n\n            target_id = str(target.get(\"id\") or \"\").strip()\n            title = str(\n                target.get(\"title\")\n                or target.get(\"url\")\n                or \"\"\n            ).strip()\n\n            if not target_id or not title:\n                continue\n\n            rows.append({\n                \"_tabRecord\": True,\n                \"id\": \"devtools:%d:%s\" % (port, target_id),\n                \"path\": \"\",\n                \"name\": title,\n                \"tabTitle\": title,\n                \"appName\": app_name,\n                \"windowName\": str(target.get(\"url\") or \"\"),\n                \"selected\": False,\n                \"provider\": \"DEVTOOLS\",\n                \"debugPort\": port,\n                \"targetId\": target_id\n            })\n\n    port_text = (\n        \",\".join(str(port) for port in sorted(ports))\n        if ports\n        else \"NONE\"\n    )\n\n    diagnostics.append(\n        \"DEVTOOLS PORTS:%s\" % port_text\n    )\n    diagnostics.append(\n        \"DEVTOOLS TARGETS:%d\" % devtools_target_count\n    )\n    diagnostics.append(\n        \"DEVTOOLS ERROR:%s\"\n        % (\n            \" | \".join(devtools_errors[:3])\n            if devtools_errors\n            else \"NONE\"\n        )\n    )\n\n    return rows, diagnostics\n\ntry:\n    lib_name = ctypes.util.find_library(\"atspi\") or \"libatspi.so.0\"\n    atspi = ctypes.CDLL(lib_name)\n\n    # Core.\n    atspi.atspi_init.argtypes = []\n    atspi.atspi_init.restype = ctypes.c_int\n\n    atspi.atspi_get_desktop.argtypes = [ctypes.c_int]\n    atspi.atspi_get_desktop.restype = ctypes.c_void_p\n\n    # Accessible.\n    atspi.atspi_accessible_get_child_count.argtypes = [\n        ctypes.c_void_p,\n        ctypes.c_void_p\n    ]\n    atspi.atspi_accessible_get_child_count.restype = ctypes.c_int\n\n    atspi.atspi_accessible_get_child_at_index.argtypes = [\n        ctypes.c_void_p,\n        ctypes.c_int,\n        ctypes.c_void_p\n    ]\n    atspi.atspi_accessible_get_child_at_index.restype = ctypes.c_void_p\n\n    atspi.atspi_accessible_get_role.argtypes = [\n        ctypes.c_void_p,\n        ctypes.c_void_p\n    ]\n    atspi.atspi_accessible_get_role.restype = ctypes.c_int\n\n    atspi.atspi_accessible_get_name.argtypes = [\n        ctypes.c_void_p,\n        ctypes.c_void_p\n    ]\n    atspi.atspi_accessible_get_name.restype = ctypes.c_void_p\n\n    atspi.atspi_accessible_get_role_name.argtypes = [\n        ctypes.c_void_p,\n        ctypes.c_void_p\n    ]\n    atspi.atspi_accessible_get_role_name.restype = ctypes.c_void_p\n\n    atspi.atspi_accessible_get_state_set.argtypes = [\n        ctypes.c_void_p\n    ]\n    atspi.atspi_accessible_get_state_set.restype = ctypes.c_void_p\n\n    atspi.atspi_state_set_contains.argtypes = [\n        ctypes.c_void_p,\n        ctypes.c_int\n    ]\n    atspi.atspi_state_set_contains.restype = ctypes.c_int\n\n    # Event listener — keeps the AT registration alive.\n    CALLBACK = ctypes.CFUNCTYPE(\n        None,\n        ctypes.c_void_p,\n        ctypes.c_void_p\n    )\n\n    @CALLBACK\n    def event_callback(_event, _user_data):\n        global dirty\n        dirty = True\n\n    atspi.atspi_event_listener_new.argtypes = [\n        CALLBACK,\n        ctypes.c_void_p,\n        ctypes.c_void_p\n    ]\n    atspi.atspi_event_listener_new.restype = ctypes.c_void_p\n\n    atspi.atspi_event_listener_register.argtypes = [\n        ctypes.c_void_p,\n        ctypes.c_char_p,\n        ctypes.c_void_p\n    ]\n    atspi.atspi_event_listener_register.restype = ctypes.c_int\n\n    init_result = int(atspi.atspi_init())\n\n    listener = atspi.atspi_event_listener_new(\n        event_callback,\n        None,\n        None\n    )\n\n    registrations = []\n\n    if listener:\n        for event_name in (\n            b\"object:children-changed\",\n            b\"object:selection-changed\",\n            b\"object:state-changed:selected\",\n            b\"window:activate\"\n        ):\n            try:\n                ok = int(\n                    atspi.atspi_event_listener_register(\n                        listener,\n                        event_name,\n                        None\n                    )\n                )\n            except Exception:\n                ok = 0\n\n            registrations.append(ok)\n\n    ready = bool(listener) and any(registrations)\n\n    print(\n        json.dumps({\n            \"ready\": ready,\n            \"library\": lib_name,\n            \"init\": init_result,\n            \"registrations\": registrations,\n            \"diagnostics\": [\n                \"LIBATSPI BRIDGE:%s\"\n                % (\"READY\" if ready else \"NOT READY\"),\n                \"LIBATSPI LIBRARY:%s\" % lib_name,\n                \"LIBATSPI INIT:%d\" % init_result,\n                \"LIBATSPI REGISTRATIONS:%s\"\n                % \",\".join(str(value) for value in registrations),\n                \"LIBATSPI ERROR:%s\"\n                % (\n                    \"NONE\"\n                    if ready\n                    else \"LIBATSPI EVENT REGISTRATION FAILED\"\n                )\n            ],\n            \"error\": \"\" if ready else \"LIBATSPI EVENT REGISTRATION FAILED\"\n        }),\n        flush=True\n    )\n\n    def c_string(pointer):\n        if not pointer:\n            return \"\"\n\n        try:\n            return ctypes.string_at(pointer).decode(\n                \"utf-8\",\n                \"replace\"\n            )\n        except Exception:\n            return \"\"\n\n    def get_name(obj):\n        if not obj:\n            return \"\"\n\n        try:\n            return c_string(\n                atspi.atspi_accessible_get_name(\n                    obj,\n                    None\n                )\n            ).strip()\n        except Exception:\n            return \"\"\n\n    def get_role_name(obj):\n        if not obj:\n            return \"\"\n\n        try:\n            return c_string(\n                atspi.atspi_accessible_get_role_name(\n                    obj,\n                    None\n                )\n            ).strip().lower().replace(\"_\", \" \")\n        except Exception:\n            return \"\"\n\n    def selected_state(obj):\n        try:\n            state_set = atspi.atspi_accessible_get_state_set(obj)\n\n            if not state_set:\n                return False\n\n            return bool(\n                atspi.atspi_state_set_contains(\n                    state_set,\n                    STATE_SELECTED\n                )\n                or atspi.atspi_state_set_contains(\n                    state_set,\n                    STATE_FOCUSED\n                )\n                or atspi.atspi_state_set_contains(\n                    state_set,\n                    STATE_ACTIVE\n                )\n            )\n        except Exception:\n            return False\n\n    def scan_libatspi():\n        rows = []\n        controls = []\n        diagnostics = [\n            \"LIBATSPI BRIDGE:%s\"\n            % (\"READY\" if ready else \"NOT READY\")\n        ]\n        seen = set()\n        control_seen = set()\n\n        desktop = atspi.atspi_get_desktop(0)\n\n        if not desktop:\n            diagnostics.extend([\n                \"LIBATSPI APPS:0\",\n                \"LIBATSPI NODES:0\",\n                \"LIBATSPI PAGE_TAB:0\",\n                \"LIBATSPI TABS:0\",\n                \"LIBATSPI CONTROLS:0\",\n                \"LIBATSPI ERROR:NO DESKTOP\"\n            ])\n            return rows, controls, diagnostics\n\n        visited = 0\n        app_count = 0\n        page_tab_count = 0\n        reclassified_control_count = 0\n        vscode_editor_candidate_count = 0\n        max_nodes = 30000\n        max_depth = 40\n\n        def add_row(item):\n            key = (\n                re.sub(\n                    r\"\\s+\",\n                    \" \",\n                    str(item.get(\"appName\") or \"\").lower()\n                ),\n                re.sub(\n                    r\"\\s+\",\n                    \" \",\n                    str(item.get(\"windowName\") or \"\").lower()\n                ),\n                re.sub(\n                    r\"\\s+\",\n                    \" \",\n                    str(item.get(\"tabTitle\") or \"\").lower()\n                )\n            )\n\n            if not key[2] or key in seen:\n                return\n\n            seen.add(key)\n            rows.append(item)\n\n        def add_control(item):\n            key = (\n                re.sub(\n                    r\"\\s+\",\n                    \" \",\n                    str(item.get(\"appName\") or \"\").lower()\n                ),\n                re.sub(\n                    r\"\\s+\",\n                    \" \",\n                    str(item.get(\"name\") or \"\").lower()\n                ),\n                int(item.get(\"role\") or -1)\n            )\n\n            if not key[1] or key in control_seen:\n                return\n\n            control_seen.add(key)\n            controls.append(item)\n\n        def walk(\n                obj,\n                path,\n                app_name=\"\",\n                window_name=\"\",\n                tab_context=False,\n                depth=0):\n            nonlocal visited, app_count, page_tab_count, reclassified_control_count, vscode_editor_candidate_count\n\n            if (\n                not obj\n                or depth > max_depth\n                or visited >= max_nodes\n            ):\n                return\n\n            visited += 1\n\n            try:\n                role = int(\n                    atspi.atspi_accessible_get_role(\n                        obj,\n                        None\n                    )\n                )\n            except Exception:\n                role = -1\n\n            name = get_name(obj)\n            role_name = get_role_name(obj)\n\n            if role == ROLE_APPLICATION:\n                app_count += 1\n\n                if name:\n                    app_name = name\n\n            if role == ROLE_PAGE_TAB:\n                page_tab_count += 1\n\n            if (\n                role in (\n                    ROLE_DIALOG,\n                    ROLE_FRAME,\n                    ROLE_WINDOW\n                )\n                and name\n            ):\n                window_name = name\n\n            is_tab_container = (\n                role == ROLE_PAGE_TAB_LIST\n                or \"page tab list\" in role_name\n                or role_name == \"tab list\"\n                or role_name == \"tablist\"\n                or role_name == \"tab bar\"\n            )\n\n            is_real_tab = (\n                role == ROLE_PAGE_TAB\n                or role_name == \"page tab\"\n                or role_name == \"tab\"\n                or role_name == \"document tab\"\n            )\n\n            # Chromium/Electron accessibility uses PAGE_TAB for more than\n            # document/editor tabs. VS Code's Activity Bar/view switcher is\n            # exposed as tabs too (Explorer, Search, Source Control, etc.).\n            # Preserve those objects, but classify them as alternate app\n            # controls so the left TABS list can stay document-focused.\n            app_key = re.sub(\n                r\"\\s+\",\n                \" \",\n                str(app_name or \"\").strip().lower()\n            )\n            label_key = re.sub(\n                r\"\\s+\",\n                \" \",\n                str(name or \"\").strip().lower()\n            )\n            label_base = re.sub(\n                r\"\\s*\\([^)]*\\)\\s*$\",\n                \"\",\n                label_key\n            ).strip()\n\n            is_vscode = (\n                app_key in (\n                    \"code\",\n                    \"visual studio code\",\n                    \"code - oss\",\n                    \"code-oss\",\n                    \"vscodium\"\n                )\n                or \"visual studio code\" in app_key\n            )\n\n            has_command_shortcut = bool(\n                re.search(\n                    r\"\\([^)]*(?:ctrl|alt|shift|cmd|super|meta)[^)]*\\)\\s*$\",\n                    label_key,\n                    re.IGNORECASE\n                )\n            )\n\n            vscode_view_labels = {\n                \"explorer\",\n                \"search\",\n                \"source control\",\n                \"run and debug\",\n                \"extensions\",\n                \"chat\",\n                \"testing\",\n                \"remote explorer\",\n                \"problems\",\n                \"output\",\n                \"debug console\",\n                \"terminal\",\n                \"ports\"\n            }\n\n            reclassified_vscode_control = (\n                is_real_tab\n                and is_vscode\n                and (\n                    has_command_shortcut\n                    or label_base in vscode_view_labels\n                )\n            )\n\n            if reclassified_vscode_control:\n                is_real_tab = False\n                reclassified_control_count += 1\n\n            # VS Code may expose the active editor as PAGE_TAB while sibling\n            # inactive editors become button/list-item objects in the same\n            # tab container. Promote those siblings to editor tabs, while\n            # keeping known Activity Bar/view controls on the right panel.\n            vscode_editor_candidate = (\n                is_vscode\n                and tab_context\n                and not is_real_tab\n                and not reclassified_vscode_control\n                and role in (\n                    ROLE_PUSH_BUTTON,\n                    ROLE_TOGGLE_BUTTON,\n                    ROLE_LIST_ITEM\n                )\n                and bool(label_base)\n                and label_base not in vscode_view_labels\n                and not label_base.startswith(\"close\")\n                and not label_base.startswith(\"split\")\n                and not label_base.startswith(\"more actions\")\n                and not has_command_shortcut\n            )\n\n            if vscode_editor_candidate:\n                is_real_tab = True\n                vscode_editor_candidate_count += 1\n\n            is_app_control = (\n                reclassified_vscode_control\n                or (\n                    tab_context\n                    and not is_real_tab\n                    and role in (\n                        ROLE_PUSH_BUTTON,\n                        ROLE_RADIO_BUTTON,\n                        ROLE_TOGGLE_BUTTON,\n                        ROLE_LIST_ITEM\n                    )\n                )\n            )\n\n            if is_real_tab and name:\n                add_row({\n                    \"_tabRecord\": True,\n                    \"id\": \"libatspi:\" + path,\n                    \"path\": path,\n                    \"name\": name,\n                    \"tabTitle\": name,\n                    \"appName\": app_name or \"APPLICATION\",\n                    \"windowName\": window_name,\n                    \"selected\": selected_state(obj),\n                    \"provider\": \"LIBATSPI\",\n                    \"role\": role,\n                    \"roleName\": role_name\n                })\n            elif is_app_control and name:\n                add_control({\n                    \"_tabControlRecord\": True,\n                    \"id\": \"libatspi-control:\" + path,\n                    \"path\": path,\n                    \"name\": name,\n                    \"controlName\": name,\n                    \"appName\": app_name or \"APPLICATION\",\n                    \"windowName\": window_name,\n                    \"selected\": selected_state(obj),\n                    \"provider\": \"LIBATSPI\",\n                    \"role\": role,\n                    \"roleName\": role_name\n                })\n\n            try:\n                child_count = int(\n                    atspi.atspi_accessible_get_child_count(\n                        obj,\n                        None\n                    )\n                )\n            except Exception:\n                child_count = 0\n\n            child_context = tab_context or is_tab_container\n\n            for index in range(max(0, child_count)):\n                if visited >= max_nodes:\n                    break\n\n                try:\n                    child = atspi.atspi_accessible_get_child_at_index(\n                        obj,\n                        index,\n                        None\n                    )\n                except Exception:\n                    child = None\n\n                if not child:\n                    continue\n\n                child_path = (\n                    str(index)\n                    if not path\n                    else path + \".\" + str(index)\n                )\n\n                walk(\n                    child,\n                    child_path,\n                    app_name,\n                    window_name,\n                    child_context,\n                    depth + 1\n                )\n\n        walk(desktop, \"\")\n\n        diagnostics.extend([\n            \"LIBATSPI APPS:%d\" % app_count,\n            \"LIBATSPI NODES:%d\" % visited,\n            \"LIBATSPI PAGE_TAB:%d\" % page_tab_count,\n            \"LIBATSPI TABS:%d\" % len(rows),\n            \"LIBATSPI CONTROLS:%d\" % len(controls),\n            \"LIBATSPI RECLASSIFIED:%d\" % reclassified_control_count,\n            \"VSCODE EDITOR CANDIDATES:%d\" % vscode_editor_candidate_count,\n            \"LIBATSPI ERROR:NONE\"\n        ])\n\n        return rows, controls, diagnostics\n\n    last_emit = 0.0\n    last_signature = None\n\n    while running:\n        now = time.monotonic()\n\n        if dirty or (now - last_emit) >= 1.15:\n            dirty = False\n\n            lib_rows, lib_controls, diagnostics = scan_libatspi()\n            extra_rows, extra_diagnostics = process_provider_tabs()\n            diagnostics.extend(extra_diagnostics)\n\n            all_rows = []\n            dedupe = set()\n\n            for item in lib_rows + extra_rows:\n                key = (\n                    re.sub(\n                        r\"\\s+\",\n                        \" \",\n                        str(item.get(\"appName\") or \"\").lower()\n                    ),\n                    re.sub(\n                        r\"\\s+\",\n                        \" \",\n                        str(item.get(\"tabTitle\") or \"\").lower()\n                    )\n                )\n\n                if not key[1] or key in dedupe:\n                    continue\n\n                dedupe.add(key)\n                all_rows.append(item)\n\n            diagnostics.append(\n                \"PROVIDER TABS TOTAL:%d\"\n                % len(all_rows)\n            )\n\n            signature = json.dumps(\n                {\n                    \"tabs\": [\n                        (\n                            item.get(\"provider\"),\n                            item.get(\"id\"),\n                            item.get(\"selected\")\n                        )\n                        for item in all_rows\n                    ],\n                    \"controls\": [\n                        (\n                            item.get(\"provider\"),\n                            item.get(\"id\"),\n                            item.get(\"selected\")\n                        )\n                        for item in lib_controls\n                    ]\n                },\n                sort_keys=True\n            )\n\n            # Emit at least every interval so QML can recover if it missed\n            # an earlier snapshot. Changes emit immediately.\n            if signature != last_signature or (now - last_emit) >= 1.15:\n                print(\n                    json.dumps({\n                        \"ready\": ready,\n                        \"tabs\": all_rows,\n                        \"controls\": lib_controls,\n                        \"diagnostics\": diagnostics,\n                        \"error\":\n                            \"\"\n                            if all_rows\n                            else \" • \".join(diagnostics)\n                    }),\n                    flush=True\n                )\n\n                last_signature = signature\n                last_emit = now\n\n        time.sleep(0.10)\n\nexcept Exception as exc:\n    print(\n        json.dumps({\n            \"ready\": False,\n            \"tabs\": [],\n            \"controls\": [],\n            \"diagnostics\": [\n                \"LIBATSPI BRIDGE:NOT READY\",\n                \"LIBATSPI ERROR:\" + str(exc),\n                \"KITTY ERROR:BRIDGE ABORTED BEFORE PROVIDER SCAN\",\n                \"DEVTOOLS ERROR:BRIDGE ABORTED BEFORE PROVIDER SCAN\"\n            ],\n            \"error\": \"LIBATSPI BRIDGE: \" + str(exc)\n        }),\n        flush=True\n    )\n    sys.exit(1)\n";
    }

    Process {
        id: appTabsBridgeProcess

        command: [
            "/usr/bin/python3",
            "-u",
            "-c",
            appControlWindow.appTabBridgeScript()
        ]

        running:
            appControlWindow.menuOpen
            && appControlWindow.selectedModeIndex
               === appControlWindow.windowsModeIndex
            && appControlWindow.windowListMode
               === appControlWindow.windowListTabs

        stdout: SplitParser {
            onRead: function(line) {
                const raw = String(line || "").trim();

                if (!raw)
                    return;

                try {
                    const payload = JSON.parse(raw);

                    appControlWindow.appTabsBridgeReady =
                        !!payload.ready;
                    appControlWindow.appTabsBridgeError =
                        String(payload.error || "");

                    if (Array.isArray(payload.diagnostics)) {
                        const diagnosticRows =
                            payload.diagnostics.map(function(value) {
                                return String(value || "");
                            });
                        const diagnosticText =
                            diagnosticRows.join(" • ");

                        // Heartbeat diagnostics are usually identical. Do not
                        // replace the array unless the text actually changed,
                        // because windowResults observes this property too.
                        if (diagnosticText
                                !== appControlWindow.appTabsDiagnosticsSignature) {
                            appControlWindow.appTabsDiagnosticsSignature =
                                diagnosticText;
                            appControlWindow.appTabsDiagnostics =
                                diagnosticRows;

                            if (diagnosticText.length > 0)
                                console.log(
                                    "AppControl TABS diagnostics:",
                                    diagnosticText
                                );
                        }
                    }

                    if (Array.isArray(payload.controls))
                        appControlWindow.appTabControls =
                            payload.controls.slice();

                    if (Array.isArray(payload.tabs)) {
                        const nextTabs = payload.tabs;

                        if (nextTabs.length > 0
                                || appControlWindow.appTabs.length === 0)
                            appControlWindow.updateAppTabsStable(nextTabs);

                        appControlWindow.appTabsLoading = false;

                        if (nextTabs.length > 0)
                            appControlWindow.appTabsError = "";
                        else if (Array.isArray(payload.diagnostics))
                            appControlWindow.appTabsError =
                                payload.diagnostics.join(" • ");
                    }

                    if (payload.ready)
                        appTabsBridgeRefreshTimer.restart();
                } catch (error) {
                    appControlWindow.appTabsBridgeReady = false;
                    appControlWindow.appTabsBridgeError =
                        "TAB BRIDGE PARSE: " + String(error);
                }
            }
        }

        stderr: SplitParser {
            onRead: function(line) {
                const message = String(line || "").trim();

                if (message.length > 0)
                    appControlWindow.appTabsBridgeError = message;
            }
        }

        onRunningChanged: {
            if (!running)
                appControlWindow.appTabsBridgeReady = false;
        }
    }

    Timer {
        id: appTabsBridgeRefreshTimer

        interval: 700
        repeat: false

        onTriggered: {
            if (appControlWindow.menuOpen
                    && appControlWindow.selectedModeIndex
                       === appControlWindow.windowsModeIndex
                    && appControlWindow.windowListMode
                       === appControlWindow.windowListTabs)
                appControlWindow.refreshAppTabs();
        }
    }

    function appTabScanScript() {
        return "import ast\nimport json\nimport os\nimport re\nimport shutil\nimport subprocess\nimport time\nimport urllib.request\n\ntabs = []\ndiagnostics = []\nseen = set()\n\nROLE_DIALOG = 16\nROLE_FRAME = 23\nROLE_PAGE_TAB = 37\nROLE_PAGE_TAB_LIST = 38\nROLE_PUSH_BUTTON = 43\nROLE_RADIO_BUTTON = 44\nROLE_WINDOW = 69\nROLE_APPLICATION = 75\n\nSTATE_ACTIVE = 1\nSTATE_FOCUSED = 12\nSTATE_SELECTED = 23\n\ndef add_tab(item):\n    title = str(item.get(\"tabTitle\") or item.get(\"name\") or \"\").strip()\n    app = str(item.get(\"appName\") or \"\").strip()\n    window = str(item.get(\"windowName\") or \"\").strip()\n\n    if not title:\n        return\n\n    # Cross-provider dedupe. The same Brave/Code tab may be visible through\n    # libatspi and the raw cache at the same time.\n    key = (\n        re.sub(r\"\\s+\", \" \", app.lower()),\n        re.sub(r\"\\s+\", \" \", window.lower()),\n        re.sub(r\"\\s+\", \" \", title.lower())\n    )\n\n    if key in seen:\n        return\n\n    seen.add(key)\n    tabs.append(item)\n\ndef run_cmd(argv, timeout=1.5):\n    try:\n        proc = subprocess.run(\n            argv,\n            stdout=subprocess.PIPE,\n            stderr=subprocess.PIPE,\n            text=True,\n            timeout=timeout\n        )\n        return proc.returncode, proc.stdout.strip(), proc.stderr.strip()\n    except Exception as exc:\n        return 1, \"\", str(exc)\n\ndef first_string(raw):\n    match = re.search(r\"'((?:\\\\.|[^'])*)'\", str(raw or \"\"))\n    if not match:\n        return \"\"\n\n    try:\n        return ast.literal_eval(\"'\" + match.group(1) + \"'\")\n    except Exception:\n        return match.group(1).replace(\"\\\\'\", \"'\").replace(\"\\\\\\\\\", \"\\\\\")\n\ndef parse_gvariant_literal(raw):\n    text = str(raw or \"\").strip()\n\n    if not text:\n        return None\n\n    # gdbus prints valid Python-ish containers plus GVariant type words.\n    # Cache.GetItems has no arbitrary variants, so stripping the annotations\n    # leaves a safe literal that ast.literal_eval can consume.\n    text = re.sub(\n        r\"@[A-Za-z0-9_{}()]+(?=\\s)\",\n        \"\",\n        text\n    )\n    text = re.sub(\n        r\"\\b(?:objectpath|signature|byte|uint16|uint32|uint64|\"\n        r\"int16|int32|int64|double)\\s+\",\n        \"\",\n        text\n    )\n    text = re.sub(r\"\\btrue\\b\", \"True\", text, flags=re.I)\n    text = re.sub(r\"\\bfalse\\b\", \"False\", text, flags=re.I)\n\n    return ast.literal_eval(text)\n\ndef as_ref(value):\n    if (\n        isinstance(value, (tuple, list))\n        and len(value) >= 2\n    ):\n        return (\n            str(value[0] or \"\"),\n            str(value[1] or \"\")\n        )\n\n    return (\"\", \"\")\n\ndef parse_registry_roots(raw):\n    try:\n        payload = parse_gvariant_literal(raw)\n    except Exception:\n        payload = None\n\n    if (\n        isinstance(payload, tuple)\n        and len(payload) == 1\n    ):\n        payload = payload[0]\n\n    refs = []\n\n    if isinstance(payload, list):\n        for value in payload:\n            ref = as_ref(value)\n            if ref[0] and ref[1] and not ref[1].endswith(\"/null\"):\n                refs.append(ref)\n\n    # Fallback for older/newer gdbus formatting.\n    if not refs:\n        pattern = re.compile(\n            r\"\\('([^']*)',\\s*(?:objectpath\\s*)?'([^']*)'\\)\"\n        )\n\n        for bus_name, object_path in pattern.findall(str(raw or \"\")):\n            if (\n                bus_name\n                and object_path\n                and not object_path.endswith(\"/null\")\n            ):\n                refs.append((bus_name, object_path))\n\n    return refs\n\ndef enable_a11y_runtime():\n    enabled = False\n    notes = []\n\n    if shutil.which(\"busctl\"):\n        rc, out, err = run_cmd([\n            \"busctl\",\n            \"--user\",\n            \"set-property\",\n            \"org.a11y.Bus\",\n            \"/org/a11y/bus\",\n            \"org.a11y.Status\",\n            \"IsEnabled\",\n            \"b\",\n            \"true\"\n        ], 1.5)\n\n        if rc == 0:\n            enabled = True\n            notes.append(\"BUSCTL\")\n        elif err:\n            notes.append(\"BUSCTL:\" + err)\n\n    if not enabled and shutil.which(\"gdbus\"):\n        rc, out, err = run_cmd([\n            \"gdbus\",\n            \"call\",\n            \"--session\",\n            \"--dest\", \"org.a11y.Bus\",\n            \"--object-path\", \"/org/a11y/bus\",\n            \"--method\", \"org.freedesktop.DBus.Properties.Set\",\n            \"org.a11y.Status\",\n            \"IsEnabled\",\n            \"<true>\"\n        ], 1.5)\n\n        if rc == 0:\n            enabled = True\n            notes.append(\"GDBUS\")\n        elif err:\n            notes.append(\"GDBUS:\" + err)\n\n    state = \"\"\n\n    if shutil.which(\"gdbus\"):\n        rc, out, err = run_cmd([\n            \"gdbus\",\n            \"call\",\n            \"--session\",\n            \"--dest\", \"org.a11y.Bus\",\n            \"--object-path\", \"/org/a11y/bus\",\n            \"--method\", \"org.freedesktop.DBus.Properties.Get\",\n            \"org.a11y.Status\",\n            \"IsEnabled\"\n        ], 1.5)\n\n        if rc == 0:\n            state = out\n\n    actually_enabled = enabled or \"true\" in state.lower()\n\n    diagnostics.append(\n        \"A11Y:%s%s\"\n        % (\n            \"ON\" if actually_enabled else \"OFF\",\n            (\"(\" + \",\".join(notes) + \")\") if notes else \"\"\n        )\n    )\n\n    if actually_enabled:\n        time.sleep(0.55)\n\n    return actually_enabled\n\n\ndef get_a11y_bus_address():\n    if not shutil.which(\"gdbus\"):\n        return \"\"\n\n    code, out, _ = run_cmd([\n        \"gdbus\", \"call\",\n        \"--session\",\n        \"--dest\", \"org.a11y.Bus\",\n        \"--object-path\", \"/org/a11y/bus\",\n        \"--method\", \"org.a11y.Bus.GetAddress\"\n    ], 1.5)\n\n    if code != 0:\n        return \"\"\n\n    return first_string(out)\n\ndef role_number(value):\n    try:\n        return int(value)\n    except Exception:\n        return -1\n\ndef state_values(value):\n    if isinstance(value, (tuple, list)):\n        result = []\n        for item in value:\n            try:\n                result.append(int(item))\n            except Exception:\n                pass\n        return result\n    return []\n\ndef normalize_cache_item(item):\n    if not isinstance(item, (tuple, list)):\n        return None\n\n    # Current cache signature:\n    # ((so)(so)(so)iiassusau)\n    if (\n        len(item) >= 10\n        and isinstance(item[3], int)\n        and isinstance(item[4], int)\n    ):\n        return {\n            \"ref\": as_ref(item[0]),\n            \"appRef\": as_ref(item[1]),\n            \"parentRef\": as_ref(item[2]),\n            \"interfaces\": list(item[5]) if isinstance(item[5], (list, tuple)) else [],\n            \"name\": str(item[6] or \"\"),\n            \"role\": role_number(item[7]),\n            \"description\": str(item[8] or \"\"),\n            \"states\": state_values(item[9])\n        }\n\n    # Qt legacy cache signature:\n    # ((so)(so)(so)a(so)assusau)\n    if len(item) >= 9:\n        return {\n            \"ref\": as_ref(item[0]),\n            \"appRef\": as_ref(item[1]),\n            \"parentRef\": as_ref(item[2]),\n            \"interfaces\": list(item[4]) if isinstance(item[4], (list, tuple)) else [],\n            \"name\": str(item[5] or \"\"),\n            \"role\": role_number(item[6]),\n            \"description\": str(item[7] or \"\"),\n            \"states\": state_values(item[8])\n        }\n\n    return None\n\ndef parse_cache_items(raw):\n    payload = parse_gvariant_literal(raw)\n\n    if (\n        isinstance(payload, tuple)\n        and len(payload) == 1\n    ):\n        payload = payload[0]\n\n    if not isinstance(payload, list):\n        return []\n\n    rows = []\n\n    for item in payload:\n        normalized = normalize_cache_item(item)\n\n        if normalized is not None:\n            rows.append(normalized)\n\n    return rows\n\ndef ancestor_info(row, by_ref):\n    app_name = \"\"\n    window_name = \"\"\n    parent = row.get(\"parentRef\", (\"\", \"\"))\n    visited = set()\n\n    while parent and parent not in visited:\n        visited.add(parent)\n        ancestor = by_ref.get(parent)\n\n        if not ancestor:\n            break\n\n        role = ancestor.get(\"role\", -1)\n        name = str(ancestor.get(\"name\") or \"\").strip()\n\n        if (\n            not window_name\n            and role in (\n                ROLE_DIALOG,\n                ROLE_FRAME,\n                ROLE_WINDOW\n            )\n            and name\n        ):\n            window_name = name\n\n        if role == ROLE_APPLICATION and name:\n            app_name = name\n            break\n\n        parent = ancestor.get(\"parentRef\", (\"\", \"\"))\n\n    return app_name, window_name\n\na11y_runtime_enabled = enable_a11y_runtime()\na11y_address = get_a11y_bus_address()\n\n# ------------------------------------------------------------\n# Provider 1: libatspi through PyGObject, when installed.\n# Use numeric roles instead of GetRoleName(); GetRoleName is optional.\n# ------------------------------------------------------------\ngi_count = 0\n\ntry:\n    import gi\n    gi.require_version(\"Atspi\", \"2.0\")\n    from gi.repository import Atspi\n\n    try:\n        Atspi.init()\n    except Exception:\n        pass\n\n    desktop = Atspi.get_desktop(0)\n    visited = 0\n    max_nodes = 26000\n    max_depth = 36\n\n    def gi_name(obj):\n        try:\n            return str(obj.get_name() or \"\")\n        except Exception:\n            return \"\"\n\n    def gi_role(obj):\n        try:\n            return int(obj.get_role())\n        except Exception:\n            return -1\n\n    def gi_selected(obj):\n        try:\n            states = obj.get_state_set()\n\n            return bool(\n                states.contains(Atspi.StateType.SELECTED)\n                or states.contains(Atspi.StateType.FOCUSED)\n                or states.contains(Atspi.StateType.ACTIVE)\n            )\n        except Exception:\n            return False\n\n    def gi_walk(\n            obj,\n            path,\n            app_name=\"\",\n            window_name=\"\",\n            tab_context=False,\n            depth=0):\n        global visited, gi_count\n\n        if (\n            obj is None\n            or depth > max_depth\n            or visited >= max_nodes\n        ):\n            return\n\n        visited += 1\n\n        role = gi_role(obj)\n        name = gi_name(obj).strip()\n\n        if role == ROLE_APPLICATION and name:\n            app_name = name\n\n        if (\n            role in (\n                ROLE_DIALOG,\n                ROLE_FRAME,\n                ROLE_WINDOW\n            )\n            and name\n        ):\n            window_name = name\n\n        is_tab_container = role == ROLE_PAGE_TAB_LIST\n\n        is_tab = (\n            role == ROLE_PAGE_TAB\n            or (\n                tab_context\n                and role in (\n                    ROLE_PUSH_BUTTON,\n                    ROLE_RADIO_BUTTON\n                )\n            )\n        )\n\n        if is_tab and name:\n            add_tab({\n                \"_tabRecord\": True,\n                \"id\": \"atspi:\" + path,\n                \"path\": path,\n                \"name\": name,\n                \"tabTitle\": name,\n                \"appName\": app_name or \"APPLICATION\",\n                \"windowName\": window_name,\n                \"selected\": gi_selected(obj),\n                \"provider\": \"AT-SPI\"\n            })\n            gi_count += 1\n\n        try:\n            count = int(obj.get_child_count())\n        except Exception:\n            count = 0\n\n        child_tab_context = tab_context or is_tab_container\n\n        for index in range(count):\n            try:\n                child = obj.get_child_at_index(index)\n            except Exception:\n                continue\n\n            child_path = (\n                str(index)\n                if not path\n                else path + \".\" + str(index)\n            )\n\n            gi_walk(\n                child,\n                child_path,\n                app_name,\n                window_name,\n                child_tab_context,\n                depth + 1\n            )\n\n    gi_walk(desktop, \"\")\n    diagnostics.append(\"AT-SPI GI:%d\" % gi_count)\n\nexcept Exception as exc:\n    diagnostics.append(\"AT-SPI GI ERROR:%s\" % exc)\n\n# ------------------------------------------------------------\n# Provider 2: AT-SPI Cache.GetItems through gdbus.\n#\n# This is the important fallback. Cache.GetItems returns each app's\n# accessibility tree in ONE D-Bus call, including Name, Role, Parent and\n# State. It avoids launching thousands of gdbus processes and works even\n# when python3-gi is not installed.\n# ------------------------------------------------------------\ncache_count = 0\ncache_apps = 0\n\nif a11y_address and shutil.which(\"gdbus\"):\n    code, roots_raw, roots_err = run_cmd([\n        \"gdbus\", \"call\",\n        \"--address\", a11y_address,\n        \"--dest\", \"org.a11y.atspi.Registry\",\n        \"--object-path\", \"/org/a11y/atspi/accessible/root\",\n        \"--method\", \"org.a11y.atspi.Accessible.GetChildren\"\n    ], 2.0)\n\n    roots = parse_registry_roots(roots_raw) if code == 0 else []\n\n    if code != 0:\n        diagnostics.append(\n            \"AT-SPI CACHE ROOT ERROR:\"\n            + (roots_err or \"GetChildren failed\")\n        )\n    else:\n        unique_buses = []\n        seen_buses = set()\n\n        for bus_name, _ in roots:\n            if bus_name and bus_name not in seen_buses:\n                seen_buses.add(bus_name)\n                unique_buses.append(bus_name)\n\n        for bus_name in unique_buses:\n            code, cache_raw, cache_err = run_cmd([\n                \"gdbus\", \"call\",\n                \"--address\", a11y_address,\n                \"--dest\", bus_name,\n                \"--object-path\", \"/org/a11y/atspi/cache\",\n                \"--method\", \"org.a11y.atspi.Cache.GetItems\"\n            ], 2.4)\n\n            if (code != 0 or not cache_raw) and a11y_runtime_enabled:\n                time.sleep(0.12)\n                code, cache_raw, cache_err = run_cmd([\n                    \"gdbus\", \"call\",\n                    \"--address\", a11y_address,\n                    \"--dest\", bus_name,\n                    \"--object-path\", \"/org/a11y/atspi/cache\",\n                    \"--method\", \"org.a11y.atspi.Cache.GetItems\"\n                ], 2.4)\n\n            if code != 0 or not cache_raw:\n                continue\n\n            try:\n                rows = parse_cache_items(cache_raw)\n            except Exception:\n                continue\n\n            if not rows:\n                continue\n\n            cache_apps += 1\n\n            by_ref = {\n                row[\"ref\"]: row\n                for row in rows\n                if row.get(\"ref\", (\"\", \"\"))[0]\n                and row.get(\"ref\", (\"\", \"\"))[1]\n            }\n\n            for row in rows:\n                role = row.get(\"role\", -1)\n                parent_row = by_ref.get(\n                    row.get(\"parentRef\", (\"\", \"\"))\n                )\n                parent_role = (\n                    parent_row.get(\"role\", -1)\n                    if parent_row\n                    else -1\n                )\n\n                is_tab = (\n                    role == ROLE_PAGE_TAB\n                    or (\n                        parent_role == ROLE_PAGE_TAB_LIST\n                        and role in (\n                            ROLE_PUSH_BUTTON,\n                            ROLE_RADIO_BUTTON\n                        )\n                    )\n                )\n\n                if not is_tab:\n                    continue\n\n                name = str(row.get(\"name\") or \"\").strip()\n\n                if not name:\n                    continue\n\n                app_name, window_name = ancestor_info(\n                    row,\n                    by_ref\n                )\n\n                states = row.get(\"states\", [])\n\n                add_tab({\n                    \"_tabRecord\": True,\n                    \"id\":\n                        \"atspi-cache:\"\n                        + row[\"ref\"][0]\n                        + \":\"\n                        + row[\"ref\"][1],\n                    \"path\": \"\",\n                    \"busName\": row[\"ref\"][0],\n                    \"objectPath\": row[\"ref\"][1],\n                    \"name\": name,\n                    \"tabTitle\": name,\n                    \"appName\": app_name or \"APPLICATION\",\n                    \"windowName\": window_name,\n                    \"selected\":\n                        STATE_SELECTED in states\n                        or STATE_FOCUSED in states\n                        or STATE_ACTIVE in states,\n                    \"provider\": \"AT-SPI-CACHE\"\n                })\n                cache_count += 1\n\n        diagnostics.append(\n            \"AT-SPI CACHE:%d/%d\"\n            % (cache_count, cache_apps)\n        )\nelse:\n    diagnostics.append(\"AT-SPI CACHE:UNAVAILABLE\")\n\n# ------------------------------------------------------------\n# Provider 3: Kitty remote control.\n# ------------------------------------------------------------\nkitty_addresses = []\n\ntry:\n    for pid in os.listdir(\"/proc\"):\n        if not pid.isdigit():\n            continue\n\n        try:\n            env = open(\n                \"/proc/%s/environ\" % pid,\n                \"rb\"\n            ).read().split(b\"\\0\")\n        except Exception:\n            continue\n\n        for item in env:\n            if item.startswith(b\"KITTY_LISTEN_ON=\"):\n                address = item.split(\n                    b\"=\",\n                    1\n                )[1].decode(\n                    \"utf-8\",\n                    \"ignore\"\n                ).strip()\n\n                if (\n                    address\n                    and address not in kitty_addresses\n                ):\n                    kitty_addresses.append(address)\nexcept Exception:\n    pass\n\nkitty_count = 0\n\nfor address in kitty_addresses:\n    try:\n        proc = subprocess.run(\n            [\n                \"kitty\",\n                \"@\",\n                \"--to\",\n                address,\n                \"ls\"\n            ],\n            stdout=subprocess.PIPE,\n            stderr=subprocess.DEVNULL,\n            text=True,\n            timeout=1.5\n        )\n\n        if (\n            proc.returncode != 0\n            or not proc.stdout.strip()\n        ):\n            continue\n\n        payload = json.loads(proc.stdout)\n\n        for os_window in (\n            payload\n            if isinstance(payload, list)\n            else []\n        ):\n            for tab in os_window.get(\"tabs\", []) or []:\n                tab_id = tab.get(\"id\")\n                title = str(\n                    tab.get(\"title\")\n                    or \"\"\n                ).strip()\n\n                if not title:\n                    wins = tab.get(\"windows\", []) or []\n                    active = next(\n                        (\n                            w for w in wins\n                            if w.get(\"is_active\")\n                        ),\n                        None\n                    )\n                    active = (\n                        active\n                        or (wins[0] if wins else {})\n                    )\n                    title = str(\n                        active.get(\"title\")\n                        or active.get(\"cwd\")\n                        or (\n                            \"KITTY TAB \"\n                            + str(tab_id)\n                        )\n                    )\n\n                add_tab({\n                    \"_tabRecord\": True,\n                    \"id\":\n                        \"kitty:\"\n                        + str(tab_id),\n                    \"path\": \"\",\n                    \"name\": title,\n                    \"tabTitle\": title,\n                    \"appName\": \"Kitty\",\n                    \"windowName\":\n                        str(\n                            os_window.get(\"id\")\n                            or \"\"\n                        ),\n                    \"selected\":\n                        bool(tab.get(\"is_active\")),\n                    \"provider\": \"KITTY\",\n                    \"kittyAddress\": address,\n                    \"kittyTabId\": tab_id\n                })\n                kitty_count += 1\n\n    except Exception:\n        pass\n\ndiagnostics.append(\"KITTY:%d\" % kitty_count)\n\n# ------------------------------------------------------------\n# Provider 4: Chromium/Electron DevTools, when already enabled.\n# ------------------------------------------------------------\nports = {}\n\ntry:\n    for pid in os.listdir(\"/proc\"):\n        if not pid.isdigit():\n            continue\n\n        try:\n            raw = open(\n                \"/proc/%s/cmdline\" % pid,\n                \"rb\"\n            ).read()\n\n            argv = [\n                part.decode(\n                    \"utf-8\",\n                    \"ignore\"\n                )\n                for part in raw.split(b\"\\0\")\n                if part\n            ]\n        except Exception:\n            continue\n\n        if not argv:\n            continue\n\n        exe = os.path.basename(\n            argv[0]\n        ).lower()\n\n        app_name = (\n            \"Brave\"\n            if \"brave\" in exe\n            else \"Chrome\"\n            if \"chrome\" in exe\n            else \"Chromium\"\n            if \"chromium\" in exe\n            else \"VS Code\"\n            if exe in (\n                \"code\",\n                \"code-oss\",\n                \"codium\"\n            )\n            else \"Electron\"\n            if \"electron\" in exe\n            else \"\"\n        )\n\n        if not app_name:\n            continue\n\n        port = None\n\n        for index, arg in enumerate(argv):\n            if arg.startswith(\n                    \"--remote-debugging-port=\"):\n                try:\n                    port = int(\n                        arg.split(\"=\", 1)[1]\n                    )\n                except Exception:\n                    port = None\n                break\n\n            if (\n                arg == \"--remote-debugging-port\"\n                and index + 1 < len(argv)\n            ):\n                try:\n                    port = int(argv[index + 1])\n                except Exception:\n                    port = None\n                break\n\n        if port and port > 0:\n            ports[port] = app_name\n\nexcept Exception:\n    pass\n\ndevtools_count = 0\n\nfor port, app_name in ports.items():\n    try:\n        with urllib.request.urlopen(\n            \"http://127.0.0.1:%d/json/list\"\n            % port,\n            timeout=0.8\n        ) as response:\n            targets = json.loads(\n                response.read().decode(\n                    \"utf-8\",\n                    \"ignore\"\n                )\n            )\n    except Exception:\n        continue\n\n    for target in targets:\n        if str(\n            target.get(\"type\", \"\")\n        ).lower() not in (\n            \"page\",\n            \"webview\"\n        ):\n            continue\n\n        target_id = str(\n            target.get(\"id\")\n            or \"\"\n        ).strip()\n\n        title = str(\n            target.get(\"title\")\n            or target.get(\"url\")\n            or \"\"\n        ).strip()\n\n        if not target_id or not title:\n            continue\n\n        add_tab({\n            \"_tabRecord\": True,\n            \"id\":\n                \"devtools:%d:%s\"\n                % (port, target_id),\n            \"path\": \"\",\n            \"name\": title,\n            \"tabTitle\": title,\n            \"appName\": app_name,\n            \"windowName\":\n                str(target.get(\"url\") or \"\"),\n            \"selected\": False,\n            \"provider\": \"DEVTOOLS\",\n            \"debugPort\": port,\n            \"targetId\": target_id\n        })\n        devtools_count += 1\n\ndiagnostics.append(\n    \"DEVTOOLS:%d\"\n    % devtools_count\n)\n\nprint(json.dumps({\n    \"error\":\n        \"\"\n        if tabs\n        else \"NO TABS \u2022 \" + \" | \".join(diagnostics),\n    \"tabs\": tabs,\n    \"diagnostics\": diagnostics\n}))\n";
    }

    function appTabActivateScript() {
        return "import ast\nimport ctypes\nimport ctypes.util\nimport json\nimport re\nimport subprocess\nimport sys\nimport urllib.request\n\nprovider = sys.argv[1] if len(sys.argv) > 1 else \"\"\npayload = sys.argv[2] if len(sys.argv) > 2 else \"\"\n\ntry:\n    data = json.loads(payload or \"{}\")\nexcept Exception:\n    data = {}\n\nacted = False\nerror = \"\"\n\ntry:\n    if provider == \"LIBATSPI\":\n        lib_name = (\n            ctypes.util.find_library(\"atspi\")\n            or \"libatspi.so.0\"\n        )\n        atspi = ctypes.CDLL(lib_name)\n\n        atspi.atspi_init.argtypes = []\n        atspi.atspi_init.restype = ctypes.c_int\n\n        atspi.atspi_get_desktop.argtypes = [ctypes.c_int]\n        atspi.atspi_get_desktop.restype = ctypes.c_void_p\n\n        atspi.atspi_accessible_get_child_at_index.argtypes = [\n            ctypes.c_void_p,\n            ctypes.c_int,\n            ctypes.c_void_p\n        ]\n        atspi.atspi_accessible_get_child_at_index.restype = ctypes.c_void_p\n\n        atspi.atspi_accessible_get_child_count.argtypes = [\n            ctypes.c_void_p,\n            ctypes.c_void_p\n        ]\n        atspi.atspi_accessible_get_child_count.restype = ctypes.c_int\n\n        atspi.atspi_accessible_get_role.argtypes = [\n            ctypes.c_void_p,\n            ctypes.c_void_p\n        ]\n        atspi.atspi_accessible_get_role.restype = ctypes.c_int\n\n        atspi.atspi_accessible_get_name.argtypes = [\n            ctypes.c_void_p,\n            ctypes.c_void_p\n        ]\n        atspi.atspi_accessible_get_name.restype = ctypes.c_void_p\n\n        atspi.atspi_accessible_get_action_iface.argtypes = [\n            ctypes.c_void_p\n        ]\n        atspi.atspi_accessible_get_action_iface.restype = ctypes.c_void_p\n\n        atspi.atspi_action_get_n_actions.argtypes = [\n            ctypes.c_void_p,\n            ctypes.c_void_p\n        ]\n        atspi.atspi_action_get_n_actions.restype = ctypes.c_int\n\n        atspi.atspi_action_get_action_name.argtypes = [\n            ctypes.c_void_p,\n            ctypes.c_int,\n            ctypes.c_void_p\n        ]\n        atspi.atspi_action_get_action_name.restype = ctypes.c_void_p\n\n        atspi.atspi_action_do_action.argtypes = [\n            ctypes.c_void_p,\n            ctypes.c_int,\n            ctypes.c_void_p\n        ]\n        atspi.atspi_action_do_action.restype = ctypes.c_int\n\n        atspi.atspi_accessible_get_component_iface.argtypes = [\n            ctypes.c_void_p\n        ]\n        atspi.atspi_accessible_get_component_iface.restype = ctypes.c_void_p\n\n        atspi.atspi_component_grab_focus.argtypes = [\n            ctypes.c_void_p,\n            ctypes.c_void_p\n        ]\n        atspi.atspi_component_grab_focus.restype = ctypes.c_int\n\n        atspi.atspi_init()\n\n        def read_string(pointer):\n            if not pointer:\n                return \"\"\n\n            try:\n                return ctypes.string_at(pointer).decode(\n                    \"utf-8\",\n                    \"replace\"\n                )\n            except Exception:\n                return \"\"\n\n        def obj_name(obj):\n            try:\n                return read_string(\n                    atspi.atspi_accessible_get_name(\n                        obj,\n                        None\n                    )\n                ).strip()\n            except Exception:\n                return \"\"\n\n        desktop = atspi.atspi_get_desktop(0)\n        obj = desktop\n        path = str(data.get(\"path\") or \"\")\n\n        for piece in path.split(\".\"):\n            if not piece:\n                continue\n\n            if not obj:\n                break\n\n            try:\n                obj = atspi.atspi_accessible_get_child_at_index(\n                    obj,\n                    int(piece),\n                    None\n                )\n            except Exception:\n                obj = None\n\n        wanted_title = str(\n            data.get(\"tabTitle\")\n            or data.get(\"controlName\")\n            or data.get(\"name\")\n            or \"\"\n        ).strip()\n        wanted_role = int(data.get(\"role\") or -1)\n        is_control = bool(data.get(\"_tabControlRecord\"))\n\n        # If the tree changed between scan and click, search by current title.\n        if not obj or (\n            wanted_title\n            and obj_name(obj) != wanted_title\n        ):\n            obj = None\n            max_nodes = 20000\n            visited = 0\n            stack = [desktop] if desktop else []\n\n            while stack and visited < max_nodes and not obj:\n                candidate = stack.pop()\n                visited += 1\n\n                try:\n                    role = int(\n                        atspi.atspi_accessible_get_role(\n                            candidate,\n                            None\n                        )\n                    )\n                except Exception:\n                    role = -1\n\n                role_matches = (\n                    role == wanted_role\n                    if is_control and wanted_role >= 0\n                    else role == 37\n                )\n\n                if role_matches and obj_name(candidate) == wanted_title:\n                    obj = candidate\n                    break\n\n                try:\n                    count = int(\n                        atspi.atspi_accessible_get_child_count(\n                            candidate,\n                            None\n                        )\n                    )\n                except Exception:\n                    count = 0\n\n                for index in range(max(0, count) - 1, -1, -1):\n                    try:\n                        child = atspi.atspi_accessible_get_child_at_index(\n                            candidate,\n                            index,\n                            None\n                        )\n                    except Exception:\n                        child = None\n\n                    if child:\n                        stack.append(child)\n\n        if obj:\n            action = atspi.atspi_accessible_get_action_iface(obj)\n\n            if action:\n                try:\n                    count = int(\n                        atspi.atspi_action_get_n_actions(\n                            action,\n                            None\n                        )\n                    )\n                except Exception:\n                    count = 0\n\n                preferred = []\n                other = []\n\n                for index in range(max(0, count)):\n                    try:\n                        name = read_string(\n                            atspi.atspi_action_get_action_name(\n                                action,\n                                index,\n                                None\n                            )\n                        ).lower()\n                    except Exception:\n                        name = \"\"\n\n                    if any(\n                        word in name\n                        for word in (\n                            \"activate\",\n                            \"click\",\n                            \"press\",\n                            \"select\",\n                            \"switch\"\n                        )\n                    ):\n                        preferred.append(index)\n                    else:\n                        other.append(index)\n\n                for index in preferred + other:\n                    try:\n                        if atspi.atspi_action_do_action(\n                            action,\n                            index,\n                            None\n                        ):\n                            acted = True\n                            break\n                    except Exception:\n                        pass\n\n            if not acted:\n                component = atspi.atspi_accessible_get_component_iface(obj)\n\n                if component:\n                    try:\n                        acted = bool(\n                            atspi.atspi_component_grab_focus(\n                                component,\n                                None\n                            )\n                        )\n                    except Exception:\n                        acted = False\n\n    elif provider == \"AT-SPI\":\n        import gi\n        gi.require_version(\"Atspi\", \"2.0\")\n        from gi.repository import Atspi\n\n        try:\n            Atspi.init()\n        except Exception:\n            pass\n\n        desktop = Atspi.get_desktop(0)\n        obj = desktop\n        path = str(data.get(\"path\") or \"\")\n\n        for piece in path.split(\".\"):\n            if piece:\n                obj = obj.get_child_at_index(int(piece))\n\n        try:\n            action = obj.get_action_iface()\n        except Exception:\n            action = None\n\n        if action is not None:\n            try:\n                count = int(action.get_n_actions())\n            except Exception:\n                count = 0\n\n            preferred = []\n\n            for index in range(count):\n                try:\n                    name = str(action.get_action_name(index) or \"\").lower()\n                except Exception:\n                    name = \"\"\n\n                if any(word in name for word in (\n                    \"activate\", \"click\", \"press\", \"select\", \"switch\"\n                )):\n                    preferred.append(index)\n\n            order = preferred + [\n                index for index in range(count)\n                if index not in preferred\n            ]\n\n            for index in order:\n                try:\n                    if action.do_action(index):\n                        acted = True\n                        break\n                except Exception:\n                    pass\n\n        if not acted:\n            try:\n                component = obj.get_component_iface()\n                if component is not None:\n                    acted = bool(component.grab_focus())\n            except Exception:\n                pass\n\n    elif provider == \"AT-SPI-CACHE\":\n        bus_name = str(data.get(\"busName\") or \"\")\n        object_path = str(data.get(\"objectPath\") or \"\")\n\n        def first_string(raw):\n            match = re.search(\n                r\"'((?:\\\\.|[^'])*)'\",\n                str(raw or \"\")\n            )\n            if not match:\n                return \"\"\n            try:\n                return ast.literal_eval(\n                    \"'\" + match.group(1) + \"'\"\n                )\n            except Exception:\n                return match.group(1)\n\n        address_proc = subprocess.run(\n            [\n                \"gdbus\",\n                \"call\",\n                \"--session\",\n                \"--dest\",\n                \"org.a11y.Bus\",\n                \"--object-path\",\n                \"/org/a11y/bus\",\n                \"--method\",\n                \"org.a11y.Bus.GetAddress\"\n            ],\n            stdout=subprocess.PIPE,\n            stderr=subprocess.PIPE,\n            text=True,\n            timeout=1.0\n        )\n\n        address = first_string(\n            address_proc.stdout\n        )\n\n        if address and bus_name and object_path:\n            # Page tabs conventionally expose their default activate/select\n            # action at slot 0. Query action names first when possible.\n            order = []\n\n            get_actions = subprocess.run(\n                [\n                    \"gdbus\",\n                    \"call\",\n                    \"--address\",\n                    address,\n                    \"--dest\",\n                    bus_name,\n                    \"--object-path\",\n                    object_path,\n                    \"--method\",\n                    \"org.a11y.atspi.Action.GetActions\"\n                ],\n                stdout=subprocess.PIPE,\n                stderr=subprocess.PIPE,\n                text=True,\n                timeout=0.65\n            )\n\n            if get_actions.returncode == 0:\n                names = re.findall(\n                    r\"\\('([^']*)',\",\n                    get_actions.stdout\n                )\n\n                preferred = []\n                other = []\n\n                for index, name in enumerate(names):\n                    low = name.lower()\n\n                    if any(\n                        word in low\n                        for word in (\n                            \"activate\",\n                            \"click\",\n                            \"press\",\n                            \"select\",\n                            \"switch\"\n                        )\n                    ):\n                        preferred.append(index)\n                    else:\n                        other.append(index)\n\n                order = preferred + other\n\n            if not order:\n                order = [0, 1, 2, 3]\n\n            for index in order:\n                proc = subprocess.run(\n                    [\n                        \"gdbus\",\n                        \"call\",\n                        \"--address\",\n                        address,\n                        \"--dest\",\n                        bus_name,\n                        \"--object-path\",\n                        object_path,\n                        \"--method\",\n                        \"org.a11y.atspi.Action.DoAction\",\n                        str(index)\n                    ],\n                    stdout=subprocess.PIPE,\n                    stderr=subprocess.PIPE,\n                    text=True,\n                    timeout=0.65\n                )\n\n                if (\n                    proc.returncode == 0\n                    and \"true\" in proc.stdout.lower()\n                ):\n                    acted = True\n                    break\n\n            if not acted:\n                proc = subprocess.run(\n                    [\n                        \"gdbus\",\n                        \"call\",\n                        \"--address\",\n                        address,\n                        \"--dest\",\n                        bus_name,\n                        \"--object-path\",\n                        object_path,\n                        \"--method\",\n                        \"org.a11y.atspi.Component.GrabFocus\"\n                    ],\n                    stdout=subprocess.PIPE,\n                    stderr=subprocess.PIPE,\n                    text=True,\n                    timeout=0.65\n                )\n\n                acted = (\n                    proc.returncode == 0\n                    and \"true\" in proc.stdout.lower()\n                )\n\n                if not acted:\n                    error = proc.stderr.strip()\n\n    elif provider == \"AT-SPI-DBUS\":\n        bus_name = str(data.get(\"busName\") or \"\")\n        object_path = str(data.get(\"objectPath\") or \"\")\n\n        def first_string(raw):\n            match = re.search(r\"'((?:\\\\.|[^'])*)'\", str(raw or \"\"))\n            if not match:\n                return \"\"\n            try:\n                return ast.literal_eval(\"'\" + match.group(1) + \"'\")\n            except Exception:\n                return match.group(1)\n\n        address_proc = subprocess.run(\n            [\n                \"gdbus\", \"call\",\n                \"--session\",\n                \"--dest\", \"org.a11y.Bus\",\n                \"--object-path\", \"/org/a11y/bus\",\n                \"--method\", \"org.a11y.Bus.GetAddress\"\n            ],\n            stdout=subprocess.PIPE,\n            stderr=subprocess.PIPE,\n            text=True,\n            timeout=1.0\n        )\n\n        address = first_string(address_proc.stdout)\n\n        if address and bus_name and object_path:\n            # Toolkit action ordering differs. Try a few action slots, then\n            # fall back to keyboard focus.\n            for index in range(6):\n                proc = subprocess.run(\n                    [\n                        \"gdbus\", \"call\",\n                        \"--address\", address,\n                        \"--dest\", bus_name,\n                        \"--object-path\", object_path,\n                        \"--method\", \"org.a11y.atspi.Action.DoAction\",\n                        str(index)\n                    ],\n                    stdout=subprocess.PIPE,\n                    stderr=subprocess.PIPE,\n                    text=True,\n                    timeout=0.65\n                )\n\n                if proc.returncode == 0 and \"true\" in proc.stdout.lower():\n                    acted = True\n                    break\n\n            if not acted:\n                proc = subprocess.run(\n                    [\n                        \"gdbus\", \"call\",\n                        \"--address\", address,\n                        \"--dest\", bus_name,\n                        \"--object-path\", object_path,\n                        \"--method\", \"org.a11y.atspi.Component.GrabFocus\"\n                    ],\n                    stdout=subprocess.PIPE,\n                    stderr=subprocess.PIPE,\n                    text=True,\n                    timeout=0.65\n                )\n\n                acted = (\n                    proc.returncode == 0\n                    and \"true\" in proc.stdout.lower()\n                )\n\n                if not acted:\n                    error = proc.stderr.strip()\n\n    elif provider == \"KITTY\":\n        address = str(data.get(\"kittyAddress\") or \"\")\n        tab_id = data.get(\"kittyTabId\")\n\n        cmd = [\"kitty\", \"@\"]\n        if address:\n            cmd += [\"--to\", address]\n\n        cmd += [\"focus-tab\", \"--match\", \"id:\" + str(tab_id)]\n\n        proc = subprocess.run(\n            cmd,\n            stdout=subprocess.DEVNULL,\n            stderr=subprocess.PIPE,\n            text=True,\n            timeout=2.0\n        )\n        acted = proc.returncode == 0\n\n        if not acted:\n            error = proc.stderr.strip()\n\n    elif provider == \"DEVTOOLS\":\n        port = int(data.get(\"debugPort\") or 0)\n        target_id = str(data.get(\"targetId\") or \"\")\n\n        req = urllib.request.Request(\n            \"http://127.0.0.1:%d/json/activate/%s\" % (port, target_id),\n            method=\"PUT\"\n        )\n\n        with urllib.request.urlopen(req, timeout=1.0) as response:\n            response.read()\n\n        acted = True\n\nexcept Exception as exc:\n    error = str(exc)\n\nprint(json.dumps({\"ok\": acted, \"error\": error}))\n";
    }

    function refreshAppTabs() {
        // The persistent libatspi process continuously publishes live
        // snapshots. The old scanner remains only as a fallback if that
        // bridge could not start.
        if (appTabsBridgeReady)
            return;

        if (appTabsProcess.running)
            return;

        if (appTabs.length === 0
                && appTabsError.length === 0)
            appTabsLoading = true;

        appTabsProcess.exec([
            "/usr/bin/python3",
            "-c",
            appTabScanScript()
        ]);
    }

    function activateAppTab(entry) {
        if (!entry || !entry._tabRecord || entry._tabUnavailable)
            return;

        appTabsActivateProcess.exec([
            "/usr/bin/python3",
            "-c",
            appTabActivateScript(),
            String(entry.provider || ""),
            JSON.stringify(entry)
        ]);

        menuOpen = false;
    }

    Process {
        id: appTabsProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const payload = JSON.parse(text || "{}");
                    const nextTabs =
                        Array.isArray(payload.tabs)
                        ? payload.tabs
                        : [];

                    // Do not throw away a good tab list because one refresh
                    // raced an app rebuilding its accessibility tree.
                    if (nextTabs.length > 0
                            || appControlWindow.appTabs.length === 0)
                        appControlWindow.updateAppTabsStable(nextTabs);

                    appControlWindow.appTabsError =
                        String(payload.error || "");

                    if (Array.isArray(payload.diagnostics)) {
                        const diagnosticRows =
                            payload.diagnostics.map(function(value) {
                                return String(value || "");
                            });
                        const diagnosticText =
                            diagnosticRows.join(" • ");

                        if (diagnosticText
                                !== appControlWindow.appTabsDiagnosticsSignature) {
                            appControlWindow.appTabsDiagnosticsSignature =
                                diagnosticText;
                            appControlWindow.appTabsDiagnostics =
                                diagnosticRows;
                        }
                    }
                } catch (error) {
                    appControlWindow.appTabsError =
                        "TAB SCAN PARSE: " + String(error);
                }

                appControlWindow.appTabsLoading = false;
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = String(text || "").trim();

                if (message.length > 0)
                    appControlWindow.appTabsError = message;

                appControlWindow.appTabsLoading = false;
            }
        }
    }

    Process {
        id: appTabsActivateProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const message = String(text || "").trim();

                if (message.length > 0)
                    console.log("AppControl: tab activation:", message);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = String(text || "").trim();

                if (message.length > 0)
                    console.log("AppControl: tab activation error:", message);
            }
        }
    }

    Timer {
        id: appTabsWarmRefreshTimer

        interval: 850
        repeat: false

        onTriggered: {
            if (appControlWindow.menuOpen
                    && appControlWindow.selectedModeIndex
                       === appControlWindow.windowsModeIndex
                    && appControlWindow.windowListMode
                       === appControlWindow.windowListTabs)
                appControlWindow.refreshAppTabs();
        }
    }

    Timer {
        id: appTabsSecondWarmRefreshTimer

        interval: 1800
        repeat: false

        onTriggered: {
            if (appControlWindow.menuOpen
                    && appControlWindow.selectedModeIndex
                       === appControlWindow.windowsModeIndex
                    && appControlWindow.windowListMode
                       === appControlWindow.windowListTabs)
                appControlWindow.refreshAppTabs();
        }
    }

    Timer {
        id: appTabsRefreshTimer

        interval: 2200
        repeat: true

        running:
            appControlWindow.menuOpen
            && appControlWindow.selectedModeIndex
               === appControlWindow.windowsModeIndex
            && appControlWindow.windowListMode
               === appControlWindow.windowListTabs
            && !appControlWindow.appTabsBridgeReady

        onTriggered: appControlWindow.refreshAppTabs()
    }

    // WINDOWS audio control. A Sway window can own zero, one, or several
    // PipeWire/PulseAudio sink-input streams, so keep the resolved indexes.
    property var windowAudioSinkInputs: []
    property bool windowAudioAvailable: false
    property bool windowAudioMuted: false
    property bool windowAudioPolicyActive: false
    property string windowAudioProbeWindowKey: ""

    // Session-level future-stream mute policies, keyed by the live Sway
    // window identity. This lets MUTE work even before that window starts
    // producing audio. Policies are pruned automatically when the window
    // disappears from the Sway tree.
    property var windowAudioMutePolicies: ({})

    property var selectedAppWindows: {
        if (!selectedResultIsApplication())
            return [];

        return windowsForApp(selectedResult());
    }

    // ============================================================
    // MODE DATA
    // ============================================================

    property var modes: [
        {
            name: "FAVORITES",
            symbol: "(˵✧ᴗ✧˵)"
        },
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
            name: "THERMAL",
            symbol: "🌡"
        },
        {
            name: "KILL",
            symbol: "(-_•)︻デ═一"
        },
        {
            name: "SYSTEM",
            symbol: "🖳"
        }
    ]

    function favoritesFilterAccent(modeIndex) {
        if (modeIndex === favoritesFilterAll)
            return Colors.magenta;
        if (modeIndex === systemModeIndex)
            return Colors.white;
        if (modeIndex === killModeIndex)
            return Colors.red;
        if (modeIndex === runModeIndex)
            return Colors.yellow;
        if (modeIndex === windowsModeIndex)
            return Colors.omnitrix;
        if (modeIndex === thermalModeIndex)
            return Colors.orange;
        return Colors.cyan;
    }

    function favoritesFilterSymbol(modeIndex) {
        if (modeIndex === favoritesFilterAll)
            return modes[favoritesModeIndex].symbol;
        if (modeIndex === killModeIndex)
            return "⌐╦╾━";
        if (modeIndex >= 0 && modeIndex < modes.length)
            return modes[modeIndex].symbol;
        return "✦";
    }

    function setFavoritesFilterMode(modeIndex) {
        const allowed = [
            favoritesFilterAll, appsModeIndex, runModeIndex, windowsModeIndex,
            thermalModeIndex, killModeIndex, systemModeIndex
        ];
        favoritesFilterMode = allowed.indexOf(modeIndex) >= 0
                              ? modeIndex : favoritesFilterAll;
        keyboardActive = true;
        hoveredResultIndex = -1;
        detailFocused = false;
        resetResultSelection();
        resetDetailActionSelection();
    }

    function combiSearchTextForRecord(record) {
        if (!record)
            return "";
        const source = favoriteSourceItem(record) || record;
        return ((record.name || "") + " "
                + (record.genericName || "") + " "
                + (record.comment || "") + " "
                + (record.keywords || "") + " "
                + (source.args || "") + " "
                + (source.commandText || "") + " "
                + (source.appName || "") + " "
                + (source.windowName || "") + " "
                + (source.tabTitle || "") + " "
                + (source.category || "") + " "
                + (source.role || "") + " "
                + (source.metric || "") + " "
                + String(source.pid || "")).toLowerCase();
    }

    function prepareCombiRecord(record) {
        if (!record)
            return null;
        record._combiSearchText = combiSearchTextForRecord(record);
        return record;
    }

    function rebuildCombiStaticCatalog() {
        const rows = [];
        const seen = ({});

        function pushUnique(record) {
            record = appControlWindow.prepareCombiRecord(record);
            if (!record)
                return;
            const key = String(record._favoriteKey || record.id || record.name || "");
            if (!key || seen[key])
                return;
            seen[key] = true;
            rows.push(record);
        }

        const apps = [...DesktopEntries.applications.values];
        for (let i = 0; i < apps.length; i++)
            pushUnique(appControlWindow.favoriteRecordForApp(apps[i]));

        for (let i = 0; i < appControlWindow.runAllCommands.length; i++) {
            pushUnique(appControlWindow.favoriteRecordForRunCommand(
                appControlWindow.runAllCommands[i],
                appControlWindow.runPrefixNormal
            ));
        }

        for (let i = 0; i < appControlWindow.runHistory.length; i++) {
            const item = appControlWindow.runHistory[i];
            const commandText = typeof item === "object" ? item.commandText : item;
            const prefixMode = typeof item === "object"
                               ? item.prefixMode : appControlWindow.runPrefixNormal;
            pushUnique(appControlWindow.favoriteRecordForRunCommand(
                commandText, prefixMode
            ));
        }

        for (let i = 0; i < appControlWindow.swayWindows.length; i++) {
            pushUnique(appControlWindow.favoriteRecordForModeItem(
                appControlWindow.swayWindows[i], appControlWindow.windowsModeIndex
            ));
        }

        for (let i = 0; i < appControlWindow.appTabs.length; i++) {
            const tab = appControlWindow.appTabs[i];
            if (!tab || tab._tabUnavailable)
                continue;
            pushUnique(appControlWindow.favoriteRecordForModeItem(
                tab, appControlWindow.windowsModeIndex
            ));
        }

        const thermalItems = appControlWindow.thermalRows.concat(appControlWindow.fanRows);
        for (let i = 0; i < thermalItems.length; i++) {
            pushUnique(appControlWindow.favoriteRecordForModeItem(
                thermalItems[i], appControlWindow.thermalModeIndex
            ));
        }

        for (let i = 0; i < appControlWindow.systemRows.length; i++) {
            pushUnique(appControlWindow.favoriteRecordForModeItem(
                appControlWindow.systemRows[i], appControlWindow.systemModeIndex
            ));
        }

        rows.sort(function(a, b) {
            const modeCompare = Number(a._sourceModeIndex || 0)
                                - Number(b._sourceModeIndex || 0);
            if (modeCompare !== 0)
                return modeCompare;
            return String(a.name || "").localeCompare(String(b.name || ""));
        });
        const structureSignature = JSON.stringify(
            rows.map(function(entry) {
                return [
                    Number(entry._sourceModeIndex || -1),
                    String(entry.id || entry._favoriteKey || ""),
                    String(entry.name || "")
                ];
            })
        );

        // Thermal/system telemetry changes frequently, but the COMBI list
        // structure usually does not. Avoid replacing the ScriptModel for
        // metric-only refreshes, which was the main source of wheel-scroll
        // jumps while browsing deep in COMBI.
        if (structureSignature === combiStaticStructureSignature
                && combiStaticCatalog.length > 0) {
            combiStaticCatalogDirty = false;
            return;
        }

        const state =
            selectedModeIndex === favoritesModeIndex
            && favoritesScopeMode === favoritesScopeCombi
            ? captureResultListState()
            : null;

        combiStaticStructureSignature = structureSignature;
        combiStaticCatalog = rows;
        combiStaticCatalogDirty = false;

        if (state)
            restoreResultListState(state);
    }

    function rebuildCombiTaskCatalog() {
        const rows = [];
        const seen = ({});
        const identities = [];

        for (let i = 0; i < taskRows.length; i++) {
            const task = taskRows[i];
            const identity = taskPersistentIdentity(task);
            if (!identity || seen[identity])
                continue;

            seen[identity] = true;
            identities.push(identity);

            const record = prepareCombiRecord(
                favoriteRecordForTaskIdentity(identity, task)
            );
            if (record)
                rows.push(record);
        }

        identities.sort();
        const signature = identities.join("\\n");

        // Metric values change continuously, but those changes do not alter
        // the COMBI row order. Only rebuild when the process identity set
        // changes; selected process details resolve against live taskRows.
        if (signature === combiTaskIdentitySignature
                && combiTaskCatalog.length > 0)
            return;

        const state =
            selectedModeIndex === favoritesModeIndex
            && favoritesScopeMode === favoritesScopeCombi
            ? captureResultListState()
            : null;

        rows.sort(function(a, b) {
            return String(a.name || "").localeCompare(String(b.name || ""));
        });

        combiTaskIdentitySignature = signature;
        combiTaskCatalog = rows;

        if (state)
            restoreResultListState(state);
    }

    function scheduleCombiStaticCatalogRefresh() {
        combiStaticCatalogDirty = true;
        if (favoritesScopeMode !== favoritesScopeCombi
                || selectedModeIndex !== favoritesModeIndex)
            return;
        combiStaticCatalogRefreshTimer.restart();
    }

    function scheduleCombiTaskCatalogRefresh() {
        if (favoritesScopeMode !== favoritesScopeCombi
                || selectedModeIndex !== favoritesModeIndex)
            return;
        if (!combiTaskCatalogRefreshTimer.running)
            combiTaskCatalogRefreshTimer.start();
    }

    function ensureCombiCatalog() {
        if (combiStaticCatalogDirty || combiStaticCatalog.length === 0)
            combiStaticCatalogRefreshTimer.restart();
        if (combiTaskCatalog.length === 0)
            rebuildCombiTaskCatalog();
    }

    Timer {
        id: combiStaticCatalogRefreshTimer
        interval: 90
        repeat: false
        onTriggered: {
            if (appControlWindow.favoritesScopeMode === appControlWindow.favoritesScopeCombi)
                appControlWindow.rebuildCombiStaticCatalog();
        }
    }

    Timer {
        id: combiTaskCatalogRefreshTimer
        interval: 700
        repeat: false
        onTriggered: {
            if (appControlWindow.favoritesScopeMode === appControlWindow.favoritesScopeCombi)
                appControlWindow.rebuildCombiTaskCatalog();
        }
    }

    function setFavoritesScopeMode(scopeMode) {
        favoritesScopeMode =
            scopeMode === favoritesScopeCombi
            ? favoritesScopeCombi
            : favoritesScopeFavorites;

        keyboardActive = true;
        hoveredResultIndex = -1;
        detailFocused = false;

        // COMBI intentionally reaches across providers, so prime the data
        // sources that are otherwise only refreshed inside their own modes.
        if (favoritesScopeMode === favoritesScopeCombi) {
            ensureCombiCatalog();
            refreshRunAllCommands(false);
            refreshWindowState();
            refreshKillMonitor();
            refreshTaskManager();
        } else if (hasTaskFavorites()) {
            refreshTaskManager();
        }

        resetResultSelection();
        resetDetailActionSelection();
        searchInput.forceActiveFocus();
    }

    function cycleFavoritesFilter(direction) {
        const order = [
            favoritesFilterAll, appsModeIndex, runModeIndex, windowsModeIndex,
            thermalModeIndex, killModeIndex, systemModeIndex
        ];
        let index = order.indexOf(favoritesFilterMode);
        if (index < 0) index = 0;
        index = (index + direction + order.length) % order.length;
        setFavoritesFilterMode(order[index]);
    }

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
    // RUN MODE
    // ============================================================
    //
    // RUN uses the shared selector/search field as a command input. The
    // current typed command becomes the first result, followed by matching
    // saved favorites and recent in-memory history. Only commands explicitly
    // favorited are persisted; ordinary command history is session-local.
    // Commands are executed detached
    // through the user's login shell so pipes, redirects, variables, etc.
    // work as expected.
    //
    // Favorite RUN commands are encoded directly into favoriteKeys using:
    //
    //     run:<encodeURIComponent(command)>
    //
    // That makes RUN favorites reconstructable after a Quickshell restart
    // without introducing a second favorite database.

    property var modeInputTexts: ({})
    property var runHistory: []
    readonly property int runHistoryLimit: 40

    // Conditional RUN termination action.
    //
    // The KILL button is deliberately conservative: it only appears when
    // the selected command has a simple executable name that we can map to
    // an exact process name AND a matching process is currently running.
    // This avoids offering a destructive action for shell pipelines,
    // interpreters, wrappers, services, etc. where "kill this command"
    // would be ambiguous.
    property string runKillProbeTarget: ""
    property string runKillResolvedTarget: ""
    property var runKillPids: []
    property bool runKillAvailable: false

    // RUN prefix selector.
    //
    // NORMAL  executes the entered command as-is.
    // KITTY   launches the command through Kitty.
    // TOOLBOX launches Kitty, enters the default Toolbox container, executes
    //         the command there, then leaves an interactive shell open.
    readonly property int runPrefixNormal: 0
    readonly property int runPrefixKitty: 1
    readonly property int runPrefixToolbox: 2
    property int runPrefixMode: runPrefixNormal

    // RUN list selector.
    //
    // USER = the uncluttered mode we already had:
    //        exact typed command + RUN favorites + session history.
    //
    // ALL  = a Rofi-run-style catalog of executable command names found
    //        in the user's current $PATH. This lives in a separate view so
    //        thousands of commands never clutter USER/history mode.
    readonly property int runListUser: 0
    readonly property int runListTerminal: 1
    readonly property int runListAll: 2
    property int runListMode: runListUser

    property var runTerminalHistory: []
    property bool runTerminalHistoryLoaded: false
    property bool runTerminalHistoryLoading: false
    property string runTerminalHistoryError: ""

    property var runAllCommands: []
    property bool runAllCommandsLoaded: false
    property bool runAllCommandsLoading: false
    property string runAllCommandsError: ""

    function runKillTargetForCommand(command) {
        const candidates = runKillCandidatesForCommand(command);
        return candidates.length > 0 ? candidates[0] : "";
    }

    function runKillCandidatesForCommand(command) {
        const normalized = String(command || "").trim();

        if (!normalized)
            return [];

        // Only inspect a simple leading executable token. Complex shell
        // syntax remains intentionally ineligible for a destructive action.
        const match = normalized.match(
            /^([A-Za-z0-9_./+@%:-]+)(?:\s|$)/
        );

        if (!match || !match[1])
            return [];

        let executable = String(match[1]);
        const slash = executable.lastIndexOf("/");

        if (slash >= 0)
            executable = executable.slice(slash + 1);

        if (!executable)
            return [];

        const blocked = {
            "sudo": true,
            "doas": true,
            "env": true,
            "exec": true,
            "sh": true,
            "bash": true,
            "zsh": true,
            "fish": true,
            "python": true,
            "python3": true,
            "perl": true,
            "ruby": true,
            "node": true,
            "java": true,
            "kitty": true,
            "flatpak": true,
            "systemctl": true,
            "swaymsg": true,
            "kill": true,
            "pkill": true,
            "pgrep": true
        };

        if (blocked[executable])
            return [];

        const candidates = [];

        function addCandidate(value) {
            const candidate = String(value || "").trim();

            if (!candidate || blocked[candidate])
                return;

            if (candidates.indexOf(candidate) === -1)
                candidates.push(candidate);
        }

        addCandidate(executable);

        // Common launcher/wrapper suffixes often disappear once the real
        // process starts. Keep progressively simpler equivalents so e.g.
        // brave-browser-stable can match brave.
        const suffixes = [
            "-stable",
            "-beta",
            "-dev",
            "-bin"
        ];

        let simplified = executable;

        for (let i = 0; i < suffixes.length; i++) {
            const suffix = suffixes[i];

            if (simplified.endsWith(suffix)) {
                simplified =
                    simplified.slice(0, -suffix.length);
                addCandidate(simplified);
                break;
            }
        }

        if (simplified.endsWith("-browser")) {
            addCandidate(
                simplified.slice(
                    0,
                    -"-browser".length
                )
            );
        }

        // A few common wrapper -> real-process equivalents.
        const aliases = {
            "brave-browser-stable": ["brave-browser", "brave"],
            "brave-browser": ["brave"],
            "google-chrome-stable": ["google-chrome", "chrome"],
            "google-chrome": ["chrome"],
            "chromium-browser": ["chromium"]
        };

        const mapped = aliases[executable] || [];

        for (let i = 0; i < mapped.length; i++)
            addCandidate(mapped[i]);

        return candidates;
    }

    function currentRunKillTarget() {
        const candidates = currentRunKillCandidates();
        return candidates.length > 0 ? candidates[0] : "";
    }

    function currentRunKillCandidates() {
        if (!selectedResultIsRun())
            return [];

        const entry = selectedResult();
        const sourceEntry = favoriteSourceItem(entry) || entry;

        return runKillCandidatesForCommand(
            runCommandText(sourceEntry)
        );
    }

    function scheduleRunKillProbe() {
        runKillAvailable = false;
        runKillProbeTarget = "";
        runKillResolvedTarget = "";
        runKillPids = [];

        if (!menuOpen || !selectedResultIsRun())
            return;

        runKillProbeTimer.restart();
    }

    function executeRunKillAction() {
        if (!runKillAvailable || runKillPids.length === 0)
            return;

        const argv = [
            "/usr/bin/kill",
            "-TERM",
            "--"
        ];

        for (let i = 0; i < runKillPids.length; i++)
            argv.push(String(runKillPids[i]));

        console.log(
            "AppControl: RUN TERMINATE",
            runKillResolvedTarget,
            "PIDs:",
            runKillPids.join(", ")
        );

        // TERM is deliberate. FORCE/SIGKILL belongs in the dedicated KILL
        // mode rather than this contextual RUN action.
        Quickshell.execDetached(argv);

        // Keep AppControl open after terminating the target. Re-probe shortly
        // afterward so the KILL button can update to [NO TARGET] once the
        // process actually exits.
        runKillRefreshTimer.restart();
    }

    Timer {
        id: runKillRefreshTimer

        interval: 350
        repeat: false

        onTriggered: {
            appControlWindow.scheduleRunKillProbe();
        }
    }

    Timer {
        id: runKillProbeTimer

        interval: 70
        repeat: false

        onTriggered: {
            const candidates =
                appControlWindow.currentRunKillCandidates();

            appControlWindow.runKillAvailable = false;
            appControlWindow.runKillPids = [];
            appControlWindow.runKillResolvedTarget = "";
            appControlWindow.runKillProbeTarget =
                candidates.join("\u0000");

            if (candidates.length === 0)
                return;

            // Use ps rather than pgrep -x. Linux process `comm` names can be
            // truncated and wrapper commands frequently exec a differently
            // named binary, which is why the previous probe never exposed
            // KILL for commands such as brave-browser-stable.
            runKillProbeProcess.exec([
                "/usr/bin/ps",
                "-eo",
                "pid=,comm=,args="
            ]);
        }
    }

    Process {
        id: runKillProbeProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const candidates =
                    appControlWindow.currentRunKillCandidates();
                const signature = candidates.join("\u0000");

                // Selection changed while ps was running.
                if (!signature
                        || signature
                           !== appControlWindow.runKillProbeTarget) {
                    appControlWindow.runKillAvailable = false;
                    appControlWindow.runKillPids = [];
                    appControlWindow.runKillResolvedTarget = "";
                    return;
                }

                const pids = [];
                let resolvedTarget = "";
                const lines = String(text || "").split("\n");

                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i];

                    // pid, comm, then the complete command line.
                    const match = line.match(
                        /^\s*([0-9]+)\s+(\S+)\s+(.*)$/
                    );

                    if (!match)
                        continue;

                    const pid = Number(match[1]);
                    const comm = String(match[2] || "");
                    const args = String(match[3] || "").trim();

                    if (!pid || !args)
                        continue;

                    // Match more than just argv[0]. Shell scripts
                    // commonly appear as:
                    //
                    //   zsh /path/to/pipes.sh
                    //   bash ./script.sh
                    //
                    // so the real process `comm` is zsh/bash even though the
                    // RUN command the user selected is pipes.sh. Inspect every
                    // argv token and compare its basename to the candidate.
                    const argvTokens = args.split(/\s+/);
                    const argBases = [];

                    for (let a = 0; a < argvTokens.length; a++) {
                        const token = String(argvTokens[a] || "");

                        if (!token)
                            continue;

                        const slash = token.lastIndexOf("/");
                        const base =
                            slash >= 0
                            ? token.slice(slash + 1)
                            : token;

                        if (base)
                            argBases.push(base);
                    }

                    for (let c = 0; c < candidates.length; c++) {
                        const candidate = candidates[c];

                        if (comm === candidate
                                || argBases.indexOf(candidate) !== -1) {
                            if (pids.indexOf(pid) === -1)
                                pids.push(pid);

                            if (!resolvedTarget)
                                resolvedTarget = candidate;

                            break;
                        }
                    }
                }

                appControlWindow.runKillPids = pids;
                appControlWindow.runKillResolvedTarget =
                    resolvedTarget;
                appControlWindow.runKillAvailable =
                    pids.length > 0;

                console.log(
                    "AppControl: RUN kill probe",
                    "candidates=" + candidates.join(","),
                    "resolved=" + resolvedTarget,
                    "pids=" + pids.join(",")
                );
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) {
                    console.log(
                        "AppControl: RUN kill probe:",
                        text.trim()
                    );
                }
            }
        }
    }

    function runShellPath() {
        const shell = Quickshell.env("SHELL");
        return shell && String(shell).length > 0
               ? String(shell)
               : "/bin/sh";
    }

    function runShellName() {
        const shell = runShellPath();
        const parts = shell.split("/");
        return parts.length > 0 ? parts[parts.length - 1] : shell;
    }

    function runCommandText(entry) {
        if (!entry)
            return "";

        if (entry.commandText !== undefined)
            return String(entry.commandText || "").trim();

        if (typeof entry.command === "string")
            return String(entry.command).trim();

        return String(entry.label || entry.name || "").trim();
    }

    function normalizeRunPrefixMode(prefixMode) {
        if (Number(prefixMode) === runPrefixToolbox)
            return runPrefixToolbox;

        if (Number(prefixMode) === runPrefixKitty)
            return runPrefixKitty;

        return runPrefixNormal;
    }

    function runPrefixModeForEntry(entry) {
        if (entry && entry._runPrefixMode !== undefined)
            return normalizeRunPrefixMode(entry._runPrefixMode);

        return runPrefixNormal;
    }

    function runPrefixName(prefixMode) {
        const resolved = normalizeRunPrefixMode(prefixMode);

        if (resolved === runPrefixToolbox)
            return "TOOLBOX";

        if (resolved === runPrefixKitty)
            return "KITTY";

        return "NORMAL";
    }

    function runPrefixSymbol(prefixMode) {
        const resolved = normalizeRunPrefixMode(prefixMode);

        if (resolved === runPrefixToolbox)
            return "TOOLBOX";

        if (resolved === runPrefixKitty)
            return "≽(^•⩊•^)≼";

        return modes[runModeIndex].symbol;
    }

    function runEffectiveCommand(command, prefixMode) {
        const normalized = String(command || "").trim();

        if (!normalized)
            return "";

        if (normalizeRunPrefixMode(prefixMode) === runPrefixKitty) {
            // Start Kitty with a unique socket-only remote-control endpoint so
            // the TABS provider can enumerate/focus its real Kitty tabs.
            const kittyPrefix =
                "kitty "
                + "-o allow_remote_control=socket-only "
                + "--listen-on unix:@appcontrol-kitty-$$ ";

            if (normalized === "kitty")
                return kittyPrefix.trim();

            if (normalized.indexOf("kitty ") === 0)
                return normalized;

            return kittyPrefix + normalized;
        }

        return normalized;
    }

    function runFavoriteKey(command, prefixMode) {
        const normalized = String(command || "").trim();

        if (!normalized)
            return "";

        // Keep the old normal-command key format for backward compatibility.
        // Alternate launch environments get their own namespaces so the same
        // raw command can be favorited independently.
        const resolved = normalizeRunPrefixMode(prefixMode);

        if (resolved === runPrefixToolbox)
            return "run:toolbox:" + encodeURIComponent(normalized);

        if (resolved === runPrefixKitty)
            return "run:kitty:" + encodeURIComponent(normalized);

        return "run:" + encodeURIComponent(normalized);
    }

    function runFavoriteDataFromKey(key) {
        const raw = String(key || "");

        if (raw.indexOf("run:") !== 0)
            return null;

        let prefixMode = runPrefixNormal;
        let encoded = raw.slice(4);

        if (raw.indexOf("run:toolbox:") === 0) {
            prefixMode = runPrefixToolbox;
            encoded = raw.slice(12);
        } else if (raw.indexOf("run:kitty:") === 0) {
            prefixMode = runPrefixKitty;
            encoded = raw.slice(10);
        }

        try {
            const command = decodeURIComponent(encoded);

            if (!command)
                return null;

            return {
                commandText: command,
                prefixMode: prefixMode
            };
        } catch (error) {
            console.log("AppControl: invalid RUN favorite key:", raw);
            return null;
        }
    }

    function runFavoriteCommandFromKey(key) {
        const data = runFavoriteDataFromKey(key);
        return data ? data.commandText : "";
    }

    function runRecord(command, origin, prefixMode) {
        const normalized = String(command || "").trim();
        const resolvedPrefix = normalizeRunPrefixMode(prefixMode);

        return {
            _runRecord: true,
            _runOrigin: origin || "COMMAND",
            _runPrefixMode: resolvedPrefix,

            id: runFavoriteKey(normalized, resolvedPrefix),
            label: normalized,
            name: normalized,
            commandText: normalized,
            genericName: "RUN COMMAND",
            comment: (origin || "COMMAND")
                     + " • "
                     + runPrefixName(resolvedPrefix)
                     + " • "
                     + runShellName().toUpperCase(),
            keywords: "",
            icon: "",
            actions: [],
            startupClass: ""
        };
    }

    function rememberRunHistory(command, prefixMode) {
        const normalized = String(command || "").trim();
        const resolvedPrefix = normalizeRunPrefixMode(prefixMode);

        if (!normalized)
            return;

        const next = [];

        next.push({
            commandText: normalized,
            prefixMode: resolvedPrefix
        });

        for (let i = 0; i < runHistory.length; i++) {
            const existing = runHistory[i];

            const existingCommand =
                typeof existing === "object"
                ? String(existing.commandText || "").trim()
                : String(existing || "").trim();

            const existingPrefix =
                typeof existing === "object"
                ? normalizeRunPrefixMode(existing.prefixMode)
                : runPrefixNormal;

            if (!existingCommand)
                continue;

            if (existingCommand === normalized
                    && existingPrefix === resolvedPrefix)
                continue;

            next.push({
                commandText: existingCommand,
                prefixMode: existingPrefix
            });

            if (next.length >= runHistoryLimit)
                break;
        }

        runHistory = next;
    }

    function executeRunCommand(command, prefixMode) {
        const normalized = String(command || "").trim();
        const resolvedPrefix = normalizeRunPrefixMode(prefixMode);

        if (!normalized)
            return;

        rememberRunHistory(normalized, resolvedPrefix);

        if (resolvedPrefix === runPrefixToolbox) {
            // Use toolbox run instead of trying to type into an interactive
            // `toolbox enter` session. Kitty opens first, the command executes
            // inside the default Toolbox, and an interactive Bash shell stays
            // open in that same Toolbox afterward.
            const toolboxCommand =
                normalized + "; exec bash";

            console.log(
                "AppControl: RUN [TOOLBOX]",
                normalized
            );

            Quickshell.execDetached([
                "kitty",
                "--title",
                "Toolbox",
                "toolbox",
                "run",
                "bash",
                "-lc",
                toolboxCommand
            ]);

            menuOpen = false;
            return;
        }

        const effectiveCommand =
            runEffectiveCommand(normalized, resolvedPrefix);

        console.log(
            "AppControl: RUN",
            "[" + runPrefixName(resolvedPrefix) + "]",
            runShellPath(),
            "-lc",
            effectiveCommand
        );

        Quickshell.execDetached([
            runShellPath(),
            "-lc",
            effectiveCommand
        ]);

        menuOpen = false;
    }

    function shellQuote(value) {
        // POSIX-safe single-quote escaping for the small Sway/Kitty wrapper
        // used by the FLOAT alternate action.
        return "'" + String(value || "").replace(/'/g, "'\"'\"'") + "'";
    }

    function executeRunFloatCommand(command) {
        const normalized = String(command || "").trim();

        if (!normalized)
            return;

        rememberRunHistory(normalized, runPrefixKitty);

        // Give every floating launch its own app_id so the temporary Sway
        // rule only applies to this one Kitty window.
        const floatAppId =
            "appcontrol-float-" + String(Date.now());

        const swayCriteria =
            '[app_id="' + floatAppId + '"]';

        const swayRule =
            "for_window "
            + swayCriteria
            + " floating enable, move position center";

        const script =
            "swaymsg "
            + shellQuote(swayRule)
            + " >/dev/null 2>&1; "
            + "exec kitty"
            + " -o allow_remote_control=socket-only"
            + " --listen-on "
            + shellQuote("unix:@appcontrol-kitty-" + stamp)
            + " --class "
            + shellQuote(floatAppId)
            + " --title "
            + shellQuote("Float")
            + " "
            + shellQuote(runShellPath())
            + " -lc "
            + shellQuote(normalized);

        console.log(
            "AppControl: RUN FLOAT",
            normalized,
            "app_id:",
            floatAppId
        );

        Quickshell.execDetached([
            runShellPath(),
            "-lc",
            script
        ]);

        menuOpen = false;
    }

    function executeRunFullscreenCommand(command) {
        const normalized = String(command || "").trim();

        if (!normalized)
            return;

        rememberRunHistory(normalized, runPrefixKitty);

        // Unique app_id lets Sway target only this Kitty instance.
        const fullscreenAppId =
            "appcontrol-fullscreen-" + String(Date.now());

        const swayCriteria =
            '[app_id="' + fullscreenAppId + '"]';

        const swayRule =
            "for_window "
            + swayCriteria
            + " fullscreen enable";

        const script =
            "swaymsg "
            + shellQuote(swayRule)
            + " >/dev/null 2>&1; "
            + "exec kitty"
            + " --class "
            + shellQuote(fullscreenAppId)
            + " --title "
            + shellQuote("Fullscreen")
            + " "
            + shellQuote(runShellPath())
            + " -lc "
            + shellQuote(normalized);

        console.log(
            "AppControl: RUN FULLSCREEN",
            normalized,
            "app_id:",
            fullscreenAppId
        );

        Quickshell.execDetached([
            runShellPath(),
            "-lc",
            script
        ]);

        menuOpen = false;
    }

    function setRunPrefixMode(prefixMode) {
        const nextMode = normalizeRunPrefixMode(prefixMode);

        if (runPrefixMode === nextMode)
            return;

        runPrefixMode = nextMode;

        // Rebuild the typed-command row with the new prefix identity while
        // keeping the user's input text untouched.
        Qt.callLater(function() {
            if (selectedModeIndex === runModeIndex) {
                resetResultSelection();
                resetDetailActionSelection();
                searchInput.forceActiveFocus();
            }
        });
    }

    function consumeRunTerminalHistory(output) {
        const lines = String(output || "").split("\n");
        const rows = [];

        for (let i = 0; i < lines.length; i++) {
            const command = String(lines[i] || "").trim();

            if (!command)
                continue;

            rows.push(command);
        }

        runTerminalHistory = rows;
        runTerminalHistoryLoaded = true;
        runTerminalHistoryLoading = false;
        runTerminalHistoryError = "";

        console.log(
            "AppControl: loaded",
            rows.length,
            "recent terminal-history rows"
        );

        if (selectedModeIndex === runModeIndex
                && runListMode === runListTerminal) {
            Qt.callLater(function() {
                resetResultSelection();
                resetDetailActionSelection();
            });
        }
    }

    function refreshRunTerminalHistory() {
        if (runTerminalHistoryLoading)
            return;

        runTerminalHistoryLoading = true;
        runTerminalHistoryError = "";

        // Read the user's real shell history rather than mixing it into the
        // AppControl USER-session history. Output is newest-first.
        //
        // Supported directly:
        //   bash -> ~/.bash_history (or $HISTFILE)
        //   zsh  -> ~/.zsh_history  (or $HISTFILE), including extended format
        //   fish -> fish_history YAML-ish "- cmd:" rows
        //
        // Unknown shells fall back to the common bash/zsh files when present.
        const historyScript =
            "shell=${SHELL##*/}; "
            + "case \"$shell\" in "
            + "fish) "
            + "  f=\"$HOME/.local/share/fish/fish_history\"; "
            + "  if [ -r \"$f\" ]; then "
            + "    sed -n 's/^- cmd: //p' \"$f\" | tail -n 800 | tac; "
            + "  fi; "
            + "  ;; "
            + "zsh) "
            + "  f=\"${HISTFILE:-$HOME/.zsh_history}\"; "
            + "  if [ -r \"$f\" ]; then "
            + "    tail -n 800 \"$f\" "
            + "      | sed -E 's/^: [0-9]+:[0-9]+;//' "
            + "      | tac; "
            + "  fi; "
            + "  ;; "
            + "bash) "
            + "  f=\"${HISTFILE:-$HOME/.bash_history}\"; "
            + "  if [ -r \"$f\" ]; then "
            + "    tail -n 800 \"$f\" "
            + "      | sed -E '/^#[0-9]{9,}$/d' "
            + "      | tac; "
            + "  fi; "
            + "  ;; "
            + "*) "
            + "  if [ -n \"$HISTFILE\" ] && [ -r \"$HISTFILE\" ]; then "
            + "    tail -n 800 \"$HISTFILE\" "
            + "      | sed -E 's/^: [0-9]+:[0-9]+;//; /^#[0-9]{9,}$/d' "
            + "      | tac; "
            + "  elif [ -r \"$HOME/.zsh_history\" ]; then "
            + "    tail -n 800 \"$HOME/.zsh_history\" "
            + "      | sed -E 's/^: [0-9]+:[0-9]+;//' "
            + "      | tac; "
            + "  elif [ -r \"$HOME/.bash_history\" ]; then "
            + "    tail -n 800 \"$HOME/.bash_history\" "
            + "      | sed -E '/^#[0-9]{9,}$/d' "
            + "      | tac; "
            + "  fi; "
            + "  ;; "
            + "esac";

        runTerminalHistoryProcess.exec([
            "/bin/sh",
            "-lc",
            historyScript
        ]);
    }

    Process {
        id: runTerminalHistoryProcess

        stdout: StdioCollector {
            onStreamFinished: {
                appControlWindow.consumeRunTerminalHistory(text);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();

                if (message.length > 0) {
                    appControlWindow.runTerminalHistoryError = message;
                    console.log(
                        "AppControl: terminal history:",
                        message
                    );
                }

                appControlWindow.runTerminalHistoryLoading = false;
            }
        }
    }

    function consumeRunAllCommands(output) {
        const lines = String(output || "").split("\n");
        const rows = [];
        const seen = {};

        for (let i = 0; i < lines.length; i++) {
            const command = String(lines[i] || "").trim();

            if (!command || seen[command])
                continue;

            seen[command] = true;
            rows.push(command);
        }

        runAllCommands = rows;
        runAllCommandsLoaded = true;
        runAllCommandsLoading = false;
        runAllCommandsError = "";

        console.log(
            "AppControl: loaded",
            rows.length,
            "RUN ALL commands from PATH"
        );

        if (selectedModeIndex === runModeIndex
                && runListMode === runListAll) {
            Qt.callLater(function() {
                resetResultSelection();
                resetDetailActionSelection();
            });
        }
    }

    function refreshRunAllCommands(force) {
        if (runAllCommandsLoading)
            return;

        if (runAllCommandsLoaded && !force)
            return;

        runAllCommandsLoading = true;
        runAllCommandsError = "";

        // Scan executable files from every directory in the current PATH.
        // Only basenames are exposed, matching the command names a normal
        // run prompt expects rather than flooding the UI with full paths.
        runAllCommandsProcess.exec([
            "/bin/sh",
            "-lc",
            "IFS=:; "
            + "for d in $PATH; do "
            + "  [ -d \"$d\" ] || continue; "
            + "  for f in \"$d\"/*; do "
            + "    [ -f \"$f\" ] && [ -x \"$f\" ] "
            + "      && printf '%s\\n' \"${f##*/}\"; "
            + "  done; "
            + "done | sort -u"
        ]);
    }

    function setRunListMode(listMode) {
        const nextMode = listMode === runListAll
                         ? runListAll
                         : listMode === runListTerminal
                         ? runListTerminal
                         : runListUser;

        if (runListMode === nextMode) {
            if (nextMode === runListAll
                    && !runAllCommandsLoaded
                    && !runAllCommandsLoading)
                refreshRunAllCommands(false);

            if (nextMode === runListTerminal)
                refreshRunTerminalHistory();

            return;
        }

        runListMode = nextMode;

        if (nextMode === runListAll)
            refreshRunAllCommands(false);
        else if (nextMode === runListTerminal)
            refreshRunTerminalHistory();

        Qt.callLater(function() {
            if (selectedModeIndex === runModeIndex) {
                resetResultSelection();
                resetDetailActionSelection();
                searchInput.forceActiveFocus();
            }
        });
    }

    Process {
        id: runAllCommandsProcess

        stdout: StdioCollector {
            onStreamFinished: {
                appControlWindow.consumeRunAllCommands(text);
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = text.trim();

                if (message.length > 0) {
                    appControlWindow.runAllCommandsError = message;
                    console.log(
                        "AppControl: RUN ALL command scan:",
                        message
                    );
                }

                appControlWindow.runAllCommandsLoading = false;
            }
        }
    }

    function saveInputForMode(modeIndex) {
        if (!searchInput)
            return;

        const next = Object.assign({}, modeInputTexts);
        next[String(modeIndex)] = searchInput.text;
        modeInputTexts = next;
    }

    function restoreInputForMode(modeIndex) {
        const key = String(modeIndex);
        const value = modeInputTexts[key] !== undefined
                      ? modeInputTexts[key]
                      : "";

        if (searchInput.text !== value)
            searchInput.text = value;
    }

    // ============================================================
    // FAVORITES
    // ============================================================

    FileView {
        id: favoriteStoreFile

        path: Quickshell.dataDir + "/appcontrol-favorites.json"
        watchChanges: true

        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()

        JsonAdapter {
            id: favoriteStore

            property list<string> favoriteKeys: []
            // One preferred control-panel action per app/command.
            property list<string> favoriteDetailActionKeys: []
            // Persistent watch/favorite state for individual THERMAL/SYSTEM
            // control-panel metric boxes. Notification thresholds can bind
            // to these keys later without changing the on-disk format again.
            property list<string> favoriteMonitorBoxKeys: []
            // KILL watches use a stable command identity, not PID, so they
            // survive process termination and PID reuse.
            property list<string> favoriteTaskMetricKeys: []
        }
    }



    function isApplicationMode(modeIndex) {
        // FAVORITES is mixed now, so mode identity alone is not enough to
        // decide how a row behaves. Use resultIsApplication() for rows.
        return modeIndex === appsModeIndex;
    }

    function resultSourceMode(entry, modeIndex) {
        return favoriteSourceMode(entry, modeIndex);
    }

    function resultIsApplication(entry, modeIndex) {
        return resultSourceMode(entry, modeIndex) === appsModeIndex;
    }

    function resultIsRun(entry, modeIndex) {
        return resultSourceMode(entry, modeIndex) === runModeIndex;
    }

    function resultIsTab(entry, modeIndex) {
        const source = favoriteSourceItem(entry) || entry;
        return resultSourceMode(entry, modeIndex) === windowsModeIndex
               && !!source
               && !!source._tabRecord;
    }

    function resultIsWindow(entry, modeIndex) {
        return resultSourceMode(entry, modeIndex) === windowsModeIndex
               && !resultIsTab(entry, modeIndex);
    }

    function selectedResultIsApplication() {
        return resultIsApplication(selectedResult(), selectedModeIndex);
    }

    function selectedResultIsRun() {
        return resultIsRun(selectedResult(), selectedModeIndex);
    }

    function selectedResultIsWindow() {
        return resultIsWindow(selectedResult(), selectedModeIndex);
    }

    function selectedResultIsTab() {
        return resultIsTab(selectedResult(), selectedModeIndex);
    }


    function selectedTabControls() {
        const entry = favoriteSourceItem(selectedResult()) || selectedResult();

        if (!entry || !entry._tabRecord || entry._tabUnavailable)
            return [];

        const appName = String(entry.appName || "").trim().toLowerCase();
        const windowName = String(entry.windowName || "").trim().toLowerCase();
        const controls = Array.isArray(appTabControls)
                         ? appTabControls
                         : [];
        const filtered = [];
        const seen = {};

        for (let i = 0; i < controls.length; i++) {
            const control = controls[i];

            if (!control || !control._tabControlRecord)
                continue;

            const controlApp =
                String(control.appName || "").trim().toLowerCase();
            const controlWindow =
                String(control.windowName || "").trim().toLowerCase();

            // These are app-level alternates. Match the selected tab's app
            // first; use the window title as a fallback when an app name is
            // unavailable from the accessibility tree.
            const matchesApp =
                appName.length > 0
                && controlApp.length > 0
                && controlApp === appName;
            const matchesWindow =
                !matchesApp
                && windowName.length > 0
                && controlWindow.length > 0
                && controlWindow === windowName;

            if (!matchesApp && !matchesWindow)
                continue;

            const label = String(
                control.controlName || control.name || "CONTROL"
            ).trim();
            const key = label.toLowerCase();

            if (!label || seen[key])
                continue;

            seen[key] = true;
            filtered.push(control);
        }

        filtered.sort(function(a, b) {
            const aName = String(a.controlName || a.name || "").toLowerCase();
            const bName = String(b.controlName || b.name || "").toLowerCase();
            const priority = function(name) {
                const isNewTab =
                    name.indexOf("new tab") !== -1
                    || (name.indexOf("open") !== -1
                        && name.indexOf("tab") !== -1);

                if (isNewTab)
                    return 0;
                if (name.indexOf("mute") !== -1)
                    return 1;
                if (name.indexOf("close") !== -1)
                    return 2;
                return 3;
            };
            const aPriority = priority(aName);
            const bPriority = priority(bName);

            if (aPriority !== bPriority)
                return aPriority - bPriority;

            return aName.localeCompare(
                bName,
                undefined,
                { sensitivity: "base" }
            );
        });

        return filtered;
    }

    function activateAppTabControl(entry, keepMenuOpen) {
        if (!entry || !entry._tabControlRecord)
            return;

        appTabsActivateProcess.exec([
            "/usr/bin/python3",
            "-c",
            appTabActivateScript(),
            String(entry.provider || ""),
            JSON.stringify(entry)
        ]);

        if (!keepMenuOpen)
            menuOpen = false;
    }

    function selectedResultSupportsDetail() {
        const entry = selectedResult();

        return selectedResultIsApplication()
               || selectedResultIsRun()
               || selectedResultIsWindow()
               || (selectedResultIsTab()
                   && entry
                   && !entry._tabUnavailable)
               || selectedResultIsTask()
               || selectedResultIsThermal()
               || selectedResultIsSystemComponent();
    }

    function selectedControlModeIndex() {
        const entry = selectedResult();

        if (selectedModeIndex === favoritesModeIndex && entry)
            return favoriteSourceMode(entry, selectedModeIndex);

        return selectedModeIndex;
    }

    function windowDisplayAppName(entry) {
        if (!entry)
            return "WINDOW";

        const raw =
            String(
                entry.appId
                || entry.className
                || entry.instance
                || "WINDOW"
            ).trim();

        if (!raw)
            return "WINDOW";

        const lower = raw.toLowerCase();

        const aliases = {
            "code": "Code",
            "code-oss": "Code",
            "codium": "VSCodium",
            "brave-browser": "Brave",
            "brave-browser-stable": "Brave",
            "google-chrome": "Chrome",
            "google-chrome-stable": "Chrome",
            "chromium": "Chromium",
            "chromium-browser": "Chromium",
            "firefox": "Firefox",
            "kitty": "Kitty",
            "org.wezfurlong.wezterm": "WezTerm",
            "com.mitchellh.ghostty": "Ghostty",
            "thunar": "Thunar",
            "pcmanfm": "PCManFM",
            "nemo": "Nemo"
        };

        if (aliases[lower])
            return aliases[lower];

        let name = raw;

        // Reverse-domain app ids are usually most readable from the final
        // component, e.g. com.mitchellh.ghostty -> ghostty.
        if (name.indexOf(".") !== -1) {
            const parts = name.split(".");
            name = parts[parts.length - 1] || name;
        }

        name = name
            .replace(/\.desktop$/i, "")
            .replace(/-stable$/i, "")
            .replace(/-browser$/i, "")
            .replace(/[_-]+/g, " ")
            .trim();

        if (!name)
            return "WINDOW";

        return name
            .split(/\s+/)
            .map(function(part) {
                if (!part)
                    return "";

                if (part.length <= 3
                        && part === part.toUpperCase())
                    return part;

                return part.charAt(0).toUpperCase()
                       + part.slice(1);
            })
            .join(" ");
    }

    function windowDisplaySubName(entry) {
        if (!entry)
            return "";

        return String(
            entry.name
            || entry.appId
            || entry.className
            || entry.instance
            || ""
        );
    }

    function resultDisplayName(entry, modeIndex) {
        if (!entry)
            return "";

        if (resultIsApplication(entry, modeIndex))
            return entry.name || "APPLICATION";

        if (resultIsTab(entry, modeIndex))
            return entry.tabTitle || entry.name || "TAB";

        if (resultIsWindow(entry, modeIndex))
            return windowDisplayAppName(entry);

        if (modeIndex === killModeIndex && entry._taskRecord)
            return entry.comm || entry.name || "PROCESS";

        if (modeIndex === thermalModeIndex && entry._thermalRecord)
            return entry.name || "THERMAL SENSOR";

        if (modeIndex === systemModeIndex && entry._systemRecord)
            return entry.name || "SYSTEM COMPONENT";

        return entry.label || entry.name || "OPTION";
    }

    function favoriteSourceMode(entry, modeIndex) {
        if (entry && entry._favoriteRecord)
            return entry._sourceModeIndex;

        return modeIndex;
    }

    function favoriteSourceItem(entry) {
        if (entry && entry._favoriteRecord)
            return entry._sourceItem;

        return entry;
    }

    function taskPersistentIdentity(entry) {
        const source = favoriteSourceItem(entry) || entry;
        if (!source)
            return "";

        const comm = String(source.comm || source.name || source.label || "").trim();
        if (comm)
            return comm.toLowerCase();

        const args = String(source.args || "").trim();
        if (!args)
            return "";

        const first = args.split(/\s+/)[0] || "";
        const pieces = first.split("/");
        return String(pieces[pieces.length - 1] || first).toLowerCase();
    }

    function taskFavoriteKey(entry) {
        const identity = taskPersistentIdentity(entry);
        return identity ? "task|" + encodeURIComponent(identity) : "";
    }

    function taskIdentityFromFavoriteKey(key) {
        const raw = String(key || "");
        if (raw.indexOf("task|") !== 0)
            return "";
        try { return decodeURIComponent(raw.slice(5)); }
        catch (error) { return ""; }
    }

    function taskMetricFavoriteKey(entry, metricId) {
        const identity = taskPersistentIdentity(entry);
        const id = String(metricId || "").trim().toLowerCase();
        if (!identity || !id)
            return "";
        return "taskmetric|" + encodeURIComponent(identity)
               + "|" + encodeURIComponent(id);
    }

    function taskMetricFavoriteData(key) {
        const raw = String(key || "");
        if (raw.indexOf("taskmetric|") !== 0)
            return null;
        const parts = raw.split("|");
        if (parts.length < 3)
            return null;
        try {
            return {
                identity: decodeURIComponent(parts[1]),
                metricId: decodeURIComponent(parts.slice(2).join("|"))
            };
        } catch (error) { return null; }
    }

    function isTaskMetricFavorite(entry, metricId) {
        const key = taskMetricFavoriteKey(entry, metricId);
        return key.length > 0
               && favoriteStore.favoriteTaskMetricKeys.indexOf(key) !== -1;
    }

    function toggleTaskMetricFavorite(entry, metricId) {
        const key = taskMetricFavoriteKey(entry, metricId);
        if (!key)
            return;
        const next = favoriteStore.favoriteTaskMetricKeys.slice();
        const index = next.indexOf(key);
        if (index >= 0) next.splice(index, 1);
        else next.unshift(key);
        favoriteStore.favoriteTaskMetricKeys = next;
    }

    function taskHasMetricFavorite(entry) {
        const identity = taskPersistentIdentity(entry);
        if (!identity)
            return false;
        const prefix = "taskmetric|" + encodeURIComponent(identity) + "|";
        for (let i = 0; i < favoriteStore.favoriteTaskMetricKeys.length; i++) {
            if (String(favoriteStore.favoriteTaskMetricKeys[i] || "").indexOf(prefix) === 0)
                return true;
        }
        return false;
    }

    function hasTaskFavorites() {
        if (favoriteStore.favoriteTaskMetricKeys.length > 0)
            return true;
        for (let i = 0; i < favoriteStore.favoriteKeys.length; i++) {
            if (String(favoriteStore.favoriteKeys[i] || "").indexOf("task|") === 0)
                return true;
        }
        return false;
    }

    function taskMetricValue(entry, metricId) {
        if (!entry) return 0;
        switch (String(metricId || "")) {
        case "cpu": return Number(entry.cpu || 0);
        case "mem": return Number(entry.mem || 0);
        case "rss": return Number(entry.rss || 0);
        case "threads": return Number(entry.threads || 0);
        default: return 0;
        }
    }

    function taskMetricIsCritical(entry, metricId) {
        if (!entry) return false;
        switch (String(metricId || "")) {
        case "cpu": return Number(entry.cpu || 0) >= 80;
        case "mem": return Number(entry.mem || 0) >= 80;
        case "rss": return Number(entry.mem || 0) >= 80;
        case "threads": return Number(entry.threads || 0) >= 256;
        default: return false;
        }
    }

    function taskMetricDisplayValue(entry, metricId) {
        if (!entry) return "";
        switch (String(metricId || "")) {
        case "cpu": return Number(entry.cpu || 0).toFixed(1) + "%";
        case "mem": return Number(entry.mem || 0).toFixed(1) + "%";
        case "rss": return formatTaskMemory(entry.rss);
        case "threads": return String(entry.threads || 0);
        case "pid": return String(entry.pid || "?");
        case "uptime": return String(entry.elapsed || "?");
        default: return "";
        }
    }

    property var taskAlertLastSent: ({})

    function checkTaskMetricAlerts(rows) {
        const watches = favoriteStore.favoriteTaskMetricKeys;
        if (!watches || watches.length === 0)
            return;

        const now = Date.now();
        for (let i = 0; i < watches.length; i++) {
            const watchKey = String(watches[i] || "");
            const watch = taskMetricFavoriteData(watchKey);
            if (!watch) continue;

            let match = null;
            for (let j = 0; j < rows.length; j++) {
                const candidate = rows[j];
                if (taskPersistentIdentity(candidate) !== watch.identity)
                    continue;
                if (!match || taskMetricValue(candidate, watch.metricId)
                        > taskMetricValue(match, watch.metricId))
                    match = candidate;
            }

            if (!match || !taskMetricIsCritical(match, watch.metricId))
                continue;

            const previous = Number(taskAlertLastSent[watchKey] || 0);
            if (now - previous < 60000)
                continue;
            taskAlertLastSent[watchKey] = now;

            Quickshell.execDetached([
                "notify-send", "-u", "critical", "-a", "AppControl",
                "AppControl • " + String(match.comm || match.name || "PROCESS")
                + " " + String(watch.metricId || "").toUpperCase() + " HIGH",
                String(watch.metricId || "").toUpperCase() + " : "
                + taskMetricDisplayValue(match, watch.metricId)
            ]);
        }
    }

    function favoriteKeyFor(entry, modeIndex) {
        if (!entry)
            return "";

        if (entry._favoriteRecord && entry._favoriteKey)
            return entry._favoriteKey;

        if (modeIndex === appsModeIndex)
            return appEntryKey(entry);

        if (modeIndex === runModeIndex)
            return runFavoriteKey(
                runCommandText(entry),
                runPrefixModeForEntry(entry)
            );

        if (modeIndex === thermalModeIndex && entry.id)
            return "thermal|" + encodeURIComponent(String(entry.id));

        if (modeIndex === systemModeIndex && entry.id)
            return "system|" + encodeURIComponent(String(entry.id));

        if (modeIndex === killModeIndex && entry._taskRecord)
            return taskFavoriteKey(entry);

        // WINDOWS and any remaining placeholders include the mode index so
        // identical temporary labels remain distinct until those modes get
        // their real stable identities.
        const label = String(entry.label || entry.name || "");

        if (!label)
            return "";

        return "mode:" + modeIndex + ":" + label;
    }

    function isFavoriteItem(entry, modeIndex) {
        const key = favoriteKeyFor(entry, modeIndex);

        if (!key)
            return false;

        return favoriteStore.favoriteKeys.indexOf(key) !== -1;
    }

    function monitorBoxFavoriteKey(entry, boxId) {
        if (!entry || !entry.id || !boxId)
            return "";

        const controlMode = selectedControlModeIndex();

        const modeName =
            controlMode === thermalModeIndex
            ? "thermal"
            : controlMode === systemModeIndex
            ? "system"
            : "";

        if (!modeName)
            return "";

        return "watchbox|"
               + modeName
               + "|"
               + encodeURIComponent(String(entry.id))
               + "|"
               + encodeURIComponent(String(boxId));
    }

    function isMonitorBoxFavorite(entry, boxId) {
        const key = monitorBoxFavoriteKey(entry, boxId);

        return key
               && favoriteStore.favoriteMonitorBoxKeys.indexOf(key) !== -1;
    }

    function toggleMonitorBoxFavorite(entry, boxId) {
        const key = monitorBoxFavoriteKey(entry, boxId);

        if (!key)
            return;

        const next = favoriteStore.favoriteMonitorBoxKeys.slice();
        const index = next.indexOf(key);

        if (index >= 0)
            next.splice(index, 1);
        else
            next.unshift(key);

        favoriteStore.favoriteMonitorBoxKeys = next;
    }

    function monitorEntryHasBoxFavorite(entry, modeIndex) {
        if (!entry || !entry.id)
            return false;

        const modeName =
            modeIndex === thermalModeIndex
            ? "thermal"
            : modeIndex === systemModeIndex
            ? "system"
            : "";

        if (!modeName)
            return false;

        const prefix =
            "watchbox|"
            + modeName
            + "|"
            + encodeURIComponent(String(entry.id))
            + "|";

        for (let i = 0;
             i < favoriteStore.favoriteMonitorBoxKeys.length;
             i++) {
            if (String(
                    favoriteStore.favoriteMonitorBoxKeys[i] || ""
                ).indexOf(prefix) === 0)
                return true;
        }

        return false;
    }

    function hasMonitorFavorites() {
        if (favoriteStore.favoriteMonitorBoxKeys.length > 0)
            return true;

        for (let i = 0; i < favoriteStore.favoriteKeys.length; i++) {
            const key = String(favoriteStore.favoriteKeys[i] || "");

            if (key.indexOf("thermal|") === 0
                    || key.indexOf("system|") === 0)
                return true;
        }

        return false;
    }

    // Kept as a small compatibility helper for app sorting.
    function isFavorite(entry) {
        return isFavoriteItem(entry, appsModeIndex);
    }

    function favoriteRecordForApp(entry) {
        const key = favoriteKeyFor(entry, appsModeIndex);

        return {
            _favoriteRecord: true,
            _favoriteType: "app",
            _favoriteKey: key,
            _sourceModeIndex: appsModeIndex,
            _sourceItem: entry,

            id: entry.id || key,
            name: entry.name || "APPLICATION",
            genericName: entry.genericName || "",
            comment: entry.comment || "",
            keywords: entry.keywords || "",
            icon: entry.icon || "",
            actions: entry.actions || [],
            command: entry.command || [],
            startupClass: entry.startupClass || "",

            execute: function() {
                appControlWindow.launchApplication(entry);
            }
        };
    }

    function favoriteRecordForRunCommand(command, prefixMode) {
        const resolvedPrefix =
            normalizeRunPrefixMode(prefixMode);
        const sourceItem =
            runRecord(command, "FAVORITE", resolvedPrefix);
        const key = runFavoriteKey(command, resolvedPrefix);

        return {
            _favoriteRecord: true,
            _favoriteType: "run",
            _favoriteKey: key,
            _sourceModeIndex: runModeIndex,
            _sourceItem: sourceItem,
            _runPrefixMode: resolvedPrefix,

            id: key,
            label: sourceItem.label,
            name: sourceItem.name,
            commandText: sourceItem.commandText,
            genericName: sourceItem.genericName,
            comment: "FAVORITE • "
                     + runPrefixName(resolvedPrefix)
                     + " • "
                     + runShellName().toUpperCase(),
            keywords: "",
            icon: "",
            actions: [],
            startupClass: ""
        };
    }

    function favoriteRecordForModeItem(entry, modeIndex) {
        const key = favoriteKeyFor(entry, modeIndex);
        const modeName = modes[modeIndex]
                         ? modes[modeIndex].name
                         : "MODE";
        const label = entry.label || entry.name || "OPTION";

        return {
            _favoriteRecord: true,
            _favoriteType: "mode",
            _favoriteKey: key,
            _sourceModeIndex: modeIndex,
            _sourceItem: entry,

            id: key,
            name: label,
            genericName: modeName,
            comment: "FAVORITE FROM " + modeName,
            keywords: "",
            icon: "",
            actions: [],
            command: [],
            startupClass: "",

            execute: function() {
                console.log("AppControl:", modeName, label);
            }
        };
    }

    function favoriteRecordForTaskIdentity(identity, liveEntry) {
        const normalized = String(identity || "").trim().toLowerCase();
        if (!normalized)
            return null;

        const source = liveEntry ? liveEntry : {
            _taskRecord: true,
            _taskOffline: true,
            id: "task-offline:" + normalized,
            pid: 0, ppid: 0, user: "", state: "OFFLINE",
            cpu: 0, mem: 0, rss: 0, vsz: 0, threads: 0,
            elapsed: "NOT RUNNING",
            comm: normalized, args: "", name: normalized, label: normalized
        };
        const key = "task|" + encodeURIComponent(normalized);
        return {
            _favoriteRecord: true,
            _favoriteType: "task",
            _favoriteKey: key,
            _sourceModeIndex: killModeIndex,
            _sourceItem: source,
            id: key,
            name: source.comm || normalized,
            genericName: "WATCHED PROCESS",
            comment: liveEntry
                     ? "KILL • RUNNING • PID " + String(source.pid || "?")
                     : "KILL • NOT RUNNING • FAVORITE RETAINED",
            keywords: "kill process task watched",
            icon: "", actions: [], command: [], startupClass: ""
        };
    }

    function currentApplicationValues() {
        return selectedModeIndex === appsModeIndex
               ? filteredApps.values
               : [];
    }

    function restoreSelectionByKey(key) {
        let values = [];

        if (selectedModeIndex === favoritesModeIndex)
            values = favoriteResults.values;
        else if (selectedModeIndex === appsModeIndex)
            values = filteredApps.values;
        else if (selectedModeIndex === runModeIndex)
            values = runResults.values;
        else if (selectedModeIndex === windowsModeIndex)
            values = windowResults.values;
        else if (selectedModeIndex === thermalModeIndex)
            values = thermalResults.values;
        else if (selectedModeIndex === killModeIndex)
            values = killTaskResults.values;
        else if (selectedModeIndex === systemModeIndex)
            values = systemResults.values;
        else
            values = placeholderResults;

        if (values.length === 0) {
            selectedResultIndex = -1;
            return;
        }

        let targetIndex = -1;

        for (let i = 0; i < values.length; i++) {
            const candidateKey = favoriteKeyFor(
                values[i],
                selectedModeIndex
            );

            if (candidateKey === key) {
                targetIndex = i;
                break;
            }
        }

        if (targetIndex < 0)
            targetIndex = Math.min(
                Math.max(0, selectedResultIndex),
                values.length - 1
            );

        selectedResultIndex = targetIndex;
        hoveredResultIndex = -1;

        Qt.callLater(function() {
            if (selectedResultIndex >= 0)
                resultList.positionViewAtIndex(
                    selectedResultIndex,
                    ListView.Contain
                );
        });
    }

    function toggleFavorite(entry, modeIndex) {
        if (!entry)
            return;

        const key = favoriteKeyFor(entry, modeIndex);

        if (!key)
            return;

        const next = favoriteStore.favoriteKeys.slice();
        const existingIndex = next.indexOf(key);

        if (existingIndex >= 0)
            next.splice(existingIndex, 1);
        else
            next.unshift(key);

        favoriteStore.favoriteKeys = next;

        // APPS still remembers the desktop entry across mode changes.
        if (favoriteSourceMode(entry, modeIndex) === appsModeIndex)
            rememberedAppKey = appEntryKey(favoriteSourceItem(entry));

        Qt.callLater(function() {
            appControlWindow.restoreSelectionByKey(key);
            appControlWindow.resetDetailActionSelection();
        });
    }

    function hiddenCommandIcon(command) {
        const name = String(command || "").trim().toLowerCase();

        const known = {
            "cava": "audio-card",
            "nvim": "nvim",
            "vim": "vim",
            "htop": "htop",
            "btop": "btop",
            "fastfetch": "utilities-system-monitor",
            "neofetch": "utilities-system-monitor",
            "zsh": "utilities-terminal",
            "bash": "utilities-terminal",
            "fish": "utilities-terminal",
            "kitty": "kitty",
            "cat": "text-x-generic",
            "less": "text-x-generic",
            "man": "help-browser",
            "hollywood": "utilities-terminal",
            "pipes.sh": "utilities-terminal",
            "pipes": "utilities-terminal",
            "cmatrix": "utilities-terminal"
        };

        if (known[name])
            return known[name];

        const apps = [...DesktopEntries.applications.values];
        for (let i = 0; i < apps.length; i++) {
            const entry = apps[i];
            if (appLaunchExecutableName(entry) === name && entry.icon)
                return entry.icon;
        }

        return "";
    }

    function hiddenPersistentCommand(command) {
        const name = String(command || "").trim();

        if (!name)
            return "";

        return shellQuote(name)
               + "; printf '\\n[AppControl] command exited — shell remains open.\\n'; "
               + "exec " + shellQuote(runShellPath());
    }

    function launchHiddenKitty(command) {
        const script = hiddenPersistentCommand(command);

        if (!script)
            return;

        Quickshell.execDetached([
            "kitty",
            "-o",
            "allow_remote_control=socket-only",
            "--listen-on",
            "unix:@appcontrol-kitty-" + String(Date.now()),
            runShellPath(),
            "-lc",
            script
        ]);

        menuOpen = false;
    }

    function launchHiddenGeometry(command, fullscreen) {
        const persistent = hiddenPersistentCommand(command);

        if (!persistent)
            return;

        const stamp = String(Date.now());
        const appId =
            fullscreen
            ? "appcontrol-hidden-fullscreen-" + stamp
            : "appcontrol-hidden-float-" + stamp;

        const criteria = '[app_id="' + appId + '"]';
        const rule =
            fullscreen
            ? "for_window " + criteria + " fullscreen enable"
            : "for_window "
              + criteria
              + " floating enable, move position center";

        const script =
            "swaymsg "
            + shellQuote(rule)
            + " >/dev/null 2>&1; "
            + "exec kitty"
            + " --class "
            + shellQuote(appId)
            + " --title "
            + shellQuote(fullscreen ? "Hidden Fullscreen" : "Hidden Float")
            + " "
            + shellQuote(runShellPath())
            + " -lc "
            + shellQuote(persistent);

        Quickshell.execDetached([
            runShellPath(),
            "-lc",
            script
        ]);

        menuOpen = false;
    }

    function launchHiddenToolbox(command) {
        const name = String(command || "").trim();
        if (!name) return;

        const inner = shellQuote(name)
                      + "; printf '\n[AppControl] toolbox command exited — shell remains open.\n'; "
                      + "exec bash";

        Quickshell.execDetached([
            "kitty",
            "toolbox",
            "run",
            "bash",
            "-lc",
            inner
        ]);
        menuOpen = false;
    }

    function terminateHiddenCommand(command) {
        const name = String(command || "").trim();
        if (!name) return;

        Quickshell.execDetached([
            runShellPath(),
            "-lc",
            "pkill -TERM -u \"$(id -u)\" -x -- "
            + shellQuote(name)
            + " >/dev/null 2>&1 || true"
        ]);
        menuOpen = false;
    }

    function hiddenCommandRecord(command) {
        const name = String(command || "").trim();

        return {
            _hiddenCommand: true,
            id: "hidden:" + name,
            name: name,
            genericName: "HIDDEN COMMAND",
            comment: "Command-line application from $PATH",
            keywords: "terminal cli hidden command",
            icon: hiddenCommandIcon(name),
            actions: [],
            command: [name],
            startupClass: "",

            execute: function() {
                appControlWindow.launchHiddenCommand(name);
            }
        };
    }

    function launchHiddenCommand(command) {
        const name = String(command || "").trim();

        if (!name)
            return;

        // Hidden commands are the programs that normally do not have a
        // launchable desktop entry. Give them a terminal automatically so
        // interactive tools such as cava, pipes, zsh, cat, etc. are usable.
        launchHiddenKitty(name);
    }

    function appEntryIsFlatpak(entry) {
        if (!entry)
            return false;

        const command = entry.command || [];
        const joined = command.map(function(token) {
            return String(token || "").toLowerCase();
        }).join(" ");

        return joined.indexOf("flatpak run") !== -1
               || joined.indexOf("/flatpak ") !== -1
               || joined.indexOf("flatpak --") !== -1;
    }

    function appSourceLabel(entry) {
        if (entry && entry._hiddenCommand)
            return "HIDDEN";

        return appEntryIsFlatpak(entry) ? "FLATPAK" : "NORMAL";
    }

    function appEntryHasLaunchCommand(entry) {
        if (!entry)
            return false;

        const command = entry.command;

        if (Array.isArray(command))
            return command.length > 0
                   && String(command[0] || "").trim().length > 0;

        return String(command || "").trim().length > 0;
    }

    function appEntryMatchesSelectedSource(entry) {
        if (!entry)
            return false;

        if (appSourceMode === appSourceHidden)
            return !!entry._hiddenCommand;

        if (entry._hiddenCommand)
            return false;

        const isFlatpak = appEntryIsFlatpak(entry);

        return appSourceMode === appSourceFlatpak
               ? isFlatpak
               : !isFlatpak;
    }

    function appEntryLaunchableForCurrentContext(entry) {
        if (!entry || !appEntryHasLaunchCommand(entry))
            return false;

        if (selectedModeIndex === favoritesModeIndex)
            return true;

        return appEntryLaunchableForSelectedSource(entry);
    }

    function appEntryLaunchableForSelectedSource(entry) {
        if (!entry || !appEntryHasLaunchCommand(entry))
            return false;

        // NORMAL is the broad/default launcher: native AND Flatpak desktop
        // entries may launch from here.
        //
        // FLATPAK is intentionally strict: native entries remain visible for
        // comparison, but only Flatpak entries may launch in this sub-mode.
        if (appSourceMode === appSourceHidden)
            return !!entry._hiddenCommand;

        if (entry._hiddenCommand)
            return false;

        if (appSourceMode === appSourceFlatpak)
            return appEntryIsFlatpak(entry);

        return true;
    }

    function restoreMatchingAppForSource(previousName) {
        Qt.callLater(function() {
            const apps = filteredApps.values;

            if (!apps || apps.length === 0) {
                appControlWindow.selectedResultIndex = -1;
                return;
            }

            const wanted =
                String(previousName || "").trim().toLowerCase();

            let match = -1;

            // When both package forms of the same app exist, Shift+Left
            // lands on the counterpart for the newly selected source.
            if (wanted.length > 0) {
                for (let i = 0; i < apps.length; i++) {
                    const entry = apps[i];

                    if (!appControlWindow.appEntryMatchesSelectedSource(entry))
                        continue;

                    if (String(entry.name || "").trim().toLowerCase()
                            === wanted) {
                        match = i;
                        break;
                    }
                }
            }

            if (match < 0)
                match = 0;

            appControlWindow.selectedResultIndex = match;

            if (match >= 0) {
                appControlWindow.rememberCurrentAppSelection();

                Qt.callLater(function() {
                    resultList.positionViewAtIndex(
                        appControlWindow.selectedResultIndex,
                        ListView.Center
                    );
                });
            }

            appControlWindow.resetDetailActionSelection();
        });
    }

    function setAppSourceMode(mode) {
        const current = selectedResult();
        const previousName =
            selectedResultIsApplication() && current
            ? String(current.name || "")
            : "";

        appSourceMode =
            mode === appSourceHidden
            ? appSourceHidden
            : mode === appSourceFlatpak
            ? appSourceFlatpak
            : appSourceNative;

        if (appSourceMode === appSourceHidden)
            refreshRunAllCommands(false);

        keyboardActive = true;
        hoveredResultIndex = -1;
        restoreMatchingAppForSource(previousName);
    }

    function setAppLaunchMode(mode) {
        if (mode === appLaunchToolbox)
            appLaunchMode = appLaunchToolbox;
        else if (mode === appLaunchBottle)
            appLaunchMode = appLaunchBottle;
        else
            appLaunchMode = appLaunchNormal;

        keyboardActive = true;
    }

    function bottleProgramName(entry) {
        if (!entry)
            return "";

        return String(
            appDisplayName(entry)
            || entry.name
            || ""
        ).trim();
    }

    function refreshBottleList() {
        if (bottlesLoading)
            return;

        bottlesLoading = true;
        bottlesError = "";

        bottlesListProcess.exec([
            "sh",
            "-lc",
            "if command -v flatpak >/dev/null 2>&1 "
            + "&& flatpak info com.usebottles.bottles >/dev/null 2>&1; then "
            + "flatpak run --command=bottles-cli com.usebottles.bottles "
            + "--json list bottles; "
            + "elif command -v bottles-cli >/dev/null 2>&1; then "
            + "bottles-cli --json list bottles; "
            + "else exit 127; fi"
        ]);
    }

    function collectBottleNames(value, output) {
        if (value === null || value === undefined)
            return;

        if (typeof value === "string") {
            const name = value.trim();

            if (name && output.indexOf(name) === -1)
                output.push(name);

            return;
        }

        if (Array.isArray(value)) {
            for (let i = 0; i < value.length; i++) {
                const item = value[i];

                if (typeof item === "string") {
                    collectBottleNames(item, output);
                    continue;
                }

                if (item && typeof item === "object") {
                    if (item.name)
                        collectBottleNames(item.name, output);
                    else if (item.Name)
                        collectBottleNames(item.Name, output);
                    else if (item.bottle)
                        collectBottleNames(item.bottle, output);
                }
            }

            return;
        }

        if (typeof value === "object") {
            if (value.name)
                collectBottleNames(value.name, output);

            if (value.Name)
                collectBottleNames(value.Name, output);

            if (value.bottles)
                collectBottleNames(value.bottles, output);

            const keys = Object.keys(value);

            for (let i = 0; i < keys.length; i++) {
                const key = keys[i];

                // Some Bottles versions return an object keyed by bottle name.
                if (key !== "bottles"
                        && key !== "name"
                        && key !== "Name"
                        && value[key]
                        && typeof value[key] === "object") {
                    collectBottleNames(key, output);
                }
            }
        }
    }

    function launchAppInBottle(entry) {
        const appEntry = favoriteSourceItem(entry) || entry;

        if (!appEntry)
            return;

        if (!selectedBottleName) {
            console.log(
                "AppControl: BOTTLES launch requested but no bottle is available"
            );

            refreshBottleList();
            return;
        }

        const programName = bottleProgramName(appEntry);

        if (!programName)
            return;

        console.log(
            "AppControl: Bottles launch",
            programName,
            "in",
            selectedBottleName
        );

        Quickshell.execDetached([
            "sh",
            "-lc",
            "if command -v flatpak >/dev/null 2>&1 "
            + "&& flatpak info com.usebottles.bottles >/dev/null 2>&1; then "
            + "exec flatpak run --command=bottles-cli "
            + "com.usebottles.bottles run -b "
            + shellQuote(selectedBottleName)
            + " -p "
            + shellQuote(programName)
            + "; else exec bottles-cli run -b "
            + shellQuote(selectedBottleName)
            + " -p "
            + shellQuote(programName)
            + "; fi"
        ]);

        menuOpen = false;
    }

    function appToolboxCommandTokens(entry) {
        if (!entry)
            return [];

        const raw = entry.command || [];

        if (Array.isArray(raw)) {
            const tokens = [];

            for (let i = 0; i < raw.length; i++) {
                const token = String(raw[i] || "").trim();

                if (!token)
                    continue;

                // Desktop-entry field codes need a file/URL selection.
                if (/^%[fFuUdDnNickvm]$/.test(token))
                    continue;

                tokens.push(token);
            }

            return tokens;
        }

        const commandText =
            String(raw || "")
            .replace(/\s+%[fFuUdDnNickvm]\b/g, "")
            .trim();

        if (!commandText)
            return [];

        return ["__APPCONTROL_SHELL__", commandText];
    }

    function launchAppInToolbox(entry) {
        const appEntry = favoriteSourceItem(entry) || entry;

        if (!appEntry)
            return;

        const tokens = appToolboxCommandTokens(appEntry);

        if (tokens.length === 0) {
            console.log(
                "AppControl: TOOLBOX app launch unavailable:",
                appEntry.name
            );
            return;
        }

        console.log(
            "AppControl: TOOLBOX app launch:",
            appEntry.name
        );

        if (tokens[0] === "__APPCONTROL_SHELL__") {
            Quickshell.execDetached([
                "toolbox",
                "run",
                "bash",
                "-lc",
                tokens[1]
            ]);
        } else {
            Quickshell.execDetached(
                ["toolbox", "run"].concat(tokens)
            );
        }

        menuOpen = false;
    }

    function appLaunchCommandTokens(entry) {
        // Reuse the cleaned DesktopEntry argv logic; despite the historical
        // helper name, these tokens are equally useful for normal launches.
        return appToolboxCommandTokens(entry);
    }

    function appLaunchExecutableName(entry) {
        const tokens = appLaunchCommandTokens(entry);

        if (tokens.length === 0)
            return "";

        if (tokens[0] === "__APPCONTROL_SHELL__") {
            const match = String(tokens[1] || "").trim().match(
                /^([A-Za-z0-9_./+@%:-]+)(?:\s|$)/
            );

            if (!match)
                return "";

            const parts = match[1].split("/");
            return String(parts[parts.length - 1] || "").toLowerCase();
        }

        // Flatpak desktop entries normally look like:
        //   flatpak run ... APP_ID
        // so detect them from the entire command below as well.
        const first = String(tokens[0] || "");
        const firstParts = first.split("/");

        return String(
            firstParts[firstParts.length - 1] || ""
        ).toLowerCase();
    }

    function appNeedsForcedAccessibility(entry) {
        if (!entry)
            return false;

        const tokens = appLaunchCommandTokens(entry);
        const commandText = tokens.join(" ").toLowerCase();
        const name = String(entry.name || "").toLowerCase();
        const id = String(entry.id || "").toLowerCase();
        const startupClass =
            String(entry.startupClass || "").toLowerCase();

        const haystack =
            name + " " + id + " " + startupClass + " " + commandText;

        return haystack.indexOf("brave") !== -1
               || haystack.indexOf("chromium") !== -1
               || haystack.indexOf("google-chrome") !== -1
               || haystack.indexOf("chrome ") !== -1
               || haystack.indexOf("code-oss") !== -1
               || haystack.indexOf("vscode") !== -1
               || haystack.indexOf("visual studio code") !== -1
               || haystack.indexOf("codium") !== -1
               || haystack.indexOf("electron") !== -1;
    }

    function appTabDebugPort(entry) {
        if (!entry)
            return 0;

        const tokens = appLaunchCommandTokens(entry);
        const haystack =
            (
                String(entry.name || "")
                + " "
                + String(entry.id || "")
                + " "
                + String(entry.startupClass || "")
                + " "
                + tokens.join(" ")
            ).toLowerCase();

        if (haystack.indexOf("brave") !== -1)
            return 9222;

        if (haystack.indexOf("google-chrome") !== -1
                || haystack.indexOf("chrome ") !== -1)
            return 9223;

        if (haystack.indexOf("chromium") !== -1)
            return 9224;

        if (haystack.indexOf("code-oss") !== -1
                || haystack.indexOf("visual studio code") !== -1
                || haystack.indexOf("vscode") !== -1)
            return 9225;

        if (haystack.indexOf("codium") !== -1)
            return 9226;

        if (haystack.indexOf("electron") !== -1) {
            const key =
                String(entry.id || entry.name || "electron");

            let hash = 0;

            for (let i = 0; i < key.length; i++)
                hash = ((hash * 31) + key.charCodeAt(i)) & 0x7fffffff;

            return 9300 + (hash % 200);
        }

        return 0;
    }

    function appIsKitty(entry) {
        if (!entry)
            return false;

        const tokens = appLaunchCommandTokens(entry);
        const commandText = tokens.join(" ").toLowerCase();
        const name = String(entry.name || "").toLowerCase();
        const id = String(entry.id || "").toLowerCase();

        return name === "kitty"
               || id.indexOf("kitty") !== -1
               || commandText.indexOf("kitty") !== -1;
    }

    function launchApplicationWithTabProvider(entry) {
        if (!entry)
            return false;

        const tokens = appLaunchCommandTokens(entry);

        if (tokens.length === 0)
            return false;

        // Kitty remote control must be enabled when Kitty starts. Socket-only
        // keeps control local to the explicitly-created Unix socket.
        if (appIsKitty(entry)) {
            const script =
                "exec kitty "
                + "-o allow_remote_control=socket-only "
                + "--listen-on \"unix:@appcontrol-kitty-$$\"";

            console.log(
                "AppControl: launching Kitty with tab provider socket"
            );

            Quickshell.execDetached([
                runShellPath(),
                "-lc",
                script
            ]);

            return true;
        }

        // Chromium-family and Electron apps do not necessarily populate their
        // native accessibility trees until accessibility is enabled at launch.
        if (!appNeedsForcedAccessibility(entry))
            return false;

        const accessibilityFlag =
            "--force-renderer-accessibility=complete";
        const debugPort =
            appTabDebugPort(entry);

        if (tokens[0] === "__APPCONTROL_SHELL__") {
            let commandText = String(tokens[1] || "");

            if (commandText.indexOf("--force-renderer-accessibility") === -1)
                commandText += " " + accessibilityFlag;

            if (debugPort > 0
                    && commandText.indexOf("--remote-debugging-port") === -1) {
                commandText +=
                    " --remote-debugging-address=127.0.0.1"
                    + " --remote-debugging-port="
                    + String(debugPort);
            }

            console.log(
                "AppControl: launching with accessibility tab provider:",
                entry.name
            );

            Quickshell.execDetached([
                "env",
                "NO_AT_BRIDGE=0",
                "ACCESSIBILITY_ENABLED=1",
                "QT_ACCESSIBILITY=1",
                "QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1",
                runShellPath(),
                "-lc",
                commandText
            ]);

            return true;
        }

        const command = tokens.slice();

        let alreadyEnabled = false;

        for (let i = 0; i < command.length; i++) {
            if (String(command[i]).indexOf(
                        "--force-renderer-accessibility"
                    ) === 0) {
                alreadyEnabled = true;
                break;
            }
        }

        if (!alreadyEnabled)
            command.push(accessibilityFlag);

        let hasDebugPort = false;

        for (let i = 0; i < command.length; i++) {
            if (String(command[i]).indexOf(
                        "--remote-debugging-port"
                    ) === 0) {
                hasDebugPort = true;
                break;
            }
        }

        if (debugPort > 0 && !hasDebugPort) {
            command.push("--remote-debugging-address=127.0.0.1");
            command.push(
                "--remote-debugging-port=" + String(debugPort)
            );
        }

        console.log(
            "AppControl: launching with accessibility tab provider:",
            entry.name
        );

        const accessibleCommand = [
            "env",
            "NO_AT_BRIDGE=0",
            "ACCESSIBILITY_ENABLED=1",
            "QT_ACCESSIBILITY=1",
            "QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1"
        ].concat(command);

        Quickshell.execDetached(accessibleCommand);
        return true;
    }

    function launchApplication(entry) {
        const appEntry = favoriteSourceItem(entry) || entry;

        if (!appEntry)
            return;

        if (!appEntryLaunchableForCurrentContext(appEntry)) {
            console.log(
                "AppControl: application unavailable in current source mode:",
                appEntry.name,
                appSourceLabel(appEntry)
            );
            return;
        }

        if (selectedModeIndex === appsModeIndex
                && appEntry._hiddenCommand) {
            launchHiddenCommand(appEntry.name);
            return;
        }

        if (selectedModeIndex === appsModeIndex
                && appLaunchMode === appLaunchToolbox) {
            launchAppInToolbox(appEntry);
            return;
        }

        if (selectedModeIndex === appsModeIndex
                && appLaunchMode === appLaunchBottle) {
            launchAppInBottle(appEntry);
            return;
        }

        console.log("AppControl: launching", appEntry.name);

        if (!launchApplicationWithTabProvider(appEntry))
            appEntry.execute();

        menuOpen = false;
    }

    Process {
        id: bottlesListProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const names = [];

                try {
                    const parsed = JSON.parse(text || "[]");
                    appControlWindow.collectBottleNames(parsed, names);
                } catch (error) {
                    // Keep a small text fallback for older CLI output.
                    const lines = String(text || "")
                        .split(/\\r?\\n/)
                        .map(function(line) { return line.trim(); })
                        .filter(function(line) { return line.length > 0; });

                    for (let i = 0; i < lines.length; i++) {
                        const clean = lines[i]
                            .replace(/^[-*]\\s*/, "")
                            .trim();

                        if (clean
                                && clean.toLowerCase() !== "bottles")
                            names.push(clean);
                    }
                }

                appControlWindow.bottleNames = names;
                appControlWindow.selectedBottleName =
                    names.length > 0 ? names[0] : "";
                appControlWindow.bottlesLoading = false;

                console.log(
                    "AppControl: Bottles discovered:",
                    names.join(", ")
                );
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const message = String(text || "").trim();

                if (message) {
                    appControlWindow.bottlesError = message;
                    console.log("AppControl: Bottles list:", message);
                }

                appControlWindow.bottlesLoading = false;
            }
        }
    }

    // ============================================================
    // REAL APPLICATION MODEL
    // ============================================================

    ScriptModel {
        id: filteredApps

        values: {
            const query = searchInput.text.trim().toLowerCase();

            if (appControlWindow.appSourceMode
                    === appControlWindow.appSourceHidden) {
                const hidden = [];

                for (let i = 0;
                     i < appControlWindow.runAllCommands.length;
                     i++) {
                    const command =
                        String(appControlWindow.runAllCommands[i] || "").trim();

                    if (!command)
                        continue;

                    if (query.length > 0
                            && command.toLowerCase().indexOf(query) === -1)
                        continue;

                    hidden.push(
                        appControlWindow.hiddenCommandRecord(command)
                    );
                }

                hidden.sort(function(a, b) {
                    return String(a.name || "").localeCompare(
                        String(b.name || "")
                    );
                });

                return hidden;
            }

            const apps = [...DesktopEntries.applications.values];

            const filtered = apps.filter(function (entry) {
                if (query.length === 0)
                    return true;

                const haystack =
                    ((entry.name || "") + " "
                     + (entry.genericName || "") + " "
                     + (entry.comment || "") + " "
                     + (entry.keywords || "") + " "
                     + appControlWindow.appSourceLabel(entry)).toLowerCase();

                return haystack.indexOf(query) !== -1;
            });

            filtered.sort(function (a, b) {
                const aFavorite = appControlWindow.isFavorite(a);
                const bFavorite = appControlWindow.isFavorite(b);

                if (aFavorite !== bFavorite)
                    return aFavorite ? -1 : 1;

                const nameCompare =
                    String(a.name || "").localeCompare(
                        String(b.name || "")
                    );

                if (nameCompare !== 0)
                    return nameCompare;

                const aMatches =
                    appControlWindow.appEntryMatchesSelectedSource(a);
                const bMatches =
                    appControlWindow.appEntryMatchesSelectedSource(b);

                if (aMatches !== bMatches)
                    return aMatches ? -1 : 1;

                return appControlWindow.appEntryKey(a).localeCompare(
                    appControlWindow.appEntryKey(b)
                );
            });

            return filtered;
        }
    }

    ScriptModel {
        id: runResults

        values: {
            const queryRaw = searchInput.text.trim();
            const query = queryRaw.toLowerCase();
            const rows = [];
            const seen = {};

            function addCommand(command, origin, prefixMode) {
                const normalized = String(command || "").trim();
                const resolvedPrefix =
                    appControlWindow.normalizeRunPrefixMode(prefixMode);

                if (!normalized)
                    return;

                const dedupeKey =
                    String(resolvedPrefix) + "\u0000" + normalized;

                if (seen[dedupeKey])
                    return;

                if (query.length > 0
                        && normalized.toLowerCase().indexOf(query) === -1
                        && normalized !== queryRaw)
                    return;

                seen[dedupeKey] = true;
                rows.push(
                    appControlWindow.runRecord(
                        normalized,
                        origin,
                        resolvedPrefix
                    )
                );
            }

            // ----------------------------------------------------
            // ALL
            // ----------------------------------------------------
            //
            // A separate Rofi-run-style command catalog. Nothing from this
            // giant list is injected into USER/history mode.
            if (appControlWindow.runListMode
                    === appControlWindow.runListAll) {
                for (let i = 0;
                     i < appControlWindow.runAllCommands.length;
                     i++) {
                    addCommand(
                        appControlWindow.runAllCommands[i],
                        "SYSTEM",
                        appControlWindow.runPrefixMode
                    );
                }

                // SYSTEM mirrors APPS favorite sorting: starred commands
                // pin to the top immediately; both groups stay alphabetic.
                //
                // Reading favoriteKeys here creates a direct ScriptModel
                // dependency so clicking a star causes the list to reorder.
                const favoriteKeys = favoriteStore.favoriteKeys;

                rows.sort(function(a, b) {
                    const aKey = appControlWindow.favoriteKeyFor(
                        a,
                        appControlWindow.runModeIndex
                    );
                    const bKey = appControlWindow.favoriteKeyFor(
                        b,
                        appControlWindow.runModeIndex
                    );

                    const aFavorite =
                        favoriteKeys.indexOf(aKey) !== -1;
                    const bFavorite =
                        favoriteKeys.indexOf(bKey) !== -1;

                    if (aFavorite !== bFavorite)
                        return aFavorite ? -1 : 1;

                    return String(a.name || a.label || "")
                        .localeCompare(
                            String(b.name || b.label || "")
                        );
                });

                return rows;
            }

            // ----------------------------------------------------
            // TERMINAL
            // ----------------------------------------------------
            //
            // Real shell history, newest first. addCommand() de-duplicates
            // repeated commands while preserving the newest occurrence.
            if (appControlWindow.runListMode
                    === appControlWindow.runListTerminal) {
                for (let i = 0;
                     i < appControlWindow.runTerminalHistory.length;
                     i++) {
                    addCommand(
                        appControlWindow.runTerminalHistory[i],
                        "TERMINAL",
                        appControlWindow.runPrefixMode
                    );
                }

                return rows;
            }

            // ----------------------------------------------------
            // USER / HISTORY
            // ----------------------------------------------------

            // The exact typed command is always first and takes the prefix
            // currently selected in the bottom RUN prefix selector.
            if (queryRaw.length > 0) {
                addCommand(
                    queryRaw,
                    "INPUT",
                    appControlWindow.runPrefixMode
                );
            }

            // Saved RUN favorites stay above ordinary history and preserve
            // whether they were saved as NORMAL or KITTY.
            for (let i = 0; i < favoriteStore.favoriteKeys.length; i++) {
                const favoriteData =
                    appControlWindow.runFavoriteDataFromKey(
                        favoriteStore.favoriteKeys[i]
                    );

                if (favoriteData) {
                    addCommand(
                        favoriteData.commandText,
                        "FAVORITE",
                        favoriteData.prefixMode
                    );
                }
            }

            // Most-recent command history follows and also preserves prefix.
            for (let i = 0; i < appControlWindow.runHistory.length; i++) {
                const historyEntry = appControlWindow.runHistory[i];

                if (typeof historyEntry === "object") {
                    addCommand(
                        historyEntry.commandText,
                        "HISTORY",
                        historyEntry.prefixMode
                    );
                } else {
                    // Compatibility with an already-running older instance.
                    addCommand(
                        historyEntry,
                        "HISTORY",
                        appControlWindow.runPrefixNormal
                    );
                }
            }

            return rows;
        }
    }

    ScriptModel {
        id: windowResults

        values: {
            const query = searchInput.text.trim().toLowerCase();

            if (appControlWindow.windowListMode
                    === appControlWindow.windowListTabs) {
                let tabRows = appControlWindow.appTabs.slice();
                const tabDiagnostics =
                    Array.isArray(appControlWindow.appTabsDiagnostics)
                    ? appControlWindow.appTabsDiagnostics
                    : [];
                const tabDiagnosticText =
                    tabDiagnostics.length > 0
                    ? tabDiagnostics.join(" • ")
                    : appControlWindow.appTabsBridgeError.length > 0
                    ? appControlWindow.appTabsBridgeError
                    : appControlWindow.appTabsError.length > 0
                    ? appControlWindow.appTabsError
                    : "NO PROVIDER DIAGNOSTICS YET";

                if (tabRows.length === 0) {
                    tabRows = [{
                        _tabRecord: true,
                        _tabUnavailable: true,
                        id: "tab-status",
                        path: "",
                        name:
                            appControlWindow.appTabsLoading
                            ? "SCANNING TABS..."
                            : "TABS DIAGNOSTICS",
                        tabTitle:
                            appControlWindow.appTabsLoading
                            ? "SCANNING TABS..."
                            : "TABS DIAGNOSTICS",
                        appName: tabDiagnosticText,
                        windowName: "",
                        selected: false,
                        provider: "DIAGNOSTIC"
                    }];
                } else if (tabDiagnostics.length > 0) {
                    tabRows.push({
                        _tabRecord: true,
                        _tabUnavailable: true,
                        id: "tab-diagnostics",
                        path: "",
                        name: "TABS DIAGNOSTICS",
                        tabTitle: "TABS DIAGNOSTICS",
                        appName: tabDiagnosticText,
                        windowName: "",
                        selected: false,
                        provider: "DIAGNOSTIC"
                    });
                }

                const visibleTabs = tabRows.filter(function(entry) {
                    if (query.length === 0)
                        return true;

                    const haystack =
                        ((entry.tabTitle || entry.name || "") + " "
                         + (entry.appName || "") + " "
                         + (entry.windowName || "") + " "
                         + (entry.provider || "")).toLowerCase();

                    return haystack.indexOf(query) !== -1;
                });

                visibleTabs.sort(function(a, b) {
                    if (!!a._tabUnavailable !== !!b._tabUnavailable)
                        return a._tabUnavailable ? 1 : -1;

                    if (!!a.selected !== !!b.selected)
                        return a.selected ? -1 : 1;

                    const appCompare =
                        String(a.appName || "").localeCompare(
                            String(b.appName || "")
                        );

                    if (appCompare !== 0)
                        return appCompare;

                    return String(a.tabTitle || a.name || "")
                        .localeCompare(
                            String(b.tabTitle || b.name || "")
                        );
                });

                return visibleTabs;
            }

            const rows = appControlWindow.swayWindows.filter(
                function(entry) {
                    if (query.length === 0)
                        return true;

                    const haystack =
                        ((entry.name || "") + " "
                         + (entry.appId || "") + " "
                         + (entry.className || "") + " "
                         + (entry.instance || "") + " "
                         + (entry.workspace || "") + " "
                         + String(entry.pid || "")).toLowerCase();

                    return haystack.indexOf(query) !== -1;
                }
            );

            rows.sort(function(a, b) {
                if (!!a.focused !== !!b.focused)
                    return a.focused ? -1 : 1;

                const workspaceCompare =
                    String(a.workspace || "").localeCompare(
                        String(b.workspace || ""),
                        undefined,
                        { numeric: true }
                    );

                if (workspaceCompare !== 0)
                    return workspaceCompare;

                return appControlWindow.resultDisplayName(
                    a,
                    appControlWindow.windowsModeIndex
                ).localeCompare(
                    appControlWindow.resultDisplayName(
                        b,
                        appControlWindow.windowsModeIndex
                    )
                );
            });

            return rows;
        }
    }

    ScriptModel {
        id: killTaskResults

        values: {
            const query = searchInput.text.trim().toLowerCase();

            const rows = appControlWindow.taskRows.filter(
                function(entry) {
                    if (query.length === 0)
                        return true;

                    const haystack =
                        ((entry.comm || "") + " "
                         + (entry.args || "") + " "
                         + (entry.user || "") + " "
                         + String(entry.pid || "") + " "
                         + String(entry.ppid || "") + " "
                         + (entry.state || "")).toLowerCase();

                    return haystack.indexOf(query) !== -1;
                }
            );

            rows.sort(function(a, b) {
                const cpuDelta =
                    Number(b.cpu || 0) - Number(a.cpu || 0);

                if (Math.abs(cpuDelta) > 0.001)
                    return cpuDelta;

                const memDelta =
                    Number(b.mem || 0) - Number(a.mem || 0);

                if (Math.abs(memDelta) > 0.001)
                    return memDelta;

                return Number(a.pid || 0) - Number(b.pid || 0);
            });

            return rows;
        }
    }

    ScriptModel {
        id: thermalResults

        values: {
            const query = searchInput.text.trim().toLowerCase();
            const favoriteKeys = favoriteStore.favoriteKeys;

            const sourceRows =
                appControlWindow.thermalViewMode
                === appControlWindow.thermalViewFans
                ? appControlWindow.fanRows
                : appControlWindow.thermalRows;

            const rows = sourceRows.filter(function(entry) {
                if (query.length === 0)
                    return true;

                const haystack =
                    ((entry.name || "") + " "
                     + (entry.label || "") + " "
                     + (entry.chip || "") + " "
                     + (entry.role || "") + " "
                     + (entry.source || "")).toLowerCase();

                return haystack.indexOf(query) !== -1;
            });

            rows.sort(function(a, b) {
                const aFavorite =
                    favoriteKeys.indexOf(
                        appControlWindow.favoriteKeyFor(
                            a,
                            appControlWindow.thermalModeIndex
                        )
                    ) !== -1;
                const bFavorite =
                    favoriteKeys.indexOf(
                        appControlWindow.favoriteKeyFor(
                            b,
                            appControlWindow.thermalModeIndex
                        )
                    ) !== -1;

                if (aFavorite !== bFavorite)
                    return aFavorite ? -1 : 1;

                if (appControlWindow.thermalViewMode
                        === appControlWindow.thermalViewFans)
                    return Number(b.rpm || 0) - Number(a.rpm || 0);

                return Number(b.tempC || 0) - Number(a.tempC || 0);
            });

            return rows;
        }
    }

    ScriptModel {
        id: systemResults

        values: {
            const query = searchInput.text.trim().toLowerCase();
            const favoriteKeys = favoriteStore.favoriteKeys;

            const rows = appControlWindow.systemRows.filter(function(entry) {
                if (query.length === 0)
                    return true;

                const haystack =
                    ((entry.name || "") + " "
                     + (entry.category || "") + " "
                     + (entry.role || "") + " "
                     + (entry.metric || "") + " "
                     + (entry.secondary || "") + " "
                     + (entry.detail || "")).toLowerCase();

                return haystack.indexOf(query) !== -1;
            });

            rows.sort(function(a, b) {
                const aFavorite =
                    favoriteKeys.indexOf(
                        appControlWindow.favoriteKeyFor(
                            a,
                            appControlWindow.systemModeIndex
                        )
                    ) !== -1;
                const bFavorite =
                    favoriteKeys.indexOf(
                        appControlWindow.favoriteKeyFor(
                            b,
                            appControlWindow.systemModeIndex
                        )
                    ) !== -1;

                if (aFavorite !== bFavorite)
                    return aFavorite ? -1 : 1;

                return String(a.name || "").localeCompare(
                    String(b.name || "")
                );
            });

            return rows;
        }
    }

    ScriptModel {
        id: favoriteResults

        values: {
            const query = searchInput.text.trim().toLowerCase();
            const inCombi = appControlWindow.favoritesScopeMode
                            === appControlWindow.favoritesScopeCombi;
            const thermalSnapshot = inCombi ? [] : appControlWindow.thermalRows;
            const fanSnapshot = inCombi ? [] : appControlWindow.fanRows;
            const systemSnapshot = inCombi ? [] : appControlWindow.systemRows;
            const taskSnapshot = inCombi ? [] : appControlWindow.taskRows;
            const rows = [];
            const seen = ({});
            const preferredAppKeys = ({});
            const preferredRunKeys = ({});

            function pushUnique(record) {
                if (!record)
                    return;

                const key = String(record._favoriteKey || record.id || record.name || "");
                if (!key || seen[key])
                    return;

                seen[key] = true;
                rows.push(record);
            }

            if (inCombi) {
                const cached = appControlWindow.combiStaticCatalog.concat(
                    appControlWindow.combiTaskCatalog
                );
                for (let i = 0; i < cached.length; i++)
                    pushUnique(cached[i]);
            } else {
            for (let i = 0; i < favoriteStore.favoriteDetailActionKeys.length; i++) {
                const raw = String(favoriteStore.favoriteDetailActionKeys[i] || "");
                const first = raw.indexOf("|");
                const second = first >= 0 ? raw.indexOf("|", first + 1) : -1;
                if (first < 0 || second < 0)
                    continue;

                const type = raw.slice(0, first);
                let context = "";
                try {
                    context = decodeURIComponent(raw.slice(first + 1, second));
                } catch (error) {
                    continue;
                }

                if (type === "app") preferredAppKeys[context] = true;
                else if (type === "run") preferredRunKeys[context] = true;
            }

            const apps = [...DesktopEntries.applications.values];
            for (let i = 0; i < apps.length; i++) {
                const entry = apps[i];
                const appKey = appControlWindow.appEntryKey(entry);
                if (appControlWindow.isFavoriteItem(entry, appControlWindow.appsModeIndex)
                        || !!preferredAppKeys[appKey]) {
                    pushUnique(appControlWindow.favoriteRecordForApp(entry));
                }
            }

            const runKeys = ({});
            for (let i = 0; i < favoriteStore.favoriteKeys.length; i++) {
                const key = String(favoriteStore.favoriteKeys[i] || "");
                if (appControlWindow.runFavoriteDataFromKey(key)) runKeys[key] = true;
            }
            for (const key in preferredRunKeys) runKeys[key] = true;
            for (const key in runKeys) {
                const data = appControlWindow.runFavoriteDataFromKey(key);
                if (data) pushUnique(appControlWindow.favoriteRecordForRunCommand(data.commandText, data.prefixMode));
            }

            const hiddenKeys = ({});
            for (let i = 0; i < favoriteStore.favoriteKeys.length; i++) {
                const key = String(favoriteStore.favoriteKeys[i] || "");
                if (key.indexOf("hidden:") === 0) hiddenKeys[key] = true;
            }
            for (const key in preferredAppKeys) {
                if (key.indexOf("hidden:") === 0) hiddenKeys[key] = true;
            }
            for (const key in hiddenKeys) {
                const command = key.slice(7);
                if (command) pushUnique(appControlWindow.favoriteRecordForApp(appControlWindow.hiddenCommandRecord(command)));
            }

            const thermalItems = thermalSnapshot.concat(fanSnapshot);
            for (let i = 0; i < thermalItems.length; i++) {
                const entry = thermalItems[i];
                if (appControlWindow.isFavoriteItem(entry, appControlWindow.thermalModeIndex)
                        || appControlWindow.monitorEntryHasBoxFavorite(entry, appControlWindow.thermalModeIndex)) {
                    pushUnique(appControlWindow.favoriteRecordForModeItem(entry, appControlWindow.thermalModeIndex));
                }
            }

            for (let i = 0; i < systemSnapshot.length; i++) {
                const entry = systemSnapshot[i];
                if (appControlWindow.isFavoriteItem(entry, appControlWindow.systemModeIndex)
                        || appControlWindow.monitorEntryHasBoxFavorite(entry, appControlWindow.systemModeIndex)) {
                    pushUnique(appControlWindow.favoriteRecordForModeItem(entry, appControlWindow.systemModeIndex));
                }
            }

            const windows = windowResults.values;
            for (let i = 0; i < windows.length; i++) {
                const entry = windows[i];
                if (appControlWindow.isFavoriteItem(entry, appControlWindow.windowsModeIndex)) {
                    pushUnique(appControlWindow.favoriteRecordForModeItem(entry, appControlWindow.windowsModeIndex));
                }
            }

            const taskIdentities = ({});

            for (let i = 0; i < favoriteStore.favoriteKeys.length; i++) {
                const identity = appControlWindow.taskIdentityFromFavoriteKey(
                    favoriteStore.favoriteKeys[i]
                );
                if (identity)
                    taskIdentities[identity] = true;
            }

            for (let i = 0; i < favoriteStore.favoriteTaskMetricKeys.length; i++) {
                const data = appControlWindow.taskMetricFavoriteData(
                    favoriteStore.favoriteTaskMetricKeys[i]
                );
                if (data && data.identity)
                    taskIdentities[data.identity] = true;
            }

            for (const identity in taskIdentities) {
                let live = null;
                for (let i = 0; i < taskSnapshot.length; i++) {
                    if (appControlWindow.taskPersistentIdentity(taskSnapshot[i]) === identity) {
                        live = taskSnapshot[i];
                        break;
                    }
                }
                pushUnique(
                    appControlWindow.favoriteRecordForTaskIdentity(
                        identity,
                        live
                    )
                );
            }

            }

            const visibleRows = rows.filter(function(entry) {
                if (appControlWindow.favoritesFilterMode
                        !== appControlWindow.favoritesFilterAll
                        && Number(entry._sourceModeIndex)
                           !== appControlWindow.favoritesFilterMode)
                    return false;

                if (query.length === 0)
                    return true;

                const source = appControlWindow.favoriteSourceItem(entry) || entry;
                const haystack = inCombi && entry._combiSearchText
                                 ? entry._combiSearchText
                                 : ((entry.name || "") + " "
                                    + (entry.genericName || "") + " "
                                    + (entry.comment || "") + " "
                                    + (entry.keywords || "") + " "
                                    + (source.args || "") + " "
                                    + (source.commandText || "") + " "
                                    + (source.appName || "") + " "
                                    + (source.windowName || "") + " "
                                    + (source.tabTitle || "") + " "
                                    + (source.category || "") + " "
                                    + (source.role || "") + " "
                                    + (source.metric || "") + " "
                                    + String(source.pid || "")).toLowerCase();
                return haystack.indexOf(query) !== -1;
            });

            if (inCombi && query.length === 0) {
                // The cache is already source/name ordered. Avoid an O(n log n)
                // sort of the entire command universe every time FAVORITES is
                // opened; a linear stable partition is enough to pin stars.
                const pinned = [];
                const ordinary = [];
                for (let i = 0; i < visibleRows.length; i++) {
                    const entry = visibleRows[i];
                    if (appControlWindow.isFavoriteItem(
                            entry, appControlWindow.favoritesModeIndex))
                        pinned.push(entry);
                    else
                        ordinary.push(entry);
                }
                return pinned.concat(ordinary);
            }

            visibleRows.sort(function(a, b) {
                if (inCombi) {
                    const aFavorite = appControlWindow.isFavoriteItem(
                        a, appControlWindow.favoritesModeIndex
                    );
                    const bFavorite = appControlWindow.isFavoriteItem(
                        b, appControlWindow.favoritesModeIndex
                    );
                    if (aFavorite !== bFavorite)
                        return aFavorite ? -1 : 1;
                }

                const modeCompare = a._sourceModeIndex - b._sourceModeIndex;
                if (modeCompare !== 0) return modeCompare;
                return String(a.name || "").localeCompare(String(b.name || ""));
            });

            return visibleRows;
        }
    }    function resultCount() {
        if (selectedModeIndex === favoritesModeIndex)
            return favoriteResults.values.length;

        if (selectedModeIndex === appsModeIndex)
            return filteredApps.values.length;

        if (selectedModeIndex === runModeIndex)
            return runResults.values.length;

        if (selectedModeIndex === windowsModeIndex)
            return windowResults.values.length;

        if (selectedModeIndex === thermalModeIndex)
            return thermalResults.values.length;

        if (selectedModeIndex === killModeIndex)
            return killTaskResults.values.length;

        if (selectedModeIndex === systemModeIndex)
            return systemResults.values.length;

        return placeholderResults.length;
    }

    function selectedResult() {
        if (selectedResultIndex < 0 || selectedResultIndex >= resultCount())
            return null;

        if (selectedModeIndex === favoritesModeIndex)
            return favoriteResults.values[selectedResultIndex];

        if (selectedModeIndex === appsModeIndex)
            return filteredApps.values[selectedResultIndex];

        if (selectedModeIndex === runModeIndex)
            return runResults.values[selectedResultIndex];

        if (selectedModeIndex === windowsModeIndex)
            return windowResults.values[selectedResultIndex];

        if (selectedModeIndex === thermalModeIndex)
            return thermalResults.values[selectedResultIndex];

        if (selectedModeIndex === killModeIndex)
            return killTaskResults.values[selectedResultIndex];

        if (selectedModeIndex === systemModeIndex)
            return systemResults.values[selectedResultIndex];

        return placeholderResults[selectedResultIndex];
    }

    function resultStableKey(entry) {
        if (!entry)
            return "";

        const source = favoriteSourceItem(entry) || entry;

        if (entry._favoriteKey)
            return "favorite:" + String(entry._favoriteKey);

        if (source && source._tabRecord)
            return "tab:" + String(
                source.id || source.path || source.tabTitle || source.name || ""
            );

        if (source && source._taskRecord) {
            const identity = taskPersistentIdentity(entry);
            if (identity)
                return "task:" + identity;
        }

        return String(
            (source && (source.id || source.path))
            || entry.id
            || entry.name
            || ""
        );
    }

    function currentResultValuesForStability() {
        if (selectedModeIndex === favoritesModeIndex)
            return favoriteResults.values;
        if (selectedModeIndex === appsModeIndex)
            return filteredApps.values;
        if (selectedModeIndex === runModeIndex)
            return runResults.values;
        if (selectedModeIndex === windowsModeIndex)
            return windowResults.values;
        if (selectedModeIndex === thermalModeIndex)
            return thermalResults.values;
        if (selectedModeIndex === killModeIndex)
            return killTaskResults.values;
        if (selectedModeIndex === systemModeIndex)
            return systemResults.values;

        return placeholderResults;
    }

    function captureResultListState() {
        return {
            mode: selectedModeIndex,
            favoritesScope: favoritesScopeMode,
            favoritesFilter: favoritesFilterMode,
            windowListMode: windowListMode,
            selectedIndex: selectedResultIndex,
            selectedKey: resultStableKey(selectedResult()),
            contentY: Number(resultList.contentY || 0)
        };
    }

    function restoreResultListState(state) {
        if (!state)
            return;

        Qt.callLater(function() {
            // Give ScriptModel one turn to publish the replacement values.
            Qt.callLater(function() {
                if (appControlWindow.selectedModeIndex !== state.mode)
                    return;

                if (state.mode === appControlWindow.favoritesModeIndex
                        && (appControlWindow.favoritesScopeMode
                            !== state.favoritesScope
                            || appControlWindow.favoritesFilterMode
                               !== state.favoritesFilter))
                    return;

                if (state.mode === appControlWindow.windowsModeIndex
                        && appControlWindow.windowListMode
                           !== state.windowListMode)
                    return;

                const values =
                    appControlWindow.currentResultValuesForStability();
                let targetIndex = -1;

                if (state.selectedKey) {
                    for (let i = 0; i < values.length; i++) {
                        if (appControlWindow.resultStableKey(values[i])
                                === state.selectedKey) {
                            targetIndex = i;
                            break;
                        }
                    }
                }

                if (targetIndex < 0 && values.length > 0)
                    targetIndex = Math.min(
                        Math.max(0, Number(state.selectedIndex || 0)),
                        values.length - 1
                    );

                appControlWindow.selectedResultIndex =
                    values.length > 0 ? targetIndex : -1;

                const maxY = Math.max(
                    0,
                    Number(resultList.contentHeight || 0)
                    - Number(resultList.height || 0)
                );

                resultList.contentY = Math.max(
                    0,
                    Math.min(Number(state.contentY || 0), maxY)
                );
            });
        });
    }

    function tabRowsSignature(rows) {
        const normalized = [];

        for (let i = 0; i < rows.length; i++) {
            const row = rows[i] || ({});
            normalized.push([
                String(row.provider || ""),
                String(row.id || row.path || ""),
                String(row.tabTitle || row.name || ""),
                !!row.selected
            ]);
        }

        return JSON.stringify(normalized);
    }

    function updateAppTabsStable(nextTabs) {
        if (!Array.isArray(nextTabs))
            return;

        const signature = tabRowsSignature(nextTabs);

        // The bridge emits heartbeat snapshots even when the tab set did not
        // change. Reassigning appTabs on every heartbeat was rebuilding the
        // ScriptModel and forcing keyboard navigation back toward the top.
        if (signature === appTabsDataSignature)
            return;

        const state =
            selectedModeIndex === windowsModeIndex
            && windowListMode === windowListTabs
            ? captureResultListState()
            : null;

        appTabsDataSignature = signature;
        appTabs = nextTabs;

        if (state)
            restoreResultListState(state);
    }

    function resetResultSelection() {
        selectedResultIndex = resultCount() > 0 ? 0 : -1;

        if (selectedResultIndex >= 0)
            resultList.positionViewAtIndex(selectedResultIndex, ListView.Beginning);

        scheduleRunKillProbe();
    }


    function appEntryKey(entry) {
        if (!entry)
            return "";

        if (entry.id)
            return String(entry.id);

        return String(entry.name || "");
    }

    function rememberCurrentAppSelection() {
        if (!selectedResultIsApplication())
            return;

        const entry = selectedResult();

        if (entry)
            rememberedAppKey = appEntryKey(entry);
    }

    function restoreRememberedAppSelection() {
        const apps = currentApplicationValues();

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

        saveInputForMode(selectedModeIndex);

        if (selectedResultIsApplication())
            rememberCurrentAppSelection();

        selectedModeIndex = newModeIndex;
        modeRailCursorIndex = newModeIndex;
        restoreInputForMode(selectedModeIndex);

        if (selectedModeIndex === appsModeIndex)
            restoreRememberedAppSelection();
        else
            resetResultSelection();

        if (selectedModeIndex === windowsModeIndex) {
            refreshWindowState();

            if (windowListMode === windowListTabs)
                refreshAppTabs();
        }

        if (selectedModeIndex === thermalModeIndex
                || selectedModeIndex === systemModeIndex)
            refreshKillMonitor();

        if (selectedModeIndex === killModeIndex
                || (selectedModeIndex === favoritesModeIndex
                    && (hasTaskFavorites()
                        || favoritesScopeMode === favoritesScopeCombi)))
            refreshTaskManager();

        if (selectedModeIndex === favoritesModeIndex
                && favoritesScopeMode === favoritesScopeCombi)
            ensureCombiCatalog();

        detailFocused =
            preservePane
            && selectedResultSupportsDetail()
            ? wasDetailFocused
            : false;

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

        if (selectedResultIsApplication())
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


    function detailFavoriteContextKey() {
        const entry = selectedResult();

        if (!entry)
            return "";

        if (selectedResultIsApplication()) {
            const appEntry = favoriteSourceItem(entry) || entry;
            const appKey = appEntryKey(appEntry);

            return appKey
                   ? "app|" + encodeURIComponent(appKey)
                   : "";
        }

        if (selectedResultIsRun()) {
            const runEntry = favoriteSourceItem(entry) || entry;
            const runKey = favoriteKeyFor(runEntry, runModeIndex);

            return runKey
                   ? "run|" + encodeURIComponent(runKey)
                   : "";
        }

        return "";
    }

    function detailActionStableId(actionIndex) {
        const entry = selectedResult();

        if (!entry || actionIndex < 0)
            return "";

        if (selectedResultIsRun()) {
            if (actionIndex === 0)
                return "run";
            if (actionIndex === 1)
                return "kitty";
            if (actionIndex === 2)
                return "float";
            if (actionIndex === 3)
                return "fullscreen";
            if (actionIndex === 4)
                return "toolbox";
            if (actionIndex === 5)
                return "kill";

            return "";
        }

        if (!selectedResultIsApplication())
            return "";

        const appEntry = favoriteSourceItem(entry) || entry;
        const desktopCount = appEntry.actions.length;

        if (actionIndex === 0)
            return "launch";

        if (appEntry._hiddenCommand) {
            if (actionIndex === 1) return "hidden-kitty";
            if (actionIndex === 2) return "hidden-float";
            if (actionIndex === 3) return "hidden-fullscreen";
            if (actionIndex === 4) return "hidden-bottles";
            if (actionIndex === 5) return "hidden-toolbox";
            if (actionIndex === 6) return "hidden-kill";
            return "";
        }

        if (actionIndex === desktopCount + 1)
            return "bottles";

        if (actionIndex === desktopCount + 2)
            return "toolbox";

        if (actionIndex === desktopCount + 3)
            return "kill";

        const desktopIndex = actionIndex - 1;

        if (desktopIndex < 0 || desktopIndex >= desktopCount)
            return "";

        const action = appEntry.actions[desktopIndex];

        return "desktop|"
               + encodeURIComponent(
                     String(
                         action && action.name
                         ? action.name
                         : desktopIndex
                     )
                 );
    }

    function detailFavoriteKeyFor(actionIndex) {
        const context = detailFavoriteContextKey();
        const actionId = detailActionStableId(actionIndex);

        if (!context || !actionId)
            return "";

        return context + "|" + actionId;
    }

    function isDetailActionFavorite(actionIndex) {
        const key = detailFavoriteKeyFor(actionIndex);

        return key.length > 0
               && favoriteStore.favoriteDetailActionKeys.indexOf(key) !== -1;
    }

    function detailActionAvailable(actionIndex) {
        const entry = selectedResult();

        if (!entry || actionIndex < 0)
            return false;

        if (selectedResultIsRun()) {
            const runEntry = favoriteSourceItem(entry) || entry;
            const command =
                String(runCommandText(runEntry) || "").trim();

            if (actionIndex === 4)
                return command.length > 0;

            if (actionIndex === 5)
                return runKillAvailable;

            return actionIndex >= 0 && actionIndex < 4;
        }

        if (selectedResultIsTab())
            return actionIndex >= 0
                   && actionIndex < selectedTabControls().length;

        if (selectedResultIsTask())
            return actionIndex === 0
                   && Number(entry.pid || 0) > 1;

        if (!selectedResultIsApplication())
            return false;

        const appEntry = favoriteSourceItem(entry) || entry;
        const desktopCount = appEntry.actions.length;

        if (actionIndex === 0) {
            return appEntryLaunchableForCurrentContext(appEntry);
        }

        if (appEntry._hiddenCommand) {
            if (actionIndex >= 1 && actionIndex <= 3) return true;
            if (actionIndex === 4) return selectedBottleName.length > 0 && !bottlesLoading;
            if (actionIndex === 5) return String(appEntry.name || "").trim().length > 0;
            if (actionIndex === 6) return String(appEntry.name || "").trim().length > 0;
            return false;
        }

        if (actionIndex === desktopCount + 1) {
            return selectedBottleName.length > 0
                   && !bottlesLoading;
        }

        if (actionIndex === desktopCount + 2) {
            return appToolboxCommandTokens(appEntry).length > 0;
        }

        if (actionIndex === desktopCount + 3) {
            return selectedApplicationKillPids().length > 0;
        }

        const desktopIndex = actionIndex - 1;

        return desktopIndex >= 0
               && desktopIndex < desktopCount;
    }

    function favoriteDetailActionIndex() {
        const count = detailActionCount();

        for (let i = 0; i < count; i++) {
            if (isDetailActionFavorite(i))
                return i;
        }

        return -1;
    }

    function toggleDetailActionFavorite(actionIndex) {
        if (!detailActionAvailable(actionIndex))
            return;

        const context = detailFavoriteContextKey();
        const key = detailFavoriteKeyFor(actionIndex);

        if (!context || !key)
            return;

        const prefix = context + "|";
        const oldKeys = favoriteStore.favoriteDetailActionKeys;
        const next = [];

        // Keep favorites belonging to every OTHER app/command.
        for (let i = 0; i < oldKeys.length; i++) {
            const existing = String(oldKeys[i]);

            if (existing.indexOf(prefix) !== 0)
                next.push(existing);
        }

        const wasFavorite = oldKeys.indexOf(key) !== -1;

        // Clicking a different star replaces the old preferred action.
        // Clicking the same filled star clears it.
        if (!wasFavorite)
            next.push(key);

        favoriteStore.favoriteDetailActionKeys = next;

        // Force a fresh detail-selection pass after the JsonAdapter property
        // has changed. This makes the favorite immediately become the keyboard
        // default instead of waiting for the user to leave/re-enter the pane.
        Qt.callLater(function() {
            if (!wasFavorite) {
                appControlWindow.selectedDetailActionIndex = actionIndex;
                appControlWindow.detailFocused = true;
            } else {
                appControlWindow.resetDetailActionSelection();
            }

            appControlWindow.ensureDetailActionVisible();
        });

        console.log(
            "AppControl: detail favorite",
            wasFavorite ? "CLEARED" : "SET",
            key,
            "stored-count",
            favoriteStore.favoriteDetailActionKeys.length
        );
    }

    function detailActionCount() {
        const entry = selectedResult();

        if (!entry)
            return 0;

        if (selectedResultIsRun())
            return 6;

        if (selectedResultIsWindow())
            return 7;

        if (selectedResultIsTab())
            return selectedTabControls().length;

        if (selectedResultIsTask())
            return 1;

        if (!selectedResultIsApplication())
            return 0;

        const appEntry = favoriteSourceItem(entry) || entry;

        if (appEntry._hiddenCommand)
            return 7; // LAUNCH + KITTY + FLOAT + FULLSCREEN + BOTTLES + TOOLBOX + KILL

        // Primary LAUNCH + desktop actions + BOTTLES + TOOLBOX + KILL.
        return 4 + appEntry.actions.length;
    }

    function resetDetailActionSelection() {
        const count = detailActionCount();
        const favoriteIndex = favoriteDetailActionIndex();

        selectedDetailActionIndex =
            favoriteIndex >= 0
            && favoriteIndex < count
            && detailActionAvailable(favoriteIndex)
            ? favoriteIndex
            : count > 0
            ? 0
            : -1;

        if (detailFocused && selectedResultSupportsDetail())
            detailFlickable.contentY = 0;

        ensureDetailActionVisible();
    }

    function detailActionItem(actionIndex) {
        if (selectedResultIsRun()) {
            if (actionIndex === 0)
                return runAction;

            if (actionIndex === 1)
                return runKittyAction;

            if (actionIndex === 2)
                return runFloatAction;

            if (actionIndex === 3)
                return runFullscreenAction;

            if (actionIndex === 4)
                return runToolboxAction;

            if (actionIndex === 5)
                return runKillAction;

            return null;
        }

        if (selectedResultIsWindow()) {
            if (actionIndex >= 0 && actionIndex <= 4)
                return windowPrimaryActionsRepeater.itemAt(actionIndex);

            if (actionIndex === 5)
                return windowMuteAction;

            if (actionIndex === 6)
                return windowKillAction;

            return null;
        }

        if (selectedResultIsTab())
            return appTabControlsRepeater.itemAt(actionIndex);

        if (selectedResultIsTask()) {
            if (actionIndex === 0)
                return taskEndAction;

            return null;
        }

        if (!selectedResultIsApplication())
            return null;

        if (actionIndex === 0)
            return launchAction;

        const entry = selectedResult();
        const appEntry = favoriteSourceItem(entry) || entry;
        const desktopCount = appEntry ? appEntry.actions.length : 0;

        if (appEntry && appEntry._hiddenCommand) {
            if (actionIndex >= 1 && actionIndex <= 3)
                return hiddenActionsRepeater.itemAt(actionIndex - 1);
            if (actionIndex === 4) return hiddenBottleAction;
            if (actionIndex === 5) return hiddenToolboxAction;
            if (actionIndex === 6) return hiddenKillAction;
            return null;
        }

        if (actionIndex === desktopCount + 1)
            return appBottleAction;

        if (actionIndex === desktopCount + 2)
            return appToolboxAction;

        if (actionIndex === desktopCount + 3)
            return appKillAction;

        const desktopIndex = actionIndex - 1;

        if (desktopIndex < 0 || desktopIndex >= desktopCount)
            return null;

        return desktopActionsRepeater.itemAt(desktopIndex);
    }

    function ensureDetailActionVisible() {
        if (!detailFocused || !selectedResultSupportsDetail())
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

    function selectedApplicationKillPids() {
        if (!selectedResultIsApplication())
            return [];

        const windows = selectedAppWindows || [];
        const pids = [];

        for (let i = 0; i < windows.length; i++) {
            const pid = Number(windows[i].pid || 0);

            if (pid > 1 && pids.indexOf(pid) === -1)
                pids.push(pid);
        }

        return pids;
    }

    function terminateSelectedApplication() {
        const entry = selectedResult();

        if (!entry || !selectedResultIsApplication())
            return;

        const pids = selectedApplicationKillPids();

        if (pids.length === 0) {
            console.log(
                "AppControl: APP TERM no live PID:",
                appDisplayName(entry)
            );
            return;
        }

        const argv = ["kill", "-TERM"];

        for (let i = 0; i < pids.length; i++)
            argv.push(String(pids[i]));

        console.log(
            "AppControl: APP TERM",
            appDisplayName(entry),
            pids.join(",")
        );

        Quickshell.execDetached(argv);
        appKillRefreshTimer.restart();
    }

    Timer {
        id: appKillRefreshTimer

        interval: 360
        repeat: false

        onTriggered: {
            appControlWindow.refreshWindowState();
        }
    }

    function windowKey(entry) {
        if (!entry)
            return "";

        return String(entry.id || 0)
               + ":"
               + String(entry.pid || 0)
               + ":"
               + String(entry.appId || entry.className || entry.instance || "");
    }

    function isWindowOnSecondOutput(entry) {
        if (!entry || !entry.output)
            return false;

        return swayOutputNames.indexOf(String(entry.output)) === 1;
    }

    function runSwayWindowCommand(entry, command, closeMenuAfter) {
        if (!entry || !entry.id || !command)
            return;

        console.log(
            "AppControl: WINDOW",
            entry.id,
            command
        );

        Quickshell.execDetached([
            "swaymsg",
            "[con_id=" + String(entry.id) + "] " + command
        ]);

        if (closeMenuAfter) {
            menuOpen = false;
            return;
        }

        windowActionRefreshTimer.restart();
    }

    function focusSwayWindow(entry) {
        runSwayWindowCommand(entry, "focus", true);
    }

    function moveSwayWindowHere(entry) {
        runSwayWindowCommand(
            entry,
            "move container to workspace current, focus",
            false
        );
    }

    function toggleSwayWindowFloating(entry) {
        runSwayWindowCommand(entry, "floating toggle", false);
    }

    function toggleSwayWindowFullscreen(entry) {
        runSwayWindowCommand(entry, "fullscreen toggle", false);
    }

    function centerSwayWindow(entry) {
        // Centering only has useful geometry for a floating container.
        runSwayWindowCommand(
            entry,
            "floating enable, move position center",
            false
        );
    }

    function closeSwayWindow(entry) {
        // Sway's `kill` command is a compositor-level close request. This is
        // intentionally not SIGKILL; FORCE belongs in the dedicated KILL mode.
        runSwayWindowCommand(entry, "kill", false);
    }

    Timer {
        id: windowActionRefreshTimer

        interval: 240
        repeat: false

        onTriggered: {
            appControlWindow.refreshWindowState();
            appControlWindow.scheduleWindowAudioProbe();
        }
    }

    function windowPrimaryActionLabel(actionIndex) {
        if (actionIndex === 0)
            return "FOCUS";

        if (actionIndex === 1)
            return "MOVE HERE";

        if (actionIndex === 2)
            return "TOGGLE FLOATING";

        if (actionIndex === 3)
            return "TOGGLE CENTER";

        if (actionIndex === 4)
            return "TOGGLE FULLSCREEN";

        return "WINDOW ACTION";
    }

    function windowPrimaryActionIcon(actionIndex) {
        if (actionIndex === 0)
            return "(╭ರ_•́)";

        if (actionIndex === 1)
            return "જ⁀➴";

        if (actionIndex === 2)
            return "⊹ ࣪ ˖🕊⋆₊⊹";

        if (actionIndex === 3)
            return "🃁🂡🂱🃑";

        if (actionIndex === 4)
            return "🂡🂱🃑🂭🂽";

        return "•";
    }

    function activateWindowDetailAction(actionIndex) {
        const entry = selectedResult();

        if (!entry || !selectedResultIsWindow())
            return;

        if (actionIndex === 0) {
            focusSwayWindow(entry);
            return;
        }

        if (actionIndex === 1) {
            moveSwayWindowHere(entry);
            return;
        }

        if (actionIndex === 2) {
            toggleSwayWindowFloating(entry);
            return;
        }

        if (actionIndex === 3) {
            centerSwayWindow(entry);
            return;
        }

        if (actionIndex === 4) {
            toggleSwayWindowFullscreen(entry);
            return;
        }

        if (actionIndex === 5) {
            toggleSelectedWindowMute();
            return;
        }

        if (actionIndex === 6) {
            closeSwayWindow(entry);
            return;
        }
    }

    function windowAudioRawTokens(entry) {
        if (!entry)
            return [];

        return [
            entry.appId || "",
            entry.className || "",
            entry.instance || ""
        ];
    }

    function windowAudioTokens(entry) {
        const raw = windowAudioRawTokens(entry);
        const tokens = [];

        function addToken(value) {
            const normalized = normalizeAppToken(value);

            if (normalized.length >= 3
                    && tokens.indexOf(normalized) === -1)
                tokens.push(normalized);
        }

        for (let i = 0; i < raw.length; i++) {
            const value = String(raw[i] || "");

            addToken(value);

            // Wrapper ids such as brave-browser-stable commonly map to an
            // audio stream whose process binary is simply "brave".
            const parts = value.toLowerCase().split(/[^a-z0-9]+/);

            for (let p = 0; p < parts.length; p++) {
                const part = parts[p];

                if (part === "browser"
                        || part === "stable"
                        || part === "beta"
                        || part === "dev"
                        || part === "bin")
                    continue;

                if (part.length >= 4)
                    addToken(part);
            }
        }

        return tokens;
    }

    function audioPropertyTokens(properties) {
        if (!properties)
            return [];

        const raw = [
            properties["application.process.binary"] || "",
            properties["application.name"] || "",
            properties["application.id"] || "",
            properties["media.name"] || ""
        ];

        const tokens = [];

        for (let i = 0; i < raw.length; i++) {
            const normalized = normalizeAppToken(raw[i]);

            if (normalized.length >= 3
                    && tokens.indexOf(normalized) === -1)
                tokens.push(normalized);
        }

        return tokens;
    }

    function windowMatchesAudioSink(entry, sinkInput) {
        if (!entry || !sinkInput)
            return false;

        const props = sinkInput.properties || {};
        const processId =
            Number(props["application.process.id"] || 0);

        if (entry.pid && processId && Number(entry.pid) === processId)
            return true;

        const windowTokens = windowAudioTokens(entry);
        const audioTokens = audioPropertyTokens(props);

        for (let i = 0; i < windowTokens.length; i++) {
            for (let j = 0; j < audioTokens.length; j++) {
                if (tokensMatch(windowTokens[i], audioTokens[j]))
                    return true;
            }
        }

        return false;
    }

    function windowMutePolicyKey(entry) {
        return windowKey(entry);
    }

    function windowMutePolicyActiveFor(entry) {
        const key = windowMutePolicyKey(entry);

        if (!key)
            return false;

        return windowAudioMutePolicies[key] !== undefined;
    }

    function setWindowMutePolicy(entry, enabled) {
        if (!entry)
            return;

        const key = windowMutePolicyKey(entry);

        if (!key)
            return;

        const nextPolicies =
            Object.assign({}, windowAudioMutePolicies);

        if (enabled) {
            nextPolicies[key] = {
                id: entry.id || 0,
                pid: entry.pid || 0,
                appId: entry.appId || "",
                className: entry.className || "",
                instance: entry.instance || "",
                name: entry.name || ""
            };
        } else {
            delete nextPolicies[key];
        }

        windowAudioMutePolicies = nextPolicies;

        // Apply a newly armed policy immediately if a stream already exists.
        if (enabled)
            windowAudioPolicyRefreshTimer.restart();
    }

    function pruneWindowMutePolicies(liveWindows) {
        const current = windowAudioMutePolicies;
        const keys = Object.keys(current);

        if (keys.length === 0)
            return;

        const liveKeys = {};

        for (let i = 0; i < liveWindows.length; i++) {
            const key = windowMutePolicyKey(liveWindows[i]);

            if (key)
                liveKeys[key] = true;
        }

        let changed = false;
        const nextPolicies = Object.assign({}, current);

        for (let i = 0; i < keys.length; i++) {
            if (!liveKeys[keys[i]]) {
                delete nextPolicies[keys[i]];
                changed = true;
            }
        }

        if (changed)
            windowAudioMutePolicies = nextPolicies;
    }

    function applyWindowMutePolicies(inputs) {
        const policies = windowAudioMutePolicies;
        const keys = Object.keys(policies);

        if (keys.length === 0)
            return;

        for (let i = 0; i < inputs.length; i++) {
            const input = inputs[i];
            const index = Number(input.index);

            if (isNaN(index))
                continue;

            let shouldMute = false;

            for (let p = 0; p < keys.length; p++) {
                if (windowMatchesAudioSink(
                            policies[keys[p]],
                            input)) {
                    shouldMute = true;
                    break;
                }
            }

            if (shouldMute && !input.mute) {
                Quickshell.execDetached([
                    "pactl",
                    "set-sink-input-mute",
                    String(index),
                    "1"
                ]);
            }
        }
    }

    function scheduleWindowAudioProbe() {
        windowAudioAvailable = false;
        windowAudioMuted = false;
        windowAudioPolicyActive = false;
        windowAudioSinkInputs = [];
        windowAudioProbeWindowKey = "";

        if (!menuOpen || !selectedResultIsWindow())
            return;

        const entry = selectedResult();

        windowAudioPolicyActive =
            windowMutePolicyActiveFor(entry);
        windowAudioMuted =
            windowAudioPolicyActive;

        windowAudioProbeTimer.restart();
    }

    Timer {
        id: windowAudioProbeTimer

        interval: 80
        repeat: false

        onTriggered: {
            const entry = appControlWindow.selectedResult();

            if (!entry || !appControlWindow.selectedResultIsWindow())
                return;

            appControlWindow.windowAudioProbeWindowKey =
                appControlWindow.windowKey(entry);

            windowAudioProbeProcess.exec([
                "pactl",
                "-f",
                "json",
                "list",
                "sink-inputs"
            ]);
        }
    }

    Process {
        id: windowAudioProbeProcess

        stdout: StdioCollector {
            onStreamFinished: {
                const entry = appControlWindow.selectedResult();

                if (!entry
                        || !appControlWindow.selectedResultIsWindow()
                        || appControlWindow.windowKey(entry)
                           !== appControlWindow.windowAudioProbeWindowKey) {
                    appControlWindow.windowAudioAvailable = false;
                    appControlWindow.windowAudioSinkInputs = [];
                    return;
                }

                try {
                    const inputs = JSON.parse(text || "[]");
                    const indexes = [];
                    let allMuted = true;

                    for (let i = 0; i < inputs.length; i++) {
                        const input = inputs[i];

                        if (!appControlWindow.windowMatchesAudioSink(
                                    entry,
                                    input))
                            continue;

                        const index = Number(input.index);

                        if (!isNaN(index))
                            indexes.push(index);

                        if (!input.mute)
                            allMuted = false;
                    }

                    const policyActive =
                        appControlWindow.windowMutePolicyActiveFor(entry);

                    appControlWindow.windowAudioSinkInputs = indexes;
                    appControlWindow.windowAudioAvailable =
                        indexes.length > 0;
                    appControlWindow.windowAudioPolicyActive =
                        policyActive;

                    // A future-stream policy counts as muted/armed even when
                    // the window has not created an audio stream yet.
                    appControlWindow.windowAudioMuted =
                        policyActive
                        || (indexes.length > 0 && allMuted);

                    // If the policy was armed before the stream existed,
                    // enforce it as soon as this probe sees the new stream.
                    if (policyActive)
                        appControlWindow.applyWindowMutePolicies(inputs);

                    console.log(
                        "AppControl: WINDOW audio",
                        appControlWindow.windowKey(entry),
                        "streams=" + indexes.join(","),
                        "policy=" + policyActive,
                        "muted=" + appControlWindow.windowAudioMuted
                    );
                } catch (error) {
                    appControlWindow.windowAudioAvailable = false;
                    appControlWindow.windowAudioSinkInputs = [];

                    const policyActive =
                        appControlWindow.windowMutePolicyActiveFor(entry);

                    appControlWindow.windowAudioPolicyActive =
                        policyActive;
                    appControlWindow.windowAudioMuted =
                        policyActive;

                    console.log(
                        "AppControl: failed to parse pactl sink inputs:",
                        error
                    );
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) {
                    console.log(
                        "AppControl: WINDOW audio probe:",
                        text.trim()
                    );
                }
            }
        }
    }

    function toggleSelectedWindowMute() {
        const entry = selectedResult();

        if (!entry || !selectedResultIsWindow())
            return;

        const shouldMute =
            !windowMutePolicyActiveFor(entry)
            && !windowAudioMuted;

        setWindowMutePolicy(entry, shouldMute);

        // Existing streams react immediately. If there is no stream yet,
        // the session-level policy stays armed and the background watcher
        // will mute the first matching stream as soon as it appears.
        for (let i = 0; i < windowAudioSinkInputs.length; i++) {
            Quickshell.execDetached([
                "pactl",
                "set-sink-input-mute",
                String(windowAudioSinkInputs[i]),
                shouldMute ? "1" : "0"
            ]);
        }

        windowAudioPolicyActive = shouldMute;
        windowAudioMuted = shouldMute;
        windowAudioRefreshTimer.restart();
    }

    Timer {
        id: windowAudioRefreshTimer

        interval: 260
        repeat: false

        onTriggered: {
            appControlWindow.scheduleWindowAudioProbe();
        }
    }


    Timer {
        id: windowAudioPolicyTimer

        interval: 1200
        repeat: true

        running:
            Object.keys(
                appControlWindow.windowAudioMutePolicies
            ).length > 0

        triggeredOnStart: true

        onTriggered: {
            windowAudioPolicyProcess.exec([
                "pactl",
                "-f",
                "json",
                "list",
                "sink-inputs"
            ]);
        }
    }

    Timer {
        id: windowAudioPolicyRefreshTimer

        interval: 40
        repeat: false

        onTriggered: {
            windowAudioPolicyProcess.exec([
                "pactl",
                "-f",
                "json",
                "list",
                "sink-inputs"
            ]);
        }
    }

    Process {
        id: windowAudioPolicyProcess

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const inputs = JSON.parse(text || "[]");

                    appControlWindow.applyWindowMutePolicies(inputs);
                } catch (error) {
                    console.log(
                        "AppControl: mute-policy audio parse failed:",
                        error
                    );
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim().length > 0) {
                    console.log(
                        "AppControl: mute-policy audio probe:",
                        text.trim()
                    );
                }
            }
        }
    }

    function activateResult(entry, modeIndex) {
        if (!entry)
            return;

        const sourceMode = resultSourceMode(entry, modeIndex);
        const sourceItem = favoriteSourceItem(entry);

        if (sourceMode === appsModeIndex) {
            const appEntry = sourceItem || entry;

            launchApplication(appEntry);
            return;
        }

        if (sourceMode === runModeIndex) {
            const runEntry = sourceItem || entry;

            const prefixMode =
                modeIndex === runModeIndex
                ? runPrefixMode
                : runPrefixModeForEntry(runEntry);

            executeRunCommand(
                runCommandText(runEntry),
                prefixMode
            );
            return;
        }

        if (sourceMode === windowsModeIndex) {
            const windowEntry = sourceItem || entry;

            if (windowEntry && windowEntry._tabRecord) {
                activateAppTab(windowEntry);
                return;
            }

            focusSwayWindow(windowEntry);
            return;
        }

        if ((sourceMode === killModeIndex
                || sourceMode === thermalModeIndex
                || sourceMode === systemModeIndex)
                && sourceItem
                && (sourceItem._taskRecord
                    || sourceItem._thermalRecord
                    || sourceItem._systemRecord)) {
            detailFocused = true;
            resetDetailActionSelection();
            ensureDetailActionVisible();
            return;
        }

        console.log(
            "AppControl:",
            modes[sourceMode] ? modes[sourceMode].name : "MODE",
            resultDisplayName(sourceItem || entry, sourceMode)
        );
    }

    function activateSelectedDetailAction() {
        const entry = selectedResult();

        if (!entry)
            return;

        if (selectedResultIsRun()) {
            const runEntry = favoriteSourceItem(entry) || entry;
            const command = runCommandText(runEntry);

            // Primary action respects the prefix stored on the selected
            // result. Alternate KITTY action always forces Kitty regardless
            // of the top/bottom selector state or how the favorite was saved.
            if (selectedDetailActionIndex === 1) {
                executeRunCommand(command, runPrefixKitty);
                return;
            }

            if (selectedDetailActionIndex === 2) {
                executeRunFloatCommand(command);
                return;
            }

            if (selectedDetailActionIndex === 3) {
                executeRunFullscreenCommand(command);
                return;
            }

            if (selectedDetailActionIndex === 4) {
                executeRunCommand(command, runPrefixToolbox);
                return;
            }

            if (selectedDetailActionIndex === 5) {
                if (runKillAvailable)
                    executeRunKillAction();

                return;
            }

            // Inside RUN itself, the bottom prefix selector is
            // authoritative. This fixes USER/history/favorite rows retaining
            // an older stored prefix after the user switches NORMAL/KITTY.
            //
            // When a RUN favorite is activated from FAVORITES, preserve the
            // prefix that was saved with that favorite.
            const primaryPrefix =
                selectedModeIndex === runModeIndex
                ? runPrefixMode
                : runPrefixModeForEntry(runEntry);

            executeRunCommand(
                command,
                primaryPrefix
            );
            return;
        }

        if (selectedResultIsWindow()) {
            activateWindowDetailAction(selectedDetailActionIndex);
            return;
        }

        if (selectedResultIsTab()) {
            const controls = selectedTabControls();
            const control = controls[selectedDetailActionIndex];

            if (control) {
                const controlName = String(
                    control.controlName || control.name || ""
                ).toLowerCase();
                const keepOpen = controlName.indexOf("mute") !== -1;

                activateAppTabControl(control, keepOpen);

                if (keepOpen) {
                    // Keep the TABS panel alive so the bridge can refresh the
                    // control label between MUTE TAB and UNMUTE TAB.
                    detailFocused = true;
                    appTabsBridgeRefreshTimer.restart();
                }
            }

            return;
        }

        if (selectedResultIsTask()) {
            if (selectedDetailActionIndex === 0)
                terminateSelectedTask();

            return;
        }

        if (!selectedResultIsApplication())
            return;

        const appEntry = favoriteSourceItem(entry) || entry;

        if (selectedDetailActionIndex === 0) {
            launchApplication(appEntry);
            return;
        }

        if (appEntry._hiddenCommand) {
            const command = String(appEntry.name || "").trim();

            if (selectedDetailActionIndex === 1) {
                launchHiddenKitty(command);
                return;
            }

            if (selectedDetailActionIndex === 2) {
                launchHiddenGeometry(command, false);
                return;
            }

            if (selectedDetailActionIndex === 3) {
                launchHiddenGeometry(command, true);
                return;
            }
            if (selectedDetailActionIndex === 4) {
                launchAppInBottle(appEntry);
                return;
            }
            if (selectedDetailActionIndex === 5) {
                launchHiddenToolbox(command);
                return;
            }
            if (selectedDetailActionIndex === 6) {
                terminateHiddenCommand(command);
                return;
            }
            return;
        }

        const bottleActionIndex = appEntry.actions.length + 1;
        const toolboxActionIndex = appEntry.actions.length + 2;
        const killActionIndex = appEntry.actions.length + 3;

        if (selectedDetailActionIndex === bottleActionIndex) {
            launchAppInBottle(appEntry);
            return;
        }

        if (selectedDetailActionIndex === toolboxActionIndex) {
            launchAppInToolbox(appEntry);
            return;
        }

        if (selectedDetailActionIndex === killActionIndex) {
            terminateSelectedApplication();
            return;
        }

        const desktopActionIndex = selectedDetailActionIndex - 1;

        if (desktopActionIndex < 0
                || desktopActionIndex >= appEntry.actions.length)
            return;

        const action = appEntry.actions[desktopActionIndex];

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
    property var iconGlowCache: ({})

    function cachedIconGlow(source) {
        const key = source ? source.toString() : "";

        if (!key || iconGlowCache[key] === undefined)
            return null;

        return iconGlowCache[key];
    }

    function rememberIconGlow(source, color, forceOverwrite) {
        const key = source ? source.toString() : "";

        if (!key)
            return;

        if (!forceOverwrite && iconGlowCache[key] !== undefined)
            return;

        // Reassign the object so QML bindings depending on iconGlowCache
        // are notified. Mutating iconGlowCache[key] in place did not
        // reliably update the other copy of the same app icon.
        const nextCache = Object.assign({}, iconGlowCache);
        nextCache[key] = color;
        iconGlowCache = nextCache;
    }

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

    function safeActionIconSource(icon) {
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

        // Monochrome fallback:
        // bright/white icons -> white text/icon accent with cyan glow
        // gray, charcoal and black icons -> magenta.
        if (lightNeutralWeight > darkNeutralWeight
                && lightNeutralWeight > midNeutralWeight)
            return Colors.white;

        return Colors.magenta;
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

    function appEntryForWindow(windowInfo) {
        if (!windowInfo)
            return null;

        const apps = [...DesktopEntries.applications.values];

        for (let i = 0; i < apps.length; i++) {
            if (windowMatchesApp(windowInfo, apps[i]))
                return apps[i];
        }

        return null;
    }

    function windowIconSource(windowInfo) {
        const entry = appEntryForWindow(windowInfo);

        if (!entry)
            return "";

        return appIconSource(entry);
    }

    function appEntryForTab(tabInfo) {
        if (!tabInfo)
            return null;

        const wanted = String(tabInfo.appName || "").trim().toLowerCase();
        const apps = [...DesktopEntries.applications.values];

        for (let i = 0; i < apps.length; i++) {
            const entry = apps[i];
            const name = String(appDisplayName(entry) || "").trim().toLowerCase();
            const id = String(entry.id || "").trim().toLowerCase();

            if (wanted.length > 0
                    && (name === wanted
                        || id === wanted
                        || name.indexOf(wanted) !== -1
                        || wanted.indexOf(name) !== -1))
                return entry;

            if ((wanted === "code" || wanted === "vs code" || wanted === "visual studio code")
                    && (name.indexOf("visual studio code") !== -1
                        || id.indexOf("code") !== -1))
                return entry;

            if (wanted === "kitty"
                    && (name.indexOf("kitty") !== -1 || id.indexOf("kitty") !== -1))
                return entry;
        }

        return null;
    }

    function tabIconSource(tabInfo) {
        const entry = appEntryForTab(tabInfo);
        return entry ? appIconSource(entry) : "";
    }

    function tabFallbackGlyph(tabInfo) {
        if (!tabInfo || tabInfo._tabUnavailable)
            return "⌁";

        const title = String(tabInfo.tabTitle || tabInfo.name || "").toLowerCase();
        const app = String(tabInfo.appName || "").toLowerCase();

        if (app.indexOf("code") !== -1) {
            if (/\.(qml|js|ts|tsx|jsx)$/.test(title)) return "󰛦";
            if (/\.py$/.test(title)) return "󰌠";
            if (/\.(json|jsonc)$/.test(title)) return "";
            if (/\.(md|markdown)$/.test(title)) return "󰍔";
            if (/\.(css|scss|sass)$/.test(title)) return "󰌜";
            if (/\.(html|htm)$/.test(title)) return "󰌝";
            if (/\.(sh|bash|zsh|fish)$/.test(title)) return "";
            return "󰨞";
        }

        if (app.indexOf("kitty") !== -1)
            return "";
        if (app.indexOf("brave") !== -1
                || app.indexOf("chrome") !== -1
                || app.indexOf("chromium") !== -1)
            return "󰖟";

        return "▣";
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

    function collectSwayOutputNames(node, names) {
        if (!node)
            return;

        if (node.type === "output"
                && node.name
                && String(node.name).indexOf("__") !== 0
                && names.indexOf(String(node.name)) === -1) {
            names.push(String(node.name));
        }

        const children = node.nodes || [];

        for (let i = 0; i < children.length; i++)
            collectSwayOutputNames(children[i], names);

        const floatingChildren = node.floating_nodes || [];

        for (let i = 0; i < floatingChildren.length; i++)
            collectSwayOutputNames(floatingChildren[i], names);
    }

    function collectSwayWindows(
        node,
        currentWorkspace,
        currentOutput,
        output,
        inheritedFloating,
        inheritedTabbed,
        inheritedTabGroupId,
        inheritedTabGroupName
    ) {
        if (!node)
            return;

        let workspace = currentWorkspace || "";
        let outputName = currentOutput || "";
        let floatingContext = !!inheritedFloating;
        let tabbedContext = !!inheritedTabbed;
        let tabGroupId = Number(inheritedTabGroupId || 0);
        let tabGroupName = String(inheritedTabGroupName || "");

        if (node.type === "output"
                && node.name
                && String(node.name).indexOf("__") !== 0)
            outputName = String(node.name);

        if (node.type === "workspace")
            workspace = node.name || workspace;

        // Sway commonly wraps floating clients in a floating_con. The client
        // child itself may report floating:auto_off, so carry the state down.
        if (node.type === "floating_con"
                || String(node.floating || "").indexOf("_on") !== -1)
            floatingContext = true;

        // A client can sit several levels below the container that actually
        // owns the tabbed layout, so carry tab-group ancestry down the tree.
        //
        // Sway normally reports layout:"tabbed". Some tree shapes are easier
        // to recognize from representation:"T[...]", so support both.
        const nodeLayout =
            String(node.layout || "").trim().toLowerCase();
        const nodeRepresentation =
            String(node.representation || "").trim();

        const beginsTabbedRepresentation =
            nodeRepresentation.toUpperCase().indexOf("T[") === 0;

        if (nodeLayout === "tabbed" || beginsTabbedRepresentation) {
            tabbedContext = true;

            if (node.id)
                tabGroupId = Number(node.id);

            tabGroupName =
                String(node.name || workspace || "TABS");
        }

        const properties = node.window_properties || {};
        const appId = node.app_id || "";
        const className = properties.class || "";
        const instance = properties.instance || "";
        const hasIdentity = appId || className || instance;
        const hasLiveClient = !!node.pid && !!node.name;

        // Include ordinary tiled clients AND floating/centered clients whose
        // compositor identity fields are sparse but still have a live pid/title.
        if (node.type === "con" && (hasIdentity || hasLiveClient)) {
            output.push({
                id: node.id || 0,
                name: node.name || "",
                appId: appId,
                className: className,
                instance: instance,
                pid: node.pid || 0,
                focused: !!node.focused,
                workspace: workspace,
                output: outputName,
                floating: floatingContext,
                tabbed: tabbedContext || tabGroupId !== 0,
                tabGroupId: tabGroupId,
                tabGroupName: tabGroupName,
                fullscreen: Number(node.fullscreen_mode || 0) !== 0,
                rect: node.rect || {}
            });
        }

        const children = node.nodes || [];

        for (let i = 0; i < children.length; i++) {
            collectSwayWindows(
                children[i],
                workspace,
                outputName,
                output,
                floatingContext,
                tabbedContext,
                tabGroupId,
                tabGroupName
            );
        }

        const floatingChildren = node.floating_nodes || [];

        for (let i = 0; i < floatingChildren.length; i++) {
            collectSwayWindows(
                floatingChildren[i],
                workspace,
                outputName,
                output,
                true,
                tabbedContext,
                tabGroupId,
                tabGroupName
            );
        }
    }

    function consumeSwayTree(rawText) {
        if (!rawText || rawText.trim().length === 0)
            return;

        try {
            const tree = JSON.parse(rawText);
            const windows = [];
            const outputs = [];

            collectSwayOutputNames(tree, outputs);
            collectSwayWindows(
                tree,
                "",
                "",
                windows,
                false,
                false,
                0,
                ""
            );

            swayOutputNames = outputs;
            swayWindows = windows;
            pruneWindowMutePolicies(windows);
            windowDataReady = true;
            windowDataError = "";

            let tabbedCount = 0;

            for (let i = 0; i < windows.length; i++) {
                if (windows[i].tabbed || windows[i].tabGroupId)
                    tabbedCount++;
            }

            console.log(
                "AppControl: Sway window snapshot:",
                windows.length,
                "windows,",
                tabbedCount,
                "tabbed clients on",
                outputs.join(", ")
            );

            if (selectedModeIndex === windowsModeIndex)
                scheduleWindowAudioProbe();
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

    // Top-right popup placement.
    // Applauncher is 50px tall with an 8px top offset, so 58px
    // starts this window directly underneath it.
    anchors {
        top: true
        left: true
    }

    margins {
        top: -3
        left: 2
    }

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
                model:
                    appControlWindow.modes.slice(
                        0,
                        appControlWindow.systemModeIndex
                    )

                Rectangle {
                    id: modeButton

                    property bool isSelected:
                        index === appControlWindow.selectedModeIndex
                    property bool isRailCursor:
                        appControlWindow.modeRailFocused
                        && index === appControlWindow.modeRailCursorIndex

                    property bool isHovered:
                        !appControlWindow.keyboardActive
                        && modeMouse.containsMouse

                    property bool isPressed: modeMouse.pressed

                    width: parent.width
                    height: 55

                    color:
                        modeButton.isPressed
                        ? Colors.magenta
                        : modeButton.isHovered
                          || modeButton.isSelected
                          || modeButton.isRailCursor
                        ? Colors.yellow
                        : Colors.black

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

                                text:
                                    index === appControlWindow.favoritesModeIndex
                                    ? (modeButton.isHovered
                                       || modeButton.isPressed
                                       || appControlWindow.favoritesFaceClickPulse
                                       ? "(˶ˆᗜˆ˵)"
                                       : appControlWindow.favoritesFaceBlinking
                                       ? "(˵-ᴗ-˵)"
                                       : modelData.symbol)
                                    : modelData.symbol

                                font.pixelSize: 17

                                color: modeButton.isPressed
                                       ? Colors.black
                                       : modeButton.isSelected
                                       ? Colors.magenta
                                       : modeButton.isHovered
                                         || modeButton.isRailCursor
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

                                // Treat the mode name like secondary/disabled
                                // metadata: the glyph carries the active color.
                                opacity: modeButton.isPressed
                                         ? 0.42
                                         : modeButton.isHovered
                                           || modeButton.isRailCursor
                                           || modeButton.isSelected
                                         ? 0.48
                                         : 0.34

                                color: modeButton.isPressed
                                       ? Colors.black
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

                                opacity: modeButton.isPressed
                                         ? 0.0
                                         : modeButton.isHovered
                                           || modeButton.isRailCursor
                                           || modeButton.isSelected
                                         ? 0.10
                                         : 0.06

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
                            appControlWindow.modeRailHoveredIndex = index;
                            appControlWindow.modeRailCursorIndex = index;
                        }

                        onExited: {
                            if (appControlWindow.modeRailHoveredIndex === index)
                                appControlWindow.modeRailHoveredIndex = -1;
                        }

                        onWheel: function(wheel) {
                            appControlWindow.enterModeRail();
                            appControlWindow.moveModeRailCursor(
                                wheel.angleDelta.y > 0 ? -1 : 1
                            );
                            wheel.accepted = true;
                        }

                        onClicked: {
                            if (index === appControlWindow.favoritesModeIndex) {
                                appControlWindow.favoritesFaceClickPulse = true;
                                favoritesFaceClickPulseTimer.restart();
                            }

                            appControlWindow.modeRailFocused = false;
                            appControlWindow.modeRailCursorIndex = index;
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
                        opacity:
                            modeButton.isSelected
                            || modeButton.isHovered
                            || modeButton.isRailCursor
                            ? 0.5
                                 : 0.0

                        color: Colors.orange
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 10
                        z: 1

                        opacity:
                            modeButton.isSelected
                            || modeButton.isHovered
                            || modeButton.isRailCursor
                            ? 0.09
                                 : 0.0

                        color: Colors.orange
                    }
                }
            }
        }

        Rectangle {
            id: systemModeButton

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 20

            height: 55

            property bool isSelected:
                appControlWindow.selectedModeIndex
                === appControlWindow.systemModeIndex
            property bool isRailCursor:
                appControlWindow.modeRailFocused
                && appControlWindow.modeRailCursorIndex
                   === appControlWindow.systemModeIndex
            property bool isHovered:
                !appControlWindow.keyboardActive
                && systemModeMouse.containsMouse
            property bool isPressed:
                systemModeMouse.pressed

            color:
                isPressed
                ? Colors.magenta
                : isHovered || isSelected || isRailCursor
                ? Colors.yellow
                : Colors.black

            Column {
                anchors.centerIn: parent
                spacing: 2

                Item {
                    width: systemModeSymbol.implicitWidth
                    height: systemModeSymbol.implicitHeight
                    anchors.horizontalCenter: parent.horizontalCenter

                    GohuText {
                        id: systemModeSymbol
                        anchors.centerIn: parent

                        text: "🖳"
                        font.pixelSize: 17

                        color:
                            systemModeButton.isPressed
                            ? Colors.black
                            : systemModeButton.isSelected
                            ? Colors.magenta
                            : systemModeButton.isHovered
                              || systemModeButton.isRailCursor
                            ? Colors.orange
                            : Colors.cyan
                    }

                    DropShadow {
                        anchors.fill: systemModeSymbol
                        source: systemModeSymbol

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius:
                            systemModeButton.isSelected
                            ? 18
                            : systemModeButton.isHovered
                              || systemModeButton.isRailCursor
                            ? 14
                            : 10
                        samples:
                            systemModeButton.isSelected
                            ? 17
                            : systemModeButton.isHovered
                              || systemModeButton.isRailCursor
                            ? 9
                            : 7
                        opacity:
                            systemModeButton.isSelected
                            ? 1.0
                            : systemModeButton.isHovered
                              || systemModeButton.isRailCursor
                            ? 0.8
                            : 0.42

                        color:
                            systemModeButton.isSelected
                            ? Colors.magenta
                            : systemModeButton.isHovered
                              || systemModeButton.isRailCursor
                            ? Colors.orange
                            : Colors.cyan

                        transparentBorder: true
                    }
                }

                GohuText {
                    text: "SYSTEM"
                    font.pixelSize: 11
                    opacity: 0.80

                    color:
                        systemModeButton.isPressed
                        ? Colors.black
                        : systemModeButton.isHovered
                          || systemModeButton.isRailCursor
                        ? Colors.orange
                        : systemModeButton.isSelected
                        ? Colors.orange
                        : Colors.white
                }
            }

            MouseArea {
                id: systemModeMouse
                anchors.fill: parent
                hoverEnabled: true

                onEntered: {
                    appControlWindow.keyboardActive = false;
                    appControlWindow.modeRailHoveredIndex =
                        appControlWindow.systemModeIndex;
                    appControlWindow.modeRailCursorIndex =
                        appControlWindow.systemModeIndex;
                }

                onExited: {
                    if (appControlWindow.modeRailHoveredIndex
                            === appControlWindow.systemModeIndex)
                        appControlWindow.modeRailHoveredIndex = -1;
                }

                onWheel: function(wheel) {
                    appControlWindow.enterModeRail();
                    appControlWindow.moveModeRailCursor(
                        wheel.angleDelta.y > 0 ? -1 : 1
                    );
                    wheel.accepted = true;
                }

                onClicked: {
                    appControlWindow.modeRailFocused = false;
                    appControlWindow.modeRailCursorIndex =
                        appControlWindow.systemModeIndex;
                    appControlWindow.switchMode(
                        appControlWindow.systemModeIndex,
                        false
                    );
                    searchInput.forceActiveFocus();
                }
            }

            RectangularShadow {
                anchors.fill: parent
                spread: 3
                z: -1

                opacity:
                    systemModeButton.isSelected
                    || systemModeButton.isHovered
                    || systemModeButton.isRailCursor
                    ? 0.5
                    : 0.0

                color: Colors.orange
            }

            RectangularShadow {
                anchors.fill: parent
                spread: 10
                z: 1

                opacity:
                    systemModeButton.isSelected
                    || systemModeButton.isHovered
                    || systemModeButton.isRailCursor
                    ? 0.09
                    : 0.0

                color: Colors.orange
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

            color: Colors.black

            // Fixed header geometry: the decorative APPS title has unusual
            // combining-glyph metrics, so it must not participate in sizing
            // the search row. Title and input are anchored independently.
            Item {
                id: selectorTitleSlot

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                anchors.leftMargin: 15
                anchors.rightMargin: 15
                anchors.topMargin: 9

                height: 22

                // Ordinary mode title.
                GohuText {
                    id: selectorModeHeaderText

                    visible:
                        appControlWindow.selectedModeIndex
                        !== appControlWindow.appsModeIndex
                        && appControlWindow.selectedModeIndex
                        !== appControlWindow.runModeIndex
                        && appControlWindow.selectedModeIndex
                        !== appControlWindow.favoritesModeIndex

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter

                    text: appControlWindow.modes[
                              appControlWindow.selectedModeIndex
                          ].name

                    font.pixelSize: 19

                    color: appControlWindow.selectedModeIndex
                           === appControlWindow.killModeIndex
                           ? Colors.red
                           : Colors.cyan
                }

                DropShadow {
                    anchors.fill: selectorModeHeaderText
                    source: selectorModeHeaderText

                    visible: selectorModeHeaderText.visible

                    horizontalOffset: 0
                    verticalOffset: 0

                    radius: 14
                    samples: 11

                    z: 2

                    opacity: 0.75

                    color: appControlWindow.selectedModeIndex
                           === appControlWindow.killModeIndex
                           ? Colors.red
                           : Colors.cyan

                    transparentBorder: true
                }

                // APPS / RUN / FAVORITES ornate title: keep the words readable, but
                // give the decorative stars and edge dashes a stronger cyan halo.
                Row {
                    id: appsSelectorTitle

                    visible:
                        appControlWindow.selectedModeIndex
                        === appControlWindow.appsModeIndex
                        || appControlWindow.selectedModeIndex
                           === appControlWindow.runModeIndex
                        || appControlWindow.selectedModeIndex
                           === appControlWindow.favoritesModeIndex

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter

                    spacing: 0

                    Item {
                        width: appsTitleLeftDecor.implicitWidth
                        height: appsTitleLeftDecor.implicitHeight

                        GohuText {
                            id: appsTitleLeftDecor

                            anchors.centerIn: parent

                            text: "- ༘⋆₊⊹"
                            font.pixelSize: 16
                            color:
                appControlWindow.selectedModeIndex
                === appControlWindow.thermalModeIndex
                ? Colors.orange
                : appControlWindow.selectedModeIndex
                  === appControlWindow.killModeIndex
                ? Colors.red
                : Colors.cyan
                        }

                        DropShadow {
                            anchors.fill: appsTitleLeftDecor
                            source: appsTitleLeftDecor

                            horizontalOffset: 0
                            verticalOffset: 0

                            radius: 12
                            samples: 9

                            opacity: 0.88
                            color: Colors.cyan

                            transparentBorder: true
                        }
                    }

                    Item {
                        width: appsTitleWords.implicitWidth
                        height: appsTitleWords.implicitHeight

                        GohuText {
                            id: appsTitleWords

                            anchors.centerIn: parent
                            anchors.verticalCenterOffset: 4

                            text:
                                appControlWindow.selectedModeIndex
                                === appControlWindow.runModeIndex
                                ? "Run Command, Run!"
                                : appControlWindow.selectedModeIndex
                                  === appControlWindow.favoritesModeIndex
                                ? "All Your Favorites!"
                                : appControlWindow.selectedModeIndex
                                  === appControlWindow.thermalModeIndex
                                ? "Thermal Monitor"
                                : appControlWindow.selectedModeIndex
                                  === appControlWindow.killModeIndex
                                ? "Task Manager"
                                : appControlWindow.selectedModeIndex
                                  === appControlWindow.systemModeIndex
                                ? "System Monitor"
                                : "Pick an App any App"
                            font.pixelSize: 16
                            color:
                                appControlWindow.selectedModeIndex
                                === appControlWindow.killModeIndex
                                ? Colors.red
                                : appControlWindow.selectedModeIndex
                                  === appControlWindow.thermalModeIndex
                                ? Colors.orange
                                : Colors.cyan
                        }

                        DropShadow {
                            anchors.fill: appsTitleWords
                            source: appsTitleWords

                            horizontalOffset: 0
                            verticalOffset: 0

                            radius: 8
                            samples: 7

                            opacity: 0.56
                            color: appsTitleWords.color

                            transparentBorder: true
                        }
                    }

                    Item {
                        width: appsTitleRightDecor.implicitWidth
                        height: appsTitleRightDecor.implicitHeight

                        GohuText {
                            id: appsTitleRightDecor

                            anchors.centerIn: parent

                            text: " ๋࣭ ⭑⋆｡˚-"
                            font.pixelSize: 16
                            color: Colors.cyan
                        }

                        DropShadow {
                            anchors.fill: appsTitleRightDecor
                            source: appsTitleRightDecor

                            horizontalOffset: 0
                            verticalOffset: 0

                            radius: 12
                            samples: 9

                            opacity: 0.88
                            color: Colors.cyan

                            transparentBorder: true
                        }
                    }
                }

                Rectangle {
                    id: selectorTitleDivider

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom

                    anchors.leftMargin: -15
                    anchors.rightMargin: -15

                    // Nudge the title underline lower without changing the
                    // fixed selector/title/input layout.
                    transform: Translate {
                        y: 4
                    }

                    height: 1

                    color:
                        appControlWindow.selectedModeIndex
                        === appControlWindow.killModeIndex
                        ? Colors.red
                        : appControlWindow.selectedModeIndex
                          === appControlWindow.thermalModeIndex
                        ? Colors.orange
                        : Colors.cyan

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 3
                        z: -1

                        opacity: 0.38
                        color: selectorTitleDivider.color
                    }
                }
            }

            TextInput {
                id: searchInput

                // Fixed to the divider instead of flowing under the title.
                // Mode/header glyph metrics can no longer move this row.
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                anchors.leftMargin: 15
                anchors.rightMargin: 15
                anchors.bottomMargin: 3

                height: 22

                // The decorative cursor should not reserve horizontal
                // space in the input. These properties only drive the
                // idle star blink.
                property bool typingRecently: false
                property bool cursorStarsVisible: true
                property int trailingStarPhase: 0

                Timer {
                    id: typingPauseTimer

                    interval: 500
                    repeat: false

                    onTriggered: {
                        searchInput.typingRecently = false;
                        searchInput.cursorStarsVisible = true;
                    }
                }

                Timer {
                    id: cursorStarsBlinkTimer

                    interval: 420
                    repeat: true
                    running: searchInput.activeFocus
                             && !searchInput.typingRecently

                    onTriggered: {
                        searchInput.cursorStarsVisible =
                            !searchInput.cursorStarsVisible;
                    }
                }

                Timer {
                    id: trailingStarWaveTimer

                    interval: 360
                    repeat: true
                    running: searchInput.activeFocus
                             && !searchInput.typingRecently

                    onTriggered: {
                        searchInput.trailingStarPhase =
                            (searchInput.trailingStarPhase + 1) % 5;
                    }
                }

                font.family: "GohuFont 11 Nerd Font Mono"
                font.pixelSize: 18

                verticalAlignment: TextInput.AlignVCenter

                color: Colors.magenta

                selectionColor: Colors.yellow
                selectedTextColor: Colors.black

                // Keep cursor geometry active, but replace the native
                // insertion bar with a truly invisible zero-width delegate.
                // The decorative overlay below is the only visible cursor.
                cursorVisible: activeFocus

                cursorDelegate: Item {
                    width: 0
                    height: 0
                    visible: false
                    opacity: 0.0
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

                Keys.priority: Keys.BeforeItem

                Keys.onShortcutOverride: function(event) {
                    const quickSelectorMode =
                        appControlWindow.selectedModeIndex
                        === appControlWindow.runModeIndex
                        || appControlWindow.selectedModeIndex
                           === appControlWindow.appsModeIndex
                        || appControlWindow.selectedModeIndex
                           === appControlWindow.windowsModeIndex
                        || appControlWindow.selectedModeIndex
                           === appControlWindow.thermalModeIndex;

                    if (quickSelectorMode
                            && event.key === Qt.Key_Left
                            && ((event.modifiers & Qt.ControlModifier)
                                || (event.modifiers & Qt.ShiftModifier))) {
                        event.accepted = true;
                    }
                }

                Keys.onPressed: function (event) {
                    appControlWindow.handleKey(event);
                }

                onTextChanged: {
                    searchInput.typingRecently = true;
                    searchInput.cursorStarsVisible = true;
                    searchInput.trailingStarPhase = 0;
                    typingPauseTimer.restart();

                    if (appControlWindow.selectedModeIndex
                            === appControlWindow.appsModeIndex
                            || appControlWindow.selectedModeIndex
                            === appControlWindow.favoritesModeIndex
                            || appControlWindow.selectedModeIndex
                            === appControlWindow.runModeIndex
                            || appControlWindow.selectedModeIndex
                            === appControlWindow.killModeIndex
                            || appControlWindow.selectedModeIndex
                            === appControlWindow.thermalModeIndex
                            || appControlWindow.selectedModeIndex
                            === appControlWindow.systemModeIndex) {
                        appControlWindow.resetResultSelection();

                        if (appControlWindow.selectedResultIsApplication())
                            appControlWindow.rememberCurrentAppSelection();

                        appControlWindow.resetDetailActionSelection();
                    }
                }
            }

            // Decorative search cursor rendered OUTSIDE TextInput.
            // Using cursorRectangle for x keeps it attached to the real
            // insertion point, while avoiding TextInput's layer shadow.
            Item {
                id: searchCursorOverlay

                visible: searchInput.activeFocus

                // Match the real insertion point instead of trailing behind
                // it. The native bar itself is suppressed above.
                x: searchInput.x + searchInput.cursorRectangle.x - 1
                y: searchInput.y + 3

                width: typingCursorVisual.implicitWidth
                height: searchInput.height

                z: 50

                Row {
                    id: typingCursorVisual

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter

                    spacing: -2

                    GohuText {
                        id: typingCursorStars

                        text: "݁˖"

                        font.pixelSize: 17
                        color: Colors.orange

                        opacity: searchInput.typingRecently
                                 || searchInput.cursorStarsVisible
                                 ? 1.0
                                 : 0.02
                    }

                    Item {
                        id: typingCursorHandGroup

                        width: typingCursorHand.implicitWidth
                        height: typingCursorHand.implicitHeight

                        GohuText {
                            id: typingCursorHand

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                            text: "✍︎"

                            font.pixelSize: 17
                            color: Colors.orange
                        }

                        // First decorative mark immediately behind the hand.
                        // Including the hand in the shaping string prevents
                        // the mark from becoming a detached/doubled glyph.
                        GohuText {
                            id: typingCursorNearStarOne

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                            text: "✍︎๋"

                            font.pixelSize: 17
                            color: Colors.orange

                            opacity: searchInput.typingRecently
                                     ? 0.60
                                     : searchInput.trailingStarPhase === 0
                                     ? 0.68
                                     : searchInput.trailingStarPhase === 1
                                     ? 0.36
                                     : searchInput.trailingStarPhase === 4
                                     ? 0.22
                                     : 0.04
                        }

                        // Second decorative mark follows the first with an
                        // overlapping phase instead of blinking one-by-one.
                        GohuText {
                            id: typingCursorNearStarTwo

                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter

                            text: "✍︎࣭"

                            font.pixelSize: 17
                            color: Colors.orange

                            opacity: searchInput.typingRecently
                                     ? 0.60
                                     : searchInput.trailingStarPhase === 0
                                     ? 0.28
                                     : searchInput.trailingStarPhase === 1
                                     ? 0.68
                                     : searchInput.trailingStarPhase === 2
                                     ? 0.38
                                     : 0.04
                        }
                    }

                    GohuText {
                        id: typingCursorTrailStar

                        text: "⭑"

                        font.pixelSize: 17
                        color: Colors.orange

                        opacity: searchInput.typingRecently
                                 ? 1.0
                                 : searchInput.trailingStarPhase === 0
                                 ? 0.14
                                 : searchInput.trailingStarPhase === 1
                                 ? 0.48
                                 : searchInput.trailingStarPhase === 2
                                 ? 1.0
                                 : searchInput.trailingStarPhase === 3
                                 ? 0.74
                                 : 0.30
                    }

                    GohuText {
                        id: typingCursorTrailPlus

                        text: "₊ "

                        font.pixelSize: 17
                        color: Colors.orange

                        opacity: searchInput.typingRecently
                                 ? 1.0
                                 : searchInput.trailingStarPhase === 0
                                 ? 0.06
                                 : searchInput.trailingStarPhase === 1
                                 ? 0.18
                                 : searchInput.trailingStarPhase === 2
                                 ? 0.46
                                 : searchInput.trailingStarPhase === 3
                                 ? 1.0
                                 : 0.62
                    }
                }

                DropShadow {
                    anchors.fill: typingCursorVisual
                    source: typingCursorVisual

                    horizontalOffset: 0
                    verticalOffset: 0

                    radius: 5
                    samples: 5

                    opacity: 0.42
                    color: Colors.orange

                    transparentBorder: true
                }
            }

            Rectangle {
                id: selectorHeaderDivider

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                height: 1

                color:
                    appControlWindow.selectedModeIndex
                    === appControlWindow.killModeIndex
                    ? Colors.red
                    : appControlWindow.selectedModeIndex
                      === appControlWindow.thermalModeIndex
                    ? Colors.orange
                    : Colors.cyan

                RectangularShadow {
                    anchors.fill: parent
                    spread: 3
                    z: -1
                    opacity: 0.38
                    color: selectorHeaderDivider.color
                }
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
            anchors.bottomMargin:
                appControlWindow.selectedModeIndex
                === appControlWindow.runModeIndex
                ? runPrefixSelector.height
                : appControlWindow.selectedModeIndex
                  === appControlWindow.appsModeIndex
                ? appLaunchSelector.height
                : 0

            // Permanent viewport gap: no app row can ever touch the
            // header divider, even while the list is scrolled.
            anchors.topMargin:
                appControlWindow.selectedModeIndex
                === appControlWindow.favoritesModeIndex
                ? favoritesModeSelector.height + 8
                : appControlWindow.selectedModeIndex
                  === appControlWindow.runModeIndex
                ? runListSelector.height + 8
                : appControlWindow.selectedModeIndex
                  === appControlWindow.appsModeIndex
                ? appSourceSelector.height + 8
                : appControlWindow.selectedModeIndex
                  === appControlWindow.windowsModeIndex
                ? windowListSelector.height + 8
                : appControlWindow.selectedModeIndex
                  === appControlWindow.thermalModeIndex
                ? thermalViewSelector.height + 8
                : appControlWindow.selectedModeIndex
                  === appControlWindow.killModeIndex
                ? killGlobalSelector.height + 8
                : 8

            clip: true

            boundsBehavior: Flickable.StopAtBounds
            highlightMoveDuration: 0
            highlightResizeDuration: 0

            model: appControlWindow.selectedModeIndex === appControlWindow.favoritesModeIndex
                   ? favoriteResults
                   : appControlWindow.selectedModeIndex === appControlWindow.appsModeIndex
                   ? filteredApps
                   : appControlWindow.selectedModeIndex === appControlWindow.runModeIndex
                   ? runResults
                   : appControlWindow.selectedModeIndex === appControlWindow.windowsModeIndex
                   ? windowResults
                   : appControlWindow.selectedModeIndex === appControlWindow.thermalModeIndex
                   ? thermalResults
                   : appControlWindow.selectedModeIndex === appControlWindow.killModeIndex
                   ? killTaskResults
                   : appControlWindow.selectedModeIndex === appControlWindow.systemModeIndex
                   ? systemResults
                   : appControlWindow.placeholderResults

            footer: Item {
                width: resultList.width
                height: 10
            }

            delegate: Item {
                id: resultDelegate

                required property int index
                required property var modelData

                width: resultList.width
                height:
                    appControlWindow.resultSourceMode(
                        modelData,
                        appControlWindow.selectedModeIndex
                    ) === appControlWindow.killModeIndex
                    || appControlWindow.resultSourceMode(
                        modelData,
                        appControlWindow.selectedModeIndex
                    ) === appControlWindow.thermalModeIndex
                    || appControlWindow.resultSourceMode(
                        modelData,
                        appControlWindow.selectedModeIndex
                    ) === appControlWindow.systemModeIndex
                    ? 50
                    : 42

                z: resultButton.isSelected || resultButton.isHovered ? 10 : 0

                Rectangle {
                    id: resultButton

                    property bool isSelected: resultDelegate.index === appControlWindow.selectedResultIndex

                    property bool isHovered: !appControlWindow.keyboardActive
                                             && appControlWindow.hoveredResultIndex === resultDelegate.index

                    property bool isPressed: resultMouse.pressed

                    property bool isUnavailableApp:
                        appControlWindow.selectedModeIndex
                        === appControlWindow.appsModeIndex
                        && appControlWindow.resultIsApplication(
                               modelData,
                               appControlWindow.selectedModeIndex
                           )
                        && !appControlWindow.appEntryLaunchableForSelectedSource(
                                modelData
                            )

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

                    opacity: resultButton.isUnavailableApp ? 0.48 : 1.0

                    Item {
                        id: killMiniGraphBox

                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 5
                        anchors.bottomMargin: 5
                        width: 82
                        z: 1

                        // Keep the original row identity permanently available.
                        // A FAVORITES task row may be created before the first live
                        // task snapshot, so visibility must never depend on a PID.
                        readonly property var rowItem: modelData
                        readonly property int sourceMode:
                            appControlWindow.resultSourceMode(
                                rowItem,
                                appControlWindow.selectedModeIndex
                            )
                        readonly property string taskIdentity:
                            sourceMode === appControlWindow.killModeIndex
                            ? appControlWindow.taskIdentityForEntry(rowItem)
                            : ""
                        readonly property var sourceItem: {
                            // Make the revision an explicit dependency so this
                            // binding re-resolves the live row on every snapshot.
                            const revision = appControlWindow.taskMiniHistoryRevision;
                            return appControlWindow.liveTaskForMiniGraph(rowItem)
                                   || appControlWindow.favoriteSourceItem(rowItem)
                                   || rowItem;
                        }
                        readonly property bool showingTask:
                            sourceMode === appControlWindow.killModeIndex
                            && taskIdentity.length > 0
                        readonly property color accent:
                            Number(
                                sourceItem
                                ? (sourceItem.cpuInstant !== undefined
                                   ? sourceItem.cpuInstant
                                   : sourceItem.cpu)
                                : 0
                            ) >= 25
                            ? Colors.red : Colors.magenta

                        visible: showingTask

                        Rectangle {
                            anchors.fill: parent
                            color: Colors.black
                            opacity: 0.80
                            border.width: 1
                            border.color: killMiniGraphBox.accent
                        }

                        Item {
                            id: killMiniCpuCanvas
                            anchors.fill: parent
                            anchors.margins: 2
                            z: 2
                            clip: true

                            // Keep a delegate-local copy of the history. A root-level
                            // JS object changing underneath a Repeater is not a reliable
                            // notification path in Qt/QML, especially after hide/show.
                            // Every completed task snapshot explicitly replaces this
                            // array, which guarantees the segment bindings see a change.
                            property int historyRevision:
                                appControlWindow.taskMiniHistoryRevision
                            property int graphEpoch: 0
                            property var historyValues: []

                            function refreshHistory() {
                                const live =
                                    appControlWindow.liveTaskForMiniGraph(
                                        killMiniGraphBox.rowItem
                                    )
                                    || killMiniGraphBox.sourceItem;
                                const next =
                                    appControlWindow.taskMiniCpuHistoryByIdentity(
                                        killMiniGraphBox.taskIdentity,
                                        live
                                    );

                                historyValues = Array.isArray(next)
                                                ? next.slice()
                                                : [];
                                graphEpoch += 1;
                            }

                            onHistoryRevisionChanged: refreshHistory()

                            // ListView delegates are reused. A reused delegate can
                            // receive a different modelData/task identity without the
                            // global history revision changing at that exact moment.
                            // Refresh on identity/source changes as well, otherwise a
                            // FAVORITES row can display the previous row's frozen graph.
                            Connections {
                                target: killMiniGraphBox
                                function onTaskIdentityChanged() {
                                    killMiniCpuCanvas.refreshHistory();
                                }
                                function onRowItemChanged() {
                                    killMiniCpuCanvas.refreshHistory();
                                }
                            }

                            Component.onCompleted: refreshHistory()

                            readonly property var graphPoints: {
                                const epoch = graphEpoch;
                                const values = historyValues;

                                // While the history is filling, spread the samples over
                                // the whole mini graph instead of parking a 2px starter
                                // segment at one edge. Once the history reaches the cap
                                // it naturally becomes the normal scrolling window.
                                const slots = Math.max(2, values.length);

                                return appControlWindow.graphLinePoints(
                                    values,
                                    width,
                                    height,
                                    appControlWindow.selectedModeIndex
                                    === appControlWindow.favoritesModeIndex
                                    ? 1.0
                                    : 5.0,
                                    slots,
                                    2,
                                    3
                                );
                            }

                            // Match the large TASK MANAGER graphs with a
                            // translucent filled area beneath the mini trace. This is
                            // ordinary QML geometry, so it keeps the same hide/show
                            // stability as the segment renderer.
                            Repeater {
                                model: killMiniCpuCanvas.graphPoints.length

                                delegate: Rectangle {
                                    readonly property point graphPoint:
                                        killMiniCpuCanvas.graphPoints[index]
                                    readonly property real pointSpacing:
                                        killMiniCpuCanvas.graphPoints.length > 1
                                        ? Math.abs(
                                              killMiniCpuCanvas.graphPoints[
                                                  Math.min(
                                                      index + 1,
                                                      killMiniCpuCanvas.graphPoints.length - 1
                                                  )
                                              ].x
                                              - graphPoint.x
                                          )
                                        : killMiniCpuCanvas.width

                                    readonly property real fillX:
                                        Math.max(0, graphPoint.x - pointSpacing / 2)
                                    readonly property real fillY:
                                        Math.max(0, Math.min(
                                            killMiniCpuCanvas.height - 1,
                                            graphPoint.y
                                        ))

                                    x: fillX
                                    y: fillY
                                    width: Math.max(
                                        1.0,
                                        Math.min(
                                            pointSpacing + 0.8,
                                            killMiniCpuCanvas.width - fillX
                                        )
                                    )
                                    height: Math.max(
                                        0,
                                        killMiniCpuCanvas.height - fillY - 1
                                    )
                                    color: killMiniGraphBox.accent
                                    opacity: 0.20
                                    antialiasing: true
                                }
                            }

                            Repeater {
                                model: Math.max(0, killMiniCpuCanvas.graphPoints.length - 1)

                                delegate: Item {
                                    anchors.fill: parent

                                    // graphEpoch is deliberately referenced here as well.
                                    // It forces already-created delegates to refresh their
                                    // coordinates even when the Repeater count is unchanged.
                                    readonly property point p1: {
                                        const epoch = killMiniCpuCanvas.graphEpoch;
                                        return killMiniCpuCanvas.graphPoints[index];
                                    }
                                    readonly property point p2: {
                                        const epoch = killMiniCpuCanvas.graphEpoch;
                                        return killMiniCpuCanvas.graphPoints[index + 1];
                                    }
                                    readonly property real dx: p2.x - p1.x
                                    readonly property real dy: p2.y - p1.y
                                    readonly property real segmentLength:
                                        Math.sqrt(dx * dx + dy * dy)
                                    readonly property real segmentAngle:
                                        Math.atan2(dy, dx) * 180 / Math.PI

                                    Rectangle {
                                        x: parent.p1.x
                                        y: parent.p1.y - height / 2
                                        width: parent.segmentLength
                                        height: 6
                                        radius: 3
                                        rotation: parent.segmentAngle
                                        transformOrigin: Item.Left
                                        color: killMiniGraphBox.accent
                                        opacity: 0.20
                                        antialiasing: true
                                    }

                                    Rectangle {
                                        x: parent.p1.x
                                        y: parent.p1.y - height / 2
                                        width: parent.segmentLength
                                        height: 2
                                        radius: 1
                                        rotation: parent.segmentAngle
                                        transformOrigin: Item.Left
                                        color: killMiniGraphBox.accent
                                        opacity: 1.0
                                        antialiasing: true
                                    }
                                }
                            }
                        }
                    }

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right

                    anchors.leftMargin: 14
                    anchors.rightMargin:
                        appControlWindow.resultSourceMode(
                            modelData,
                            appControlWindow.selectedModeIndex
                        ) === appControlWindow.killModeIndex
                        && (appControlWindow.favoriteSourceItem(modelData)
                            || modelData)._taskRecord
                        && Number((appControlWindow.favoriteSourceItem(modelData)
                                   || modelData).pid || 0) > 0
                        ? 100
                        : 38

                    // Do not clip here: the selector icon's DropShadow needs
                    // room above/below the row. Clipping this Row made the
                    // halo look offset toward the bottom-right.
                    clip: false

                    // resultNameGlowBox has 8px internal left padding,
                    // so 1 + 8 preserves the original 9px icon/name gap.
                    spacing: 1

                    Item {
                        id: selectorAppIconBox

                        width:
                            sourceMode === appControlWindow.killModeIndex
                            && !!sourceItem._taskRecord
                            ? 50
                            : hiddenFallbackActive
                            ? 42
                            : 22
                        height: 22

                        anchors.verticalCenter: parent.verticalCenter

                        readonly property color sampledGlowColor: {
                            const cached = appControlWindow.cachedIconGlow(
                                selectorAppIcon.source
                            );
                            return cached !== null ? cached : Colors.cyan;
                        }
                        property var iconGrabResult: null
                        property string samplingSource: ""
                        property string verifiedSource: ""
                        readonly property int sourceMode:
                            appControlWindow.resultSourceMode(
                                modelData,
                                appControlWindow.selectedModeIndex
                            )
                        readonly property var sourceItem:
                            appControlWindow.favoriteSourceItem(modelData)
                            || modelData

                        readonly property bool hiddenFallbackActive:
                            sourceItem
                            && sourceItem._hiddenCommand === true
                            && selectorAppIcon.source.toString().length === 0
                            && (
                                (appControlWindow.selectedModeIndex
                                 === appControlWindow.appsModeIndex
                                 && appControlWindow.appSourceMode
                                    === appControlWindow.appSourceHidden)
                                || appControlWindow.selectedModeIndex
                                   === appControlWindow.favoritesModeIndex
                            )

                        visible:
                            ((appControlWindow.resultIsApplication(
                                  modelData,
                                  appControlWindow.selectedModeIndex
                              )
                              || appControlWindow.resultIsWindow(
                                  modelData,
                                  appControlWindow.selectedModeIndex
                              )
                              || appControlWindow.resultIsTab(
                                  modelData,
                                  appControlWindow.selectedModeIndex
                              ))
                             && (selectorAppIcon.source.toString().length > 0
                                 || appControlWindow.resultIsTab(
                                     modelData,
                                     appControlWindow.selectedModeIndex
                                 )
                                 || (selectorAppIconBox.sourceItem
                                     && selectorAppIconBox.sourceItem._hiddenCommand)))
                            || (sourceMode
                                === appControlWindow.killModeIndex
                                && !!sourceItem._taskRecord)
                            || (sourceMode
                                === appControlWindow.thermalModeIndex
                                && !!sourceItem._thermalRecord)
                            || (sourceMode
                                === appControlWindow.systemModeIndex
                                && !!sourceItem._systemRecord)

                        function sampleRenderedIcon() {
                            const sourceKey = selectorAppIcon.source.toString();

                            if (!sourceKey || selectorAppIcon.status !== Image.Ready)
                                return;

                            // Verify each rendered source once per delegate.
                            // Do not trust a stale cache entry here: that was
                            // why Bottles could begin cyan/blue and flip red
                            // only after the detail pane sampled it.
                            if (verifiedSource === sourceKey
                                    || samplingSource === sourceKey)
                                return;

                            samplingSource = sourceKey;

                            Qt.callLater(function() {
                                if (selectorAppIcon.source.toString() !== sourceKey
                                        || selectorAppIcon.status !== Image.Ready) {
                                    selectorAppIconBox.samplingSource = "";
                                    return;
                                }

                                const started =
                                    selectorAppIcon.grabToImage(
                                        function(result) {
                                            if (selectorAppIcon.source.toString()
                                                    !== sourceKey) {
                                                selectorAppIconBox.samplingSource = "";
                                                return;
                                            }

                                            // Keep the grab alive until Canvas has
                                            // sampled its in-memory URL.
                                            selectorAppIconBox.iconGrabResult =
                                                result;

                                            selectorIconColorSampler.originalSource =
                                                sourceKey;
                                            selectorIconColorSampler.sampleSource =
                                                result.url.toString();
                                            selectorIconColorSampler.prepareSample();
                                        },
                                        Qt.size(52, 52)
                                    );

                                if (!started)
                                    selectorAppIconBox.samplingSource = "";
                            });
                        }

                        onVisibleChanged: {
                            if (visible)
                                sampleRenderedIcon();
                        }

                        Component.onCompleted: {
                            if (visible) {
                                Qt.callLater(function() {
                                    selectorAppIconBox.sampleRenderedIcon();
                                });
                            }
                        }

                        Image {
                            id: selectorAppIcon

                            anchors.fill: parent
                            z: 20
                            visible: source.toString().length > 0

                            source:
                                appControlWindow.resultIsApplication(
                                    modelData,
                                    appControlWindow.selectedModeIndex
                                )
                                ? appControlWindow.appIconSource(modelData)
                                : appControlWindow.resultIsTab(
                                      modelData,
                                      appControlWindow.selectedModeIndex
                                  )
                                ? appControlWindow.tabIconSource(modelData)
                                : appControlWindow.resultIsWindow(
                                      modelData,
                                      appControlWindow.selectedModeIndex
                                  )
                                ? appControlWindow.windowIconSource(modelData)
                                : ""

                            // Use the same provider raster size as the
                            // control-panel icon. The item still displays at
                            // 22x22; only the source raster is higher quality.
                            sourceSize.width: 52
                            sourceSize.height: 52
                            asynchronous: false
                            cache: true
                            fillMode: Image.PreserveAspectFit
                            smooth: false

                            onSourceChanged: {
                                selectorAppIconBox.iconGrabResult = null;
                                selectorAppIconBox.samplingSource = "";
                                selectorAppIconBox.verifiedSource = "";

                                if (status === Image.Ready)
                                    selectorAppIconBox.sampleRenderedIcon();
                            }

                            onStatusChanged: {
                                if (status === Image.Ready)
                                    selectorAppIconBox.sampleRenderedIcon();
                            }
                        }

                        GohuText {
                            id: selectorTabFallbackGlyph
                            anchors.centerIn: parent
                            z: 2

                            visible:
                                appControlWindow.resultIsTab(
                                    modelData,
                                    appControlWindow.selectedModeIndex
                                )
                                && selectorAppIcon.source.toString().length === 0

                            text: appControlWindow.tabFallbackGlyph(selectorAppIconBox.sourceItem)
                            font.pixelSize: 15
                            color:
                                resultButton.isPressed
                                ? Colors.black
                                : resultButton.isHovered || resultButton.isSelected
                                ? Colors.orange
                                : Colors.cyan

                            layer.enabled: !resultButton.isPressed
                            layer.effect: DropShadow {
                                radius: 5
                                samples: 5
                                opacity: 0.44
                                color:
                                    resultButton.isHovered || resultButton.isSelected
                                    ? Colors.orange
                                    : Colors.cyan
                                transparentBorder: true
                            }
                        }

                        GohuText {
                            id: selectorHiddenFallbackGlyph
                            anchors.centerIn: parent
                            z: 1

                            visible:
                                selectorAppIconBox.hiddenFallbackActive

                            text:
                                resultButton.isHovered
                                || resultButton.isSelected
                                || appControlWindow.hiddenFaceBlinking
                                ? "|ω･`ς)"
                                : "|ω-ς)"

                            font.pixelSize: 11
                            color:
                                resultButton.isPressed
                                ? Colors.black
                                : resultButton.isHovered
                                  || resultButton.isSelected
                                ? Colors.orange
                                : Colors.yellow

                            layer.enabled: !resultButton.isPressed
                            layer.effect: DropShadow {
                                radius: 6
                                samples: 5
                                opacity: 0.46
                                color:
                                    resultButton.isHovered
                                    || resultButton.isSelected
                                    ? Colors.orange
                                    : Colors.yellow
                                transparentBorder: true
                            }
                        }

                        
                        Rectangle {
                            id: selectorMonitorFanIconBox

                            anchors.centerIn: parent
                            width: 21
                            height: 21

                            visible:
                                selectorAppIconBox.sourceMode
                                === appControlWindow.thermalModeIndex
                                && !!selectorAppIconBox.sourceItem._thermalRecord
                                && selectorAppIconBox.sourceItem.sensorKind
                                   === "fan"

                            color: Colors.black
                            border.width: 1
                            border.color:
                                resultButton.isHovered
                                || resultButton.isSelected
                                ? Colors.orange
                                : Colors.omnitrix

                            GohuText {
                                anchors.centerIn: parent
                                text: "✇"
                                font.pixelSize: 15
                                color:
                                    resultButton.isPressed
                                    ? Colors.black
                                    : resultButton.isHovered
                                      || resultButton.isSelected
                                    ? Colors.orange
                                    : Colors.omnitrix

                                layer.enabled: !resultButton.isPressed
                                layer.effect: DropShadow {
                                    horizontalOffset: 0
                                    verticalOffset: 0
                                    radius: 5
                                    samples: 5
                                    opacity: 0.42
                                    color:
                                        resultButton.isHovered
                                        || resultButton.isSelected
                                        ? Colors.orange
                                        : Colors.omnitrix
                                    transparentBorder: true
                                }
                            }
                        }

                        GohuText {
                            id: selectorMonitorGlyph

                            anchors.centerIn: parent

                            visible:
                                (selectorAppIconBox.sourceMode
                                 === appControlWindow.killModeIndex
                                 && !!selectorAppIconBox.sourceItem._taskRecord)
                                || (selectorAppIconBox.sourceMode
                                    === appControlWindow.thermalModeIndex
                                    && !!selectorAppIconBox.sourceItem._thermalRecord
                                    && selectorAppIconBox.sourceItem.sensorKind
                                       !== "fan")
                                || (selectorAppIconBox.sourceMode
                                    === appControlWindow.systemModeIndex
                                    && !!selectorAppIconBox.sourceItem._systemRecord)

                            text:
                                appControlWindow.monitorResultIcon(selectorAppIconBox.sourceItem)

                            font.pixelSize:
                                selectorAppIconBox.sourceMode
                                === appControlWindow.killModeIndex
                                && !!selectorAppIconBox.sourceItem._taskRecord
                                ? 11
                                : 17

                            color:
                                resultButton.isPressed
                                ? Colors.black
                                : resultButton.isHovered
                                  || resultButton.isSelected
                                ? Colors.orange
                                : selectorAppIconBox.sourceMode
                                  === appControlWindow.killModeIndex
                                ? Colors.red
                                : selectorAppIconBox.sourceMode
                                  === appControlWindow.thermalModeIndex
                                ? appControlWindow.thermalAccent(selectorAppIconBox.sourceItem)
                                : appControlWindow.systemAccent(selectorAppIconBox.sourceItem)

                            layer.enabled: !resultButton.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0
                                radius: 6
                                samples: 5
                                opacity: 0.46
                                color:
                                    resultButton.isHovered
                                    || resultButton.isSelected
                                    ? Colors.orange
                                    : selectorAppIconBox.sourceMode
                                      === appControlWindow.killModeIndex
                                    ? Colors.red
                                    : selectorAppIconBox.sourceMode
                                      === appControlWindow.thermalModeIndex
                                    ? appControlWindow.thermalAccent(selectorAppIconBox.sourceItem)
                                    : appControlWindow.systemAccent(selectorAppIconBox.sourceItem)
                                transparentBorder: true
                            }
                        }

                        // Safe sampler: this reads a grab of the already-rendered
                        // Image instead of loading image://icon/... a second time.
                        Canvas {
                            id: selectorIconColorSampler

                            width: 18
                            height: 18

                            opacity: 0.001
                            z: -100

                            property string sampleSource: ""
                            property string originalSource: ""

                            function prepareSample() {
                                if (!sampleSource)
                                    return;

                                loadImage(
                                    sampleSource,
                                    Qt.size(width, height)
                                );

                                if (isImageLoaded(sampleSource))
                                    requestPaint();
                            }

                            onImageLoaded: requestPaint()

                            onPaint: {
                                if (!sampleSource
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

                                const glow =
                                    appControlWindow.classifyIconGlow(pixels);

                                appControlWindow.rememberIconGlow(
                                    originalSource,
                                    glow,
                                    false
                                );

                                selectorAppIconBox.verifiedSource =
                                    originalSource;

                                const finishedSource = sampleSource;

                                Qt.callLater(function() {
                                    selectorIconColorSampler.unloadImage(
                                        finishedSource
                                    );
                                    selectorIconColorSampler.sampleSource = "";
                                    selectorAppIconBox.iconGrabResult = null;
                                    selectorAppIconBox.samplingSource = "";
                                });
                            }
                        }

                        DropShadow {
                            anchors.fill: selectorAppIcon
                            source: selectorAppIcon

                            horizontalOffset: 0
                            verticalOffset: 0

                            radius: resultButton.isPressed ? 10 : 8
                            samples: resultButton.isPressed ? 7 : 5

                            opacity: selectorAppIcon.status === Image.Ready
                                     ? (resultButton.isPressed ? 0.85 : 0.52)
                                     : 0.0

                            color: resultButton.isPressed
                                   ? Colors.magenta
                                   : resultButton.isHovered
                                   ? Colors.orange
                                   : resultButton.isSelected
                                     && appControlWindow.keyboardActive
                                   ? Colors.yellow
                                   : resultButton.isSelected
                                   ? Colors.orange
                                   : selectorAppIconBox.sampledGlowColor === Colors.white
                                   ? Colors.cyan
                                   : selectorAppIconBox.sampledGlowColor

                            transparentBorder: true
                        }
                    }

                    Item {
                        id: resultNameGlowBox

                        width: Math.max(
                            0,
                            parent.width
                            - selectorAppIconBox.width
                            - parent.spacing
                        )
                        height:
                            appControlWindow.resultIsWindow(
                                modelData,
                                appControlWindow.selectedModeIndex
                            )
                            || appControlWindow.resultIsTab(
                                   modelData,
                                   appControlWindow.selectedModeIndex
                               )
                            || resultNameGlowBox.showingKillData
                            || (appControlWindow.selectedModeIndex
                                === appControlWindow.appsModeIndex
                                && appControlWindow.resultIsApplication(
                                       modelData,
                                       appControlWindow.selectedModeIndex
                                   ))
                            ? 36
                            : resultNameText.implicitHeight + 12

                        readonly property bool showingWindow:
                            appControlWindow.resultIsWindow(
                                modelData,
                                appControlWindow.selectedModeIndex
                            )

                        readonly property bool showingTab:
                            appControlWindow.resultIsTab(
                                modelData,
                                appControlWindow.selectedModeIndex
                            )

                        readonly property int sourceMode:
                            appControlWindow.resultSourceMode(
                                modelData,
                                appControlWindow.selectedModeIndex
                            )
                        readonly property var sourceItem:
                            appControlWindow.favoriteSourceItem(modelData)
                            || modelData

                        readonly property var liveTaskItem: {
                            // Force this binding to re-resolve on every task
                            // snapshot. FAVORITES wrappers do not themselves
                            // own live CPU/MEM/PID fields.
                            const revision = appControlWindow.taskMiniHistoryRevision;
                            return appControlWindow.liveTaskForMiniGraph(modelData)
                                   || sourceItem;
                        }

                        readonly property bool showingTask:
                            sourceMode === appControlWindow.killModeIndex
                            && !!sourceItem
                            && !!sourceItem._taskRecord

                        readonly property bool showingThermal:
                            sourceMode === appControlWindow.thermalModeIndex
                            && !!sourceItem
                            && !!sourceItem._thermalRecord

                        readonly property bool showingSystem:
                            sourceMode === appControlWindow.systemModeIndex
                            && !!sourceItem
                            && !!sourceItem._systemRecord

                        readonly property bool showingKillData:
                            showingTask || showingThermal || showingSystem

                        readonly property bool showingAppSource:
                            appControlWindow.selectedModeIndex
                            === appControlWindow.appsModeIndex
                            && appControlWindow.resultIsApplication(
                                   modelData,
                                   appControlWindow.selectedModeIndex
                               )

                        readonly property color idleTextColor:
                            showingWindow
                            && appControlWindow.isWindowOnSecondOutput(modelData)
                            ? Colors.white
                            : resultNameGlowBox.showingTask
                            ? Colors.red
                            : resultNameGlowBox.showingThermal
                            ? appControlWindow.thermalAccent(resultNameGlowBox.sourceItem)
                            : resultNameGlowBox.showingSystem
                            ? appControlWindow.systemAccent(resultNameGlowBox.sourceItem)
                            : appControlWindow.resultIsApplication(
                                  modelData,
                                  appControlWindow.selectedModeIndex
                              )
                              && selectorAppIconBox.visible
                            ? selectorAppIconBox.sampledGlowColor
                            : Colors.cyan

                        // White app/window labels keep a cyan halo.
                        readonly property color idleGlowColor:
                            idleTextColor === Colors.white
                            ? Colors.cyan
                            : idleTextColor

                        layer.enabled: !resultButton.isPressed
                                       && !resultButton.isHovered
                                       && !resultButton.isSelected

                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0

                            radius: 6
                            samples: 6

                            opacity: 0.38
                            color: resultNameGlowBox.idleGlowColor

                            transparentBorder: true
                        }

                        GohuText {
                            id: resultNameText

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8

                            anchors.verticalCenter:
                                resultNameGlowBox.showingWindow
                                || resultNameGlowBox.showingTab
                                || resultNameGlowBox.showingKillData
                                || resultNameGlowBox.showingAppSource
                                ? undefined
                                : parent.verticalCenter

                            anchors.top:
                                resultNameGlowBox.showingWindow
                                || resultNameGlowBox.showingTab
                                || resultNameGlowBox.showingKillData
                                || resultNameGlowBox.showingAppSource
                                ? parent.top
                                : undefined
                            anchors.topMargin:
                                resultNameGlowBox.showingWindow
                                || resultNameGlowBox.showingTab
                                || resultNameGlowBox.showingKillData
                                || resultNameGlowBox.showingAppSource
                                ? 1
                                : 0

                            text: appControlWindow.resultDisplayName(
                                      modelData,
                                      appControlWindow.selectedModeIndex
                                  )

                            font.pixelSize:
                                resultNameGlowBox.showingWindow
                                || resultNameGlowBox.showingKillData
                                || resultNameGlowBox.showingAppSource
                                ? 15
                                : 17
                            elide: Text.ElideRight

                            color: resultButton.isPressed
                                   ? Colors.black
                                   : resultButton.isHovered
                                   ? Colors.orange
                                   : resultButton.isSelected
                                   ? Colors.orange
                                   : resultNameGlowBox.idleTextColor
                        }

                        GohuText {
                            id: resultWindowSubName

                            visible: resultNameGlowBox.showingWindow

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8
                            anchors.top: resultNameText.bottom
                            anchors.topMargin: 1

                            text:
                                appControlWindow.windowDisplaySubName(modelData)

                            font.pixelSize: 12
                            elide: Text.ElideRight

                            color: resultButton.isPressed
                                   ? Colors.black
                                   : resultButton.isSelected
                                   ? Colors.orange
                                   : appControlWindow.isWindowOnSecondOutput(
                                         modelData
                                     )
                                   ? Colors.white
                                   : Colors.cyan

                            opacity: 1.0
                        }

                        GohuText {
                            id: resultTabSubName

                            visible: resultNameGlowBox.showingTab

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8
                            anchors.top: resultNameText.bottom
                            anchors.topMargin: 1

                            text:
                                modelData._tabUnavailable
                                ? (modelData.appName || "AT-SPI")
                                : (modelData.appName || "APPLICATION")

                            font.pixelSize: 10
                            elide: Text.ElideRight

                            color:
                                resultButton.isPressed
                                ? Colors.black
                                : resultButton.isSelected
                                ? Colors.orange
                                : Colors.cyan

                            opacity:
                                modelData._tabUnavailable ? 0.58 : 0.88
                        }

                        GohuText {
                            id: resultTaskSubName

                            visible: resultNameGlowBox.showingKillData

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8
                            anchors.top: resultNameText.bottom
                            anchors.topMargin: 0

                            text:
                                resultNameGlowBox.showingTask
                                ? "CPU "
                                  + Number(resultNameGlowBox.liveTaskItem.cpu || 0).toFixed(1)
                                  + "% • MEM "
                                  + Number(resultNameGlowBox.liveTaskItem.mem || 0).toFixed(1)
                                  + "% • PID "
                                  + String(resultNameGlowBox.liveTaskItem.pid || "?")
                                : resultNameGlowBox.showingThermal
                                ? resultNameGlowBox.sourceItem.sensorKind === "fan"
                                  ? Number(resultNameGlowBox.sourceItem.rpm || 0).toFixed(0)
                                    + " RPM • "
                                    + String(resultNameGlowBox.sourceItem.chip || "FAN")
                                  : appControlWindow.formatThermalMenuTemp(
                                        resultNameGlowBox.sourceItem.tempC
                                    )
                                    + " • "
                                    + String(resultNameGlowBox.sourceItem.chip || "SENSOR")
                                : String(resultNameGlowBox.sourceItem.metric || "")
                                  + " • "
                                  + String(resultNameGlowBox.sourceItem.category || "SYSTEM")

                            font.pixelSize: 10
                            elide: Text.ElideRight

                            color:
                                resultButton.isPressed
                                ? Colors.black
                                : resultButton.isSelected
                                ? Colors.orange
                                : resultNameGlowBox.showingThermal
                                ? appControlWindow.thermalAccent(resultNameGlowBox.sourceItem)
                                : resultNameGlowBox.showingSystem
                                ? appControlWindow.systemAccent(resultNameGlowBox.sourceItem)
                                : Number(resultNameGlowBox.liveTaskItem.cpu || 0) >= 25
                                ? Colors.red
                                : Colors.magenta

                            opacity: 0.90
                        }

                                                GohuText {
                            id: resultAppSourceSubName

                            visible: resultNameGlowBox.showingAppSource

                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8
                            anchors.top: resultNameText.bottom
                            anchors.topMargin: 1

                            text:
                                appControlWindow.appSourceLabel(modelData)

                            font.pixelSize: 10
                            elide: Text.ElideRight

                            color:
                                resultButton.isUnavailableApp
                                ? Colors.white
                                : appControlWindow.appEntryIsFlatpak(modelData)
                                ? Colors.magenta
                                : Colors.cyan

                            opacity:
                                resultButton.isUnavailableApp
                                ? 0.58
                                : 0.82
                        }
                    }
                }

                MouseArea {
                    id: resultMouse

                    anchors.fill: parent

                    acceptedButtons: Qt.LeftButton

                    onClicked: {
                        // A click is always an intentional mouse selection.
                        appControlWindow.modeRailFocused = false;
                        appControlWindow.keyboardActive = false;
                        appControlWindow.hoveredResultIndex = resultDelegate.index;
                        appControlWindow.selectedResultIndex = resultDelegate.index;

                        if (appControlWindow.resultIsApplication(
                                    modelData,
                                    appControlWindow.selectedModeIndex))
                            appControlWindow.rememberCurrentAppSelection();

                        appControlWindow.resetDetailActionSelection();

                        if (!resultButton.isUnavailableApp)
                            appControlWindow.activateSelectedResult();
                    }
                }

                Item {
                    id: favoriteStarButton

                    width: 30
                    height: 30

                    anchors.right: parent.right
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter

                    visible:
                        appControlWindow.selectedModeIndex
                        !== appControlWindow.windowsModeIndex

                    z: 500

                    readonly property bool favorite:
                        appControlWindow.isFavoriteItem(
                            modelData,
                            appControlWindow.selectedModeIndex
                        )

                    readonly property bool hovered:
                        favoriteStarMouse.containsMouse

                    // Normal unfavorited state is the original generic gray.
                    // Removing a favorite gives a brief black/red confirmation
                    // flash, then returns to gray automatically.
                    property bool removalFlash: false

                    readonly property var resolvedAppGlow:
                        selectorAppIconBox.visible
                        ? appControlWindow.cachedIconGlow(
                              selectorAppIcon.source
                          )
                        : null

                    readonly property int sourceMode:
                        appControlWindow.resultSourceMode(
                            modelData,
                            appControlWindow.selectedModeIndex
                        )
                    readonly property var sourceItem:
                        appControlWindow.favoriteSourceItem(modelData)
                        || modelData
                    readonly property bool monitorColorReady:
                        sourceMode === appControlWindow.thermalModeIndex
                        || sourceMode === appControlWindow.systemModeIndex
                        || sourceMode === appControlWindow.killModeIndex

                    readonly property bool appColorReady:
                        monitorColorReady
                        || !selectorAppIconBox.visible
                        || resolvedAppGlow !== null

                    readonly property color appStarColor:
                        sourceMode === appControlWindow.killModeIndex
                        ? Colors.red
                        : sourceMode === appControlWindow.thermalModeIndex
                        ? appControlWindow.thermalAccent(sourceItem)
                        : sourceMode === appControlWindow.systemModeIndex
                        ? appControlWindow.systemAccent(sourceItem)
                        : selectorAppIconBox.visible
                          && resolvedAppGlow !== null
                        ? resolvedAppGlow
                        : resultNameGlowBox.idleTextColor

                    readonly property color appStarGlowColor:
                        appStarColor === Colors.white
                        ? Colors.cyan
                        : appStarColor

                    Timer {
                        id: removalFlashTimer

                        interval: 240
                        repeat: false

                        onTriggered: {
                            favoriteStarButton.removalFlash = false;
                        }
                    }

                    GohuText {
                        id: favoriteStarGlyph

                        anchors.centerIn: parent

                        text: favoriteStarButton.favorite ? "✦" : "✧"

                        font.pixelSize: 19

                        color:
                               favoriteStarButton.favorite
                               && favoriteStarButton.sourceItem
                               && favoriteStarButton.sourceItem._hiddenCommand
                                  === true
                               ? Colors.magenta
                               : favoriteStarButton.favorite
                                 && appControlWindow.selectedModeIndex
                                    === appControlWindow.runModeIndex
                               ? Colors.magenta
                               : favoriteStarButton.favorite
                                 && favoriteStarButton.appColorReady
                               ? favoriteStarButton.appStarColor
                               : favoriteStarButton.removalFlash
                               ? Colors.black
                               : Colors.white

                        opacity: favoriteStarButton.favorite
                                 && favoriteStarButton.appColorReady
                                 ? 1.0
                                 : favoriteStarButton.removalFlash
                                 ? 1.0
                                 : 0.62
                    }

                    DropShadow {
                        anchors.fill: favoriteStarGlyph
                        source: favoriteStarGlyph

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: favoriteStarButton.favorite
                                ? 8
                                : favoriteStarButton.removalFlash
                                ? 8
                                : 5
                        samples: 5

                        opacity: favoriteStarButton.favorite
                                 && favoriteStarButton.appColorReady
                                 ? 0.58
                                 : favoriteStarButton.removalFlash
                                 ? 0.72
                                 : (favoriteStarButton.hovered ? 0.20 : 0.08)

                        color:
                               favoriteStarButton.favorite
                               && favoriteStarButton.sourceItem
                               && favoriteStarButton.sourceItem._hiddenCommand
                                  === true
                               ? Colors.magenta
                               : favoriteStarButton.favorite
                                 && appControlWindow.selectedModeIndex
                                    === appControlWindow.runModeIndex
                               ? Colors.magenta
                               : favoriteStarButton.favorite
                                 && favoriteStarButton.appColorReady
                               ? favoriteStarButton.appStarGlowColor
                               : favoriteStarButton.removalFlash
                               ? Colors.red
                               : Colors.white

                        transparentBorder: true
                    }

                    MouseArea {
                        id: favoriteStarMouse

                        anchors.fill: parent

                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton
                        preventStealing: true

                        onEntered: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.hoveredResultIndex =
                                resultDelegate.index;
                            appControlWindow.selectedResultIndex =
                                resultDelegate.index;
                        }

                        onClicked: function(mouse) {
                            mouse.accepted = true;

                            appControlWindow.selectedResultIndex =
                                resultDelegate.index;

                            const wasFavorite = favoriteStarButton.favorite;

                            appControlWindow.toggleFavorite(
                                modelData,
                                appControlWindow.selectedModeIndex
                            );

                            if (wasFavorite) {
                                favoriteStarButton.removalFlash = true;
                                removalFlashTimer.restart();
                            }
                        }
                    }
                }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 3
                        z: -1

                        opacity: resultButton.isSelected || resultButton.isHovered ? 0.45 : 0.0

                        color: appControlWindow.selectedModeIndex === appControlWindow.killModeIndex ? Colors.red : Colors.orange
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

                    appControlWindow.modeRailFocused = false;
                    appControlWindow.hoveredResultIndex = hoveredIndex;

                    if (hoveredIndex < 0)
                        return;

                    appControlWindow.keyboardActive = false;
                    appControlWindow.selectedResultIndex = hoveredIndex;

                    if (appControlWindow.selectedResultIsApplication())
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
        // FAVORITES / COMBI SCOPE + SHARED SOURCE FILTER
        // ========================================================

        Rectangle {
            id: favoritesModeSelector
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: searchHeader.bottom
            height: 78
            visible: appControlWindow.selectedModeIndex === appControlWindow.favoritesModeIndex
            color: Colors.black
            z: 260

            Column {
                anchors.fill: parent
                spacing: 0

                Item {
                    width: parent.width
                    height: 34

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 5
                        anchors.rightMargin: 5
                        anchors.topMargin: 4
                        anchors.bottomMargin: 4
                        spacing: 5

                        Repeater {
                            model: [
                                appControlWindow.favoritesScopeFavorites,
                                appControlWindow.favoritesScopeCombi
                            ]

                            Rectangle {
                                id: favoriteScopeButton
                                required property int modelData
                                width: (parent.width - parent.spacing) / 2
                                height: parent.height

                                property bool isSelected:
                                    appControlWindow.favoritesScopeMode === modelData
                                property bool isHovered: favoriteScopeMouse.containsMouse
                                property bool isPressed: favoriteScopeMouse.pressed
                                readonly property color accent:
                                    modelData === appControlWindow.favoritesScopeFavorites
                                    ? Colors.magenta : Colors.orange
                                readonly property color stateColor:
                                    isSelected ? Colors.magenta
                                    : isHovered ? Colors.orange
                                    : accent

                                color: isPressed ? Colors.magenta
                                       : isHovered || isSelected ? Colors.yellow
                                       : Colors.dark
                                border.width: 1
                                border.color: stateColor

                                GohuText {
                                    id: favoriteScopeText
                                    anchors.centerIn: parent
                                    text:
                                        favoriteScopeButton.modelData
                                        === appControlWindow.favoritesScopeCombi
                                        ? "⌕  COMBI"
                                        : "✦  FAVORITES"
                                    font.pixelSize: 10
                                    color: favoriteScopeButton.isPressed
                                           ? Colors.black
                                           : favoriteScopeButton.stateColor
                                }

                                DropShadow {
                                    anchors.fill: favoriteScopeText
                                    source: favoriteScopeText
                                    radius: 7
                                    samples: 7
                                    opacity: favoriteScopeButton.isPressed ? 0.0
                                             : favoriteScopeButton.isSelected
                                               || favoriteScopeButton.isHovered
                                             ? 0.62 : 0.46
                                    color: favoriteScopeButton.stateColor
                                    transparentBorder: true
                                }

                                MouseArea {
                                    id: favoriteScopeMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked:
                                        appControlWindow.setFavoritesScopeMode(
                                            favoriteScopeButton.modelData
                                        )
                                }

                                RectangularShadow {
                                    anchors.fill: parent
                                    spread: 3
                                    z: -1
                                    opacity: favoriteScopeButton.isSelected
                                             || favoriteScopeButton.isHovered
                                             ? 0.48 : 0.28
                                    color: favoriteScopeButton.stateColor
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Colors.magenta
                    opacity: 0.42
                }

                Item {
                    width: parent.width
                    height: 43

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: 5
                        anchors.rightMargin: 5
                        anchors.topMargin: 5
                        anchors.bottomMargin: 6
                        spacing: 4

                        Repeater {
                            model: [
                                appControlWindow.favoritesFilterAll,
                                appControlWindow.appsModeIndex,
                                appControlWindow.runModeIndex,
                                appControlWindow.windowsModeIndex,
                                appControlWindow.thermalModeIndex,
                                appControlWindow.killModeIndex,
                                appControlWindow.systemModeIndex
                            ]

                            Rectangle {
                                id: favoriteFilterButton
                                required property int modelData
                                width: (parent.width - parent.spacing * 6) / 7
                                height: parent.height

                                property bool isSelected:
                                    appControlWindow.favoritesFilterMode === modelData
                                property bool isHovered: favoriteFilterMouse.containsMouse
                                property bool isPressed: favoriteFilterMouse.pressed
                                readonly property color accent:
                                    appControlWindow.favoritesFilterAccent(modelData)
                                readonly property color stateColor:
                                    isSelected ? Colors.magenta
                                    : isHovered ? Colors.orange
                                    : accent

                                color: isPressed ? Colors.magenta
                                       : isHovered || isSelected ? Colors.yellow
                                       : Colors.dark
                                border.width: 1
                                border.color: stateColor

                                GohuText {
                                    id: favoriteFilterIcon
                                    anchors.centerIn: parent
                                    text:
                                        appControlWindow.favoritesFilterSymbol(
                                            favoriteFilterButton.modelData
                                        )
                                    font.pixelSize:
                                        favoriteFilterButton.modelData
                                        === appControlWindow.thermalModeIndex
                                        || favoriteFilterButton.modelData
                                           === appControlWindow.systemModeIndex
                                        ? 14
                                        : favoriteFilterButton.modelData
                                          === appControlWindow.favoritesFilterAll
                                        ? 8 : 9
                                    color: favoriteFilterButton.isPressed
                                           ? Colors.black
                                           : favoriteFilterButton.stateColor
                                }

                                DropShadow {
                                    anchors.fill: favoriteFilterIcon
                                    source: favoriteFilterIcon
                                    radius: 7
                                    samples: 7
                                    opacity: favoriteFilterButton.isPressed ? 0.0
                                             : favoriteFilterButton.isSelected
                                               || favoriteFilterButton.isHovered
                                             ? 0.62 : 0.46
                                    color: favoriteFilterButton.stateColor
                                    transparentBorder: true
                                }

                                MouseArea {
                                    id: favoriteFilterMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked:
                                        appControlWindow.setFavoritesFilterMode(
                                            favoriteFilterButton.modelData
                                        )
                                }

                                RectangularShadow {
                                    anchors.fill: parent
                                    spread: 3
                                    z: -1
                                    opacity: favoriteFilterButton.isSelected
                                             || favoriteFilterButton.isHovered
                                             ? 0.48 : 0.28
                                    color: favoriteFilterButton.stateColor
                                }
                            }
                        }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Colors.cyan

                RectangularShadow {
                    anchors.fill: parent
                    spread: 3
                    z: -1
                    opacity: 0.30
                    color: Colors.cyan
                }
            }
        }

        // ========================================================
        // KILL GLOBAL ACTIONS
        // ========================================================

        Rectangle {
            id: killGlobalSelector
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: searchHeader.bottom
            height: 42
            visible:
                appControlWindow.selectedModeIndex
                === appControlWindow.killModeIndex
            color: Colors.black
            z: 260

            Row {
                anchors.fill: parent
                anchors.leftMargin: 5
                anchors.rightMargin: 5
                anchors.topMargin: 5
                anchors.bottomMargin: 6
                spacing: 4

                Repeater {
                    model: [
                        {
                            key: "kill-all",
                            label: "KILL ALL",
                            accent: Colors.red,
                            available: appControlWindow.killAllEligibleTasks().length > 0,
                            armed: false
                        },
                        {
                            key: "kill-hog",
                            label:
                                appControlWindow.killHogArmedPid > 0
                                ? "CONFIRM HOG"
                                : "KILL HOG",
                            accent: Colors.orange,
                            available:
                                appControlWindow.killHogArmedPid > 0
                                || !!appControlWindow.mostDemandingVisibleTask(),
                            armed: appControlWindow.killHogArmedPid > 0
                        },
                        {
                            key: "limit",
                            label:
                                appControlWindow.selectedTaskHasSoftLimit()
                                ? "UNLIMIT"
                                : "LIMIT",
                            accent: Colors.yellow,
                            available: appControlWindow.selectedResultIsTask(),
                            armed: appControlWindow.selectedTaskHasSoftLimit()
                        },
                        {
                            key: "freeze",
                            label:
                                appControlWindow.selectedTaskIsFrozen()
                                ? "RESUME"
                                : "FREEZE",
                            accent:
                                appControlWindow.selectedTaskIsFrozen()
                                ? Colors.omnitrix
                                : Colors.cyan,
                            available: appControlWindow.selectedResultIsTask(),
                            armed: appControlWindow.selectedTaskIsFrozen()
                        }
                    ]

                    Rectangle {
                        id: killGlobalButton
                        required property var modelData
                        width: (parent.width - parent.spacing * 3) / 4
                        height: parent.height

                        property bool canRun: !!modelData.available
                        property bool isHovered: killGlobalMouse.containsMouse
                        property bool isPressed: killGlobalMouse.pressed

                        color:
                            isPressed
                            ? Colors.magenta
                            : (isHovered && canRun) || modelData.armed
                            ? Colors.yellow
                            : Colors.dark
                        opacity: canRun ? 1.0 : 0.34
                        border.width: 1
                        border.color: canRun ? modelData.accent : Colors.white

                        GohuText {
                            id: killGlobalText
                            anchors.centerIn: parent
                            text: killGlobalButton.modelData.label
                            font.pixelSize: 9
                            color:
                                killGlobalButton.isPressed
                                ? Colors.black
                                : killGlobalButton.modelData.accent
                        }

                        DropShadow {
                            anchors.fill: killGlobalText
                            source: killGlobalText
                            radius: 7
                            samples: 7
                            opacity:
                                killGlobalButton.canRun
                                ? (killGlobalButton.isHovered
                                   || killGlobalButton.modelData.armed
                                   ? 0.66 : 0.46)
                                : 0.0
                            color: killGlobalButton.modelData.accent
                            transparentBorder: true
                        }

                        MouseArea {
                            id: killGlobalMouse
                            anchors.fill: parent
                            enabled: killGlobalButton.canRun
                            hoverEnabled: true

                            onClicked: {
                                appControlWindow.keyboardActive = false;

                                if (modelData.key === "kill-all")
                                    appControlWindow.requestKillAllEligibleTasks();
                                else if (modelData.key === "kill-hog")
                                    appControlWindow.triggerKillHog();
                                else if (modelData.key === "limit")
                                    appControlWindow.toggleSelectedTaskLimit();
                                else if (modelData.key === "freeze")
                                    appControlWindow.toggleSelectedTaskFreeze();
                            }
                        }

                        RectangularShadow {
                            anchors.fill: parent
                            spread: 3
                            z: -1
                            opacity:
                                killGlobalButton.canRun
                                ? (killGlobalButton.isHovered
                                   || killGlobalButton.modelData.armed
                                   ? 0.50 : 0.28)
                                : 0.0
                            color: killGlobalButton.modelData.accent
                        }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Colors.red

                RectangularShadow {
                    anchors.fill: parent
                    spread: 3
                    z: -1
                    opacity: 0.34
                    color: Colors.red
                }
            }
        }

        // ========================================================
        // KILL VIEW SELECTOR — DETAILED / THERMAL / SYSTEM
        // ========================================================

                Rectangle {
            id: thermalViewSelector

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: searchHeader.bottom

            height: 42
            visible:
                appControlWindow.selectedModeIndex
                === appControlWindow.thermalModeIndex

            color: Colors.black
            z: 260

            Row {
                anchors.fill: parent
                anchors.leftMargin: 7
                anchors.rightMargin: 7
                anchors.topMargin: 5
                anchors.bottomMargin: 6
                spacing: 7

                Rectangle {
                    id: thermalViewThermalButton

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height

                    opacity: 1.0

                    property bool isSelected:
                        appControlWindow.thermalViewMode
                        === appControlWindow.thermalViewThermal
                    property bool isHovered:
                        thermalViewThermalMouse.containsMouse
                    property bool isPressed:
                        thermalViewThermalMouse.pressed

                    readonly property color subModeGlowColor:
                        isSelected
                        ? Colors.magenta
                        : isHovered
                        ? Colors.orange
                        : Colors.orange

                    color:
                        isPressed
                        ? Colors.magenta
                        : isHovered || isSelected
                        ? Colors.yellow
                        : Colors.dark

                    border.width: 1
                    border.color: thermalViewThermalButton.subModeGlowColor

                    Row {
                        id: thermalViewThermalContent
                        anchors.centerIn: parent
                        spacing: 6
                        opacity: 1.0

                        GohuText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "🌡"
                            font.pixelSize: 15
                            color:
                                thermalViewThermalButton.isPressed
                                ? Colors.black
                                : thermalViewThermalButton.subModeGlowColor
                        }

                        GohuText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "THERMAL"
                            font.pixelSize: 13
                            color:
                                thermalViewThermalButton.isPressed
                                ? Colors.black
                                : thermalViewThermalButton.subModeGlowColor
                        }
                    }

                    DropShadow {
                        anchors.fill: thermalViewThermalContent
                        source: thermalViewThermalContent
                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 8
                        samples: 7

                        opacity:
                            thermalViewThermalButton.isPressed
                            ? 0.0
                            : thermalViewThermalButton.isSelected
                            ? 0.64
                            : thermalViewThermalButton.isHovered
                            ? 0.60
                            : 0.50

                        color: thermalViewThermalButton.subModeGlowColor
                        transparentBorder: true
                    }

                    MouseArea {
                        id: thermalViewThermalMouse
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            appControlWindow.setThermalViewMode(
                                appControlWindow.thermalViewThermal
                            );
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        spread: 4
                        z: -1
                        opacity:
                            thermalViewThermalButton.isHovered
                            || thermalViewThermalButton.isSelected
                            ? 0.52
                            : 0.34
                        color: thermalViewThermalButton.subModeGlowColor
                    }
                }

                Rectangle {
                    id: thermalViewFansButton

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height

                    opacity: 1.0

                    property bool isSelected:
                        appControlWindow.thermalViewMode
                        === appControlWindow.thermalViewFans
                    property bool isHovered:
                        thermalViewFansMouse.containsMouse
                    property bool isPressed:
                        thermalViewFansMouse.pressed

                    readonly property color subModeGlowColor:
                        isSelected
                        ? Colors.magenta
                        : isHovered
                        ? Colors.orange
                        : Colors.omnitrix

                    color:
                        isPressed
                        ? Colors.magenta
                        : isHovered || isSelected
                        ? Colors.yellow
                        : Colors.dark

                    border.width: 1
                    border.color: thermalViewFansButton.subModeGlowColor

                    Row {
                        id: thermalViewFansContent
                        anchors.centerIn: parent
                        spacing: 6
                        opacity: 1.0

                        Rectangle {
                            width: 20
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter

                            color: Colors.black
                            border.width: 1
                            border.color:
                                thermalViewFansButton.subModeGlowColor

                            GohuText {
                                anchors.centerIn: parent
                                text: "✇"
                                font.pixelSize: 14
                                color:
                                    thermalViewFansButton.isPressed
                                    ? Colors.black
                                    : thermalViewFansButton.subModeGlowColor
                            }
                        }

                        GohuText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "FANS"
                            font.pixelSize: 13
                            color:
                                thermalViewFansButton.isPressed
                                ? Colors.black
                                : thermalViewFansButton.subModeGlowColor
                        }
                    }

                    DropShadow {
                        anchors.fill: thermalViewFansContent
                        source: thermalViewFansContent
                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 8
                        samples: 7

                        opacity:
                            thermalViewFansButton.isPressed
                            ? 0.0
                            : thermalViewFansButton.isSelected
                            ? 0.64
                            : thermalViewFansButton.isHovered
                            ? 0.60
                            : 0.50

                        color: thermalViewFansButton.subModeGlowColor
                        transparentBorder: true
                    }

                    MouseArea {
                        id: thermalViewFansMouse
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            appControlWindow.setThermalViewMode(
                                appControlWindow.thermalViewFans
                            );
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        spread: 4
                        z: -1
                        opacity:
                            thermalViewFansButton.isHovered
                            || thermalViewFansButton.isSelected
                            ? 0.52
                            : 0.34
                        color: thermalViewFansButton.subModeGlowColor
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Colors.orange

                RectangularShadow {
                    anchors.fill: parent
                    spread: 2
                    z: -1
                    opacity: 0.26
                    color: Colors.orange
                }
            }
        }

        // ========================================================
        // WINDOWS LIST SELECTOR — WINDOWS / TABS
        // ========================================================

        Rectangle {
            id: windowListSelector

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: searchHeader.bottom

            height: 42
            visible:
                appControlWindow.selectedModeIndex
                === appControlWindow.windowsModeIndex

            color: Colors.black
            z: 260

            Row {
                anchors.fill: parent
                anchors.leftMargin: 7
                anchors.rightMargin: 7
                anchors.topMargin: 5
                anchors.bottomMargin: 6
                spacing: 7

                Rectangle {
                    id: windowListWindowsButton

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height

                    opacity: 1.0

                    property bool isSelected:
                        appControlWindow.windowListMode
                        === appControlWindow.windowListWindows
                    property bool isHovered:
                        windowListWindowsMouse.containsMouse
                    property bool isPressed:
                        windowListWindowsMouse.pressed

                    readonly property color subModeGlowColor:
                        isSelected
                        ? Colors.magenta
                        : isHovered
                        ? Colors.orange
                        : Colors.omnitrix

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: windowListWindowsButton.subModeGlowColor

                    GohuText {
                        id: windowListWindowsText
                        anchors.centerIn: parent

                        text: "WINDOWS"
                        font.pixelSize: 14
                        opacity: 1.0

                        color:
                            windowListWindowsButton.isPressed
                            ? Colors.black
                            : windowListWindowsButton.subModeGlowColor
                    }

                    DropShadow {
                        anchors.fill: windowListWindowsText
                        source: windowListWindowsText
                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 8
                        samples: 7

                        opacity:
                            windowListWindowsButton.isPressed
                            ? 0.0
                            : windowListWindowsButton.isSelected
                            ? 0.64
                            : windowListWindowsButton.isHovered
                            ? 0.60
                            : 0.50

                        color: windowListWindowsButton.subModeGlowColor
                        transparentBorder: true
                    }

                    MouseArea {
                        id: windowListWindowsMouse
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            appControlWindow.setWindowListMode(
                                appControlWindow.windowListWindows
                            );
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        spread: 4
                        z: -1

                        opacity:
                            windowListWindowsButton.isHovered
                            || windowListWindowsButton.isSelected
                            ? 0.52
                            : 0.34

                        color: windowListWindowsButton.subModeGlowColor
                    }
                }

                Rectangle {
                    id: windowListTabsButton

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height

                    opacity: 1.0

                    property bool isSelected:
                        appControlWindow.windowListMode
                        === appControlWindow.windowListTabs
                    property bool isHovered:
                        windowListTabsMouse.containsMouse
                    property bool isPressed:
                        windowListTabsMouse.pressed

                    readonly property color subModeGlowColor:
                        isSelected
                        ? Colors.magenta
                        : isHovered
                        ? Colors.orange
                        : Colors.magenta

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: windowListTabsButton.subModeGlowColor

                    GohuText {
                        id: windowListTabsText
                        anchors.centerIn: parent

                        text: "TABS"
                        font.pixelSize: 14
                        opacity: 1.0

                        color:
                            windowListTabsButton.isPressed
                            ? Colors.black
                            : windowListTabsButton.subModeGlowColor
                    }

                    DropShadow {
                        anchors.fill: windowListTabsText
                        source: windowListTabsText
                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 8
                        samples: 7

                        opacity:
                            windowListTabsButton.isPressed
                            ? 0.0
                            : windowListTabsButton.isSelected
                            ? 0.64
                            : windowListTabsButton.isHovered
                            ? 0.60
                            : 0.50

                        color: windowListTabsButton.subModeGlowColor
                        transparentBorder: true
                    }

                    MouseArea {
                        id: windowListTabsMouse
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            appControlWindow.setWindowListMode(
                                appControlWindow.windowListTabs
                            );
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        spread: 4
                        z: -1

                        opacity:
                            windowListTabsButton.isHovered
                            || windowListTabsButton.isSelected
                            ? 0.52
                            : 0.34

                        color: windowListTabsButton.subModeGlowColor
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                height: 1
                color: Colors.cyan

                RectangularShadow {
                    anchors.fill: parent
                    spread: 3
                    z: -1
                    opacity: 0.30
                    color: Colors.cyan
                }
            }
        }

        // ========================================================
        // APPS SOURCE SELECTOR — NATIVE / FLATPAK
        // ========================================================

                Rectangle {
            id: appSourceSelector

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: searchHeader.bottom

            height: 42
            visible:
                appControlWindow.selectedModeIndex
                === appControlWindow.appsModeIndex

            color: Colors.black
            z: 260

            Row {
                anchors.fill: parent
                anchors.leftMargin: 7
                anchors.rightMargin: 7
                anchors.topMargin: 5
                anchors.bottomMargin: 6
                spacing: 7

                Repeater {
                    model: [
                        {
                            label: "-⋆♱⋆-",
                            mode: appControlWindow.appSourceNative,
                            accent: Colors.cyan
                        },
                        {
                            label: "⋆˙⟡ ⌯⛟\nFLATPACK",
                            mode: appControlWindow.appSourceFlatpak,
                            accent: Colors.magenta
                        },
                        {
                            label: "HIDDEN",
                            mode: appControlWindow.appSourceHidden,
                            accent: Colors.yellow
                        }
                    ]

                    Rectangle {
                        id: appSourceModeButton

                        required property var modelData

                        width: (appSourceSelector.width - 28) / 3
                        height: parent.height

                    opacity: 1.0

                        property bool isSelected:
                            appControlWindow.appSourceMode
                            === modelData.mode
                        property bool isHovered:
                            appSourceModeMouse.containsMouse
                        property bool isPressed:
                            appSourceModeMouse.pressed

                        readonly property color subModeGlowColor:
                            isSelected
                            ? Colors.magenta
                            : isHovered
                            ? Colors.orange
                            : modelData.accent

                    color:
                            isPressed
                            ? Colors.magenta
                            : isHovered || isSelected
                            ? Colors.yellow
                            : Colors.dark

                        border.width: 1
                        border.color: subModeGlowColor

                        GohuText {
                            id: appSourceModeText
                            anchors.centerIn: parent

                            text:
                                modelData.mode
                                === appControlWindow.appSourceHidden
                                ? (appSourceModeButton.isHovered
                                   || appSourceModeButton.isSelected
                                   || appControlWindow.hiddenFaceBlinking
                                   ? "|ω･`ς)"
                                   : "|ω-ς)")
                                : modelData.label

                            font.pixelSize:
                                modelData.mode
                                === appControlWindow.appSourceFlatpak
                                ? 10
                                : 14

                            horizontalAlignment: Text.AlignHCenter
                            lineHeight: 0.88
                            opacity: 1.0

                            color:
                                appSourceModeButton.isPressed
                                ? Colors.black
                                : appSourceModeButton.subModeGlowColor
                        }

                        DropShadow {
                            anchors.fill: appSourceModeText
                            source: appSourceModeText

                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 8
                            samples: 7

                            opacity:
                                appSourceModeButton.isPressed
                                ? 0.0
                                : appSourceModeButton.isSelected
                                ? 0.64
                                : appSourceModeButton.isHovered
                                ? 0.60
                                : 0.50

                            color: appSourceModeButton.subModeGlowColor
                            transparentBorder: true
                        }

                    MouseArea {
                            id: appSourceModeMouse
                            anchors.fill: parent
                            hoverEnabled: true

                            onClicked: {
                                appControlWindow.setAppSourceMode(
                                    modelData.mode
                                );
                            }
                        }

                        RectangularShadow {
                            anchors.fill: parent
                            spread: 4
                            z: -1
                            opacity:
                                appSourceModeButton.isHovered
                                || appSourceModeButton.isSelected
                                ? 0.52
                                : 0.34
                            color: appSourceModeButton.subModeGlowColor
                        }
                    }
                }
            }

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: 1
                color: Colors.cyan

                RectangularShadow {
                    anchors.fill: parent
                    spread: 3
                    z: -1
                    opacity: 0.30
                    color: Colors.cyan
                }
            }
        }

        // ========================================================
        // RUN LIST SELECTOR — USER / TERMINAL / SYSTEM
        // ========================================================

        Rectangle {
            id: runListSelector

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: searchHeader.bottom

            height: 42
            visible:
                appControlWindow.selectedModeIndex
                === appControlWindow.runModeIndex

            color: Colors.black
            z: 260

            Row {
                anchors.fill: parent

                anchors.leftMargin: 7
                anchors.rightMargin: 7
                anchors.topMargin: 5
                anchors.bottomMargin: 6

                spacing: 7

                Rectangle {
                    id: runListUserButton

                    width: (parent.width - (parent.spacing * 2)) / 3
                    height: parent.height

                    opacity: 1.0

                    property bool isSelected:
                        appControlWindow.runListMode
                        === appControlWindow.runListUser
                    property bool isHovered: runListUserMouse.containsMouse
                    property bool isPressed: runListUserMouse.pressed

                    readonly property color subModeGlowColor:
                        isSelected
                        ? Colors.magenta
                        : isHovered
                        ? Colors.orange
                        : Colors.cyan

                    color:
                        isPressed
                        ? Colors.magenta
                        : isHovered || isSelected
                        ? Colors.yellow
                        : Colors.dark

                    border.width: 1
                    border.color: runListUserButton.subModeGlowColor
                    GohuText {
                        id: runListUserText

                        anchors.centerIn: parent

                        text: "﹏݁˖✍︎๋࣭⭑₊"

                        font.pixelSize: 16

                        color:
                               runListUserButton.isPressed
                               ? Colors.black
                               : runListUserButton.subModeGlowColor
                    }

                    DropShadow {
                        anchors.fill: runListUserText
                        source: runListUserText

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 8
                        samples: 7

                        opacity: runListUserButton.isPressed
                                 ? 0.0
                                 : runListUserButton.isSelected
                                   || runListUserButton.isHovered
                                 ? 0.64
                                 : 0.50

                        color: runListUserButton.subModeGlowColor

                        transparentBorder: true
                    }

                    MouseArea {
                        id: runListUserMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.setRunListMode(
                                appControlWindow.runListUser
                            );
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 4
                        z: -1

                        opacity: runListUserButton.isSelected
                                 || runListUserButton.isHovered
                                 ? 0.52
                                 : 0.34

                        color: runListUserButton.subModeGlowColor
                    }
                }

                Rectangle {
                    id: runListTerminalButton

                    width: (parent.width - (parent.spacing * 2)) / 3
                    height: parent.height

                    opacity: 1.0

                    property bool isSelected:
                        appControlWindow.runListMode
                        === appControlWindow.runListTerminal
                    property bool isHovered:
                        runListTerminalMouse.containsMouse
                    property bool isPressed:
                        runListTerminalMouse.pressed

                    readonly property color subModeGlowColor:
                        isSelected
                        ? Colors.magenta
                        : isHovered
                        ? Colors.orange
                        : Colors.magenta

                    color:
                        isPressed
                        ? Colors.magenta
                        : isHovered || isSelected
                        ? Colors.yellow
                        : Colors.dark

                    border.width: 1
                    border.color: runListTerminalButton.subModeGlowColor
                    GohuText {
                        id: runListTerminalText

                        anchors.centerIn: parent

                        text: "⌨"

                        font.pixelSize: 18

                        color:
                               runListTerminalButton.isPressed
                               ? Colors.black
                               : runListTerminalButton.subModeGlowColor
                    }

                    DropShadow {
                        anchors.fill: runListTerminalText
                        source: runListTerminalText

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 8
                        samples: 7

                        opacity: runListTerminalButton.isPressed
                                 ? 0.0
                                 : runListTerminalButton.isSelected
                                   || runListTerminalButton.isHovered
                                 ? 0.64
                                 : 0.50

                        color: runListTerminalButton.subModeGlowColor

                        transparentBorder: true
                    }

                    MouseArea {
                        id: runListTerminalMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.setRunListMode(
                                appControlWindow.runListTerminal
                            );
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 4
                        z: -1

                        opacity: runListTerminalButton.isSelected
                                 || runListTerminalButton.isHovered
                                 ? 0.52
                                 : 0.34

                        color: runListTerminalButton.subModeGlowColor
                    }
                }

                Rectangle {
                    id: runListAllButton

                    width: (parent.width - (parent.spacing * 2)) / 3
                    height: parent.height

                    opacity: 1.0

                    property bool isSelected:
                        appControlWindow.runListMode
                        === appControlWindow.runListAll
                    property bool isHovered: runListAllMouse.containsMouse
                    property bool isPressed: runListAllMouse.pressed

                    readonly property color subModeGlowColor:
                        isSelected
                        ? Colors.magenta
                        : isHovered
                        ? Colors.orange
                        : Colors.omnitrix

                    color:
                        isPressed
                        ? Colors.magenta
                        : isHovered || isSelected
                        ? Colors.yellow
                        : Colors.dark

                    border.width: 1
                    border.color: runListAllButton.subModeGlowColor
                    GohuText {
                        id: runListAllText

                        anchors.centerIn: parent

                        text: "🖳"

                        font.pixelSize: 18

                        color:
                               runListAllButton.isPressed
                               ? Colors.black
                               : runListAllButton.subModeGlowColor
                    }

                    DropShadow {
                        anchors.fill: runListAllText
                        source: runListAllText

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 8
                        samples: 7

                        opacity: runListAllButton.isPressed
                                 ? 0.0
                                 : runListAllButton.isSelected
                                   || runListAllButton.isHovered
                                 ? 0.64
                                 : 0.50

                        color: runListAllButton.subModeGlowColor

                        transparentBorder: true
                    }

                    MouseArea {
                        id: runListAllMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.setRunListMode(
                                appControlWindow.runListAll
                            );
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 4
                        z: -1

                        opacity: runListAllButton.isSelected
                                 || runListAllButton.isHovered
                                 ? 0.52
                                 : 0.34

                        color: runListAllButton.subModeGlowColor
                    }
                }
            }

            Rectangle {
                id: runListBottomDivider

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom

                height: 1
                color: Colors.cyan

                RectangularShadow {
                    anchors.fill: parent

                    spread: 3
                    z: -1

                    opacity: 0.30
                    color: Colors.cyan
                }
            }
        }

        // ========================================================
        // APPS LAUNCH SELECTOR — NORMAL / BOTTLES
        // ========================================================

        Rectangle {
            id: appLaunchSelector

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            height: 48
            visible:
                appControlWindow.selectedModeIndex
                === appControlWindow.appsModeIndex

            color: Colors.black
            z: 250

            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                height: 1
                color: Colors.cyan

                RectangularShadow {
                    anchors.fill: parent
                    spread: 3
                    z: -1
                    opacity: 0.38
                    color: Colors.cyan
                }
            }

            Row {
                anchors.fill: parent
                anchors.leftMargin: 7
                anchors.rightMargin: 7
                anchors.topMargin: 7
                anchors.bottomMargin: 6
                spacing: 7

                Rectangle {
                    id: appLaunchNormalButton

                    width: (parent.width - (parent.spacing * 2)) / 3
                    height: parent.height

                    opacity: 1.0

                    property bool isSelected:
                        appControlWindow.appLaunchMode
                        === appControlWindow.appLaunchNormal
                    property bool isHovered:
                        appLaunchNormalMouse.containsMouse
                    property bool isPressed:
                        appLaunchNormalMouse.pressed

                    readonly property color subModeGlowColor:
                        isSelected
                        ? Colors.magenta
                        : isHovered
                        ? Colors.orange
                        : Colors.cyan

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: appLaunchNormalButton.subModeGlowColor

                    GohuText {
                        id: appLaunchNormalText
                        anchors.centerIn: parent

                        text: "⌯♱ ๋࣭⭑"
                        font.pixelSize: 16
                        opacity: 1.0
                        color:
                            appLaunchNormalButton.isPressed
                            ? Colors.black
                            : appLaunchNormalButton.subModeGlowColor
                    }

                    DropShadow {
                        anchors.fill: appLaunchNormalText
                        source: appLaunchNormalText
                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 8
                        samples: 7

                        opacity:
                            appLaunchNormalButton.isPressed
                            ? 0.0
                            : appLaunchNormalButton.isSelected
                            ? 0.64
                            : appLaunchNormalButton.isHovered
                            ? 0.60
                            : 0.50

                        color: appLaunchNormalButton.subModeGlowColor
                        transparentBorder: true
                    }

                    MouseArea {
                        id: appLaunchNormalMouse
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            appControlWindow.setAppLaunchMode(
                                appControlWindow.appLaunchNormal
                            );
                        }
                    }
                
                    RectangularShadow {
                        anchors.fill: parent
                        spread: 4
                        z: -1

                        opacity:
                            appLaunchNormalButton.isHovered
                            || appLaunchNormalButton.isSelected
                            ? 0.52
                            : 0.34

                        color: appLaunchNormalButton.subModeGlowColor
                    }
}

                Rectangle {
                    id: appLaunchBottleButton

                    width: (parent.width - (parent.spacing * 2)) / 3
                    height: parent.height

                    opacity: 1.0

                    property bool isSelected:
                        appControlWindow.appLaunchMode
                        === appControlWindow.appLaunchBottle
                    property bool isHovered:
                        appLaunchBottleMouse.containsMouse
                    property bool isPressed:
                        appLaunchBottleMouse.pressed

                    readonly property color subModeGlowColor:
                        isSelected
                        ? Colors.magenta
                        : isHovered
                        ? Colors.orange
                        : Colors.magenta

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: appLaunchBottleButton.subModeGlowColor

                    Row {
                        id: appLaunchBottleContent
                        anchors.centerIn: parent
                        spacing: -2
                        opacity: 1.0

                        GohuText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "⚱"
                            font.pixelSize: 11
                            color:
                                appLaunchBottleButton.isPressed
                                ? Colors.black
                                : appLaunchBottleButton.subModeGlowColor
                        }

                        GohuText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "⚱"
                            font.pixelSize: 18
                            color:
                                appLaunchBottleButton.isPressed
                                ? Colors.black
                                : appLaunchBottleButton.subModeGlowColor
                        }

                        GohuText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "⚱"
                            font.pixelSize: 11
                            color:
                                appLaunchBottleButton.isPressed
                                ? Colors.black
                                : appLaunchBottleButton.subModeGlowColor
                        }
                    }

                    DropShadow {
                        anchors.fill: appLaunchBottleContent
                        source: appLaunchBottleContent
                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 8
                        samples: 7

                        opacity:
                            appLaunchBottleButton.isPressed
                            ? 0.0
                            : appLaunchBottleButton.isSelected
                            ? 0.64
                            : appLaunchBottleButton.isHovered
                            ? 0.60
                            : 0.50

                        color: appLaunchBottleButton.subModeGlowColor
                        transparentBorder: true
                    }

                    MouseArea {
                        id: appLaunchBottleMouse
                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            appControlWindow.setAppLaunchMode(
                                appControlWindow.appLaunchBottle
                            );

                            if (!appControlWindow.selectedBottleName)
                                appControlWindow.refreshBottleList();
                        }
                    }
                
                    RectangularShadow {
                        anchors.fill: parent
                        spread: 4
                        z: -1

                        opacity:
                            appLaunchBottleButton.isHovered
                            || appLaunchBottleButton.isSelected
                            ? 0.52
                            : 0.34

                        color: appLaunchBottleButton.subModeGlowColor
                    }
}


                Rectangle {
                    id: appLaunchToolboxButton

                    width: (parent.width - (parent.spacing * 2)) / 3
                    height: parent.height

                    opacity: 1.0

                    property bool isSelected:
                        appControlWindow.appLaunchMode
                        === appControlWindow.appLaunchToolbox
                    property bool isHovered:
                        appLaunchToolboxMouse.containsMouse
                    property bool isPressed:
                        appLaunchToolboxMouse.pressed

                    readonly property color subModeGlowColor:
                        isSelected
                        ? Colors.magenta
                        : isHovered
                        ? Colors.orange
                        : Colors.omnitrix

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: appLaunchToolboxButton.subModeGlowColor

                    Item {
                        id: appLaunchToolboxContent
                        width: 23
                        height: 23
                        anchors.centerIn: parent
                        opacity: 1.0

                        Rectangle {
                            anchors.fill: parent
                            color: Colors.black
                            border.width: 1
                            border.color:
                                appLaunchToolboxButton.subModeGlowColor

                            GohuText {
                                anchors.centerIn: parent
                                text: "🛠"
                                font.pixelSize: 14
                                color:
                                    appLaunchToolboxButton.isPressed
                                    ? Colors.black
                                    : appLaunchToolboxButton.subModeGlowColor
                            }
                        }
                    }

                    DropShadow {
                        anchors.fill: appLaunchToolboxContent
                        source: appLaunchToolboxContent
                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 8
                        samples: 7

                        opacity:
                            appLaunchToolboxButton.isPressed
                            ? 0.0
                            : appLaunchToolboxButton.isSelected
                            ? 0.64
                            : appLaunchToolboxButton.isHovered
                            ? 0.60
                            : 0.50

                        color: appLaunchToolboxButton.subModeGlowColor
                        transparentBorder: true
                    }

                    MouseArea {
                        id: appLaunchToolboxMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            appControlWindow.setAppLaunchMode(
                                appControlWindow.appLaunchToolbox
                            );
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        spread: 4
                        z: -1

                        opacity:
                            appLaunchToolboxButton.isHovered
                            || appLaunchToolboxButton.isSelected
                            ? 0.52
                            : 0.34

                        color: appLaunchToolboxButton.subModeGlowColor
                    }
                }
            }
        }

        // ========================================================
        // RUN PREFIX SELECTOR
        // ========================================================

        Rectangle {
            id: runPrefixSelector

            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            height: 48
            visible:
                appControlWindow.selectedModeIndex
                === appControlWindow.runModeIndex

            color: Colors.black
            z: 250

            Rectangle {
                id: runPrefixTopDivider

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top

                height: 1
                color: Colors.cyan

                RectangularShadow {
                    anchors.fill: parent

                    spread: 3
                    z: -1

                    opacity: 0.38
                    color: Colors.cyan
                }
            }

            Row {
                id: runPrefixButtons

                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: runPrefixTopDivider.bottom
                anchors.bottom: parent.bottom

                anchors.leftMargin: 7
                anchors.rightMargin: 7
                anchors.topMargin: 6
                anchors.bottomMargin: 6

                spacing: 7

                Rectangle {
                    id: runPrefixNormalButton

                    width: (parent.width - (parent.spacing * 2)) / 3
                    height: parent.height

                    opacity: 1.0

                    property bool isSelected:
                        appControlWindow.runPrefixMode
                        === appControlWindow.runPrefixNormal
                    property bool isHovered: runPrefixNormalMouse.containsMouse
                    property bool isPressed: runPrefixNormalMouse.pressed

                    readonly property color subModeGlowColor:
                        isSelected
                        ? Colors.magenta
                        : isHovered
                        ? Colors.orange
                        : Colors.cyan

                    color:
                        isPressed
                        ? Colors.magenta
                        : isHovered || isSelected
                        ? Colors.yellow
                        : Colors.dark

                    border.width: 1
                    border.color: runPrefixNormalButton.subModeGlowColor
                    GohuText {
                        id: runPrefixNormalIcon

                        anchors.centerIn: parent

                        text: appControlWindow.modes[
                                  appControlWindow.runModeIndex
                              ].symbol

                        font.pixelSize: 16

                        color:
                               runPrefixNormalButton.isPressed
                               ? Colors.black
                               : runPrefixNormalButton.subModeGlowColor
                    }

                    DropShadow {
                        anchors.fill: runPrefixNormalIcon
                        source: runPrefixNormalIcon

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 8
                        samples: 7

                        opacity: runPrefixNormalButton.isPressed
                                 ? 0.0
                                 : runPrefixNormalButton.isSelected
                                   || runPrefixNormalButton.isHovered
                                 ? 0.64
                                 : 0.50

                        color: runPrefixNormalButton.subModeGlowColor

                        transparentBorder: true
                    }

                    MouseArea {
                        id: runPrefixNormalMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.setRunPrefixMode(
                                appControlWindow.runPrefixNormal
                            );
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 4
                        z: -1

                        opacity: runPrefixNormalButton.isSelected
                                 || runPrefixNormalButton.isHovered
                                 ? 0.52
                                 : 0.34

                        color: runPrefixNormalButton.subModeGlowColor
                    }
                }

                Rectangle {
                    id: runPrefixKittyButton

                    width: (parent.width - (parent.spacing * 2)) / 3
                    height: parent.height

                    opacity: 1.0

                    property bool isSelected:
                        appControlWindow.runPrefixMode
                        === appControlWindow.runPrefixKitty
                    property bool isHovered: runPrefixKittyMouse.containsMouse
                    property bool isPressed: runPrefixKittyMouse.pressed

                    readonly property color subModeGlowColor:
                        isSelected
                        ? Colors.magenta
                        : isHovered
                        ? Colors.orange
                        : Colors.magenta

                    color:
                        isPressed
                        ? Colors.magenta
                        : isHovered || isSelected
                        ? Colors.yellow
                        : Colors.dark

                    border.width: 1
                    border.color: runPrefixKittyButton.subModeGlowColor
                    GohuText {
                        id: runPrefixKittyIcon

                        anchors.centerIn: parent

                        text:
                            runPrefixKittyButton.isHovered
                            || runPrefixKittyButton.isPressed
                            || appControlWindow.kittyFaceClickPulse
                            ? "≽(^≧⩊≦^)≼"
                            : appControlWindow.kittyFaceBlinking
                            ? "≽(^-⩊-^)≼"
                            : "≽(^•⩊•^)≼"

                        font.pixelSize: 16

                        color:
                               runPrefixKittyButton.isPressed
                               ? Colors.black
                               : runPrefixKittyButton.subModeGlowColor
                    }

                    DropShadow {
                        anchors.fill: runPrefixKittyIcon
                        source: runPrefixKittyIcon

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 8
                        samples: 7

                        opacity: runPrefixKittyButton.isPressed
                                 ? 0.0
                                 : runPrefixKittyButton.isSelected
                                   || runPrefixKittyButton.isHovered
                                 ? 0.64
                                 : 0.50

                        color: runPrefixKittyButton.subModeGlowColor

                        transparentBorder: true
                    }

                    MouseArea {
                        id: runPrefixKittyMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            appControlWindow.keyboardActive = false;

                            appControlWindow.kittyFaceClickPulse = true;
                            kittyFaceClickPulseTimer.restart();

                            appControlWindow.setRunPrefixMode(
                                appControlWindow.runPrefixKitty
                            );
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 4
                        z: -1

                        opacity: runPrefixKittyButton.isSelected
                                 || runPrefixKittyButton.isHovered
                                 ? 0.52
                                 : 0.34

                        color: runPrefixKittyButton.subModeGlowColor
                    }
                }

                Rectangle {
                    id: runPrefixToolboxButton

                    width: (parent.width - (parent.spacing * 2)) / 3
                    height: parent.height

                    opacity: 1.0

                    property bool isSelected:
                        appControlWindow.runPrefixMode
                        === appControlWindow.runPrefixToolbox
                    property bool isHovered:
                        runPrefixToolboxMouse.containsMouse
                    property bool isPressed:
                        runPrefixToolboxMouse.pressed

                    readonly property color subModeGlowColor:
                        isSelected
                        ? Colors.magenta
                        : isHovered
                        ? Colors.orange
                        : Colors.omnitrix

                    color:
                        isPressed
                        ? Colors.magenta
                        : isHovered || isSelected
                        ? Colors.yellow
                        : Colors.dark

                    border.width: 1
                    border.color: runPrefixToolboxButton.subModeGlowColor

                    Item {
                        id: runPrefixToolboxContent
                        width: 23
                        height: 23
                        anchors.centerIn: parent
                        opacity: 1.0

                        Rectangle {
                            anchors.fill: parent
                            color: Colors.black
                            border.width: 1
                            border.color:
                                runPrefixToolboxButton.subModeGlowColor

                            GohuText {
                                anchors.centerIn: parent
                                text: "🛠"
                                font.pixelSize: 14
                                color:
                                    runPrefixToolboxButton.isPressed
                                    ? Colors.black
                                    : runPrefixToolboxButton.subModeGlowColor
                            }
                        }
                    }

                    DropShadow {
                        anchors.fill: runPrefixToolboxContent
                        source: runPrefixToolboxContent
                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 8
                        samples: 7

                        opacity:
                            runPrefixToolboxButton.isPressed
                            ? 0.0
                            : runPrefixToolboxButton.isSelected
                            ? 0.64
                            : runPrefixToolboxButton.isHovered
                            ? 0.60
                            : 0.50

                        color: runPrefixToolboxButton.subModeGlowColor
                        transparentBorder: true
                    }

                    MouseArea {
                        id: runPrefixToolboxMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onClicked: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.setRunPrefixMode(
                                appControlWindow.runPrefixToolbox
                            );
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 4
                        z: -1

                        opacity: runPrefixToolboxButton.isSelected
                                 || runPrefixToolboxButton.isHovered
                                 ? 0.52
                                 : 0.34

                        color: runPrefixToolboxButton.subModeGlowColor
                    }
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

            anchors.topMargin:
                appControlWindow.selectedModeIndex
                === appControlWindow.favoritesModeIndex
                ? favoritesModeSelector.height
                : appControlWindow.selectedModeIndex
                  === appControlWindow.runModeIndex
                ? runListSelector.height
                : appControlWindow.selectedModeIndex
                  === appControlWindow.appsModeIndex
                ? appSourceSelector.height
                : appControlWindow.selectedModeIndex
                  === appControlWindow.windowsModeIndex
                ? windowListSelector.height
                : appControlWindow.selectedModeIndex
                  === appControlWindow.thermalModeIndex
                ? thermalViewSelector.height
                : appControlWindow.selectedModeIndex
                  === appControlWindow.killModeIndex
                ? killGlobalSelector.height
                : 0
            anchors.bottomMargin:
                appControlWindow.selectedModeIndex
                === appControlWindow.runModeIndex
                ? runPrefixSelector.height + 4
                : appControlWindow.selectedModeIndex
                  === appControlWindow.appsModeIndex
                ? appLaunchSelector.height + 4
                : 4
            anchors.rightMargin: 3

            color:
                appControlWindow.selectedModeIndex
                === appControlWindow.thermalModeIndex
                ? Colors.orange
                : appControlWindow.selectedModeIndex
                  === appControlWindow.killModeIndex
                ? Colors.red
                : Colors.cyan

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

                color:
                    appControlWindow.selectedModeIndex
                    === appControlWindow.thermalModeIndex
                    ? Colors.yellow
                    : appControlWindow.selectedModeIndex
                      === appControlWindow.killModeIndex
                    ? Colors.magenta
                    : Colors.magenta

                RectangularShadow {
                    anchors.fill: parent

                    spread: 2
                    z: -1

                    opacity: 0.16
                    color: resultScrollHandle.color
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

        color: Qt.rgba(Colors.black.r, Colors.black.g, Colors.black.b, 0.95)

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

            RectangularShadow {
                anchors.fill: parent
                spread: 3
                z: -1
                opacity: 0.38
                color: Colors.cyan
            }
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

            Item {
                id: appControlHeader

                width: parent.width
                height: 28

                // The title is centered on the pane itself. Each icon gets
                // exactly one half of the remaining space between the title
                // and its corresponding side, so the header stays balanced
                // even when APPLICATION CONTROL / COMMAND CONTROL differ in
                // width.
                Item {
                    id: applicationControlTitleBox

                    width: applicationControlTitle.implicitWidth
                    height: applicationControlTitle.implicitHeight

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter

                    GohuText {
                        id: applicationControlTitle

                        anchors.centerIn: parent

                        text:
                            appControlWindow.selectedControlModeIndex()
                            === appControlWindow.runModeIndex
                            ? "COMMAND CONTROL"
                            : appControlWindow.selectedControlModeIndex()
                              === appControlWindow.windowsModeIndex
                            ? (appControlWindow.selectedResultIsTab()
                               ? "TAB CONTROL"
                               : "WINDOW CONTROL")
                            : appControlWindow.selectedControlModeIndex()
                              === appControlWindow.thermalModeIndex
                            ? "THERMAL MONITOR"
                            : appControlWindow.selectedControlModeIndex()
                              === appControlWindow.killModeIndex
                            ? "TASK MANAGER"
                            : appControlWindow.selectedControlModeIndex()
                              === appControlWindow.systemModeIndex
                            ? "SYSTEM MONITOR"
                            : "APPLICATION CONTROL"

                        font.pixelSize: 20
                        color:
                            appControlWindow.selectedControlModeIndex()
                            === appControlWindow.windowsModeIndex
                            ? Colors.white
                            : appControlWindow.selectedControlModeIndex()
                              === appControlWindow.thermalModeIndex
                            ? Colors.orange
                            : appControlWindow.selectedControlModeIndex()
                              === appControlWindow.killModeIndex
                            ? Colors.red
                            : Colors.cyan
                    }

                    DropShadow {
                        anchors.fill: applicationControlTitle
                        source: applicationControlTitle

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 8
                        samples: 7

                        z: 2

                        opacity:
                            appControlWindow.selectedControlModeIndex()
                            === appControlWindow.killModeIndex
                            ? 0.58
                            : 0.58
                        color:
                            appControlWindow.selectedControlModeIndex()
                            === appControlWindow.thermalModeIndex
                            ? Colors.orange
                            : appControlWindow.selectedControlModeIndex()
                              === appControlWindow.killModeIndex
                            ? Colors.red
                            : Colors.cyan

                        transparentBorder: true
                    }
                }

                Item {
                    id: controlModeIconLeftRegion

                    anchors.left: parent.left
                    anchors.right: applicationControlTitleBox.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    Item {
                        width: controlModeIcon.implicitWidth
                        height: controlModeIcon.implicitHeight

                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: -14

                        GohuText {
                            id: controlModeIcon

                            anchors.centerIn: parent

                            text: appControlWindow.modes[
                                      appControlWindow.selectedControlModeIndex()
                                  ].symbol

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
                }

                Item {
                    id: controlModeIconRightRegion

                    anchors.left: applicationControlTitleBox.right
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom

                    Item {
                        id: controlModeIconRightBox

                        width: controlModeIconRight.implicitWidth
                        height: controlModeIconRight.implicitHeight

                        anchors.centerIn: parent
                        anchors.horizontalCenterOffset: 14

                        // Mirror the right-side symbol so directional glyphs
                        // face inward toward the centered header title.
                        transform: Scale {
                            origin.x: controlModeIconRightBox.width / 2
                            origin.y: controlModeIconRightBox.height / 2
                            xScale: -1
                            yScale: 1
                        }

                        GohuText {
                            id: controlModeIconRight

                            anchors.centerIn: parent

                            text: appControlWindow.modes[
                                      appControlWindow.selectedControlModeIndex()
                                  ].symbol

                            font.pixelSize: 20
                            color: Colors.magenta
                        }

                        DropShadow {
                            anchors.fill: controlModeIconRight
                            source: controlModeIconRight

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
                }
            }

            Rectangle {
                id: detailHeaderDivider

                width: parent.width + 40
                height: 2

                x: -20
                z: 20

                color: Colors.cyan

                RectangularShadow {
                    anchors.fill: parent
                    spread: 3
                    z: -1
                    opacity: 0.38
                    color: Colors.cyan
                }
            }

            Item {
                id: selectedAppInfoBand

                // Keep the content geometry unchanged, but trim the lower
                // breathing room so the state divider/header sits closer to
                // the identity block in both APPS and RUN.
                width: parent.width + 50
                x: -25

                height:
                    selectedAppIdentity.showingWindow
                    || selectedAppIdentity.showingTab
                    ? selectedAppInfoContent.implicitHeight
                    : selectedAppInfoContent.implicitHeight + 12
                clip: false

                Item {
                    id: selectedAppInfoBackground

                    x: 0
                    y: -18

                    width: parent.width

                    // Stop exactly at the fixed divider for the current
                    // control mode. APPS uses RUNNING STATE; RUN uses the
                    // matching divider slot added below.
                    height: Math.max(
                        parent.height,
                        (((appControlWindow.selectedResultIsWindow()
                            || appControlWindow.selectedResultIsTab())
                          ? windowControlDividerSection.y
                            + windowControlDivider.y
                          : appControlWindow.selectedResultIsRun()
                          ? runControlDividerSection.y
                            + runControlDivider.y
                          : runningStateSection.y
                            + runningStateDivider.y)
                         - selectedAppInfoBand.y)
                        - y
                    )

                    clip: true
                    z: -1

                    // Slightly inset + blurred so the dark band's edges
                    // feather inward instead of ending as a hard rectangle.
                    Rectangle {
                        id: selectedAppInfoBackgroundFill

                        anchors.fill: parent
                        anchors.margins: 2

                        color: Qt.rgba(
                            Colors.dark.r,
                            Colors.dark.g,
                            Colors.dark.b,
                            0.80
                        )

                        layer.enabled: true
                        layer.effect: GaussianBlur {
                            radius: 8
                            samples: 9
                            transparentBorder: true
                        }
                    }
                }

                Column {
                    id: selectedAppInfoContent

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top

                    anchors.leftMargin: 25
                    anchors.rightMargin: 25
                    anchors.topMargin:
                        selectedAppIdentity.showingWindow ? 1 : 8

                    spacing:
                        selectedAppIdentity.showingWindow
                        || selectedAppIdentity.showingTab
                        ? 7
                        : 18

                            Row {
                                id: selectedAppIdentity

                                width: parent.width
                                spacing: 14

                                property var selectedRecord:
                                    appControlWindow.selectedResult()
                                property var currentResult:
                                    appControlWindow.favoriteSourceItem(
                                        selectedRecord
                                    )
                                    || selectedRecord
                                property bool showingApp:
                                    appControlWindow.selectedResultIsApplication()
                                    && currentResult
                                property bool showingRun:
                                    appControlWindow.selectedResultIsRun()
                                    && currentResult
                                property bool showingWindow:
                                    appControlWindow.selectedResultIsWindow()
                                    && currentResult
                                property bool showingTab:
                                    appControlWindow.selectedResultIsTab()
                                    && currentResult
                                property bool showingTask:
                                    appControlWindow.selectedResultIsTask()
                                    && currentResult
                                property bool showingThermal:
                                    appControlWindow.selectedResultIsThermal()
                                    && currentResult
                                property bool showingSystem:
                                    appControlWindow.selectedResultIsSystemComponent()
                                    && currentResult

                                Item {
                                    id: selectedAppIconBox

                                    width: 52
                                    height: 52

                                    readonly property color sampledGlowColor: {
                                        const cached = appControlWindow.cachedIconGlow(
                                            selectedAppIcon.source
                                        );
                                        return cached !== null ? cached : Colors.cyan;
                                    }
                                    property var iconGrabResult: null
                                    property string samplingSource: ""
                                    property string authoritativeSource: ""

                                    readonly property bool hiddenFallbackActive:
                                        selectedAppIdentity.showingApp
                                        && selectedAppIdentity.currentResult
                                        && selectedAppIdentity.currentResult._hiddenCommand
                                           === true
                                        && selectedAppIcon.source.toString().length
                                           === 0

                                    visible:
                                        ((selectedAppIdentity.showingApp
                                          || selectedAppIdentity.showingWindow)
                                         && (selectedAppIcon.source.toString().length > 0
                                             || selectedAppIconBox.hiddenFallbackActive))
                                        || selectedAppIdentity.showingTask
                                        || selectedAppIdentity.showingThermal
                                        || selectedAppIdentity.showingSystem

                                    function sampleRenderedIcon() {
                                        const sourceKey = selectedAppIcon.source.toString();

                                        if (!sourceKey || selectedAppIcon.status !== Image.Ready)
                                            return;

                                        if (authoritativeSource === sourceKey
                                                || samplingSource === sourceKey)
                                            return;

                                        samplingSource = sourceKey;

                                        Qt.callLater(function() {
                                            if (selectedAppIcon.source.toString() !== sourceKey
                                                    || selectedAppIcon.status !== Image.Ready) {
                                                selectedAppIconBox.samplingSource = "";
                                                return;
                                            }

                                            const started =
                                                selectedAppIcon.grabToImage(
                                                    function(result) {
                                                        if (selectedAppIcon.source.toString()
                                                                !== sourceKey) {
                                                            selectedAppIconBox.samplingSource = "";
                                                            return;
                                                        }

                                                        selectedAppIconBox.iconGrabResult =
                                                            result;

                                                        selectedIconColorSampler.originalSource =
                                                            sourceKey;
                                                        selectedIconColorSampler.sampleSource =
                                                            result.url.toString();
                                                        selectedIconColorSampler.prepareSample();
                                                    },
                                                    Qt.size(18, 18)
                                                );

                                            if (!started)
                                                selectedAppIconBox.samplingSource = "";
                                        });
                                    }

                                    onVisibleChanged: {
                                        if (visible)
                                            sampleRenderedIcon();
                                    }

                                    Component.onCompleted: {
                                        if (visible) {
                                            Qt.callLater(function() {
                                                selectedAppIconBox.sampleRenderedIcon();
                                            });
                                        }
                                    }

                                    Image {
                                        id: selectedAppIcon

                                        anchors.fill: parent
                                        z: 20
                                        visible: source.toString().length > 0

                                        source:
                                            selectedAppIdentity.showingApp
                                            ? appControlWindow.appIconSource(
                                                  selectedAppIdentity.currentResult
                                              )
                                            : selectedAppIdentity.showingWindow
                                            ? appControlWindow.windowIconSource(
                                                  selectedAppIdentity.currentResult
                                              )
                                            : ""

                                        sourceSize.width: 52
                                        sourceSize.height: 52
                                        asynchronous: false
                                        cache: true
                                        fillMode: Image.PreserveAspectFit
                                        smooth: false

                                        onSourceChanged: {
                                            selectedAppIconBox.iconGrabResult = null;
                                            selectedAppIconBox.samplingSource = "";
                                            selectedAppIconBox.authoritativeSource = "";

                                            if (status === Image.Ready)
                                                selectedAppIconBox.sampleRenderedIcon();
                                        }

                                        onStatusChanged: {
                                            if (status === Image.Ready)
                                                selectedAppIconBox.sampleRenderedIcon();
                                        }
                                    }

                                    GohuText {
                                        anchors.centerIn: parent
                                        z: 1

                                        visible:
                                            selectedAppIconBox.hiddenFallbackActive

                                        text:
                                            appControlWindow.hiddenFaceBlinking
                                            ? "|ω･`ς)"
                                            : "|ω-ς)"

                                        font.pixelSize: 18
                                        color: Colors.yellow

                                        layer.enabled: true
                                        layer.effect: DropShadow {
                                            radius: 8
                                            samples: 7
                                            opacity: 0.52
                                            color: Colors.yellow
                                            transparentBorder: true
                                        }
                                    }

                                    
                                    Rectangle {
                                        anchors.centerIn: parent
                                        width: 42
                                        height: 42

                                        visible:
                                            selectedAppIdentity.showingThermal
                                            && selectedAppIdentity.currentResult
                                            && selectedAppIdentity.currentResult.sensorKind
                                               === "fan"

                                        color: Colors.black
                                        border.width: 1
                                        border.color: Colors.omnitrix

                                        GohuText {
                                            anchors.centerIn: parent
                                            text: "✇"
                                            font.pixelSize: 28
                                            color: Colors.omnitrix

                                            layer.enabled: true
                                            layer.effect: DropShadow {
                                                horizontalOffset: 0
                                                verticalOffset: 0
                                                radius: 7
                                                samples: 5
                                                opacity: 0.50
                                                color: Colors.omnitrix
                                                transparentBorder: true
                                            }
                                        }
                                    }

                                    GohuText {
                                        anchors.centerIn: parent

                                        visible:
                                            selectedAppIdentity.showingTask
                                            || (selectedAppIdentity.showingThermal
                                                && selectedAppIdentity.currentResult
                                                && selectedAppIdentity.currentResult.sensorKind
                                                   !== "fan")
                                            || selectedAppIdentity.showingSystem

                                        text:
                                            selectedAppIdentity.currentResult
                                            ? appControlWindow.monitorResultIcon(
                                                  selectedAppIdentity.currentResult
                                              )
                                            : ""

                                        font.pixelSize:
                                            selectedAppIdentity.showingTask
                                            ? 15
                                            : 31

                                        color:
                                            selectedAppIdentity.showingTask
                                            ? Colors.red
                                            : selectedAppIdentity.showingThermal
                                            ? appControlWindow.thermalAccent(
                                                  selectedAppIdentity.currentResult
                                              )
                                            : appControlWindow.systemAccent(
                                                  selectedAppIdentity.currentResult
                                              )

                                        layer.enabled: true
                                        layer.effect: DropShadow {
                                            horizontalOffset: 0
                                            verticalOffset: 0
                                            radius: 8
                                            samples: 5
                                            opacity: 0.52
                                            color:
                                                selectedAppIdentity.showingTask
                                                ? Colors.red
                                                : selectedAppIdentity.showingThermal
                                                ? appControlWindow.thermalAccent(
                                                      selectedAppIdentity.currentResult
                                                  )
                                                : appControlWindow.systemAccent(
                                                      selectedAppIdentity.currentResult
                                                  )
                                            transparentBorder: true
                                        }
                                    }

                                    Canvas {
                                        id: selectedIconColorSampler

                                        width: 18
                                        height: 18

                                        opacity: 0.001
                                        z: -100

                                        property string sampleSource: ""
                                        property string originalSource: ""

                                        function prepareSample() {
                                            if (!sampleSource)
                                                return;

                                            loadImage(
                                                sampleSource,
                                                Qt.size(width, height)
                                            );

                                            if (isImageLoaded(sampleSource))
                                                requestPaint();
                                        }

                                        onImageLoaded: requestPaint()

                                        onPaint: {
                                            if (!sampleSource
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

                                            const glow =
                                                appControlWindow.classifyIconGlow(pixels);

                                            selectedAppIconBox.authoritativeSource =
                                                originalSource;

                                            appControlWindow.rememberIconGlow(
                                                originalSource,
                                                glow,
                                                true
                                            );

                                            const finishedSource = sampleSource;

                                            Qt.callLater(function() {
                                                selectedIconColorSampler.unloadImage(
                                                    finishedSource
                                                );
                                                selectedIconColorSampler.sampleSource = "";
                                                selectedAppIconBox.iconGrabResult = null;
                                                selectedAppIconBox.samplingSource = "";
                                            });
                                        }
                                    }

                                    DropShadow {
                                        anchors.fill: selectedAppIcon
                                        source: selectedAppIcon

                                        horizontalOffset: 0
                                        verticalOffset: 0

                                        radius: 12
                                        samples: 5

                                        opacity: selectedAppIcon.status === Image.Ready
                                                 ? 0.50
                                                 : 0.0

                                        color: selectedAppIconBox.sampledGlowColor === Colors.white
                                               ? Colors.cyan
                                               : selectedAppIconBox.sampledGlowColor

                                        transparentBorder: true
                                    }
                                }

                                Column {
                                    width:
                                        parent.width
                                        - (selectedAppIconBox.visible
                                           ? 66
                                           : 0)
                                    spacing:
                                        selectedAppIdentity.showingWindow ? 3 : 5

                                    Item {
                                        width: parent.width
                                        height: selectedAppName.implicitHeight

                                        GohuText {
                                            id: selectedAppName

                                            width: parent.width

                                            text: selectedAppIdentity.showingApp
                                                  ? appControlWindow.appDisplayName(selectedAppIdentity.currentResult)
                                                  : selectedAppIdentity.showingRun
                                                  ? appControlWindow.runCommandText(
                                                        selectedAppIdentity.currentResult
                                                    )
                                                  : selectedAppIdentity.showingWindow
                                                  ? appControlWindow.windowDisplayAppName(
                                                        selectedAppIdentity.currentResult
                                                    )
                                                  : selectedAppIdentity.showingTask
                                                  ? String(
                                                        selectedAppIdentity.currentResult.comm
                                                        || "PROCESS"
                                                    )
                                                  : selectedAppIdentity.showingThermal
                                                  ? String(
                                                        selectedAppIdentity.currentResult.name
                                                        || "THERMAL SENSOR"
                                                    )
                                                  : selectedAppIdentity.showingSystem
                                                  ? String(
                                                        selectedAppIdentity.currentResult.name
                                                        || "SYSTEM COMPONENT"
                                                    )
                                                  : (selectedAppIdentity.currentResult
                                                     ? appControlWindow.resultDisplayName(
                                                           selectedAppIdentity.currentResult,
                                                           appControlWindow.selectedModeIndex
                                                       )
                                                     : "NO SELECTION")

                                            // Keep the App Control panel width
                                            // fixed and scale only long names.
                                            // Normal names remain 22px.
                                            font.pixelSize:
                                                selectedAppIdentity.showingWindow
                                                || selectedAppIdentity.showingTab
                                                ? 18
                                                : 22
                                            fontSizeMode: Text.HorizontalFit
                                            minimumPixelSize:
                                                selectedAppIdentity.showingWindow
                                                || selectedAppIdentity.showingTab
                                                ? 11
                                                : 13

                                            color: Colors.orange

                                            // Safety fallback if a name is
                                            // extreme even at 13px.
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
                                              ? appControlWindow.appDisplayDescription(
                                                    selectedAppIdentity.currentResult
                                                )
                                              : selectedAppIdentity.showingRun
                                              ? "RUN COMMAND • "
                                                + appControlWindow.runPrefixName(
                                                      appControlWindow.runPrefixModeForEntry(
                                                          appControlWindow.favoriteSourceItem(
                                                              selectedAppIdentity.currentResult
                                                          )
                                                      )
                                                  )
                                                + " • "
                                                + appControlWindow.runShellName().toUpperCase()
                                              : selectedAppIdentity.showingWindow
                                              ? appControlWindow.windowDisplaySubName(
                                                    selectedAppIdentity.currentResult
                                                )
                                              : selectedAppIdentity.showingTab
                                              ? String(
                                                    selectedAppIdentity.currentResult.appName
                                                    || "APPLICATION"
                                                )
                                                + " • "
                                                + String(
                                                      selectedAppIdentity.currentResult.provider
                                                      || "AT-SPI"
                                                  )
                                              : selectedAppIdentity.showingTask
                                              ? "PID "
                                                + String(
                                                      selectedAppIdentity.currentResult.pid
                                                      || "?"
                                                  )
                                                + " • "
                                                + String(
                                                      selectedAppIdentity.currentResult.user
                                                      || "?"
                                                  )
                                                + " • "
                                                + String(
                                                      selectedAppIdentity.currentResult.state
                                                      || "?"
                                                  )
                                              : selectedAppIdentity.showingThermal
                                              ? selectedAppIdentity.currentResult.sensorKind
                                                === "fan"
                                                ? Number(
                                                      selectedAppIdentity.currentResult.rpm
                                                      || 0
                                                  ).toFixed(0)
                                                  + " RPM • "
                                                  + String(
                                                        selectedAppIdentity.currentResult.chip
                                                        || "FAN"
                                                    )
                                                : appControlWindow.formatThermalMenuTemp(
                                                      selectedAppIdentity.currentResult.tempC
                                                  )
                                                  + " • "
                                                  + String(
                                                        selectedAppIdentity.currentResult.chip
                                                        || "SENSOR"
                                                    )
                                              : selectedAppIdentity.showingSystem
                                              ? String(
                                                    selectedAppIdentity.currentResult.category
                                                    || "SYSTEM"
                                                )
                                                + " • "
                                                + String(
                                                      selectedAppIdentity.currentResult.metric
                                                      || ""
                                                  )
                                              : "Phase 1 placeholder"

                                        font.pixelSize:
                                            selectedAppIdentity.showingWindow
                                            || selectedAppIdentity.showingTab
                                            ? 13
                                            : 15

                                        color:
                                            selectedAppIdentity.showingWindow
                                            || selectedAppIdentity.showingTab
                                            ? Colors.cyan
                                            : Colors.white
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

                                    GohuText {
                                        id: selectedWindowLocationInfo

                                        visible:
                                            selectedAppIdentity.showingWindow

                                        width: parent.width

                                        text:
                                            selectedAppIdentity.showingWindow
                                            ? "WINDOW • "
                                              + String(
                                                    selectedAppIdentity.currentResult.output
                                                    || "SCREEN ?"
                                                )
                                              + " • WORKSPACE "
                                              + String(
                                                    selectedAppIdentity.currentResult.workspace
                                                    || "?"
                                                )
                                            : ""

                                        font.pixelSize: 11
                                        color: Colors.white
                                        opacity: 0.92

                                        elide: Text.ElideRight

                                        layer.enabled: visible
                                        layer.effect: DropShadow {
                                            horizontalOffset: 0
                                            verticalOffset: 0

                                            radius: 5
                                            samples: 5

                                            opacity: 0.22
                                            color: Colors.cyan

                                            transparentBorder: true
                                        }
                                    }
                                }
                            }

                            GohuText {
                                property var currentResult: appControlWindow.selectedResult()

                                width: parent.width

                                text: appControlWindow.selectedResultIsApplication()
                                      && currentResult
                                      ? appControlWindow.appLongDescription(currentResult)
                                      : appControlWindow.selectedResultIsRun()
                                        && currentResult
                                      ? "EXECUTES : "
                                        + appControlWindow.runEffectiveCommand(
                                              appControlWindow.runCommandText(
                                                  appControlWindow.favoriteSourceItem(
                                                      currentResult
                                                  )
                                              ),
                                              appControlWindow.runPrefixModeForEntry(
                                                  appControlWindow.favoriteSourceItem(
                                                      currentResult
                                                  )
                                              )
                                          )
                                      : appControlWindow.selectedResultIsWindow()
                                        && currentResult
                                      ? "APP_ID : "
                                        + String(currentResult.appId || "—")
                                        + "   CLASS : "
                                        + String(currentResult.className || "—")
                                        + "   PID : "
                                        + String(currentResult.pid || "—")
                                        + "   STATE : "
                                        + (currentResult.fullscreen
                                           ? "FULLSCREEN"
                                           : currentResult.floating
                                           ? "FLOATING"
                                           : "TILED")
                                      : ""

                                visible: text.length > 0

                                wrapMode: Text.Wrap

                                font.pixelSize:
                                    appControlWindow.selectedResultIsWindow()
                                    ? 10
                                    : 14

                                color: Colors.white

                                opacity: 0.5
                            }
                }
            }

            Column {
                id: runningStateSection

                width: parent.width
                spacing: 3

                visible:
                    (appControlWindow.selectedResultIsApplication()
                     || appControlWindow.selectedResultIsTask()
                     || appControlWindow.selectedResultIsThermal()
                     || appControlWindow.selectedResultIsSystemComponent())
                    && appControlWindow.selectedResult() !== null

                                Item {
                    id: runningStateHeaderGlowBox

                    width: runningStateHeaderText.implicitWidth + 32
                    height: runningStateHeaderText.implicitHeight + 16

                    GohuText {
                        id: runningStateHeaderText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 16

                        text: appControlWindow.selectedResultIsTask()
                            ? "PROCESS STATE"
                            : appControlWindow.selectedResultIsThermal()
                            ? "THERMAL STATE"
                            : appControlWindow.selectedResultIsSystemComponent()
                            ? "SYSTEM STATE"
                            : "RUNNING STATE"
                        font.pixelSize: 13
                        color: appControlWindow.selectedResultIsTask()
                            ? Colors.red
                            : appControlWindow.selectedResultIsThermal()
                            ? Colors.orange
                            : Colors.cyan
                    }

                    DropShadow {
                        anchors.fill: runningStateHeaderText
                        source: runningStateHeaderText

                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 5
                        samples: 5
                        opacity: 0.34
                        color:
                            runningStateHeaderText.color === Colors.white
                            ? Colors.cyan
                            : runningStateHeaderText.color
                        transparentBorder: true
                    }
                }

                Rectangle {
                    id: runningStateDivider

                    width: parent.width + 20
                    height: 1

                    x: -10
                    z: 20

                    color:
                        appControlWindow.selectedResultIsTask()
                        ? Colors.red
                        : appControlWindow.selectedResultIsThermal()
                        ? Colors.orange
                        : Colors.cyan

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 2
                        z: -1

                        opacity: 0.28
                        color: runningStateDivider.color
                    }
                }
            }

            Column {
                id: runControlDividerSection

                width: parent.width
                spacing: 3

                visible: appControlWindow.selectedResultIsRun()
                         && appControlWindow.selectedResult() !== null

                                Item {
                    id: commandStateHeaderGlowBox

                    width: commandStateHeaderText.implicitWidth + 32
                    height: commandStateHeaderText.implicitHeight + 16

                    GohuText {
                        id: commandStateHeaderText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 16

                        text: "COMMAND STATE"
                        font.pixelSize: 13
                        color: Colors.cyan
                    }

                    DropShadow {
                        anchors.fill: commandStateHeaderText
                        source: commandStateHeaderText

                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 5
                        samples: 5
                        opacity: 0.34
                        color:
                            commandStateHeaderText.color === Colors.white
                            ? Colors.cyan
                            : commandStateHeaderText.color
                        transparentBorder: true
                    }
                }

                Rectangle {
                    id: runControlDivider

                    width: parent.width + 20
                    height: 1

                    x: -10
                    z: 20

                    color: Colors.cyan

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 2
                        z: -1

                        opacity: 0.28
                        color: Colors.cyan
                    }
                }
            }

            Column {
                id: windowControlDividerSection

                width: parent.width
                spacing: 1

                visible: (appControlWindow.selectedResultIsWindow()
                          || appControlWindow.selectedResultIsTab())
                         && appControlWindow.selectedResult() !== null

                                Item {
                    id: windowStateHeaderGlowBox

                    width: windowStateHeaderText.implicitWidth + 32
                    height: windowStateHeaderText.implicitHeight + 16

                    GohuText {
                        id: windowStateHeaderText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 16

                        text: appControlWindow.selectedResultIsTab()
                              ? "APP CONTROLS"
                              : "WINDOW STATE"
                        font.pixelSize: 13
                        color: Colors.white
                    }

                    DropShadow {
                        anchors.fill: windowStateHeaderText
                        source: windowStateHeaderText

                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 5
                        samples: 5
                        opacity: 0.34
                        color:
                            windowStateHeaderText.color === Colors.white
                            ? Colors.cyan
                            : windowStateHeaderText.color
                        transparentBorder: true
                    }
                }

                Rectangle {
                    id: windowControlDivider

                    width: parent.width + 20
                    height: 1

                    x: -10
                    z: 20

                    color: Colors.cyan

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 2
                        z: -1

                        opacity: 0.28
                        color: Colors.cyan
                    }
                }
            }
        }

        // Only content BELOW the APPS/RUN/WINDOWS static divider scrolls.
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

                    visible: appControlWindow.selectedResultIsApplication()
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
                            color: Colors.white

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
                            color: Colors.orange
                            opacity: 1.0

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
                id: thermalMonitorBody

                width: parent.width
                spacing: 12

                visible:
                    appControlWindow.selectedResultIsThermal()
                    && appControlWindow.selectedResult() !== null

                property var selectedRecord:
                    appControlWindow.selectedResult()
                property var currentSensor:
                    appControlWindow.favoriteSourceItem(selectedRecord)
                    || selectedRecord

                GridLayout {
                    width: parent.width
                    columns: 3
                    columnSpacing: 2
                    rowSpacing: 0
                    clip: false

                    Repeater {
                        model: {
                            const sensor = thermalMonitorBody.currentSensor;

                            if (!sensor)
                                return [];

                            if (sensor.sensorKind === "fan") {
                                return [
                                    {
                                        id: "rpm",
                                        label: "RPM",
                                        value: Number(sensor.rpm || 0).toFixed(0),
                                        accent: Colors.omnitrix
                                    },
                                    {
                                        id: "min",
                                        label: "MIN",
                                        value:
                                            Number(sensor.minRpm || 0) > 0
                                            ? Number(sensor.minRpm).toFixed(0)
                                              + " RPM"
                                            : "N/A",
                                        accent: Colors.cyan
                                    },
                                    {
                                        id: "max",
                                        label: "MAX",
                                        value:
                                            Number(sensor.maxRpm || 0) > 0
                                            ? Number(sensor.maxRpm).toFixed(0)
                                              + " RPM"
                                            : "N/A",
                                        accent:
                                        appControlWindow.thermalColorForCelsius(
                                            Number(sensor.highC || 0)
                                        )
                                    }
                                ];
                            }

                            return [
                                {
                                    id: "current",
                                    label: "CURRENT",
                                    tempC: Number(sensor.tempC || 0),
                                    value: "",
                                    accent:
                                        appControlWindow.thermalAccent(sensor)
                                },
                                {
                                    id: "high",
                                    label: "HIGH",
                                    tempC:
                                        Number(sensor.highC || 0) > 0
                                        ? Number(sensor.highC)
                                        : -1,
                                    value:
                                        Number(sensor.highC || 0) > 0
                                        ? ""
                                        : "N/A",
                                    accent: Colors.orange
                                },
                                {
                                    id: "critical",
                                    label: "CRITICAL",
                                    tempC:
                                        Number(sensor.critC || 0) > 0
                                        ? Number(sensor.critC)
                                        : -1,
                                    value:
                                        Number(sensor.critC || 0) > 0
                                        ? ""
                                        : "N/A",
                                    accent:
                                        appControlWindow.thermalColorForCelsius(
                                            Number(sensor.critC || 0)
                                        )
                                }
                            ];
                        }

                        Item {
                            required property var modelData

                            Layout.fillWidth: true
                            Layout.preferredHeight: 72
                            clip: false

                            Rectangle {
                                id: thermalMetricCard

                                anchors.fill: parent
                                anchors.margins: 6

                                color: Colors.black
                                border.width: 1
                                border.color: modelData.accent

                                RectangularShadow {
                                    anchors.fill: parent
                                    spread: 3
                                    z: -1
                                    opacity: 0.28
                                    color: modelData.accent
                                }

                                Column {
                                    anchors.fill: parent
                                    anchors.margins: 7
                                    spacing: 3

                                    GohuText {
                                        text: modelData.label
                                        font.pixelSize: 10
                                        color: modelData.accent

                                        layer.enabled: true
                                        layer.effect: DropShadow {
                                            horizontalOffset: 0
                                            verticalOffset: 0
                                            radius: 6
                                            samples: 5
                                            opacity: 0.46
                                            color: modelData.accent
                                            transparentBorder: true
                                        }
                                    }

                                    Item {
                                        width: parent.width - 18
                                        height: 23

                                        readonly property bool hasTemperature:
                                            modelData.tempC !== undefined
                                            && Number(modelData.tempC) >= 0

                                        GohuText {
                                            id: thermalMetricFahrenheit

                                            visible: parent.hasTemperature
                                            anchors.left: parent.left
                                            anchors.bottom: parent.bottom

                                            text:
                                                appControlWindow.celsiusToFahrenheit(
                                                    modelData.tempC
                                                ).toFixed(1)
                                                + "°F"

                                            font.pixelSize: 16
                                            color: modelData.accent

                                            layer.enabled: true
                                            layer.effect: DropShadow {
                                                radius: 7
                                                samples: 5
                                                opacity: 0.58
                                                color: modelData.accent
                                                transparentBorder: true
                                            }
                                        }

                                        GohuText {
                                            visible: parent.hasTemperature
                                            anchors.left:
                                                thermalMetricFahrenheit.right
                                            anchors.leftMargin: -4
                                            anchors.top:
                                                thermalMetricFahrenheit.top
                                            anchors.topMargin: -9

                                            text:
                                                Number(
                                                    modelData.tempC
                                                ).toFixed(1)
                                                + "°C"

                                            font.pixelSize: 11
                                            color: modelData.accent
                                            opacity: 0.82

                                            layer.enabled: true
                                            layer.effect: DropShadow {
                                                radius: 4
                                                samples: 5
                                                opacity: 0.34
                                                color: modelData.accent
                                                transparentBorder: true
                                            }
                                        }

                                        GohuText {
                                            visible: !parent.hasTemperature
                                            anchors.left: parent.left
                                            anchors.bottom: parent.bottom
                                            width: parent.width

                                            text: modelData.value
                                            font.pixelSize: 16
                                            color: modelData.accent
                                            elide: Text.ElideRight

                                            layer.enabled: true
                                            layer.effect: DropShadow {
                                                radius: 7
                                                samples: 5
                                                opacity: 0.58
                                                color: modelData.accent
                                                transparentBorder: true
                                            }
                                        }
                                    }
                                }

                                Item {
                                    anchors.right: parent.right
                                    anchors.top: parent.top
                                    anchors.rightMargin: 2
                                    anchors.topMargin: 2
                                    width: 20
                                    height: 20
                                    z: 20

                                    readonly property bool favorite:
                                        appControlWindow.isMonitorBoxFavorite(
                                            thermalMonitorBody.currentSensor,
                                            modelData.id
                                        )

                                    GohuText {
                                        anchors.centerIn: parent
                                        text: parent.favorite ? "✦" : "✧"
                                        font.pixelSize: 13
                                        color: modelData.accent

                                        layer.enabled: true
                                        layer.effect: DropShadow {
                                            radius: 5
                                            samples: 5
                                            opacity: 0.42
                                            color: modelData.accent
                                            transparentBorder: true
                                        }
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true

                                        onClicked: {
                                            appControlWindow.toggleMonitorBoxFavorite(
                                                thermalMonitorBody.currentSensor,
                                                modelData.id
                                            );
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: thermalLoadSlider
                    width: parent.width - 10
                    height: 32
                    anchors.horizontalCenter: parent.horizontalCenter

                    readonly property bool fanMode:
                        thermalMonitorBody.currentSensor
                        && thermalMonitorBody.currentSensor.sensorKind === "fan"
                    readonly property bool canAdjust:
                        fanMode && thermalMonitorBody.currentSensor.controlWritable
                    property real previewPercent: -1

                    function sensorPercent() {
                        if (!fanMode)
                            return Math.max(0, Math.min(100,
                                Number(thermalMonitorBody.currentSensor
                                       ? thermalMonitorBody.currentSensor.tempC : 0)));

                        const pwm = Number(thermalMonitorBody.currentSensor.pwmPercent || -1);
                        if (pwm >= 0)
                            return Math.max(0, Math.min(100, pwm));

                        return Math.max(0, Math.min(100,
                            (Number(thermalMonitorBody.currentSensor.rpm || 0)
                             / Math.max(1, Number(thermalMonitorBody.currentSensor.maxRpm || 5000)))
                            * 100));
                    }

                    function activePercent() {
                        return previewPercent >= 0 ? previewPercent : sensorPercent();
                    }

                    function percentAt(positionX) {
                        const usable = Math.max(1, width - 8);
                        return Math.max(0, Math.min(100, ((positionX - 4) / usable) * 100));
                    }

                    color: Colors.black
                    border.width: 1
                    border.color: appControlWindow.thermalAccent(thermalMonitorBody.currentSensor)

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 3
                        width: Math.max(0, (parent.width - 6) * thermalLoadSlider.activePercent() / 100.0)
                        color: appControlWindow.thermalAccent(thermalMonitorBody.currentSensor)
                        opacity: 0.50
                        layer.enabled: true
                        layer.effect: DropShadow {
                            radius: 6
                            samples: 5
                            opacity: 0.40
                            color: appControlWindow.thermalAccent(thermalMonitorBody.currentSensor)
                            transparentBorder: true
                        }
                    }

                    Rectangle {
                        id: fanSliderHandle
                        visible: thermalLoadSlider.fanMode
                        width: 24
                        height: parent.height - 4
                        y: 2
                        x: 2 + (parent.width - width - 4) * thermalLoadSlider.activePercent() / 100.0
                        color: Colors.white
                        border.width: 1
                        border.color: appControlWindow.thermalAccent(thermalMonitorBody.currentSensor)

                        GohuText {
                            anchors.centerIn: parent
                            text: "✇"
                            font.pixelSize: 14
                            color: Colors.black
                        }

                        RectangularShadow {
                            anchors.fill: parent
                            spread: 3
                            z: -1
                            opacity: 0.40
                            color: appControlWindow.thermalAccent(thermalMonitorBody.currentSensor)
                        }
                    }

                    GohuText {
                        anchors.centerIn: parent
                        text: thermalLoadSlider.fanMode
                              ? "FAN SPEED  " + thermalLoadSlider.activePercent().toFixed(0) + "%"
                              : "THERMAL LOAD"
                        font.pixelSize: 10
                        color: thermalLoadSlider.fanMode ? Colors.black : Colors.white
                        layer.enabled: !thermalLoadSlider.fanMode
                        layer.effect: DropShadow {
                            radius: 5
                            samples: 5
                            opacity: 0.34
                            color: appControlWindow.thermalAccent(thermalMonitorBody.currentSensor)
                            transparentBorder: true
                        }
                    }

                    MouseArea {
                        id: fanSliderMouse
                        anchors.fill: parent
                        enabled: thermalLoadSlider.canAdjust
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton

                        onPressed: function(mouse) {
                            thermalLoadSlider.previewPercent = thermalLoadSlider.percentAt(mouse.x);
                            mouse.accepted = true;
                        }
                        onPositionChanged: function(mouse) {
                            if (pressed)
                                thermalLoadSlider.previewPercent = thermalLoadSlider.percentAt(mouse.x);
                        }
                        onReleased: function(mouse) {
                            const target = thermalLoadSlider.percentAt(mouse.x);
                            thermalLoadSlider.previewPercent = target;
                            appControlWindow.writeFanPercent(thermalMonitorBody.currentSensor, target);
                            fanSliderPreviewReset.restart();
                            mouse.accepted = true;
                        }
                        onWheel: function(wheel) {
                            const delta = wheel.angleDelta.y !== 0
                                          ? wheel.angleDelta.y : wheel.pixelDelta.y;
                            if (delta === 0) return;
                            const target = Math.max(0, Math.min(100,
                                thermalLoadSlider.activePercent() + (delta > 0 ? 5 : -5)));
                            thermalLoadSlider.previewPercent = target;
                            appControlWindow.writeFanPercent(thermalMonitorBody.currentSensor, target);
                            fanSliderPreviewReset.restart();
                            wheel.accepted = true;
                        }
                    }

                    Timer {
                        id: fanSliderPreviewReset
                        interval: 900
                        repeat: false
                        onTriggered: thermalLoadSlider.previewPercent = -1
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        spread: 2
                        z: -1
                        opacity: 0.26
                        color: appControlWindow.thermalAccent(thermalMonitorBody.currentSensor)
                    }
                }

                Column {
                    visible:
                        thermalMonitorBody.currentSensor
                        && thermalMonitorBody.currentSensor.sensorKind
                           === "fan"

                    width: parent.width
                    spacing: 7

                    Item {
                        width: fanControlHeader.implicitWidth + 32
                        height: fanControlHeader.implicitHeight + 16

                        GohuText {
                            id: fanControlHeader
                            anchors.left: parent.left
                            anchors.leftMargin: 16
                            anchors.verticalCenter: parent.verticalCenter
                            text: "FAN CONTROL"
                            font.pixelSize: 13
                            color: Colors.omnitrix
                        }

                        DropShadow {
                            anchors.fill: fanControlHeader
                            source: fanControlHeader
                            radius: 5
                            samples: 5
                            opacity: 0.34
                            color: Colors.omnitrix
                            transparentBorder: true
                        }
                    }

                    GohuText {
                        width: parent.width
                        text:
                            thermalMonitorBody.currentSensor.controlWritable
                            ? "MODE "
                              + (Number(
                                     thermalMonitorBody.currentSensor.pwmEnable
                                     || -1
                                 ) === 1
                                 ? "MANUAL"
                                 : "AUTO")
                              + " • PWM "
                              + (Number(
                                     thermalMonitorBody.currentSensor.pwmPercent
                                     || -1
                                 ) >= 0
                                 ? Number(
                                       thermalMonitorBody.currentSensor.pwmPercent
                                   ).toFixed(0)
                                   + "%"
                                 : "N/A")
                            : "CONTROL LOCKED • HWMON PWM IS NOT WRITABLE BY THIS USER"

                        font.pixelSize: 10
                        color:
                            thermalMonitorBody.currentSensor.controlWritable
                            ? Colors.white
                            : Colors.red
                        wrapMode: Text.Wrap

                        layer.enabled:
                            !thermalMonitorBody.currentSensor.controlWritable
                        layer.effect: DropShadow {
                            radius: 5
                            samples: 5
                            opacity: 0.40
                            color: Colors.red
                            transparentBorder: true
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: [
                                { label: "AUTO", action: "auto", accent: Colors.cyan },
                                { label: "MANUAL BOOST", action: "manual", accent: Colors.orange },
                                { label: "+10%", action: "boost", accent: Colors.omnitrix },
                                { label: "MAX", action: "max", accent: Colors.red }
                            ]

                            Rectangle {
                                required property var modelData

                                width: (thermalMonitorBody.width - 18) / 4
                                height: 32

                                property bool canControl:
                                    thermalMonitorBody.currentSensor
                                    && thermalMonitorBody.currentSensor.controlWritable

                                color:
                                    fanControlMouse.pressed
                                    ? Colors.magenta
                                    : fanControlMouse.containsMouse
                                    ? Colors.yellow
                                    : Colors.black
                                opacity: canControl ? 1.0 : 0.38
                                border.width: 1
                                border.color: modelData.accent

                                RectangularShadow {
                                    anchors.fill: parent
                                    spread: 3
                                    z: -1
                                    opacity:
                                        fanControlMouse.containsMouse
                                        ? 0.52
                                        : 0.34
                                    color: modelData.accent
                                }

                                GohuText {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    font.pixelSize: 9
                                    color:
                                        fanControlMouse.pressed
                                        ? Colors.black
                                        : fanControlMouse.containsMouse
                                        ? Colors.orange
                                        : modelData.accent

                                    layer.enabled: !fanControlMouse.pressed
                                    layer.effect: DropShadow {
                                        radius: 5
                                        samples: 5
                                        opacity: 0.34
                                        color: modelData.accent
                                        transparentBorder: true
                                    }
                                }

                                MouseArea {
                                    id: fanControlMouse
                                    anchors.fill: parent
                                    enabled: parent.canControl
                                    hoverEnabled: true

                                    onClicked: {
                                        appControlWindow.writeFanControl(
                                            thermalMonitorBody.currentSensor,
                                            modelData.action
                                        );
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    width: thermalContributorHeader.implicitWidth + 32
                    height: thermalContributorHeader.implicitHeight + 16

                    GohuText {
                        id: thermalContributorHeader
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text:
                            thermalMonitorBody.currentSensor
                            && thermalMonitorBody.currentSensor.sensorKind
                               === "fan"
                            ? "EST. HEAT CONTRIBUTORS"
                            : "EST. THERMAL CONTRIBUTORS"
                        font.pixelSize: 13
                        color: Colors.orange
                    }

                    DropShadow {
                        anchors.fill: thermalContributorHeader
                        source: thermalContributorHeader
                        radius: 5
                        samples: 5
                        opacity: 0.34
                        color: Colors.orange
                        transparentBorder: true
                    }
                }

                GohuText {
                    width: parent.width
                    text:
                        thermalMonitorBody.currentSensor
                        ? String(
                              thermalMonitorBody.currentSensor.contributorNote
                              || ""
                          )
                        : ""
                    font.pixelSize: 9
                    color: Colors.white
                    opacity: 0.58
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model:
                        appControlWindow.contributorRows(
                            thermalMonitorBody.currentSensor
                        )

                    Rectangle {
                        required property var modelData

                        width: thermalMonitorBody.width - 8
                        height: 34
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Colors.black
                        border.width: 1
                        border.color: Colors.orange

                        RectangularShadow {
                            anchors.fill: parent
                            spread: 3
                            z: -1
                            opacity: 0.34
                            color: Colors.orange
                        }

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 7
                            anchors.rightMargin: 7
                            spacing: 7

                            GohuText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "⚙"
                                font.pixelSize: 12
                                color: Colors.orange

                                layer.enabled: true
                                layer.effect: DropShadow {
                                    radius: 4
                                    samples: 5
                                    opacity: 0.34
                                    color: Colors.orange
                                    transparentBorder: true
                                }
                            }

                            GohuText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * 0.52
                                text:
                                    String(modelData.name || "PROCESS")
                                    + "  ["
                                    + String(modelData.pid || "?")
                                    + "]"
                                font.pixelSize: 10
                                color: Colors.white
                                elide: Text.ElideRight
                            }

                            GohuText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * 0.34
                                text: String(modelData.valueText || "")
                                font.pixelSize: 10
                                color: Colors.orange
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight

                                layer.enabled: true
                                layer.effect: DropShadow {
                                    radius: 4
                                    samples: 5
                                    opacity: 0.32
                                    color: Colors.orange
                                    transparentBorder: true
                                }
                            }
                        }
                    }
                }

                GohuText {
                    width: parent.width
                    text:
                        thermalMonitorBody.currentSensor
                        ? String(thermalMonitorBody.currentSensor.role || "")
                        : ""
                    font.pixelSize: 12
                    color: Colors.orange
                    wrapMode: Text.Wrap

                    layer.enabled: true
                    layer.effect: DropShadow {
                        radius: 5
                        samples: 5
                        opacity: 0.34
                        color: Colors.orange
                        transparentBorder: true
                    }
                }

                GohuText {
                    width: parent.width
                    text:
                        thermalMonitorBody.currentSensor
                        ? "SOURCE : "
                          + String(thermalMonitorBody.currentSensor.source || "")
                        : ""
                    font.pixelSize: 10
                    color: Colors.white
                    opacity: 0.58
                    wrapMode: Text.Wrap
                }
            }

                        Column {
                id: systemMonitorBody

                width: parent.width
                spacing: 12

                visible:
                    appControlWindow.selectedResultIsSystemComponent()
                    && appControlWindow.selectedResult() !== null

                property var selectedRecord:
                    appControlWindow.selectedResult()
                property var currentComponent:
                    appControlWindow.favoriteSourceItem(selectedRecord)
                    || selectedRecord
                property color accent:
                    appControlWindow.systemAccent(currentComponent)

                Row {
                    width: parent.width
                    height: 78
                    spacing: 2
                    clip: false

                    Item {
                        width: (parent.width - parent.spacing) * 0.42
                        height: parent.height
                        clip: false

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 7
                            color: Colors.black
                            border.width: 1
                            border.color: systemMonitorBody.accent

                            RectangularShadow {
                                anchors.fill: parent
                                spread: 3
                                z: -1
                                opacity: 0.28
                                color: systemMonitorBody.accent
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                GohuText {
                                    text: "UTILIZATION"
                                    font.pixelSize: 10
                                    color: systemMonitorBody.accent

                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        radius: 6
                                        samples: 5
                                        opacity: 0.46
                                        color: systemMonitorBody.accent
                                        transparentBorder: true
                                    }
                                }

                                GohuText {
                                    text:
                                        systemMonitorBody.currentComponent
                                        && Number(
                                               systemMonitorBody.currentComponent.usage
                                           ) >= 0
                                        ? Number(
                                              systemMonitorBody.currentComponent.usage
                                          ).toFixed(1)
                                          + "%"
                                        : "LIVE I/O"
                                    font.pixelSize: 18
                                    color: systemMonitorBody.accent

                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        radius: 7
                                        samples: 5
                                        opacity: 0.58
                                        color: systemMonitorBody.accent
                                        transparentBorder: true
                                    }
                                }
                            }

                            Item {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                width: 20
                                height: 20
                                z: 20

                                readonly property bool favorite:
                                    appControlWindow.isMonitorBoxFavorite(
                                        systemMonitorBody.currentComponent,
                                        "utilization"
                                    )

                                GohuText {
                                    anchors.centerIn: parent
                                    text: parent.favorite ? "✦" : "✧"
                                    font.pixelSize: 13
                                    color: systemMonitorBody.accent

                                    layer.enabled: parent.favorite
                                    layer.effect: DropShadow {
                                        radius: 5
                                        samples: 5
                                        opacity: 0.42
                                        color: systemMonitorBody.accent
                                        transparentBorder: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        appControlWindow.toggleMonitorBoxFavorite(
                                            systemMonitorBody.currentComponent,
                                            "utilization"
                                        );
                                    }
                                }
                            }
                        }
                    }

                    Item {
                        width:
                            parent.width
                            - ((parent.width - parent.spacing) * 0.42)
                            - parent.spacing
                        height: parent.height
                        clip: false

                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: 7
                            color: Colors.black
                            border.width: 1
                            border.color: systemMonitorBody.accent

                            RectangularShadow {
                                anchors.fill: parent
                                spread: 3
                                z: -1
                                opacity: 0.28
                                color: systemMonitorBody.accent
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 8
                                spacing: 4

                                GohuText {
                                    text:
                                        systemMonitorBody.currentComponent
                                        ? String(
                                              systemMonitorBody.currentComponent.category
                                              || "SYSTEM"
                                          )
                                        : "SYSTEM"
                                    font.pixelSize: 10
                                    color: systemMonitorBody.accent

                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        radius: 6
                                        samples: 5
                                        opacity: 0.46
                                        color: systemMonitorBody.accent
                                        transparentBorder: true
                                    }
                                }

                                GohuText {
                                    width: parent.width - 16
                                    text:
                                        systemMonitorBody.currentComponent
                                        ? String(
                                              systemMonitorBody.currentComponent.metric
                                              || ""
                                          )
                                        : ""
                                    font.pixelSize: 14
                                    color: Colors.white
                                    elide: Text.ElideRight

                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        radius: 6
                                        samples: 5
                                        opacity: 0.48
                                        color: systemMonitorBody.accent
                                        transparentBorder: true
                                    }
                                }
                            }

                            Item {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                width: 20
                                height: 20
                                z: 20

                                readonly property bool favorite:
                                    appControlWindow.isMonitorBoxFavorite(
                                        systemMonitorBody.currentComponent,
                                        "metric"
                                    )

                                GohuText {
                                    anchors.centerIn: parent
                                    text: parent.favorite ? "✦" : "✧"
                                    font.pixelSize: 13
                                    color: systemMonitorBody.accent

                                    layer.enabled: parent.favorite
                                    layer.effect: DropShadow {
                                        radius: 5
                                        samples: 5
                                        opacity: 0.42
                                        color: systemMonitorBody.accent
                                        transparentBorder: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        appControlWindow.toggleMonitorBoxFavorite(
                                            systemMonitorBody.currentComponent,
                                            "metric"
                                        );
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    visible:
                        systemMonitorBody.currentComponent
                        && Number(
                               systemMonitorBody.currentComponent.usage
                           ) >= 0

                    width: parent.width - 10
                    height: 24
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Colors.black
                    border.width: 1
                    border.color: systemMonitorBody.accent

                    Rectangle {
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        anchors.margins: 3

                        width:
                            Math.max(
                                0,
                                (parent.width - 6)
                                * Math.min(
                                    1.0,
                                    Number(
                                        systemMonitorBody.currentComponent
                                        ? systemMonitorBody.currentComponent.usage
                                        : 0
                                    ) / 100.0
                                )
                            )

                        color: systemMonitorBody.accent
                        opacity: 0.58
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        spread: 2
                        z: -1
                        opacity: 0.26
                        color: systemMonitorBody.accent
                    }
                }

                Row {
                    width: parent.width
                    spacing: 7

                    GohuText {
                        text:
                            appControlWindow.systemIconFor(
                                systemMonitorBody.currentComponent
                            )
                        font.pixelSize: 17
                        color: systemMonitorBody.accent

                        layer.enabled: true
                        layer.effect: DropShadow {
                            radius: 6
                            samples: 5
                            opacity: 0.44
                            color: systemMonitorBody.accent
                            transparentBorder: true
                        }
                    }

                    GohuText {
                        width: parent.width - 26
                        text:
                            systemMonitorBody.currentComponent
                            ? String(systemMonitorBody.currentComponent.role || "")
                            : ""
                        font.pixelSize: 12
                        color: systemMonitorBody.accent
                        wrapMode: Text.Wrap

                        layer.enabled: true
                        layer.effect: DropShadow {
                            radius: 5
                            samples: 5
                            opacity: 0.36
                            color: systemMonitorBody.accent
                            transparentBorder: true
                        }
                    }
                }

                GohuText {
                    width: parent.width
                    text:
                        systemMonitorBody.currentComponent
                        ? String(
                              systemMonitorBody.currentComponent.secondary
                              || ""
                          )
                        : ""
                    font.pixelSize: 12
                    color: Colors.white
                    wrapMode: Text.Wrap
                }

                GohuText {
                    width: parent.width
                    text:
                        systemMonitorBody.currentComponent
                        ? String(
                              systemMonitorBody.currentComponent.detail
                              || ""
                          )
                        : ""
                    font.pixelSize: 10
                    color: Colors.white
                    opacity: 0.64
                    wrapMode: Text.Wrap
                }

                Item {
                    width:
                        systemControlHeader.implicitWidth
                        + systemControlWarning.implicitWidth
                        + 44
                    height: systemControlHeader.implicitHeight + 16

                    GohuText {
                        id: systemControlHeader
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter

                        text: "SYSTEM CONTROL"
                        font.pixelSize: 13
                        color: Colors.red

                        layer.enabled: true
                        layer.effect: DropShadow {
                            radius: 5
                            samples: 5
                            opacity: 0.34
                            color: Colors.red
                            transparentBorder: true
                        }
                    }

                    GohuText {
                        id: systemControlWarning
                        anchors.left: systemControlHeader.right
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter

                        text:
                            appControlWindow.systemComponentWarning(
                                systemMonitorBody.currentComponent
                            )

                        font.pixelSize: 9
                        color: Colors.yellow

                        layer.enabled: text.length > 0
                        layer.effect: DropShadow {
                            radius: 4
                            samples: 5
                            opacity: 0.32
                            color: Colors.yellow
                            transparentBorder: true
                        }
                    }
                }

                Row {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: [
                            {
                                label: "DISCONNECT",
                                action: "disconnect",
                                accent: Colors.red,
                                available:
                                    systemMonitorBody.currentComponent
                                    && systemMonitorBody.currentComponent.canDisconnect
                            },
                            {
                                label: "RECONNECT",
                                action: "reconnect",
                                accent: Colors.omnitrix,
                                available:
                                    systemMonitorBody.currentComponent
                                    && systemMonitorBody.currentComponent.canReconnect
                            },
                            {
                                label:
                                    appControlWindow.systemRebootArmed
                                    ? "CONFIRM REBOOT"
                                    : "REBOOT PC",
                                action: "reboot",
                                accent: Colors.orange,
                                available:
                                    systemMonitorBody.currentComponent
                                    && systemMonitorBody.currentComponent.canReboot
                            }
                        ]

                        Rectangle {
                            id: systemControlActionButton

                            required property var modelData

                            width: (systemMonitorBody.width - 12) / 3
                            height: 34

                            property bool canRun:
                                !!modelData.available
                            property bool isRebootAction:
                                modelData.action === "reboot"

                            color:
                                systemControlMouse.pressed
                                ? Colors.magenta
                                : systemControlMouse.containsMouse
                                  && canRun
                                  && isRebootAction
                                ? Colors.red
                                : systemControlMouse.containsMouse
                                  && canRun
                                ? Colors.yellow
                                : Colors.black

                            opacity: canRun ? 1.0 : 0.32

                            border.width: 1
                            border.color:
                                canRun
                                ? modelData.accent
                                : Colors.white

                            GohuText {
                                anchors.centerIn: parent
                                text: modelData.label
                                font.pixelSize: 9

                                color:
                                    systemControlMouse.pressed
                                    ? Colors.black
                                    : systemControlMouse.containsMouse
                                      && parent.canRun
                                      && parent.isRebootAction
                                    ? Colors.black
                                    : systemControlMouse.containsMouse
                                      && parent.canRun
                                    ? Colors.orange
                                    : parent.canRun
                                    ? modelData.accent
                                    : Colors.white

                                opacity: parent.canRun ? 1.0 : 0.42

                                layer.enabled: parent.canRun
                                layer.effect: DropShadow {
                                    radius: 5
                                    samples: 5
                                    opacity: 0.34
                                    color:
                                        systemControlActionButton.isRebootAction
                                        && systemControlMouse.containsMouse
                                        ? Colors.red
                                        : modelData.accent
                                    transparentBorder: true
                                }
                            }

                            RectangularShadow {
                                anchors.fill: parent
                                spread: 2
                                z: -1
                                opacity:
                                    systemControlMouse.containsMouse
                                    && parent.isRebootAction
                                    && parent.canRun
                                    ? 0.46
                                    : 0.0
                                color: Colors.red
                            }

                            MouseArea {
                                id: systemControlMouse

                                anchors.fill: parent
                                enabled: parent.canRun
                                hoverEnabled: true

                                onClicked: {
                                    appControlWindow.runSystemComponentAction(
                                        systemMonitorBody.currentComponent,
                                        modelData.action
                                    );
                                }
                            }
                        }
                    }
                }

                Item {
                    width: systemContributorHeader.implicitWidth + 32
                    height: systemContributorHeader.implicitHeight + 16

                    GohuText {
                        id: systemContributorHeader
                        anchors.left: parent.left
                        anchors.leftMargin: 16
                        anchors.verticalCenter: parent.verticalCenter
                        text: "PROCESS / APP CONTRIBUTORS"
                        font.pixelSize: 13
                        color: systemMonitorBody.accent
                    }

                    DropShadow {
                        anchors.fill: systemContributorHeader
                        source: systemContributorHeader
                        radius: 5
                        samples: 5
                        opacity: 0.34
                        color: systemMonitorBody.accent
                        transparentBorder: true
                    }
                }

                GohuText {
                    width: parent.width
                    text:
                        systemMonitorBody.currentComponent
                        ? String(
                              systemMonitorBody.currentComponent.contributorNote
                              || ""
                          )
                        : ""
                    font.pixelSize: 9
                    color: Colors.white
                    opacity: 0.58
                    wrapMode: Text.Wrap
                }

                Repeater {
                    model:
                        appControlWindow.contributorRows(
                            systemMonitorBody.currentComponent
                        )

                    Rectangle {
                        required property var modelData

                        width: systemMonitorBody.width - 8
                        height: 38
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Colors.black
                        border.width: 1
                        border.color: systemMonitorBody.accent

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 7
                            anchors.rightMargin: 7
                            spacing: 6

                            GohuText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "⚙"
                                font.pixelSize: 12
                                color: systemMonitorBody.accent

                                layer.enabled: true
                                layer.effect: DropShadow {
                                    radius: 4
                                    samples: 5
                                    opacity: 0.34
                                    color: systemMonitorBody.accent
                                    transparentBorder: true
                                }
                            }

                            GohuText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * 0.40
                                text:
                                    String(modelData.name || "PROCESS")
                                    + "  ["
                                    + String(modelData.pid || "?")
                                    + "]"
                                font.pixelSize: 10
                                color: Colors.white
                                elide: Text.ElideRight
                            }

                            GohuText {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * 0.28
                                text: String(modelData.valueText || "")
                                font.pixelSize: 10
                                color: systemMonitorBody.accent
                                horizontalAlignment: Text.AlignRight
                                elide: Text.ElideRight

                                layer.enabled: true
                                layer.effect: DropShadow {
                                    radius: 4
                                    samples: 5
                                    opacity: 0.32
                                    color: systemMonitorBody.accent
                                    transparentBorder: true
                                }
                            }

                            Rectangle {
                                width: 58
                                height: 26
                                anchors.verticalCenter: parent.verticalCenter

                                property bool canKill:
                                    !!modelData.killable
                                    && Number(modelData.pid || 0) > 1

                                color:
                                    contributorKillMouse.pressed
                                    ? Colors.magenta
                                    : contributorKillMouse.containsMouse
                                      && canKill
                                    ? Colors.yellow
                                    : Colors.black

                                opacity: canKill ? 1.0 : 0.30
                                border.width: 1
                                border.color:
                                    canKill
                                    ? Colors.red
                                    : Colors.white

                                GohuText {
                                    anchors.centerIn: parent

                                    text: "TERM"
                                    font.pixelSize: 9
                                    color:
                                        contributorKillMouse.pressed
                                        ? Colors.black
                                        : contributorKillMouse.containsMouse
                                          && parent.canKill
                                        ? Colors.orange
                                        : parent.canKill
                                        ? Colors.red
                                        : Colors.white

                                    layer.enabled: parent.canKill
                                    layer.effect: DropShadow {
                                        radius: 4
                                        samples: 5
                                        opacity: 0.34
                                        color: Colors.red
                                        transparentBorder: true
                                    }
                                }

                                MouseArea {
                                    id: contributorKillMouse
                                    anchors.fill: parent
                                    enabled: parent.canKill
                                    hoverEnabled: true

                                    onClicked: {
                                        appControlWindow.terminateSystemContributor(
                                            modelData
                                        );
                                    }
                                }
                            }
                        }
                    }
                }

                GohuText {
                    visible:
                        appControlWindow.contributorRows(
                            systemMonitorBody.currentComponent
                        ).length === 0

                    width: parent.width
                    text:
                        systemMonitorBody.currentComponent
                        ? String(
                              systemMonitorBody.currentComponent.contributorNote
                              || "NO PER-PROCESS ATTRIBUTION AVAILABLE"
                          )
                        : ""
                    font.pixelSize: 10
                    color: Colors.white
                    opacity: 0.58
                    wrapMode: Text.Wrap
                }
            }

            Column {
                id: taskManagerBody

                width: parent.width
                spacing: 12

                visible:
                    appControlWindow.selectedResultIsTask()
                    && appControlWindow.selectedResult() !== null

                property var currentTask:
                    appControlWindow.selectedTask()

                GridLayout {
                    id: taskMetricGrid

                    width: parent.width
                    columns: 3
                    columnSpacing: 6
                    rowSpacing: 6

                    Repeater {
                        model: {
                            const task = taskManagerBody.currentTask;
                            if (!task) return [];

                            return [
                                { id: "cpu", label: "CPU", value: Number(task.cpu || 0).toFixed(1) + "%", baseAccent: Colors.orange, critical: appControlWindow.taskMetricIsCritical(task, "cpu") },
                                { id: "mem", label: "MEM", value: Number(task.mem || 0).toFixed(1) + "%", baseAccent: Colors.magenta, critical: appControlWindow.taskMetricIsCritical(task, "mem") },
                                { id: "rss", label: "RSS", value: appControlWindow.formatTaskMemory(task.rss), baseAccent: Colors.cyan, critical: appControlWindow.taskMetricIsCritical(task, "rss") },
                                { id: "threads", label: "THREADS", value: String(task.threads || 0), baseAccent: Colors.omnitrix, critical: appControlWindow.taskMetricIsCritical(task, "threads") },
                                { id: "pid", label: "PID", value: String(task.pid || "?"), baseAccent: Colors.yellow, critical: false },
                                { id: "uptime", label: "UPTIME", value: String(task.elapsed || "?"), baseAccent: Colors.white, critical: false }
                            ];
                        }

                        Rectangle {
                            id: taskMetricCard
                            required property var modelData

                            readonly property color accent:
                                modelData.critical ? Colors.red : modelData.baseAccent
                            readonly property color glowColor:
                                accent === Colors.white ? Colors.cyan : accent
                            readonly property bool favorite:
                                appControlWindow.isTaskMetricFavorite(
                                    taskManagerBody.currentTask,
                                    modelData.id
                                )

                            Layout.fillWidth: true
                            Layout.preferredHeight: 58
                            color: Colors.black
                            border.width: 1
                            border.color: accent

                            RectangularShadow {
                                anchors.fill: parent
                                spread: 3
                                z: -1
                                opacity: modelData.critical ? 0.58 : 0.28
                                color: taskMetricCard.glowColor
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 7
                                spacing: 3

                                GohuText {
                                    text: modelData.label
                                    font.pixelSize: 10
                                    color: taskMetricCard.accent
                                    opacity: 0.90
                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        radius: modelData.critical ? 9 : 5
                                        samples: 7
                                        opacity: modelData.critical ? 0.76 : 0.30
                                        color: taskMetricCard.glowColor
                                        transparentBorder: true
                                    }
                                }

                                GohuText {
                                    width: parent.width - 16
                                    text: modelData.value
                                    font.pixelSize: 16
                                    color: taskMetricCard.accent
                                    elide: Text.ElideRight
                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        radius: modelData.critical ? 10 : 5
                                        samples: 9
                                        opacity: modelData.critical ? 0.90 : 0.38
                                        color: taskMetricCard.glowColor
                                        transparentBorder: true
                                    }
                                }
                            }

                            Item {
                                anchors.right: parent.right
                                anchors.top: parent.top
                                anchors.rightMargin: 2
                                anchors.topMargin: 2
                                width: 20
                                height: 20
                                z: 30

                                GohuText {
                                    anchors.centerIn: parent
                                    text: taskMetricCard.favorite ? "✦" : "✧"
                                    font.pixelSize: 13
                                    color: taskMetricCard.favorite ? taskMetricCard.accent : Colors.white
                                    opacity: taskMetricCard.favorite ? 1.0 : 0.48
                                    layer.enabled: taskMetricCard.favorite
                                    layer.effect: DropShadow {
                                        radius: 5
                                        samples: 5
                                        opacity: 0.46
                                        color: taskMetricCard.glowColor
                                        transparentBorder: true
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        appControlWindow.toggleTaskMetricFavorite(
                                            taskManagerBody.currentTask,
                                            modelData.id
                                        );
                                    }
                                }
                            }
                        }
                    }
                }

                Item {
                    id: taskCpuGraph

                    width: parent.width
                    height: 112

                    GohuText {
                        id: taskCpuGraphTitle
                        anchors.left: parent.left
                        anchors.top: parent.top

                        text:
                            "CPU HISTORY  "
                            + (taskManagerBody.currentTask
                               ? Number(taskManagerBody.currentTask.cpu).toFixed(1)
                               : "0.0")
                            + "%"

                        font.pixelSize: 12
                        color: Colors.orange

                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 5
                            samples: 5
                            opacity: 0.34
                            color: Colors.orange
                            transparentBorder: true
                        }
                    }

                    Rectangle {
                        id: taskCpuGraphFrame

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: taskCpuGraphTitle.bottom
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 5

                        color: Colors.black
                        border.width: 1
                        border.color: Colors.orange

                        RectangularShadow {
                            anchors.fill: parent
                            spread: 3
                            z: -1
                            opacity: 0.30
                            color: Colors.orange
                        }
                    }

                    Item {
                        id: taskCpuCanvas

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.fill: taskCpuGraphFrame
                        anchors.margins: 4
                        z: 2

                        // Kept as a method because appendTaskHistoryValues() calls
                        // requestPaint(). Incrementing this revision simply forces the
                        // point binding to be reevaluated; rendering itself is QML.
                        property int graphRevision: 0
                        function requestPaint() { graphRevision += 1; }

                        readonly property var graphPoints: {
                            const revision = graphRevision;
                            return appControlWindow.graphLinePoints(
                                appControlWindow.taskCpuHistory,
                                width,
                                height,
                                6.0,
                                appControlWindow.taskHistoryLimit,
                                2,
                                2
                            );
                        }

                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                x: 0
                                y: taskCpuCanvas.height * (index + 1) / 4
                                width: taskCpuCanvas.width
                                height: 1
                                color: Colors.orange
                                opacity: 0.16
                            }
                        }

                        // Stable translucent area under the trace. Each point
                        // contributes a narrow vertical strip down to the graph floor;
                        // this recreates the old filled-graph look without Canvas.
                        Repeater {
                            model: taskCpuCanvas.graphPoints.length

                            delegate: Rectangle {
                                readonly property point graphPoint:
                                    taskCpuCanvas.graphPoints[index]
                                x: graphPoint.x - width / 2
                                y: graphPoint.y
                                width: Math.max(2.0,
                                    taskCpuCanvas.width
                                    / Math.max(2, appControlWindow.taskHistoryLimit - 1)
                                    + 0.8)
                                height: Math.max(0, taskCpuCanvas.height - graphPoint.y - 1)
                                color: Colors.orange
                                opacity: 0.10
                                antialiasing: true
                            }
                        }

                        Repeater {
                            model: Math.max(0, taskCpuCanvas.graphPoints.length - 1)

                            delegate: Item {
                                anchors.fill: parent

                                readonly property point p1:
                                    taskCpuCanvas.graphPoints[index]
                                readonly property point p2:
                                    taskCpuCanvas.graphPoints[index + 1]
                                readonly property real dx: p2.x - p1.x
                                readonly property real dy: p2.y - p1.y
                                readonly property real segmentLength:
                                    Math.sqrt(dx * dx + dy * dy)
                                readonly property real segmentAngle:
                                    Math.atan2(dy, dx) * 180 / Math.PI

                                // Soft under-trace. This replaces the old Canvas
                                // shadow/fill without depending on retained paint state.
                                Rectangle {
                                    x: parent.p1.x
                                    y: parent.p1.y - height / 2
                                    width: parent.segmentLength
                                    height: 7
                                    radius: 3.5
                                    rotation: parent.segmentAngle
                                    transformOrigin: Item.Left
                                    color: Colors.orange
                                    opacity: 0.20
                                    antialiasing: true
                                }

                                Rectangle {
                                    x: parent.p1.x
                                    y: parent.p1.y - height / 2
                                    width: parent.segmentLength
                                    height: 2
                                    radius: 1
                                    rotation: parent.segmentAngle
                                    transformOrigin: Item.Left
                                    color: Colors.orange
                                    opacity: 1.0
                                    antialiasing: true
                                }
                            }
                        }
                    }
                }

                Item {
                    id: taskMemGraph

                    width: parent.width
                    height: 112

                    GohuText {
                        id: taskMemGraphTitle
                        anchors.left: parent.left
                        anchors.top: parent.top

                        text:
                            "MEMORY HISTORY  "
                            + (taskManagerBody.currentTask
                               ? Number(taskManagerBody.currentTask.mem).toFixed(1)
                               : "0.0")
                            + "%"

                        font.pixelSize: 12
                        color: Colors.magenta

                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 5
                            samples: 5
                            opacity: 0.34
                            color: Colors.magenta
                            transparentBorder: true
                        }
                    }

                    Rectangle {
                        id: taskMemGraphFrame

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: taskMemGraphTitle.bottom
                        anchors.bottom: parent.bottom
                        anchors.topMargin: 5

                        color: Colors.black
                        border.width: 1
                        border.color: Colors.magenta

                        RectangularShadow {
                            anchors.fill: parent
                            spread: 3
                            z: -1
                            opacity: 0.30
                            color: Colors.magenta
                        }
                    }

                    Item {
                        id: taskMemCanvas

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.fill: taskMemGraphFrame
                        anchors.margins: 4
                        z: 2

                        property int graphRevision: 0
                        function requestPaint() { graphRevision += 1; }

                        readonly property var graphPoints: {
                            const revision = graphRevision;
                            return appControlWindow.graphLinePoints(
                                appControlWindow.taskMemHistory,
                                width,
                                height,
                                0.35,
                                appControlWindow.taskHistoryLimit,
                                2,
                                2
                            );
                        }

                        Repeater {
                            model: 3
                            delegate: Rectangle {
                                x: 0
                                y: taskMemCanvas.height * (index + 1) / 4
                                width: taskMemCanvas.width
                                height: 1
                                color: Colors.magenta
                                opacity: 0.16
                            }
                        }

                        // Stable translucent area under the memory trace.
                        Repeater {
                            model: taskMemCanvas.graphPoints.length

                            delegate: Rectangle {
                                readonly property point graphPoint:
                                    taskMemCanvas.graphPoints[index]
                                x: graphPoint.x - width / 2
                                y: graphPoint.y
                                width: Math.max(2.0,
                                    taskMemCanvas.width
                                    / Math.max(2, appControlWindow.taskHistoryLimit - 1)
                                    + 0.8)
                                height: Math.max(0, taskMemCanvas.height - graphPoint.y - 1)
                                color: Colors.magenta
                                opacity: 0.10
                                antialiasing: true
                            }
                        }

                        Repeater {
                            model: Math.max(0, taskMemCanvas.graphPoints.length - 1)

                            delegate: Item {
                                anchors.fill: parent

                                readonly property point p1:
                                    taskMemCanvas.graphPoints[index]
                                readonly property point p2:
                                    taskMemCanvas.graphPoints[index + 1]
                                readonly property real dx: p2.x - p1.x
                                readonly property real dy: p2.y - p1.y
                                readonly property real segmentLength:
                                    Math.sqrt(dx * dx + dy * dy)
                                readonly property real segmentAngle:
                                    Math.atan2(dy, dx) * 180 / Math.PI

                                Rectangle {
                                    x: parent.p1.x
                                    y: parent.p1.y - height / 2
                                    width: parent.segmentLength
                                    height: 7
                                    radius: 3.5
                                    rotation: parent.segmentAngle
                                    transformOrigin: Item.Left
                                    color: Colors.magenta
                                    opacity: 0.20
                                    antialiasing: true
                                }

                                Rectangle {
                                    x: parent.p1.x
                                    y: parent.p1.y - height / 2
                                    width: parent.segmentLength
                                    height: 2
                                    radius: 1
                                    rotation: parent.segmentAngle
                                    transformOrigin: Item.Left
                                    color: Colors.magenta
                                    opacity: 1.0
                                    antialiasing: true
                                }
                            }
                        }
                    }
                }



                                Item {
                    id: taskTerminationHeaderBox

                    width: taskTerminationHeader.implicitWidth + 32
                    height: taskTerminationHeader.implicitHeight + 16

                    GohuText {
                        id: taskTerminationHeader

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 16

                        text: "PROCESS CONTROL"
                        font.pixelSize: 13
                        color: Colors.red
                    }

                    DropShadow {
                        anchors.fill: taskTerminationHeader
                        source: taskTerminationHeader

                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 10
                        samples: 9
                        opacity: 0.68
                        color: Colors.red
                        transparentBorder: true
                    }
                }

                Rectangle {
                    id: taskEndAction

                    width: parent.width - 10
                    height: 36
                    anchors.horizontalCenter: parent.horizontalCenter

                    property bool isHovered:
                        !appControlWindow.keyboardActive
                        && taskEndActionMouse.containsMouse
                    property bool isPressed: taskEndActionMouse.pressed
                    property bool isSelected:
                        appControlWindow.detailFocused
                        && appControlWindow.selectedResultIsTask()
                        && appControlWindow.selectedDetailActionIndex === 0
                    property bool canEnd:
                        taskManagerBody.currentTask
                        && Number(taskManagerBody.currentTask.pid || 0) > 1

                    color:
                        isPressed
                        ? Colors.magenta
                        : isHovered || isSelected
                        ? Colors.yellow
                        : Colors.black

                    opacity: canEnd ? 1.0 : 0.42

                    border.width: 1
                    border.color: Colors.red

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        spacing: 8

                        GohuText {
                            text: "(-_•)デ╾━"
                            font.pixelSize: 14
                            color:
                                taskEndAction.isPressed
                                ? Colors.black
                                : taskEndAction.isHovered
                                  || taskEndAction.isSelected
                                ? Colors.orange
                                : Colors.red

                            layer.enabled: !taskEndAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0
                                radius: 13
                                samples: 11
                                opacity: 0.86
                                color: Colors.red
                                transparentBorder: true
                            }
                        }

                        GohuText {
                            text: "END PROCESS  [TERM]"
                            font.pixelSize: 14
                            color:
                                taskEndAction.isPressed
                                ? Colors.black
                                : taskEndAction.isHovered
                                  || taskEndAction.isSelected
                                ? Colors.orange
                                : Colors.red

                            layer.enabled: !taskEndAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0
                                radius: 11
                                samples: 9
                                opacity: 0.72
                                color: Colors.red
                                transparentBorder: true
                            }
                        }
                    }

                    MouseArea {
                        id: taskEndActionMouse

                        anchors.fill: parent
                        enabled: taskEndAction.canEnd
                        hoverEnabled: true

                        onEntered: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.selectedDetailActionIndex = 0;
                        }

                        onClicked: {
                            appControlWindow.selectedDetailActionIndex = 0;
                            appControlWindow.terminateSelectedTask();
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        spread: 5
                        z: -1
                        opacity:
                            taskEndAction.isHovered
                            || taskEndAction.isSelected
                            ? 0.74
                            : 0.34
                        color: Colors.red
                    }
                }

                // KEEP THIS FOOTER LAST: metadata stays below every process-control button.
                GridLayout {
                    width: parent.width
                    columns: 3
                    columnSpacing: 6
                    rowSpacing: 4

                    GohuText {
                        Layout.preferredWidth: 62
                        text: "USER"
                        font.pixelSize: 11
                        color: Colors.cyan
                    }

                    GohuText {
                        Layout.preferredWidth: 10
                        text: ":"
                        font.pixelSize: 11
                        color: Colors.white
                    }

                    GohuText {
                        Layout.fillWidth: true
                        text:
                            taskManagerBody.currentTask
                            ? String(taskManagerBody.currentTask.user || "?")
                            : "?"
                        font.pixelSize: 11
                        color: Colors.white
                        elide: Text.ElideRight
                    }

                    GohuText {
                        Layout.preferredWidth: 62
                        text: "PPID"
                        font.pixelSize: 11
                        color: Colors.cyan
                    }

                    GohuText {
                        Layout.preferredWidth: 10
                        text: ":"
                        font.pixelSize: 11
                        color: Colors.white
                    }

                    GohuText {
                        Layout.fillWidth: true
                        text:
                            taskManagerBody.currentTask
                            ? String(taskManagerBody.currentTask.ppid || "?")
                            : "?"
                        font.pixelSize: 11
                        color: Colors.white
                    }

                    GohuText {
                        Layout.preferredWidth: 62
                        text: "VIRT"
                        font.pixelSize: 11
                        color: Colors.cyan
                    }

                    GohuText {
                        Layout.preferredWidth: 10
                        text: ":"
                        font.pixelSize: 11
                        color: Colors.white
                    }

                    GohuText {
                        Layout.fillWidth: true
                        text:
                            taskManagerBody.currentTask
                            ? appControlWindow.formatTaskMemory(
                                  taskManagerBody.currentTask.vsz
                              )
                            : "?"
                        font.pixelSize: 11
                        color: Colors.white
                    }

                    GohuText {
                        Layout.preferredWidth: 62
                        text: "STATE"
                        font.pixelSize: 11
                        color: Colors.cyan
                    }

                    GohuText {
                        Layout.preferredWidth: 10
                        text: ":"
                        font.pixelSize: 11
                        color: Colors.white
                    }

                    GohuText {
                        Layout.fillWidth: true
                        text:
                            taskManagerBody.currentTask
                            ? String(taskManagerBody.currentTask.state || "?")
                            : "?"
                        font.pixelSize: 11
                        color: Colors.white
                    }
                }

                GohuText {
                    width: parent.width

                    text:
                        taskManagerBody.currentTask
                        ? String(taskManagerBody.currentTask.args || "")
                        : ""

                    font.pixelSize: 10
                    color: Colors.white
                    opacity: 0.56
                    wrapMode: Text.Wrap
                }

            }

            Column {
                id: appActionSection

                width: parent.width
                spacing: 8

                visible: appControlWindow.selectedResultIsApplication()
                         && appControlWindow.selectedResult() !== null

                Item {
                    id: actionsHeaderGlowBox

                    width: actionsHeaderText.implicitWidth + 24
                    height: actionsHeaderText.implicitHeight + 16

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

                    GohuText {
                        id: actionsHeaderText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        text: "ACTIONS"

                        font.pixelSize: 13

                        color: Colors.cyan
                    }
                }

                Rectangle {
                    id: launchAction

                    width: parent.width - 10
                    height: 38

                    anchors.horizontalCenter: parent.horizontalCenter

                    property bool isHovered:
                        canLaunch
                        && !appControlWindow.keyboardActive
                        && launchMouse.containsMouse
                    property bool isPressed:
                        canLaunch && launchMouse.pressed
                    property bool isSelected: appControlWindow.detailFocused
                                              && appControlWindow.selectedDetailActionIndex === 0

                    property var currentResult:
                        appControlWindow.selectedResult()
                    property var sourceResult:
                        appControlWindow.favoriteSourceItem(currentResult)
                        || currentResult

                    property bool canLaunch:
                        sourceResult
                        && appControlWindow.appEntryLaunchableForCurrentContext(
                               sourceResult
                           )

                    property bool targetIsFlatpak:
                        sourceResult
                        && appControlWindow.appEntryIsFlatpak(sourceResult)

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.dark

                    opacity: launchAction.canLaunch ? 1.0 : 0.48

                    border.width: 1
                    border.color: isHovered || isSelected ? Colors.orange : Colors.cyan

                    GohuText {
                        id: launchActionText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        text:
                            launchAction.targetIsFlatpak
                            ? launchAction.canLaunch
                              ? "⌯✉︎ ๋࣭⭑  FLATPACK"
                              : "⌯✉︎ ๋࣭⭑  FLATPACK  [UNAVAILABLE]"
                            : launchAction.canLaunch
                              ? "⌯♱ ๋࣭⭑  LAUNCH"
                              : "⌯♱ ๋࣭⭑  LAUNCH  [UNAVAILABLE]"

                        font.pixelSize: 13

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

                        opacity: launchAction.isPressed
                                 ? 0.0
                                 : launchAction.isHovered || launchAction.isSelected
                                 ? 0.48
                                 : 0.38

                        color: launchAction.isHovered || launchAction.isSelected
                               ? Colors.orange
                               : Colors.cyan

                        transparentBorder: true
                    }

                    MouseArea {
                        id: launchMouse

                        anchors.fill: parent
                        enabled: launchAction.canLaunch
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

                        spread: 5
                        z: -1

                        opacity: launchAction.isHovered || launchAction.isSelected
                                 ? 0.62
                                 : 0.26

                        color: launchAction.isHovered || launchAction.isSelected
                               ? Colors.orange
                               : Colors.cyan
                    }
                


                    Item {
                        id: launchActionFavoriteStar

                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter

                        width: 28
                        height: 28
                        z: 5000

                        readonly property int actionIndex: 0
                        readonly property bool actionAvailable:
                            (launchAction.canLaunch)
                            && appControlWindow.detailActionAvailable(actionIndex)
                        readonly property bool actionFavorite:
                            appControlWindow.isDetailActionFavorite(actionIndex)
                        readonly property bool starHovered:
                            launchActionFavoriteStarMouse.containsMouse

                        opacity: actionAvailable ? 1.0 : 0.34

                        GohuText {
                            id: launchActionFavoriteStarGlyph
                            anchors.centerIn: parent

                            text: launchActionFavoriteStar.actionFavorite ? "✦" : "✧"
                            font.pixelSize: 18

                            color:
                                launchActionFavoriteStarMouse.pressed
                                ? Colors.black
                                : launchActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : launchActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white
                        }

                        DropShadow {
                            anchors.fill: launchActionFavoriteStarGlyph
                            source: launchActionFavoriteStarGlyph

                            horizontalOffset: 0
                            verticalOffset: 0

                            radius:
                                launchActionFavoriteStar.actionFavorite
                                || launchActionFavoriteStar.starHovered
                                ? 9
                                : 5
                            samples: 7

                            opacity:
                                launchActionFavoriteStar.actionFavorite
                                ? 0.76
                                : launchActionFavoriteStar.starHovered
                                ? 0.52
                                : 0.14

                            color:
                                launchActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : launchActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white

                            transparentBorder: true
                        }

                        MouseArea {
                            id: launchActionFavoriteStarMouse
                            anchors.fill: parent
                            z: 100

                            enabled: launchActionFavoriteStar.actionAvailable
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            preventStealing: true
                            propagateComposedEvents: false

                            onPressed: function(mouse) {
                                mouse.accepted = true;
                            }

                            onClicked: function(mouse) {
                                mouse.accepted = true;

                                appControlWindow.keyboardActive = true;
                                appControlWindow.detailFocused = true;
                                appControlWindow.selectedDetailActionIndex =
                                    launchActionFavoriteStar.actionIndex;

                                appControlWindow.toggleDetailActionFavorite(
                                    launchActionFavoriteStar.actionIndex
                                );
                            }
                        }
                    }
}

                Column {
                    id: hiddenCommandActionsSection

                    width: parent.width
                    spacing: 7

                    property var currentResult:
                        appControlWindow.selectedResult()
                    property var sourceResult:
                        appControlWindow.favoriteSourceItem(currentResult)
                        || currentResult

                    visible:
                        appControlWindow.selectedResultIsApplication()
                        && sourceResult
                        && sourceResult._hiddenCommand

                    Item {
                        width: hiddenActionsHeaderText.implicitWidth + 24
                        height: hiddenActionsHeaderText.implicitHeight + 14

                        GohuText {
                            id: hiddenActionsHeaderText

                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter

                            text: "HIDDEN ACTIONS"
                            font.pixelSize: 13
                            color: Colors.orange
                        }

                        DropShadow {
                            anchors.fill: hiddenActionsHeaderText
                            source: hiddenActionsHeaderText

                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 6
                            samples: 5
                            opacity: 0.42
                            color: Colors.orange
                            transparentBorder: true
                        }
                    }

                    Repeater {
                        id: hiddenActionsRepeater

                        model: [
                            {
                                label: "KITTY",
                                icon: "≽(^•⩊•^)≼",
                                accent: Colors.magenta
                            },
                            {
                                label: "FLOAT",
                                icon: "⊹ ࣪ ˖🕊⋆₊⊹",
                                accent: Colors.white
                            },
                            {
                                label: "FULLSCREEN",
                                icon: "🂡🂱🃑🂭🂽",
                                accent: Colors.omnitrix
                            }
                        ]

                        Rectangle {
                            id: hiddenActionButton

                            required property int index
                            required property var modelData

                            width: hiddenCommandActionsSection.width - 10
                            height: 34
                            anchors.horizontalCenter: parent.horizontalCenter

                            property int detailIndex: index + 1
                            property bool isHovered:
                                !appControlWindow.keyboardActive
                                && hiddenActionMouse.containsMouse
                            property bool isPressed:
                                hiddenActionMouse.pressed
                            property bool isSelected:
                                appControlWindow.detailFocused
                                && appControlWindow.selectedDetailActionIndex
                                   === detailIndex

                            readonly property color haloColor:
                                isHovered || isSelected
                                ? Colors.orange
                                : modelData.label === "FLOAT"
                                ? Colors.cyan
                                : modelData.accent

                            color:
                                isPressed
                                ? Colors.magenta
                                : isHovered || isSelected
                                ? Colors.yellow
                                : Colors.black

                            border.width: 1
                            border.color:
                                isHovered || isSelected
                                ? Colors.orange
                                : modelData.accent

                            Row {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 10
                                spacing: 8

                                GohuText {
                                    anchors.verticalCenter: parent.verticalCenter

                                    text: modelData.icon
                                    font.pixelSize: 14

                                    color:
                                        hiddenActionButton.isPressed
                                        ? Colors.black
                                        : hiddenActionButton.isHovered
                                          || hiddenActionButton.isSelected
                                        ? Colors.orange
                                        : modelData.accent

                                    layer.enabled: !hiddenActionButton.isPressed
                                    layer.effect: DropShadow {
                                        radius: 8
                                        samples: 7
                                        opacity:
                                            hiddenActionButton.isHovered
                                            || hiddenActionButton.isSelected
                                            ? 0.68
                                            : 0.56
                                        color: hiddenActionButton.haloColor
                                        transparentBorder: true
                                    }
                                }

                                GohuText {
                                    anchors.verticalCenter: parent.verticalCenter

                                    text: modelData.label
                                    font.pixelSize: 14

                                    color:
                                        hiddenActionButton.isPressed
                                        ? Colors.black
                                        : hiddenActionButton.isHovered
                                          || hiddenActionButton.isSelected
                                        ? Colors.orange
                                        : modelData.accent

                                    layer.enabled: !hiddenActionButton.isPressed
                                    layer.effect: DropShadow {
                                        radius: 8
                                        samples: 7
                                        opacity:
                                            hiddenActionButton.isHovered
                                            || hiddenActionButton.isSelected
                                            ? 0.68
                                            : 0.56
                                        color: hiddenActionButton.haloColor
                                        transparentBorder: true
                                    }
                                }
                            }

                            MouseArea {
                                id: hiddenActionMouse

                                anchors.fill: parent
                                hoverEnabled: true

                                onEntered: {
                                    appControlWindow.keyboardActive = false;
                                    appControlWindow.selectedDetailActionIndex =
                                        hiddenActionButton.detailIndex;
                                }

                                onClicked: {
                                    appControlWindow.selectedDetailActionIndex =
                                        hiddenActionButton.detailIndex;
                                    appControlWindow.activateSelectedDetailAction();
                                }
                            }

                            RectangularShadow {
                                anchors.fill: parent
                                spread: 3
                                z: -1

                                opacity:
                                    hiddenActionButton.isHovered
                                    || hiddenActionButton.isSelected
                                    ? 0.48
                                    : 0.28

                                color: hiddenActionButton.haloColor
                            }
                        }
                    }

                    Item {
                        width: hiddenAlternateHeaderText.implicitWidth + 24
                        height: hiddenAlternateHeaderText.implicitHeight + 14
                        GohuText {
                            id: hiddenAlternateHeaderText
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "ALTERNATE ACTIONS"
                            font.pixelSize: 13
                            color: Colors.magenta
                            layer.enabled: true
                            layer.effect: DropShadow { radius: 6; samples: 5; opacity: 0.48; color: Colors.magenta; transparentBorder: true }
                        }
                    }

                    Rectangle {
                        id: hiddenBottleAction
                        width: hiddenCommandActionsSection.width - 10
                        height: 34
                        anchors.horizontalCenter: parent.horizontalCenter
                        property bool canRun: appControlWindow.detailActionAvailable(4)
                        property bool isHovered: canRun && !appControlWindow.keyboardActive && hiddenBottleActionMouse.containsMouse
                        property bool isPressed: canRun && hiddenBottleActionMouse.pressed
                        property bool isSelected: appControlWindow.detailFocused && appControlWindow.selectedDetailActionIndex === 4
                        color: isPressed ? Colors.magenta : isHovered || isSelected ? Colors.yellow : Colors.black
                        opacity: canRun ? 1.0 : 0.38
                        border.width: 1
                        border.color: Colors.magenta
                        Row {
                            id: hiddenBottleActionContent
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Row {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: -2

                                GohuText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "⚱"
                                    font.pixelSize: 10
                                    color:
                                        hiddenBottleAction.isPressed
                                        ? Colors.black
                                        : Colors.magenta

                                    layer.enabled: !hiddenBottleAction.isPressed
                                    layer.effect: DropShadow {
                                        radius: 7
                                        samples: 7
                                        opacity: 0.50
                                        color: Colors.magenta
                                        transparentBorder: true
                                    }
                                }

                                GohuText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "⚱"
                                    font.pixelSize: 17
                                    color:
                                        hiddenBottleAction.isPressed
                                        ? Colors.black
                                        : Colors.magenta

                                    layer.enabled: !hiddenBottleAction.isPressed
                                    layer.effect: DropShadow {
                                        radius: 8
                                        samples: 7
                                        opacity: 0.62
                                        color: Colors.magenta
                                        transparentBorder: true
                                    }
                                }

                                GohuText {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "⚱"
                                    font.pixelSize: 10
                                    color:
                                        hiddenBottleAction.isPressed
                                        ? Colors.black
                                        : Colors.magenta

                                    layer.enabled: !hiddenBottleAction.isPressed
                                    layer.effect: DropShadow {
                                        radius: 7
                                        samples: 7
                                        opacity: 0.50
                                        color: Colors.magenta
                                        transparentBorder: true
                                    }
                                }
                            }

                            GohuText {
                                id: hiddenBottleActionText
                                anchors.verticalCenter: parent.verticalCenter
                                text: hiddenBottleAction.canRun
                                ? "BOTTLES"
                                : "BOTTLES  [NO TARGET]"
                                font.pixelSize: 14
                                color:
                                    hiddenBottleAction.isPressed
                                    ? Colors.black
                                    : Colors.magenta

                                layer.enabled: !hiddenBottleAction.isPressed
                                layer.effect: DropShadow {
                                    radius: 8
                                    samples: 7
                                    opacity:
                                        hiddenBottleAction.isHovered
                                        || hiddenBottleAction.isSelected
                                        ? 0.66
                                        : 0.46
                                    color: Colors.magenta
                                    transparentBorder: true
                                }
                            }
                        }

MouseArea {
                            id: hiddenBottleActionMouse; anchors.fill: parent; enabled: hiddenBottleAction.canRun; hoverEnabled: true
                            onEntered: { appControlWindow.keyboardActive = false; appControlWindow.selectedDetailActionIndex = 4; }
                            onClicked: { appControlWindow.selectedDetailActionIndex = 4; appControlWindow.activateSelectedDetailAction(); }
                        }
                        RectangularShadow { anchors.fill: parent; spread: 3; z: -1; opacity: hiddenBottleAction.isHovered || hiddenBottleAction.isSelected ? 0.46 : 0.24; color: Colors.magenta }
                    }

                    Rectangle {
                        id: hiddenToolboxAction
                        width: hiddenCommandActionsSection.width - 10
                        height: 34
                        anchors.horizontalCenter: parent.horizontalCenter
                        property bool isHovered: !appControlWindow.keyboardActive && hiddenToolboxActionMouse.containsMouse
                        property bool isPressed: hiddenToolboxActionMouse.pressed
                        property bool isSelected: appControlWindow.detailFocused && appControlWindow.selectedDetailActionIndex === 5
                        color: isPressed ? Colors.magenta : isHovered || isSelected ? Colors.yellow : Colors.black
                        border.width: 1
                        border.color: Colors.omnitrix
                        Row {
                            id: hiddenToolboxActionContent
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            Rectangle {
                                width: 22
                                height: 22
                                anchors.verticalCenter: parent.verticalCenter

                                color: Colors.black
                                border.width: 1
                                border.color: Colors.omnitrix

                                GohuText {
                                    anchors.centerIn: parent
                                    text: "🛠"
                                    font.pixelSize: 13
                                    color:
                                        hiddenToolboxAction.isPressed
                                        ? Colors.black
                                        : Colors.omnitrix

                                    layer.enabled: !hiddenToolboxAction.isPressed
                                    layer.effect: DropShadow {
                                        radius: 7
                                        samples: 7
                                        opacity: 0.58
                                        color: Colors.omnitrix
                                        transparentBorder: true
                                    }
                                }
                            }

                            GohuText {
                                id: hiddenToolboxActionText
                                anchors.verticalCenter: parent.verticalCenter
                                text: "TOOLBOX"
                                font.pixelSize: 14
                                color:
                                    hiddenToolboxAction.isPressed
                                    ? Colors.black
                                    : Colors.omnitrix

                                layer.enabled: !hiddenToolboxAction.isPressed
                                layer.effect: DropShadow {
                                    radius: 8
                                    samples: 7
                                    opacity:
                                        hiddenToolboxAction.isHovered
                                        || hiddenToolboxAction.isSelected
                                        ? 0.66
                                        : 0.46
                                    color: Colors.omnitrix
                                    transparentBorder: true
                                }
                            }
                        }

MouseArea {
                            id: hiddenToolboxActionMouse; anchors.fill: parent; hoverEnabled: true
                            onEntered: { appControlWindow.keyboardActive = false; appControlWindow.selectedDetailActionIndex = 5; }
                            onClicked: { appControlWindow.selectedDetailActionIndex = 5; appControlWindow.activateSelectedDetailAction(); }
                        }
                        RectangularShadow { anchors.fill: parent; spread: 3; z: -1; opacity: hiddenToolboxAction.isHovered || hiddenToolboxAction.isSelected ? 0.46 : 0.26; color: Colors.omnitrix }
                    }

                    Item {
                        width: hiddenTerminationHeaderText.implicitWidth + 24
                        height: hiddenTerminationHeaderText.implicitHeight + 14
                        GohuText {
                            id: hiddenTerminationHeaderText
                            anchors.left: parent.left; anchors.leftMargin: 12; anchors.verticalCenter: parent.verticalCenter
                            text: "TERMINATION ACTION"; font.pixelSize: 13; color: Colors.red
                            layer.enabled: true
                            layer.effect: DropShadow { radius: 6; samples: 5; opacity: 0.46; color: Colors.red; transparentBorder: true }
                        }
                    }

                    Rectangle {
                        id: hiddenKillAction
                        width: hiddenCommandActionsSection.width - 10
                        height: 36
                        anchors.horizontalCenter: parent.horizontalCenter
                        property bool isHovered: !appControlWindow.keyboardActive && hiddenKillActionMouse.containsMouse
                        property bool isPressed: hiddenKillActionMouse.pressed
                        property bool isSelected: appControlWindow.detailFocused && appControlWindow.selectedDetailActionIndex === 6
                        color: isPressed ? Colors.magenta : isHovered || isSelected ? Colors.yellow : Colors.black
                        border.width: 1
                        border.color: Colors.red
                        Row {
                            anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 8
                            GohuText { text: "(-_•)デ╾━"; font.pixelSize: 13; color: hiddenKillAction.isPressed ? Colors.black : hiddenKillAction.isHovered || hiddenKillAction.isSelected ? Colors.orange : Colors.red; layer.enabled: !hiddenKillAction.isPressed; layer.effect: DropShadow { radius: 8; samples: 7; opacity: 0.56; color: Colors.red; transparentBorder: true } }
                            GohuText { text: "KILL COMMAND  [TERM]"; font.pixelSize: 13; color: hiddenKillAction.isPressed ? Colors.black : hiddenKillAction.isHovered || hiddenKillAction.isSelected ? Colors.orange : Colors.red; layer.enabled: !hiddenKillAction.isPressed; layer.effect: DropShadow { radius: 8; samples: 7; opacity: 0.56; color: Colors.red; transparentBorder: true } }
                        }
                        MouseArea {
                            id: hiddenKillActionMouse; anchors.fill: parent; hoverEnabled: true
                            onEntered: { appControlWindow.keyboardActive = false; appControlWindow.selectedDetailActionIndex = 6; }
                            onClicked: { appControlWindow.selectedDetailActionIndex = 6; appControlWindow.activateSelectedDetailAction(); }
                        }
                        RectangularShadow { anchors.fill: parent; spread: 3; z: -1; opacity: hiddenKillAction.isHovered || hiddenKillAction.isSelected ? 0.50 : 0.26; color: Colors.red }
                    }

                }


                Item {
                    id: desktopActionsHeaderGlowBox

                    property var currentResult:
                        appControlWindow.selectedResult()

                    visible:
                        currentResult
                        && !(appControlWindow.favoriteSourceItem(currentResult)
                             || currentResult)._hiddenCommand
                        && currentResult.actions.length > 0

                    width: desktopActionsHeaderText.implicitWidth + 24
                    height: desktopActionsHeaderText.implicitHeight + 14

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

                    GohuText {
                        id: desktopActionsHeaderText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        text: "DESKTOP ACTIONS"

                        font.pixelSize: 13
                        color: Colors.orange
                        opacity: 0.75
                    }
                }

                Repeater {
                    id: desktopActionsRepeater

                    model: {
                        const entry = appControlWindow.selectedResult();
                        const source =
                            appControlWindow.favoriteSourceItem(entry)
                            || entry;

                        if (!appControlWindow.selectedResultIsApplication()
                                || !source
                                || source._hiddenCommand)
                            return [];

                        return source.actions;
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

                                source: appControlWindow.safeActionIconSource(modelData.icon)

                                visible: source.toString().length > 0

                                sourceSize.width: 18
                                sourceSize.height: 18
                                asynchronous: false
                                cache: true
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
                                           : desktopActionButton.isHovered
                                             || desktopActionButton.isSelected
                                           ? Colors.orange
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

                                    opacity: desktopActionButton.isPressed
                                             ? 0.0
                                             : desktopActionButton.isHovered
                                               || desktopActionButton.isSelected
                                             ? 0.48
                                             : 0.38

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

                            spread: 5
                            z: -1

                            opacity: desktopActionButton.isHovered
                                     || desktopActionButton.isSelected
                                     ? 0.60
                                     : 0.26

                            color: Colors.orange
                        }
                    


                        Item {
                            id: desktopActionFavoriteStar

                            anchors.right: parent.right
                            anchors.rightMargin: 6
                            anchors.verticalCenter: parent.verticalCenter

                            width: 28
                            height: 28
                            z: 5000

                            readonly property int actionIndex: desktopActionButton.index + 1
                            readonly property bool actionAvailable:
                                (true)
                                && appControlWindow.detailActionAvailable(actionIndex)
                            readonly property bool actionFavorite:
                                appControlWindow.isDetailActionFavorite(actionIndex)
                            readonly property bool starHovered:
                                desktopActionFavoriteStarMouse.containsMouse

                            opacity: actionAvailable ? 1.0 : 0.34

                            GohuText {
                                id: desktopActionFavoriteStarGlyph
                                anchors.centerIn: parent

                                text: desktopActionFavoriteStar.actionFavorite ? "✦" : "✧"
                                font.pixelSize: 18

                                color:
                                    desktopActionFavoriteStarMouse.pressed
                                    ? Colors.black
                                    : desktopActionFavoriteStar.actionFavorite
                                    ? Colors.magenta
                                    : desktopActionFavoriteStar.starHovered
                                    ? Colors.orange
                                    : Colors.white
                            }

                            DropShadow {
                                anchors.fill: desktopActionFavoriteStarGlyph
                                source: desktopActionFavoriteStarGlyph

                                horizontalOffset: 0
                                verticalOffset: 0

                                radius:
                                    desktopActionFavoriteStar.actionFavorite
                                    || desktopActionFavoriteStar.starHovered
                                    ? 9
                                    : 5
                                samples: 7

                                opacity:
                                    desktopActionFavoriteStar.actionFavorite
                                    ? 0.76
                                    : desktopActionFavoriteStar.starHovered
                                    ? 0.52
                                    : 0.14

                                color:
                                    desktopActionFavoriteStar.actionFavorite
                                    ? Colors.magenta
                                    : desktopActionFavoriteStar.starHovered
                                    ? Colors.orange
                                    : Colors.white

                                transparentBorder: true
                            }

                            MouseArea {
                                id: desktopActionFavoriteStarMouse
                                anchors.fill: parent
                                z: 100

                                enabled: desktopActionFavoriteStar.actionAvailable
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton
                                preventStealing: true
                                propagateComposedEvents: false

                                onPressed: function(mouse) {
                                    mouse.accepted = true;
                                }

                                onClicked: function(mouse) {
                                    mouse.accepted = true;

                                    appControlWindow.keyboardActive = true;
                                    appControlWindow.detailFocused = true;
                                    appControlWindow.selectedDetailActionIndex =
                                        desktopActionFavoriteStar.actionIndex;

                                    appControlWindow.toggleDetailActionFavorite(
                                        desktopActionFavoriteStar.actionIndex
                                    );
                                }
                            }
                        }
}
                }

                Item {
                    width: 1
                    height: 6
                }

                Item {
                    id: appAlternateLaunchHeaderGlowBox

                    visible: {
                        const current =
                            appControlWindow.favoriteSourceItem(
                                appControlWindow.selectedResult()
                            )
                            || appControlWindow.selectedResult();

                        return !current || !current._hiddenCommand;
                    }


                    width: appAlternateLaunchHeaderText.implicitWidth + 24
                    height: appAlternateLaunchHeaderText.implicitHeight + 14

                    layer.enabled: true
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 6
                        samples: 5

                        opacity: 0.36
                        color: Colors.magenta

                        transparentBorder: true
                    }

                    GohuText {
                        id: appAlternateLaunchHeaderText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        text: "ALTERNATE ACTIONS"

                        font.pixelSize: 13
                        color: Colors.magenta
                    }
                }

                Rectangle {
                    id: appBottleAction

                    visible: {
                        const current =
                            appControlWindow.favoriteSourceItem(
                                appControlWindow.selectedResult()
                            )
                            || appControlWindow.selectedResult();

                        return !current || !current._hiddenCommand;
                    }


                    width: parent.width - 10
                    height: 34

                    anchors.horizontalCenter: parent.horizontalCenter

                    property var currentResult:
                        appControlWindow.selectedResult()

                    property int detailIndex:
                        currentResult
                        ? currentResult.actions.length + 1
                        : 1

                    property bool hasBottle:
                        appControlWindow.selectedBottleName.length > 0

                    property bool isHovered:
                        hasBottle
                        && !appControlWindow.bottlesLoading
                        && !appControlWindow.keyboardActive
                        && appBottleActionMouse.containsMouse

                    property bool isPressed:
                        hasBottle
                        && !appControlWindow.bottlesLoading
                        && appBottleActionMouse.pressed

                    property bool isSelected:
                        appControlWindow.detailFocused
                        && appControlWindow.selectedDetailActionIndex
                           === detailIndex

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.black

                    opacity:
                        appControlWindow.bottlesLoading
                        || !appBottleAction.hasBottle
                        ? 0.48
                        : 1.0

                    border.width: 1
                    border.color: Colors.magenta
                    Row {
                        id: appBottleActionContent
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: -2

                            GohuText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "⚱"
                                font.pixelSize: 10
                                color:
                                    appBottleAction.isPressed
                                    ? Colors.black
                                    : Colors.magenta

                                layer.enabled: !appBottleAction.isPressed
                                layer.effect: DropShadow {
                                    radius: 7
                                    samples: 7
                                    opacity: 0.50
                                    color: Colors.magenta
                                    transparentBorder: true
                                }
                            }

                            GohuText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "⚱"
                                font.pixelSize: 17
                                color:
                                    appBottleAction.isPressed
                                    ? Colors.black
                                    : Colors.magenta

                                layer.enabled: !appBottleAction.isPressed
                                layer.effect: DropShadow {
                                    radius: 8
                                    samples: 7
                                    opacity: 0.62
                                    color: Colors.magenta
                                    transparentBorder: true
                                }
                            }

                            GohuText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "⚱"
                                font.pixelSize: 10
                                color:
                                    appBottleAction.isPressed
                                    ? Colors.black
                                    : Colors.magenta

                                layer.enabled: !appBottleAction.isPressed
                                layer.effect: DropShadow {
                                    radius: 7
                                    samples: 7
                                    opacity: 0.50
                                    color: Colors.magenta
                                    transparentBorder: true
                                }
                            }
                        }

                        GohuText {
                            id: appBottleActionText
                            anchors.verticalCenter: parent.verticalCenter
                            text: appControlWindow.bottlesLoading
                                ? "BOTTLES  [LOADING]"
                                : appBottleAction.hasBottle
                                ? "BOTTLES"
                                : "BOTTLES  [NO TARGET]"
                            font.pixelSize: 14
                            color:
                                appBottleAction.isPressed
                                ? Colors.black
                                : Colors.magenta

                            layer.enabled: !appBottleAction.isPressed
                            layer.effect: DropShadow {
                                radius: 8
                                samples: 7
                                opacity:
                                    appBottleAction.isHovered
                                    || appBottleAction.isSelected
                                    ? 0.66
                                    : 0.46
                                color: Colors.magenta
                                transparentBorder: true
                            }
                        }
                    }

MouseArea {
                        id: appBottleActionMouse

                        anchors.fill: parent
                        enabled:
                            appBottleAction.hasBottle
                            && !appControlWindow.bottlesLoading
                        hoverEnabled: true

                        onEntered: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.selectedDetailActionIndex =
                                appBottleAction.detailIndex;
                        }

                        onClicked: {
                            appControlWindow.selectedDetailActionIndex =
                                appBottleAction.detailIndex;
                            appControlWindow.activateSelectedDetailAction();
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 5
                        z: -1

                        opacity:
                            appBottleAction.isHovered
                            || appBottleAction.isSelected
                            ? 0.58
                            : 0.20

                        color: Colors.magenta
                    }
                


                    Item {
                        id: appBottleActionFavoriteStar

                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter

                        width: 28
                        height: 28
                        z: 5000

                        readonly property int actionIndex: appBottleAction.detailIndex
                        readonly property bool actionAvailable:
                            (appBottleAction.hasBottle && !appControlWindow.bottlesLoading)
                            && appControlWindow.detailActionAvailable(actionIndex)
                        readonly property bool actionFavorite:
                            appControlWindow.isDetailActionFavorite(actionIndex)
                        readonly property bool starHovered:
                            appBottleActionFavoriteStarMouse.containsMouse

                        opacity: actionAvailable ? 1.0 : 0.34

                        GohuText {
                            id: appBottleActionFavoriteStarGlyph
                            anchors.centerIn: parent

                            text: appBottleActionFavoriteStar.actionFavorite ? "✦" : "✧"
                            font.pixelSize: 18

                            color:
                                appBottleActionFavoriteStarMouse.pressed
                                ? Colors.black
                                : appBottleActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : appBottleActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white
                        }

                        DropShadow {
                            anchors.fill: appBottleActionFavoriteStarGlyph
                            source: appBottleActionFavoriteStarGlyph

                            horizontalOffset: 0
                            verticalOffset: 0

                            radius:
                                appBottleActionFavoriteStar.actionFavorite
                                || appBottleActionFavoriteStar.starHovered
                                ? 9
                                : 5
                            samples: 7

                            opacity:
                                appBottleActionFavoriteStar.actionFavorite
                                ? 0.76
                                : appBottleActionFavoriteStar.starHovered
                                ? 0.52
                                : 0.14

                            color:
                                appBottleActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : appBottleActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white

                            transparentBorder: true
                        }

                        MouseArea {
                            id: appBottleActionFavoriteStarMouse
                            anchors.fill: parent
                            z: 100

                            enabled: appBottleActionFavoriteStar.actionAvailable
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            preventStealing: true
                            propagateComposedEvents: false

                            onPressed: function(mouse) {
                                mouse.accepted = true;
                            }

                            onClicked: function(mouse) {
                                mouse.accepted = true;

                                appControlWindow.keyboardActive = true;
                                appControlWindow.detailFocused = true;
                                appControlWindow.selectedDetailActionIndex =
                                    appBottleActionFavoriteStar.actionIndex;

                                appControlWindow.toggleDetailActionFavorite(
                                    appBottleActionFavoriteStar.actionIndex
                                );
                            }
                        }
                    }
}

                Rectangle {
                    id: appToolboxAction

                    visible: {
                        const current =
                            appControlWindow.favoriteSourceItem(
                                appControlWindow.selectedResult()
                            )
                            || appControlWindow.selectedResult();

                        return !current || !current._hiddenCommand;
                    }


                    width: parent.width - 10
                    height: 34

                    anchors.horizontalCenter: parent.horizontalCenter

                    property var currentResult:
                        appControlWindow.selectedResult()

                    property int detailIndex:
                        currentResult
                        ? currentResult.actions.length + 2
                        : 2

                    property bool canLaunch:
                        currentResult
                        && appControlWindow.appToolboxCommandTokens(
                               currentResult
                           ).length > 0

                    property bool isHovered:
                        canLaunch
                        && !appControlWindow.keyboardActive
                        && appToolboxActionMouse.containsMouse

                    property bool isPressed:
                        canLaunch && appToolboxActionMouse.pressed

                    property bool isSelected:
                        appControlWindow.detailFocused
                        && appControlWindow.selectedDetailActionIndex
                           === detailIndex

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.black

                    opacity: canLaunch ? 1.0 : 0.48

                    border.width: 1
                    border.color: Colors.omnitrix
                    Row {
                        id: appToolboxActionContent
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            width: 22
                            height: 22
                            anchors.verticalCenter: parent.verticalCenter

                            color: Colors.black
                            border.width: 1
                            border.color: Colors.omnitrix

                            GohuText {
                                anchors.centerIn: parent
                                text: "🛠"
                                font.pixelSize: 13
                                color:
                                    appToolboxAction.isPressed
                                    ? Colors.black
                                    : Colors.omnitrix

                                layer.enabled: !appToolboxAction.isPressed
                                layer.effect: DropShadow {
                                    radius: 7
                                    samples: 7
                                    opacity: 0.58
                                    color: Colors.omnitrix
                                    transparentBorder: true
                                }
                            }
                        }

                        GohuText {
                            id: appToolboxActionText
                            anchors.verticalCenter: parent.verticalCenter
                            text: appToolboxAction.canLaunch
                                ? "TOOLBOX"
                                : "TOOLBOX  [UNAVAILABLE]"
                            font.pixelSize: 14
                            color:
                                appToolboxAction.isPressed
                                ? Colors.black
                                : Colors.omnitrix

                            layer.enabled: !appToolboxAction.isPressed
                            layer.effect: DropShadow {
                                radius: 8
                                samples: 7
                                opacity:
                                    appToolboxAction.isHovered
                                    || appToolboxAction.isSelected
                                    ? 0.66
                                    : 0.46
                                color: Colors.omnitrix
                                transparentBorder: true
                            }
                        }
                    }

MouseArea {
                        id: appToolboxActionMouse

                        anchors.fill: parent
                        enabled: appToolboxAction.canLaunch
                        hoverEnabled: true

                        onEntered: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.selectedDetailActionIndex =
                                appToolboxAction.detailIndex;
                        }

                        onClicked: {
                            appControlWindow.selectedDetailActionIndex =
                                appToolboxAction.detailIndex;
                            appControlWindow.activateSelectedDetailAction();
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 5
                        z: -1

                        opacity:
                            appToolboxAction.isHovered
                            || appToolboxAction.isSelected
                            ? 0.56
                            : 0.18

                        color: Colors.omnitrix
                    }

                    Item {
                        id: appToolboxActionFavoriteStar

                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter

                        width: 28
                        height: 28
                        z: 5000

                        readonly property int actionIndex:
                            appToolboxAction.detailIndex
                        readonly property bool actionAvailable:
                            appToolboxAction.canLaunch
                            && appControlWindow.detailActionAvailable(
                                   actionIndex
                               )
                        readonly property bool actionFavorite:
                            appControlWindow.isDetailActionFavorite(
                                actionIndex
                            )
                        readonly property bool starHovered:
                            appToolboxActionFavoriteStarMouse.containsMouse

                        opacity: actionAvailable ? 1.0 : 0.34

                        GohuText {
                            id: appToolboxActionFavoriteStarGlyph
                            anchors.centerIn: parent

                            text:
                                appToolboxActionFavoriteStar.actionFavorite
                                ? "✦"
                                : "✧"

                            font.pixelSize: 18

                            color:
                                appToolboxActionFavoriteStarMouse.pressed
                                ? Colors.black
                                : appToolboxActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : appToolboxActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white
                        }

                        DropShadow {
                            anchors.fill: appToolboxActionFavoriteStarGlyph
                            source: appToolboxActionFavoriteStarGlyph

                            horizontalOffset: 0
                            verticalOffset: 0

                            radius:
                                appToolboxActionFavoriteStar.actionFavorite
                                || appToolboxActionFavoriteStar.starHovered
                                ? 9
                                : 5
                            samples: 7

                            opacity:
                                appToolboxActionFavoriteStar.actionFavorite
                                ? 0.76
                                : appToolboxActionFavoriteStar.starHovered
                                ? 0.52
                                : 0.14

                            color:
                                appToolboxActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : appToolboxActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white

                            transparentBorder: true
                        }

                        MouseArea {
                            id: appToolboxActionFavoriteStarMouse

                            anchors.fill: parent
                            z: 100

                            enabled:
                                appToolboxActionFavoriteStar.actionAvailable
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            preventStealing: true
                            propagateComposedEvents: false

                            onPressed: function(mouse) {
                                mouse.accepted = true;
                            }

                            onClicked: function(mouse) {
                                mouse.accepted = true;

                                appControlWindow.keyboardActive = true;
                                appControlWindow.detailFocused = true;
                                appControlWindow.selectedDetailActionIndex =
                                    appToolboxActionFavoriteStar.actionIndex;

                                appControlWindow.toggleDetailActionFavorite(
                                    appToolboxActionFavoriteStar.actionIndex
                                );
                            }
                        }
                    }
                }

                Item {
                    id: appTerminationHeaderGlowBox

                    visible: {
                        const current =
                            appControlWindow.favoriteSourceItem(
                                appControlWindow.selectedResult()
                            )
                            || appControlWindow.selectedResult();

                        return !current || !current._hiddenCommand;
                    }


                    width: appTerminationHeaderText.implicitWidth + 24
                    height: appTerminationHeaderText.implicitHeight + 14

                    layer.enabled: true
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 7
                        samples: 7
                        opacity: 0.44
                        color: Colors.red
                        transparentBorder: true
                    }

                    GohuText {
                        id: appTerminationHeaderText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        text: "TERMINATION ACTION"
                        font.pixelSize: 13
                        color: Colors.red
                    }
                }

                Rectangle {
                    id: appKillAction

                    visible: {
                        const current =
                            appControlWindow.favoriteSourceItem(
                                appControlWindow.selectedResult()
                            )
                            || appControlWindow.selectedResult();

                        return !current || !current._hiddenCommand;
                    }


                    width: parent.width - 10
                    height: 36
                    anchors.horizontalCenter: parent.horizontalCenter

                    property var currentResult:
                        appControlWindow.selectedResult()

                    property int detailIndex:
                        currentResult
                        ? currentResult.actions.length + 3
                        : 3

                    property bool canKill:
                        appControlWindow.selectedApplicationKillPids().length > 0

                    property bool isHovered:
                        canKill
                        && !appControlWindow.keyboardActive
                        && appKillActionMouse.containsMouse

                    property bool isPressed:
                        canKill
                        && appKillActionMouse.pressed

                    property bool isSelected:
                        appControlWindow.detailFocused
                        && appControlWindow.selectedDetailActionIndex
                           === detailIndex

                    color:
                        isPressed
                        ? Colors.magenta
                        : isHovered || isSelected
                        ? Colors.yellow
                        : Colors.black

                    opacity: canKill ? 1.0 : 0.44

                    border.width: 1
                    border.color: Colors.red

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        spacing: 8

                        GohuText {
                            id: appKillActionIcon

                            text:
                                appKillAction.canKill
                                ? "(-_•)デ╾━"
                                : "(•_•)デ╾━"

                            font.pixelSize: 14

                            color:
                                appKillAction.isPressed
                                ? Colors.black
                                : appKillAction.isHovered
                                  || appKillAction.isSelected
                                ? Colors.orange
                                : Colors.red

                            layer.enabled: !appKillAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0
                                radius: 9
                                samples: 7
                                opacity: 0.66
                                color: Colors.red
                                transparentBorder: true
                            }
                        }

                        GohuText {
                            id: appKillActionText

                            text:
                                appKillAction.canKill
                                ? "KILL APP  [TERM]"
                                : "KILL APP  [NO TARGET]"

                            font.pixelSize: 14

                            color:
                                appKillAction.isPressed
                                ? Colors.black
                                : appKillAction.isHovered
                                  || appKillAction.isSelected
                                ? Colors.orange
                                : Colors.red

                            layer.enabled: !appKillAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0
                                radius: 7
                                samples: 5
                                opacity: 0.50
                                color: Colors.red
                                transparentBorder: true
                            }
                        }
                    }

                    MouseArea {
                        id: appKillActionMouse

                        anchors.fill: parent
                        enabled: appKillAction.canKill
                        hoverEnabled: true

                        onEntered: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.selectedDetailActionIndex =
                                appKillAction.detailIndex;
                        }

                        onClicked: {
                            appControlWindow.selectedDetailActionIndex =
                                appKillAction.detailIndex;
                            appControlWindow.terminateSelectedApplication();
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        spread: 5
                        z: -1

                        opacity:
                            appKillAction.isHovered
                            || appKillAction.isSelected
                            ? 0.64
                            : 0.22

                        color: Colors.red
                    }
                }


            }

            Column {
                id: tabControlSection

                width: parent.width
                spacing: 8

                visible: appControlWindow.selectedResultIsTab()
                         && appControlWindow.selectedResult() !== null

                readonly property var controls:
                    appControlWindow.selectedTabControls()

                Item {
                    width: parent.width
                    height: tabControlIntro.implicitHeight + 10

                    GohuText {
                        id: tabControlIntro

                        width: parent.width
                        anchors.verticalCenter: parent.verticalCenter

                        text: tabControlSection.controls.length > 0
                              ? "ALTERNATE APP ACTIONS • "
                                + tabControlSection.controls.length
                              : "NO ALTERNATE APP ACTIONS EXPOSED"
                        font.pixelSize: 12
                        color: tabControlSection.controls.length > 0
                               ? Colors.cyan
                               : Colors.white
                        opacity: tabControlSection.controls.length > 0
                                 ? 1.0
                                 : 0.58
                    }
                }

                Repeater {
                    id: appTabControlsRepeater

                    model: tabControlSection.controls

                    delegate: Rectangle {
                        id: appTabControlButton

                        required property var modelData
                        required property int index

                        width: tabControlSection.width - 10
                        height: 34

                        anchors.horizontalCenter: parent.horizontalCenter

                        property bool isHovered:
                            !appControlWindow.keyboardActive
                            && appTabControlMouse.containsMouse
                        property bool isPressed:
                            appTabControlMouse.pressed
                        property bool isSelected:
                            appControlWindow.detailFocused
                            && appControlWindow.selectedDetailActionIndex
                               === index

                        readonly property string actionName: String(
                            modelData.controlName
                            || modelData.name
                            || "APP ACTION"
                        )
                        readonly property string actionNameLower:
                            actionName.toLowerCase()
                        readonly property bool isCloseAction:
                            actionNameLower.indexOf("close") !== -1
                        readonly property bool isMuteAction:
                            actionNameLower.indexOf("mute") !== -1
                        readonly property bool isUnmuteAction:
                            isMuteAction
                            && actionNameLower.indexOf("unmute") !== -1
                        readonly property bool isNewTabAction:
                            actionNameLower.indexOf("new tab") !== -1
                            || (actionNameLower.indexOf("open") !== -1
                                && actionNameLower.indexOf("tab") !== -1)
                        readonly property bool hasSemanticAccent:
                            isCloseAction || isMuteAction || isNewTabAction
                        readonly property color semanticAccent:
                            isCloseAction
                            ? Colors.red
                            : isMuteAction
                            ? Colors.omnitrix
                            : Colors.cyan
                        readonly property color visualAccent:
                            hasSemanticAccent
                            ? semanticAccent
                            : isHovered || isSelected
                            ? Colors.orange
                            : Colors.cyan

                        // Selected CLOSE/MUTE controls keep their semantic
                        // red/omnitrix border + glow while using yellow fill.
                        color: isPressed
                               ? Colors.magenta
                               : isHovered || isSelected
                               ? Colors.yellow
                               : Colors.black

                        border.width: 1
                        border.color: visualAccent

                        Row {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            spacing: 8

                            GohuText {
                                anchors.verticalCenter: parent.verticalCenter
                                text:
                                    appTabControlButton.isCloseAction
                                    ? "(-_•)デ╾━"
                                    : appTabControlButton.isMuteAction
                                    ? (appTabControlButton.isUnmuteAction
                                       ? "⊹ ࣪ (ᴗ˳ᴗ)ᶻ𝗓 ࣪ "
                                       : "* (ˊᗜˋو)و︎︎♬*")
                                    : "⌯"
                                font.pixelSize:
                                    appTabControlButton.isMuteAction
                                    ? 11
                                    : 14
                                color: appTabControlButton.isPressed
                                       ? Colors.black
                                       : appTabControlButton.visualAccent

                                layer.enabled: !appTabControlButton.isPressed
                                layer.effect: DropShadow {
                                    horizontalOffset: 0
                                    verticalOffset: 0
                                    radius: 5
                                    samples: 5
                                    opacity: 0.42
                                    color: appTabControlButton.visualAccent
                                    transparentBorder: true
                                }
                            }

                            GohuText {
                                width: parent.width - 28
                                anchors.verticalCenter: parent.verticalCenter

                                text: appTabControlButton.isCloseAction
                                      ? "\"CLOSE\" TAB"
                                      : appTabControlButton.isMuteAction
                                      ? (appTabControlButton.isUnmuteAction
                                         ? "UNMUTE TAB"
                                         : "MUTE TAB")
                                      : appTabControlButton.actionName
                                font.pixelSize: 14
                                color: appTabControlButton.isPressed
                                       ? Colors.black
                                       : appTabControlButton.hasSemanticAccent
                                       ? appTabControlButton.semanticAccent
                                       : appTabControlButton.isHovered
                                         || appTabControlButton.isSelected
                                       ? Colors.orange
                                       : Colors.white
                                elide: Text.ElideRight

                                layer.enabled:
                                    !appTabControlButton.isPressed
                                layer.effect: DropShadow {
                                    horizontalOffset: 0
                                    verticalOffset: 0
                                    radius: 5
                                    samples: 5
                                    opacity: 0.34
                                    color: appTabControlButton.visualAccent
                                    transparentBorder: true
                                }
                            }
                        }

                        MouseArea {
                            id: appTabControlMouse

                            anchors.fill: parent
                            hoverEnabled: true

                            onEntered: {
                                appControlWindow.keyboardActive = false;
                                appControlWindow.selectedDetailActionIndex =
                                    appTabControlButton.index;
                            }

                            onClicked: {
                                appControlWindow.selectedDetailActionIndex =
                                    appTabControlButton.index;
                                appControlWindow.activateSelectedDetailAction();
                            }
                        }

                        RectangularShadow {
                            anchors.fill: parent
                            spread: 3
                            z: -1

                            opacity: appTabControlButton.isPressed
                                     ? 0.0
                                     : appTabControlButton.isHovered
                                       || appTabControlButton.isSelected
                                     ? 0.46
                                     : 0.20
                            color: appTabControlButton.visualAccent
                        }
                    }
                }
            }

            Column {
                id: windowActionSection

                width: parent.width
                spacing: 8

                visible: appControlWindow.selectedResultIsWindow()
                         && appControlWindow.selectedResult() !== null

                Item {
                    id: windowActionsHeaderGlowBox

                    width: windowActionsHeaderText.implicitWidth + 24
                    height: windowActionsHeaderText.implicitHeight + 16

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

                    GohuText {
                        id: windowActionsHeaderText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        text: "WINDOW ACTIONS"

                        font.pixelSize: 13
                        color: Colors.white

                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 5
                            samples: 5
                            opacity: 0.34
                            color: Colors.cyan
                            transparentBorder: true
                        }
                    }
                }

                Repeater {
                    id: windowPrimaryActionsRepeater

                    model: 5

                    delegate: Rectangle {
                        id: windowPrimaryActionButton

                        required property int index

                        width: windowActionSection.width - 10
                        height: index === 0 ? 38 : 34

                        anchors.horizontalCenter: parent.horizontalCenter

                        property bool isHovered:
                            !appControlWindow.keyboardActive
                            && windowPrimaryActionMouse.containsMouse
                        property bool isPressed:
                            windowPrimaryActionMouse.pressed
                        property bool isSelected:
                            appControlWindow.detailFocused
                            && appControlWindow.selectedDetailActionIndex === index
                        readonly property bool hasSemanticAccent:
                            index === 2 || index === 4
                        readonly property color inactiveAccent:
                            index === 2
                            ? Colors.white
                            : index === 4
                            ? Colors.omnitrix
                            : Colors.cyan
                        readonly property color visualAccent:
                            isHovered || isSelected
                            ? Colors.orange
                            : inactiveAccent
                        readonly property color glowAccent:
                            isHovered || isSelected
                            ? Colors.orange
                            : index === 2
                            ? Colors.cyan
                            : inactiveAccent

                        color: isPressed
                               ? Colors.magenta
                               : isHovered || isSelected
                               ? Colors.yellow
                               : index === 0
                               ? Colors.dark
                               : Colors.black

                        border.width: 1
                        border.color: visualAccent

                        Row {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 10
                            spacing: 8

                            Item {
                                id: windowPrimaryActionIconBox

                                anchors.verticalCenter: parent.verticalCenter

                                width:
                                    windowPrimaryActionIcon.implicitWidth + 16
                                height:
                                    windowPrimaryActionIcon.implicitHeight + 12

                                GohuText {
                                    id: windowPrimaryActionIcon

                                    anchors.centerIn: parent

                                    text:
                                        appControlWindow.windowPrimaryActionIcon(
                                            windowPrimaryActionButton.index
                                        )

                                    font.pixelSize: 14

                                    color: windowPrimaryActionButton.isPressed
                                           ? Colors.black
                                           : windowPrimaryActionButton.hasSemanticAccent
                                           ? windowPrimaryActionButton.visualAccent
                                           : windowPrimaryActionButton.isHovered
                                             || windowPrimaryActionButton.isSelected
                                           ? Colors.orange
                                           : Colors.white
                                }

                                DropShadow {
                                    anchors.fill: windowPrimaryActionIcon
                                    source: windowPrimaryActionIcon

                                    horizontalOffset: 0
                                    verticalOffset: 0

                                    readonly property bool topThreeIcon:
                                        windowPrimaryActionButton.index <= 2
                                    readonly property bool boostedIcon:
                                        topThreeIcon
                                        || windowPrimaryActionButton.index === 4

                                    radius:
                                        topThreeIcon
                                        ? 18
                                        : boostedIcon
                                        ? 15
                                        : 10
                                    samples:
                                        topThreeIcon
                                        ? 9
                                        : boostedIcon
                                        ? 9
                                        : 7

                                    opacity:
                                        windowPrimaryActionButton.isPressed
                                        ? 0.0
                                        : topThreeIcon
                                        ? (windowPrimaryActionButton.isHovered
                                           || windowPrimaryActionButton.isSelected
                                           ? 1.0
                                           : 0.98)
                                        : boostedIcon
                                        ? (windowPrimaryActionButton.isHovered
                                           || windowPrimaryActionButton.isSelected
                                           ? 0.98
                                           : 0.92)
                                        : (windowPrimaryActionButton.isHovered
                                           || windowPrimaryActionButton.isSelected
                                           ? 0.72
                                           : 0.56)

                                    color: windowPrimaryActionButton.glowAccent

                                    transparentBorder: true
                                }
                            }

                            GohuText {
                                id: windowPrimaryActionText

                                anchors.verticalCenter: parent.verticalCenter

                                text:
                                    appControlWindow.windowPrimaryActionLabel(
                                        windowPrimaryActionButton.index
                                    )

                                font.pixelSize: 14

                                color: windowPrimaryActionButton.isPressed
                                       ? Colors.black
                                       : windowPrimaryActionButton.hasSemanticAccent
                                       ? windowPrimaryActionButton.visualAccent
                                       : windowPrimaryActionButton.isHovered
                                         || windowPrimaryActionButton.isSelected
                                       ? Colors.orange
                                       : Colors.white

                                layer.enabled:
                                    !windowPrimaryActionButton.isPressed

                                layer.effect: DropShadow {
                                    horizontalOffset: 0
                                    verticalOffset: 0
                                    radius: 5
                                    samples: 5
                                    opacity: 0.34
                                    color: windowPrimaryActionButton.glowAccent
                                    transparentBorder: true
                                }
                            }
                        }

                        MouseArea {
                            id: windowPrimaryActionMouse

                            anchors.fill: parent
                            hoverEnabled: true

                            onEntered: {
                                appControlWindow.keyboardActive = false;
                                appControlWindow.selectedDetailActionIndex =
                                    windowPrimaryActionButton.index;
                            }

                            onClicked: {
                                appControlWindow.selectedDetailActionIndex =
                                    windowPrimaryActionButton.index;
                                appControlWindow.activateSelectedDetailAction();
                            }
                        }

                        RectangularShadow {
                            anchors.fill: parent

                            spread: 3
                            z: -1

                            opacity:
                                windowPrimaryActionButton.isPressed
                                ? 0.0
                                : windowPrimaryActionButton.isHovered
                                  || windowPrimaryActionButton.isSelected
                                ? 0.46
                                : 0.20

                            // FLOAT keeps white text/border but uses a cyan halo.
                            // FULLSCREEN keeps its omnitrix semantic accent.
                            color: windowPrimaryActionButton.glowAccent
                        }
                    }
                }

                Item {
                    width: 1
                    height: 6
                }

                Item {
                    id: windowAudioHeaderGlowBox

                    width: windowAudioHeaderText.implicitWidth + 24
                    height: windowAudioHeaderText.implicitHeight + 14

                    layer.enabled: true
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 6
                        samples: 5
                        opacity: 0.36
                        color: Colors.green
                        transparentBorder: true
                    }

                    GohuText {
                        id: windowAudioHeaderText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        text: "AUDIO ACTION"

                        font.pixelSize: 13
                        color: Colors.omnitrix
                    }
                }

                Rectangle {
                    id: windowMuteAction

                    width: parent.width - 10
                    height: 34

                    anchors.horizontalCenter: parent.horizontalCenter

                    property bool isHovered:
                        !appControlWindow.keyboardActive
                        && windowMuteActionMouse.containsMouse
                    property bool isPressed:
                        windowMuteActionMouse.pressed
                    property bool isSelected:
                        appControlWindow.detailFocused
                        && appControlWindow.selectedDetailActionIndex === 5

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.black

                    opacity: 1.0

                    border.width: 1
                    border.color: Colors.omnitrix

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        spacing: 8

                        Item {
                            id: windowMuteActionIconBox

                            anchors.verticalCenter: parent.verticalCenter

                            width: windowMuteActionIcon.implicitWidth
                            height: windowMuteActionIcon.implicitHeight

                            GohuText {
                                id: windowMuteActionIcon

                                anchors.centerIn: parent

                                text: appControlWindow.windowAudioMuted
                                      ? "⊹ ࣪ (ᴗ˳ᴗ)ᶻ𝗓 ࣪ "
                                      : "* (ˊᗜˋو)و︎︎♬*"

                                font.pixelSize: 14

                                color: windowMuteAction.isPressed
                                       ? Colors.black
                                       : windowMuteAction.isHovered
                                       ? Colors.green
                                       : Colors.omnitrix
                            }

                            DropShadow {
                                anchors.fill: windowMuteActionIcon
                                source: windowMuteActionIcon

                                horizontalOffset: 0
                                verticalOffset: 0

                                radius: 15
                                samples: 11

                                opacity:
                                    windowMuteAction.isPressed
                                    ? 0.0
                                    : windowMuteAction.isHovered
                                      || windowMuteAction.isSelected
                                    ? 0.94
                                    : 0.78

                                color: Colors.green

                                transparentBorder: true
                            }
                        }

                        GohuText {
                            id: windowMuteActionText

                            anchors.verticalCenter: parent.verticalCenter

                            text: appControlWindow.windowAudioMuted
                                  ? "UNMUTE WINDOW"
                                  : "MUTE WINDOW"

                            font.pixelSize: 14
                            color: windowMuteAction.isPressed
                                   ? Colors.black
                                   : Colors.omnitrix

                            layer.enabled: !windowMuteAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0

                                radius: 11
                                samples: 9

                                opacity:
                                    windowMuteAction.isHovered
                                    || windowMuteAction.isSelected
                                    ? 0.82
                                    : 0.58

                                color: Colors.green

                                transparentBorder: true
                            }
                        }
                    }

                    MouseArea {
                        id: windowMuteActionMouse

                        anchors.fill: parent
                        enabled: true
                        hoverEnabled: true

                        onEntered: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.selectedDetailActionIndex = 5;
                        }

                        onClicked: {
                            appControlWindow.selectedDetailActionIndex = 5;
                            appControlWindow.activateSelectedDetailAction();
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        spread: 5
                        z: -1

                        opacity: windowMuteAction.isHovered
                                 || windowMuteAction.isSelected
                                 ? 0.54
                                 : 0.20

                        color: Colors.green
                    }
                }

                Item {
                    id: windowTerminationHeaderGlowBox

                    width: windowTerminationHeaderText.implicitWidth + 24
                    height: windowTerminationHeaderText.implicitHeight + 14

                    layer.enabled: true
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 0
                        radius: 5
                        samples: 5
                        opacity: 0.24
                        color: Colors.red
                        transparentBorder: true
                    }

                    GohuText {
                        id: windowTerminationHeaderText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        text: "TERMINATION ACTION"

                        font.pixelSize: 13
                        color: Colors.red
                        opacity: 0.82
                    }
                }

                Rectangle {
                    id: windowKillAction

                    width: parent.width - 10
                    height: 34

                    anchors.horizontalCenter: parent.horizontalCenter

                    property bool isHovered:
                        !appControlWindow.keyboardActive
                        && windowKillActionMouse.containsMouse
                    property bool isPressed:
                        windowKillActionMouse.pressed
                    property bool isSelected:
                        appControlWindow.detailFocused
                        && appControlWindow.selectedDetailActionIndex === 6

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.black

                    border.width: 1
                    border.color: Colors.red

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        spacing: 8

                        GohuText {
                            id: windowKillActionIcon

                            anchors.verticalCenter: parent.verticalCenter

                            text: "(-_•)デ╾━"
                            font.pixelSize: 14
                            color: windowKillAction.isPressed
                                   ? Colors.black
                                   : Colors.red

                            layer.enabled: !windowKillAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0

                                radius: 10
                                samples: 7

                                opacity:
                                    windowKillAction.isHovered
                                    || windowKillAction.isSelected
                                    ? 0.82
                                    : 0.60

                                color: Colors.red
                                transparentBorder: true
                            }
                        }

                        GohuText {
                            id: windowKillActionText

                            anchors.verticalCenter: parent.verticalCenter

                            text: "KILL WINDOW"

                            font.pixelSize: 14
                            color: windowKillAction.isPressed
                                   ? Colors.black
                                   : Colors.red

                            layer.enabled: !windowKillAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0
                                radius: 6
                                samples: 5
                                opacity: 0.40
                                color: Colors.red
                                transparentBorder: true
                            }
                        }
                    }

                    MouseArea {
                        id: windowKillActionMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onEntered: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.selectedDetailActionIndex = 6;
                        }

                        onClicked: {
                            appControlWindow.selectedDetailActionIndex = 6;
                            appControlWindow.activateSelectedDetailAction();
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        spread: 5
                        z: -1

                        opacity: windowKillAction.isHovered
                                 || windowKillAction.isSelected
                                 ? 0.60
                                 : 0.22

                        color: Colors.red
                    }
                }

                GridLayout {
                    width: parent.width

                    columns: 3
                    columnSpacing: 6
                    rowSpacing: 4

                    GohuText {
                        Layout.preferredWidth: 92
                        text: "OUTPUT"
                        font.pixelSize: 13
                        color: Colors.orange
                    }

                    GohuText {
                        Layout.preferredWidth: 10
                        text: ":"
                        font.pixelSize: 13
                        color: Colors.white
                    }

                    GohuText {
                        Layout.fillWidth: true
                        text: {
                            const entry = appControlWindow.selectedResult();
                            return entry ? String(entry.output || "—") : "—";
                        }
                        font.pixelSize: 13
                        color: appControlWindow.isWindowOnSecondOutput(
                                   appControlWindow.selectedResult()
                               )
                               ? Colors.white
                               : Colors.cyan
                        elide: Text.ElideRight

                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 5
                            samples: 5
                            opacity: 0.34
                            color: Colors.cyan
                            transparentBorder: true
                        }
                    }

                    GohuText {
                        Layout.preferredWidth: 92
                        text: "WORKSPACE"
                        font.pixelSize: 13
                        color: Colors.orange
                    }

                    GohuText {
                        Layout.preferredWidth: 10
                        text: ":"
                        font.pixelSize: 13
                        color: Colors.white
                    }

                    GohuText {
                        Layout.fillWidth: true
                        text: {
                            const entry = appControlWindow.selectedResult();
                            return entry ? String(entry.workspace || "—") : "—";
                        }
                        font.pixelSize: 13
                        color: Colors.white
                        elide: Text.ElideRight
                    }

                    GohuText {
                        Layout.preferredWidth: 92
                        text: "STATE"
                        font.pixelSize: 13
                        color: Colors.orange
                    }

                    GohuText {
                        Layout.preferredWidth: 10
                        text: ":"
                        font.pixelSize: 13
                        color: Colors.white
                    }

                    GohuText {
                        Layout.fillWidth: true
                        text: {
                            const entry = appControlWindow.selectedResult();

                            if (!entry)
                                return "—";

                            return entry.fullscreen
                                   ? "FULLSCREEN"
                                   : entry.floating
                                   ? "FLOATING"
                                   : "TILED";
                        }
                        font.pixelSize: 13
                        color: Colors.cyan
                        elide: Text.ElideRight
                    }

                    GohuText {
                        Layout.preferredWidth: 92
                        text: "AUDIO"
                        font.pixelSize: 13
                        color: Colors.orange
                    }

                    GohuText {
                        Layout.preferredWidth: 10
                        text: ":"
                        font.pixelSize: 13
                        color: Colors.white
                    }

                    GohuText {
                        Layout.fillWidth: true
                        text: appControlWindow.windowAudioPolicyActive
                              && !appControlWindow.windowAudioAvailable
                              ? "MUTED • ARMED"
                              : !appControlWindow.windowAudioAvailable
                              ? "IDLE"
                              : appControlWindow.windowAudioMuted
                              ? "MUTED"
                              : "ACTIVE"
                        font.pixelSize: 13
                        color: appControlWindow.windowAudioMuted
                               ? Colors.magenta
                               : appControlWindow.windowAudioAvailable
                               ? Colors.omnitrix
                               : Colors.white
                        elide: Text.ElideRight
                    }
                }
            }

            Column {
                id: runActionSection

                width: parent.width
                spacing: 8

                visible: appControlWindow.selectedResultIsRun()
                         && appControlWindow.selectedResult() !== null

                Item {
                    id: runActionsHeaderGlowBox

                    width: runActionsHeaderText.implicitWidth + 24
                    height: runActionsHeaderText.implicitHeight + 16

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

                    GohuText {
                        id: runActionsHeaderText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        text: "COMMAND ACTION"

                        font.pixelSize: 13
                        color: Colors.cyan
                    }
                }

                Rectangle {
                    id: runAction

                    width: parent.width - 10
                    height: 38

                    anchors.horizontalCenter: parent.horizontalCenter

                    property bool isHovered:
                        !appControlWindow.keyboardActive
                        && runActionMouse.containsMouse
                    property bool isPressed: runActionMouse.pressed
                    property bool isSelected:
                        appControlWindow.detailFocused
                        && appControlWindow.selectedDetailActionIndex === 0

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: isHovered || isSelected
                                  ? Colors.orange
                                  : Colors.cyan

                    GohuText {
                        id: runActionText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        text: "⌯✎﹏﹏  RUN COMMAND"

                        font.pixelSize: 15

                        color: runAction.isPressed
                               ? Colors.black
                               : runAction.isHovered
                                 || runAction.isSelected
                               ? Colors.orange
                               : Colors.cyan
                    }

                    DropShadow {
                        anchors.fill: runActionText
                        source: runActionText

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 7
                        samples: 5

                        z: 2

                        opacity: runAction.isPressed
                                 ? 0.0
                                 : runAction.isHovered || runAction.isSelected
                                 ? 0.48
                                 : 0.38

                        color: runAction.isHovered || runAction.isSelected
                               ? Colors.orange
                               : Colors.cyan

                        transparentBorder: true
                    }

                    MouseArea {
                        id: runActionMouse

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

                        spread: 5
                        z: -1

                        opacity: runAction.isHovered || runAction.isSelected
                                 ? 0.62
                                 : 0.26

                        color: runAction.isHovered || runAction.isSelected
                               ? Colors.orange
                               : Colors.cyan
                    }
                


                    Item {
                        id: runActionFavoriteStar

                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter

                        width: 28
                        height: 28
                        z: 5000

                        readonly property int actionIndex: 0
                        readonly property bool actionAvailable:
                            (true)
                            && appControlWindow.detailActionAvailable(actionIndex)
                        readonly property bool actionFavorite:
                            appControlWindow.isDetailActionFavorite(actionIndex)
                        readonly property bool starHovered:
                            runActionFavoriteStarMouse.containsMouse

                        opacity: actionAvailable ? 1.0 : 0.34

                        GohuText {
                            id: runActionFavoriteStarGlyph
                            anchors.centerIn: parent

                            text: runActionFavoriteStar.actionFavorite ? "✦" : "✧"
                            font.pixelSize: 18

                            color:
                                runActionFavoriteStarMouse.pressed
                                ? Colors.black
                                : runActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : runActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white
                        }

                        DropShadow {
                            anchors.fill: runActionFavoriteStarGlyph
                            source: runActionFavoriteStarGlyph

                            horizontalOffset: 0
                            verticalOffset: 0

                            radius:
                                runActionFavoriteStar.actionFavorite
                                || runActionFavoriteStar.starHovered
                                ? 9
                                : 5
                            samples: 7

                            opacity:
                                runActionFavoriteStar.actionFavorite
                                ? 0.76
                                : runActionFavoriteStar.starHovered
                                ? 0.52
                                : 0.14

                            color:
                                runActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : runActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white

                            transparentBorder: true
                        }

                        MouseArea {
                            id: runActionFavoriteStarMouse
                            anchors.fill: parent
                            z: 100

                            enabled: runActionFavoriteStar.actionAvailable
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            preventStealing: true
                            propagateComposedEvents: false

                            onPressed: function(mouse) {
                                mouse.accepted = true;
                            }

                            onClicked: function(mouse) {
                                mouse.accepted = true;

                                appControlWindow.keyboardActive = true;
                                appControlWindow.detailFocused = true;
                                appControlWindow.selectedDetailActionIndex =
                                    runActionFavoriteStar.actionIndex;

                                appControlWindow.toggleDetailActionFavorite(
                                    runActionFavoriteStar.actionIndex
                                );
                            }
                        }
                    }
}

                Item {
                    id: runAlternateActionsHeaderGlowBox

                    width: runAlternateActionsHeaderText.implicitWidth + 24
                    height: runAlternateActionsHeaderText.implicitHeight + 16

                    layer.enabled: true
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 5
                        samples: 5

                        opacity: 0.20
                        color: Colors.magenta

                        transparentBorder: true
                    }

                    GohuText {
                        id: runAlternateActionsHeaderText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        text: "ALTERNATE ACTIONS"

                        font.pixelSize: 13
                        color: Colors.magenta
                        opacity: 0.75
                    }
                }

                Rectangle {
                    id: runKittyAction

                    width: parent.width - 10
                    height: 34

                    anchors.horizontalCenter: parent.horizontalCenter

                    property bool isHovered:
                        !appControlWindow.keyboardActive
                        && runKittyActionMouse.containsMouse
                    property bool isPressed: runKittyActionMouse.pressed
                    property bool isSelected:
                        appControlWindow.detailFocused
                        && appControlWindow.selectedDetailActionIndex === 1

                    // Match the alternate/desktop-action visual language.
                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.black

                    border.width: 1
                    border.color:
                        isHovered || isSelected
                        ? Colors.orange
                        : Colors.magenta

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10

                        spacing: 8

                        GohuText {
                            id: runKittyActionIcon

                            anchors.verticalCenter: parent.verticalCenter

                            text: "≽(^•⩊•^)≼"
                            font.pixelSize: 14

                            color: runKittyAction.isPressed
                                   ? Colors.black
                                   : runKittyAction.isHovered
                                     || runKittyAction.isSelected
                                   ? Colors.orange
                                   : Colors.magenta

                            layer.enabled: !runKittyAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0

                                radius: 9
                                samples: 7

                                opacity:
                                    runKittyAction.isHovered
                                    || runKittyAction.isSelected
                                    ? 0.68
                                    : 0.50

                                color:
                                    runKittyAction.isHovered
                                    || runKittyAction.isSelected
                                    ? Colors.orange
                                    : Colors.magenta
                                transparentBorder: true
                            }
                        }

                        GohuText {
                            id: runKittyActionText

                            anchors.verticalCenter: parent.verticalCenter

                            text: "KITTY"

                            font.pixelSize: 14
                            color: runKittyAction.isPressed
                                   ? Colors.black
                                   : runKittyAction.isHovered
                                     || runKittyAction.isSelected
                                   ? Colors.orange
                                   : Colors.magenta

                            layer.enabled: !runKittyAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0

                                radius: 11
                                samples: 9

                                opacity:
                                    runKittyAction.isHovered
                                    || runKittyAction.isSelected
                                    ? 0.78
                                    : 0.60

                                color:
                                    runKittyAction.isHovered
                                    || runKittyAction.isSelected
                                    ? Colors.orange
                                    : Colors.magenta
                                transparentBorder: true
                            }
                        }
                    }

                    DropShadow {
                        anchors.fill: runKittyActionText
                        source: runKittyActionText

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 12
                        samples: 9

                        opacity: runKittyAction.isPressed
                                 ? 0.0
                                 : runKittyAction.isHovered
                                   || runKittyAction.isSelected
                                 ? 0.82
                                 : 0.62

                        color:
                            runKittyAction.isHovered
                            || runKittyAction.isSelected
                            ? Colors.orange
                            : Colors.magenta
                        transparentBorder: true
                    }

                    MouseArea {
                        id: runKittyActionMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onEntered: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.selectedDetailActionIndex = 1;
                        }

                        onClicked: {
                            appControlWindow.selectedDetailActionIndex = 1;
                            appControlWindow.activateSelectedDetailAction();
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 5
                        z: -1

                        opacity: runKittyAction.isHovered
                                 || runKittyAction.isSelected
                                 ? 0.60
                                 : 0.26

                        color:
                            runKittyAction.isHovered
                            || runKittyAction.isSelected
                            ? Colors.orange
                            : Colors.magenta
                    }
                


                    Item {
                        id: runKittyActionFavoriteStar

                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter

                        width: 28
                        height: 28
                        z: 5000

                        readonly property int actionIndex: 1
                        readonly property bool actionAvailable:
                            (true)
                            && appControlWindow.detailActionAvailable(actionIndex)
                        readonly property bool actionFavorite:
                            appControlWindow.isDetailActionFavorite(actionIndex)
                        readonly property bool starHovered:
                            runKittyActionFavoriteStarMouse.containsMouse

                        opacity: actionAvailable ? 1.0 : 0.34

                        GohuText {
                            id: runKittyActionFavoriteStarGlyph
                            anchors.centerIn: parent

                            text: runKittyActionFavoriteStar.actionFavorite ? "✦" : "✧"
                            font.pixelSize: 18

                            color:
                                runKittyActionFavoriteStarMouse.pressed
                                ? Colors.black
                                : runKittyActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : runKittyActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white
                        }

                        DropShadow {
                            anchors.fill: runKittyActionFavoriteStarGlyph
                            source: runKittyActionFavoriteStarGlyph

                            horizontalOffset: 0
                            verticalOffset: 0

                            radius:
                                runKittyActionFavoriteStar.actionFavorite
                                || runKittyActionFavoriteStar.starHovered
                                ? 9
                                : 5
                            samples: 7

                            opacity:
                                runKittyActionFavoriteStar.actionFavorite
                                ? 0.76
                                : runKittyActionFavoriteStar.starHovered
                                ? 0.52
                                : 0.14

                            color:
                                runKittyActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : runKittyActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white

                            transparentBorder: true
                        }

                        MouseArea {
                            id: runKittyActionFavoriteStarMouse
                            anchors.fill: parent
                            z: 100

                            enabled: runKittyActionFavoriteStar.actionAvailable
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            preventStealing: true
                            propagateComposedEvents: false

                            onPressed: function(mouse) {
                                mouse.accepted = true;
                            }

                            onClicked: function(mouse) {
                                mouse.accepted = true;

                                appControlWindow.keyboardActive = true;
                                appControlWindow.detailFocused = true;
                                appControlWindow.selectedDetailActionIndex =
                                    runKittyActionFavoriteStar.actionIndex;

                                appControlWindow.toggleDetailActionFavorite(
                                    runKittyActionFavoriteStar.actionIndex
                                );
                            }
                        }
                    }
}

                Rectangle {
                    id: runFloatAction

                    width: parent.width - 10
                    height: 34

                    anchors.horizontalCenter: parent.horizontalCenter

                    property bool isHovered:
                        !appControlWindow.keyboardActive
                        && runFloatActionMouse.containsMouse
                    property bool isPressed: runFloatActionMouse.pressed
                    property bool isSelected:
                        appControlWindow.detailFocused
                        && appControlWindow.selectedDetailActionIndex === 2

                    // Same alternate-action language as KITTY and desktop
                    // actions: orange frame/text, yellow selected, magenta
                    // pressed.
                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.black

                    border.width: 1
                    border.color:
                        isHovered || isSelected
                        ? Colors.orange
                        : Colors.white

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10

                        spacing: 8

                        GohuText {
                            id: runFloatActionIcon

                            anchors.verticalCenter: parent.verticalCenter

                            text: "⊹ ࣪ ˖🕊⋆₊⊹"
                            font.pixelSize: 14

                            color: runFloatAction.isPressed
                                   ? Colors.black
                                   : runFloatAction.isHovered
                                     || runFloatAction.isSelected
                                   ? Colors.orange
                                   : Colors.white

                            layer.enabled: !runFloatAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0

                                radius: 9
                                samples: 7

                                opacity:
                                    runFloatAction.isHovered
                                    || runFloatAction.isSelected
                                    ? 0.68
                                    : 0.50

                                color:
                                    runFloatAction.isHovered
                                    || runFloatAction.isSelected
                                    ? Colors.orange
                                    : Colors.cyan
                                transparentBorder: true
                            }
                        }

                        GohuText {
                            id: runFloatActionText

                            anchors.verticalCenter: parent.verticalCenter

                            text: "FLOAT"

                            font.pixelSize: 14
                            color: runFloatAction.isPressed
                                   ? Colors.black
                                   : runFloatAction.isHovered
                                     || runFloatAction.isSelected
                                   ? Colors.orange
                                   : Colors.white

                            layer.enabled: !runFloatAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0

                                radius: 11
                                samples: 9

                                opacity:
                                    runFloatAction.isHovered
                                    || runFloatAction.isSelected
                                    ? 0.78
                                    : 0.60

                                color:
                                    runFloatAction.isHovered
                                    || runFloatAction.isSelected
                                    ? Colors.orange
                                    : Colors.cyan
                                transparentBorder: true
                            }
                        }
                    }

                    DropShadow {
                        anchors.fill: runFloatActionText
                        source: runFloatActionText

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 12
                        samples: 9

                        opacity: runFloatAction.isPressed
                                 ? 0.0
                                 : runFloatAction.isHovered
                                   || runFloatAction.isSelected
                                 ? 0.82
                                 : 0.62

                        color:
                            runFloatAction.isHovered
                            || runFloatAction.isSelected
                            ? Colors.orange
                            : Colors.cyan
                        transparentBorder: true
                    }

                    MouseArea {
                        id: runFloatActionMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onEntered: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.selectedDetailActionIndex = 2;
                        }

                        onClicked: {
                            appControlWindow.selectedDetailActionIndex = 2;
                            appControlWindow.activateSelectedDetailAction();
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 5
                        z: -1

                        opacity: runFloatAction.isHovered
                                 || runFloatAction.isSelected
                                 ? 0.60
                                 : 0.26

                        color:
                            runFloatAction.isHovered
                            || runFloatAction.isSelected
                            ? Colors.orange
                            : Colors.cyan
                    }
                


                    Item {
                        id: runFloatActionFavoriteStar

                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter

                        width: 28
                        height: 28
                        z: 5000

                        readonly property int actionIndex: 2
                        readonly property bool actionAvailable:
                            (true)
                            && appControlWindow.detailActionAvailable(actionIndex)
                        readonly property bool actionFavorite:
                            appControlWindow.isDetailActionFavorite(actionIndex)
                        readonly property bool starHovered:
                            runFloatActionFavoriteStarMouse.containsMouse

                        opacity: actionAvailable ? 1.0 : 0.34

                        GohuText {
                            id: runFloatActionFavoriteStarGlyph
                            anchors.centerIn: parent

                            text: runFloatActionFavoriteStar.actionFavorite ? "✦" : "✧"
                            font.pixelSize: 18

                            color:
                                runFloatActionFavoriteStarMouse.pressed
                                ? Colors.black
                                : runFloatActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : runFloatActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white
                        }

                        DropShadow {
                            anchors.fill: runFloatActionFavoriteStarGlyph
                            source: runFloatActionFavoriteStarGlyph

                            horizontalOffset: 0
                            verticalOffset: 0

                            radius:
                                runFloatActionFavoriteStar.actionFavorite
                                || runFloatActionFavoriteStar.starHovered
                                ? 9
                                : 5
                            samples: 7

                            opacity:
                                runFloatActionFavoriteStar.actionFavorite
                                ? 0.76
                                : runFloatActionFavoriteStar.starHovered
                                ? 0.52
                                : 0.14

                            color:
                                runFloatActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : runFloatActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white

                            transparentBorder: true
                        }

                        MouseArea {
                            id: runFloatActionFavoriteStarMouse
                            anchors.fill: parent
                            z: 100

                            enabled: runFloatActionFavoriteStar.actionAvailable
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            preventStealing: true
                            propagateComposedEvents: false

                            onPressed: function(mouse) {
                                mouse.accepted = true;
                            }

                            onClicked: function(mouse) {
                                mouse.accepted = true;

                                appControlWindow.keyboardActive = true;
                                appControlWindow.detailFocused = true;
                                appControlWindow.selectedDetailActionIndex =
                                    runFloatActionFavoriteStar.actionIndex;

                                appControlWindow.toggleDetailActionFavorite(
                                    runFloatActionFavoriteStar.actionIndex
                                );
                            }
                        }
                    }
}

                Rectangle {
                    id: runFullscreenAction

                    width: parent.width - 10
                    height: 34

                    anchors.horizontalCenter: parent.horizontalCenter

                    property bool isHovered:
                        !appControlWindow.keyboardActive
                        && runFullscreenActionMouse.containsMouse
                    property bool isPressed: runFullscreenActionMouse.pressed
                    property bool isSelected:
                        appControlWindow.detailFocused
                        && appControlWindow.selectedDetailActionIndex === 3

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.black

                    border.width: 1
                    border.color:
                        isHovered || isSelected
                        ? Colors.orange
                        : Colors.omnitrix

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10

                        spacing: 8

                        GohuText {
                            id: runFullscreenActionIcon

                            anchors.verticalCenter: parent.verticalCenter

                            text: "🂡🂱🃑🂭🂽"
                            font.pixelSize: 16

                            color: runFullscreenAction.isPressed
                                   ? Colors.black
                                   : runFullscreenAction.isHovered
                                     || runFullscreenAction.isSelected
                                   ? Colors.orange
                                   : Colors.omnitrix

                            layer.enabled: !runFullscreenAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0

                                radius: 9
                                samples: 7

                                opacity:
                                    runFullscreenAction.isHovered
                                    || runFullscreenAction.isSelected
                                    ? 0.68
                                    : 0.50

                                color:
                                    runFullscreenAction.isHovered
                                    || runFullscreenAction.isSelected
                                    ? Colors.orange
                                    : Colors.omnitrix
                                transparentBorder: true
                            }
                        }

                        GohuText {
                            id: runFullscreenActionText

                            anchors.verticalCenter: parent.verticalCenter

                            text: "FULLSCREEN"

                            font.pixelSize: 14
                            color: runFullscreenAction.isPressed
                                   ? Colors.black
                                   : runFullscreenAction.isHovered
                                     || runFullscreenAction.isSelected
                                   ? Colors.orange
                                   : Colors.omnitrix

                            layer.enabled: !runFullscreenAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0

                                radius: 11
                                samples: 9

                                opacity:
                                    runFullscreenAction.isHovered
                                    || runFullscreenAction.isSelected
                                    ? 0.78
                                    : 0.60

                                color:
                                    runFullscreenAction.isHovered
                                    || runFullscreenAction.isSelected
                                    ? Colors.orange
                                    : Colors.omnitrix
                                transparentBorder: true
                            }
                        }
                    }

                    DropShadow {
                        anchors.fill: runFullscreenActionText
                        source: runFullscreenActionText

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 12
                        samples: 9

                        opacity: runFullscreenAction.isPressed
                                 ? 0.0
                                 : runFullscreenAction.isHovered
                                   || runFullscreenAction.isSelected
                                 ? 0.82
                                 : 0.62

                        color:
                            runFullscreenAction.isHovered
                            || runFullscreenAction.isSelected
                            ? Colors.orange
                            : Colors.omnitrix
                        transparentBorder: true
                    }

                    MouseArea {
                        id: runFullscreenActionMouse

                        anchors.fill: parent
                        hoverEnabled: true

                        onEntered: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.selectedDetailActionIndex = 3;
                        }

                        onClicked: {
                            appControlWindow.selectedDetailActionIndex = 3;
                            appControlWindow.activateSelectedDetailAction();
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 5
                        z: -1

                        opacity: runFullscreenAction.isHovered
                                 || runFullscreenAction.isSelected
                                 ? 0.60
                                 : 0.26

                        color:
                            runFullscreenAction.isHovered
                            || runFullscreenAction.isSelected
                            ? Colors.orange
                            : Colors.omnitrix
                    }
                


                    Item {
                        id: runFullscreenActionFavoriteStar

                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter

                        width: 28
                        height: 28
                        z: 5000

                        readonly property int actionIndex: 3
                        readonly property bool actionAvailable:
                            (true)
                            && appControlWindow.detailActionAvailable(actionIndex)
                        readonly property bool actionFavorite:
                            appControlWindow.isDetailActionFavorite(actionIndex)
                        readonly property bool starHovered:
                            runFullscreenActionFavoriteStarMouse.containsMouse

                        opacity: actionAvailable ? 1.0 : 0.34

                        GohuText {
                            id: runFullscreenActionFavoriteStarGlyph
                            anchors.centerIn: parent

                            text: runFullscreenActionFavoriteStar.actionFavorite ? "✦" : "✧"
                            font.pixelSize: 18

                            color:
                                runFullscreenActionFavoriteStarMouse.pressed
                                ? Colors.black
                                : runFullscreenActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : runFullscreenActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white
                        }

                        DropShadow {
                            anchors.fill: runFullscreenActionFavoriteStarGlyph
                            source: runFullscreenActionFavoriteStarGlyph

                            horizontalOffset: 0
                            verticalOffset: 0

                            radius:
                                runFullscreenActionFavoriteStar.actionFavorite
                                || runFullscreenActionFavoriteStar.starHovered
                                ? 9
                                : 5
                            samples: 7

                            opacity:
                                runFullscreenActionFavoriteStar.actionFavorite
                                ? 0.76
                                : runFullscreenActionFavoriteStar.starHovered
                                ? 0.52
                                : 0.14

                            color:
                                runFullscreenActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : runFullscreenActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white

                            transparentBorder: true
                        }

                        MouseArea {
                            id: runFullscreenActionFavoriteStarMouse
                            anchors.fill: parent
                            z: 100

                            enabled: runFullscreenActionFavoriteStar.actionAvailable
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            preventStealing: true
                            propagateComposedEvents: false

                            onPressed: function(mouse) {
                                mouse.accepted = true;
                            }

                            onClicked: function(mouse) {
                                mouse.accepted = true;

                                appControlWindow.keyboardActive = true;
                                appControlWindow.detailFocused = true;
                                appControlWindow.selectedDetailActionIndex =
                                    runFullscreenActionFavoriteStar.actionIndex;

                                appControlWindow.toggleDetailActionFavorite(
                                    runFullscreenActionFavoriteStar.actionIndex
                                );
                            }
                        }
                    }
}

                Rectangle {
                    id: runToolboxAction

                    width: parent.width - 10
                    height: 34
                    anchors.horizontalCenter: parent.horizontalCenter

                    property bool isHovered:
                        !appControlWindow.keyboardActive
                        && runToolboxActionMouse.containsMouse
                    property bool isPressed:
                        runToolboxActionMouse.pressed
                    property bool isSelected:
                        appControlWindow.detailFocused
                        && appControlWindow.selectedDetailActionIndex === 4
                    property bool canLaunch:
                        appControlWindow.detailActionAvailable(4)

                    color:
                        isPressed
                        ? Colors.magenta
                        : isHovered || isSelected
                        ? Colors.yellow
                        : Colors.black

                    opacity: canLaunch ? 1.0 : 0.48

                    border.width: 1
                    border.color: Colors.omnitrix
                    Row {
                        id: runToolboxActionContent
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Rectangle {
                            width: 22
                            height: 22
                            anchors.verticalCenter: parent.verticalCenter

                            color: Colors.black
                            border.width: 1
                            border.color: Colors.omnitrix

                            GohuText {
                                anchors.centerIn: parent
                                text: "🛠"
                                font.pixelSize: 13
                                color:
                                    runToolboxAction.isPressed
                                    ? Colors.black
                                    : Colors.omnitrix

                                layer.enabled: !runToolboxAction.isPressed
                                layer.effect: DropShadow {
                                    radius: 7
                                    samples: 7
                                    opacity: 0.58
                                    color: Colors.omnitrix
                                    transparentBorder: true
                                }
                            }
                        }

                        GohuText {
                            id: runToolboxActionText
                            anchors.verticalCenter: parent.verticalCenter
                            text: runToolboxAction.canLaunch
                                ? "TOOLBOX"
                                : "TOOLBOX  [UNAVAILABLE]"
                            font.pixelSize: 14
                            color:
                                runToolboxAction.isPressed
                                ? Colors.black
                                : Colors.omnitrix

                            layer.enabled: !runToolboxAction.isPressed
                            layer.effect: DropShadow {
                                radius: 8
                                samples: 7
                                opacity:
                                    runToolboxAction.isHovered
                                    || runToolboxAction.isSelected
                                    ? 0.66
                                    : 0.46
                                color: Colors.omnitrix
                                transparentBorder: true
                            }
                        }
                    }

MouseArea {
                        id: runToolboxActionMouse
                        anchors.fill: parent
                        enabled: runToolboxAction.canLaunch
                        hoverEnabled: true

                        onEntered: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.selectedDetailActionIndex = 4;
                        }

                        onClicked: {
                            appControlWindow.selectedDetailActionIndex = 4;
                            appControlWindow.activateSelectedDetailAction();
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        spread: 5
                        z: -1

                        opacity:
                            runToolboxAction.isHovered
                            || runToolboxAction.isSelected
                            ? 0.56
                            : 0.18

                        color: Colors.omnitrix
                    }

                    Item {
                        id: runToolboxActionFavoriteStar

                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter

                        width: 28
                        height: 28
                        z: 5000

                        readonly property int actionIndex: 4
                        readonly property bool actionAvailable:
                            runToolboxAction.canLaunch
                            && appControlWindow.detailActionAvailable(
                                   actionIndex
                               )
                        readonly property bool actionFavorite:
                            appControlWindow.isDetailActionFavorite(
                                actionIndex
                            )
                        readonly property bool starHovered:
                            runToolboxActionFavoriteStarMouse.containsMouse

                        opacity: actionAvailable ? 1.0 : 0.34

                        GohuText {
                            id: runToolboxActionFavoriteStarGlyph
                            anchors.centerIn: parent

                            text:
                                runToolboxActionFavoriteStar.actionFavorite
                                ? "✦"
                                : "✧"

                            font.pixelSize: 18

                            color:
                                runToolboxActionFavoriteStarMouse.pressed
                                ? Colors.black
                                : runToolboxActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : runToolboxActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white
                        }

                        DropShadow {
                            anchors.fill:
                                runToolboxActionFavoriteStarGlyph
                            source:
                                runToolboxActionFavoriteStarGlyph

                            horizontalOffset: 0
                            verticalOffset: 0

                            radius:
                                runToolboxActionFavoriteStar.actionFavorite
                                || runToolboxActionFavoriteStar.starHovered
                                ? 9
                                : 5
                            samples: 7

                            opacity:
                                runToolboxActionFavoriteStar.actionFavorite
                                ? 0.76
                                : runToolboxActionFavoriteStar.starHovered
                                ? 0.52
                                : 0.14

                            color:
                                runToolboxActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : runToolboxActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white

                            transparentBorder: true
                        }

                        MouseArea {
                            id: runToolboxActionFavoriteStarMouse
                            anchors.fill: parent
                            z: 100

                            enabled:
                                runToolboxActionFavoriteStar.actionAvailable
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            preventStealing: true
                            propagateComposedEvents: false

                            onPressed: function(mouse) {
                                mouse.accepted = true;
                            }

                            onClicked: function(mouse) {
                                mouse.accepted = true;

                                appControlWindow.keyboardActive = true;
                                appControlWindow.detailFocused = true;
                                appControlWindow.selectedDetailActionIndex =
                                    runToolboxActionFavoriteStar.actionIndex;

                                appControlWindow.toggleDetailActionFavorite(
                                    runToolboxActionFavoriteStar.actionIndex
                                );
                            }
                        }
                    }
                }


                // Slight visual break between launch variants and
                // destructive process control.
                Item {
                    width: 1
                    height: 8
                    visible: true
                }

                Item {
                    id: runTerminationActionsHeaderGlowBox

                    visible: true

                    width: runTerminationActionsHeaderText.implicitWidth + 24
                    height: runTerminationActionsHeaderText.implicitHeight + 16

                    layer.enabled: visible
                    layer.effect: DropShadow {
                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 5
                        samples: 5

                        opacity: 0.24
                        color: Colors.red

                        transparentBorder: true
                    }

                    GohuText {
                        id: runTerminationActionsHeaderText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        text: "TERMINATION ACTIONS"

                        font.pixelSize: 13
                        color: Colors.red
                        opacity: 0.82
                    }
                }

                Rectangle {
                    id: runKillAction

                    visible: true

                    width: parent.width - 10
                    height: 34

                    anchors.horizontalCenter: parent.horizontalCenter

                    property bool isHovered:
                        visible
                        && !appControlWindow.keyboardActive
                        && runKillActionMouse.containsMouse
                    property bool isPressed:
                        visible && runKillActionMouse.pressed
                    property bool isSelected:
                        visible
                        && appControlWindow.detailFocused
                        && appControlWindow.selectedDetailActionIndex === 5

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.black

                    opacity: appControlWindow.runKillAvailable ? 1.0 : 0.48

                    border.width: 1
                    border.color: Colors.red

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10

                        spacing: 8

                        Row {
                            id: runKillActionIcon

                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 0

                            GohuText {
                                id: runKillActionFace

                                anchors.verticalCenter: parent.verticalCenter

                                text:
                                    !appControlWindow.runKillAvailable
                                    ? "(•_•)"
                                    : runKillAction.isPressed
                                    ? "(=ᗜ=)"
                                    : runKillAction.isHovered
                                    ? "ദ്ദി(-_•)"
                                    : "(-_•)"

                                font.pixelSize: 14

                                color: runKillAction.isPressed
                                       ? Colors.black
                                       : Colors.red

                                layer.enabled: !runKillAction.isPressed
                                layer.effect: DropShadow {
                                    horizontalOffset: 0
                                    verticalOffset: 0

                                    radius: 10
                                    samples: 7

                                    opacity:
                                        runKillAction.isHovered
                                        || runKillAction.isSelected
                                        ? 0.82
                                        : 0.60

                                    color: Colors.red
                                    transparentBorder: true
                                }
                            }

                            GohuText {
                                id: runKillActionGun

                                anchors.verticalCenter: parent.verticalCenter

                                // Keep the gun isolated from the changing face
                                // so the combining marks shape identically in
                                // idle, hover, and selected states.
                                text: "デ╾━"

                                font.pixelSize: 14

                                color: runKillAction.isPressed
                                       ? Colors.black
                                       : Colors.red

                                layer.enabled: !runKillAction.isPressed
                                layer.effect: DropShadow {
                                    horizontalOffset: 0
                                    verticalOffset: 0

                                    radius: 10
                                    samples: 7

                                    opacity:
                                        runKillAction.isHovered
                                        || runKillAction.isSelected
                                        ? 0.82
                                        : 0.60

                                    color: Colors.red
                                    transparentBorder: true
                                }
                            }

                            GohuText {
                                id: runKillActionSpray

                                anchors.verticalCenter: parent.verticalCenter

                                text: runKillAction.isPressed
                                      ? " ๋࣭⭑"
                                      : ""

                                font.pixelSize: 14

                                color: runKillAction.isPressed
                                       ? Colors.black
                                       : Colors.red

                                layer.enabled: !runKillAction.isPressed
                                layer.effect: DropShadow {
                                    horizontalOffset: 0
                                    verticalOffset: 0

                                    radius: 10
                                    samples: 7

                                    opacity:
                                        runKillAction.isHovered
                                        || runKillAction.isSelected
                                        ? 0.82
                                        : 0.60

                                    color: Colors.red
                                    transparentBorder: true
                                }
                            }
                        }

                        GohuText {
                            id: runKillActionText

                            anchors.verticalCenter: parent.verticalCenter

                            text: appControlWindow.runKillAvailable
                                  ? "KILL"
                                  : "KILL  [NO TARGET]"

                            font.pixelSize: 14
                            color: runKillAction.isPressed
                                   ? Colors.black
                                   : Colors.red
                        }
                    }

                    DropShadow {
                        anchors.fill: runKillActionText
                        source: runKillActionText

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 7
                        samples: 5

                        opacity: runKillAction.isPressed
                                 ? 0.0
                                 : runKillAction.isHovered
                                   || runKillAction.isSelected
                                 ? 0.52
                                 : 0.34

                        color: Colors.red
                        transparentBorder: true
                    }

                    MouseArea {
                        id: runKillActionMouse

                        anchors.fill: parent
                        enabled: appControlWindow.runKillAvailable
                        hoverEnabled: true

                        onEntered: {
                            appControlWindow.keyboardActive = false;
                            appControlWindow.selectedDetailActionIndex = 5;
                        }

                        onClicked: {
                            appControlWindow.selectedDetailActionIndex = 5;
                            appControlWindow.activateSelectedDetailAction();
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent

                        spread: 5
                        z: -1

                        opacity: runKillAction.isHovered
                                 || runKillAction.isSelected
                                 ? 0.62
                                 : 0.22

                        color: Colors.red
                    }
                


                    Item {
                        id: runKillActionFavoriteStar

                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter

                        width: 28
                        height: 28
                        z: 5000

                        readonly property int actionIndex: 5
                        readonly property bool actionAvailable:
                            (appControlWindow.runKillAvailable)
                            && appControlWindow.detailActionAvailable(actionIndex)
                        readonly property bool actionFavorite:
                            appControlWindow.isDetailActionFavorite(actionIndex)
                        readonly property bool starHovered:
                            runKillActionFavoriteStarMouse.containsMouse

                        opacity: actionAvailable ? 1.0 : 0.34

                        GohuText {
                            id: runKillActionFavoriteStarGlyph
                            anchors.centerIn: parent

                            text: runKillActionFavoriteStar.actionFavorite ? "✦" : "✧"
                            font.pixelSize: 18

                            color:
                                runKillActionFavoriteStarMouse.pressed
                                ? Colors.black
                                : runKillActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : runKillActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white
                        }

                        DropShadow {
                            anchors.fill: runKillActionFavoriteStarGlyph
                            source: runKillActionFavoriteStarGlyph

                            horizontalOffset: 0
                            verticalOffset: 0

                            radius:
                                runKillActionFavoriteStar.actionFavorite
                                || runKillActionFavoriteStar.starHovered
                                ? 9
                                : 5
                            samples: 7

                            opacity:
                                runKillActionFavoriteStar.actionFavorite
                                ? 0.76
                                : runKillActionFavoriteStar.starHovered
                                ? 0.52
                                : 0.14

                            color:
                                runKillActionFavoriteStar.actionFavorite
                                ? Colors.magenta
                                : runKillActionFavoriteStar.starHovered
                                ? Colors.orange
                                : Colors.white

                            transparentBorder: true
                        }

                        MouseArea {
                            id: runKillActionFavoriteStarMouse
                            anchors.fill: parent
                            z: 100

                            enabled: runKillActionFavoriteStar.actionAvailable
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton
                            preventStealing: true
                            propagateComposedEvents: false

                            onPressed: function(mouse) {
                                mouse.accepted = true;
                            }

                            onClicked: function(mouse) {
                                mouse.accepted = true;

                                appControlWindow.keyboardActive = true;
                                appControlWindow.detailFocused = true;
                                appControlWindow.selectedDetailActionIndex =
                                    runKillActionFavoriteStar.actionIndex;

                                appControlWindow.toggleDetailActionFavorite(
                                    runKillActionFavoriteStar.actionIndex
                                );
                            }
                        }
                    }
}

                GridLayout {
                    width: parent.width

                    columns: 3
                    columnSpacing: 6
                    rowSpacing: 4

                    GohuText {
                        id: runShellLabel

                        Layout.preferredWidth: 76
                        text: "SHELL"
                        font.pixelSize: 13
                        color: Colors.orange

                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 5
                            samples: 5
                            opacity: 0.34
                            color: runShellLabel.color
                            transparentBorder: true
                        }
                    }

                    GohuText {
                        Layout.preferredWidth: 10
                        text: ":"
                        font.pixelSize: 13
                        color: Colors.white
                    }

                    GohuText {
                        id: runShellValue

                        Layout.fillWidth: true
                        text: appControlWindow.runShellName().toUpperCase()
                        font.pixelSize: 13
                        color: Colors.white
                        elide: Text.ElideRight

                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 5
                            samples: 5
                            opacity: 0.30
                            color: runShellValue.color
                            transparentBorder: true
                        }
                    }

                    GohuText {
                        id: runPrefixLabel

                        Layout.preferredWidth: 76
                        text: "PREFIX"
                        font.pixelSize: 13
                        color: Colors.orange

                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 5
                            samples: 5
                            opacity: 0.34
                            color: runPrefixLabel.color
                            transparentBorder: true
                        }
                    }

                    GohuText {
                        Layout.preferredWidth: 10
                        text: ":"
                        font.pixelSize: 13
                        color: Colors.white
                    }

                    GohuText {
                        id: runPrefixValue

                        Layout.fillWidth: true

                        property var runEntry: appControlWindow.selectedResult()
                        property var sourceEntry:
                            appControlWindow.favoriteSourceItem(runEntry)

                        text: appControlWindow.runPrefixName(
                                  appControlWindow.runPrefixModeForEntry(
                                      sourceEntry
                                  )
                              )

                        font.pixelSize: 13
                        color: text === "KITTY"
                               ? Colors.magenta
                               : Colors.cyan
                        elide: Text.ElideRight

                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 5
                            samples: 5
                            opacity: 0.34
                            color: runPrefixValue.color
                            transparentBorder: true
                        }
                    }

                    GohuText {
                        id: runListLabel

                        Layout.preferredWidth: 76
                        text: "LIST"
                        font.pixelSize: 13
                        color: Colors.orange

                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 5
                            samples: 5
                            opacity: 0.34
                            color: runListLabel.color
                            transparentBorder: true
                        }
                    }

                    GohuText {
                        Layout.preferredWidth: 10
                        text: ":"
                        font.pixelSize: 13
                        color: Colors.white
                    }

                    GohuText {
                        id: runListValue

                        Layout.fillWidth: true

                        text: appControlWindow.runListMode
                              === appControlWindow.runListAll
                              ? "SYSTEM"
                              : appControlWindow.runListMode
                                === appControlWindow.runListTerminal
                              ? "TERMINAL"
                              : "USER"

                        font.pixelSize: 13
                        color: text === "SYSTEM"
                               ? Colors.magenta
                               : text === "TERMINAL"
                               ? Colors.omnitrix
                               : Colors.cyan
                        elide: Text.ElideRight

                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 5
                            samples: 5
                            opacity: 0.34
                            color: runListValue.color
                            transparentBorder: true
                        }
                    }

                    GohuText {
                        id: runSourceLabel

                        Layout.preferredWidth: 76
                        text: "SOURCE"
                        font.pixelSize: 13
                        color: Colors.orange

                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 5
                            samples: 5
                            opacity: 0.34
                            color: runSourceLabel.color
                            transparentBorder: true
                        }
                    }

                    GohuText {
                        Layout.preferredWidth: 10
                        text: ":"
                        font.pixelSize: 13
                        color: Colors.white
                    }

                    GohuText {
                        id: runSourceValue

                        Layout.fillWidth: true

                        property var runEntry: appControlWindow.selectedResult()

                        text: runEntry && runEntry._runOrigin
                              ? String(runEntry._runOrigin)
                              : appControlWindow.selectedModeIndex
                                === appControlWindow.favoritesModeIndex
                              ? "FAVORITE"
                              : "COMMAND"

                        font.pixelSize: 13
                        color: Colors.magenta
                        elide: Text.ElideRight

                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 5
                            samples: 5
                            opacity: 0.34
                            color: runSourceValue.color
                            transparentBorder: true
                        }
                    }
                }
            }

                Item {
                    id: detailHintGlowBox

                    visible: appControlWindow.selectedResultSupportsDetail()

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

            color:
                appControlWindow.selectedModeIndex
                === appControlWindow.thermalModeIndex
                ? Colors.orange
                : appControlWindow.selectedModeIndex
                  === appControlWindow.killModeIndex
                ? Colors.red
                : Colors.cyan

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

                color:
                    appControlWindow.selectedModeIndex
                    === appControlWindow.thermalModeIndex
                    ? Colors.yellow
                    : appControlWindow.selectedModeIndex
                      === appControlWindow.killModeIndex
                    ? Colors.magenta
                    : Colors.magenta

                RectangularShadow {
                    anchors.fill: parent

                    spread: 2
                    z: -1

                    opacity: 0.16
                    color: detailScrollHandle.color
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
                }            }
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

            RectangularShadow {
                anchors.fill: parent
                spread: 3
                z: -1
                opacity: 0.38
                color: Colors.cyan
            }
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
               && appControlWindow.selectedResultSupportsDetail()
               ? Colors.magenta
               : Colors.orange

        z: 1002

        RectangularShadow {
            anchors.fill: parent
            spread: 3
            z: -1
            opacity: 0.38
            color: resultsDetailDivider.color
        }
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

        RectangularShadow {
            anchors.fill: parent
            spread: 3
            z: -1
            opacity: 0.38
            color: Colors.orange
        }
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
    // SHARED DESTRUCTIVE-ACTION CONFIRMATION
    // ============================================================

    Rectangle {
        id: destructiveConfirmOverlay
        anchors.fill: parent
        visible: appControlWindow.destructiveConfirmOpen
        color: Qt.rgba(
            Colors.dark.r, Colors.dark.g, Colors.dark.b, 0.88
        )
        z: 9000

        MouseArea {
            anchors.fill: parent
            // Consume all clicks behind the modal. Clicking outside does not
            // accidentally confirm a destructive action.
            onClicked: function(mouse) { mouse.accepted = true; }
        }

        Rectangle {
            id: destructiveConfirmDialog
            width: Math.min(470, parent.width - 80)
            height: 190
            anchors.centerIn: parent
            color: Colors.black
            border.width: 1
            border.color: Colors.red
            z: 1

            RectangularShadow {
                anchors.fill: parent
                spread: 12
                z: -1
                opacity: 0.58
                color: Colors.red
            }

            GohuText {
                id: destructiveConfirmTitleText
                anchors.top: parent.top
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.topMargin: 22
                text: appControlWindow.destructiveConfirmTitle
                font.pixelSize: 16
                color: Colors.red
            }

            DropShadow {
                anchors.fill: destructiveConfirmTitleText
                source: destructiveConfirmTitleText
                radius: 7
                samples: 7
                opacity: 0.58
                color: Colors.red
                transparentBorder: true
            }

            GohuText {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: destructiveConfirmTitleText.bottom
                anchors.leftMargin: 24
                anchors.rightMargin: 24
                anchors.topMargin: 18
                text: appControlWindow.destructiveConfirmMessage
                font.pixelSize: 10
                color: Colors.white
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                spacing: 18

                Repeater {
                    model: [
                        { key: "cancel", label: "CANCEL", accent: Colors.cyan, choice: 0 },
                        {
                            key: "confirm",
                            label: appControlWindow.destructiveConfirmActionLabel,
                            accent: Colors.red,
                            choice: 1
                        }
                    ]

                    Rectangle {
                        id: destructiveConfirmButton
                        required property var modelData
                        width: 150
                        height: 34
                        property bool isSelected:
                            appControlWindow.destructiveConfirmChoice
                            === modelData.choice
                        property bool isHovered: destructiveConfirmMouse.containsMouse
                        property bool isPressed: destructiveConfirmMouse.pressed

                        color: isPressed ? Colors.magenta
                               : isSelected || isHovered ? Colors.yellow
                               : Colors.dark
                        border.width: 1
                        border.color: modelData.accent

                        GohuText {
                            id: destructiveConfirmButtonText
                            anchors.centerIn: parent
                            text: destructiveConfirmButton.modelData.label
                            font.pixelSize: 11
                            color: destructiveConfirmButton.isPressed
                                   ? Colors.black
                                   : destructiveConfirmButton.modelData.accent
                        }

                        DropShadow {
                            anchors.fill: destructiveConfirmButtonText
                            source: destructiveConfirmButtonText
                            radius: 7
                            samples: 7
                            opacity: 0.56
                            color: destructiveConfirmButton.modelData.accent
                            transparentBorder: true
                        }

                        RectangularShadow {
                            anchors.fill: parent
                            spread: 4
                            z: -1
                            opacity:
                                destructiveConfirmButton.isSelected
                                || destructiveConfirmButton.isHovered
                                ? 0.52 : 0.28
                            color: destructiveConfirmButton.modelData.accent
                        }

                        MouseArea {
                            id: destructiveConfirmMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                appControlWindow.destructiveConfirmChoice =
                                    modelData.choice;
                                if (modelData.key === "cancel")
                                    appControlWindow.cancelDestructiveConfirm();
                                else
                                    appControlWindow.executeDestructiveConfirm();
                            }
                        }
                    }
                }
            }
        }
    }

    // ============================================================
    // KEYBOARD
    // ============================================================

    function handleKey(event) {
        keyboardActive = true;

        if (destructiveConfirmOpen) {
            if (event.key === Qt.Key_Escape) {
                cancelDestructiveConfirm();
            } else if (event.key === Qt.Key_Left
                       || event.key === Qt.Key_Right
                       || event.key === Qt.Key_Tab) {
                destructiveConfirmChoice =
                    destructiveConfirmChoice === 0 ? 1 : 0;
            } else if (event.key === Qt.Key_Return
                       || event.key === Qt.Key_Enter) {
                if (destructiveConfirmChoice === 0)
                    cancelDestructiveConfirm();
                else
                    executeDestructiveConfirm();
            }

            event.accepted = true;
            return;
        }

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
        if (selectedModeIndex === thermalModeIndex
                && !modeRailFocused
                && !detailFocused
                && event.key === Qt.Key_Tab
                && (event.modifiers & Qt.ControlModifier)) {
            setThermalViewMode(
                thermalViewMode === thermalViewThermal
                ? thermalViewFans
                : thermalViewThermal
            );

            event.accepted = true;
            return;
        }

        if (modeRailFocused
                && (event.key === Qt.Key_Tab
                    || event.key === Qt.Key_Backtab)) {
            const backwards =
                event.key === Qt.Key_Backtab
                || (event.modifiers & Qt.ShiftModifier);

            moveModeRailCursor(backwards ? -1 : 1);
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
            const backwards = event.key === Qt.Key_Backtab
                              || (event.modifiers & Qt.ShiftModifier);

            if (detailFocused && selectedResultSupportsDetail()) {
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

        if (modeRailFocused && event.key === Qt.Key_Up) {
            moveModeRailCursor(-1);
            event.accepted = true;
            return;
        }

        if (modeRailFocused && event.key === Qt.Key_Down) {
            moveModeRailCursor(1);
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

        if (modeRailFocused && event.key === Qt.Key_Right) {
            activateModeRailCursor();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Right) {
            if (!detailFocused && selectedResultSupportsDetail()) {
                detailFocused = true;
                resetDetailActionSelection();
            }

            event.accepted = true;
            return;
        }

        // FAVORITES quick selector:
        // Shift+Left cycles ALL -> APPS -> RUN -> WINDOWS -> THERMAL -> KILL -> SYSTEM.
        if (selectedModeIndex === favoritesModeIndex
                && event.key === Qt.Key_Left
                && (event.modifiers & Qt.ShiftModifier)) {
            cycleFavoritesFilter(1);
            event.accepted = true;
            return;
        }

        // APPS quick selectors:
        //
        //   Shift+Left -> NORMAL -> FLATPAK -> HIDDEN -> NORMAL
        //   Ctrl+Left  -> NORMAL <-> BOTTLES launch
        if (selectedModeIndex === appsModeIndex
                && event.key === Qt.Key_Left
                && (event.modifiers & Qt.ShiftModifier)) {
            if (appSourceMode === appSourceNative)
                setAppSourceMode(appSourceFlatpak);
            else if (appSourceMode === appSourceFlatpak)
                setAppSourceMode(appSourceHidden);
            else
                setAppSourceMode(appSourceNative);

            event.accepted = true;
            return;
        }

        if (selectedModeIndex === appsModeIndex
                && event.key === Qt.Key_Left
                && (event.modifiers & Qt.ControlModifier)) {
            if (appLaunchMode === appLaunchNormal)
                setAppLaunchMode(appLaunchBottle);
            else if (appLaunchMode === appLaunchBottle)
                setAppLaunchMode(appLaunchToolbox);
            else
                setAppLaunchMode(appLaunchNormal);

            event.accepted = true;
            return;
        }

        // THERMAL quick selector:
        //
        //   Shift+Left -> THERMAL <-> FANS
        if (selectedModeIndex === thermalModeIndex
                && event.key === Qt.Key_Left
                && (event.modifiers & Qt.ShiftModifier)) {
            setThermalViewMode(
                thermalViewMode === thermalViewThermal
                ? thermalViewFans
                : thermalViewThermal
            );

            event.accepted = true;
            return;
        }

        // WINDOWS quick selector:
        //
        //   Shift+Left -> WINDOWS <-> TABS
        if (selectedModeIndex === windowsModeIndex
                && event.key === Qt.Key_Left
                && (event.modifiers & Qt.ShiftModifier)) {
            setWindowListMode(
                windowListMode === windowListWindows
                ? windowListTabs
                : windowListWindows
            );

            event.accepted = true;
            return;
        }

        // RUN quick selectors:
        //
        //   Shift+Left -> USER -> TERMINAL -> SYSTEM -> USER
        //   Ctrl+Left  -> NORMAL -> KITTY -> TOOLBOX -> NORMAL
        if (selectedModeIndex === runModeIndex
                && event.key === Qt.Key_Left
                && (event.modifiers & Qt.ShiftModifier)) {
            if (runListMode === runListUser)
                setRunListMode(runListTerminal);
            else if (runListMode === runListTerminal)
                setRunListMode(runListAll);
            else
                setRunListMode(runListUser);

            event.accepted = true;
            return;
        }

        if (selectedModeIndex === runModeIndex
                && event.key === Qt.Key_Left
                && (event.modifiers & Qt.ControlModifier)) {
            if (runPrefixMode === runPrefixNormal)
                setRunPrefixMode(runPrefixKitty);
            else if (runPrefixMode === runPrefixKitty)
                setRunPrefixMode(runPrefixToolbox);
            else
                setRunPrefixMode(runPrefixNormal);

            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Left) {
            if (detailFocused) {
                detailFocused = false;
                resetDetailActionSelection();
                searchInput.forceActiveFocus();
            } else if (!modeRailFocused) {
                enterModeRail();
            }

            event.accepted = true;
            return;
        }

        if (modeRailFocused
                && (event.key === Qt.Key_Return
                    || event.key === Qt.Key_Enter)) {
            activateModeRailCursor();
            event.accepted = true;
            return;
        }

        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            if (detailFocused) {
                activateSelectedDetailAction();
            } else if (!activateFavoriteDetailActionFromSelector()) {
                // No saved control action: preserve the original selector
                // behavior (ordinary app launch / ordinary RUN execution).
                activateSelectedResult();
            }

            event.accepted = true;
            return;
        }
    }

    // ============================================================
    // MODE-SPECIFIC RESULT ACTIVATION
    // ============================================================

    function activateFavoriteDetailActionFromSelector() {
        // The preferred control action is a keyboard shortcut from the
        // selector itself. No trip into the control pane is required.
        //
        // FAVORITES is a mixed selector, so do NOT gate this on
        // selectedModeIndex. Instead resolve the selected row's real source
        // type. This lets favorite APP and RUN rows reuse the exact same
        // per-item preferred control action they have in their native menus.
        if (!selectedResultIsApplication()
                && !selectedResultIsRun())
            return false;

        const favoriteIndex = favoriteDetailActionIndex();

        if (favoriteIndex < 0
                || !detailActionAvailable(favoriteIndex))
            return false;

        selectedDetailActionIndex = favoriteIndex;

        console.log(
            "AppControl: selector Enter -> favorite detail action",
            favoriteIndex,
            detailFavoriteKeyFor(favoriteIndex),
            "source-mode",
            selectedControlModeIndex()
        );

        activateSelectedDetailAction();
        return true;
    }

    function activateSelectedResult() {
        activateResult(selectedResult(), selectedModeIndex);
    }

    // ============================================================
    // OPEN / FOCUS
    // ============================================================

    onMenuOpenChanged: {
        if (menuOpen) {
            appControlWindow.favoritesFaceClickPulse = false;
            appControlWindow.favoritesFaceBlinking = false;
            appControlWindow.favoritesFaceDoubleBlinkPending = false;

            appControlWindow.kittyFaceClickPulse = false;
            appControlWindow.kittyFaceBlinking = false;
            appControlWindow.kittyFaceDoubleBlinkPending = false;

            appControlWindow.hiddenFaceBlinking = false;
            appControlWindow.hiddenFaceDoubleBlinkPending = false;

            appControlWindow.appTabsDiagnosticsSignature = "";
            appControlWindow.destructiveConfirmOpen = false;
            appControlWindow.destructiveConfirmKind = "";
            appControlWindow.destructiveConfirmChoice = 0;
            appControlWindow.destructiveConfirmTargetPids = [];
            appControlWindow.killHogArmedPid = 0;

            // Force graph geometry to rebind after PanelWindow visibility
            // changes. The histories themselves stay intact across close/open.
            appControlWindow.taskMiniHistoryRevision += 1;
            if (taskCpuCanvas)
                taskCpuCanvas.requestPaint();
            if (taskMemCanvas)
                taskMemCanvas.requestPaint();

            appControlWindow.scheduleFavoritesFaceBlink();
            appControlWindow.scheduleKittyFaceBlink();
            appControlWindow.scheduleHiddenFaceBlink();

            // FAVORITES stays first in the rail, but opening the menu
            // always starts interaction on APPS. Preserve each mode's input
            // independently so an APPS search never becomes a RUN command.
            saveInputForMode(selectedModeIndex);
            selectedModeIndex = appsModeIndex;
            restoreInputForMode(selectedModeIndex);

            detailFocused = false;
            modeRailFocused = false;
            modeRailCursorIndex = appsModeIndex;
            modeRailHoveredIndex = -1;
            keyboardActive = false;
            hoveredResultIndex = -1;
            resetResultSelection();
            rememberCurrentAppSelection();
            resetDetailActionSelection();
            scheduleRunKillProbe();
            scheduleWindowAudioProbe();

            refreshWindowState();

            if (appControlWindow.bottleNames.length === 0)
                refreshBottleList();

            searchInput.forceActiveFocus();
        } else {
            favoritesFaceBlinkTimer.stop();
            favoritesFaceBlinkEndTimer.stop();
            favoritesFaceSecondBlinkGapTimer.stop();
            favoritesFaceSecondBlinkEndTimer.stop();
            favoritesFaceClickPulseTimer.stop();

            kittyFaceBlinkTimer.stop();
            kittyFaceBlinkEndTimer.stop();
            kittyFaceSecondBlinkGapTimer.stop();
            kittyFaceSecondBlinkEndTimer.stop();
            kittyFaceClickPulseTimer.stop();

            hiddenFaceBlinkTimer.stop();
            hiddenFaceBlinkEndTimer.stop();
            hiddenFaceSecondBlinkGapTimer.stop();
            hiddenFaceSecondBlinkEndTimer.stop();

            runKillProbeTimer.stop();
            runKillRefreshTimer.stop();
            windowActionRefreshTimer.stop();
            windowAudioProbeTimer.stop();
            windowAudioRefreshTimer.stop();

            appControlWindow.windowAudioAvailable = false;
            appControlWindow.windowAudioMuted = false;
            appControlWindow.windowAudioPolicyActive = false;
            appControlWindow.windowAudioSinkInputs = [];
            appControlWindow.windowAudioProbeWindowKey = "";

            appControlWindow.runKillAvailable = false;
            appControlWindow.runKillProbeTarget = "";
            appControlWindow.runKillResolvedTarget = "";
            appControlWindow.runKillPids = [];

            appControlWindow.destructiveConfirmOpen = false;
            appControlWindow.destructiveConfirmKind = "";
            appControlWindow.destructiveConfirmChoice = 0;
            appControlWindow.destructiveConfirmTargetPids = [];
            appControlWindow.killHogArmedPid = 0;
            killHogArmTimer.stop();

            appControlWindow.favoritesFaceClickPulse = false;
            appControlWindow.favoritesFaceBlinking = false;
            appControlWindow.favoritesFaceDoubleBlinkPending = false;

            appControlWindow.kittyFaceClickPulse = false;
            appControlWindow.kittyFaceBlinking = false;
            appControlWindow.kittyFaceDoubleBlinkPending = false;

            appControlWindow.hiddenFaceBlinking = false;
            appControlWindow.hiddenFaceDoubleBlinkPending = false;
        }
    }
}


