# Complete Rice / Quickshell Project Dossier

> **Purpose:** This document consolidates, in one place, the design language, architecture, historical context, current implementation, future direction, code conventions, configuration details, screenshots, module behavior, aesthetic references, interaction patterns, and design decisions discussed so far.
>
> It is intentionally detailed. It is meant to serve as a project reference, design brief, architecture note, and historical record rather than a short summary.

---

## 0. How to read this document

There are several different kinds of information mixed throughout the project, so this dossier keeps them distinct:

- **Legacy / old rice:** the older Waybar, Rofi, Sway, Kitty, Zellij, Fastfetch, wttr.in and related setup before Quickshell became the main graphical shell.
- **Established convention:** patterns that recur often enough to be treated as project standards rather than one-off experiments.
- **Current implementation:** what the current Quickshell QML is doing now.
- **Experimental / scaffolding:** temporary hard-coded positioning, debug `Process` objects, logging, duplicated thresholds, placeholder buttons, and similar development-stage code.
- **Future / intended architecture:** directions explicitly stated for the project, especially the goal of moving desktop-facing UI into Quickshell while retaining Linux services underneath.

This distinction is important. A temporary implementation detail should not be mistaken for a final design principle.

---

# 1. Project identity

The desktop stack is centered around:

```text
Fedora / Silverblue
        ↓
      Sway
        ↓
   Quickshell
        ↓
 Kitty + Zellij
        ↓
Neovim / Yazi / btop / ncmpcpp / other TUI tools
```

The emerging desktop philosophy is:

```text
Sway
  ↓
Quickshell (unified graphical shell)
  ↓
existing Linux backends/services
```

and for terminal work:

```text
Sway workspace/window
  ↓
Kitty
  ↓
Zellij
  ↓
Neovim / Yazi / btop / etc.
```

The system is not trying to replace Linux services with QML reimplementations.

Instead:

> **Quickshell should become the graphical presentation and orchestration layer over the existing Linux stack.**

Examples:

- Quickshell audio mixer over **PipeWire**
- Quickshell network frontend over **NetworkManager**
- Quickshell workspace frontend over **Sway**
- Quickshell Bluetooth frontend over the existing Bluetooth stack
- Quickshell power controls calling **systemd / swaymsg**
- Quickshell wallpaper controls over normal wallpaper/system tools
- Quickshell media UI over the actual media service/player
- Quickshell monitoring UI over existing telemetry sources

The goal is not “rewrite the system.”

The goal is:

> **replace fragmented desktop-facing frontends with one coherent shell.**

---

# 2. The biggest architectural evolution

The old rice was primarily a collection of independently themed applications.

Conceptually:

```text
                 ┌─ Waybar
                 ├─ Rofi
Sway ────────────┼─ wlogout-style controls
                 ├─ Pavucontrol
                 ├─ Blueman
                 ├─ NetworkManager GUI
                 ├─ Mako
                 ├─ terminal utilities
                 └─ other desktop tools
```

The newer architecture is moving toward:

```text
                         Sway
                           │
                           ▼
                    ┌────────────┐
                    │ Quickshell │
                    └────────────┘
                    │    │    │
          ┌─────────┘    │    └──────────┐
          ▼              ▼               ▼
      workspaces       audio          network
          │              │               │
          ▼              ▼               ▼
        Sway          PipeWire      NetworkManager

                    + Bluetooth
                    + power
                    + launcher
                    + clock
                    + media
                    + wallpaper
                    + notifications
                    + monitoring
                    + screenshots
                    + calendar
                    + weather
                    + other desktop-facing UI
```

At the same time, terminal applications remain deep interfaces:

```text
Quickshell = quick graphical controls and glanceable information
Terminal   = deep keyboard-heavy control and work
```

That duality is fundamental to the project.

---

# 3. Aesthetic identity

The aesthetic should **not** be described as “Gothic” or “occult.”

The intended language is much more accurately described as a combination of:

- **Christian**
- **celestial / stars / night sky / outer space**
- **retro-computing**
- **terminal / ASCII / CRT**
- **old televisions**
- **old personal computers**
- **neon**
- **synthwave**
- **playful / fun**
- **retro-American visual culture**
- **Japanese reinterpretations of American visual culture**
- **gaming interfaces**
- **anime-like neon / energy**
- **comic-book graphics**

Specific inspiration references discussed include:

- Fallout
- The Handmaid’s Tale
- iCarly
- American diners
- Spider-Man
- Superman
- Batman
- old televisions
- PCs
- cars
- gas stations
- mid-century modern design
- Japanese neon signs
- Japanese copies/reinterpretations of American visual ideas
- Pokémon
- Pokémon Storage PC
- Game Boy Advance
- Nintendo DS
- Nintendo
- Wii
- old game menus and screens
- Naruto
- anime energy-beam effects

These are **not** intended to all appear literally at once.

They form a vocabulary from which individual components can borrow.

---

# 4. Core visual vocabulary

The strongest repeated visual elements are:

- deep purple foundation
- cyan primary information/interface color
- orange active/focus/hot color
- gold/yellow selected or emphasized states
- pale cyan/off-white neutral text
- red-orange urgent/destructive state
- magenta special/pressed state
- green as an established palette color that should receive more use
- strong glow
- layered shadows
- very restrained physical borders
- black or deep-dark active surfaces
- transparent shell areas over wallpaper
- thin luminous horizontal lines
- square or barely rounded geometry
- large negative space
- sparse HUD presentation
- monospace/pixel-terminal typography
- Nerd Font and Unicode glyphs
- Christian symbols
- stars/celestial motifs
- parentheses/brackets around glyphs
- box-drawing characters
- ASCII graphics
- text-based meters
- central alignment/reference markers
- occasional animation or telemetry-driven motion
- a preference for “instrument panel” behavior over ordinary GUI chrome

---

# 5. Core palette

The palette repeatedly established across the old rice and Quickshell is:

```qml
// approximate shared semantic palette
property color background: "#1B0623" // deep purple
property color cyan:       "#55CFCA"
property color orange:     "#ED981A"
property color yellow:     "#F2BE4E" // gold/highlight
property color white:      "#DCF3FA" // pale cyan-white
property color red:        "#D16041" // red-orange / urgent
property color indigo:     "#5B5FD4"
property color magenta:     "#C74EC7"
property color green:       "#9ece6a"
```

## 5.1 Semantic interpretation

Established/general meanings:

```text
cyan       = normal / information / interface / data
orange     = active / focused / important / hot
gold       = secondary selection / emphasis
red-orange = urgent / dangerous / destructive / warning
magenta    = special / pressed / alternate interaction
deep purple= background foundation
pale cyan  = neutral / light text / syntax/context
green      = established palette color, but not yet assigned one universal semantic role
```

Important nuance:

- `#9ece6a` was already present in Rofi.
- It should not be described as newly invented.
- Its broader semantic role is **not yet universally established in QML**.
- The desire is to use it more.

Some modules intentionally override the general palette with local state semantics.

Examples:

```text
Clock:
12-hour mode → cyan
24-hour mode → orange
```

```text
Volume:
active → cyan
muted / not-ready → yellow/gold
```

```text
Workspaces on HDMI-A-1:
active → yellow
inactive → white
```

So global semantics are guidelines, not inflexible laws.

---

# 6. High-priority semantic text rule

One of the most important newer design decisions is that textual data should be visually separated from punctuation, units and contextual suffixes.

The rule:

> **numerical/data values → cyan**
>
> **punctuation / units / suffixes / syntax / context → pale off-white**

Examples:

```text
12:34 PM
```

Desired conceptual coloring:

```text
12    cyan
:     off-white
34    cyan
PM    off-white
```

Similarly:

```text
75%
```

becomes:

```text
75  → cyan
%   → off-white
```

and:

```text
72°F
```

becomes:

```text
72  → cyan
°F  → off-white
```

This should be treated as a **general UI design convention**, not just a Clock or Volume tweak.

Current combined strings are acceptable interim implementations.

A likely implementation pattern is separate `Text` elements:

```qml
Row {
    spacing: 0

    Text {
        text: "12"
        color: Colors.cyan
    }

    Text {
        text: ":"
        color: Colors.white
    }

    Text {
        text: "34"
        color: Colors.cyan
    }

    Text {
        text: " PM"
        color: Colors.white
    }
}
```

The idea is:

> visually distinguish **the data itself** from **the syntax that explains the data**.

---

# 7. Typography

The main repeated font identity is:

```text
Gohu Nerd Font / GohuFont Mono / GohuFont 11 Nerd Font Mono
```

This appears across the old rice in different tools and is part of the visual identity.

The typography communicates:

- terminal heritage
- old-computer/pixel feeling
- text-first UI
- compatibility with Nerd Font glyphs
- compatibility with symbolic interfaces

Typography is not just a font choice; the project uses text itself as a drawing/interaction medium.

---

# 8. Unicode / glyph language

Unicode and Nerd Font symbols are a major part of the design.

They are **not** merely substitutes for SVG icons.

Examples already used or discussed include:

```text
-⋆♱⋆-
⏻
 ๋࣭🕰 ⭑
(﹙˓🌐˒﹚)
(˓✟˒)
░░░░░░░
███████
⌯⌲
♠ ♥ ♦ ♣
A K Q J
✦
```

The old Rofi configuration also used playing-card graphics:

```text
🃁🃜🃚🃖🂭🂺
```

This means cards are not a random new visual direction. They already fit the established symbolic vocabulary.

---

# 9. The “mask glyph” discussion

A possible future glyph was discussed that would resemble a theatrical mask like:

```text
🎭
```

but should ideally render as:

- one text-like glyph
- hollow or line-based
- monochrome
- recolorable
- compatible with QML `Text`
- visually closer to characters like:

```text
🂱
♠
🗣
```

The conclusion so far:

- standard Unicode does not provide an obvious perfect hollow monochrome equivalent of `🎭`
- `🎭` tends to render as color emoji and therefore does not fit the desired style very well
- no final glyph has been chosen
- this is intentionally left open until a satisfying glyph is found
- a custom monochrome SVG/icon-font glyph would be a fallback if necessary, but actual text/Unicode is preferred

---

# 10. Old rice: Waybar

Waybar was the old/current persistent HUD before migration into Quickshell.

Its configuration communicated a strong “thin HUD” philosophy rather than a conventional desktop taskbar.

## 10.1 Layout

Important structural values:

```text
layer: bottom
spacing: 0
height: 0
position: top

left margin: 200 px
right margin: 200 px
bottom margin: 3 px
```

Modules:

```text
LEFT
- launcher
- Sway workspaces
- MPD
- cava

CENTER
- calendar

RIGHT
- network
- Bluetooth
- CPU
- GPU usage
- temperature
- PulseAudio
- volume bar
- tray
- clock
- battery
```

A power custom module existed for a wlogout workflow but was not part of the normal right-side module list shown.

## 10.2 Waybar behavior

### Launcher

- toggles Rofi
- uses symbolic custom visual language

### Network

Shows:

- Wi-Fi
- Ethernet
- disconnected state
- SSID
- signal
- IP
- bandwidth

Interaction:

- click → NetworkManager connection editor
- right click → bandwidth-related behavior

### Bluetooth

- glyph-based presentation
- toggle/control behavior
- deeper interface through Blueman

### PulseAudio / volume

- click opens Pavucontrol
- custom volume script:
  `~/bin/volumebars.sh`
- click can mute
- scroll changes volume

### MPD

Displays:

- artist
- title
- playback state

Interaction:

- click toggles playback
- middle click opens `ncmpcpp`

### cava

Important values:

```text
60 FPS
10 bars
gradient
max height: 40
```

This reinforced:

- dynamic telemetry
- visualized sound
- live instrumentation

### Tray

```text
spacing: 10
```

### Clock

Decorative string:

```text
๋࣭🕰 ⭑
```

and 12/24-hour support.

### Calendar

Decorative language:

```text
⌯⌲ 🗓⋆˙⟡
```

Click opens GNOME Calendar.

### Battery

Displays:

- Nerd Font glyph
- capacity
- time

### Temperature

- orange
- Fahrenheit

### CPU

Click toggles a floating `btop-cpu` Kitty window.

### GPU

- script-based display
- click opens Kitty + `nvtop`

---

# 11. Waybar visual design / CSS language

Waybar CSS strongly established the current visual system before Quickshell.

Important traits:

```text
font: "GohuFont 11 Nerd Font Mono"
font size: 20px
```

Global/window:

- transparent background
- very small corner radii
- transparent-ish gradient
- no strong physical border
- cyan glow / drop shadows

Modules:

```text
background: #1B0623
foreground: #DCF3FA
```

with:

- small margins
- small padding
- very small radius
- cyan box-shadow

Important state colors:

```text
cyan    #55CFCA
orange  #ED981A
red     #D16041
```

Examples:

- focused workspace → orange
- active/playing MPD → orange
- temperature → orange
- urgent Sway window → red-orange

Hover:

```text
pale/neutral → cyan
stronger glow
```

Other traits:

- multi-layer text shadows
- tray menu used a separate dark surface
- gradients were partly used as a workaround for GTK rounded-corner behavior

The important design lesson is:

> **glow is the decoration; physical borders remain restrained.**

---

# 12. Old rice: Sway

Sway is the spatial skeleton of the environment and remains important.

## 12.1 Navigation

```text
$mod = Mod4
```

Movement uses both:

```text
h j k l
```

and arrow keys.

This matches the wider keyboard philosophy also visible in Zellij and terminal tools.

## 12.2 Terminal command history

Two assignments appeared:

```text
set $term kitty zsh
set $term kitty zellij
```

The second likely overrides the first, making the effective terminal launch behavior:

```text
Kitty → Zellij
```

## 12.3 Menu

Rofi was the configured menu, with custom theme and icons.

## 12.4 File explorer

```text
$file_explorer = kitty yazi
```

This is architecturally important:

> file management remains a deep terminal/TUI function.

## 12.5 Quickshell startup

```text
exec_always quickshell
```

Quickshell is already structurally part of the desktop session.

Also:

```text
exec_always /var/home/mapple/.local/bin/autotiling
```

## 12.6 Application choreography

GNOME Calendar was configured as a floating window:

```text
768x600
moved upward by 380
```

A duplicate rule was present.

`btop-cpu` was also choreographed:

```text
900x600
centered
moved upward by 380
```

This suggests a project-wide behavior:

> applications are not simply launched; their geometry can be intentionally choreographed into the desktop.

## 12.7 Wallpaper

Historical Sway wallpaper:

```text
/var/home/mapple/Downloads/Wallpapers/nightsky1.png
```

This reinforces the night-sky / celestial foundation.

Long-term, wallpaper management should migrate into Quickshell.

## 12.8 Gaps and borders

Important values:

```text
inner gaps: 8
outer gaps: 5
top gap: 1

default border: pixel 2
floating border: pixel 4
```

These indicate:

- precise spatial rhythm
- thin framing
- controlled negative space

## 12.9 Sway client colors

```text
focused:
#ED981A #1B0623 #55CFCA #DCF3FA #F2BE4F

focused_inactive:
#DCF3FA #5B5FD4 #55CFCA #DCF3FA #55CFCA

unfocused:
#DCF3FA #1B0623 #1B0623 #DCF3FA #DCF3FA

urgent:
#D16041 #1B0623 #D16041 #D16041 #ED981A

placeholder:
#55CFCA #5B5FD4 #DCF3FA #55CFCA #55CFCA
```

This shows the same semantic palette already operating at the compositor/window level.

---

# 13. Old rice: Zellij

The uploaded Zellij configuration is mostly autogenerated/default infrastructure, but it contains a very strong customized keyboard layer.

Important facts:

- autogenerated by Zellij
- previous config backed up as:
  `/var/home/mapple/.config/zellij/config.kdl.bak`
- clears defaults:

```kdl
keybinds clear-defaults=true
```

- default shell:

```kdl
default_shell "zsh"
```

- startup tips disabled:

```kdl
show_startup_tips false
```

## 13.1 Strongest design signal: unified spatial keyboard vocabulary

Examples:

```kdl
bind "h" { MoveFocus "left"; }
bind "j" { MoveFocus "down"; }
bind "k" { MoveFocus "up"; }
bind "l" { MoveFocus "right"; }
```

The same movement vocabulary is used for:

- pane focus
- tab movement
- resize
- pane movement
- scroll
- tmux compatibility behavior

That means keyboard interaction is not merely “Vim-like in one program.”

It is becoming a **cross-environment spatial language**.

## 13.2 Pane behavior

Zellij supports:

- normal panes
- floating panes
- fullscreen
- no-UI fullscreen
- pinned panes
- grouped panes
- stacked panes
- pane frames
- break-out/break-pane behavior

This fits the larger architectural pattern:

```text
stable structure
+
temporary breakout
```

## 13.3 Visual status

Zellij is **not yet visually integrated** into the rice to the same extent as the rest of the environment.

The theme configuration is largely stock/commented.

For example:

```kdl
// theme "dracula"
```

No purple/cyan/orange visual integration should be inferred from the current Zellij file.

It is on the list for future styling.

---

# 14. Kitty

Important historical/current Kitty values discussed:

```conf
font_family "GohuFont Mono 11 Nerd Font"
bold_font auto
italic_font auto
bold_italic_font auto

font_size 13

map ctrl+shift_plus change_font_size all +1.0
map ctrl+shift_minus change_font_size all -1.0

cursor_shape beam

window_padding_width 5
window_padding_height 5px

background_opacity 1

scrollback_lines 10000
```

Another relevant Kitty configuration included:

```conf
include theme.conf

background_opacity 0.8
background #1B0623

font_family family="GohuFont 11 Nerd Font Mono"

shell ~/.local/bin/kitty-zellij
```

Interpretation:

- Gohu Nerd Font is part of the main identity
- size 13
- beam cursor
- 5px internal padding
- 10,000 line scrollback
- custom font resizing
- deep-purple terminal foundation
- optional transparency
- shell wrapper starts Zellij automatically

Kitty remains part of the system.

It may receive visual integration updates, but it is not something Quickshell is intended to replace.

---

# 15. Rofi

Rofi was heavily themed and is one of the clearest predecessors to the Quickshell visual language.

Important configuration:

```text
modi: "drun,run,window"
show-icons: true
terminal: kitty
sidebar-mode: true
```

Font:

```text
Gohu
```

Custom mode labels included:

```text
drun   → -⋆♱⋆-
run    → >_
window → 🃁🃜🃚🃖🂭🂺
```

Display format:

```text
{name}
```

Window geometry:

```text
position: northwest
width: 280
x-offset: 110
y-offset: 0
border: 1
border color: orange
radius: 0
```

State language:

- selected/focused → orange/gold
- urgent → red
- scrollbar → magenta handle on cyan background

Important color:

```text
#9ece6a
```

This confirms green is already part of the project's palette history.

Future direction:

> most or all Rofi functionality should migrate into Quickshell.

That includes the application launcher.

---

# 16. Fastfetch

Fastfetch is one of the strongest terminal expressions of the rice.

Important structure:

```json
"logo": {
    "source": "~/.config/fastfetch/icon",
    "type": "file"
}
```

Logo colors use:

- gold
- orange
- white
- black
- cyan

Layout padding:

```text
top: 2
left: 2
right: 4
```

Display bars:

```text
character: ─
width: 10
```

Percent formatting:

```text
type: 3
ndigits: 2
```

Other display details:

```text
key width: 16
separator: empty
color: blink_
```

Modules were grouped around:

### Identity
- user
- host

### Date/time
- datetime

### System
- PC
- OS
- WM
- packages
- uptime

### Terminal
- shell
- terminal
- font
- size

### Hardware
- display
- CPU
- GPU
- RAM
- disk
- battery

### Media
- sound
- volume
- progress
- playing

Extensive box drawing reinforces:

- terminal dashboard
- information architecture through text
- constructed/diagrammatic text layout

The custom logo includes a computer/terminal-like graphic and “hello world” language.

---

# 17. wttr.in

The terminal weather service used is:

```text
wttr.in
```

The output itself should not be mistaken for custom rice code.

Its relevance is conceptual:

- terminal-first weather access
- ANSI output
- ASCII weather symbols
- box drawing
- compact data presentation

This fits naturally with the project.

A future graphical Weather module may exist in Quickshell, but the terminal service can remain a useful deep/alternate interface.

---

# 18. Configuration directory inventory

The discussed `~/.config` inventory included:

```text
BraveSoftware
autostart
btop
cava
dconf
evolution
fastfetch
fontconfig
gtk-3.0
gtk-4.0
htop
ibus
kitty
mako
menus
mozilla
mpd
nautilus
nemo
nvim
nvim.lazyvim.bak
org.gnome.Ptyxis
procps
pulse
quickshell
rofi
sway
systemd
toolbox
uv
waybar
wofi
yazi
zellij
zsh
```

Important “rice” components among these:

```text
Sway
Waybar
Quickshell
Kitty
Zellij
Rofi
Fastfetch
Yazi
Zsh
```

---

# 19. Quickshell directory structure

The discussed tree:

```text
~/.config/quickshell
├── archive/
│   ├── 3
│   ├── Workspaces.qml.backup
│   ├── shell.qml.backup
│   ├── shell.qml.blue
│   ├── shell.qml.broken
│   └── shell.qml.orange
├── components/
│   ├── Basicbutton.qml.template
│   ├── Colors.qml
│   └── qmldira
├── modules/
│   ├── Applauncher.qml
│   ├── Bluetooth.qml
│   ├── Calendar.qml
│   ├── Clock.qml
│   ├── Cpu.qml
│   ├── Gaming.qml
│   ├── Mediaplayer.qml
│   ├── Network.qml
│   ├── Notifications.qml
│   ├── Performancemode.qml
│   ├── Power.qml
│   ├── Screenshot.qml
│   ├── Temperature.qml
│   ├── Wallpaper.qml
│   ├── Weather.qml
│   ├── Volumebar.qml
│   └── Workspaces.qml
└── shell.qml
```

Known populated module sizes:

```text
Applauncher.qml   ~2.06 KB
Bluetooth.qml     ~1.62 KB
Clock.qml         ~3.89 KB
Network.qml       ~1.84 KB
Power.qml        ~23.18 KB
Volumebar.qml     ~4.85 KB
Workspaces.qml    ~9.28 KB
Colors.qml         451 B
shell.qml         ~1.56 KB
```

Known 0-byte placeholders:

```text
Calendar.qml
Cpu.qml
Gaming.qml
Mediaplayer.qml
Notifications.qml
Performancemode.qml
Screenshot.qml
Temperature.qml
Wallpaper.qml
Weather.qml
```

Important:

> Placeholder files should **not** automatically be treated as mandatory features.

They represent possible/anticipated modules, not a guaranteed final checklist.

---

# 20. Quickshell development history

Historical shell files included:

```text
shell.qml.orange
shell.qml.blue
shell.qml.backup
shell.qml.broken
```

The `orange` and `blue` versions were **older historical shell implementations**, not two currently maintained “themes.”

They previously contained the power-button logic directly inside the root shell.

Later:

```text
Power.qml
```

was separated into its own module.

Current Power positioning is self-contained.

Future intent:

> positioning should eventually move back under `shell.qml` ownership as part of a dynamic layout system.

So current manual coordinates are temporary implementation scaffolding.

Do **not** treat them as the desired final architecture.

---

# 21. Current `shell.qml`

The current root shell discussed was:

```qml
import Quickshell
import QtQuick
import Quickshell.Io
import Quickshell.Wayland
import "modules"
import "components"
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

PanelWindow {
    anchors {
        top: true
        bottom: false
        right: true
        left: true
    }
    margins {
        left: 200
        right: 200
        bottom: 3
    }
    WlrLayershell.layer: WlrLayer.Bottom
    implicitHeight: 70
    color: "transparent"

    Rectangle {
        anchors.centerIn: parent
        width: parent.width
        height: 50
        opacity: 0.1
        color: "transparent"
    }

    Rectangle {
        id: cyanLine
        anchors.centerIn: parent
        width: parent.width
        height: 2
        color: Colors.cyan
    }

    DropShadow {
        anchors.fill: cyanLine
        source: cyanLine
        horizontalOffset: 0
        verticalOffset: 0
        radius: 18
        samples: 37
        color: "transparent"
    }

    Rectangle {
        anchors.centerIn: parent
        width: 4
        height: 20
        opacity: 0.7
        color: Colors.cyan
    }

    Applauncher { x: 5; y: 8 }
    Workspaces { x: 80; y: 8 }
    Network { x: 1000; y: 8 }
    Bluetooth { x: 1650; y: 8 }
    Volumebar { x: 1825; y: 8 }
    Clock { x: 1996; y: 8 }
    Power {}
}
```

## 21.1 Interpretation

The root shell currently establishes:

- a `PanelWindow`
- screen-spanning top anchor
- 200px left/right margins
- 3px bottom margin
- bottom layer
- 70px shell height
- transparent background

The central structural graphic is:

```qml
Rectangle {
    width: parent.width
    height: 2
    color: Colors.cyan
}
```

This is a thin luminous cyan horizontal line.

A central marker:

```qml
Rectangle {
    width: 4
    height: 20
    opacity: 0.7
    color: Colors.cyan
}
```

acts like a reference/alignment marker.

This is strongly consistent with:

- HUD language
- instrumentation
- calibration marks
- retro-futuristic UI
- minimal linework

The transparent 50px rectangle with `opacity: 0.1` appears more like temporary/debug scaffolding than a major visual element.

---

# 22. App Launcher QML

The launcher is visually established but functionally still placeholder-stage in the version discussed.

Main traits:

```text
root Item
black Rectangle
50 × 65
```

Text:

```text
-⋆♱⋆-
```

Font size:

```text
20px
```

State:

```text
idle    → white
hover   → cyan
pressed → cyan
```

Glow:

- `DropShadow`
- radius ~14
- samples ~15
- cyan
- increasing opacity with interaction

Additional geometry glows:

- soft `RectangularShadow`
- wider `RectangularShadow`
- spreads around 3 and 10

Interaction:

- full `MouseArea`
- hover enabled
- click currently logs only
- actual process invocation was commented out

Interpretation:

> This is the visual placeholder for the future Quickshell-native replacement of the Rofi launcher.

It also establishes a repeated “basic button” language:

```text
black surface
+
20px symbolic glyph
+
white → cyan interaction
+
multi-layer cyan glow
+
full-surface MouseArea
```

---

# 23. Network QML

The network module shares the same basic visual template.

Approximate geometry:

```text
black surface
50 × 130
```

Glyph:

```text
(﹙˓🌐˒﹚)
```

Style:

```text
20px
white idle
cyan hover/pressed
```

Effects:

- `DropShadow`
- two `RectangularShadow` layers
- cyan glow

The version discussed had no meaningful click behavior yet.

Interpretation:

- placeholder/basic-stage module
- same button grammar as launcher
- text/glyph framing with parentheses
- symbolic networking identity
- wider width, same basic component language

---

# 24. Bluetooth QML

The Bluetooth module used a similar template.

A glyph shown was:

```text
(˓✟˒)
```

Even though the glyph looks cross-like, this file is the **Bluetooth module** and should not be mislabeled as a generic Christian module.

Suggested naming cleanup discussed:

```text
dock                  → bluetoothDock
textglowContainer     → bluetoothTextContainer
text                  → bluetoothText
textGlow              → bluetoothTextGlow
mouse                 → bluetoothDockMouse
dockSoftGlow          → bluetoothDockSoftGlow
dockWideGlow          → bluetoothDockWideGlow
```

Those were naming suggestions only.

No functional or aesthetic rewrite was intended by those renames.

---

# 25. Clock.qml

The Clock module is one of the first clearly stateful working HUD instruments.

Important root:

```text
id: clockArea
```

Outer sizing is based on button dimensions:

```text
clockButton.width + 20
clockButton.height + 46
```

State:

```qml
property bool is24Hour: false
```

Main visual:

```text
black
50 × 151
```

It uses a `SystemClock` with second-level precision.

The row contains:

```text
icon + clock text
```

with spacing around:

```text
9
```

Decorative icon:

```text
 ๋࣭🕰 ⭑
```

Font:

```text
20px
```

Clock formatting:

```qml
is24Hour ? "HH:mm AP" : "hh:mm AP"
```

Important intentional behavior:

> AM/PM remains visible even in 24-hour mode.

This is deliberate because it makes the clock easier to interpret for people unfamiliar with military time.

It should **not** be “corrected” as if it were a bug.

## 25.1 Clock color state

```text
12-hour mode → cyan
24-hour mode → orange
```

Both the icon and clock text follow that mode state.

## 25.2 Clock glow

Each text element uses a glow such as:

```text
DropShadow
radius: 14
samples: 15
```

Interaction state modifies glow intensity:

```text
idle < hover < pressed
```

Approximate opacity progression discussed:

```text
0.6 / 0.8 / 1.0
```

Additional rectangular glow also follows the clock's mode color.

## 25.3 Clock interaction

Mouse input:

- left click → currently logging/normal action
- right click → toggles 12/24-hour mode

This is a recurring interaction pattern:

> primary click for normal action, secondary click for alternate mode/control.

## 25.4 Future semantic-text refactor

Clock is one of the clearest candidates for the new text-separation rule.

Instead of:

```text
12:34 PM
```

as one `Text`, future structure can be:

```qml
Row {
    Text { text: "12"; color: Colors.cyan }
    Text { text: ":";  color: Colors.white }
    Text { text: "34"; color: Colors.cyan }
    Text { text: " PM"; color: Colors.white }
}
```

---

# 26. Volumebar.qml

The volume module is one of the strongest examples of the intended Quickshell architecture.

It directly reads live audio state through PipeWire rather than shelling out to a graphical frontend.

Core:

```qml
property var sink: Pipewire.defaultAudioSink
```

Other logical properties:

```text
ready
muted
vol
```

The volume is converted into percent-like presentation.

## 26.1 Volume glyph/meter states

The dynamic icon logic discussed:

```text
not ready:
Nerd Font codepoint 0xf0581

muted:
⊹ ࣪ ˖(ᴗ˳ᴗ)ᶻ𝗓

0:
░░░░░░░

<10:
█░░░░░

<30:
██░░░░░

<40:
██░░░░░

<60:
████░░░

<80:
█████░░

>=80:
███████
```

There is a duplicated-looking `<30` / `<40` visual threshold.

That was noted, but should not automatically be treated as a required bug fix.

## 26.2 Volume colors

Icon/text:

```text
not ready → white/yellow-context
muted     → white/yellow-context
active    → cyan
```

Glow:

```text
muted / not-ready → yellow
active            → cyan
```

## 26.3 Telemetry-driven glow

A particularly important design pattern:

> live numeric state does not only change the text; it changes the intensity/size of the visual effect.

Example logic discussed:

```text
radius ≈ 6 + volume * 0.16
```

Active glow opacity approximates:

```text
0.20 + (volume / 100) * 0.90
```

Muted/not-ready can suppress the active glow.

This makes the module feel like a **live instrument** rather than a passive label.

## 26.4 Percentage display

Current logic resembles:

```text
not ready → "-"
muted     → " ࣪ ˖"
normal    → volume + "%"
```

Text color:

```text
muted/not-ready → white
active          → cyan
```

There is also extra glow behavior at extreme/high volume, including a special condition around `>= 200`.

## 26.5 Backend tracking

The module uses:

```qml
PwObjectTracker
```

to track the sink.

This is important architecturally:

> Quickshell can react directly to live backend objects rather than periodically parsing shell command output.

## 26.6 Interaction

- right click → mute/unmute
- mouse wheel → ±0.05 volume
- lower bound constrained to 0
- no explicit 100% upper bound in the discussed code

That makes over-amplification possible.

Again, the project uses multiple input modalities:

```text
hover
click
right-click
wheel
```

## 26.7 Future semantic-text refactor

Instead of one string:

```text
75%
```

future presentation should become:

```qml
Row {
    Text {
        text: volumeNumber
        color: Colors.cyan
    }

    Text {
        text: "%"
        color: Colors.white
    }
}
```

---

# 27. Workspaces.qml

Workspaces is one of the most mature Quickshell modules discussed.

Imports include:

```qml
import Quickshell
import QtQuick
import QtQml
import QtQuick.Layouts
import Quickshell.Io
import "components"
import Quickshell.I3
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
```

The module demonstrates a stronger architecture than the placeholder buttons because it uses Quickshell's Sway/I3 integration directly.

## 27.1 Root

```text
Rectangle id: workspacesDock
```

Width is based on content:

```text
row implicit width + 13
```

Height:

```text
row implicit height + 8
```

Background:

```text
black
```

State colors:

```qml
property color inactiveColor: Colors.cyan
property color activeColor: Colors.orange
```

Interaction state includes:

```text
workspacesButtonPressed
workspacesButtonHovered
```

## 27.2 Dock glow

Two `RectangularShadow` layers surround the dock.

Approximate spread:

```text
3
10
```

Interaction changes opacity.

Color pattern discussed:

```text
pressed → cyan
hover   → orange
idle    → cyan
```

A full-dock `MouseArea` exists for hover state only:

```qml
acceptedButtons: Qt.NoButton
```

That is an intentional pattern: parent-level hover effects can react even though children own the actual clicks.

## 27.3 Debug/exploratory Sway subscription

There is a `Process` subscribing to:

```text
swaymsg -t subscribe ["workspace"]
```

with logs and a `SplitParser`.

This appears exploratory/debug-oriented.

The important point:

> It coexists with the real reactive `I3.workspaces` API and should not be mistaken for the authoritative state path.

## 27.4 Actual workspace state

The `Repeater` model is:

```qml
I3.workspaces
```

Active state:

```qml
I3.focusedWorkspace?.num === workspaceNumber
```

Workspace number:

```qml
modelData.number
```

Each workspace is approximately:

```text
25 px wide
42 px high
```

when visible.

Z-order:

```text
active → 2
inactive → 1
```

## 27.5 Context-sensitive visibility

A special monitor rule exists around:

```text
HDMI-A-1
```

The module can hide/show workspaces depending on:

- monitor
- active state
- whether the workspace has windows

This is important:

> the shell is already context-sensitive rather than blindly rendering all data.

## 27.6 Active workspace background

An active background rectangle is:

- centered
- full-size
- dark
- partly opaque when active

Another background object exists with an opacity that is effectively always `0.0`, suggesting historical or unfinished inactive-state infrastructure.

## 27.7 Workspace text

Current workspace identifier:

```text
workspace number
```

Font size:

```text
20px
```

Color logic:

Normal displays:

```text
active   → orange
inactive → cyan
```

Special HDMI-A-1 context:

```text
active   → yellow
inactive → white
```

This is a good example of local/contextual semantics overriding the default global scheme.

## 27.8 Workspace glow

Two levels:

- standard text glow
- extra active glow

Interaction strength roughly follows:

```text
idle → hover → pressed
0.6 → 0.8 → 1.0
```

Active workspace gets additional emphasis.

This shows a recurring rule:

> active state is communicated by **color + extra glow**, not necessarily by large geometric changes.

## 27.9 Workspace control

Per-workspace processes include:

```text
swaymsg workspace <number>
```

Scrolling:

```text
swaymsg workspace prev
swaymsg workspace next
```

Another test process:

```text
swaymsg -t get_workspaces -r
```

logs JSON but was not being used as the live display source.

Input:

- click → select workspace
- wheel → previous/next
- hover/press state propagates to parent dock glow

## 27.10 Architectural significance

Workspaces demonstrates:

```text
backend state
    ↓
Quickshell reactive object
    ↓
QML content/state
    ↓
visual color/glow
    ↓
direct user control
    ↓
backend action
```

This is probably the clearest small-scale model for how future Quickshell modules should work.

---

# 28. Workspace redesign direction

The workspace numbers are under consideration for a more symbolic/minimal presentation.

Ideas discussed:

- Braille
- Roman numerals
- CRT glitch
- playing cards
- face/mask glyph
- symbolic identity instead of conventional numeric buttons

The strongest current direction is playing-card language.

An early idea was:

```text
♠Ⅰ ♥Ⅱ ♦Ⅲ ♣Ⅳ
```

but the preference shifted toward actual card ranks:

```text
♠A
♥K
♦Q
♣J
```

plus a simple Joker/special-workspace symbol.

Possible Joker directions discussed:

```text
✦J
★J
✦
```

The simpler:

```text
✦
```

was attractive because it visually behaves more like a text glyph and does not become an emoji card image.

No final suit-to-workspace mapping should be treated as locked yet.

---

# 29. CRT glitch behavior

The workspace redesign may include an occasional CRT-like glitch.

The key design decision:

> the glitch should be an event, not a constant animation.

Desired behavior:

### Interaction-triggered
A low probability when:

- clicking
- switching
- hovering
- interacting

### Idle-triggered
A very low probability random glitch while the shell is otherwise idle.

### Safety/usability requirements

- cooldown between glitches
- very short duration
- never breaks functionality
- active workspace must remain identifiable
- should feel like a physical/display artifact, not random chaos

Possible glitch manifestations:

- brief glyph substitution
- tiny horizontal displacement
- short disappearance
- ghost/double image
- brightness flicker
- character corruption
- cyan/orange flash
- momentary text offset

The intended feeling is “old display personality,” not “broken software.”

---

# 30. Power module

Power is historically important because it contains many interaction ideas that later became recognizable project conventions.

It is a `PanelWindow` with a state machine.

Core state:

```qml
property bool menuOpen: false
property bool confirmShutdown: false
property bool confirmReboot: false
property int clickCount: 0
property int pressCount: 0
property int selectedIndex: 0
property int hoveredIndex: 0
property bool keyboardActive: false
```

Processes:

```qml
Process {
    id: lockProcess
    command: ["swaylock"]
}

Process {
    id: logoutProcess
    command: ["swaymsg", "exit"]
}

Process {
    id: rebootProcess
    command: ["systemctl", "reboot"]
}

Process {
    id: shutdownProcess
    command: ["systemctl", "poweroff"]
}
```

This is a textbook example of the intended architectural philosophy:

> QML is the graphical control surface; the actual system action remains delegated to normal Linux tools.

## 30.1 Panel geometry

Historical Power panel:

```text
bottom-right
220 × 290
transparent
focusable
right margin: 10
bottom margin: 10
```

Power button:

```text
50 × 50
x: 155
y: 230
```

This manual placement is historical/current scaffolding, not a final dynamic-layout commitment.

## 30.2 Power button

Glyph:

```text
⏻
```

Approximate size:

```text
35px
```

Visual language in the more developed variant:

```text
idle        → white text / cyan glow
hover       → orange text / orange glow
pressed     → orange or special pressed behavior depending on revision
```

The historical variants differ slightly, which is useful because they show the process of converging on a state language.

## 30.3 Power menu

Approximate size:

```text
150 × 200
```

Position:

```text
x: 35
y: 20
```

Surface:

```text
black
```

Title:

```text
POWER MENU
```

with cyan text and around `20px`.

Below it:

```text
2px cyan separator
```

Options:

```text
Lock
Logout
Reboot
Shutdown
```

## 30.4 Power menu state language

Normal:

```text
black background
cyan text
```

Hover/selection:

```text
yellow/gold background
orange text
orange glow
```

Pressed:

```text
Lock / Logout  → magenta-associated
Reboot/Shutdown→ red-associated
```

This is where the semantic role of destructive actions becomes explicit.

## 30.5 Keyboard navigation

The menu handles:

```text
Up
Down
Escape
Enter
```

Selection wraps from the first to last item and vice versa.

On menu open:

```text
selectedIndex = 1
forceActiveFocus()
```

This establishes a repeated UX preference:

- open menu
- immediate keyboard focus
- predictable initial selection
- wrapping navigation
- Enter activates
- Escape closes

## 30.6 Mouse + keyboard coexistence

`keyboardActive` helps distinguish whether the keyboard or mouse is currently driving selection.

Hover can update `selectedIndex`.

This is an important design goal:

> mouse and keyboard should feel like two equal ways to manipulate the same state, not two separate UI systems.

## 30.7 Destructive confirmation

Reboot and Shutdown do not need to execute instantly.

Instead:

```text
normal menu
    ↓
confirmation state
    ↓
Cancel / Confirm
```

Confirmation happens **in place**.

This supports:

- safety
- continuity
- compact shell geometry
- stronger red/destructive semantics

## 30.8 Historical significance

Power contains many pieces of the project's later design DNA:

- dark substrate
- cyan baseline
- orange focus
- gold selection
- magenta pressed/special
- red destructive
- glow as semantic feedback
- Unicode glyphs
- thin separators
- keyboard-first navigation
- direct backend Process calls
- local UI state machine
- in-place confirmations

Some repetition/debug code is historical and does not need to be preserved literally in future refactors.

---

# 31. Screenshots and observed visual behavior

Screenshots showed:

- purple/cyan/orange overall identity
- Quickshell visibly active
- power button/menu
- Yazi
- btop
- Neovim/terminal workflow
- browser/application areas
- a second Quickshell bar
- large negative space
- night/purple wallpaper environment
- thin HUD-like shell elements rather than traditional opaque taskbars

Important clarification:

> the power menu/button and the second bar were Quickshell, not Waybar.

A secondary monitor showed older Quickshell error output, but that appeared to be historical/temporary rather than a current design direction.

The visual identity across monitors was otherwise consistent.

---

# 32. Existing Quickshell roles

Already present or meaningfully implemented:

```text
application launcher
workspaces
network
Bluetooth
volume
clock
power
secondary/top shell bar
```

Possible/future roles:

```text
remaining Waybar functionality
notifications
media player controls
weather
CPU/system monitoring
temperature
screenshots
wallpaper
gaming controls
performance controls
session/logout controls
audio mixer
network management UI
Bluetooth management UI
calendar
other system indicators
```

The goal is broad:

> Quickshell should do as much desktop-facing work as reasonably practical.

But it should not reimplement the underlying services.

---

# 33. What should remain outside Quickshell

The project is **not** trying to eliminate specialized CLI/TUI applications.

Strong examples that should remain deep tools:

```text
Neovim
Yazi
btop
nvtop
ncmpcpp
Zellij
Kitty
shell utilities
```

Quickshell can provide a fast graphical gateway or overview, while those applications remain the deeper interface.

Example:

```text
Quickshell CPU indicator
     ↓ click
Kitty + btop
```

That “glanceable state → deeper tool” pattern existed already in Waybar and remains valuable.

---

# 34. Repeated UX language

The strongest recurring interaction conventions are:

- glanceable information
- shell elements are controls, not passive decorations
- hover increases brightness/glow
- active state often becomes orange
- urgent/destructive state becomes red
- click leads to a deeper interface or action
- right-click provides alternate action
- mouse wheel adjusts continuous values
- keyboard remains first-class
- `h/j/k/l` spatial navigation
- arrow-key equivalents
- Enter activates
- Escape cancels/closes
- menus focus themselves on open
- navigation wraps
- hover changes selection
- pressed state is visually distinct
- destructive actions get confirmation
- confirmation is often in place
- system state drives visuals
- multiple input modalities should converge on the same logical state

---

# 35. Repeated architectural language

The architecture repeatedly follows:

```text
backend/service
    ↓
live state or command bridge
    ↓
QML module
    ↓
visual presentation
    ↓
user interaction
    ↓
backend action
```

Examples:

```text
PipeWire
  ↓
Volumebar.qml
  ↓
meter / percentage / glow
  ↓
wheel / right-click
  ↓
volume / mute
```

```text
Sway
  ↓
I3.workspaces
  ↓
Workspaces.qml
  ↓
workspace glyph / glow
  ↓
click / wheel
  ↓
swaymsg workspace
```

```text
systemd
  ↓
Power.qml
  ↓
power menu
  ↓
confirmation
  ↓
systemctl reboot/poweroff
```

---

# 36. Old rice vs current QML

| Category | Old rice | Current Quickshell direction |
|---|---|---|
| Window management | Sway | Sway remains |
| Persistent HUD | Waybar | Quickshell |
| Launcher | Rofi | Quickshell |
| Workspaces | Waybar + Sway | Quickshell + Sway/I3 |
| Network | Waybar + NM GUI | Quickshell over NetworkManager |
| Bluetooth | Waybar + Blueman | Quickshell frontend |
| Audio | Waybar + Pavucontrol | Quickshell over PipeWire |
| Power/session | Waybar/wlogout-style | Quickshell |
| Clock | Waybar | Quickshell |
| Wallpaper | Sway/static | eventually Quickshell |
| Notifications | Mako | possibly Quickshell |
| Media | MPD + Waybar + ncmpcpp | Quickshell overview/control + deep TUI |
| Monitoring | Waybar + btop/nvtop | Quickshell overview + deep TUI |
| Weather | wttr.in | Quickshell UI + terminal option |
| File manager | Yazi in Kitty | remains Yazi |
| Editor | Neovim | remains Neovim |
| Terminal | Kitty | remains Kitty |
| Multiplexer | Zellij | remains Zellij |
| Deep controls | CLI/TUI | still CLI/TUI |

---

# 37. The old rice already contained the new design system

A central conclusion from comparing the systems is:

> Quickshell did not invent the rice's aesthetic; it is centralizing it.

Waybar, Rofi, Sway, Kitty and Fastfetch had already established:

- the palette
- the glow
- the Gohu typography
- the terminal-first thinking
- the symbolic glyphs
- the active/urgent color distinctions
- the sparse HUD
- the clickable “portal into a deeper tool” pattern

Quickshell is allowing those ideas to stop being independent themes and become a **single system-level language**.

---

# 38. From palette to state language

The old rice primarily proved:

```text
these colors belong together
```

The newer QML proves:

```text
these colors mean things
```

Examples:

```text
cyan
→ normal
→ information
→ data
→ active audio
```

```text
orange
→ focused
→ active
→ mode change
→ hot/important
```

```text
red
→ destructive
→ urgent
```

```text
magenta
→ pressed/special state
```

```text
gold/yellow
→ selection
→ muted/not-ready local states
```

This is a major maturation of the visual language.

---

# 39. UI as instrument panel

A major project characteristic is that widgets should feel like instruments.

A conventional widget:

```text
"Volume: 75%"
```

Your direction:

```text
█████░░ 75%
```

plus:

- live color
- glow intensity
- mute state
- wheel control
- alternate click
- backend integration

Likewise, a workspace selector is not merely a set of tabs.

It is a live visual representation of the compositor state.

This gives the whole desktop a “control console” or “instrument panel” quality.

---

# 40. Old-machine / futuristic-machine tension

One of the strongest thematic observations is that the system mixes:

## Old-computer language

- CRT
- ASCII
- box drawing
- monospace
- pixel fonts
- terminal interfaces
- old TV language
- old game screens
- old PC visuals
- card symbols
- character corruption/glitches

with:

## Modern implementation

- Wayland
- Sway
- Quickshell
- QML
- PipeWire
- reactive APIs
- live telemetry
- GPU monitoring
- dynamic visual effects

The resulting identity can be thought of as:

> **an old futuristic computer implemented with a modern Linux desktop stack.**

---

# 41. Sparse HUD and negative space

The shell should not become a dense dashboard that permanently occupies a large fraction of the screen.

The repeated spatial language is:

```text
wallpaper
   ↓
large negative space
   ↓
thin luminous HUD
   ↓
small controls / telemetry
   ↓
application windows
```

This is why the central line and small button clusters fit the project so well.

The shell should feel present without feeling bulky.

---

# 42. Geometry and framing

Repeated geometry:

- square
- radius 0 or very small
- thin borders
- small controlled padding
- precise gaps
- long horizontal line
- compact buttons
- narrow module strips

The visual “weight” usually comes from:

```text
glow
```

rather than:

```text
thick border
large rounded card
heavy opaque panel
```

---

# 43. Strong recurring design elements: master list

## Visual

- deep purple background
- cyan primary
- orange active/focus/hot
- pale off-white/cyan neutral
- red-orange urgent
- magenta special/pressed
- gold/yellow selected
- green established and awaiting broader use
- multi-layer glow
- restrained borders
- black interactive surfaces
- square/slightly-rounded geometry
- large negative space
- sparse HUD
- monospace/pixel font
- Nerd Font
- Unicode symbols
- Christian symbols
- celestial/star imagery
- card symbolism
- parentheses/brackets
- box drawing
- ASCII structures
- text meters
- linework
- central reference markers
- transparent shell areas
- selective animation
- telemetry-driven visuals
- CRT/glitch potential

## UX

- glanceable information
- clickable indicators
- hover brightens
- active state becomes stronger
- right-click for alternate actions
- wheel for continuous adjustment
- keyboard-first navigation
- `h/j/k/l`
- arrow equivalents
- Enter activate
- Escape cancel
- wrap-around menu navigation
- auto focus on open
- mouse hover updates selection
- pressed state distinct
- confirmation for destructive actions
- in-place confirmation
- system state drives appearance
- multiple input modalities
- temporary breakout windows
- deeper app/tool on click

## Architecture

- Sway = compositor/spatial layer
- Quickshell = unified graphical shell
- Kitty = terminal workspace
- Zellij = terminal spatial layer
- Neovim/Yazi/btop/etc. = specialized deep tools
- existing Linux backends remain authoritative
- QML provides presentation/control
- direct reactive APIs preferred when available
- `Process` bridges are valid where appropriate
- debug Processes may coexist during development
- modular QML
- shared Colors component
- root shell should eventually own dynamic placement
- manual coordinates are temporary
- Quickshell absorbs Waybar/Rofi graphical responsibilities
- application geometry can be choreographed
- stable structure + temporary breakout

---

# 44. Current development quality / maturity by module

A useful classification:

```text
Applauncher   → visually established, functional placeholder
Network       → visually established, functional placeholder/basic
Bluetooth     → visually established/basic
Clock         → working stateful module
Volumebar     → working backend-integrated module
Workspaces    → mature backend-integrated module
Power         → large working stateful module, historically evolved
Calendar      → placeholder
CPU           → placeholder
Gaming        → placeholder
Mediaplayer   → placeholder
Notifications → placeholder
Performance   → placeholder
Screenshot    → placeholder
Temperature   → placeholder
Wallpaper     → placeholder
Weather       → placeholder
```

This is not a criticism.

It simply reflects where the project is in its migration.

---

# 45. Known current scaffolding / things not to overinterpret

The following should be treated as development-stage details rather than immutable design rules:

- absolute `x`/`y` positioning in `shell.qml`
- Power self-positioning
- debug counters
- console logging
- redundant Processes
- unused/test JSON workspace retrieval
- always-transparent background rectangles
- duplicated volume threshold visuals
- commented experimental shadow layers
- archived `blue`/`orange` shell files
- old Quickshell errors on another monitor
- 0-byte placeholder modules

Future architecture should use more dynamic placement from the root shell.

---

# 46. Important intentional quirks

Not every unusual behavior should be “fixed.”

Example:

```text
24-hour clock + AM/PM
```

is intentional.

Reason:

> it helps people unfamiliar with military time quickly understand the time.

General rule:

> personal or unusual behavior may be a deliberate design feature.

Do not normalize the desktop toward generic conventions without first understanding intent.

---

# 47. Migration philosophy

The migration is broader than:

```text
Waybar → Quickshell
Rofi   → Quickshell
```

The real scope is:

> move as much reasonable desktop-facing graphical work as possible into Quickshell.

Potential migration targets include:

- Waybar modules
- Rofi launcher/window/run interfaces
- wlogout-style power interface
- Pavucontrol graphical volume mixer
- graphical wallpaper controls
- network UI
- Bluetooth UI
- notifications
- media controls
- monitoring UI
- screenshots
- calendar UI
- weather UI
- gaming/performance toggles

But again:

```text
Quickshell replaces frontends, not services.
```

---

# 48. Design principle: glanceable shell, deep tool

A highly reusable project pattern is:

```text
small persistent state
        ↓ click
deeper specialized interface
```

Examples old/current:

```text
CPU HUD
  ↓
btop
```

```text
GPU HUD
  ↓
nvtop
```

```text
MPD summary
  ↓
ncmpcpp
```

```text
calendar HUD
  ↓
calendar application
```

This model can survive the migration into Quickshell.

Quickshell does not need to duplicate the full complexity of every specialized tool.

---

# 49. Design principle: live state should affect more than text

A recurring QML lesson:

The UI should respond to state through multiple visual channels.

For example:

```text
value changes
   ↓
text changes
   +
glyph changes
   +
color changes
   +
glow changes
   +
opacity changes
```

The Volume module already demonstrates this strongly.

Future modules can follow the same principle.

---

# 50. Design principle: symbols can replace generic GUI vocabulary

The desktop increasingly prefers symbolic identity over ordinary app labels.

Examples:

```text
launcher:
-⋆♱⋆-
```

```text
workspace:
♠A / ♥K / ♦Q / ♣J / ✦
```

```text
power:
⏻
```

```text
volume:
█████░░
```

This is one of the most distinctive aspects of the project.

The shell can become recognizable even when text labels are minimal.

---

# 51. Design principle: Christian/celestial language

The Christian and celestial motifs should remain genuine and intentional.

Examples include:

- crosses
- star clusters
- night-sky wallpaper
- celestial decorative punctuation
- symbolic combinations such as the launcher mark

This should be treated as part of the identity, not mischaracterized as occult symbolism.

---

# 52. Overall conceptual summary

The project started as a highly themed Linux rice.

It is becoming something closer to a lightweight custom desktop environment:

```text
               VISUAL LANGUAGE
                     │
     ┌───────────────┼────────────────┐
     │               │                │
   COLOR          TYPOGRAPHY       SYMBOLS
     │               │                │
     └───────────────┼────────────────┘
                     │
                     ▼
               INTERACTION
                     │
                     ▼
                SYSTEM STATE
                     │
                     ▼
              UNIFIED SHELL
```

The most important evolution is:

```text
themed applications
        ↓
coherent environment
```

The aesthetic was already recognizable.

Quickshell is making the interaction and architecture equally coherent.

---

# 53. Concise project manifesto

A compact statement of the project as learned so far:

> Build a Christian/celestial, retro-computing, neon, terminal-oriented Wayland desktop where Quickshell becomes the unified graphical control surface over ordinary Linux services, while Kitty/Zellij/TUI applications remain the deep work environment. Use a sparse HUD, Gohu/Nerd Font typography, symbolic Unicode language, semantic colors, strong glow, thin geometry, large negative space, live telemetry, keyboard-first navigation, and playful controlled CRT/gaming influences. Prefer stateful “instruments” over generic widgets, and let data, system state, interaction state and visual effects all reinforce one another.

---

# 54. Appendix A — Exact uploaded Zellij configuration

The following is the complete uploaded Zellij configuration that was discussed.

```kdl
//
// THIS FILE WAS AUTOGENERATED BY ZELLIJ, THE PREVIOUS FILE AT THIS LOCATION WAS COPIED TO: /var/home/mapple/.config/zellij/config.kdl.bak
//

keybinds clear-defaults=true {
    locked {
        bind "Ctrl g" { SwitchToMode "normal"; }
    }
    pane {
        bind "left" { MoveFocus "left"; }
        bind "down" { MoveFocus "down"; }
        bind "up" { MoveFocus "up"; }
        bind "right" { MoveFocus "right"; }
        bind ";" { FocusLastPane; }
        bind "c" { SwitchToMode "renamepane"; PaneNameInput 0; }
        bind "d" { NewPane "down"; SwitchToMode "normal"; }
        bind "e" { TogglePaneEmbedOrFloating; SwitchToMode "normal"; }
        bind "f" { ToggleFocusFullscreen; SwitchToMode "normal"; }
        bind "Shift f" { ToggleFocusNoUiFullscreen; SwitchToMode "normal"; }
        bind "h" { MoveFocus "left"; }
        bind "i" { TogglePanePinned; SwitchToMode "normal"; }
        bind "j" { MoveFocus "down"; }
        bind "k" { MoveFocus "up"; }
        bind "l" { MoveFocus "right"; }
        bind "n" { NewPane; SwitchToMode "normal"; }
        bind "p" { SwitchFocus; }
        bind "Ctrl p" { SwitchToMode "normal"; }
        bind "r" { NewPane "right"; SwitchToMode "normal"; }
        bind "s" { NewPane "stacked"; SwitchToMode "normal"; }
        bind "w" { ToggleFloatingPanes; SwitchToMode "normal"; }
        bind "z" { TogglePaneFrames; SwitchToMode "normal"; }
    }
    tab {
        bind "left" { GoToPreviousTab; }
        bind "down" { GoToNextTab; }
        bind "up" { GoToPreviousTab; }
        bind "right" { GoToNextTab; }
        bind "1" { GoToTab 1; SwitchToMode "normal"; }
        bind "2" { GoToTab 2; SwitchToMode "normal"; }
        bind "3" { GoToTab 3; SwitchToMode "normal"; }
        bind "4" { GoToTab 4; SwitchToMode "normal"; }
        bind "5" { GoToTab 5; SwitchToMode "normal"; }
        bind "6" { GoToTab 6; SwitchToMode "normal"; }
        bind "7" { GoToTab 7; SwitchToMode "normal"; }
        bind "8" { GoToTab 8; SwitchToMode "normal"; }
        bind "9" { GoToTab 9; SwitchToMode "normal"; }
        bind "[" { BreakPaneLeft; SwitchToMode "normal"; }
        bind "]" { BreakPaneRight; SwitchToMode "normal"; }
        bind "b" { BreakPane; SwitchToMode "normal"; }
        bind "h" { GoToPreviousTab; }
        bind "j" { GoToNextTab; }
        bind "k" { GoToPreviousTab; }
        bind "l" { GoToNextTab; }
        bind "n" { NewTab; SwitchToMode "normal"; }
        bind "r" { SwitchToMode "renametab"; TabNameInput 0; }
        bind "s" { ToggleActiveSyncTab; SwitchToMode "normal"; }
        bind "Ctrl t" { SwitchToMode "normal"; }
        bind "x" { CloseTab; SwitchToMode "normal"; }
        bind "tab" { ToggleTab; }
    }
    resize {
        bind "left" { Resize "Increase left"; }
        bind "down" { Resize "Increase down"; }
        bind "up" { Resize "Increase up"; }
        bind "right" { Resize "Increase right"; }
        bind "+" { Resize "Increase"; }
        bind "-" { Resize "Decrease"; }
        bind "=" { Resize "Increase"; }
        bind "H" { Resize "Decrease left"; }
        bind "J" { Resize "Decrease down"; }
        bind "K" { Resize "Decrease up"; }
        bind "L" { Resize "Decrease right"; }
        bind "h" { Resize "Increase left"; }
        bind "j" { Resize "Increase down"; }
        bind "k" { Resize "Increase up"; }
        bind "l" { Resize "Increase right"; }
        bind "Ctrl n" { SwitchToMode "normal"; }
    }
    move {
        bind "left" { MovePane "left"; }
        bind "down" { MovePane "down"; }
        bind "up" { MovePane "up"; }
        bind "right" { MovePane "right"; }
        bind "h" { MovePane "left"; }
        bind "Ctrl h" { SwitchToMode "normal"; }
        bind "j" { MovePane "down"; }
        bind "k" { MovePane "up"; }
        bind "l" { MovePane "right"; }
        bind "n" { MovePane; }
        bind "p" { MovePaneBackwards; }
        bind "tab" { MovePane; }
    }
    scroll {
        bind "c" { CopyLastCommandOutput; SwitchToMode "normal"; }
        bind "e" { EditScrollback; SwitchToMode "normal"; }
        bind "s" { SwitchToMode "entersearch"; SearchInput 0; }
    }
    search {
        bind "c" { SearchToggleOption "CaseSensitivity"; }
        bind "n" { Search "down"; }
        bind "o" { SearchToggleOption "WholeWord"; }
        bind "p" { Search "up"; }
        bind "w" { SearchToggleOption "Wrap"; }
    }
    session {
        bind "[" { FocusGuestSession; SwitchToMode "normal"; }
        bind "]" { FocusHostSession; SwitchToMode "normal"; }
        bind "a" {
            LaunchOrFocusPlugin "zellij:about" {
                floating true
                move_to_focused_tab true
            }
            SwitchToMode "normal"
        }
        bind "c" {
            LaunchOrFocusPlugin "configuration" {
                floating true
                move_to_focused_tab true
            }
            SwitchToMode "normal"
        }
        bind "f" { ToggleHostFullscreen; SwitchToMode "normal"; }
        bind "l" {
            LaunchOrFocusPlugin "zellij:layout-manager" {
                floating true
                move_to_focused_tab true
            }
            SwitchToMode "normal"
        }
        bind "Ctrl o" { SwitchToMode "normal"; }
        bind "p" {
            LaunchOrFocusPlugin "plugin-manager" {
                floating true
                move_to_focused_tab true
            }
            SwitchToMode "normal"
        }
        bind "s" {
            LaunchOrFocusPlugin "zellij:share" {
                floating true
                move_to_focused_tab true
            }
            SwitchToMode "normal"
        }
        bind "w" {
            LaunchOrFocusPlugin "session-manager" {
                floating true
                move_to_focused_tab true
            }
            SwitchToMode "normal"
        }
    }
    shared_except "locked" {
        bind "Alt left" { MoveFocusOrTab "left"; }
        bind "Alt down" { MoveFocus "down"; }
        bind "Alt up" { MoveFocus "up"; }
        bind "Alt right" { MoveFocusOrTab "right"; }
        bind "Alt +" { Resize "Increase"; }
        bind "Alt -" { Resize "Decrease"; }
        bind "Alt =" { Resize "Increase"; }
        bind "Alt [" { PreviousSwapLayout; }
        bind "Alt ]" { NextSwapLayout; }
        bind "Alt f" { ToggleFloatingPanes; }
        bind "Ctrl g" { SwitchToMode "locked"; }
        bind "Alt h" { MoveFocusOrTab "left"; }
        bind "Alt i" { MoveTab "left"; }
        bind "Alt j" { MoveFocus "down"; }
        bind "Alt k" { MoveFocus "up"; }
        bind "Alt l" { MoveFocusOrTab "right"; }
        bind "Alt n" { NewPane; }
        bind "Alt o" { MoveTab "right"; }
        bind "Alt p" { TogglePaneInGroup; }
        bind "Alt Shift p" { ToggleGroupMarking; }
        bind "Ctrl q" { Quit; }
    }
    shared_except "locked" "move" {
        bind "Ctrl h" { SwitchToMode "move"; }
    }
    shared_except "locked" "session" {
        bind "Ctrl o" { SwitchToMode "session"; }
    }
    shared_except "locked" "scroll" "search" "tmux" {
        bind "Ctrl b" { SwitchToMode "tmux"; }
    }
    shared_except "locked" "scroll" "search" {
        bind "Ctrl s" { SwitchToMode "scroll"; }
    }
    shared_except "locked" "tab" {
        bind "Ctrl t" { SwitchToMode "tab"; }
    }
    shared_except "locked" "pane" {
        bind "Ctrl p" { SwitchToMode "pane"; }
    }
    shared_except "locked" "resize" {
        bind "Ctrl n" { SwitchToMode "resize"; }
    }
    shared_except "normal" "locked" "entersearch" {
        bind "enter" { SwitchToMode "normal"; }
    }
    shared_except "normal" "locked" "entersearch" "renametab" "renamepane" {
        bind "esc" { SwitchToMode "normal"; }
    }
    shared_among "pane" "tmux" {
        bind "x" { CloseFocus; SwitchToMode "normal"; }
    }
    shared_among "scroll" "search" {
        bind "PageDown" { PageScrollDown; }
        bind "PageUp" { PageScrollUp; }
        bind "left" { PageScrollUp; }
        bind "down" { ScrollDown; }
        bind "up" { ScrollUp; }
        bind "right" { PageScrollDown; }
        bind "[" { ScrollToPreviousPrompt; }
        bind "]" { ScrollToNextPrompt; }
        bind "Ctrl b" { PageScrollUp; }
        bind "Ctrl c" { ScrollToBottom; SwitchToMode "normal"; }
        bind "d" { HalfPageScrollDown; }
        bind "Ctrl f" { PageScrollDown; }
        bind "h" { PageScrollUp; }
        bind "j" { ScrollDown; }
        bind "k" { ScrollUp; }
        bind "l" { PageScrollDown; }
        bind "m" { SelectCommandAtScrollPosition; }
        bind "Ctrl s" { SwitchToMode "normal"; }
        bind "u" { HalfPageScrollUp; }
    }
    entersearch {
        bind "Ctrl c" { SwitchToMode "scroll"; }
        bind "esc" { SwitchToMode "scroll"; }
        bind "enter" { SwitchToMode "search"; }
    }
    renametab {
        bind "esc" { UndoRenameTab; SwitchToMode "tab"; }
    }
    shared_among "renametab" "renamepane" {
        bind "Ctrl c" { SwitchToMode "normal"; }
    }
    renamepane {
        bind "esc" { UndoRenamePane; SwitchToMode "pane"; }
    }
    shared_among "session" "tmux" {
        bind "d" { Detach; }
    }
    tmux {
        bind "left" { MoveFocus "left"; SwitchToMode "normal"; }
        bind "down" { MoveFocus "down"; SwitchToMode "normal"; }
        bind "up" { MoveFocus "up"; SwitchToMode "normal"; }
        bind "right" { MoveFocus "right"; SwitchToMode "normal"; }
        bind "space" { NextSwapLayout; }
        bind "\"" { NewPane "down"; SwitchToMode "normal"; }
        bind "%" { NewPane "right"; SwitchToMode "normal"; }
        bind "," { SwitchToMode "renametab"; }
        bind "[" { SwitchToMode "scroll"; }
        bind "Ctrl b" { Write 2; SwitchToMode "normal"; }
        bind "c" { NewTab; SwitchToMode "normal"; }
        bind "h" { MoveFocus "left"; SwitchToMode "normal"; }
        bind "j" { MoveFocus "down"; SwitchToMode "normal"; }
        bind "k" { MoveFocus "up"; SwitchToMode "normal"; }
        bind "l" { MoveFocus "right"; SwitchToMode "normal"; }
        bind "n" { GoToNextTab; SwitchToMode "normal"; }
        bind "o" { FocusNextPane; }
        bind "p" { GoToPreviousTab; SwitchToMode "normal"; }
        bind "z" { ToggleFocusFullscreen; SwitchToMode "normal"; }
    }
}

// Plugin aliases - can be used to change the implementation of Zellij
// changing these requires a restart to take effect
plugins {
    about location="zellij:about"
    compact-bar location="zellij:compact-bar"
    configuration location="zellij:configuration"
    filepicker location="zellij:strider" {
        cwd "/"
    }
    plugin-manager location="zellij:plugin-manager"
    session-manager location="zellij:session-manager"
    status-bar location="zellij:status-bar"
    strider location="zellij:strider"
    tab-bar location="zellij:tab-bar"
    welcome-screen location="zellij:session-manager" {
        welcome_screen true
    }
}

// Plugins to load in the background when a new session starts
// eg. "file:/path/to/my-plugin.wasm"
// eg. "https://example.com/my-plugin.wasm"
load_plugins {
    zellij:link
}
web_client {
    font "monospace"
}
 
// Use a simplified UI without special fonts (arrow glyphs)
// Options:
//   - true
//   - false (Default)
// 
// simplified_ui true
 
// Enable OSC8 hyperlink output
// Options:
//   - true (Default)
//   - false
// 
// osc8_hyperlinks true
 
// Choose the theme that is specified in the themes section.
// Default: default
// 
// theme "dracula"
 
// Theme to use when the host terminal reports a dark color palette.
// Requires `theme_light` to also be set; otherwise `theme` is used.
// 
// theme_dark "dracula"
 
// Theme to use when the host terminal reports a light color palette.
// Requires `theme_dark` to also be set; otherwise `theme` is used.
// 
// theme_light "solarized-light"
 
// Choose the base input mode of zellij.
// Default: normal
// 
// default_mode "locked"
 
// Choose the path to the default shell that zellij will use for opening new panes
// Default: $SHELL
// 
   default_shell "zsh"
 
// Choose the path to override cwd that zellij will use for opening new panes
// 
// default_cwd "/tmp"
 
// The name of the default layout to load on startup
// Default: "default"
// 
// default_layout "compact"
 
// The folder in which Zellij will look for layouts
// (Requires restart)
// 
// layout_dir "/tmp"
 
// The folder in which Zellij will look for themes
// (Requires restart)
// 
// theme_dir "/tmp"
 
// Toggle enabling the mouse mode.
// On certain configurations, or terminals this could
// potentially interfere with copying text.
// Options:
//   - true (default)
//   - false
// 
// mouse_mode false
 
// Toggle having pane frames around the panes
// Options:
//   - true (default, enabled)
//   - false
// 
// pane_frames false
 
// Set the pane frame style when pane_frames is enabled
// Options:
//   - full
//   - titles (default)
// 
// pane_frame_style "titles"
 
// When attaching to an existing session with other users,
// should the session be mirrored (true)
// or should each user have their own cursor (false)
// (Requires restart)
// Default: false
// 
// mirror_session true
 
// Choose what to do when zellij receives SIGTERM, SIGINT, SIGQUIT or SIGHUP
// eg. when terminal window with an active zellij session is closed
// (Requires restart)
// Options:
//   - detach (Default)
//   - quit
// 
// on_force_close "quit"
 
// Configure the scroll back buffer size
// This is the number of lines zellij stores for each pane in the scroll back
// buffer. Excess number of lines are discarded in a FIFO fashion.
// (Requires restart)
// Valid values: positive integers
// Default value: 10000
// 
// scroll_buffer_size 10000
 
// Provide a command to execute when copying text. The text will be piped to
// the stdin of the program to perform the copy. This can be used with
// terminal emulators which do not support the OSC 52 ANSI control sequence
// that will be used by default if this option is not set.
// Examples:
//
// copy_command "xclip -selection clipboard" // x11
// copy_command "wl-copy"                    // wayland
// copy_command "pbcopy"                     // osx
// 
// copy_command "pbcopy"
 
// Choose the destination for copied text
// Allows using the primary selection buffer (on x11/wayland) instead of the system clipboard.
// Does not apply when using copy_command.
// Options:
//   - system (default)
//   - primary
// 
// copy_clipboard "primary"
 
// Enable automatic copying (and clearing) of selection when releasing mouse
// Default: true
// 
// copy_on_select true
 
// Path to the default editor to use to edit pane scrollbuffer
// Default: $EDITOR or $VISUAL
// scrollback_editor "/usr/bin/vim"
 
// A fixed name to always give the Zellij session.
// Consider also setting `attach_to_session true,`
// otherwise this will error if such a session exists.
// Default: <RANDOM>
// 
// session_name "My singleton session"
 
// When `session_name` is provided, attaches to that session
// if it is already running or creates it otherwise.
// Default: false
// 
// attach_to_session true
 
// Toggle between having Zellij lay out panes according to a predefined set of layouts whenever possible
// Options:
//   - true (default)
//   - false
// 
// auto_layout false
 
// Whether sessions should be serialized to the cache folder (including their tabs/panes, cwds and running commands) so that they can later be resurrected
// Options:
//   - true (default)
//   - false
// 
// session_serialization false
 
// Whether pane viewports are serialized along with the session, default is false
// Options:
//   - true
//   - false (default)
// 
// serialize_pane_viewport false
 
// Scrollback lines to serialize along with the pane viewport when serializing sessions, 0
// defaults to the scrollback size. If this number is higher than the scrollback size, it will
// also default to the scrollback size. This does nothing if `serialize_pane_viewport` is not true.
// 
// scrollback_lines_to_serialize 10000
 
// Enable or disable the rendering of styled and colored underlines (undercurl).
// May need to be disabled for certain unsupported terminals
// (Requires restart)
// Default: true
// 
// styled_underlines false
 
// How often in seconds sessions are serialized
// 
// serialization_interval 10000
 
// Enable or disable writing of session metadata to disk (if disabled, other sessions might not know
// metadata info on this session)
// (Requires restart)
// Default: false
// 
// disable_session_metadata false
 
// Enable or disable support for the enhanced Kitty Keyboard Protocol (the host terminal must also support it)
// (Requires restart)
// Default: true (if the host terminal supports it)
// 
// support_kitty_keyboard_protocol false
 
// Enable or disable support for the Kitty Graphics Protocol, used to display images (the host terminal must also support it)
// (Requires restart)
// Default: true (if the host terminal supports it)
// 
// support_kitty_graphics_protocol false
// Whether to make sure a local web server is running when a new Zellij session starts.
// This web server will allow creating new sessions and attaching to existing ones that have
// opted in to being shared in the browser.
// When enabled, navigate to http://127.0.0.1:8082
// (Requires restart)
// 
// Note: a local web server can still be manually started from within a Zellij session or from the CLI.
// If this is not desired, one can use a version of Zellij compiled without
// `web_server_capability`
// 
// Possible values:
// - true
// - false
// Default: false
// 
// web_server false
// Whether to allow sessions started in the terminal to be shared through a local web server, assuming one is
// running (see the `web_server` option for more details).
// (Requires restart)
// 
// Note: This is an administrative separation and not intended as a security measure.
// 
// Possible values:
// - "on" (allow web sharing through the local web server if it
// is online)
// - "off" (do not allow web sharing unless sessions explicitly opt-in to it)
// - "disabled" (do not allow web sharing and do not permit sessions started in the terminal to opt-in to it)
// Default: "off"
// 
// web_sharing "off"
// A path to a certificate file to be used when setting up the web client to serve the
// connection over HTTPs
// 
// web_server_cert "/path/to/cert.pem"
// A path to a key file to be used when setting up the web client to serve the
// connection over HTTPs
// 
// web_server_key "/path/to/key.pem"
/// Whether to enforce https connections to the web server when it is bound to localhost
/// (127.0.0.0/8)
///
/// Note: https is ALWAYS enforced when bound to non-local interfaces
///
/// Default: false
// 
// enforce_https_for_localhost false
 
// Whether to stack panes when resizing beyond a certain size
// Default: true
// 
// stacked_resize false
 
// Whether stacked panes display as a list with the expanded pane pinned to the bottom
// Default: true
// 
// stacked_pane_list false
 
// Whether to show tips on startup
// Default: true
// 
show_startup_tips false
 
// Whether to show release notes on first version run
// Default: true
// 
// show_release_notes false
 
// Whether to enable mouse hover effects and pane grouping functionality
// default is true
// advanced_mouse_actions false
 
// Whether Ctrl+ScrollWheel resizes panes
// default is true
// mouse_scroll_resize false
 
// Whether to enable mouse hover visual effects (frame highlight and help text)
// default is true
// mouse_hover_effects false
 
// Whether to show mouse hover help-text tips (resize help and group shortcuts)
// default is true
// mouse_hover_tips false
 
// Whether to show visual bell indicators (pane/tab frame flash and [!] suffix)
// default is true
// visual_bell true
 
// Whether to focus panes on mouse hover
// default is false
// focus_follows_mouse false
 
// Whether clicking a pane to focus it also sends the click into the pane
// default is false
// mouse_click_through false
 
// Whether triple-clicking inside command output marked by the shell (OSC 133) selects
// the command and its output instead of the logical line
// default is true
// osc133_command_selection false
 
// Characters that terminate a word when double-clicking to select it
// whitespace is always a separator and need not be listed here
// default is "[]{}<>()"
// word_separators "[]{}<>()"
 
// The ip address the web server should listen on when it starts
// Default: "127.0.0.1"
// (Requires restart)
// web_server_ip "127.0.0.1"
 
// The port the web server should listen on when it starts
// Default: 8082
// (Requires restart)
// web_server_port 8082
 
// A command to run (will be wrapped with sh -c and provided the RESURRECT_COMMAND env variable) 
// after Zellij attempts to discover a command inside a pane when resurrecting sessions, the STDOUT
// of this command will be used instead of the discovered RESURRECT_COMMAND
// can be useful for removing wrappers around commands
// Note: be sure to escape backslashes and similar characters properly
// post_command_discovery_hook "echo $RESURRECT_COMMAND | sed <your_regex_here>"

// Number of async worker tasks to spawn per active client.
//
// Allocating few tasks may result in resource contention and lags. Small values (around 4) should
// typically work best. Set to 0 to use the number of (physical) CPU cores.
// Note: This only applies to web clients at the moment.
// client_async_worker_tasks 4
 
// Whether to let programs running inside panes read the paste buffer
// (clipboard) with the OSC 52 escape sequence. When enabled, any program
// in any pane - including one running on a remote machine over SSH - can
// read the clipboard without the user being asked.
// Default: false
// dangerously_enable_paste_buffer_read false
 
// How to handle a nested Zellij session detected inside a pane.
// Options:
//   - "ask" (Default — prompt with a modal)
//   - "fullscreen" (always zoom into the nested session)
//   - "descend" (always control the nested session on focus)
//   - "never" (never prompt or descend; do it manually)
// 
// nested_session_handling "ask"
 
// Which escape sequence desktop notifications coming from panes are
// forwarded to the host terminal with.
// Options:
//   - "auto" (Default — detect from the host terminal environment)
//   - "osc9" (the legacy iTerm2 protocol, understood by most terminals)
//   - "osc99" (kitty's notification protocol)
//   - "bell" (ring the terminal bell instead)
//   - "off" (do not forward notifications to the host terminal)
// 
// host_notification_protocol "auto"

```

---

# 55. Appendix B — Exact uploaded historical Power/QML variant A

The following is the complete uploaded Power/QML text from one historical/current development variant.

```qml
import Quickshell
import QtQuick
import Quickshell.Io
import "components"
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

PanelWindow {
    property bool menuOpen: false
    property bool confirmShutdown: false
    property bool confirmReboot: false
    property int clickCount: 0
    property int pressCount: 0
    property int selectedIndex: 0
    property int hoveredIndex: 0
    property bool keyboardActive: false
    Process {
        id: lockProcess
        command: ["swaylock"]
    }

    Process {
        id: logoutProcess
        command: ["swaymsg", "exit"]
    }

    Process {
        id: rebootProcess
        command: ["systemctl", "reboot"]
    }

    Process {
        id: shutdownProcess
        command: ["systemctl", "poweroff"]
    }

    anchors {
        top: false
        bottom: true
        right: true
        left: false
    }

    margins {
        top: 00
        bottom: 10
        right: 10
        left: 00
    }

    implicitWidth: 220
    implicitHeight: 290

    color: "transparent"
    focusable: true

    Item {
        id: powerArea

        width: 220
        height: 290

        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Rectangle {
            id: powerButton

            radius: width / 100
            width: 50
            height: 50
            z: 1

            x: 155
            y: 230

            color: powerMouse.pressed ? Colors.magenta
                 : powerMouse.containsMouse ? Colors.black
                 : Colors.black

            Text {
                anchors.centerIn: parent
                text: "⏻"
                font.pixelSize: 35

                color: powerMouse.pressed ? Colors.cyan
                     :powerMouse.containsMouse ? Colors.cyan
                     : Colors.white
            }

            MouseArea {
                id: powerMouse

                width: parent.width
                height: parent.height

                hoverEnabled: true

                onEntered: {
                    console.log("Mouse entered button")
                }

                onExited: {
                    console.log("Mouse left button")
                }

                onPressed: {
                    pressCount++
                }

                onClicked: {
                    clickCount++
                    menuOpen = !menuOpen

                    if (menuOpen) {
                        selectedIndex = 1
                        powerMenu.forceActiveFocus()
                    }

                    console.log("Menu open:", menuOpen)
                }
            }
        }

        DropShadow {
            source: powerButton
            anchors.centerIn: powerButton

            width: powerButton.width - 0
            height: powerButton.height - 0

            opacity: 0.3
            horizontalOffset: 0
            verticalOffset: 0
            radius: 19
            samples: 17
            z: 1

            color: Colors.cyan
            transparentBorder: true
        }

        RectangularShadow {
            anchors.fill: powerButton

            width: powerButton.width
            height: powerButton.height

            opacity: 0.5
            spread: 1
            z: -1

            color: Colors.cyan
        }
    }

    //Rectangle {
    //    width: powerButton.width + 10
    //    height: powerButton.height + 10
    //    radius: powerButton.radius + 5
    //    anchors.centerIn: powerButton
    //    color: Colors.cyan
    //    opacity: 0.15
    //    z: 0
    //
    //    Rectangle {
    //        width: parent.width + 10
    //        height: parent.height + 10
    //        radius: parent.radius + 5
    //        anchors.centerIn: parent
    //        color: Colors.cyan
    //        opacity: 0.10
    //        z: -1
    //
    //        Rectangle {
    //            width: parent.width + 10
    //            height: parent.height + 10
    //            radius: parent.radius + 5
    //            anchors.centerIn: parent
    //            color: Colors.cyan
    //            opacity: 0.06
    //            z: -2
    //        }
    //    }
    //}

    Rectangle {
        id: powerMenu

        width: 150
        height: 200
        z: 1
        color: Colors.black

        x: 35
        y: 20

        visible: menuOpen
        focus: menuOpen

        Keys.onPressed: function(event) {
            if (!menuOpen)
                return

            if (event.key === Qt.Key_Escape) {
                menuOpen = false
                event.accepted = true
            }
            else if (event.key === Qt.Key_Up) {
                keyboardActive = true

                selectedIndex--

                if (selectedIndex < 1)
                    selectedIndex = 4

                event.accepted = true
            }
            else if (event.key === Qt.Key_Down) {
                keyboardActive = true

                selectedIndex++

                if (selectedIndex > 4)
                    selectedIndex = 1

                event.accepted = true
            }
            else if (event.key === Qt.Key_Return ||
                     event.key === Qt.Key_Enter) {

                if (selectedIndex === 1) {
                    menuOpen = false
                    lockProcess.running = true
                }
                else if (selectedIndex === 2) {
                    menuOpen = false
                    logoutProcess.running = true
                }
                else if (selectedIndex === 3) {
                    menuOpen = false
                    confirmReboot = true
                }
                else if (selectedIndex === 4) {
                    menuOpen = false
                    confirmShutdown = true
                }
            }
        }

        // NORMAL POWER MENU
        Column {
            id: menuItems

            width: parent.width

            visible: !confirmShutdown && !confirmReboot

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 15

            spacing: 7

            Text {
                text: "POWER MENU"

                color: Colors.cyan
                font.pixelSize: 20

                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: parent.width - 20
                height: 2

                color: Colors.cyan

                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                id: lockButton

                width: parent.width
                height: 30

                color: lockMouse.pressed ? Colors.magenta
                     : !keyboardActive && lockMouse.containsMouse ? Colors.yellow
                     : selectedIndex === 1 ? Colors.yellow
                     : Colors.black

                Text {
                    text: "Lock"
                    anchors.centerIn: parent

                    color: lockMouse.pressed ? Colors.black
                         : !keyboardActive && lockMouse.containsMouse ? Colors.orange
                         : selectedIndex === 1 ? Colors.orange
                         : Colors.cyan

                    font.pixelSize: 20
                }

                MouseArea {
                    id: lockMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: { 
                            selectedIndex = 1
                    }

                    onClicked: {
                        console.log("Lock clicked!")
                        menuOpen = false
                        lockProcess.running = true
                    }
                }

                DropShadow {
                    source: lockButton
                    anchors.fill: lockButton

                    color: lockMouse.pressed ? Colors.magenta
                         : !keyboardActive && lockMouse.containsMouse ? Colors.orange
                         : selectedIndex === 1 ? Colors.orange
                         : Colors.cyan

                    opacity: lockMouse.pressed ? 0.55
                           : lockMouse.containsMouse ? 0.55
                           : selectedIndex === 1 ? 0.55
                           : 0

                    horizontalOffset: 0
                    verticalOffset: 0
                    radius: 12
                    samples: 25

                    z: -1
                    transparentBorder: true
                }
            }

            Rectangle {
                id: logoutButton

                width: parent.width
                height: 30

                color: logoutMouse.pressed ? Colors.magenta
                     : !keyboardActive && logoutMouse.containsMouse ? Colors.yellow
                     : selectedIndex === 2 ? Colors.yellow
                     : Colors.black

                Text {
                    text: "Logout"
                    anchors.centerIn: parent

                    color: logoutMouse.pressed ? Colors.black
                         : !keyboardActive && logoutMouse.containsMouse ? Colors.orange
                         : selectedIndex === 2 ? Colors.orange
                         : Colors.cyan

                    font.pixelSize: 20
                }

                MouseArea {
                    id: logoutMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Logout clicked!")
                        logoutProcess.running = true
                    }
                    onEntered: {
                       selectedIndex = 2
                    }
                }

                DropShadow {
                    source: logoutButton
                    anchors.fill: logoutButton

                    color: logoutMouse.pressed ? Colors.magenta
                         : selectedIndex === 2 ? Colors.orange
                         : !keyboardActive && logoutMouse.containsMouse ? Colors.orange
                         : Colors.cyan

                    opacity: logoutMouse.pressed ? 0.55
                           : selectedIndex === 2 ? 0.55
                           : logoutMouse.containsMouse ? 0.55
                           : 0

                    horizontalOffset: 0
                    verticalOffset: 0
                    radius: 12
                    samples: 25

                    z: -1
                    transparentBorder: true
                }
            }

            Rectangle {
                id: rebootButton

                width: parent.width
                height: 30

                color: rebootMouse.pressed ? Colors.red
                     : selectedIndex === 3 ? Colors.yellow
                     : !keyboardActive && rebootMouse.containsMouse ? Colors.yellow
                     : Colors.black

                Text {
                    text: "Reboot"
                    anchors.centerIn: parent

                    color: rebootMouse.pressed ? Colors.black
                         : selectedIndex === 3 ? Colors.orange
                         : !keyboardActive && rebootMouse.containsMouse ? Colors.orange
                         : Colors.cyan

                    font.pixelSize: 20
                }

                MouseArea {
                    id: rebootMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Reboot clicked!")
                        confirmReboot = true
                    }
                    onEntered: {
                        selectedIndex = 3
                    }
                }

                DropShadow {
                    source: rebootButton
                    anchors.fill: rebootButton

                    color: rebootMouse.pressed ? Colors.red
                         : selectedIndex === 3 ? Colors.orange
                         : !keyboardActive && rebootMouse.containsMouse ? Colors.orange
                         : Colors.cyan

                    opacity: rebootMouse.pressed ? 0.55
                           : selectedIndex === 3 ? 0.55
                           : rebootMouse.containsMouse ? 0.55
                           : 0

                    horizontalOffset: 0
                    verticalOffset: 0
                    radius: 12
                    samples: 25

                    z: -1
                    transparentBorder: true
                }
            }

            Rectangle {
                id: shutdownButton

                width: parent.width
                height: 30

                color: shutdownMouse.pressed ? Colors.red
                     : selectedIndex === 4 ? Colors.yellow
                     : !keyboardActive && shutdownMouse.containsMouse ? Colors.yellow
                     : Colors.black

                Text {
                    text: "Shutdown"
                    anchors.centerIn: parent

                    color: shutdownMouse.pressed ? Colors.black
                         : selectedIndex === 4 ? Colors.orange
                         : !keyboardActive && shutdownMouse.containsMouse ? Colors.orange
                         : Colors.cyan

                    font.pixelSize: 20
                }

                MouseArea {
                    id: shutdownMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Shutdown clicked!")
                        confirmShutdown = true
                    }
                    onEntered: {
                        selectedIndex = 4
                     }
                }

                DropShadow {
                    source: shutdownButton
                    anchors.fill: shutdownButton

                    color: shutdownMouse.pressed ? Colors.red
                         : selectedIndex === 4 ? Colors.orange
                         : !keyboardActive && shutdownMouse.containsMouse ? Colors.orange
                         : Colors.cyan

                    opacity: shutdownMouse.pressed ? 0.55
                           : selectedIndex === 4 ? 0.55
                           : shutdownMouse.containsMouse ? 0.55
                           : 0

                    horizontalOffset: 0
                    verticalOffset: 0
                    radius: 12
                    samples: 25

                    z: -1
                    transparentBorder: true
                }
            }
        }

        DropShadow {
            id: powerMenuGlow

            source: powerMenu

            anchors.fill: powerMenu

            width: powerMenu.width - 0
            height: powerMenu.height - 0

            horizontalOffset: 0
            verticalOffset: 0
            radius: 15
            samples: 41
            z: -1

            color: Colors.cyan
            visible: menuOpen
            opacity: menuOpen ? 0.5 : 0
            transparentBorder: true
        }

        RectangularShadow {
            anchors.centerIn: powerMenu

            width: powerMenu.width - 0
            height: powerMenu.height - 0

            spread: 3
            z: -3

            visible: menuOpen
            opacity: menuOpen ? 0.7 : 0

            color: Colors.cyan
        }
    }

    // SHUTDOWN CONFIRMATION SCREEN
    Column {
        id: shutdownConfirm

        width: parent.width

        visible: confirmShutdown

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 25

        spacing: 20

        Text {
            text: "SHUTDOWN?"
            color: Colors.red
            font.pixelSize: 22

            anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            id: cancelshutdownButton

            width: parent.width
            height: 30

            color: cancelshutdownMouse.pressed ? Colors.magenta
                 : selectedIndex === 4 ? Colors.yellow
                 : !keyboardActive && cancelshutdownMouse.containsMouse ? Colors.yellow
                 : Colors.black

            Text {
                text: "Cancel"

                color: cancelshutdownMouse.pressed ? Colors.black
                     : selectedIndex === 4 ? Colors.orange
                     : !keyboardActive && cancelshutdownMouse.containsMouse ? Colors.orange
                     : Colors.cyan

                font.pixelSize: 22

                anchors.centerIn: parent

                MouseArea {
                    id: cancelshutdownMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Shutdown cancelled!")
                        confirmShutdown = false
                    }
                }
            }

            DropShadow {
                source: cancelshutdownButton
                anchors.fill: cancelshutdownButton

                color: cancelshutdownMouse.pressed ? Colors.magenta
                     : selectedIndex === 4 ? Colors.orange
                     : !keyboardActive && cancelshutdownMouse.containsMouse ? Colors.orange
                     : Colors.cyan

                opacity: cancelshutdownMouse.pressed ? 0.55
                       : selectedIndex === 4 ? 0.55
                       : !keyboardActive && cancelshutdownMouse.containsMouse ? 0.55
                       : 0

                horizontalOffset: 0
                verticalOffset: 0
                radius: 12
                samples: 25

                z: -1
                transparentBorder: true
            }
        }

        Rectangle {
            id: confirmshutdownButton

            width: parent.width
            height: 30

            color: confirmshutdownMouse.pressed ? Colors.red
                 : selectedIndex === 4 ? Colors.yellow
                 : !keyboardActive && confirmshutdownMouse.containsMouse ? Colors.yellow
                 : Colors.black

            Text {
                text: "CONFIRM!"

                color: confirmshutdownMouse.pressed ? Colors.black
                     : selectedIndex === 4 ? Colors.orange
                     : !keyboardActive && confirmshutdownMouse.containsMouse ? Colors.orange
                     : Colors.cyan

                font.pixelSize: 20

                anchors.centerIn: parent

                MouseArea {
                    id: confirmshutdownMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Shutdown confirmed!")
                        shutdownProcess.running = true
                    }
                }
            }

            DropShadow {
                source: confirmshutdownButton
                anchors.fill: confirmshutdownButton

                color: confirmshutdownMouse.pressed ? Colors.red
                     : selectedIndex === 4 ? Colors.orange
                     : !keyboardActive && confirmshutdownMouse.containsMouse ? Colors.orange
                     : Colors.cyan

                opacity: confirmshutdownMouse.pressed ? 0.55
                       : selectedIndex === 4 ? Colors.orange
                       : !keyboardActive && confirmshutdownMouse.containsMouse ? Colors.orange
                       : 0

                horizontalOffset: 0
                verticalOffset: 0
                radius: 12
                samples: 25

                z: -1
                transparentBorder: true
            }
        }
    }

    // REBOOT CONFIRMATION SCREEN
    Column {
        id: rebootConfirm

        width: parent.width

        visible: confirmReboot

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: 25

        spacing: 20

        Text {
            text: "REBOOT?"
            color: Colors.red
            font.pixelSize: 22

            anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            id: cancelrebootButton

            width: parent.width
            height: 30

            color: cancelrebootMouse.pressed ? Colors.magenta
                 : !keyboardActive && cancelrebootMouse.containsMouse ? Colors.yellow
                 : Colors.black

            Text {
                text: "Cancel"

                color: cancelrebootMouse.pressed ? Colors.black
                     : !keyboardActive && cancelrebootMouse.containsMouse ? Colors.orange
                     : Colors.cyan

                font.pixelSize: 22

                anchors.centerIn: parent

                MouseArea {
                    id: cancelrebootMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Reboot cancelled!")
                        confirmReboot = false
                    }
                }
            }

            DropShadow {
                source: cancelrebootButton
                anchors.fill: cancelrebootButton

                color: cancelrebootMouse.pressed ? Colors.magenta
                     : !keyboardActive && cancelrebootMouse.containsMouse ? Colors.orange
                     : Colors.cyan

                opacity: cancelrebootMouse.pressed ? 0.55
                       : !keyboardActive && cancelrebootMouse.containsMouse ? 0.55
                       : 0

                horizontalOffset: 0
                verticalOffset: 0
                radius: 12
                samples: 25

                z: -1
                transparentBorder: true
            }
        }

        Rectangle {
            id: confirmrebootButton

            width: parent.width
            height: 30

            color: confirmrebootMouse.pressed ? Colors.red
                 : !keyboardActive && confirmrebootMouse.containsMouse ? Colors.yellow
                 : Colors.black

            Text {
                text: "CONFIRM!"

                color: confirmrebootMouse.pressed ? Colors.black
                     : !keyboardActive && confirmrebootMouse.containsMouse ? Colors.orange
                     : Colors.cyan

                font.pixelSize: 20

                anchors.centerIn: parent

                MouseArea {
                    id: confirmrebootMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Reboot confirmed!")
                        rebootProcess.running = true
                    }
                }
            }

            DropShadow {
                source: confirmrebootButton
                anchors.fill: confirmrebootButton

                color: confirmrebootMouse.pressed ? Colors.red
                     : !keyboardActive && confirmrebootMouse.containsMouse ? Colors.orange
                     : Colors.cyan

                opacity: confirmrebootMouse.pressed ? 0.55
                       : !keyboardActive && confirmrebootMouse.containsMouse ? Colors.orange
                       : 0

                horizontalOffset: 0
                verticalOffset: 0
                radius: 12
                samples: 25

                z: -1
                transparentBorder: true
            }
        }
    }
}

```

---

# 56. Appendix C — Exact uploaded historical Power/QML variant B

The following is the complete uploaded Power/QML text from the second development variant.

```qml
import Quickshell
import QtQuick
import Quickshell.Io
import "components"
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

PanelWindow {
    property bool menuOpen: false
    property bool confirmShutdown: false
    property bool confirmReboot: false
    property int clickCount: 0
    property int pressCount: 0
    property int selectedIndex: 0
    property int hoveredIndex: 0
    property bool keyboardActive: false
    Process {
        id: lockProcess
        command: ["swaylock"]
    }

    Process {
        id: logoutProcess
        command: ["swaymsg", "exit"]
    }

    Process {
        id: rebootProcess
        command: ["systemctl", "reboot"]
    }

    Process {
        id: shutdownProcess
        command: ["systemctl", "poweroff"]
    }

    anchors {
        top: false
        bottom: true
        right: true
        left: false
    }

    margins {
        top: 00
        bottom: 10
        right: 10
        left: 00
    }

    implicitWidth: 220
    implicitHeight: 290

    color: "transparent"
    focusable: true

    Item {
        id: powerArea

        width: 220
        height: 290

        anchors.right: parent.right
        anchors.bottom: parent.bottom

        Rectangle {
            id: powerButton

            radius: width / 100
            width: 50
            height: 50
            z: 1

            x: 155
            y: 230

            color: powerMouse.pressed ? Colors.black
                 : powerMouse.containsMouse ? Colors.black
                 : Colors.black

            Text {
                anchors.centerIn: parent
                text: "⏻"
                font.pixelSize: 35

                color: powerMouse.pressed ? Colors.orange
                     : powerMouse.containsMouse ? Colors.orange
                     : Colors.white
            }

            MouseArea {
                id: powerMouse

                width: parent.width
                height: parent.height

                hoverEnabled: true

                onEntered: {
                    console.log("Mouse entered button")
                }

                onExited: {
                    console.log("Mouse left button")
                }

                onPressed: {
                    pressCount++
                }

                onClicked: {
                    clickCount++
                    menuOpen = !menuOpen
                    confirmShutdown = false
                    confirmReboot = false
                    if (menuOpen) {
                        selectedIndex = 1
                        powerMenu.forceActiveFocus()
                    }

                    console.log("Menu open:", menuOpen)
                }
            }
        }

        DropShadow {
            source: powerButton
            anchors.centerIn: powerButton

            width: powerButton.width - 0
            height: powerButton.height - 0

            horizontalOffset: 0
            verticalOffset: 0
            radius: 19
            samples: 17
            z: 1

            opacity: powerMouse.pressed ? 0.7
                   : powerMouse.containsMouse ? 0.5
                   : 0.3

            color: powerMouse.pressed ? Colors.orange
                 :powerMouse.containsMouse ? Colors.orange
                 :Colors.cyan
            transparentBorder: true
        }

        RectangularShadow {
            anchors.fill: powerButton

            width: powerButton.width
            height: powerButton.height

            spread: 1
            z: -1

            opacity: powerMouse.pressed ? 0.9
                   : powerMouse.containsMouse ? 0.7
                   : 0.5

            color: powerMouse.pressed ? Colors.orange
                 : powerMouse.containsMouse ? Colors.orange
                 : Colors.cyan
        }
    }

    //Rectangle {
    //    width: powerButton.width + 10
    //    height: powerButton.height + 10
    //    radius: powerButton.radius + 5
    //    anchors.centerIn: powerButton
    //    color: Colors.cyan
    //    opacity: 0.15
    //    z: 0
    //
    //    Rectangle {
    //        width: parent.width + 10
    //        height: parent.height + 10
    //        radius: parent.radius + 5
    //        anchors.centerIn: parent
    //        color: Colors.cyan
    //        opacity: 0.10
    //        z: -1
    //
    //        Rectangle {
    //            width: parent.width + 10
    //            height: parent.height + 10
    //            radius: parent.radius + 5
    //            anchors.centerIn: parent
    //            color: Colors.cyan
    //            opacity: 0.06
    //            z: -2
    //        }
    //    }
    //}

    Rectangle {
        id: powerMenu

        width: 150
        height: 200
        z: 1
        color: Colors.black

        x: 35
        y: 20

        visible: menuOpen || confirmShutdown || confirmReboot
        focus:   menuOpen || confirmShutdown || confirmReboot

        Keys.onPressed: function(event) {
            if (!menuOpen)
                return

            if (event.key === Qt.Key_Escape) {
                menuOpen = false
                event.accepted = true
            }
            else if (event.key === Qt.Key_Up) {
                keyboardActive = true

                selectedIndex--

                if (selectedIndex < 1)
                    selectedIndex = 4

                event.accepted = true
            }
            else if (event.key === Qt.Key_Down) {
                keyboardActive = true

                selectedIndex++

                if (selectedIndex > 4)
                    selectedIndex = 1

                event.accepted = true
            }
            else if (event.key === Qt.Key_Return ||
                     event.key === Qt.Key_Enter) {

                if (selectedIndex === 1) {
                    menuOpen = false
                    lockProcess.running = true
                }
                else if (selectedIndex === 2) {
                    menuOpen = false
                    logoutProcess.running = true
                }
                else if (selectedIndex === 3) {
                    confirmReboot = true
                }
                else if (selectedIndex === 4) {
                    confirmShutdown = true
                }
            }
        }

        // NORMAL POWER MENU
        Column {
            id: menuItems

            width: parent.width

            visible: !confirmShutdown && !confirmReboot

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 15

            spacing: 7

            Text {
                text: "POWER MENU"

                color: Colors.cyan
                font.pixelSize: 20

                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: parent.width - 20
                height: 2

                color: Colors.cyan

                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                id: lockButton

                width: parent.width
                height: 30

                color: lockMouse.pressed ? Colors.magenta
                     : !keyboardActive && lockMouse.containsMouse ? Colors.yellow
                     : selectedIndex === 1 ? Colors.yellow
                     : Colors.black

                Text {
                    text: "Lock"
                    anchors.centerIn: parent

                    color: lockMouse.pressed ? Colors.black
                         : !keyboardActive && lockMouse.containsMouse ? Colors.orange
                         : selectedIndex === 1 ? Colors.orange
                         : Colors.cyan

                    font.pixelSize: 20
                }

                MouseArea {
                    id: lockMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    onEntered: {
                        selectedIndex = 1
                    }

                    onClicked: {
                        console.log("Lock clicked!")
                        menuOpen = false
                        lockProcess.running = true
                    }
                }

                DropShadow {
                    source: lockButton
                    anchors.fill: lockButton

                    color: lockMouse.pressed ? Colors.magenta
                         : !keyboardActive && lockMouse.containsMouse ? Colors.orange
                         : selectedIndex === 1 ? Colors.orange
                         : Colors.cyan

                    opacity: lockMouse.pressed ? 0.55
                           : lockMouse.containsMouse ? 0.55
                           : selectedIndex === 1 ? 0.55
                           : 0

                    horizontalOffset: 0
                    verticalOffset: 0
                    radius: 12
                    samples: 25

                    z: -1
                    transparentBorder: true
                }
            }

            Rectangle {
                id: logoutButton

                width: parent.width
                height: 30

                color: logoutMouse.pressed ? Colors.magenta
                     : !keyboardActive && logoutMouse.containsMouse ? Colors.yellow
                     : selectedIndex === 2 ? Colors.yellow
                     : Colors.black

                Text {
                    text: "Logout"
                    anchors.centerIn: parent

                    color: logoutMouse.pressed ? Colors.black
                         : !keyboardActive && logoutMouse.containsMouse ? Colors.orange
                         : selectedIndex === 2 ? Colors.orange
                         : Colors.cyan

                    font.pixelSize: 20
                }

                MouseArea {
                    id: logoutMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Logout clicked!")
                        logoutProcess.running = true
                    }

                    onEntered: {
                        selectedIndex = 2
                    }
                }

                DropShadow {
                    source: logoutButton
                    anchors.fill: logoutButton

                    color: logoutMouse.pressed ? Colors.magenta
                         : selectedIndex === 2 ? Colors.orange
                         : !keyboardActive && logoutMouse.containsMouse ? Colors.orange
                         : Colors.cyan

                    opacity: logoutMouse.pressed ? 0.55
                           : selectedIndex === 2 ? 0.55
                           : logoutMouse.containsMouse ? 0.55
                           : 0

                    horizontalOffset: 0
                    verticalOffset: 0
                    radius: 12
                    samples: 25

                    z: -1
                    transparentBorder: true
                }
            }

            Rectangle {
                id: rebootButton

                width: parent.width
                height: 30

                color: rebootMouse.pressed ? Colors.red
                     : selectedIndex === 3 ? Colors.yellow
                     : !keyboardActive && rebootMouse.containsMouse ? Colors.yellow
                     : Colors.black

                Text {
                    text: "Reboot"
                    anchors.centerIn: parent

                    color: rebootMouse.pressed ? Colors.black
                         : selectedIndex === 3 ? Colors.orange
                         : !keyboardActive && rebootMouse.containsMouse ? Colors.orange
                         : Colors.cyan

                    font.pixelSize: 20
                }

                MouseArea {
                    id: rebootMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Reboot clicked!")
                        confirmReboot = true
                    }

                    onEntered: {
                        selectedIndex = 3
                    }
                }

                DropShadow {
                    source: rebootButton
                    anchors.fill: rebootButton

                    color: rebootMouse.pressed ? Colors.red
                         : selectedIndex === 3 ? Colors.orange
                         : !keyboardActive && rebootMouse.containsMouse ? Colors.orange
                         : Colors.cyan

                    opacity: rebootMouse.pressed ? 0.55
                           : selectedIndex === 3 ? 0.55
                           : rebootMouse.containsMouse ? 0.55
                           : 0

                    horizontalOffset: 0
                    verticalOffset: 0
                    radius: 12
                    samples: 25

                    z: -1
                    transparentBorder: true
                }
            }

            Rectangle {
                id: shutdownButton

                width: parent.width
                height: 30

                color: shutdownMouse.pressed ? Colors.red
                     : selectedIndex === 4 ? Colors.yellow
                     : shutdownMouse.containsMouse ? Colors.yellow
                     : Colors.black

                Text {
                    text: "Shutdown"
                    anchors.centerIn: parent

                    color: shutdownMouse.pressed ? Colors.black
                         : selectedIndex === 4 ? Colors.orange
                         : shutdownMouse.containsMouse ? Colors.orange
                         : Colors.cyan

                    font.pixelSize: 20
                }

                MouseArea {
                    id: shutdownMouse

                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Shutdown clicked!")
                        confirmShutdown = true
                    }

                    onEntered: {
                        selectedIndex = 4
                    }
                }

                DropShadow {
                    source: shutdownButton
                    anchors.fill: shutdownButton

                    color: shutdownMouse.pressed ? Colors.red
                         : selectedIndex === 4 ? Colors.orange
                         : !keyboardActive && shutdownMouse.containsMouse ? Colors.orange
                         : Colors.cyan

                    opacity: shutdownMouse.pressed ? 0.55
                           : selectedIndex === 4 ? 0.55
                           : shutdownMouse.containsMouse ? 0.55
                           : 0

                    horizontalOffset: 0
                    verticalOffset: 0
                    radius: 12
                    samples: 25

                    z: -1
                    transparentBorder: true
                }
            }
        }

        DropShadow {
            id: powerMenuGlow

            source: powerMenu

            anchors.fill: powerMenu

            width: powerMenu.width - 0
            height: powerMenu.height - 0

            horizontalOffset: 0
            verticalOffset: 0
            radius: 15
            samples: 41
            z: -1

            color: Colors.cyan
            visible: menuOpen
            opacity: menuOpen ? 0.5 : 0
            transparentBorder: true
        }

        RectangularShadow {
            anchors.centerIn: powerMenu

            width: powerMenu.width - 0
            height: powerMenu.height - 0

            spread: 3
            z: -3

            visible: menuOpen
            opacity: menuOpen ? 0.7 : 0

            color: Colors.cyan
        }
    }

    // SHUTDOWN CONFIRMATION SCREEN
    Column {
        id: shutdownConfirm

        width: powerMenu.width
        height: powerMenu.height
        x: powerMenu.x
        y: powerMenu.y

        z: 10

        visible: confirmShutdown

       // anchors.horizontalCenter: parent.horizontalCenter
       // anchors.top: parent.top
       // anchors.topMargin: 25

        spacing: 20

        Text {
            text: "SHUTDOWN?"
            color: Colors.red
            font.pixelSize: 22

            anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            id: cancelshutdownButton

            width: parent.width
            height: 30

            color: cancelshutdownMouse.pressed ? Colors.magenta
                 : !keyboardActive && cancelshutdownMouse.containsMouse ? Colors.yellow
                 : Colors.black

            Text {
                text: "Cancel"

                color: cancelshutdownMouse.pressed ? Colors.black
                     : !keyboardActive && cancelshutdownMouse.containsMouse ? Colors.orange
                     : Colors.cyan

                font.pixelSize: 22
                anchors.centerIn: parent
            }

            MouseArea {
                id: cancelshutdownMouse

                anchors.fill: parent
                hoverEnabled: true

                onClicked: {
                    console.log("Shutdown cancelled!")
                    confirmShutdown = false
                }
            }

            DropShadow {
                source: cancelshutdownButton
                anchors.fill: cancelshutdownButton

                color: cancelshutdownMouse.pressed ? Colors.magenta
                     : !keyboardActive && cancelshutdownMouse.containsMouse ? Colors.orange
                     : Colors.cyan

                opacity: cancelshutdownMouse.pressed ? 0.55
                       : !keyboardActive && cancelshutdownMouse.containsMouse ? 0.55
                       : 0

                horizontalOffset: 0
                verticalOffset: 0
                radius: 12
                samples: 25

                z: -1
                transparentBorder: true
            }
        }

        Rectangle {
            id: confirmshutdownButton

            width: parent.width
            height: 30

            color: confirmshutdownMouse.pressed ? Colors.red
                 : !keyboardActive && confirmshutdownMouse.containsMouse ? Colors.yellow
                 : Colors.black

            Text {
                text: "CONFIRM!"

                color: confirmshutdownMouse.pressed ? Colors.black
                     : !keyboardActive && confirmshutdownMouse.containsMouse ? Colors.orange
                     : Colors.cyan

                font.pixelSize: 20
                anchors.centerIn: parent
            }

            MouseArea {
                id: confirmshutdownMouse

                anchors.fill: parent
                hoverEnabled: true

                onClicked: {
                    console.log("Shutdown confirmed!")
                    shutdownProcess.running = true
                }
            }

            DropShadow {
                source: confirmshutdownButton
                anchors.fill: confirmshutdownButton

                color: confirmshutdownMouse.pressed ? Colors.red
                     : !keyboardActive && confirmshutdownMouse.containsMouse ? Colors.orange
                     : Colors.cyan

                opacity: confirmshutdownMouse.pressed ? 0.55
                       : !keyboardActive && confirmshutdownMouse.containsMouse ? 0.55
                       : 0

                horizontalOffset: 0
                verticalOffset: 0
                radius: 12
                samples: 25

                z: -1
                transparentBorder: true
            }
        }
    }

    // REBOOT CONFIRMATION SCREEN
    Column {
        id: rebootConfirm

        width: powerMenu.width
        height: powerMenu.height
        x: powerMenu.x
        y: powerMenu.y

        z: 10

        visible: confirmReboot

     //   anchors.horizontalCenter: parent.horizontalCenter
     //   anchors.top: parent.top
     //   anchors.topMargin: 25

        spacing: 20

        Text {
            text: "REBOOT?"
            color: Colors.red
            font.pixelSize: 22

            anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
            id: cancelrebootButton

            width: parent.width
            height: 30

            color: cancelrebootMouse.pressed ? Colors.magenta
                 : !keyboardActive && cancelrebootMouse.containsMouse ? Colors.yellow
                 : Colors.black

            Text {
                text: "Cancel"

                color: cancelrebootMouse.pressed ? Colors.black
                     : !keyboardActive && cancelrebootMouse.containsMouse ? Colors.orange
                     : Colors.cyan

                font.pixelSize: 22

                anchors.centerIn: parent
            }

            MouseArea {
                id: cancelrebootMouse

                anchors.fill: parent
                hoverEnabled: true

                onClicked: {
                    console.log("Reboot cancelled!")
                    confirmReboot = false
                }
            }

            DropShadow {
                source: cancelrebootButton
                anchors.fill: cancelrebootButton

                color: cancelrebootMouse.pressed ? Colors.magenta
                     : !keyboardActive && cancelrebootMouse.containsMouse ? Colors.orange
                     : Colors.cyan

                opacity: cancelrebootMouse.pressed ? 0.55
                       : !keyboardActive && cancelrebootMouse.containsMouse ? 0.55
                       : 0

                horizontalOffset: 0
                verticalOffset: 0
                radius: 12
                samples: 25

                z: -1
                transparentBorder: true
            }
        }

        Rectangle {
            id: confirmrebootButton

            width: parent.width
            height: 30

            color: confirmrebootMouse.pressed ? Colors.red
                 : !keyboardActive && confirmrebootMouse.containsMouse ? Colors.yellow
                 : Colors.black

            Text {
                text: "CONFIRM!"

                color: confirmrebootMouse.pressed ? Colors.black
                     : !keyboardActive && confirmrebootMouse.containsMouse ? Colors.orange
                     : Colors.cyan

                font.pixelSize: 20

                anchors.centerIn: parent
            }

            MouseArea {
                id: confirmrebootMouse

                anchors.fill: parent
                hoverEnabled: true

                onClicked: {
                    console.log("Reboot confirmed!")
                    rebootProcess.running = true
                }
            }

            DropShadow {
                source: confirmrebootButton
                anchors.fill: confirmrebootButton

                color: confirmrebootMouse.pressed ? Colors.red
                     : !keyboardActive && confirmrebootMouse.containsMouse ? Colors.orange
                     : Colors.cyan

                opacity: confirmrebootMouse.pressed ? 0.55
                       : !keyboardActive && confirmrebootMouse.containsMouse ? 0.3
                       : 0

                horizontalOffset: 0
                verticalOffset: 0
                radius: 12
                samples: 25

                z: -1
                transparentBorder: true
            }
        }
    }
}

```

---

# 57. Final notes

This dossier should be treated as a living reference.

When future QML/config chunks are added, the useful pattern is to classify each new observation as one of:

```text
LEGACY
ESTABLISHED STANDARD
CURRENT IMPLEMENTATION
EXPERIMENTAL / DEBUG
FUTURE / INTENDED
```

New values should only be elevated into “established standard” when they genuinely recur or are explicitly declared as a project convention.

The project already has enough recurring language that future modules should increasingly be evaluated by how well they fit the existing system rather than by whether they introduce more visual novelty.

The strongest established identity is:

```text
deep purple
+
cyan information
+
orange activity
+
pale syntax
+
red urgency
+
gold selection
+
magenta special state
+
green available for broader use
+
Gohu Nerd Font
+
Unicode symbols
+
Christian/celestial motifs
+
retro terminal/CRT language
+
sparse HUD
+
glow
+
keyboard-first interaction
+
live system state
+
Quickshell as unified graphical shell
```

That is the current design and architectural foundation of the rice.
