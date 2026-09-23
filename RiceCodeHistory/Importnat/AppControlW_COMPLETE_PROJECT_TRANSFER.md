
# AppControlW / Quickshell Launcher-Control Surface — Complete Project Transfer

**Transfer date:** 2026-09-11  
**Current source-of-truth QML:** `AppControlW_taskgraphs_fan_slider_favorite_filters.qml`  
**Current file size:** 840,592 bytes  
**Current line count:** 20,589 lines  
**SHA-256:** `b431e2dfdb01fbd466b3f605dd4b52fade651b42cff9956ac45ecd507959c4f4`

> **Important:** In a new chat, upload **this Markdown file and the current QML file together**.  
> The Markdown explains the project, but the QML file remains the literal implementation source of truth.  
> Do not reconstruct AppControlW from older snippets unless a deliberate rollback is requested.

---

## 0. Executive handoff / what this project is

This project is a **Quickshell-native application launcher, command launcher, window controller, task manager, thermal/fan controller, system monitor, favorites/watch surface, and tab switcher** for a custom Fedora Silverblue + Sway desktop.

The key architectural rule is:

> **Quickshell is the UI/orchestration layer. Linux/Sway/system services remain the backend.**

This is **not** a Rofi launcher wrapped by Quickshell. Rofi was only the original visual/reference ancestry. The launcher/control system is implemented directly in QML/Quickshell and talks to:

- `DesktopEntries` for applications.
- Sway / I3 IPC for windows.
- shell commands and `/proc` for task/process data.
- `/sys/class/hwmon` and `/sys/class/thermal` for thermal/fan data.
- `pactl`/PulseAudio/PipeWire compatibility for window/session mute state.
- `nmcli` for network disconnect/reconnect.
- `systemctl` for reboot.
- `toolbox` for Fedora Toolbox launching.
- Bottles CLI where available.
- AT-SPI / libatspi / Kitty remote control / Chromium DevTools for application tabs.
- `notify-send` for current task-watch critical notifications.

The intended feel is an ornate **retro terminal / CRT / celestial HUD / game-menu instrument panel**, not a conventional GNOME/KDE launcher.

---

# 1. Environment and assumptions

## Host stack

The project has been built around:

```text
Fedora Silverblue 44
Sway / wlroots
Quickshell 0.3.1 from Fedora COPR
Qt 6.11.2
Kitty
Zellij
Zsh
```

Quickshell's build has Sway/I3 IPC support.

## Main project tree

The intended config tree is:

```text
~/.config/quickshell/
├── components/
├── modules/
│   ├── Applauncher.qml
│   └── ...
├── services/
├── widgets/
│   ├── messanger/
│   └── AppControlW.qml
└── shell.qml
```

Historical typo:

```text
AppContolW.qml
```

was corrected to:

```text
AppControlW.qml
```

## Required imports / integration

`AppControlW.qml` needs:

```qml
import "../components"
```

`shell.qml` needs:

```qml
import "widgets"
```

Typical shell instantiation:

```qml
AppControlW {
    id: appControlWindow
}
```

The small bar launcher `Applauncher.qml` is separate and has:

```qml
property var appControlWindow
```

Its left click toggles:

```qml
appControlWindow.menuOpen
```

The global Sway binding currently calls Quickshell IPC rather than being owned directly by the widget.

---

# 2. Non-negotiable project rules

These are the rules a future chat should preserve unless explicitly told otherwise.

## Quickshell only

Do **not** replace the launcher with Rofi, Wofi, Fuzzel, etc.

Rofi is reference ancestry only.

## Code-only workflow

The user explicitly corrected an accidental image-generation path with:

> “no image only code”

For launcher/QML work, edit code/files directly. Do not invoke image generation.

## Current file wins

When there are conflicting historical snippets, the newest generated/uploaded QML wins.

Current source of truth:

```text
AppControlW_taskgraphs_fan_slider_favorite_filters.qml
```

## Do not casually kill Quickshell

Never use a casual:

```bash
pkill quickshell
```

because Quickshell is the whole shell/bar.

For foreground debugging, the established command is:

```bash
qs -p ~/.config/quickshell/shell.qml
```

`qs ipc call ...` only works if Quickshell is already running.

---

# 3. Visual language

## Aesthetic

The requested aesthetic is:

- Christian/cross motifs.
- Celestial/night sky/space.
- Retro computing.
- Terminal/ASCII.
- CRT.
- Old TVs / old PCs.
- Neon / synthwave.
- Retro-American / Japanese.
- Gaming / anime / comics.
- Playful, ornate, HUD/instrument-panel presentation.

Do **not** describe the design as Gothic/occult.

## Font

Primary UI font:

```text
GohuFont 11 Nerd Font Mono
```

## Geometry

General rules:

- Mostly square geometry.
- Thin separators.
- Glow-driven decoration.
- Small dense control buttons.
- Instrument-panel/HUD feeling.
- Avoid modern rounded “material card” styling unless explicitly requested.

## Palette singleton

The project palette is:

```qml
pragma Singleton
import QtQuick

QtObject {
    readonly property color red: "#D16041"
    readonly property color orange: "#ED981A"
    readonly property color yellow: "#F2BE4E"
    readonly property color green: "#9ECE6A"
    readonly property color omnitrix: "#00F782"
    readonly property color cyan: "#55CFCA"
    readonly property color blue: "#5B5FD4"
    readonly property color magenta: "#C74EC7"
    readonly property color white: "#DCF3FA"
    readonly property color black: "#1B0623"
    readonly property color dark: "#16051F"
}
```

Important:

```text
Colors.black = deep purple
Colors.dark  = darker purple
```

There is no `Colors.background`.

## Semantic color language

Use these consistently:

```text
cyan      normal/data/interface
orange    active/focused/hot/hover
yellow    selected fill
magenta   pressed/special/favorite-selected/submode-selected
red       destructive/error/critical
white     neutral/context
omnitrix  vivid green/safe/toolbox/audio
```

---

# 4. Current main mode rail

Current mode indices in the QML:

```text
0  FAVORITES
1  APPS
2  RUN
3  WINDOWS
4  THERMAL
5  KILL
6  SYSTEM
```

Current rail definitions:

```qml
property var modes: [
    { name: "FAVORITES", symbol: "(˵✧ᴗ✧˵)" },
    { name: "APPS",      symbol: "-⋆♱⋆-" },
    { name: "RUN",       symbol: "⌯✎﹏﹏" },
    { name: "WINDOWS",   symbol: "🃁🂡🂱🃑" },
    { name: "THERMAL",   symbol: "🌡" },
    { name: "KILL",      symbol: "(-_•)︻デ═一" },
    { name: "SYSTEM",    symbol: "🖳" }
]
```

FAVORITES is visually first, but opening the panel defaults to APPS.

Current default:

```qml
property int selectedModeIndex: appsModeIndex
```

KILL's smaller FAVORITES submenu icon is intentionally:

```text
⌐╦╾━
```

instead of the full large KILL rail symbol.

---

# 5. Main panel placement / visual baseline

Established window placement:

```qml
anchors {
    top: true
    left: true
}

margins {
    top: -3
    left: 2
}
```

Approximate historical implicit size:

```text
834 × 674
```

Panel baseline:

- Outer orange glow.
- Selector top area uses `Colors.black`.
- Result area uses `Colors.dark`.
- Search typed text is magenta with glow.
- Search cursor is orange.
- Header/control pane geometry is fixed/centered.
- Right control title is centered across the entire control pane.
- Left/right title ornaments use equal side regions.
- Right ornament is horizontally mirrored.
- Permanent result-list top gap prevents rows touching the header divider.
- Bottom fixed cyan line.
- Custom scrollbars are used instead of default Qt bars.

---

# 6. Keyboard / mouse interaction model

This project spent a lot of time fixing pointer/keyboard ownership. Do not regress it.

## Core state

Important properties:

```text
keyboardActive
detailFocused
selectedResultIndex
selectedDetailActionIndex
hoveredResultIndex
modeRailFocused
modeRailCursorIndex
modeRailHoveredIndex
```

## Main keyboard behavior

Search input owns key handling through:

```qml
Keys.onPressed: appControlWindow.handleKey(event)
```

Expected behavior:

```text
Escape:
  detail pane -> return left
  otherwise -> close launcher

Up/Down:
  move result selection
  or move mode rail cursor when rail-focused

Right:
  enter detail/control pane for supported results
  or activate selected/hovered mode when mode-rail focused

Left:
  from a result/menu -> enter mode selector rail
  from detail -> return to results

Enter:
  detail pane -> activate selected detail action
  selector -> activate preferred/favorite detail action if one exists
              otherwise activate selected result

Tab / Shift+Tab:
  mode/result/detail cycling according to context

Shift+Left:
  used for several top/source sub-mode selectors

Ctrl+Left:
  used for several bottom launch-prefix selectors
```

A later change explicitly added mode-rail keyboard focus so Left from a menu goes into the left mode rail, Up/Down navigates it, and Right enters the highlighted mode.

## Mouse/keyboard arbitration

This was previously described by the user as “perfect” and should remain intact:

- Result delegate is full width.
- Actual button is an inner rectangle.
- Mouse hover tracking is based on actual pointer movement.
- Keyboard activity clears hover ownership.
- Real pointer movement takes ownership back.
- Scrolling under a stationary pointer does **not** steal keyboard selection.
- No cursor teleportation behavior.

## Result selection visual

Current desired selector-row style:

```text
selected row fill       yellow
selected main text      orange
hover row fill          yellow
hover text              orange
```

This intentionally reverted an older dark-fill/yellow-text keyboard style.

---

# 7. Mode rail / sub-mode visual contract

A recurring bug was sub-mode buttons becoming faded/grey after leaving them.

The intended contract now is:

```text
INACTIVE:
  dark fill
  text/icon = its own accent color
  border = same accent
  visible glow, not grey/faded

HOVER:
  yellow fill
  orange text/icon
  orange border/glow

SELECTED:
  yellow fill
  magenta text/icon
  magenta border/glow

PRESSED:
  magenta fill
  black text/icon where appropriate
```

The corrected architecture moved problematic controls away from inconsistent `layer.effect` behavior and toward sibling `DropShadow` objects similar to the RUN buttons.

Important affected groups:

- APPS NORMAL / FLATPAK / HIDDEN.
- APPS bottom NORMAL / BOTTLES / TOOLBOX.
- RUN USER / TERMINAL / SYSTEM.
- RUN bottom NORMAL / KITTY / TOOLBOX.
- WINDOWS / TABS.
- THERMAL / FANS.
- FAVORITES mode filters.

If a future patch makes these look grey again, inspect:

```text
root opacity
text opacity
layer.effect vs sibling DropShadow
hardcoded old border colors
disabled-state opacity accidentally applied to selector buttons
```

---

# 8. FAVORITES mode

## Purpose

FAVORITES is now a cross-mode aggregation surface rather than only an app list.

It can aggregate favorites from:

- APPS.
- RUN.
- WINDOWS.
- THERMAL.
- KILL/process watches.
- SYSTEM.
- preferred control-panel actions.
- monitor/watch boxes.

## Persistence

Stored under:

```text
Quickshell.dataDir + "/appcontrol-favorites.json"
```

Current JSON-backed favorite fields include:

```qml
property list<string> favoriteKeys: []
property list<string> favoriteDetailActionKeys: []
property list<string> favoriteMonitorBoxKeys: []
property list<string> favoriteTaskMetricKeys: []
```

### `favoriteKeys`

General row-level favorites:

- apps
- RUN commands
- thermal/system entries
- window entries
- task/process identities
- hidden commands

### `favoriteDetailActionKeys`

Preferred control-panel actions for APPS and RUN.

This supports “favorite this action, then pressing Enter on the result runs that preferred action.”

### `favoriteMonitorBoxKeys`

Thermal/system metric boxes watched/favorited in their control panels.

### `favoriteTaskMetricKeys`

Per-process task metrics, including persistent process identity + metric ID.

## Preferred control-action favorite system

The first attempts used a reusable Loader/Component star system and failed because ID matching/insertion hit unintended objects and stale indexes.

The successful architecture uses **direct star controls inside each action button**.

Important rules:

- Direct star items use high z (`z: 5000`).
- Each star has its own MouseArea.
- Desktop-action stars use the repeater index correctly.
- One preferred action per app/command context.
- Clicking the same filled favorite clears it.
- Unavailable actions cannot be favorited.
- After changing favorite, keyboard detail selection moves to the new preferred action.
- Persistence is in `appcontrol-favorites.json`.

## FAVORITES Enter semantics

Originally the preferred action shortcut worked only in APPS/RUN because it gated on `selectedModeIndex`.

The fix was to resolve the selected row's **real source type** instead.

Current intention:

```text
FAVORITES app row + Enter:
  execute that app's saved preferred control action

FAVORITES RUN row + Enter:
  execute that command's saved preferred control action

No saved preferred action:
  use normal row activation
```

This was user-confirmed as working after the fix.

## New FAVORITES source filters

The latest file adds a top filter bar:

```text
ALL / FAVORITES
APPS
RUN
WINDOWS
THERMAL
KILL
SYSTEM
```

Selecting one only shows favorites whose `_sourceModeIndex` matches that mode.

KILL filter icon:

```text
⌐╦╾━
```

The filter is stored in:

```qml
property int favoritesFilterMode
```

with:

```qml
readonly property int favoritesFilterAll: -1
```

`Shift+Left` cycles through the favorite filters.

### Latest status

**Implemented in the current file but not yet runtime-confirmed by the user.**

---

# 9. APPS mode

## Desktop-entry backend

Real backend:

```qml
DesktopEntries.applications
```

Filtering searches:

- name
- generic name
- comment
- keywords
- source label

Sorting:

- favorites pinned
- names alphabetical
- same-name native/Flatpak variants kept adjacent
- variant matching active source preferred

## App override helpers

The project has an override structure for future metadata correction:

```qml
appOverrides = ({})
```

Helpers include:

```text
appOverride
appDisplayName
appDisplayDescription
appLongDescription
appDisplayIcon
appIconSource
```

## Safe icon source helper

Important:

```qml
function appIconSource(...) {
    ...
    return Quickshell.iconPath(icon, true);
}
```

See the dedicated icon crash section later; Canvas must never request this original provider URL directly.

---

# 10. APPS source sub-modes

Current source selector:

```text
NORMAL
FLATPAK
HIDDEN
```

Indices:

```qml
appSourceNative  = 0
appSourceFlatpak = 1
appSourceHidden  = 2
```

## NORMAL / FLATPAK behavior

Both native and Flatpak desktop entries remain visible.

The selected source mode controls **launchability**, not visibility.

Expected:

```text
NORMAL selected:
  native apps launchable
  Flatpak entries remain visible but subdued/unavailable

FLATPAK selected:
  Flatpak apps launchable
  native entries remain visible but subdued/unavailable
```

A later requirement modified one direction:

> Flatpak apps should be launchable from the NORMAL app menu, but not the other way around.

The current code evolved around context-aware launchability; verify this behavior if revisiting source gating.

## Source sub-label

Rows show:

```text
NORMAL
FLATPAK
HIDDEN
```

## HIDDEN source

HIDDEN is populated from executable commands in `$PATH`.

It exists for command-line/TUI programs that normally do not expose a useful desktop entry, such as:

```text
cat
cava
hollywood
pipes / pipes.sh
zsh
bash
fish
htop
btop
nvim
vim
fastfetch
neofetch
cmatrix
...
```

HIDDEN command records are synthetic application-like records.

### HIDDEN launch behavior

Normal activation opens the command in Kitty and leaves a shell open afterward.

### HIDDEN icons

The icon resolver tries:

1. known command → icon mappings
2. matching real desktop-entry icon if found
3. no icon → HIDDEN face fallback

Current HIDDEN face:

```text
idle:            |ω-ς)
hover/selected:  |ω･`ς)
```

The face has its own randomized single/double blink schedule, independent of KITTY and FAVORITES.

A prior bug caused the fallback face/app glyph to render behind real icons in NORMAL/FLATPAK and other menus. The fix added a strict `hiddenFallbackActive` condition and put real icons above fallback content with explicit z-order.

---

# 11. APPS launch sub-modes

Current bottom APPS launch modes:

```text
NORMAL
TOOLBOX
BOTTLES
```

Indices:

```qml
appLaunchNormal  = 0
appLaunchToolbox = 1
appLaunchBottle  = 2
```

The visual order has moved around several times. The latest file's literal QML is authoritative.

## TOOLBOX

The sub-mode icon is a boxed:

```text
🛠
```

The **panel** TOOLBOX action keeps its full text/action presentation rather than becoming icon-only.

TOOLBOX color:

```text
Omnitrix green
```

Text, icon, and glow are intended to remain green even on hover/keyboard selection, while button fill still uses selected/hover states.

## BOTTLES

The sub-mode icon is a three-urn composition:

```text
⚱  ⚱  ⚱
   ^ center larger
```

Panel BOTTLES actions now also use the same three-urn icon treatment.

BOTTLES color:

```text
magenta
```

Text/icon/glow are intended to stay magenta.

### Bottles discovery

The code tries:

- Flatpak Bottles CLI
- then system `bottles-cli`

First discovered bottle becomes the default target.

### Bottles limitation

The launcher currently assumes the application display name corresponds to a registered Bottles program target.

Arbitrary Linux application launching inside Bottles has **not** been proven.

There is still no full bottle picker UI.

---

# 12. APPS control panel

Header:

```text
APPLICATION CONTROL
```

Current areas include:

- app identity/name/description/icon
- RUNNING STATE
- workspace summary
- primary launch action
- desktop actions
- ALTERNATE LAUNCH
- BOTTLES
- TOOLBOX
- process/app KILL section

Primary launch icon/text family has been styled with:

```text
normal:
  ⌯♱ ๋࣭⭑

Flatpak:
  ⌯✉︎๋࣭⭑
```

The FLATPAK source sub-mode symbol uses:

```text
⋆˙⟡ ⌯⛟
```

Desktop action alignment was corrected so:

```text
ACTIONS
DESKTOP ACTIONS
ALTERNATE LAUNCH
```

do not visibly misalign.

---

# 13. RUN mode

## Top RUN list selector

Current top modes:

```text
USER
TERMINAL
SYSTEM
```

Internally the code uses:

```qml
runListUser = 0
runListTerminal = 1
runListAll = 2
```

The visible SYSTEM label corresponds to the all-command catalog in some code paths; some internal names remain historical.

### USER

Typed command + RUN favorites + session history.

### TERMINAL

Terminal-history oriented source.

### SYSTEM / ALL

Rofi-run-style catalog of executable command names from `$PATH`.

## Bottom RUN prefix selector

Current launch prefixes:

```text
NORMAL
KITTY
TOOLBOX
```

Indices:

```qml
runPrefixNormal  = 0
runPrefixKitty   = 1
runPrefixToolbox = 2
```

TOOLBOX uses boxed `🛠`.

## Shortcuts

Established:

```text
Shift+Left:
  USER -> TERMINAL -> SYSTEM

Ctrl+Left:
  NORMAL -> KITTY -> TOOLBOX
```

The TextInput ShortcutOverride path was hardened because Ctrl+Left/Shift+Left could otherwise be consumed as text navigation.

---

# 14. RUN control panel / COMMAND CONTROL

Header:

```text
COMMAND CONTROL
```

State heading:

```text
COMMAND STATE
```

Primary action now includes:

```text
⌯✎﹏﹏  RUN COMMAND
```

Current action order:

```text
0 RUN COMMAND
1 KITTY
2 FLOAT
3 FULLSCREEN
4 TOOLBOX
5 KILL
```

Older documentation may still say KILL index 4. That is stale after TOOLBOX was inserted.

## Alternate RUN actions

### KITTY

Uses the established Kitty face/icon behavior and independent blink state.

### FLOAT

Float command icon:

```text
⊹ ࣪ ˖🕊⋆₊⊹
```

### FULLSCREEN

Fullscreen icon:

```text
🂡🂱🃑🂭🂽
```

### TOOLBOX

Added to COMMAND CONTROL to match the APP control panel TOOLBOX action.

It uses boxed:

```text
🛠
```

with Omnitrix text/icon/glow.

### KILL

Always visible.

No target:

```text
(•_•)デ╾━
```

Target idle:

```text
(-_•)デ╾━
```

Hover:

```text
ദ്ദി(-_•)デ╾━
```

Click:

```text
(=ᗜ=)デ╾━ ๋࣭⭑
```

RUN KILL uses `TERM`, not SIGKILL.

The kill probe scans processes/wrapper scripts to find likely targets for a simple leading executable token.

After kill, the launcher stays open and refreshes.

---

# 15. WINDOWS mode

## Window backend

The authoritative window list comes from Sway:

```bash
swaymsg -t get_tree
```

plus:

```qml
I3IpcListener {
    subscriptions: ["window", "workspace"]
}
```

Window records carry:

```text
id
name
appId
className
instance
pid
focused
workspace
output
floating
fullscreen
rect
```

## Floating-window collection fix

`collectSwayWindows()` was updated to preserve floating state through:

- `floating_con` wrappers
- `floating_nodes`
- `_on` floating fields

It also accepts live PID+title windows even when app identity fields are sparse.

This was specifically intended to catch centered/floating clients that disappeared under stricter identity tests.

## App ↔ window matching

Matching uses normalized combinations of:

- startupClass
- desktop-entry id
- command basename
- app_id
- class
- instance
- window title

The user previously confirmed this matching was accurate.

---

# 16. WINDOWS selector sub-modes

Current selector:

```text
WINDOWS
TABS
```

Indices:

```qml
windowListWindows = 0
windowListTabs    = 1
```

WINDOWS is real and working.

TABS has been the most difficult unresolved subsystem and is documented separately below.

---

# 17. WINDOWS control panel

Header:

```text
WINDOW CONTROL
```

State heading:

```text
WINDOW STATE
```

Detail action order:

```text
0 FOCUS
1 MOVE HERE
2 TOGGLE FLOATING
3 TOGGLE FULLSCREEN
4 TOGGLE CENTER
5 MUTE / UNMUTE
6 KILL
```

### FOCUS

Icon:

```text
(╭ರ_•́)
```

### MOVE HERE

Icon:

```text
જ⁀➴
```

### CENTER

Icon:

```text
🃁🂡🂱🃑
```

Current center implementation is effectively:

```text
floating enable
move position center
```

It is not a true two-way center toggle.

### MUTE / UNMUTE

Unmuted:

```text
* (ˊᗜˋو)و︎︎♬*
```

Muted:

```text
⊹ ࣪ (ᴗ˳ᴗ)ᶻ𝗓 ࣪
```

The latest requested color behavior:

```text
text              Omnitrix
text glow         green
audio header glow green
```

A previous bug had the AUDIO ACTION header/text halo magenta.

### KILL

WINDOW KILL uses Sway compositor `kill`, not a process SIGKILL.

---

# 18. Window audio policy

The intended audio behavior is session-level:

- probe the selected window/app's audio session
- MUTE/UNMUTE should target the relevant stream/session
- keep UI state synchronized
- avoid killing sound globally

This has been iterated but should still be treated as a subsystem that may need backend-specific testing depending on PipeWire/PulseAudio session naming.

---

# 19. TABS subsystem — current architecture and unresolved status

## User's goal

TABS is **not** Sway tabbed-layout windows.

The user wants real application tabs from apps such as:

- Brave
- Kitty
- VS Code
- Chromium/Electron apps
- other applications exposing accessibility tabs

## What failed historically

### Attempt 1: Sway tree only

Only windows/layouts appeared, not application tabs.

Reason:

Sway does not know internal browser/editor tabs.

### Attempt 2: Python AT-SPI / PyGObject

The UI reported:

```text
TAB PROVIDERS UNAVAILABLE
```

or no accessible tabs.

Likely causes:

- host Python missing `gi`/Atspi
- application accessibility not exposed
- app was already running without accessibility initialized

### Attempt 3: direct `gdbus` traversal

Added an AT-SPI D-Bus fallback without requiring Python GI.

This still cycled between:

```text
SCANNING TABS
NO TABS EXPOSED YET
```

### Attempt 4: `Cache.GetItems`

Moved to AT-SPI cache bulk discovery to avoid thousands of D-Bus calls.

Still did not produce visible tabs in user testing.

### Attempt 5: runtime accessibility enable

Tried enabling:

```text
org.a11y.Status.IsEnabled
```

and warm rescans.

Still produced waiting/no-tab states.

### Attempt 6: persistent libatspi bridge

Created a persistent Python process using `ctypes` + `libatspi`.

Purpose:

- keep a real assistive-technology registration alive
- scan the accessibility tree from the same persistent process
- avoid short-lived scanner/client races

The user then saw:

```text
WAITING FOR ACCESSIBLE TABS
```

continuously.

### Current additional provider work

The current file additionally auto-configures tab-aware launches.

For Chromium/Electron-family applications launched through AppControl:

```text
--force-renderer-accessibility=complete
NO_AT_BRIDGE=0
ACCESSIBILITY_ENABLED=1
QT_ACCESSIBILITY=1
QT_LINUX_ACCESSIBILITY_ALWAYS_ON=1
```

It also allocates local DevTools ports:

```text
Brave       9222
Chrome      9223
Chromium    9224
VS Code     9225
Codium      9226
Electron    9300..9499 hashed by app identity
```

with:

```text
--remote-debugging-address=127.0.0.1
--remote-debugging-port=<port>
```

Kitty launches through AppControl with:

```text
allow_remote_control=socket-only
--listen-on unix:@appcontrol-kitty-...
```

Current waiting label:

```text
WAITING FOR TAB PROVIDERS
```

## Provider stack currently intended

The latest code contains multiple tab-provider paths:

```text
1. persistent libatspi tree scan
2. AT-SPI fallback/cache logic
3. Kitty remote control
4. Chromium/Electron DevTools
```

## Important current status

**TABS IS NOT YET USER-CONFIRMED WORKING.**

The last confirmed user observation before moving on was effectively:

```text
still waiting / no live tabs
```

The newest DevTools-port changes were generated after that observation, but the user has not yet confirmed that they fixed tab discovery.

## Expected behavior if it works

The user should not need to manually scan.

For apps already running before the DevTools/accessibility launch flags existed:

- AT-SPI may still discover them automatically.
- DevTools cannot retroactively add a debug port to an already-running singleton process.
- One close/reopen through AppControl may be necessary for that app.
- After that, discovery should be automatic.

## Next debugging step if TABS is still blank

Do not add another blind fallback first.

Instrument the provider output visibly/log it:

```text
bridge ready?
libatspi app count?
libatspi node count?
PAGE_TAB count?
Kitty sockets found?
DevTools ports found?
GET /json/list target count per port?
```

Then verify each provider independently.

A useful debug panel/log payload should show something like:

```text
LIBATSPI: 0 TABS / 14 APPS / 12000 NODES
KITTY: 4
DEVTOOLS: 7
```

The key next question is not “can another parser be added?” but:

> **Which provider actually sees the user's running apps and what does its raw tree/target list contain?**

---

# 20. THERMAL mode

## Main mode

THERMAL has two sub-modes:

```text
THERMAL
FANS
```

Indices:

```qml
thermalViewThermal = 0
thermalViewFans    = 1
```

THERMAL mode rail icon:

```text
🌡
```

FANS uses boxed:

```text
✇
```

## Temperature display

Menu:

```text
°F / °C
```

Control panel:

- Fahrenheit is the dominant large reading.
- Celsius is a smaller secondary reading near its upper-right.

The Celsius secondary reading was repeatedly adjusted because it escaped the metric box.

## Temperature color ladder

Current thermal color mapping:

```text
< 30°C   white
< 40°C   yellow
< 50°C   omnitrix
< 60°C   cyan
< 70°C   orange
< 80°C   magenta
>=80°C   red
```

This drives:

- thermal icons
- thermal text
- metric cards
- thermal bars
- thermal bar glow
- thermal favorite/watch stars

Fans remain Omnitrix-oriented rather than temperature-colored.

## Thermal contribution caveat

The UI can show processes contributing to active CPU load near thermal sensors, but Linux generally does **not** expose a direct “PID contributed X°C” measurement.

Current notes explicitly treat process thermal contribution as an estimate.

---

# 21. FANS sub-mode and fan control

## Data source

Fans are discovered from hwmon, including values such as:

```text
fan RPM
PWM value
PWM percentage
pwm_enable
pwm path
pwm_enable path
control available
control writable
```

## Safety / availability

Fan controls are only enabled if the relevant files exist and are writable by the current user:

```text
/sys/class/hwmon/hwmonN/pwmN
/sys/class/hwmon/hwmonN/pwmN_enable
```

If not writable, UI stays disabled instead of pretending to modify the fan.

## Existing fan modes/actions

The Python control backend supports:

```text
auto
manual
boost
max
set
```

`manual` enters manual mode conservatively without lowering the current duty.

`set` writes a percentage converted to `0..255`.

## Latest fan speed slider

The newest file replaces the passive fan-speed bar with a real slider.

Features:

```text
click anywhere on bar -> set percentage
drag handle          -> preview/set percentage
mouse wheel          -> +/- 5%
```

Slider handle uses boxed/fan symbol:

```text
✇
```

The slider only enables when:

```text
sensorKind == "fan"
controlWritable == true
```

When set:

```text
pwm_enable -> manual
pwm        -> requested duty
```

## Latest status

**Implemented but not yet user-confirmed after the final patch.**

Be conservative around fan control. Never bypass write-permission checks.

---

# 22. KILL mode / task manager

KILL evolved from a placeholder destructive mode into a basic task manager.

## Process backend

Task data comes from Linux process information and monitor scripts.

Current process records include data such as:

```text
PID
PPID
USER
STATE
CPU
MEM
RSS
VSZ
THREADS
ELAPSED / UPTIME
COMM
ARGS
```

## KILL result icon

Process/task icon was changed to:

```text
(╭ರ_•́)
```

## Control panel layout

The KILL control panel contains:

- process identity
- process state metrics
- CPU graph
- memory graph
- task/process controls
- END PROCESS / KILL
- grey technical metadata moved to the very bottom

The user explicitly wanted the grey low-level metadata to stay **below all current and future control buttons**.

---

# 23. KILL graphs

This subsystem repeatedly regressed visually and should be handled carefully.

## Historical bugs

- Graphs did not update.
- Later they updated but had hard-cut glows.
- Some patches gave the line a dark/black center with a colored glow around it.
- Patches sometimes changed line color unexpectedly.
- Range was too insensitive, so graph motion looked flat.
- The user provided Windows Task Manager references and wanted more visible movement.

## Faster selected-process sampling

A later implementation added a separate selected-PID probe around:

```text
450 ms
```

using `/proc/<pid>/stat` tick deltas.

Task list refresh is slower and separate from graph sampling.

The CPU calculation is normalized to approximately a Windows-Task-Manager-style aggregate `0..100%` scale rather than “100% per core” top-style semantics.

## Current graph style

The latest file explicitly paints with Canvas:

- subtle same-hue grid
- translucent area fill under the line
- same-color wide halo trace
- same-color narrow core trace

The important anti-regression rule is:

> **Do not use a black/dark core plus colored halo. Core and halo must be the same QColor.**

The latest code obtains:

```qml
const graphColor = Colors.orange.toString()
```

or:

```qml
const graphColor = Colors.magenta.toString()
```

and uses the same value for:

```text
fill
halo trace
core trace
```

## Current big graph colors

```text
CPU     orange
MEMORY  magenta
```

## Filled graph

The latest requested style is closer to Windows Task Manager:

- colored line
- translucent filled area underneath

This is implemented in the current file.

## Current status

**Implemented in the newest file but not yet runtime-confirmed after the last request.**

---

# 24. KILL mini graphs in process buttons

The latest file adds mini per-process CPU graphs to KILL result rows.

## Data model

Per-PID history:

```qml
property var taskMiniCpuHistories: ({})
```

History length:

```text
48 samples
```

The whole object is reassigned after each process snapshot so Canvas bindings get notified.

## Rendering

Each KILL row gets:

- small right-side graph box
- line
- translucent fill below line
- same-hue line/glow
- dynamic local auto-range

Current accent behavior:

```text
normal/light load -> magenta
heavier threshold -> red
```

The exact current mini-graph threshold in the latest code should be read from the QML if adjusting.

## Current status

**Implemented in the newest file but not yet runtime-confirmed.**

---

# 25. KILL process favorites and metric watch system

## Persistent process favorite identity

Process favorites should survive process death.

They are keyed by a persistent process identity rather than PID.

When a watched process exits, FAVORITES can retain an offline synthetic record:

```text
WATCHED PROCESS
NOT RUNNING
FAVORITE RETAINED
```

When the process returns, it should reconnect to the live matching process.

## Per-metric favorites

Task metrics can be independently favorited/watched.

Current tracked metric IDs include:

```text
cpu
mem
rss
threads
pid
uptime
```

Critical checks currently include:

```text
CPU      >= 80%
MEM      >= 80%
RSS      critical when process MEM% >= 80%
THREADS  >= 256

PID / UPTIME:
  favorite/watchable
  not treated as high-threshold metrics
```

## Notifications

Critical watched process metrics currently call:

```bash
notify-send -u critical -a AppControl ...
```

with a per-watch cooldown of:

```text
60 seconds
```

This is the first real notification behavior in the project.

Long-term intent is a dedicated AppControl notification system.

---

# 26. THERMAL / SYSTEM favorite watch boxes

Thermal/system panel metric boxes can be individually favorited.

Stored in:

```text
favoriteMonitorBoxKeys
```

Key concept:

```text
watchbox|thermal|<entry>|<box>
watchbox|system|<entry>|<box>
```

Favorited stars inherit the metric/component accent rather than becoming generic magenta.

THERMAL stars can therefore follow the live thermal color ladder.

These watches are intended to feed future threshold notifications.

---

# 27. SYSTEM mode

SYSTEM is a component-oriented system monitor rather than a process list.

Current component families include:

```text
CPU
MEMORY
SWAP
STORAGE
NETWORK
GPU where available
other detected system records
```

Example system accent mapping:

```text
CPU      orange
MEMORY   magenta
GPU      omnitrix
STORAGE  cyan
NETWORK  blue
SWAP     yellow
```

Current icons are symbolic terminal-style glyphs.

## Process/app contributors

The SYSTEM panel attempts to show processes consuming a component's resource where meaningful.

Examples:

```text
CPU:
  processes with nonzero CPU

MEMORY:
  processes sorted by RSS

SWAP:
  processes with VmSwap

THERMAL/FAN:
  CPU-active processes shown as estimates, not direct physical attribution
```

## Process termination from SYSTEM

Process/app contributor rows can expose TERM controls where the current user can signal the process.

Unsupported actions are greyed/disabled.

---

# 28. SYSTEM component controls

Current component actions include combinations of:

```text
DISCONNECT
RECONNECT
REBOOT
```

depending on capability.

## Network

Uses:

```bash
nmcli device disconnect <target>
nmcli device connect <target>
```

when available.

## Reboot

Uses:

```bash
systemctl reboot
```

Current safety UX:

- explicit warning header
- reboot controls use destructive red hover
- black text on red hover
- red glow
- requires a second confirmation click within a short time window

The reboot button should never visually resemble an ordinary harmless action.

---

# 29. Running-state / process-state color language

Established APPS Running State:

```text
window count       magenta + magenta glow
WINDOW/WINDOWS     white + cyan halo
WORKSPACE(S)       orange + orange glow
workspace numbers  orange
```

WINDOW STATE was made a sibling equivalent to RUNNING/COMMAND/PROCESS state sections.

The user asked for state headings/glows to look consistent between:

```text
RUNNING STATE
COMMAND STATE
WINDOW STATE
PROCESS STATE
```

Avoid one-off opacity or glow differences unless intentionally mode-colored.

---

# 30. Scrollbars

Custom scrollbars are a major visual element.

General selector scrollbar historically:

```text
cyan track
magenta handle
```

Special requested palettes:

## THERMAL

```text
track   orange
handle  yellow
```

applies only in the THERMAL menu/control panel.

## KILL

Originally changed to:

```text
track   red
handle  cyan
```

then later requested:

```text
track   red
handle  magenta
```

The current source file is authoritative; the latest request before this transfer was magenta handles.

Do not globally recolor all scrollbars when changing a special mode.

---

# 31. Application/window icon glow system

This is one of the most important stability areas.

## Historical native crash

A critical Quickshell crash occurred when the app icon glow Canvas did this:

```text
Quickshell.iconPath()
-> image://icon/...
-> Canvas.loadImage(...)
```

The same icon provider was effectively loaded twice / through an unsafe path.

## Stable architecture

Current safe pipeline:

```text
visible Image
  -> requests Quickshell.iconPath() exactly once

Image.grabToImage()
  -> creates in-memory snapshot

Canvas
  -> samples ONLY the in-memory grab URL
```

### Absolute rule

> **Canvas MUST NEVER call `loadImage(Quickshell.iconPath(...))`.**

Never reintroduce direct Canvas loading of `image://icon/...`.

## Icon glow color classifier

Approximate dynamic mapping:

```text
red                        -> red
orange / yellow            -> orange
green                      -> omnitrix
cyan / blue                -> cyan
black/indigo/purple/pink   -> magenta
bright/white               -> white classification
gray/dark monochrome       -> magenta
```

White icon halo is often rendered as cyan in UI.

Accent detection prioritizes saturated accent pixels over neutral mass.

## Cache

Icon glow colors are cached by icon source.

---

# 32. HIDDEN/icon overlay bug history

A recurring bug showed the app-control/HIDDEN fallback icon **behind every real icon**.

Symptoms:

```text
normal app icon + fallback glyph behind it
Flatpak app icon + fallback glyph behind it
other menus contaminated too
```

Fix direction:

- strict `hiddenFallbackActive` boolean
- source item must actually have `_hiddenCommand === true`
- real icon source must be empty
- source mode/context must be HIDDEN/FAVORITES where appropriate
- fallback z lower
- real icon z higher

The HIDDEN fallback is now the face:

```text
|ω-ς)
```

not the APPS cross glyph.

If this returns, inspect fallback visibility conditions before touching opacity.

---

# 33. FAVORITES / KITTY / HIDDEN blinking faces

There are separate independent blink systems.

## FAVORITES

Own click-pulse/blink state.

## KITTY

Own independent random timing.

It should not blink in lockstep with FAVORITES.

## HIDDEN

Own independent random single/double blink timing.

Current HIDDEN face states:

```text
idle   |ω-ς)
open   |ω･`ς)
```

Hover or selection uses the open-eye version.

---

# 34. Sway IPC and Mod+D

Current Quickshell IPC target:

```qml
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
```

Sway owns the global keybinding.

The user reported that arrangement works.

Do not overwrite it with a different global-key ownership model unless asked.

---

# 35. Process / shell helpers

## `shellQuote`

There was a serious historical duplicate-function regression.

The project must contain exactly one root helper:

```qml
function shellQuote(value) {
    return "'" + String(value || "").replace(/'/g, "'\\"'\\"'") + "'";
}
```

### Absolute rule

> **Never add a second root `shellQuote`.**

A duplicate caused a broken generated file in the Flatpak/Bottles phase.

Current file validation should always include:

```text
shellQuote definition count == 1
```

---

# 36. Destructive-action safety rules

Keep these distinctions intact:

```text
RUN KILL:
  TERM
  stays in menu

HIDDEN KILL:
  TERM for current user's matching command

KILL task manager:
  TERM where signalable

WINDOW KILL:
  Sway compositor kill

SYSTEM REBOOT:
  systemctl reboot
  destructive warning
  confirmation gate

Fan controls:
  only writable hwmon paths
```

Do not silently upgrade TERM actions to SIGKILL.

---

# 37. Current visual icons worth preserving

This project uses many exact glyphs that the user cares about.

## Main rail

```text
FAVORITES  (˵✧ᴗ✧˵)
APPS       -⋆♱⋆-
RUN        ⌯✎﹏﹏
WINDOWS    🃁🂡🂱🃑
THERMAL    🌡
KILL       (-_•)︻デ═一
SYSTEM     🖳
```

## HIDDEN

```text
idle            |ω-ς)
hover/selected  |ω･`ς)
```

## KILL favorites sub-filter

```text
⌐╦╾━
```

## Fan

```text
✇
```

inside a box where requested.

## Toolbox selector

```text
🛠
```

inside a box.

## Bottles selector/panel

```text
⚱  ⚱  ⚱
```

with larger center urn.

## App launch

```text
normal    ⌯♱ ๋࣭⭑
Flatpak   ⌯✉︎๋࣭⭑
```

## RUN command control

```text
⌯✎﹏﹏
```

## Window Focus / task icon

```text
(╭ರ_•́)
```

## Window move

```text
જ⁀➴
```

## Float

```text
⊹ ࣪ ˖🕊⋆₊⊹
```

## Fullscreen

```text
🂡🂱🃑🂭🂽
```

---

# 38. Header text / ornate selector strings

Preserve exact ornate selector headers unless deliberately redesigning.

## APPS

```text
- ༘⋆₊⊹Pick an App any App ๋࣭ ⭑⋆｡˚-
```

## RUN

```text
- ༘⋆₊⊹Run Command, Run! ๋࣭ ⭑⋆｡˚-
```

## FAVORITES

```text
- ༘⋆₊⊹All Your Favorites! ๋࣭ ⭑⋆｡˚-
```

The old prompt:

```text
|合| ✧>
```

was explicitly removed.

Do not restore it.

---

# 39. Control-pane header geometry

The header title is centered over the entire control pane.

Important prior fix:

- left/right header icons sit in equal side regions
- icons moved outward
- right icon mirrored inward
- title is not centered only in leftover space

Do not regress to a visibly off-center title when changing ornaments.

---

# 40. Search field geometry

APPS title and search input were intentionally separated geometrically.

Established APPS geometry:

```text
title slot:
  top margin ~9
  height ~22

search input:
  bottom margin ~3
  height ~22
```

Search cursor is a sibling overlay rather than relying on the default cursor.

This was needed for the visual underline/cursor behavior.

---

# 41. Current task/favorite notification direction

Current real notification behavior exists only for process metric watches through `notify-send`.

Long-term planned direction:

- favorited thermal boxes
- favorited system boxes
- process metrics
- threshold settings
- dedicated AppControl notification surface

The data model already keeps enough persistent favorite/watch keys to build this later.

Avoid throwing away those keys in a UI refactor.

---

# 42. What has been user-confirmed working

The following behaviors were explicitly confirmed or strongly established during iteration.

## Confirmed / stable enough

### APPS basics

- real desktop-entry list
- real icons/names
- search/filter
- click/Enter launch
- metadata/control pane
- app ↔ Sway window matching

### Mouse/keyboard result arbitration

User said the pointer/keyboard behavior was “perfect” after the dedicated fix.

### Mod+D / IPC

Reported working.

### Preferred control-action favorite system

The direct-star architecture worked.

### Enter from APPS/RUN selector

Saved preferred action executes directly.

### Enter from FAVORITES app/RUN rows

The source-type gate fix worked.

### Sway windows

Real window selection/control behavior is established.

### Task graphs

At one point user confirmed graph **updating** was fixed.

Visual behavior has continued to evolve after that.

### SYSTEM / THERMAL data

Screenshots showed live task/system/thermal data and graph updates.

---

# 43. Implemented but not yet confirmed after latest patch

These are especially important in a new chat.

## Latest graph fill / mini graphs

Implemented:

- filled big task graphs
- same-color line/glow
- mini per-process KILL graphs

**No user confirmation yet after the newest file.**

## Fan speed slider

Implemented:

- click
- drag
- wheel
- PWM `set`

**No user confirmation yet after the newest file.**

## FAVORITES mode filter buttons

Implemented:

```text
ALL / APPS / RUN / WINDOWS / THERMAL / KILL / SYSTEM
```

**No user confirmation yet.**

## TABS newest provider combination

Still not confirmed.

The last direct user observation was that tab discovery was stuck waiting.

---

# 44. Known unresolved / fragile areas

## 1. TABS — highest-priority unresolved functional issue

Status:

```text
NOT USER-CONFIRMED
```

It has multiple sophisticated provider attempts but still needs real diagnostics against the user's running Brave/Code/Kitty environment.

Next chat should not assume it is solved.

## 2. Fan control

The slider backend exists, but actual hardware behavior depends on:

- driver
- PWM channel
- permissions
- hwmon semantics

Some drivers use different `pwm_enable` values.

The current code assumes common Linux hwmon convention:

```text
1 manual
2 automatic
```

This is not universal.

## 3. Bottles launch target model

The app-name → Bottles program assumption remains a limitation.

No full bottle/program browser yet.

## 4. SYSTEM component “reboot/reconnect” semantics

Only operations actually supported by detected backend should be enabled.

Do not imply arbitrary hardware can be power-cycled independently.

## 5. Thermal process attribution

Current process “thermal contributors” are estimates based on activity, not direct heat ownership.

## 6. Window CENTER

Not a true toggle.

It is currently closer to:

```text
floating enable + center
```

## 7. Graph color/glow regression risk

Canvas/layer changes have repeatedly reintroduced:

- dark center
- black lines
- mismatched halo
- hard clipping

Use the latest explicit Canvas same-color fill/trace approach.

## 8. Sub-menu fade regression risk

Repeatedly returned across patches.

Do not casually replace the sibling-shadow sub-mode architecture with `layer.effect`.

## 9. HIDDEN fallback overlay risk

Previously appeared behind all icons.

Keep strict fallback visibility and z ordering.

---

# 45. Major breakages and how they were fixed

This section is useful because many regressions came from repeating an old approach.

## A. Quickshell native icon crash

### Problem

Canvas directly loaded Quickshell icon-provider URLs.

### Bad pattern

```text
Canvas.loadImage(Quickshell.iconPath(...))
```

### Fix

```text
Image loads icon
Image.grabToImage()
Canvas samples in-memory grab URL
```

### Rule

Never load the original `image://icon/...` source in Canvas.

---

## B. Duplicate `shellQuote`

### Problem

A generated Flatpak/Bottles file added a second root `shellQuote` and broke QML parsing.

### Fix

Use the original helper only.

### Rule

Check:

```text
function shellQuote( count == 1
```

---

## C. Control-panel favorite Loader system

### Problem

The first reusable Loader/Component star implementation matched partial IDs and bound stale/dynamic indexes incorrectly.

### Fix

Put a direct favorite star in every relevant action button.

### Rule

Do not restore the Loader favorite architecture.

---

## D. FAVORITES preferred-action Enter

### Problem

Helper only allowed:

```text
selectedModeIndex == APPS or RUN
```

so favorites rows never used their source item's preferred action.

### Fix

Check actual source type:

```text
selectedResultIsApplication()
selectedResultIsRun()
```

instead of selected menu mode.

---

## E. Floating Sway clients missing

### Problem

Tree collector lost floating state through wrapper nodes and rejected sparse-identity windows.

### Fix

Carry inherited floating state through `floating_con` / `floating_nodes`, accept live PID+title identity.

---

## F. Ctrl+Left / Shift+Left eaten by TextInput

### Problem

Text editing consumed the shortcut before AppControl.

### Fix

ShortcutOverride handling + explicit handleKey routing.

---

## G. Tab providers unavailable

### Problem

Sway cannot see app tabs; GI AT-SPI not always available.

### Attempts

- Python GI/Atspi
- raw gdbus tree traversal
- AT-SPI cache
- accessibility runtime enabling
- persistent ctypes/libatspi client
- DevTools
- Kitty remote control

### Current lesson

Instrument provider counts before adding another abstraction.

---

## H. Sub-mode buttons go grey when mouse leaves

### Problem

Several button families used different `layer.effect` / opacity paths and fell into faded states.

### Fix direction

Use explicit state color + sibling DropShadow like known-good RUN buttons.

### Contract

```text
inactive own accent
hover orange
selected magenta
selected/hover yellow fill
```

---

## I. HIDDEN/app icon duplicated behind real icons

### Problem

Fallback glyph visibility was too broad.

### Fix

Strict `_hiddenCommand` + no-real-icon + correct mode context + z ordering.

---

## J. Task graph dark center

### Problem

DropShadow/layer-based graph rendering produced a black-looking line core.

### Fix

Paint the line in Canvas twice with the **same QColor**:

```text
wide low-alpha halo
narrow full-alpha core
```

Latest version also fills under the line.

---

## K. Task graph too flat

### Problem

Range was too broad and refresh too slow.

### Fix

- faster selected-PID sampling
- local auto-range
- longer right-to-left history
- separate graph sampling from full process-list refresh

---

## L. Thermal/system card glow clipping

### Problem

High sample radius/spread + clipped wrappers created hard-cut glows.

### Fix direction

Lower sample/spread and ensure glow wrapper has padding/room.

Do not increase sample count as the first response to “glow too weak.”

---

# 46. Current generated-file lineage

There were many generated checkpoints. Important landmarks:

```text
AppControlW_run_user_terminal_system.qml
...
AppControlW_window_icon_focus_mute_rebalance.qml
AppControlW_windows_flatpak_bottles_modes.qml
    BROKEN duplicate shellQuote

AppControlW_windows_flatpak_bottles_modes_fixed.qml
AppControlW_app_bottle_alternate_run_magenta_stars.qml
AppControlW_apps_source_shortcuts_unavailable_bottles.qml

AppControlW_detail_action_favorites_glow_keyboard_fill.qml
    BROKEN reusable favorite insertion

AppControlW_favorites_fixed_orange_submode_glow.qml
    Loader favorite attempt; still not working

AppControlW_control_favorites_direct_fix.qml
    direct favorite stars — important stable architecture

AppControlW_favorite_enter_from_selector.qml
AppControlW_favorite_enter_in_favorites_menu.qml
    preferred-action FAVORITES fix

AppControlW_system_controls_thermal_fc_flatpack.qml
AppControlW_hidden_thermal_glow_controls_final.qml
AppControlW_submodes_favorites_hidden_actions.qml
AppControlW_taskgraph_hidden_favorites_scrollfix_final.qml
AppControlW_kill_watch_submode_icons.qml
AppControlW_submode_render_and_icons_fix.qml
AppControlW_hidden_overlay_mute_toolbox_fix.qml

AppControlW_tabs_working_audio_green.qml
AppControlW_tabs_cache_fix.qml
AppControlW_tabs_runtime_enable_fix.qml
AppControlW_tabs_persistent_bridge_fix.qml
AppControlW_tabs_live_libatspi_fix.qml
AppControlW_tab_provider_icons_fix.qml

CURRENT:
AppControlW_taskgraphs_fan_slider_favorite_filters.qml
```

Do not start a future patch from one of the old milestone files unless explicitly rolling back.

---

# 47. Stale comments / naming inside the current QML

Because this file evolved through many phases, some comments or internal variable names are older than the current behavior.

Examples:

- a WINDOWS/TABS comment may still describe Sway tabbed-layout containers even though the real goal became cross-application tabs
- `runListAll` may be visibly labeled SYSTEM
- earlier action-index comments may still predate COMMAND TOOLBOX insertion

When code and comment disagree:

> **Trust current executable bindings/functions first, then update the stale comment.**

---

# 48. Current validation habits

Before handing a generated QML file back, useful structural checks have included:

```text
brace balance
bracket balance
shellQuote definition count
embedded Python compile()
expected ID/function presence
```

This catches many generated-edit failures.

It does **not** guarantee Qt/QML runtime correctness.

When possible, next chat should also use:

```bash
qs -p ~/.config/quickshell/shell.qml
```

and inspect the actual QML error line.

---

# 49. Unrelated warnings seen during debugging

These existed outside AppControl and should not be mistaken for AppControl failures:

```text
Network.qml DropShadow non-parent/sibling warning
Workspaces undefined length warning
I3 event socket disconnected
```

Investigate them separately unless an AppControl edit clearly changes them.

---

# 50. What the next chat should do first

Recommended handoff workflow:

1. Upload:
   - this transfer Markdown
   - `AppControlW_taskgraphs_fan_slider_favorite_filters.qml`

2. Tell the next chat:

   ```text
   Treat the QML as source of truth.
   Read the transfer notes before editing.
   Do not recreate old architecture.
   ```

3. First runtime checks should be:
   - Does current QML load?
   - Do KILL big graphs fill correctly?
   - Do KILL mini graphs animate?
   - Does fan slider appear and is it disabled/enabled correctly?
   - Do FAVORITES filters work?
   - What exact TABS provider diagnostic/status appears?

4. For TABS specifically, collect provider diagnostics before another redesign.

---

# 51. Suggested next-debug priority

If continuing immediately, this is the best order.

## Priority 1 — TABS observability

Add a temporary diagnostic view/log with:

```text
LIBATSPI bridge ready
accessible app count
accessible node count
PAGE_TAB count
Kitty socket count
DevTools ports
DevTools target count
raw error per provider
```

Then test:

```text
Brave opened through AppControl
VS Code opened through AppControl
Kitty opened through AppControl
```

Do not hide diagnostics behind “WAITING” while debugging.

## Priority 2 — verify latest KILL graph patch

Check:

- no black center
- fill is translucent
- line/glow same hue
- mini graphs update
- mini graph does not obscure row text/star/scrollbar

## Priority 3 — verify fan slider

Check:

- writable PWM control detected
- click works
- drag works
- wheel +/-5 works
- UI refresh reflects actual PWM after write
- no fan channel can be written if permission unavailable

## Priority 4 — verify FAVORITES source filters

Check every filter with at least one favorite:

```text
ALL
APPS
RUN
WINDOWS
THERMAL
KILL
SYSTEM
```

Also test:

```text
Shift+Left cycling
keyboard-selected filter
mouse-selected filter
favorite disappearing/reappearing without losing persistence
```

---

# 52. “Do not regress” checklist

This is the compact list to keep next to the code while editing.

- Never call `Canvas.loadImage(Quickshell.iconPath(...))`.
- Keep exactly one root `shellQuote`.
- Current Quickshell target is 0.3.1 / Qt 6.11.2.
- Do not invoke Rofi.
- Do not use image generation for QML work.
- Opening defaults to APPS.
- FAVORITES stays visually first.
- Result selected fill remains yellow, selected text orange.
- Keep full-width result delegate + inner button gap.
- Preserve mouse/keyboard ownership behavior.
- Preserve permanent result top gap.
- Preserve search cursor sibling overlay.
- Preserve centered control header geometry.
- Preserve exact ornate headers.
- RUN action order includes TOOLBOX before KILL.
- WINDOW action order remains 7 actions.
- RUN KILL uses TERM and stays open.
- WINDOW KILL uses Sway compositor kill.
- Fan writes only if hwmon files are writable.
- SYSTEM reboot remains guarded and visibly destructive.
- HIDDEN fallback must never appear behind normal icons.
- HIDDEN face uses `|ω-ς)` / `|ω･`ς)`.
- KITTY/FAVORITES/HIDDEN blink independently.
- BOTTLES icon = three urns, center larger.
- TOOLBOX icon = boxed hammer/wrench.
- BOTTLES action text/icon/glow magenta.
- TOOLBOX action text/icon/glow Omnitrix.
- WINDOW AUDIO text is Omnitrix, text/header glow green.
- KILL graph core and glow must be the same color.
- Preserve task/process favorite identity after process death.
- Preserve `favoriteTaskMetricKeys` / `favoriteMonitorBoxKeys`.
- Do not assume TABS is solved until user confirms live tabs appear.

---

# 53. Current feature/status matrix

| Area | Current status | Notes |
|---|---|---|
| APPS desktop-entry launcher | ✅ established | real DesktopEntries |
| APPS source NORMAL/FLATPAK | ✅/🟡 | established, source-gating has evolved |
| APPS HIDDEN | ✅/🟡 | real `$PATH` commands; fallback face system |
| APPS Bottles | 🟡 | CLI integration, target-name limitation |
| APPS Toolbox | 🟡/✅ | implemented and used repeatedly |
| RUN USER/TERMINAL/SYSTEM | ✅/🟡 | core working, SYSTEM internal name `runListAll` |
| RUN Kitty/Float/Fullscreen | ✅/🟡 | established |
| RUN Toolbox action | 🟡 | implemented later |
| RUN TERM kill | ✅/🟡 | implemented, non-SIGKILL |
| Sway WINDOWS | ✅ | real live window backend |
| Window actions | ✅/🟡 | focus/move/float/fullscreen/center/mute/kill |
| Window mute glow | 🟡 | latest green halo fix |
| TABS | 🔴/🟡 unresolved | newest provider architecture not confirmed |
| KILL task manager | ✅/🟡 | real data and graphs |
| Big graph area fill | 🟡 | newest patch, not confirmed |
| KILL mini graphs | 🟡 | newest patch, not confirmed |
| Process metric favorites | 🟡/✅ | persistence/notify implemented |
| Thermal sensors | ✅/🟡 | real hwmon/thermal data |
| Thermal color ladder | ✅/🟡 | implemented |
| Fan mode buttons | 🟡 | depends on writable hwmon |
| Fan speed slider | 🟡 | newest patch, not confirmed |
| SYSTEM components | ✅/🟡 | CPU/MEM/SWAP/storage/network/etc. |
| SYSTEM process contributors | 🟡 | best-effort Linux attribution |
| SYSTEM disconnect/reconnect | 🟡 | `nmcli` where supported |
| SYSTEM reboot | 🟡 | two-step destructive action |
| Cross-mode FAVORITES | ✅/🟡 | expanded persistence architecture |
| FAVORITES source filters | 🟡 | newest patch |
| Preferred detail-action stars | ✅ | direct-star architecture confirmed |
| Mod+D IPC | ✅ | user-confirmed |
| Safe icon sampling | ✅ critical | do not change architecture |

Legend:

```text
✅ established / user-confirmed or repeatedly working
🟡 implemented, partially proven, or latest patch not yet confirmed
🔴 known unresolved
```

---

# 54. Current source-of-truth metadata

Use this to verify the correct handoff file:

```text
filename:
AppControlW_taskgraphs_fan_slider_favorite_filters.qml

bytes:
840,592

lines:
20,589

sha256:
b431e2dfdb01fbd466b3f605dd4b52fade651b42cff9956ac45ecd507959c4f4
```

If the uploaded QML in the new chat does not match this hash, treat the uploaded file as newer only if the user says it is the new source of truth.

---

# 55. Short prompt to paste into the next chat

```text
This is my AppControlW Quickshell project transfer.

Read the attached PROJECT_TRANSFER.md first, then treat the attached
AppControlW_taskgraphs_fan_slider_favorite_filters.qml as the current
source of truth.

Do not rebuild from old snippets and do not invoke Rofi. Preserve the
safe icon-grab architecture, direct control-action favorite stars,
mouse/keyboard arbitration, mode/submode visual contract, and exact
mode/action ordering documented in the transfer.

Anything marked latest/unconfirmed should be tested before assuming it
works. TABS is still unresolved until I explicitly confirm live tabs
appear.
```

---

# 56. Final handoff note

This project has reached the point where it is effectively a small desktop-control application rather than a launcher.

The most important engineering lesson from the work so far is:

> **Preserve stable subsystems and debug the specific backend that is failing instead of repeatedly rewriting the whole widget.**

The user is happy to iterate visually, but regressions have usually happened when a global search/replace or generalized abstraction touched unrelated controls.

For future work:

- patch the smallest relevant block
- validate IDs and delimiters
- keep destructive actions conservative
- preserve persistence keys
- do not replace confirmed interaction architecture
- test one subsystem at a time
