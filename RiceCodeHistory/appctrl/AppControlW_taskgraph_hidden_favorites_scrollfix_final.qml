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

        if (selectedModeIndex === killModeIndex
                && !taskRestoringSelection)
            resetTaskHistoryForSelection();
    }

    onSelectedModeIndexChanged: {
        scheduleRunKillProbe();
        scheduleWindowAudioProbe();
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

            if (!systemRebootArmed) {
                systemRebootArmed = true;
                systemRebootArmTimer.restart();
                return;
            }

            systemRebootArmed = false;
            Quickshell.execDetached([
                "systemctl",
                "reboot"
            ]);
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
        return "import json\nimport os\nimport re\nimport sys\n\npayload = json.loads(sys.argv[1] if len(sys.argv) > 1 else \"{}\")\naction = str(payload.get(\"action\") or \"\")\npwm_path = str(payload.get(\"pwmPath\") or \"\")\nenable_path = str(payload.get(\"pwmEnablePath\") or \"\")\n\ndef valid(path, suffix):\n    return bool(\n        re.match(r\"^/sys/class/hwmon/hwmon[0-9]+/\" + suffix + r\"$\", path)\n    )\n\nif not valid(pwm_path, r\"pwm[0-9]+\"):\n    raise SystemExit(\"invalid pwm path\")\n\nif not valid(enable_path, r\"pwm[0-9]+_enable\"):\n    raise SystemExit(\"invalid enable path\")\n\nif not (os.path.exists(pwm_path) and os.path.exists(enable_path)):\n    raise SystemExit(\"fan control files unavailable\")\n\nif not (os.access(pwm_path, os.W_OK) and os.access(enable_path, os.W_OK)):\n    raise SystemExit(\"fan control files are not writable by this user\")\n\ndef read_int(path, default):\n    try:\n        return int(open(path, \"r\", encoding=\"utf-8\").read().strip())\n    except Exception:\n        return default\n\ndef write_int(path, value):\n    with open(path, \"w\", encoding=\"utf-8\") as handle:\n        handle.write(str(int(value)))\n\ncurrent = max(0, min(255, read_int(pwm_path, 255)))\n\nif action == \"auto\":\n    # hwmon convention: 1 manual, 2 automatic/closed-loop on many drivers.\n    write_int(enable_path, 2)\nelif action == \"manual\":\n    # Enter manual mode at a conservative boosted duty rather than lowering it.\n    write_int(enable_path, 1)\n    write_int(pwm_path, max(current, 180))\nelif action == \"boost\":\n    write_int(enable_path, 1)\n    write_int(pwm_path, min(255, max(current, 180) + 26))\nelif action == \"max\":\n    write_int(enable_path, 1)\n    write_int(pwm_path, 255)\nelse:\n    raise SystemExit(\"unknown action\")\n";
    }

    function writeFanControl(entry, action) {
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
                pwmPath: String(entry.pwmPath || ""),
                pwmEnablePath: String(entry.pwmEnablePath || "")
            })
        ]);
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

        if (!entry || !entry._taskRecord)
            return null;

        return entry;
    }

    function selectedResultIsTask() {
        const entry = selectedResult();

        return selectedModeIndex === killModeIndex
               && !!entry
               && !!entry._taskRecord;
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

            cpuPercent = ((tickDelta / tickRate) / elapsedSeconds) * 100.0 / cores;
        } else {
            const task = selectedTask();
            cpuPercent = task ? Math.max(0, Math.min(100, Number(task.cpu || 0) / cores)) : 0;
        }

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
            && appControlWindow.selectedModeIndex === appControlWindow.killModeIndex
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
            "LC_ALL=C ps -eo "
            + "pid=,ppid=,user=,stat=,pcpu=,pmem=,rss=,vsz=,nlwp=,etime=,comm=,args= "
            + "--sort=-pcpu"
        ]);
    }

    function consumeTaskSnapshot(output) {
        const lines = String(output || "").split("\n");
        const rows = [];

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

            if (fields.length < 11)
                continue;

            const pid = Number(fields[0] || 0);

            if (!pid)
                continue;

            const args =
                fields.length > 11
                ? fields.slice(11).join(" ")
                : String(fields[10] || "");

            rows.push({
                _taskRecord: true,
                id: "task:" + String(pid),
                pid: pid,
                ppid: Number(fields[1] || 0),
                user: String(fields[2] || ""),
                state: String(fields[3] || ""),
                cpu: Number(fields[4] || 0),
                mem: Number(fields[5] || 0),
                rss: Number(fields[6] || 0),
                vsz: Number(fields[7] || 0),
                threads: Number(fields[8] || 0),
                elapsed: String(fields[9] || ""),
                comm: String(fields[10] || ""),
                args: args,
                name: String(fields[10] || "PROCESS"),
                label: String(fields[10] || "PROCESS")
            });
        }

        taskRows = rows;
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

        interval: 850
        repeat: true

        running:
            appControlWindow.menuOpen
            && appControlWindow.selectedModeIndex
               === appControlWindow.killModeIndex

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

        if (windowListMode === windowListTabs)
            refreshAppTabs();

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
    property bool appTabsLoading: false
    property string appTabsError: ""

    function appTabScanScript() {
        return "import json\nimport os\nimport subprocess\nimport urllib.request\n\ntabs = []\ndiagnostics = []\nseen = set()\n\ndef add_tab(item):\n    key = (\n        str(item.get(\"provider\", \"\")),\n        str(item.get(\"id\", \"\")),\n        str(item.get(\"tabTitle\", \"\")),\n        str(item.get(\"appName\", \"\"))\n    )\n    if key in seen:\n        return\n    seen.add(key)\n    tabs.append(item)\n\n# AT-SPI\ntry:\n    import gi\n    gi.require_version(\"Atspi\", \"2.0\")\n    from gi.repository import Atspi\n\n    try:\n        Atspi.init()\n    except Exception:\n        pass\n\n    desktop = Atspi.get_desktop(0)\n    visited = 0\n    max_nodes = 22000\n    max_depth = 30\n\n    def safe_name(obj):\n        try:\n            return str(obj.get_name() or \"\")\n        except Exception:\n            return \"\"\n\n    def safe_role(obj):\n        try:\n            return str(obj.get_role_name() or \"\").lower().replace(\"_\", \" \")\n        except Exception:\n            return \"\"\n\n    def selected_state(obj):\n        try:\n            states = obj.get_state_set()\n            return bool(\n                states.contains(Atspi.StateType.SELECTED)\n                or states.contains(Atspi.StateType.ACTIVE)\n                or states.contains(Atspi.StateType.FOCUSED)\n            )\n        except Exception:\n            return False\n\n    def walk(obj, path, app_name=\"\", window_name=\"\", tab_context=False, depth=0):\n        global visited\n\n        if obj is None or depth > max_depth or visited >= max_nodes:\n            return\n\n        visited += 1\n        role = safe_role(obj)\n        name = safe_name(obj)\n\n        if role == \"application\" and name:\n            app_name = name\n\n        if role in (\"frame\", \"window\", \"dialog\") and name:\n            window_name = name\n\n        is_tab_container = (\n            \"page tab list\" in role\n            or role == \"tab list\"\n            or \"tab bar\" in role\n            or \"tablist\" in role\n        )\n\n        is_tab = (\n            role == \"page tab\"\n            or role == \"tab\"\n            or role == \"document tab\"\n            or \"page tab\" in role\n            or \"document tab\" in role\n            or (\n                tab_context\n                and role in (\n                    \"radio button\",\n                    \"toggle button\",\n                    \"push button\",\n                    \"button\"\n                )\n            )\n        )\n\n        if is_tab and name:\n            add_tab({\n                \"_tabRecord\": True,\n                \"id\": \"atspi:\" + path,\n                \"path\": path,\n                \"name\": name,\n                \"tabTitle\": name,\n                \"appName\": app_name or \"APPLICATION\",\n                \"windowName\": window_name,\n                \"selected\": selected_state(obj),\n                \"provider\": \"AT-SPI\"\n            })\n\n        try:\n            count = int(obj.get_child_count())\n        except Exception:\n            count = 0\n\n        child_tab_context = tab_context or is_tab_container\n\n        for index in range(count):\n            if visited >= max_nodes:\n                break\n\n            try:\n                child = obj.get_child_at_index(index)\n            except Exception:\n                continue\n\n            child_path = str(index) if path == \"\" else path + \".\" + str(index)\n            walk(\n                child,\n                child_path,\n                app_name,\n                window_name,\n                child_tab_context,\n                depth + 1\n            )\n\n    walk(desktop, \"\")\n    diagnostics.append(\n        \"AT-SPI:%d\"\n        % sum(1 for item in tabs if item.get(\"provider\") == \"AT-SPI\")\n    )\nexcept Exception as exc:\n    diagnostics.append(\"AT-SPI ERROR:%s\" % exc)\n\n# Kitty remote control\nkitty_addresses = []\n\ntry:\n    for pid in os.listdir(\"/proc\"):\n        if not pid.isdigit():\n            continue\n\n        try:\n            env = open(\"/proc/%s/environ\" % pid, \"rb\").read().split(b\"\\0\")\n        except Exception:\n            continue\n\n        for item in env:\n            if item.startswith(b\"KITTY_LISTEN_ON=\"):\n                address = item.split(b\"=\", 1)[1].decode(\"utf-8\", \"ignore\").strip()\n                if address and address not in kitty_addresses:\n                    kitty_addresses.append(address)\nexcept Exception:\n    pass\n\nkitty_count = 0\n\nfor address in kitty_addresses:\n    try:\n        proc = subprocess.run(\n            [\"kitty\", \"@\", \"--to\", address, \"ls\"],\n            stdout=subprocess.PIPE,\n            stderr=subprocess.DEVNULL,\n            text=True,\n            timeout=1.5\n        )\n        if proc.returncode != 0 or not proc.stdout.strip():\n            continue\n\n        payload = json.loads(proc.stdout)\n\n        for os_window in payload if isinstance(payload, list) else []:\n            for tab in os_window.get(\"tabs\", []) or []:\n                tab_id = tab.get(\"id\")\n                title = str(tab.get(\"title\") or \"\").strip()\n\n                if not title:\n                    wins = tab.get(\"windows\", []) or []\n                    active = next((w for w in wins if w.get(\"is_active\")), None)\n                    active = active or (wins[0] if wins else {})\n                    title = str(\n                        active.get(\"title\")\n                        or active.get(\"cwd\")\n                        or (\"KITTY TAB \" + str(tab_id))\n                    )\n\n                add_tab({\n                    \"_tabRecord\": True,\n                    \"id\": \"kitty:\" + str(tab_id),\n                    \"path\": \"\",\n                    \"name\": title,\n                    \"tabTitle\": title,\n                    \"appName\": \"Kitty\",\n                    \"windowName\": str(os_window.get(\"id\") or \"\"),\n                    \"selected\": bool(tab.get(\"is_active\")),\n                    \"provider\": \"KITTY\",\n                    \"kittyAddress\": address,\n                    \"kittyTabId\": tab_id\n                })\n                kitty_count += 1\n    except Exception:\n        pass\n\ndiagnostics.append(\"KITTY:%d\" % kitty_count)\n\n# Chromium-family / Electron DevTools\nports = {}\n\ntry:\n    for pid in os.listdir(\"/proc\"):\n        if not pid.isdigit():\n            continue\n\n        try:\n            raw = open(\"/proc/%s/cmdline\" % pid, \"rb\").read()\n            argv = [\n                part.decode(\"utf-8\", \"ignore\")\n                for part in raw.split(b\"\\0\")\n                if part\n            ]\n        except Exception:\n            continue\n\n        if not argv:\n            continue\n\n        exe = os.path.basename(argv[0]).lower()\n        app_name = (\n            \"Brave\" if \"brave\" in exe\n            else \"Chrome\" if \"chrome\" in exe\n            else \"Chromium\" if \"chromium\" in exe\n            else \"VS Code\" if exe in (\"code\", \"code-oss\", \"codium\")\n            else \"Electron\" if \"electron\" in exe\n            else \"\"\n        )\n\n        if not app_name:\n            continue\n\n        port = None\n\n        for index, arg in enumerate(argv):\n            if arg.startswith(\"--remote-debugging-port=\"):\n                try:\n                    port = int(arg.split(\"=\", 1)[1])\n                except Exception:\n                    port = None\n                break\n\n            if arg == \"--remote-debugging-port\" and index + 1 < len(argv):\n                try:\n                    port = int(argv[index + 1])\n                except Exception:\n                    port = None\n                break\n\n        if port and port > 0:\n            ports[port] = app_name\nexcept Exception:\n    pass\n\ndevtools_count = 0\n\nfor port, app_name in ports.items():\n    try:\n        with urllib.request.urlopen(\n            \"http://127.0.0.1:%d/json/list\" % port,\n            timeout=0.8\n        ) as response:\n            targets = json.loads(response.read().decode(\"utf-8\", \"ignore\"))\n    except Exception:\n        continue\n\n    for target in targets:\n        if str(target.get(\"type\", \"\")).lower() not in (\"page\", \"webview\"):\n            continue\n\n        target_id = str(target.get(\"id\") or \"\").strip()\n        title = str(target.get(\"title\") or target.get(\"url\") or \"\").strip()\n\n        if not target_id or not title:\n            continue\n\n        add_tab({\n            \"_tabRecord\": True,\n            \"id\": \"devtools:%d:%s\" % (port, target_id),\n            \"path\": \"\",\n            \"name\": title,\n            \"tabTitle\": title,\n            \"appName\": app_name,\n            \"windowName\": str(target.get(\"url\") or \"\"),\n            \"selected\": False,\n            \"provider\": \"DEVTOOLS\",\n            \"debugPort\": port,\n            \"targetId\": target_id\n        })\n        devtools_count += 1\n\ndiagnostics.append(\"DEVTOOLS:%d\" % devtools_count)\n\nprint(json.dumps({\n    \"error\": \"\" if tabs else \" | \".join(diagnostics),\n    \"tabs\": tabs,\n    \"diagnostics\": diagnostics\n}))\n";
    }

    function appTabActivateScript() {
        return "import json\nimport subprocess\nimport sys\nimport urllib.request\n\nprovider = sys.argv[1] if len(sys.argv) > 1 else \"\"\npayload = sys.argv[2] if len(sys.argv) > 2 else \"\"\n\ntry:\n    data = json.loads(payload or \"{}\")\nexcept Exception:\n    data = {}\n\nacted = False\nerror = \"\"\n\ntry:\n    if provider == \"AT-SPI\":\n        import gi\n        gi.require_version(\"Atspi\", \"2.0\")\n        from gi.repository import Atspi\n\n        try:\n            Atspi.init()\n        except Exception:\n            pass\n\n        desktop = Atspi.get_desktop(0)\n        obj = desktop\n        path = str(data.get(\"path\") or \"\")\n\n        for piece in path.split(\".\"):\n            if piece:\n                obj = obj.get_child_at_index(int(piece))\n\n        try:\n            action = obj.get_action_iface()\n        except Exception:\n            action = None\n\n        if action is not None:\n            try:\n                count = int(action.get_n_actions())\n            except Exception:\n                count = 0\n\n            preferred = []\n\n            for index in range(count):\n                try:\n                    name = str(action.get_action_name(index) or \"\").lower()\n                except Exception:\n                    name = \"\"\n\n                if any(word in name for word in (\n                    \"activate\", \"click\", \"press\", \"select\", \"switch\"\n                )):\n                    preferred.append(index)\n\n            order = preferred + [\n                index for index in range(count)\n                if index not in preferred\n            ]\n\n            for index in order:\n                try:\n                    if action.do_action(index):\n                        acted = True\n                        break\n                except Exception:\n                    pass\n\n        if not acted:\n            try:\n                component = obj.get_component_iface()\n                if component is not None:\n                    acted = bool(component.grab_focus())\n            except Exception:\n                pass\n\n    elif provider == \"KITTY\":\n        address = str(data.get(\"kittyAddress\") or \"\")\n        tab_id = data.get(\"kittyTabId\")\n\n        cmd = [\"kitty\", \"@\"]\n        if address:\n            cmd += [\"--to\", address]\n\n        cmd += [\"focus-tab\", \"--match\", \"id:\" + str(tab_id)]\n\n        proc = subprocess.run(\n            cmd,\n            stdout=subprocess.DEVNULL,\n            stderr=subprocess.PIPE,\n            text=True,\n            timeout=2.0\n        )\n        acted = proc.returncode == 0\n\n        if not acted:\n            error = proc.stderr.strip()\n\n    elif provider == \"DEVTOOLS\":\n        port = int(data.get(\"debugPort\") or 0)\n        target_id = str(data.get(\"targetId\") or \"\")\n\n        req = urllib.request.Request(\n            \"http://127.0.0.1:%d/json/activate/%s\" % (port, target_id),\n            method=\"PUT\"\n        )\n\n        with urllib.request.urlopen(req, timeout=1.0) as response:\n            response.read()\n\n        acted = True\n\nexcept Exception as exc:\n    error = str(exc)\n\nprint(json.dumps({\"ok\": acted, \"error\": error}))\n";
    }

    function refreshAppTabs() {
        if (appTabsLoading)
            return;

        appTabsLoading = true;
        appTabsError = "";

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
                    appControlWindow.appTabs =
                        Array.isArray(payload.tabs)
                        ? payload.tabs
                        : [];
                    appControlWindow.appTabsError =
                        String(payload.error || "");
                } catch (error) {
                    appControlWindow.appTabs = [];
                    appControlWindow.appTabsError =
                        "TAB SCAN PARSE: " + String(error);
                }

                appControlWindow.appTabsLoading = false;

                if (appControlWindow.selectedModeIndex
                        === appControlWindow.windowsModeIndex
                        && appControlWindow.windowListMode
                           === appControlWindow.windowListTabs) {
                    Qt.callLater(function() {
                        appControlWindow.resetResultSelection();
                        appControlWindow.resetDetailActionSelection();
                    });
                }
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
        id: appTabsRefreshTimer

        interval: 1400
        repeat: true

        running:
            appControlWindow.menuOpen
            && appControlWindow.selectedModeIndex
               === appControlWindow.windowsModeIndex
            && appControlWindow.windowListMode
               === appControlWindow.windowListTabs

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
        return resultSourceMode(entry, modeIndex) === windowsModeIndex
               && !!entry
               && !!entry._tabRecord;
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

    function selectedResultSupportsDetail() {
        return selectedResultIsApplication()
               || selectedResultIsRun()
               || selectedResultIsWindow()
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

        // WINDOWS/KILL are still placeholders. Include the mode index so
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

        if (tokens[0] === "__APPCONTROL_SHELL__") {
            let commandText = String(tokens[1] || "");

            if (commandText.indexOf("--force-renderer-accessibility") === -1)
                commandText += " " + accessibilityFlag;

            console.log(
                "AppControl: launching with accessibility tab provider:",
                entry.name
            );

            Quickshell.execDetached([
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

        console.log(
            "AppControl: launching with accessibility tab provider:",
            entry.name
        );

        Quickshell.execDetached(command);
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

                if (tabRows.length === 0) {
                    tabRows = [{
                        _tabRecord: true,
                        _tabUnavailable: true,
                        id: "tab-status",
                        path: "",
                        name:
                            appControlWindow.appTabsLoading
                            ? "SCANNING TABS..."
                            : appControlWindow.appTabsError.length > 0
                            ? "REOPEN TAB APPS"
                            : "NO TABS FOUND",
                        tabTitle:
                            appControlWindow.appTabsLoading
                            ? "SCANNING TABS..."
                            : appControlWindow.appTabsError.length > 0
                            ? "REOPEN TAB APPS"
                            : "NO TABS FOUND",
                        appName:
                            appControlWindow.appTabsError.length > 0
                            ? "BRAVE / CODE / KITTY VIA APPCONTROL • "
                              + appControlWindow.appTabsError
                            : "AT-SPI / KITTY / DEVTOOLS",
                        windowName: "",
                        selected: false,
                        provider: "AT-SPI"
                    }];
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
            const thermalSnapshot = appControlWindow.thermalRows;
            const fanSnapshot = appControlWindow.fanRows;
            const systemSnapshot = appControlWindow.systemRows;
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

            const visibleRows = rows.filter(function(entry) {
                if (query.length === 0) return true;
                const haystack = ((entry.name || "") + " " + (entry.genericName || "") + " " + (entry.comment || "")).toLowerCase();
                return haystack.indexOf(query) !== -1;
            });

            visibleRows.sort(function(a, b) {
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

        if (selectedModeIndex === killModeIndex)
            refreshTaskManager();

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
            if (actionIndex === 4)
                return runKillAvailable;

            return actionIndex >= 0 && actionIndex < 4;
        }

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
            return 5;

        if (selectedResultIsWindow())
            return 7;

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
            return "TOGGLE FULLSCREEN";

        if (actionIndex === 4)
            return "TOGGLE CENTER";

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
            return "🂡🂱🃑🂭🂽";

        if (actionIndex === 4)
            return "🃁🂡🂱🃑";

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
            toggleSwayWindowFullscreen(entry);
            return;
        }

        if (actionIndex === 4) {
            centerSwayWindow(entry);
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

                                color: modeButton.isPressed
                                       ? Colors.black
                                       : modeButton.isHovered
                                         || modeButton.isRailCursor
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
                    appControlWindow.selectedModeIndex
                    === appControlWindow.killModeIndex
                    || appControlWindow.selectedModeIndex
                       === appControlWindow.thermalModeIndex
                    || appControlWindow.selectedModeIndex
                       === appControlWindow.systemModeIndex
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

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right

                    anchors.leftMargin: 14
                    anchors.rightMargin: 38

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

                        visible:
                            ((appControlWindow.resultIsApplication(
                                  modelData,
                                  appControlWindow.selectedModeIndex
                              )
                              || appControlWindow.resultIsWindow(
                                  modelData,
                                  appControlWindow.selectedModeIndex
                              ))
                             && (selectorAppIcon.source.toString().length > 0
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

                            source:
                                appControlWindow.resultIsApplication(
                                    modelData,
                                    appControlWindow.selectedModeIndex
                                )
                                ? appControlWindow.appIconSource(modelData)
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
                            id: selectorHiddenFallbackGlyph
                            anchors.centerIn: parent
                            visible: selectorAppIconBox.sourceItem && selectorAppIconBox.sourceItem._hiddenCommand && selectorAppIcon.status !== Image.Ready
                            text: "-⋆♱⋆-"
                            font.pixelSize: 10
                            color: resultButton.isPressed ? Colors.black : resultButton.isHovered || resultButton.isSelected ? Colors.orange : Colors.cyan
                            layer.enabled: !resultButton.isPressed
                            layer.effect: DropShadow { radius: 6; samples: 5; opacity: 0.46; color: resultButton.isHovered || resultButton.isSelected ? Colors.orange : Colors.cyan; transparentBorder: true }
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
                                  + Number(modelData.cpu || 0).toFixed(1)
                                  + "% • MEM "
                                  + Number(modelData.mem || 0).toFixed(1)
                                  + "% • PID "
                                  + String(modelData.pid || "?")
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
                                : Number(modelData.cpu || 0) >= 25
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
                        && appControlWindow.selectedModeIndex
                           !== appControlWindow.killModeIndex

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

                    readonly property bool appColorReady:
                        monitorColorReady
                        || !selectorAppIconBox.visible
                        || resolvedAppGlow !== null

                    readonly property color appStarColor:
                        sourceMode === appControlWindow.thermalModeIndex
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

                        color: favoriteStarButton.favorite
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

                        color: favoriteStarButton.favorite
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

                    property bool isSelected:
                        appControlWindow.thermalViewMode
                        === appControlWindow.thermalViewThermal
                    property bool isHovered:
                        thermalViewThermalMouse.containsMouse
                    property bool isPressed:
                        thermalViewThermalMouse.pressed

                    color:
                        isPressed
                        ? Colors.magenta
                        : isHovered || isSelected
                        ? Colors.yellow
                        : Colors.dark

                    border.width: 1
                    border.color:
                        isHovered || isSelected
                        ? Colors.orange
                        : Colors.orange

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        GohuText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "🌡"
                            font.pixelSize: 15
                            color:
                                thermalViewThermalButton.isPressed
                                ? Colors.black
                                : thermalViewThermalButton.isHovered
                                ? Colors.orange
                                : thermalViewThermalButton.isSelected
                                ? Colors.magenta
                                : Colors.orange

                            layer.enabled: !thermalViewThermalButton.isPressed
                            layer.effect: DropShadow {
                                radius: 8
                                samples: 7
                                opacity:
                                    thermalViewThermalButton.isHovered
                                    || thermalViewThermalButton.isSelected
                                    ? 0.56
                                    : 0.38
                                color: Colors.orange
                                transparentBorder: true
                            }
                        }

                        GohuText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "THERMAL"
                            font.pixelSize: 13

                            color:
                                thermalViewThermalButton.isPressed
                                ? Colors.black
                                : thermalViewThermalButton.isHovered
                                ? Colors.orange
                                : thermalViewThermalButton.isSelected
                                ? Colors.magenta
                                : Colors.orange

                            layer.enabled: !thermalViewThermalButton.isPressed
                            layer.effect: DropShadow {
                                radius: 8
                                samples: 7
                                opacity:
                                    thermalViewThermalButton.isHovered
                                    || thermalViewThermalButton.isSelected
                                    ? 0.56
                                    : 0.38
                                color: Colors.orange
                                transparentBorder: true
                            }
                        }
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
                            ? 0.46
                            : 0.22
                        color: Colors.orange
                    }
                }

                Rectangle {
                    id: thermalViewFansButton

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height

                    property bool isSelected:
                        appControlWindow.thermalViewMode
                        === appControlWindow.thermalViewFans
                    property bool isHovered:
                        thermalViewFansMouse.containsMouse
                    property bool isPressed:
                        thermalViewFansMouse.pressed

                    color:
                        isPressed
                        ? Colors.magenta
                        : isHovered || isSelected
                        ? Colors.yellow
                        : Colors.dark

                    border.width: 1
                    border.color:
                        isHovered || isSelected
                        ? Colors.orange
                        : Colors.omnitrix

                    Row {
                        anchors.centerIn: parent
                        spacing: 6

                        Rectangle {
                            width: 20
                            height: 20
                            anchors.verticalCenter: parent.verticalCenter

                            color: Colors.black
                            border.width: 1
                            border.color:
                                thermalViewFansButton.isHovered
                                || thermalViewFansButton.isSelected
                                ? Colors.orange
                                : Colors.omnitrix

                            GohuText {
                                anchors.centerIn: parent
                                text: "✇"
                                font.pixelSize: 14

                                color:
                                    thermalViewFansButton.isPressed
                                    ? Colors.black
                                    : thermalViewFansButton.isHovered
                                    ? Colors.orange
                                    : thermalViewFansButton.isSelected
                                    ? Colors.magenta
                                    : Colors.omnitrix

                                layer.enabled: !thermalViewFansButton.isPressed
                                layer.effect: DropShadow {
                                    radius: 8
                                    samples: 7
                                    opacity:
                                        thermalViewFansButton.isHovered
                                        || thermalViewFansButton.isSelected
                                        ? 0.56
                                        : 0.24
                                    color: Colors.omnitrix
                                    transparentBorder: true
                                }
                            }
                        }

                        GohuText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "FANS"
                            font.pixelSize: 13

                            color:
                                thermalViewFansButton.isPressed
                                ? Colors.black
                                : thermalViewFansButton.isHovered
                                ? Colors.orange
                                : thermalViewFansButton.isSelected
                                ? Colors.magenta
                                : Colors.omnitrix

                            layer.enabled: !thermalViewFansButton.isPressed
                            layer.effect: DropShadow {
                                radius: 8
                                samples: 7
                                opacity:
                                    thermalViewFansButton.isHovered
                                    || thermalViewFansButton.isSelected
                                    ? 0.56
                                    : 0.38
                                color: Colors.omnitrix
                                transparentBorder: true
                            }
                        }
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
                            ? 0.46
                            : 0.22
                        color: Colors.omnitrix
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

                    property bool isSelected:
                        appControlWindow.windowListMode
                        === appControlWindow.windowListWindows
                    property bool isHovered:
                        windowListWindowsMouse.containsMouse
                    property bool isPressed:
                        windowListWindowsMouse.pressed

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
                        id: windowListWindowsText

                        anchors.centerIn: parent

                        text: "WINDOWS"
                        font.pixelSize: 14

                        color: windowListWindowsButton.isPressed
                               ? Colors.black
                               : windowListWindowsButton.isHovered
                               ? Colors.orange
                               : windowListWindowsButton.isSelected
                               ? Colors.magenta
                               : Colors.cyan

                        layer.enabled: !windowListWindowsButton.isPressed
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 8
                            samples: 7
                            opacity:
                                windowListWindowsButton.isHovered
                                || windowListWindowsButton.isSelected
                                ? 0.56
                                : 0.38
                            color: Colors.cyan
                            transparentBorder: true
                        }
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
                            ? 0.46
                            : 0.22

                        color: Colors.cyan
                    }
                }

                Rectangle {
                    id: windowListTabsButton

                    width: (parent.width - parent.spacing) / 2
                    height: parent.height

                    property bool isSelected:
                        appControlWindow.windowListMode
                        === appControlWindow.windowListTabs
                    property bool isHovered:
                        windowListTabsMouse.containsMouse
                    property bool isPressed:
                        windowListTabsMouse.pressed

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: isHovered || isSelected
                                  ? Colors.orange
                                  : Colors.magenta

                    GohuText {
                        id: windowListTabsText

                        anchors.centerIn: parent

                        text: "TABS"
                        font.pixelSize: 14

                        color: windowListTabsButton.isPressed
                               ? Colors.black
                               : windowListTabsButton.isHovered
                               ? Colors.orange
                               : windowListTabsButton.isSelected
                               ? Colors.magenta
                               : Colors.magenta

                        layer.enabled: !windowListTabsButton.isPressed
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 8
                            samples: 7
                            opacity:
                                windowListTabsButton.isHovered
                                || windowListTabsButton.isSelected
                                ? 0.56
                                : 0.38
                            color: Colors.magenta
                            transparentBorder: true
                        }
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
                            ? 0.46
                            : 0.22

                        color: Colors.magenta
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
                            label: "NORMAL",
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

                        property bool isSelected:
                            appControlWindow.appSourceMode
                            === modelData.mode
                        property bool isHovered:
                            appSourceModeMouse.containsMouse
                        property bool isPressed:
                            appSourceModeMouse.pressed

                        color:
                            isPressed
                            ? Colors.magenta
                            : isHovered || isSelected
                            ? Colors.yellow
                            : Colors.dark

                        border.width: 1
                        border.color:
                            isHovered || isSelected
                            ? Colors.orange
                            : modelData.accent

                        GohuText {
                            anchors.centerIn: parent

                            text: modelData.label
                            font.pixelSize:
                                modelData.mode
                                === appControlWindow.appSourceFlatpak
                                ? 10
                                : 14

                            horizontalAlignment: Text.AlignHCenter
                            lineHeight: 0.88

                            color:
                                appSourceModeButton.isPressed
                                ? Colors.black
                                : appSourceModeButton.isHovered
                                ? Colors.orange
                                : appSourceModeButton.isSelected
                                ? Colors.magenta
                                : modelData.accent

                            layer.enabled: !appSourceModeButton.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0
                                radius: 8
                                samples: 7
                                opacity:
                                    appSourceModeButton.isHovered
                                    || appSourceModeButton.isSelected
                                    ? 0.56
                                    : 0.38
                                color: modelData.accent
                                transparentBorder: true
                            }
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
                                ? 0.46
                                : 0.22
                            color: modelData.accent
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

                    property bool isSelected:
                        appControlWindow.runListMode
                        === appControlWindow.runListUser
                    property bool isHovered: runListUserMouse.containsMouse
                    property bool isPressed: runListUserMouse.pressed

                    color: isPressed
                           ? Colors.magenta
                           : isHovered
                           ? Colors.yellow
                           : isSelected
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: isSelected || isHovered
                                  ? Colors.orange
                                  : Colors.cyan

                    GohuText {
                        id: runListUserText

                        anchors.centerIn: parent

                        text: "USER"

                        font.pixelSize: 15

                        color: runListUserButton.isPressed
                               ? Colors.black
                               : runListUserButton.isHovered
                               ? Colors.orange
                               : runListUserButton.isSelected
                               ? Colors.magenta
                               : Colors.cyan
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
                                 ? 0.56
                                 : 0.38

                        color: Colors.cyan

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
                                 ? 0.46
                                 : 0.22

                        color: Colors.cyan
                    }
                }

                Rectangle {
                    id: runListTerminalButton

                    width: (parent.width - (parent.spacing * 2)) / 3
                    height: parent.height

                    property bool isSelected:
                        appControlWindow.runListMode
                        === appControlWindow.runListTerminal
                    property bool isHovered:
                        runListTerminalMouse.containsMouse
                    property bool isPressed:
                        runListTerminalMouse.pressed

                    color: isPressed
                           ? Colors.magenta
                           : isHovered
                           ? Colors.yellow
                           : isSelected
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: isSelected || isHovered
                                  ? Colors.orange
                                  : Colors.magenta

                    GohuText {
                        id: runListTerminalText

                        anchors.centerIn: parent

                        text: appControlWindow.runTerminalHistoryLoading
                              ? "TERMINAL ..."
                              : "TERMINAL"

                        font.pixelSize: 13

                        color: runListTerminalButton.isPressed
                               ? Colors.black
                               : runListTerminalButton.isHovered
                               ? Colors.orange
                               : runListTerminalButton.isSelected
                               ? Colors.magenta
                               : Colors.magenta
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
                                 ? 0.56
                                 : 0.38

                        color: Colors.magenta

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
                                 ? 0.46
                                 : 0.22

                        color: Colors.magenta
                    }
                }

                Rectangle {
                    id: runListAllButton

                    width: (parent.width - (parent.spacing * 2)) / 3
                    height: parent.height

                    property bool isSelected:
                        appControlWindow.runListMode
                        === appControlWindow.runListAll
                    property bool isHovered: runListAllMouse.containsMouse
                    property bool isPressed: runListAllMouse.pressed

                    color: isPressed
                           ? Colors.magenta
                           : isHovered
                           ? Colors.yellow
                           : isSelected
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: isSelected || isHovered
                                  ? Colors.orange
                                  : Colors.omnitrix

                    GohuText {
                        id: runListAllText

                        anchors.centerIn: parent

                        text: appControlWindow.runAllCommandsLoading
                              ? "SYSTEM ..."
                              : "SYSTEM"

                        font.pixelSize: 15

                        color: runListAllButton.isPressed
                               ? Colors.black
                               : runListAllButton.isHovered
                               ? Colors.orange
                               : runListAllButton.isSelected
                               ? Colors.magenta
                               : Colors.omnitrix
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
                                 ? 0.56
                                 : 0.38

                        color: Colors.omnitrix

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
                                 ? 0.46
                                 : 0.22

                        color: Colors.omnitrix
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

                    property bool isSelected:
                        appControlWindow.appLaunchMode
                        === appControlWindow.appLaunchNormal
                    property bool isHovered:
                        appLaunchNormalMouse.containsMouse
                    property bool isPressed:
                        appLaunchNormalMouse.pressed

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
                        anchors.centerIn: parent

                        text: "NORMAL"
                        font.pixelSize: 14

                        color: appLaunchNormalButton.isPressed
                               ? Colors.black
                               : appLaunchNormalButton.isHovered
                               ? Colors.orange
                               : appLaunchNormalButton.isSelected
                               ? Colors.magenta
                               : Colors.cyan
                    

                        layer.enabled: !appLaunchNormalButton.isPressed
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0

                            radius: 8
                            samples: 7

                            opacity:
                                appLaunchNormalButton.isHovered
                                || appLaunchNormalButton.isSelected
                                ? 0.56
                                : 0.38

                            // Orange halo even when selected text itself is
                            // magenta.
                            color: Colors.orange
                            transparentBorder: true
                        }
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
                            ? 0.46
                            : 0.22

                        color: Colors.orange
                    }
}

                Rectangle {
                    id: appLaunchBottleButton

                    width: (parent.width - (parent.spacing * 2)) / 3
                    height: parent.height

                    property bool isSelected:
                        appControlWindow.appLaunchMode
                        === appControlWindow.appLaunchBottle
                    property bool isHovered:
                        appLaunchBottleMouse.containsMouse
                    property bool isPressed:
                        appLaunchBottleMouse.pressed

                    opacity:
                        appControlWindow.bottlesLoading
                        || !appControlWindow.selectedBottleName
                        ? 0.48
                        : 1.0

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: isHovered || isSelected
                                  ? Colors.orange
                                  : Colors.magenta

                    GohuText {
                        anchors.centerIn: parent

                        text:
                            appControlWindow.bottlesLoading
                            ? "BOTTLES ..."
                            : "BOTTLES"

                        font.pixelSize: 14

                        color: appLaunchBottleButton.isPressed
                               ? Colors.black
                               : appLaunchBottleButton.isHovered
                               ? Colors.orange
                               : appLaunchBottleButton.isSelected
                               ? Colors.magenta
                               : Colors.magenta
                    

                        layer.enabled: !appLaunchBottleButton.isPressed
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0

                            radius: 8
                            samples: 7

                            opacity:
                                appLaunchBottleButton.isHovered
                                || appLaunchBottleButton.isSelected
                                ? 0.56
                                : 0.38

                            // Orange halo even when selected text itself is
                            // magenta.
                            color: Colors.orange
                            transparentBorder: true
                        }
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
                            ? 0.46
                            : 0.22

                        color: Colors.orange
                    }
}


                Rectangle {
                    id: appLaunchToolboxButton

                    width: (parent.width - (parent.spacing * 2)) / 3
                    height: parent.height

                    property bool isSelected:
                        appControlWindow.appLaunchMode
                        === appControlWindow.appLaunchToolbox
                    property bool isHovered:
                        appLaunchToolboxMouse.containsMouse
                    property bool isPressed:
                        appLaunchToolboxMouse.pressed

                    color: isPressed
                           ? Colors.magenta
                           : isHovered || isSelected
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: isHovered || isSelected
                                  ? Colors.orange
                                  : Colors.omnitrix

                    GohuText {
                        id: appLaunchToolboxText

                        anchors.centerIn: parent

                        text: "TOOLBOX"
                        font.pixelSize: 13

                        color: appLaunchToolboxButton.isPressed
                               ? Colors.black
                               : appLaunchToolboxButton.isHovered
                               ? Colors.orange
                               : appLaunchToolboxButton.isSelected
                               ? Colors.magenta
                               : Colors.omnitrix

                        layer.enabled: !appLaunchToolboxButton.isPressed
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0

                            radius: 8
                            samples: 7

                            opacity:
                                appLaunchToolboxButton.isHovered
                                || appLaunchToolboxButton.isSelected
                                ? 0.62
                                : 0.38

                            color: Colors.omnitrix
                            transparentBorder: true
                        }
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
                            ? 0.46
                            : 0.22

                        color: Colors.orange
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

                    property bool isSelected:
                        appControlWindow.runPrefixMode
                        === appControlWindow.runPrefixNormal
                    property bool isHovered: runPrefixNormalMouse.containsMouse
                    property bool isPressed: runPrefixNormalMouse.pressed

                    color: isPressed
                           ? Colors.magenta
                           : isHovered
                           ? Colors.yellow
                           : isSelected
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: isSelected || isHovered
                                  ? Colors.orange
                                  : Colors.cyan

                    GohuText {
                        id: runPrefixNormalIcon

                        anchors.centerIn: parent

                        text: appControlWindow.modes[
                                  appControlWindow.runModeIndex
                              ].symbol

                        font.pixelSize: 16

                        color: runPrefixNormalButton.isPressed
                               ? Colors.black
                               : runPrefixNormalButton.isHovered
                               ? Colors.orange
                               : runPrefixNormalButton.isSelected
                               ? Colors.magenta
                               : Colors.cyan
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
                                 ? 0.58
                                 : 0.24

                        color: Colors.orange

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
                                 ? 0.48
                                 : 0.14

                        color: Colors.orange
                    }
                }

                Rectangle {
                    id: runPrefixKittyButton

                    width: (parent.width - (parent.spacing * 2)) / 3
                    height: parent.height

                    property bool isSelected:
                        appControlWindow.runPrefixMode
                        === appControlWindow.runPrefixKitty
                    property bool isHovered: runPrefixKittyMouse.containsMouse
                    property bool isPressed: runPrefixKittyMouse.pressed

                    color: isPressed
                           ? Colors.magenta
                           : isHovered
                           ? Colors.yellow
                           : isSelected
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: isSelected || isHovered
                                  ? Colors.orange
                                  : Colors.magenta

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

                        color: runPrefixKittyButton.isPressed
                               ? Colors.black
                               : runPrefixKittyButton.isHovered
                               ? Colors.orange
                               : runPrefixKittyButton.isSelected
                               ? Colors.magenta
                               : Colors.magenta
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
                                 ? 0.58
                                 : 0.26

                        color: Colors.orange

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
                                 ? 0.48
                                 : 0.14

                        color: Colors.orange
                    }
                }

                Rectangle {
                    id: runPrefixToolboxButton

                    width: (parent.width - (parent.spacing * 2)) / 3
                    height: parent.height

                    property bool isSelected:
                        appControlWindow.runPrefixMode
                        === appControlWindow.runPrefixToolbox
                    property bool isHovered:
                        runPrefixToolboxMouse.containsMouse
                    property bool isPressed:
                        runPrefixToolboxMouse.pressed

                    color: isPressed
                           ? Colors.magenta
                           : isHovered
                           ? Colors.yellow
                           : isSelected
                           ? Colors.yellow
                           : Colors.dark

                    border.width: 1
                    border.color: isSelected || isHovered
                                  ? Colors.orange
                                  : Colors.omnitrix

                    GohuText {
                        id: runPrefixToolboxText

                        anchors.centerIn: parent

                        text: "TOOLBOX"
                        font.pixelSize: 13

                        color: runPrefixToolboxButton.isPressed
                               ? Colors.black
                               : runPrefixToolboxButton.isHovered
                               ? Colors.orange
                               : runPrefixToolboxButton.isSelected
                               ? Colors.magenta
                               : Colors.omnitrix
                    }

                    DropShadow {
                        anchors.fill: runPrefixToolboxText
                        source: runPrefixToolboxText

                        horizontalOffset: 0
                        verticalOffset: 0

                        radius: 8
                        samples: 7

                        opacity: runPrefixToolboxButton.isPressed
                                 ? 0.0
                                 : runPrefixToolboxButton.isSelected
                                   || runPrefixToolboxButton.isHovered
                                 ? 0.58
                                 : 0.24

                        color: Colors.orange
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
                                 ? 0.48
                                 : 0.14

                        color: Colors.orange
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
                            ? "WINDOW CONTROL"
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
                        ((appControlWindow.selectedResultIsWindow()
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
                        selectedAppIdentity.showingWindow ? 7 : 18

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

                                    visible:
                                        ((selectedAppIdentity.showingApp
                                          || selectedAppIdentity.showingWindow)
                                         && (selectedAppIcon.source.toString().length > 0
                                             || (selectedAppIdentity.currentResult
                                                 && selectedAppIdentity.currentResult._hiddenCommand)))
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
                                        visible: selectedAppIdentity.showingApp && selectedAppIdentity.currentResult && selectedAppIdentity.currentResult._hiddenCommand && selectedAppIcon.status !== Image.Ready
                                        text: "-⋆♱⋆-"
                                        font.pixelSize: 18
                                        color: Colors.cyan
                                        layer.enabled: true
                                        layer.effect: DropShadow { radius: 8; samples: 7; opacity: 0.52; color: Colors.cyan; transparentBorder: true }
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
                                                ? 18
                                                : 22
                                            fontSizeMode: Text.HorizontalFit
                                            minimumPixelSize:
                                                selectedAppIdentity.showingWindow
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
                                            ? 13
                                            : 15

                                        color:
                                            selectedAppIdentity.showingWindow
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

                visible: appControlWindow.selectedResultIsWindow()
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

                        text: "WINDOW STATE"
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
                                            anchors.leftMargin: -2
                                            anchors.top:
                                                thermalMetricFahrenheit.top
                                            anchors.topMargin: -8

                                            text:
                                                Number(
                                                    modelData.tempC
                                                ).toFixed(1)
                                                + "°C"

                                            font.pixelSize: 10
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

                                        layer.enabled: parent.favorite
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
                    width: parent.width - 10
                    height: 28
                    anchors.horizontalCenter: parent.horizontalCenter

                    color: Colors.black
                    border.width: 1
                    border.color:
                        appControlWindow.thermalAccent(
                            thermalMonitorBody.currentSensor
                        )

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
                                    thermalMonitorBody.currentSensor
                                    && thermalMonitorBody.currentSensor.sensorKind
                                       === "fan"
                                    ? Number(
                                          thermalMonitorBody.currentSensor.rpm
                                          || 0
                                      )
                                      / Math.max(
                                            1,
                                            Number(
                                                thermalMonitorBody.currentSensor.maxRpm
                                                || 5000
                                            )
                                        )
                                    : Number(
                                          thermalMonitorBody.currentSensor
                                          ? thermalMonitorBody.currentSensor.tempC
                                          : 0
                                      ) / 100.0
                                )
                            )

                        color:
                            appControlWindow.thermalAccent(
                                thermalMonitorBody.currentSensor
                            )
                        opacity: 0.58

                        layer.enabled:
                            thermalMonitorBody.currentSensor
                            && thermalMonitorBody.currentSensor.sensorKind
                               !== "fan"
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 7
                            samples: 5
                            opacity: 0.52
                            color:
                                appControlWindow.thermalAccent(
                                    thermalMonitorBody.currentSensor
                                )
                            transparentBorder: true
                        }
                    }

                    GohuText {
                        anchors.centerIn: parent
                        text:
                            thermalMonitorBody.currentSensor
                            && thermalMonitorBody.currentSensor.sensorKind
                               === "fan"
                            ? "FAN SPEED"
                            : "THERMAL LOAD"
                        font.pixelSize: 11
                        color: Colors.white

                        layer.enabled: true
                        layer.effect: DropShadow {
                            horizontalOffset: 0
                            verticalOffset: 0
                            radius: 5
                            samples: 5
                            opacity: 0.34
                            color:
                                appControlWindow.thermalAccent(
                                    thermalMonitorBody.currentSensor
                                )
                            transparentBorder: true
                        }
                    }

                    RectangularShadow {
                        anchors.fill: parent
                        spread: 2
                        z: -1
                        opacity: 0.26
                        color:
                            appControlWindow.thermalAccent(
                                thermalMonitorBody.currentSensor
                            )
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

                            if (!task)
                                return [];

                            return [
                                {
                                    label: "CPU",
                                    value: Number(task.cpu || 0).toFixed(1) + "%",
                                    accent: Colors.orange
                                },
                                {
                                    label: "MEM",
                                    value: Number(task.mem || 0).toFixed(1) + "%",
                                    accent: Colors.magenta
                                },
                                {
                                    label: "RSS",
                                    value: appControlWindow.formatTaskMemory(task.rss),
                                    accent: Colors.cyan
                                },
                                {
                                    label: "THREADS",
                                    value: String(task.threads || 0),
                                    accent: Colors.omnitrix
                                },
                                {
                                    label: "PID",
                                    value: String(task.pid || "?"),
                                    accent: Colors.yellow
                                },
                                {
                                    label: "UPTIME",
                                    value: String(task.elapsed || "?"),
                                    accent: Colors.white
                                }
                            ];
                        }

                        Rectangle {
                            required property var modelData

                            readonly property color glowColor:
                                modelData.accent === Colors.white
                                ? Colors.cyan
                                : modelData.accent

                            Layout.fillWidth: true
                            Layout.preferredHeight: 58

                            color: Colors.black
                            border.width: 1
                            border.color: modelData.accent

                            RectangularShadow {
                                anchors.fill: parent
                                spread: 3
                                z: -1
                                opacity: 0.28
                                color: parent.glowColor
                            }

                            Column {
                                anchors.fill: parent
                                anchors.margins: 7
                                spacing: 3

                                GohuText {
                                    text: modelData.label
                                    font.pixelSize: 10
                                    color: modelData.accent
                                    opacity: 0.86

                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        horizontalOffset: 0
                                        verticalOffset: 0
                                        radius: 5
                                        samples: 5
                                        opacity: 0.28
                                        color:
                                            modelData.accent === Colors.white
                                            ? Colors.cyan
                                            : modelData.accent
                                        transparentBorder: true
                                    }
                                }

                                GohuText {
                                    width: parent.width
                                    text: modelData.value
                                    font.pixelSize: 16
                                    color: modelData.accent
                                    elide: Text.ElideRight

                                    layer.enabled: true
                                    layer.effect: DropShadow {
                                        horizontalOffset: 0
                                        verticalOffset: 0
                                        radius: 5
                                        samples: 5
                                        opacity: 0.36
                                        color:
                                            modelData.accent === Colors.white
                                            ? Colors.cyan
                                            : modelData.accent
                                        transparentBorder: true
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

                    Canvas {
                        id: taskCpuCanvas

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.fill: taskCpuGraphFrame
                        anchors.margins: 4
                        z: 2

                        property var history: appControlWindow.taskCpuHistory

                        onHistoryChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()

                        Timer {
                            interval: 450
                            repeat: true
                            running:
                                appControlWindow.menuOpen
                                && appControlWindow.selectedModeIndex
                                   === appControlWindow.killModeIndex
                                && taskManagerBody.visible
                            onTriggered: parent.requestPaint()
                        }

                        onPaint: {
                            const ctx = getContext("2d");
                            const w = width;
                            const h = height;

                            ctx.clearRect(0, 0, w, h);
                            ctx.globalAlpha = 0.18;
                            ctx.strokeStyle = Colors.orange.toString();
                            ctx.lineWidth = 1;

                            for (let i = 1; i <= 3; i++) {
                                const y = h * i / 4;
                                ctx.beginPath();
                                ctx.moveTo(0, y);
                                ctx.lineTo(w, y);
                                ctx.stroke();
                            }

                            const values = history || [];
                            if (values.length < 2) {
                                ctx.globalAlpha = 1.0;
                                return;
                            }

                            let minimum = Number(values[0] || 0);
                            let maximum = minimum;
                            for (let i = 1; i < values.length; i++) {
                                const value = Number(values[i] || 0);
                                minimum = Math.min(minimum, value);
                                maximum = Math.max(maximum, value);
                            }

                            const requiredRange = 6.0;
                            let range = Math.max(requiredRange, maximum - minimum);
                            let lower = Math.max(0, minimum - (range * 0.24));
                            let upper = maximum + (range * 0.24);

                            if (upper - lower < requiredRange) {
                                const center = (upper + lower) / 2;
                                lower = Math.max(0, center - requiredRange / 2);
                                upper = lower + requiredRange;
                            }

                            const slots = Math.max(2, appControlWindow.taskHistoryLimit);
                            const step = w / Math.max(1, slots - 1);
                            const startX = w - (step * (values.length - 1));

                            function trace(lineWidth, alpha) {
                                ctx.globalAlpha = alpha;
                                ctx.strokeStyle = Colors.orange.toString();
                                ctx.lineWidth = lineWidth;
                                ctx.lineJoin = "round";
                                ctx.lineCap = "round";
                                ctx.beginPath();

                                for (let i = 0; i < values.length; i++) {
                                    const x = startX + (i * step);
                                    const normalized = Math.max(0, Math.min(1,
                                        (Number(values[i] || 0) - lower)
                                        / Math.max(0.0001, upper - lower)
                                    ));
                                    const y = (h - 2) - (normalized * (h - 4));
                                    if (i === 0) ctx.moveTo(x, y);
                                    else ctx.lineTo(x, y);
                                }
                                ctx.stroke();
                            }

                            trace(6, 0.22);
                            trace(2, 1.0);
                            ctx.globalAlpha = 1.0;
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

                    Canvas {
                        id: taskMemCanvas

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.fill: taskMemGraphFrame
                        anchors.margins: 4
                        z: 2

                        property var history: appControlWindow.taskMemHistory

                        onHistoryChanged: requestPaint()
                        onWidthChanged: requestPaint()
                        onHeightChanged: requestPaint()

                        Timer {
                            interval: 450
                            repeat: true
                            running:
                                appControlWindow.menuOpen
                                && appControlWindow.selectedModeIndex
                                   === appControlWindow.killModeIndex
                                && taskManagerBody.visible
                            onTriggered: parent.requestPaint()
                        }

                        onPaint: {
                            const ctx = getContext("2d");
                            const w = width;
                            const h = height;

                            ctx.clearRect(0, 0, w, h);
                            ctx.globalAlpha = 0.18;
                            ctx.strokeStyle = Colors.magenta.toString();
                            ctx.lineWidth = 1;

                            for (let i = 1; i <= 3; i++) {
                                const y = h * i / 4;
                                ctx.beginPath();
                                ctx.moveTo(0, y);
                                ctx.lineTo(w, y);
                                ctx.stroke();
                            }

                            const values = history || [];
                            if (values.length < 2) {
                                ctx.globalAlpha = 1.0;
                                return;
                            }

                            let minimum = Number(values[0] || 0);
                            let maximum = minimum;
                            for (let i = 1; i < values.length; i++) {
                                const value = Number(values[i] || 0);
                                minimum = Math.min(minimum, value);
                                maximum = Math.max(maximum, value);
                            }

                            const requiredRange = 0.35;
                            let range = Math.max(requiredRange, maximum - minimum);
                            let lower = Math.max(0, minimum - (range * 0.24));
                            let upper = maximum + (range * 0.24);

                            if (upper - lower < requiredRange) {
                                const center = (upper + lower) / 2;
                                lower = Math.max(0, center - requiredRange / 2);
                                upper = lower + requiredRange;
                            }

                            const slots = Math.max(2, appControlWindow.taskHistoryLimit);
                            const step = w / Math.max(1, slots - 1);
                            const startX = w - (step * (values.length - 1));

                            function trace(lineWidth, alpha) {
                                ctx.globalAlpha = alpha;
                                ctx.strokeStyle = Colors.magenta.toString();
                                ctx.lineWidth = lineWidth;
                                ctx.lineJoin = "round";
                                ctx.lineCap = "round";
                                ctx.beginPath();

                                for (let i = 0; i < values.length; i++) {
                                    const x = startX + (i * step);
                                    const normalized = Math.max(0, Math.min(1,
                                        (Number(values[i] || 0) - lower)
                                        / Math.max(0.0001, upper - lower)
                                    ));
                                    const y = (h - 2) - (normalized * (h - 4));
                                    if (i === 0) ctx.moveTo(x, y);
                                    else ctx.lineTo(x, y);
                                }
                                ctx.stroke();
                            }

                            trace(6, 0.22);
                            trace(2, 1.0);
                            ctx.globalAlpha = 1.0;
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
                        radius: 5
                        samples: 5
                        opacity: 0.34
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
                                radius: 9
                                samples: 7
                                opacity: 0.62
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
                                radius: 7
                                samples: 5
                                opacity: 0.48
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
                            ? 0.62
                            : 0.22
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
                                icon: "(ˊᗜˋو)و︎︎♬",
                                accent: Colors.orange
                            },
                            {
                                label: "FLOAT",
                                icon: "⊹ ࣪ ˖🕊⋆₊⊹",
                                accent: Colors.white
                            },
                            {
                                label: "FULLSCREEN",
                                icon: "🂡🂱🃑🂭🂽",
                                accent: Colors.magenta
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
                                modelData.accent === Colors.white
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
                            text: "ALTERNATE LAUNCH"
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
                        GohuText {
                            anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                            text: hiddenBottleAction.canRun ? "BOTTLES" : "BOTTLES  [NO TARGET]"
                            font.pixelSize: 14
                            color: hiddenBottleAction.isPressed ? Colors.black : hiddenBottleAction.isHovered || hiddenBottleAction.isSelected ? Colors.orange : Colors.magenta
                            layer.enabled: !hiddenBottleAction.isPressed
                            layer.effect: DropShadow { radius: 8; samples: 7; opacity: hiddenBottleAction.isHovered || hiddenBottleAction.isSelected ? 0.62 : 0.46; color: Colors.magenta; transparentBorder: true }
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
                        GohuText {
                            anchors.left: parent.left; anchors.leftMargin: 10; anchors.verticalCenter: parent.verticalCenter
                            text: "TOOLBOX"; font.pixelSize: 14
                            color: hiddenToolboxAction.isPressed ? Colors.black : hiddenToolboxAction.isHovered || hiddenToolboxAction.isSelected ? Colors.orange : Colors.omnitrix
                            layer.enabled: !hiddenToolboxAction.isPressed
                            layer.effect: DropShadow { radius: 8; samples: 7; opacity: hiddenToolboxAction.isHovered || hiddenToolboxAction.isSelected ? 0.64 : 0.50; color: Colors.omnitrix; transparentBorder: true }
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

                        text: "ALTERNATE LAUNCH"

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
                    border.color:
                        appBottleAction.isHovered
                        || appBottleAction.isSelected
                        ? Colors.orange
                        : Colors.magenta

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        spacing: 8

                        GohuText {
                            id: appBottleActionIcon

                            anchors.verticalCenter: parent.verticalCenter

                            text: "◌"

                            font.pixelSize: 15

                            color: appBottleAction.isPressed
                                   ? Colors.black
                                   : appBottleAction.isHovered
                                     || appBottleAction.isSelected
                                   ? Colors.orange
                                   : Colors.magenta

                            layer.enabled: !appBottleAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0

                                radius: 8
                                samples: 7

                                opacity:
                                    appBottleAction.isHovered
                                    || appBottleAction.isSelected
                                    ? 0.70
                                    : 0.46

                                color:
                                    appBottleAction.isHovered
                                    || appBottleAction.isSelected
                                    ? Colors.orange
                                    : Colors.magenta

                                transparentBorder: true
                            }
                        }

                        GohuText {
                            id: appBottleActionText

                            anchors.verticalCenter: parent.verticalCenter

                            text:
                                appControlWindow.bottlesLoading
                                ? "BOTTLES  [LOADING]"
                                : appBottleAction.hasBottle
                                ? "BOTTLES"
                                : "BOTTLES  [NO TARGET]"

                            font.pixelSize: 14

                            color: appBottleAction.isPressed
                                   ? Colors.black
                                   : appBottleAction.isHovered
                                     || appBottleAction.isSelected
                                   ? Colors.orange
                                   : Colors.magenta

                            layer.enabled: !appBottleAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0

                                radius: 7
                                samples: 5

                                opacity:
                                    appBottleAction.isHovered
                                    || appBottleAction.isSelected
                                    ? 0.62
                                    : 0.42

                                color:
                                    appBottleAction.isHovered
                                    || appBottleAction.isSelected
                                    ? Colors.orange
                                    : Colors.magenta

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

                        color:
                            appBottleAction.isHovered
                            || appBottleAction.isSelected
                            ? Colors.orange
                            : Colors.magenta
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
                    border.color:
                        appToolboxAction.isHovered
                        || appToolboxAction.isSelected
                        ? Colors.orange
                        : Colors.omnitrix

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 10
                        spacing: 8

                        GohuText {
                            id: appToolboxActionIcon

                            anchors.verticalCenter: parent.verticalCenter

                            text: "⬢"
                            font.pixelSize: 15

                            color: appToolboxAction.isPressed
                                   ? Colors.black
                                   : appToolboxAction.isHovered
                                     || appToolboxAction.isSelected
                                   ? Colors.orange
                                   : Colors.omnitrix

                            layer.enabled: !appToolboxAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0
                                radius: 8
                                samples: 7
                                opacity:
                                    appToolboxAction.isHovered
                                    || appToolboxAction.isSelected
                                    ? 0.66
                                    : 0.40
                                color:
                                    appToolboxAction.isHovered
                                    || appToolboxAction.isSelected
                                    ? Colors.orange
                                    : Colors.omnitrix
                                transparentBorder: true
                            }
                        }

                        GohuText {
                            id: appToolboxActionText

                            anchors.verticalCenter: parent.verticalCenter

                            text: appToolboxAction.canLaunch
                                  ? "TOOLBOX"
                                  : "TOOLBOX  [UNAVAILABLE]"

                            font.pixelSize: 14

                            color: appToolboxAction.isPressed
                                   ? Colors.black
                                   : appToolboxAction.isHovered
                                     || appToolboxAction.isSelected
                                   ? Colors.orange
                                   : Colors.omnitrix

                            layer.enabled: !appToolboxAction.isPressed
                            layer.effect: DropShadow {
                                horizontalOffset: 0
                                verticalOffset: 0
                                radius: 8
                                samples: 7
                                opacity:
                                    appToolboxAction.isHovered
                                    || appToolboxAction.isSelected
                                    ? 0.66
                                    : 0.42
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

                        color:
                            appToolboxAction.isHovered
                            || appToolboxAction.isSelected
                            ? Colors.orange
                            : Colors.omnitrix
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

                        color: isPressed
                               ? Colors.magenta
                               : isHovered || isSelected
                               ? Colors.yellow
                               : index === 0
                               ? Colors.dark
                               : Colors.black

                        border.width: 1
                        border.color: isHovered || isSelected
                                      ? Colors.orange
                                      : Colors.cyan

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

                                    color:
                                        windowPrimaryActionButton.isHovered
                                        || windowPrimaryActionButton.isSelected
                                        ? Colors.orange
                                        : Colors.cyan

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
                                    color:
                                        windowPrimaryActionButton.isHovered
                                        || windowPrimaryActionButton.isSelected
                                        ? Colors.orange
                                        : Colors.cyan
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

                            // Keep the action BAR halo cyan. Hover/keyboard
                            // emphasis remains on the icon/text inside.
                            color: Colors.cyan
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
                        color: Colors.magenta
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
                                   : windowMuteAction.isHovered
                                     || windowMuteAction.isSelected
                                   ? Colors.white
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
                        color: Colors.orange

                        transparentBorder: true
                    }

                    GohuText {
                        id: runAlternateActionsHeaderText

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.leftMargin: 12

                        text: "ALTERNATE ACTIONS"

                        font.pixelSize: 13
                        color: Colors.orange
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
                    border.color: Colors.orange

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
                                   : Colors.orange

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

                                color: Colors.orange
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
                                   : Colors.orange

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

                                color: Colors.orange
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

                        color: Colors.orange
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

                        color: Colors.orange
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
                    border.color: Colors.orange

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
                                   : Colors.orange

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

                                color: Colors.orange
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
                                   : Colors.orange

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

                                color: Colors.orange
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

                        color: Colors.orange
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

                        color: Colors.orange
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
                    border.color: Colors.orange

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
                                   : Colors.orange

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

                                color: Colors.orange
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
                                   : Colors.orange

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

                                color: Colors.orange
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

                        color: Colors.orange
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

                        color: Colors.orange
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
                        && appControlWindow.selectedDetailActionIndex === 4

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

                        readonly property int actionIndex: 4
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

            appControlWindow.scheduleFavoritesFaceBlink();
            appControlWindow.scheduleKittyFaceBlink();

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

            appControlWindow.favoritesFaceClickPulse = false;
            appControlWindow.favoritesFaceBlinking = false;
            appControlWindow.favoritesFaceDoubleBlinkPending = false;

            appControlWindow.kittyFaceClickPulse = false;
            appControlWindow.kittyFaceBlinking = false;
            appControlWindow.kittyFaceDoubleBlinkPending = false;
        }
    }
}

