# AppControl / Quickshell Launcher — Complete Project Handoff & Recovery Notes

**Snapshot:** 2026-09-11  
**Project:** Fedora Silverblue + Sway + Quickshell custom desktop/rice  
**Primary widget:** `~/.config/quickshell/widgets/AppControlW.qml`  
**Launcher button:** `~/.config/quickshell/modules/Applauncher.qml`  
**Current Quickshell:** 0.3.1 on Qt 6.11.2  
**Purpose of this document:** preserve enough technical, visual, architectural, and debugging context to resume work in a brand-new chat without re-discovering the same problems.

---

# 0. Read This First — Source-of-Truth Rules

This project changed very quickly and many intermediate files were generated while debugging. If two notes disagree, use this order:

1. **The user's current local file / newest file they explicitly say to use.**
2. **The newest generated `AppControlW.qml` in the current conversation.**
3. **A behavior the user explicitly confirmed as correct.**
4. Older generated AppControl files.
5. Historical dossiers / old Rofi / old Messaging notes.

The latest generated AppControl snapshot in this conversation is:

```text
AppControlW_modd_ipc_lower_icon_samples.qml
```

It was generated from:

```text
AppControlW_running_state_color_tune.qml
```

and contains the current AppControl widget state plus a Quickshell IPC endpoint for Sway.

**Important Mod+D note:** the user confirmed Mod+D works, but said they configured it "a bit different" from the suggested Sway binding. The exact final local Sway line is therefore **not captured here**. Preserve the fact that it works; do not overwrite it blindly.

---

# 1. What AppControl Is

AppControl is a **Quickshell-native application launcher and control surface**.

It is **not Rofi** and must not invoke Rofi. Rofi is only visual/reference ancestry.

The intended relationship is:

```text
Sway
  ↓
Quickshell
  ↓
AppControlW.qml
  ├── FAVORITES
  ├── APPS
  ├── RUN
  ├── WINDOWS
  └── KILL
```

The project philosophy is:

> Quickshell is the graphical presentation/orchestration layer over normal Linux services and compositor facilities. Do not unnecessarily rewrite backend services.

For AppControl specifically:

- Quickshell renders the UI.
- `DesktopEntries` supplies applications.
- Sway/I3 IPC supplies live windows/workspaces.
- Sway owns global keybindings.
- Future RUN will execute normal shell/desktop commands.
- Future KILL will use appropriate close/terminate/force mechanisms rather than inventing a fake process manager.

---

# 2. Desktop / Environment

Current environment:

```text
OS: Fedora Silverblue 44
Compositor: Sway / wlroots
Shell UI: Quickshell
Quickshell: 0.3.1
Qt: 6.11.2
Terminal: Kitty
Multiplexer: Zellij
Editor: Neovim
File manager/TUI: Yazi
Monitoring: btop / htop / similar
```

Fedora Silverblue matters because the host is immutable-ish and does **not** use ordinary `dnf` in the same way as Fedora Workstation.

Quickshell was originally:

```text
0.2.1
```

from the Fedora package, then upgraded using a COPR to:

```text
Quickshell 0.3.1
Qt 6.11.2
```

The newer version includes the I3/Sway integration being used here.

---

# 3. Project Layout

Current conceptual tree:

```text
~/.config/quickshell/
├── components/
│   ├── Colors.qml
│   └── ...
├── modules/
│   ├── Applauncher.qml
│   └── ...
├── services/
│   └── ...
├── widgets/
│   ├── AppControlW.qml
│   └── messanger/
│       └── ...
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

The `W` suffix means **Widget**.

Because `AppControlW.qml` is directly inside `widgets/`:

```qml
import "../components"
```

is correct from inside that file.

`shell.qml` needs:

```qml
import "widgets"
```

and instantiates the widget approximately as:

```qml
AppControlW {
    id: appControlWindow
}
```

`Applauncher.qml` receives the window reference:

```qml
property var appControlWindow
```

and left click toggles:

```qml
appControlWindow.menuOpen
```

---

# 4. Design Language

The visual language is a combination of:

- Christian/celestial symbolism
- night sky / space
- retro computing
- terminal / ASCII / CRT
- old televisions / PCs
- neon / synthwave
- retro American / Japanese flavor
- games / anime / comics
- HUD / instrument-panel feeling

Do **not** describe the design as occult/gothic.

The UI should feel like a machine console or instrument panel rather than a standard desktop menu.

General rules:

- square geometry
- thin dividers
- glow-driven hierarchy
- monospace/pixel feel
- restrained but expressive animation
- mouse and keyboard should represent the same state
- no generic modern rounded-card UI unless specifically requested

Font:

```text
GohuFont 11 Nerd Font Mono
```

---

# 5. Palette

Current singleton:

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
Colors.black
```

is a deep purple, not literal black.

There is no canonical:

```text
Colors.background
```

Semantic meaning:

```text
cyan      normal / data / interface / information
orange    active / focus / hot / important
yellow    selected / emphasis
magenta   pressed / special / alternate / sampled special state
red       destructive / error / danger
white     neutral / context
omnitrix  vivid green / special green state
black     deep purple base
dark      darker purple base
```

Avoid hardcoded literal colors in UI code unless absolutely necessary. Prefer `Colors.*`.

---

# 6. Small AppLauncher Button

The small bar launcher button and the large AppControl widget are separate.

Current desired small launcher behavior:

```text
fill: fixed Colors.black
glyph: fixed Colors.white
idle glow: Colors.cyan
hover glow: Colors.orange
pressed glow: Colors.magenta
```

Do not automatically propagate that exact state language to every other widget.

---

# 7. Window Placement / Base Geometry

AppControl currently sits near the top-left.

Accepted placement:

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

Approximate outer native/window size during current development:

```text
~834 × 674
```

Visible UI body is approximately:

```text
~810 × 650
```

There are transparent margins around parts of the body to make room for glow.

The user prefers changing typography/layout internally rather than simply making the whole menu wider.

---

# 8. Modes

Mode constants:

```qml
readonly property int favoritesModeIndex: 0
readonly property int appsModeIndex: 1
readonly property int runModeIndex: 2
readonly property int windowsModeIndex: 3
readonly property int killModeIndex: 4
```

Modes:

```qml
property var modes: [
    { name: "FAVORITES", symbol: "(˵✧ᴗ✧˵)" },
    { name: "APPS",      symbol: "-⋆♱⋆-" },
    { name: "RUN",       symbol: "⌯✎﹏﹏" },
    { name: "WINDOWS",   symbol: "🃁🂡🂱🃑" },
    { name: "KILL",      symbol: "(-_•)︻デ═一" }
]
```

FAVORITES is first visually, but opening AppControl defaults to APPS:

```qml
property int selectedModeIndex: appsModeIndex
```

Do **not** accidentally write future mode logic assuming:

```text
index 0 == APPS
```

That was true in old versions and is no longer true.

Always use named constants.

---

# 9. Current Mode Status

## FAVORITES

Partially implemented and functional.

Already has:

- persistent favorite storage
- favorite stars
- app favorites
- favorites aggregated from all modes
- favorite sorting/pinning in APPS
- temporary support for placeholder RUN/WINDOWS/KILL entries

Still needs:

- real RUN favorite identities
- real WINDOWS favorite identities/behavior
- real KILL favorite identities/behavior
- final behavior when destructive favorites are selected
- final right-panel metadata for mixed favorite types

## APPS

This is the most complete mode and should be treated as the **reference implementation**.

Working:

- real desktop app model
- real names
- real icons
- filtering/search
- alphabetical sorting
- favorite pinning
- app metadata
- desktop actions
- launch
- keyboard navigation
- mouse navigation
- live Sway running-state display
- workspaces
- dynamic sampled icon glow
- adaptive app-name sizing in the App Control panel
- fixed-size ellipsis behavior in selector rows

## RUN

Still mostly placeholder content.

Future implementation should become a real command launcher.

## WINDOWS

Still mostly placeholder content in the main selector, even though the APPS detail panel already has a real Sway tree backend.

Future implementation should list real windows.

## KILL

Still placeholder.

Future implementation should be deliberately destructive-safe.

Planned action progression:

```text
CLOSE → TERM → FORCE
```

FORCE should require confirmation.

---

# 10. APPS Backend

APPS uses Quickshell desktop entry support.

Core idea:

```qml
DesktopEntries.applications
```

The model excludes hidden/no-display entries naturally or via filtering and builds a searchable ScriptModel.

Search should consider things such as:

- application name
- generic name
- comment
- keywords

Results are alphabetized.

Desktop entries are real launchable entries:

```qml
entry.execute()
```

Selecting/launching an app closes AppControl.

---

# 11. App Overrides

There is a future-facing override system:

```qml
property var appOverrides: ({})
```

Helpers include:

```text
appOverride()
appDisplayName()
appDisplayDescription()
appLongDescription()
appDisplayIcon()
appIconSource()
```

This allows later customization of names/descriptions/icons without changing the actual `.desktop` files.

Icon source helper currently follows the pattern:

```qml
if (!icon)
    return "";

if (icon.indexOf("/") === 0 || icon.indexOf("file:") === 0)
    return icon;

return Quickshell.iconPath(icon, true);
```

---

# 12. Selector Search / Results Behavior

Selector rows are fixed-height and visually uniform.

The user explicitly preferred:

- unified selector font size
- trailing `...` on long names

over shrinking every selector result differently.

Current selector app name behavior:

```text
font size: 17px
long names: Text.ElideRight
```

Do **not** restore adaptive shrinking in the selector unless requested.

The adaptive shrinking is only for the larger selected-app name in the right App Control panel.

---

# 13. Adaptive App Name in App Control Panel

The large selected app name on the right keeps a normal large size but shrinks if needed.

Current behavior:

```qml
font.pixelSize: 22
fontSizeMode: Text.HorizontalFit
minimumPixelSize: 13
elide: Text.ElideRight
```

Intent:

- normal app names remain large
- long names shrink before truncation
- panel width stays fixed
- extreme names can still ellipsize as a last resort

This was chosen specifically because the user preferred changing font size rather than menu size **in the App Control panel only**.

---

# 14. Selector Header

APPS does not simply say `APPS`.

Current decorative title:

```text
- ༘⋆₊⊹Pick an App any App ๋࣭ ⭑⋆｡˚-
```

Other modes use their normal names.

APPS title font:

```text
16px
```

Other mode title font:

```text
19px
```

A major layout bug occurred when the ornate combining glyphs changed title metrics and caused the search input to move vertically between modes.

The fix was to stop using a title/input layout whose implicit heights drove each other.

Current architecture:

```text
fixed selectorTitleSlot
fixed searchInput
independent anchors
```

Approximate title slot:

```qml
anchors.left: parent.left
anchors.right: parent.right
anchors.top: parent.top

anchors.leftMargin: 15
anchors.rightMargin: 15
anchors.topMargin: 9

height: 22
```

Search input is independently bottom-anchored inside the header.

**Do not return to a Column where title `implicitHeight` controls search input placement.**

---

# 15. Pick-an-App Text / Decorations

The title was split into three visual parts:

```text
LEFT DECOR     CENTER TEXT             RIGHT DECOR
- ༘⋆₊⊹        Pick an App any App      ๋࣭ ⭑⋆｡˚-
```

Reason:

The user wanted the stars and outer decorative punctuation to glow more strongly than the words.

Current approach:

- left symbols have strong cyan glow
- words have softer cyan glow
- right symbols have strong cyan glow

The center words were visually too high relative to the symbols.

Current center offset:

```qml
anchors.verticalCenterOffset: 4
```

The decorative symbols stay in their original position.

---

# 16. Header Underlines

There are two horizontal header lines:

1. a line under the decorative Pick-an-App title
2. the normal line under the user text/search input

The new title underline was initially too high and was nudged downward.

Current title-divider transform:

```qml
transform: Translate {
    y: 4
}
```

It is cyan normally and becomes red in KILL mode.

It has a glow similar to other header dividers.

---

# 17. Search Text

Typed search text:

```text
magenta
```

with magenta glow.

The decorative cursor is orange.

---

# 18. Custom Search Cursor

The custom cursor went through several important failures.

Desired decorative cursor family:

```text
݁ ˖✍︎๋࣭⭑₊
```

with orange glow, blinking/wave behavior, and the decoration visually occupying the cursor area rather than reserving a huge typing width.

## Early failure: cursorDelegate inside TextInput

Initially the decorative cursor was a `cursorDelegate` inside `TextInput`.

Problem:

The `TextInput` itself had a layer `DropShadow`, and the cursor also had its own shadow.

That caused the cursor to be rendered through two glow paths and looked doubled/ghosted.

Additionally, splitting combining marks like:

```text
๋
࣭
```

into independent text items broke shaping and produced garbled/doubled-looking glyphs.

## Fix: sibling overlay

The decorative cursor was moved **outside the TextInput layer** and became a sibling overlay.

The real insertion position is tracked through:

```qml
searchInput.cursorRectangle.x
```

Current style:

```qml
x: searchInput.x + searchInput.cursorRectangle.x - 1
y: searchInput.y + 3
```

The overlay sits above the search input with a high `z`.

## Purple native cursor bug

After moving the decorative cursor outside the TextInput, the real native purple insertion bar was still visible in front of it.

Simply setting:

```qml
cursorVisible: false
```

did not produce the desired geometry behavior reliably.

Fix:

Keep cursor geometry alive but use a zero-size invisible delegate:

```qml
cursorVisible: activeFocus

cursorDelegate: Item {
    width: 0
    height: 0
    visible: false
    opacity: 0.0
}
```

The overlay remains the only visible cursor.

## Cursor vertical alignment

At one point:

```text
y +5
```

was too low.

Current offset:

```text
y +3
```

## Cursor glow

Current decorative cursor glow was increased to approximately:

```text
radius: 5
samples: 5
opacity: 0.42
color: Colors.orange
```

This can be tuned later, but avoid putting the cursor back inside the TextInput effect path.

---

# 19. Cursor Star Animation

There are multiple decorative marks around the hand glyph.

Important clarification from user feedback:

When the user said "the two closest stars" they meant the marks **behind/around the cursor hand**, not the separate leading pair.

The original leading group:

```text
݁˖
```

was restored as one intact group.

The hand itself is kept visually steady.

Combining marks around the hand must remain attached to a shaping base; do not split combining marks into standalone text items.

The close decorative marks animate in overlapping phases.

The trailing symbols such as:

```text
⭑
₊
```

also participate in an overlapping opacity wave.

While typing, decoration is more fully visible.

When idle, animation is slower and more decorative.

---

# 20. Favorites Rail Face Animation

FAVORITES symbol normally:

```text
(˵✧ᴗ✧˵)
```

Hover/click happy face:

```text
(˶ˆᗜˆ˵)
```

Blink face:

```text
(˵-ᴗ-˵)
```

## Bug: happy face got stuck

An earlier implementation used a click/hover state that latched and could remain:

```text
(˶ˆᗜˆ˵)
```

until the entire menu reopened.

Fix:

Separate short click pulse state:

```qml
property bool favoritesFaceClickPulse: false
```

with a short timer.

Hover/pressed state remains direct.

No permanent latch.

## Bug: blink became predictable

Initial blink timer:

```text
every 3.3 seconds
```

felt robotic and predictable.

Current strategy:

- no repeating metronome
- after every blink, schedule another random delay
- approximately `6.5s` to `12.5s`
- blink lasts about `170ms`

Conceptually:

```qml
favoritesFaceBlinkTimer.interval =
    6500 + Math.floor(Math.random() * 6000);
```

Hover/click takes visual priority but does not permanently disable future blinks.

---

# 21. Favorites Persistence

Favorites are stored persistently using Quickshell file/JSON facilities.

Concept:

```text
FileView
  ↓
JsonAdapter
  ↓
Quickshell.dataDir + "/appcontrol-favorites.json"
```

Persistent state contains favorite keys.

The implementation evolved from APPS-only favorites into a cross-mode system.

Core helpers include concepts equivalent to:

```text
favoriteKeyFor()
isFavoriteItem()
favoriteRecordForApp()
favoriteRecordForModeItem()
favoriteSourceMode()
favoriteSourceItem()
toggleFavorite()
```

APPS still has a small compatibility helper:

```text
isFavorite(entry)
```

for app sorting/pinning.

---

# 22. Favorite Keys

App favorites use a stable app identity derived from the desktop entry.

Non-app placeholder favorites currently use:

```text
"mode:" + modeIndex + ":" + label
```

Example:

```text
mode:2:OPTION 01
mode:3:OPTION 01
```

This prevents identical placeholder labels from different modes from colliding.

This is temporary.

When RUN/WINDOWS/KILL become real, replace placeholder-based keys with real identities.

---

# 23. FAVORITES Aggregate Mode

A `favoriteResults` ScriptModel aggregates favorites from all modes.

Current behavior:

- favorite apps appear
- placeholder favorites from RUN/WINDOWS/KILL can appear
- APPS favorites also pin to top of APPS
- FAVORITES itself displays the aggregate model

The system already wraps app records and non-app records so the favorite view can know their original source mode.

This architecture should be preserved and upgraded, not replaced with five separate favorite stores.

---

# 24. Favorite Star Visual States

Current desired star semantics:

## Untouched / not favorite

Neutral gray-ish:

```text
Colors.white at reduced opacity
```

with faint neutral glow.

## Favorite

Use the app's sampled idle icon/name color and a matching glow.

For white-classified apps:

```text
white star/text
cyan halo
```

## Unfavorite click

Temporary red/black destructive flash.

There is a short removal flash timer around:

```text
~240ms
```

Then it returns to neutral gray.

Important:

**Do not persist a red "touched but unfavorited" state.**

That was tried and removed.

---

# 25. Favorite Click Must Not Launch App

The favorite star has its own click target.

Clicking the star:

- toggles favorite
- must not trigger the row's app launch
- must not accidentally change behavior due to event propagation

Keep the star interaction independent from the main result activation.

---

# 26. Mouse / Keyboard Arbitration

This was a major polish area and the current behavior was confirmed as correct.

Requirements:

- keyboard selection and mouse hover represent the same conceptual selection
- keyboard movement should not instantly be stolen by a stationary mouse
- moving the real mouse should take ownership
- scrolling under a stationary pointer should not count as moving the pointer
- selection should not "teleport" unexpectedly

Current approach:

- result delegate spans full row
- actual clickable visual button is an inner Rectangle
- fixed viewport MouseArea tracks true pointer movement
- keyboard activity clears/overrides hover ownership
- actual pointer movement reclaims selection
- scrolling alone does not

The user explicitly said this behavior was **perfect**.

Do not casually rewrite this logic.

---

# 27. Result Row Geometry

The full-width delegate remains useful for pointer tracking, while the visual button has margins.

Accepted row-gap concept:

```qml
property int appSelectorRowGap: 6
```

Inner result button roughly:

```qml
anchors.leftMargin: appControlWindow.appSelectorRowGap

anchors.rightMargin:
    (resultList.width - resultScrollTrack.x)
    + appControlWindow.appSelectorRowGap
```

This creates a small visual inset while preserving the full-width interaction delegate.

The user confirmed this look.

---

# 28. Selector Top Gap

A persistent visual gap above the first result was desired.

The correct fix was **not** adding content margin that broke scrollbar positioning.

Instead the ListView viewport itself gets a top margin, approximately:

```text
8px
```

This keeps the custom scrollbar touching the header line correctly while the content starts slightly lower.

Preserve this distinction.

---

# 29. Selector Scrollbar

Custom scrollbar:

```text
track width: ~10
handle width: ~6
track: cyan
handle: magenta
```

It supports drag/click.

It should visually touch the header divider.

Footer spacing around:

```text
10px
```

---

# 30. Keyboard Controls

Search input keeps focus and forwards keys to AppControl logic.

Concept:

```qml
Keys.onPressed: appControlWindow.handleKey(event)
```

Current expected behavior:

## Escape

If detail pane focused:

```text
DETAIL → selector
```

otherwise:

```text
close AppControl
```

## Up / Down

Move result selection.

Wrap at top/bottom.

Use actual current result count.

Normal movement should keep selection visible with:

```text
ListView.Contain
```

Wrap should explicitly jump to:

```text
ListView.Beginning
ListView.End
```

## Right

Enter detail/control pane.

## Left

Return to selector/search.

## Enter

Selector:

```text
activate selected result
```

Detail mode:

```text
activate selected detail action
```

## Tab / Shift+Tab

Selector:

```text
next/previous mode
```

In APPS control pane:

```text
next/previous app while remaining in detail context
```

Shift+Tab must correctly handle either:

```text
Qt.Key_Backtab
```

or:

```text
Qt.Key_Tab + ShiftModifier
```

---

# 31. Detail Actions

APPS detail action model begins with:

```text
LAUNCH
```

then desktop actions from:

```qml
entry.actions
```

Helpers include concepts equivalent to:

```text
detailActionCount()
resetDetailActionSelection()
detailActionItem()
ensureDetailActionVisible()
activateSelectedDetailAction()
```

`ensureDetailActionVisible()` scrolls the right-side detail content only when necessary.

---

# 32. Right Pane Layout

The right pane is the App Control / detail pane.

Header currently reads:

```text
APPLICATION CONTROL
```

An intermediate request changed it to:

```text
APPLICATION CONTROL PANEL
```

but the user then explicitly asked to remove `PANEL`.

Final text is:

```text
APPLICATION CONTROL
```

There are matching magenta mode icons on **both sides** of the header.

Left and right icons use the current mode symbol with the same magenta styling/glow.

The header text itself is cyan with strong glow.

---

# 33. Right Pane Decorative Mode Icons

The right-side duplicate was added so the header visually reads:

```text
[magenta mode icon]  APPLICATION CONTROL  [magenta mode icon]
```

The second icon should mirror the first in:

- symbol
- color
- font size
- glow intensity

Current approximate icon styling:

```text
font size: 20
magenta
DropShadow radius: 18
samples: 9
opacity: 0.9
```

---

# 34. Dividers / Focus Language

Important divider colors:

```text
modeResultsDivider: orange
resultsDetailDivider:
    APPS detail-focused → magenta
    otherwise → orange
```

Right-pane structural cyan lines include:

- detail top bar
- detail header divider
- running state divider
- bottom bar
- vertical dividers

Typical line glow:

```text
RectangularShadow
spread: 3
opacity: 0.38
```

KILL-specific divider/header contexts can use red.

---

# 35. Selected App Identity Band

The top identity/info area contains:

- selected app icon
- app name
- description/metadata
- detail/control context

An earlier transparency/blur experiment was abandoned.

Do **not** revive those opacity experiments unless explicitly requested.

The accepted direction kept a dark app-info band over the deep purple base.

Historical lesson:

> Alpha over an opaque same-color parent does not magically reveal the desktop. Real desktop transparency requires the actual window/background structure to allow it.

But the user abandoned that branch, so it is not active work.

---

# 36. Safe Icon Loading Architecture

This is one of the most important technical sections in the whole project.

## Catastrophic icon crash

On Quickshell 0.3.1, repeated AppControl use produced a native crash similar to:

```text
pure virtual method called
__cxa_pure_virtual
QPlatformPixmap::fromFile
QPixmap::load
QIcon::pixmap
/usr/bin/quickshell
QQuickPixmapReader...
```

There was also warning behavior such as:

```text
Could not load icon "kitty" at size QSize(100, 100) from request
```

This was **not** primarily a window visibility bug.

The problematic architecture had multiple code paths requesting the same Quickshell theme icon, especially Canvas independently doing something equivalent to:

```qml
loadImage(Quickshell.iconPath(...))
```

while the visible `Image` was also loading the icon.

That duplicated the icon-provider/pixmap path and could hit the native crash.

## Isolation result

Removing `Quickshell.iconPath()` entirely made icons disappear but made AppControl stable.

That proved the icon-provider path was involved.

## Final safe architecture

Only the visible `Image` requests the original icon.

Then:

```text
visible Image
   ↓
grabToImage()
   ↓
temporary in-memory grab URL
   ↓
Canvas samples the grab
```

The Canvas **must never directly request the original**:

```text
image://icon/...
```

or call `Quickshell.iconPath()` itself.

Rule:

> NEVER restore Canvas `loadImage(Quickshell.iconPath(...))`.

This is a hard regression trap.

---

# 37. Icon `sourceSize`

Visible icons use controlled source sizes.

Selector/control icon source sizes around:

```text
52 × 52
```

This fixed raster icons such as Htop looking wrong/blurry or being sampled poorly.

Even if the displayed selector icon is around:

```text
22 × 22
```

its source can still be requested at:

```text
52 × 52
```

for better input quality.

---

# 38. Dynamic Icon Glow Classifier

App icons are sampled and categorized into the project palette.

General mapping:

```text
red                    → Colors.red
orange / yellow        → Colors.orange
green                  → Colors.omnitrix
cyan / blue            → Colors.cyan
purple / pink / indigo → Colors.magenta
bright / white         → Colors.white
gray / charcoal        → Colors.magenta
```

For UI display:

```text
white-classified icon:
    text = white
    halo = cyan
```

Accent colors have priority over neutral mass.

This matters because icons can have large white/gray backgrounds with a small defining accent.

Classifier tuning was needed so icons like:

- Calendar
- Mullvad
- Obsidian
- Bottles

produced useful palette colors.

A relatively small colored region, around only a few percent of the icon, can be allowed to define the glow.

Dark saturated blue needs to be detected before falling into generic dark/black fallback.

---

# 39. Icon Glow Cache / Ownership

There is an icon glow cache keyed by icon source.

Updating the cache should reassign a new object, e.g. conceptually:

```js
iconGlowCache = Object.assign({}, iconGlowCache, {
    [key]: color
});
```

so QML bindings update.

A subtle bug occurred where the selector could seed a color and the right/control icon could disagree or stale data could survive.

Current ownership rule:

```text
selector icon = seed cache only
right/control icon = authoritative and may overwrite cache
```

Conceptually:

```text
selector forceOverwrite = false
control forceOverwrite = true
```

The right/control icon is sampled at the larger/authoritative rendering size.

There is also source verification so a delayed grab from an old icon cannot be applied to a new app.

---

# 40. Bottles Glow Bug

Observed behavior:

- Bottles selector text initially appeared blue
- after hover/selection it could become red

This indicated competing cache/sample timing.

Fix direction:

- selector samples only seed missing cache values
- selected/control icon force-overwrites with authoritative sample
- sample on component creation when already ready
- verify source did not change before applying sample

Preserve this architecture.

---

# 41. Selector Glow Clipping Bug

At one point icon glow looked shifted down/right or clipped.

Cause:

A parent `Row` was clipping the halo.

Fix:

```qml
clip: false
```

on the appropriate row/container.

Selector icon also uses vertical centering.

App-name box width was constrained to available row width, with the name text anchored left/right and `Text.ElideRight`.

Do not re-enable clipping around icon glows.

---

# 42. App Icon Glow Sample Counts

User prefers lower sample counts on icon shadows because the stepped/line texture fits the retro display aesthetic.

Selector icon shadow currently roughly:

```text
pressed: samples 7
idle: samples 5
```

The large selected app icon in the App Control panel was most recently changed from:

```text
samples: 7
```

to:

```text
samples: 5
```

while preserving:

```text
radius: 12
opacity: ~0.50
```

This intentionally changes texture rather than simply shrinking the halo.

---

# 43. App Name Glow

Idle app name color follows the sampled icon color.

For white-classified icons:

```text
name text: white
halo: cyan
```

Selected / hover app names:

```text
orange
```

Pressed text can become:

```text
Colors.black
```

The name uses a padded wrapper around its layer effect so the shadow does not clip into a rectangular ugly edge.

---

# 44. Buttons

LAUNCH and desktop-action buttons were intentionally made more luminous.

LAUNCH roughly:

```text
idle: cyan
active/focused: orange
pressed: darker/black text treatment
```

Shadow intensity increases when active.

Desktop actions use orange emphasis.

Do not flatten these into ordinary flat buttons.

---

# 45. Sway Running-State Backend

APPS right pane already has a real running-state backend using Sway.

Imports include:

```qml
import Quickshell.I3
import Quickshell.Io
```

A process runs:

```bash
swaymsg -t get_tree
```

The JSON tree is parsed and flattened into real windows.

`I3IpcListener` reacts to window/workspace events and refreshes state.

State concepts:

```text
swayWindows
windowDataReady
windowDataError
selectedAppWindows
workspaceList
workspaceSummary
```

Matching tries to correlate a desktop entry to Sway windows using normalized fields such as:

- startup class
- desktop id
- name
- command basename
- Sway `app_id`
- XWayland class
- instance

The user confirmed the matching was accurate.

---

# 46. Running State Grid

The right pane has a real grid like:

```text
RUNNING    : 3 WINDOWS
WORKSPACES : 1, 4, 6
```

It is an actual multi-column `GridLayout`, not spacing hacks.

Preserve that.

Singular/plural:

```text
WINDOW / WINDOWS
WORKSPACE / WORKSPACES
```

Workspace list must not have a trailing comma.

---

# 47. Running State Color Tuning

Latest requested colors:

## RUNNING row

The numeric window count remains:

```text
magenta
```

The word:

```text
WINDOW
WINDOWS
```

is now:

```text
white
```

with a subtle cyan halo.

## WORKSPACE row

The word:

```text
WORKSPACE
WORKSPACES
```

is:

```text
orange
```

with orange glow.

Workspace numbers remain orange.

---

# 48. APPS Running State Scroll Boundary

The right panel has identity content fixed at the top.

Scrolling is intended mainly below the Running State divider / detail action region rather than allowing the whole identity header to drift arbitrarily.

Preserve the fixed-identity feel.

The right custom scrollbar only appears when content actually overflows.

Right scrollbar:

```text
cyan track
magenta handle
```

---

# 49. Mod+D / Global Shortcut Architecture

Ordinary QML `Shortcut` is not a true compositor-global shortcut under Sway.

Quickshell `GlobalShortcut` support is not the route being used here for Sway.

**Sway owns Mod+D.**

AppControl exposes a Quickshell IPC endpoint.

Current generated widget contains conceptually:

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

Suggested Sway call was:

```bash
qs ipc call appControl toggle
```

and one suggested binding was:

```conf
bindsym $mod+d exec qs ipc call appControl toggle
```

However:

> The user explicitly said they set it up a bit differently and confirmed it works.

Therefore:

- preserve the IPC target
- preserve the fact that Mod+D works
- do **not** overwrite the user's Sway config with the example above unless they ask

Useful diagnostics:

```bash
qs ipc show
qs ipc call appControl isOpen
qs ipc call appControl toggle
```

`qs ipc call` requires Quickshell to already be running.

---

# 50. Quickshell Startup / Debugging

Do not casually run:

```bash
pkill quickshell
```

because it kills the entire shell/bar and can make IPC look broken simply because there is no Quickshell instance.

Foreground debug command used during development:

```bash
qs -p ~/.config/quickshell/shell.qml
```

Older docs also use the long command:

```bash
quickshell -vv -p ~/.config/quickshell/shell.qml
```

Use whichever matches the installed CLI.

---

# 51. Important Distinction: Two Different Native Crash Families

Do not confuse these.

## A. Old MessagingW lifecycle crash

On older Quickshell 0.2.1, another widget (`MessagingW`) crashed when its root PanelWindow repeatedly did:

```qml
visible: menuOpen
```

The workaround was to keep the native root alive and hide inner content/collapse the input mask.

That problem involved native surface lifecycle/recreation.

## B. AppControl icon-provider crash

AppControl's critical crash on Quickshell 0.3.1 was tied to theme icon loading / QPixmap / QIcon / Canvas double-requests.

Its fix was the safe icon sampling architecture described above.

Do not assume AppControl needs the old MessagingW visibility workaround unless new evidence proves it.

---

# 52. Old Rofi Reference

Rofi was the aesthetic ancestor, not the backend.

Historical approximate values:

```text
width: ~280
position: northwest
border: orange
background: dark purple
text: cyan
selected: yellow
scrollbar handle: magenta
scrollbar track: cyan
~12 lines
```

Modes/symbols/playful glyph language came partly from this lineage.

Again:

> AppControl must not invoke Rofi.

---

# 53. Current AppControl Opening Behavior

When `menuOpen` becomes true:

- reset favorites face pulse/blink
- schedule irregular future favorite blink
- default mode to APPS
- reset focus/detail state as appropriate
- refresh window state
- focus search input

When closing:

- stop relevant timers
- clear temporary favorite-face states

Opening should feel deterministic even though idle animations are playful.

---

# 54. APPS Selection Persistence

Selected app is intentionally preserved across mode transitions where practical.

There are helpers around remembering/restoring the current app selection.

The objective is:

> switching modes should not unnecessarily lose the user's place in APPS.

Do not replace this with a blanket "always reset index 0" approach.

---

# 55. User Preferences Established During Iteration

These are important because many requests were preference corrections, not just bug fixes.

The user prefers:

- smaller/stepped glow sample counts over overly smooth icon glows
- fixed menu width over making the menu larger for long names
- adaptive font only in the right App Control title/name area
- unified selector result font size with `...`
- decorative title symbols brighter than central words
- title words visually baseline-adjusted independently from symbols
- irregular "alive" animation rather than metronomic repeating animation
- custom cursor decoration instead of a normal line cursor
- actual cursor animation without ghost duplicates
- AppControl focused on application lifecycle/control, not a generic mega-launcher
- the current APPS mode behavior as a stable foundation
- direct code/file edits rather than disconnected snippets once a baseline exists

---

# 56. Current Visual Checkpoint

Approximate current visual language:

## Left rail

Modes:

```text
FAVORITES
APPS
RUN
WINDOWS
KILL
```

with symbolic faces/icons.

## Selector header

APPS:

```text
- ༘⋆₊⊹Pick an App any App ๋࣭ ⭑⋆｡˚-
```

Decorations: brighter cyan glow  
Words: softer cyan glow  
Center words moved down by `4px` relative to decoration.

Line under title: cyan, shifted down to `y: 4`.

Search text: magenta.  
Decorative cursor: orange with glow.

## Results

Dark purple background.

App icon + name.

Names fixed 17px, ellipsis for long entries.

Favorite star at the row edge.

## Right pane

Header:

```text
[magenta mode symbol] APPLICATION CONTROL [magenta mode symbol]
```

Selected app identity.

Adaptive selected app name.

Metadata.

Running State.

Launch/actions.

Cyan structural dividers and contextual orange/magenta focus language.

---

# 57. Known Stable Components — Freeze Unless Needed

The following pieces took significant debugging and should be considered "stable infrastructure":

1. Safe icon sampling:
   ```text
   Image → grabToImage → Canvas grab URL
   ```

2. Mouse/keyboard arbitration.

3. Result delegate + inner visual-button geometry.

4. Selector viewport top gap.

5. Custom scrollbar geometry.

6. Fixed independent selector title/search layout.

7. Custom cursor as sibling overlay.

8. Invisible native cursor delegate.

9. App detail scroll/action focus behavior.

10. Sway running-state parsing/matching.

11. Icon glow cache ownership.

12. AppSelector fixed-font + ellipsis choice.

13. Right AppControl adaptive selected-app font.

14. Mod+D → Sway → Quickshell IPC concept.

When implementing RUN/WINDOWS/KILL, reuse these systems rather than rebuilding them independently.

---

# 58. Future Plan — Finish FAVORITES

This should happen before or alongside the other modes because every new real mode needs stable favorite identity.

## Goal

FAVORITES should become a cross-mode dashboard of genuinely useful saved targets.

## App favorite

Activation:

```text
launch app
```

Identity:

```text
desktop entry / stable app id
```

## RUN favorite

Activation:

```text
execute saved command
```

Identity should use a stable command record, probably normalized command text plus optional display name.

Potential future record shape:

```js
{
    type: "run",
    key: "...",
    label: "...",
    command: "...",
    icon: "...",
    description: "..."
}
```

## WINDOWS favorite

Needs careful semantics.

A raw window instance can disappear/reappear, so a favorite probably should not depend only on ephemeral Sway container ID.

Possible semantics:

```text
favorite app/window identity
→ if matching window exists, focus it
→ if none exists, optionally launch app or show unavailable state
```

The exact behavior should be decided during WINDOWS implementation.

## KILL favorite

A favorite must **not** make destructive action one-key accidental.

Recommended behavior:

```text
favorite selects/opens target in KILL context
→ user still chooses CLOSE / TERM / FORCE
```

Do not make activating a KILL favorite immediately kill anything.

---

# 59. Future Plan — RUN Mode

RUN should be a real command launcher, not another app list.

Reuse:

- same selector
- same text input
- same keyboard behavior
- same favorite star system
- same right control panel framework

Possible RUN behavior:

## Input

User types arbitrary command.

## Results

Could include:

- exact typed command as first executable row
- command history
- favorite commands
- optionally executables from `$PATH`
- possibly desktop actions later, but keep scope focused

## Execute

Use a Quickshell `Process` or suitable execution route.

Need to decide whether commands are:

```text
direct argv
```

or:

```text
shell command
```

This affects quoting, pipes, redirects, environment expansion, etc.

A safe design is to explicitly distinguish:

```text
direct exec
shell exec
```

rather than silently feeding everything to a shell.

## Right panel

Could show:

```text
COMMAND
SOURCE
EXECUTION TYPE
WORKING DIRECTORY
FAVORITE STATUS
```

Optional future history metadata:

```text
last run
run count
```

but do not overbuild before basic execution works.

---

# 60. Future Plan — WINDOWS Mode

This mode should use the Sway tree backend that is already present.

Instead of matching windows only to the selected app, WINDOWS should expose the flattened live window model directly.

Likely row information:

```text
app icon
window title
app/class
workspace
favorite star
```

Activation:

```text
focus selected window
```

Likely through `swaymsg` / I3 IPC.

Right panel could show:

```text
WINDOW TITLE
APP_ID / CLASS
INSTANCE
WORKSPACE
PID if available
FOCUSED?
FLOATING?
FULLSCREEN?
GEOMETRY?
```

Only show fields Sway actually provides.

Favorites:

- define stable identity carefully
- do not key solely by temporary tree node ID if user expects persistence

---

# 61. Future Plan — KILL Mode

KILL should build on real windows/process information.

User wants a progression:

```text
CLOSE → TERM → FORCE
```

Suggested semantics:

## CLOSE

Ask the application/window to close normally.

Prefer compositor/window close semantics.

## TERM

Send a normal termination request to the underlying process when a reliable PID exists.

## FORCE

Hard kill.

Requires explicit confirmation.

Potential UI state:

```text
FORCE
→ first activation enters confirmation
→ second explicit confirmation executes
```

Red should be restrained and meaningful, not flood the whole UI.

Possible color language:

```text
normal browsing: cyan/orange
close: orange
term: red emphasis
force confirmation: stronger red
```

Never allow a favorite activation alone to jump directly to FORCE.

---

# 62. Future Plan — Shared Mode Architecture

Avoid five unrelated codepaths.

Prefer:

```text
mode
  ↓
mode-specific model
  ↓
shared selector delegate
  ↓
shared selection/hover/favorite behavior
  ↓
mode-specific activation
  ↓
shared right pane shell
  ↓
mode-specific detail component/content
```

This keeps APPS stable while allowing new behaviors.

Potential conceptual interface per mode:

```text
resultCount()
resultAt(index)
displayName(result)
icon(result)
favoriteKey(result)
activate(result)
detailData(result)
```

The existing code already moves in this direction; continue that instead of hardcoding indexes everywhere.

---

# 63. Future Plan — Favorites Data Migration

The current JSON contains keys from placeholder modes.

Once real RUN/WINDOWS/KILL are implemented, old placeholder keys may exist.

Do not crash if stale keys are present.

Plan for:

- ignoring unknown favorite keys
- optionally cleaning stale entries
- versioning favorites JSON later if data structure changes substantially

A simple future schema might become:

```json
{
  "version": 2,
  "favorites": [
    {
      "type": "app",
      "key": "..."
    },
    {
      "type": "run",
      "key": "...",
      "command": "..."
    }
  ]
}
```

But do not migrate prematurely. Finish real modes first, then decide what data genuinely needs persistence.

---

# 64. Testing Checklist After Major Edits

## Open/close

- launcher click toggles
- Mod+D toggles
- Escape closes
- repeated spam does not crash

## APPS

- apps populate
- search filters
- favorites pin correctly
- star click does not launch
- Enter launches
- desktop actions work
- long selector names ellipsize
- right selected name shrinks if necessary

## Mouse/keyboard

- keyboard arrows move selection
- stationary pointer does not steal
- real mouse movement steals appropriately
- scroll does not teleport selection
- wrap works top/bottom

## Icons

- Kitty
- Bottles
- Calendar
- Mullvad
- Obsidian
- Htop
- one white/light icon
- one gray icon
- one dark blue icon

Check:

- no native crash
- no stale glow
- no huge clipping
- no extra theme-icon requests from Canvas

## Cursor

- no native purple bar visible
- decoration follows insertion point
- no doubled cursor
- combining marks not garbled
- glow visible
- y alignment correct
- idle animation works

## Header

- Pick-an-App symbols stay aligned
- words are lower than symbols as intended
- no search input jump between modes
- title underline sits at correct height
- KILL color changes do not break geometry

## Running state

- stopped app shows appropriate no-window state
- one window singular
- multiple windows plural
- workspace singular/plural
- no trailing comma
- live events refresh

## Favorites face

- normal face on open
- hover/click happy face
- no sticky happy face
- blink eventually occurs
- blink timing feels irregular

---

# 65. Regression Traps

These are the most important "do not do this again" items.

## Do not:

```qml
Canvas.loadImage(Quickshell.iconPath(...))
```

for app icons.

## Do not:

assume APPS is mode index 0.

## Do not:

split cursor combining marks into standalone text elements.

## Do not:

put the decorative cursor back inside the TextInput's glow/layer path unless there is a compelling reason and duplicate rendering is solved.

## Do not:

make selector app-name font adaptive again unless requested; the user wants fixed size + ellipsis there.

## Do not:

let title implicitHeight move the search field.

## Do not:

replace mouse/keyboard ownership logic casually.

## Do not:

use a repeating fixed favorites-face blink timer.

## Do not:

make destructive KILL favorites auto-kill on activation.

## Do not:

blindly replace the user's working Sway Mod+D setup.

## Do not:

revive abandoned transparency experiments without being asked.

## Do not:

confuse old MessagingW native window lifecycle crash with AppControl's icon-provider crash.

---

# 66. Generated File Lineage

The recent AppControl development chain in this conversation was:

```text
AppControlW_favorites_star_system.qml
AppControlW_favorites_star_palette.qml
AppControlW_favorites_star_idle_palette.qml
AppControlW_favorites_star_three_state.qml
AppControlW_favorites_star_red_flash.qml
AppControlW_favorites_all_modes_color_stable.qml
AppControlW_selector_glow_bottles_sync_fix.qml
AppControlW_pick_an_app_header.qml
AppControlW_pick_header_custom_cursor.qml
AppControlW_selector_header_aligned_smaller.qml
AppControlW_header_cursor_idle_blink.qml
AppControlW_cursor_alignment_blink_tune.qml
AppControlW_cursor_above_bar_closer.qml
AppControlW_apps_header_metrics_fix.qml
AppControlW_fixed_selector_header_layout.qml
AppControlW_cursor_star_wave.qml
AppControlW_cursor_star_wave_slower_aligned.qml
AppControlW_cursor_favorites_face_glow_tune.qml
AppControlW_cursor_overlay_favorites_blink_fix.qml
AppControlW_cursor_real_replacement_irregular_blink.qml
AppControlW_pick_title_glow_divider_cursor_up.qml
AppControlW_cursor_full_star_wave_title_line_lower.qml
AppControlW_cursor_near_stars_glow_line_lower.qml
AppControlW_adaptive_app_name_font.qml
AppControlW_selector_fixed_detail_scaling_decor_glow.qml
AppControlW_pick_text_lower_2px.qml
AppControlW_pick_text_lower_4px_panel_header.qml
AppControlW_application_control_double_icon.qml
AppControlW_running_state_color_tune.qml
AppControlW_modd_ipc_lower_icon_samples.qml
```

Not every intermediate file was "correct"; this list is useful mainly for archaeology.

Latest generated checkpoint:

```text
AppControlW_modd_ipc_lower_icon_samples.qml
```

---

# 67. Historical Bugs / Fixes Timeline

A condensed chronological recovery guide:

## File/path stage

**Bug:** widget initially had typo `AppContolW.qml`.  
**Fix:** rename to `AppControlW.qml`, correct imports.

## Functional APPS stage

**Goal:** replace placeholders with real desktop entries.  
**Result:** DesktopEntries + ScriptModel search/sort + execute + metadata.

## Keyboard/detail stage

**Bug:** selection/detail scrolling could jump or not remain visible.  
**Fix:** explicit selection helpers + `ListView.Contain` + dedicated detail scrolling.

## Sway running-state stage

**Goal:** show live windows/workspaces for selected app.  
**Fix:** `swaymsg -t get_tree`, flatten tree, normalize app matching, I3 event refresh.

## Icon native-crash stage

**Bug:** repeated icon use could trigger pure virtual / QPixmap / QIcon crash.  
**Cause:** duplicate theme-icon loading paths, especially Canvas.  
**Fix:** single visible Image request → `grabToImage()` → Canvas samples memory URL.

## Icon quality stage

**Bug:** Htop/other raster icons looked poor.  
**Fix:** controlled `sourceSize` around 52px.

## Classifier stage

**Bug:** accent colors lost to neutral background; some apps got wrong halo.  
**Fix:** prioritize saturated accents and tune thresholds.

## Bottles/cache stage

**Bug:** Bottles color changed after interaction due competing samples.  
**Fix:** selector seed-only, control authoritative overwrite, verify source.

## Glow clipping stage

**Bug:** selector halo clipped/offset.  
**Fix:** remove parent clipping, center icon, constrain name box.

## Mouse/keyboard stage

**Bug:** hover and keyboard fought; stationary pointer stole selection; scrolling teleported state.  
**Fix:** explicit input ownership; real pointer movement only reclaims hover.

## Result geometry stage

**Goal:** visual side gaps without sacrificing interaction area.  
**Fix:** full-width delegate + inset inner button.

## Header stage

**Bug:** ornate APPS glyph metrics made search field jump.  
**Fix:** fixed title slot + independently anchored search field.

## Cursor stage 1

**Bug:** decorative cursor doubled/ghosted.  
**Cause:** TextInput layer effect + cursor's own shadow.  
**Fix:** cursor moved to sibling overlay.

## Cursor stage 2

**Bug:** combining marks looked doubled/garbled.  
**Cause:** combining marks split into separate text nodes.  
**Fix:** keep shaping base and combining marks together.

## Cursor stage 3

**Bug:** real purple insertion line still visible.  
**Fix:** invisible zero-size cursor delegate while preserving cursor geometry.

## Cursor stage 4

**Bug:** cursor too low.  
**Fix:** final overlay y around `searchInput.y + 3`.

## Cursor glow stage

**Request:** stronger orange glow.  
**Fix:** approx radius 5 / samples 5 / opacity 0.42.

## Favorites face stage 1

**Bug:** happy face latched after hover/click.  
**Fix:** short click pulse + direct hover state.

## Favorites face stage 2

**Bug:** blinking too frequent/predictable.  
**Fix:** random one-shot scheduling ~6.5–12.5 sec.

## App-name scaling stage

**First attempt:** both selector and detail names adaptively shrank.  
**User preference:** selector should remain visually uniform with `...`.  
**Final:** selector fixed 17px + ellipsis; detail panel adaptive 22→13.

## Pick-an-App decoration stage

**Request:** stars/dashes brighter.  
**Fix:** split title into left decor / center words / right decor with stronger side glows.

## Pick-an-App alignment stage

**Bug:** center text and decorations visually misaligned.  
**Fix:** center text only moved downward, final offset +4px.

## Header underline stage

**Bug:** added title underline too high.  
**Fix:** move downward, final transform y4.

## Right header stage

**Request:** briefly rename to APPLICATION CONTROL PANEL.  
**Follow-up:** remove PANEL and add mirrored mode icon.  
**Final:** `[icon] APPLICATION CONTROL [icon]`.

## Running-state color stage

**Request:** WORKSPACE(S) orange; WINDOW(S) white; window number stays magenta.  
**Fix:** applied exactly that.

## Large app-icon texture stage

**Request:** lower sample size.  
**Fix:** selected app icon shadow samples 7→5, radius preserved.

## Mod+D stage

**Problem:** need global shortcut under Sway.  
**Fix:** AppControl exposes Quickshell IPC target `appControl`; Sway calls it.  
**Current:** user confirmed working, with a slightly different local Sway setup.

---

# 68. Immediate Next Work

The APPS mode is considered done enough for now.

Next work requested by user:

```text
1. finish FAVORITES
2. implement RUN
3. implement WINDOWS
4. implement KILL
```

Suggested implementation order:

```text
FAVORITES data model cleanup
→ RUN
→ WINDOWS
→ KILL
```

Why:

- every real mode should plug into the finished favorite model
- RUN is simplest new activation model
- WINDOWS can reuse Sway backend
- KILL depends on robust real target identity and needs safety/confirmation

---

# 69. Recommended Next Session Plan

When resuming:

## Step 1 — Load newest AppControl file

Verify it is the user's current local version.

Do not assume the generated sandbox copy is newer than their local edits.

## Step 2 — Confirm APPS has not regressed

Quick smoke test:

```text
open
search
keyboard select
mouse select
favorite
launch
desktop action
running state
Mod+D
```

## Step 3 — Inspect current favorite record structure

Before editing, find:

```text
favoriteKeyFor
favoriteRecordForApp
favoriteRecordForModeItem
favoriteResults
toggleFavorite
```

## Step 4 — design real RUN records

Replace placeholder rows in RUN with actual command-oriented records.

Do not touch the stable APPS result delegate unless needed.

## Step 5 — make RUN favorites real

Then FAVORITES can begin containing a second real type.

## Step 6 — expose full Sway window model in WINDOWS

Reuse existing tree refresh infrastructure.

## Step 7 — define safe KILL target model

Only after window/process identity is trustworthy.

---

# 70. New-Chat Recovery Prompt

If context is lost, upload:

1. this Markdown file
2. the current local `AppControlW.qml`
3. optionally `shell.qml`
4. optionally `modules/Applauncher.qml`
5. relevant Sway keybinding lines only if Mod+D needs work

Then tell the new chat:

> Continue my Quickshell AppControl project. Treat the uploaded `AppControlW.qml` as source of truth and the handoff Markdown as architecture/debugging history. APPS is the stable reference mode. Do not regress the safe icon sampling architecture, mouse/keyboard arbitration, fixed selector header layout, custom cursor overlay, or working Sway IPC. The next tasks are to finish FAVORITES, implement RUN, implement WINDOWS, and then implement safe CLOSE → TERM → FORCE KILL behavior.

---

# 71. Final Current-State Summary

AppControl is now a mature Quickshell launcher/control surface rather than a Rofi skin.

The APPS mode has:

- real app discovery
- search
- real icons
- dynamic icon-derived palette glow
- favorites
- desktop actions
- keyboard + mouse parity
- custom cursor
- decorative animated UI
- live Sway window/workspace state
- adaptive right-panel typography
- stable Mod+D IPC access
- extensive crash/interaction hardening

The largest remaining functional work is no longer APPS styling.

It is:

```text
FAVORITES → make all saved item types real
RUN       → real command execution
WINDOWS   → real live-window selector/focus control
KILL      → safe close/terminate/force lifecycle control
```

The safest strategy is to **reuse the finished APPS infrastructure** and swap in mode-specific data and actions rather than rebuilding each mode from scratch.

That is the current project checkpoint.
