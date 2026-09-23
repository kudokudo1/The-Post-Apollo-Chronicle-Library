# Neon CRT Desktop Project — Master Plan, Inventory, and Architecture

> Living reference document for the project as of **2026-09-17**.
>
> Purpose: preserve the current system inventory, project philosophy, architecture decisions, compatibility strategy, public-release plan, known dependencies, legacy pieces, experimental pieces, and next steps so the project can continue cleanly even if chat context is lost.

---

# 1. Project Goal

The long-term goal is to turn the current heavily customized Fedora/Sway desktop into a **single installable, modular desktop project** that other people can download, learn from, modify, and rearrange.

The project should feel less like a locked theme or prebuilt appliance and more like:

- a **recipe book**
- a **LEGO kit**
- a reference desktop people can study
- a collection of interchangeable building blocks
- a system that encourages users to understand how their desktop is assembled

The project should provide a clear **reference build**, but users should be free to swap components as long as they understand the compatibility consequences.

Core philosophy:

> **It is your toy. Build it the way you want.**

The project should not make users feel that a different terminal, editor, file manager, or other component is "wrong." Instead, it should clearly explain:

- what the reference component is
- why it was chosen
- what features the project depends on
- whether alternatives are fully compatible, adapted, partial, or untested
- what may break if the user chooses a less capable or more restrictive alternative

---

# 2. Installation Philosophy

## One install

The project should have **one installation path**, not separate "minimal," "full," "developer," or "advanced" editions.

Desired user experience:

```bash
git clone <repo-url> ~/.config/<project-name>
cd ~/.config/<project-name>
./install.sh
```

The installer installs the full known-good environment.

If users never touch a feature, that is fine. The feature can simply remain unused.

Examples:

- AI tooling can be installed but ignored.
- Developer Toolbox can be installed but never entered.
- Weather features can remain unused.
- Discord/Session integration can remain unused.
- Extra terminal toys can remain unused.

The user should not have to understand installer variants before they can use the desktop.

## Internally modular, externally simple

The installer itself can be split into internal modules:

```text
installer/
├── host.sh
├── packages.sh
├── toolbox.sh
├── build-swayfx.sh
├── deploy-configs.sh
├── services.sh
└── ...
```

But the user should only need to run one entry point:

```bash
./install.sh
```

---

# 3. Dogfooding Rule

The project developer should use the **same layout and install path as public users**.

The Git repository should eventually live directly in the same centralized configuration directory users receive.

Example:

```text
~/.config/<project-name>/
```

The local machine should not use a special hidden developer layout while the public project uses something else.

Migration strategy:

```text
current live config
        ↓
move into repo
        ↓
normal application path becomes symlink
        ↓
test it
        ↓
commit it
        ↓
document capabilities and dependencies
```

This makes the developer experience and user experience match as closely as possible.

---

# 4. Central Configuration Philosophy

A major design rule is:

> **User-editable configuration should be centralized, readable, and discoverable.**

Users should not need to search through:

- `~/.config/sway`
- `~/.config/kitty`
- `~/.config/quickshell`
- random scripts
- `/etc`
- systemd units
- application-specific directories

just to figure out where to change something.

The project should have a **single obvious configuration root**.

Recommended base:

```text
~/.config/<project-name>/
```

Applications may still require conventional paths, but those paths can point back into the central project tree using symlinks.

Example:

```text
~/.config/sway
    → ~/.config/<project-name>/components/compositor/sway

~/.config/kitty
    → ~/.config/<project-name>/components/terminal-emulator/kitty

~/.config/quickshell
    → ~/.config/<project-name>/components/desktop-shell/quickshell
```

The project copy should be the **single source of truth**.

Avoid:

```text
project config
     ≠
live config
```

Prefer:

```text
project config
     =
live config
```

---

# 5. Human-Readable Architecture

An earlier layout mixed software names and conceptual categories, for example:

```text
sway/
quickshell/
terminal/
apps/
themes/
```

That was inconsistent because:

- `sway` is an implementation
- `quickshell` is an implementation
- `terminal` is a role/category
- `apps` is a broad category
- `themes` is a concept

The architecture should use a consistent mental model.

## Two-layer model

The chosen direction is:

```text
user/
components/
```

### `user/`

The human-facing control panel.

Users should begin here.

This is organized around **what the user wants to change**, not what application happens to implement it.

Example:

```text
user/
├── appearance/
│   ├── colors.conf
│   ├── fonts.conf
│   ├── effects.conf
│   └── wallpaper.conf
│
├── keybinds/
│   ├── desktop.conf
│   ├── terminal.conf
│   ├── editor.conf
│   ├── media.conf
│   └── apps.conf
│
├── hardware/
│   ├── displays.conf
│   ├── audio.conf
│   └── performance.conf
│
├── defaults/
│   ├── apps.conf
│   ├── paths.conf
│   └── behavior.conf
│
└── features/
    ├── weather.conf
    ├── social.conf
    ├── media.conf
    ├── notifications.conf
    └── ai.conf
```

### `components/`

The implementation layer.

Rule:

```text
ROLE
└── IMPLEMENTATION
```

Examples:

```text
components/
├── compositor/
│   └── sway/
│
├── desktop-shell/
│   └── quickshell/
│
├── terminal-emulator/
│   └── kitty/
│
├── shell/
│   └── zsh/
│
├── multiplexer/
│   └── zellij/
│
├── editor/
│   └── nvim/
│
├── file-manager/
│   └── yazi/
│
├── system-monitor/
│   └── btop/
│
├── audio-visualizer/
│   └── cava/
│
├── music-daemon/
│   └── mpd/
│
└── messaging/
    ├── vesktop/
    └── session/
```

This creates a natural learning path:

```text
WHAT I WANT TO CHANGE
        ↓
user/
        ↓
WHAT PART OF THE SYSTEM DOES IT
        ↓
components/
        ↓
HOW THE PROGRAM ACTUALLY WORKS
```

---

# 6. Compatibility Architecture

The project should not fundamentally depend on an application name.

It should depend on **capabilities**.

Instead of saying:

```text
I require Kitty.
```

the system should think:

```text
I require a terminal that can provide:
- arbitrary command launch
- predictable app/window identity
- custom font configuration
- custom colors
- transparency
- keyboard mappings
- project-specific integration behavior
```

Then individual applications implement that capability contract.

## Proposed compatibility tree

```text
compatibility/
├── terminal-emulator/
│   ├── contract.conf
│   ├── kitty/
│   │   ├── provider.conf
│   │   ├── adapter.sh
│   │   └── notes.md
│   └── ghostty/
│       ├── provider.conf
│       ├── adapter.sh
│       └── notes.md
│
├── compositor/
├── editor/
├── file-manager/
└── ...
```

## User choice stays simple

Example:

```text
# user/defaults/apps.conf

terminal=ghostty
editor=nvim
file-manager=yazi
```

The user should not need to manually reorganize configuration when switching applications.

The project should resolve the implementation automatically.

## Compatibility labels

Use clear, non-judgmental labels:

| Label | Meaning |
|---|---|
| **Reference** | Main implementation used to build and test the project |
| **Native Supported** | Alternative already provides everything required |
| **Adapted Supported** | Alternative works fully with project compatibility glue |
| **Partial** | Known missing functionality |
| **Unknown** | Not tested; users are free to experiment |

Example:

```text
Kitty   → Reference
Ghostty → Adapted Supported
```

if a future Ghostty adapter fills one or two missing capabilities.

## Alternative applications

The installer should not say:

> Kitty not found. Error.

Prefer something like:

> This project is built and tested around Kitty. Your current terminal was detected and can still be used. The reference terminal is available here if you want the supported reference experience.

If the project later ships or maintains a forked terminal, that can become the recommended reference implementation.

---

# 7. Reference Build vs Required Build

This distinction should be a **core project philosophy**.

The project should clearly document:

- **Reference:** what the project is designed and tested around
- **Required:** what truly cannot be replaced
- **Compatible alternative:** what can be swapped directly
- **Adapted alternative:** what works through a shim/adapter
- **Partial alternative:** what loses functionality
- **Experimental alternative:** what the project does not currently guarantee

This avoids forcing users into specific software while still being honest about why certain tools were chosen.

Many tools were selected specifically because they are:

- highly configurable
- modular
- scriptable
- composable
- transparent in behavior
- friendly to external control

A more restrictive replacement may not expose enough functionality for other project features to work.

Users should be warned before switching, not prevented from switching.

---

# 8. Current System Environment

Current primary environment:

```text
OS: Fedora Silverblue 44
Compositor: Sway / custom SwayFX fork
Desktop shell: Quickshell
Terminal: Kitty
Multiplexer: Zellij
Shell: Zsh
Editor: Neovim / AstroNvim
GPU: NVIDIA Quadro K4200
NVIDIA driver: 470xx
Audio: PipeWire
```

Displays:

```text
DP-5
- primary
- 2560×1440
- ~164.834 Hz

HDMI-A-1
- secondary
- 1360×768
- ~60.015 Hz
```

Primary visual style:

> old TV + neon future pop

Aesthetic goals include:

- CRT influence
- neon glows
- pixel/terminal typography
- purple/black background
- cyan inactive states
- orange active states
- layered bloom/glow
- occasional magenta/red/yellow semantic accents
- future VHS/CRT media effects
- possible LCD-style full-color Quickshell panels

Primary font:

```text
GohuFont 11 Nerd Font Mono
```

---

# 9. Core Color System

Known project palette:

```text
Background purple/black: #1B0623
Cyan:                   #55CFCA
Orange:                 #ED981A
Yellow:                 #F2BE4E
Blue:                   #5B5FD4
Red:                    #D16041
Magenta:                #C74EC7
Offwhite:               #DCF3FA
Green:                  #9ECE6A
Omnitrix green:         #00F782
```

General visual state philosophy:

```text
inactive → cyan
active   → orange
hover    → stronger glow
pressed  → strongest glow
critical → red/magenta depending on context
```

---

# 10. Sway / SwayFX

## Current custom fork

Source:

```text
~/src/swayfx
```

SceneFX source:

```text
~/src/scenefx
```

Installed runtime prefix:

```text
~/.local/opt/swayfx
```

Wrapper:

```text
~/.local/bin/swayfx
```

Current wrapper concept:

```bash
#!/usr/bin/env bash

export LD_LIBRARY_PATH="$HOME/.local/opt/swayfx/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

exec "$HOME/.local/opt/swayfx/bin/sway" "$@"
```

GitHub fork:

```text
https://github.com/kudokudo1/animate-swayfx
```

Remotes:

```text
origin   → https://github.com/kudokudo1/animate-swayfx
upstream → https://github.com/wlrfx/swayfx.git
```

Current live version previously observed:

```text
0.6-663cf66f
branch: master
```

## Current visual config

```text
shadows enable
shadow_blur_radius 20
shadow_offset 0 0
shadow_color #ED981A
shadow_inactive_color #55CFCA

animation_duration_ms 250
```

## Future SwayFX goals

Planned eventual framework:

```text
animation open CRT
animation close CRT
animation workspace ...
```

Goal: optional per-event animation system while preserving stable Sway semantics.

Also desired:

- glows/shadows that follow tabbed/stacked container boundaries
- global defaults
- optional per-tab overrides
- future effect plugins/shader integration

---

# 11. Current Sway Configuration

Current major bindings/choices:

```text
$mod = Mod4
movement = h/j/k/l
terminal = kitty zellij
menu = Quickshell IPC launcher
file explorer = kitty yazi
```

Quickshell autostart:

```text
exec_always sh -c 'pkill -x quickshell; quickshell >/tmp/quickshell.log 2>&1 &'
```

Autotiling:

```text
exec_always /var/home/mapple/.local/bin/autotiling
```

Output configuration:

```text
DP-5     2560x1440@164.834Hz position 0,0
HDMI-A-1 1360x768@60.015Hz   position 2560,0

workspace 1 output DP-5
exec swaymsg workspace 1
exec swaymsg focus output DP-5
```

Visual:

```text
gaps inner 8px
gaps outer 5px
gaps top 1px
default_border pixel 2px
default_floating_border pixel 4px
```

Focused client palette includes:

```text
#ED981A
#1B0623
#55CFCA
#DCF3FA
#F2BE4E
```

Future public refactor should separate:

- theme/colors
- keybinds
- outputs
- default apps
- window rules
- animation settings
- core behavior

---

# 12. Quickshell

Current location:

```text
~/.config/quickshell
```

Major structure:

```text
quickshell/
├── shell.qml
├── components/
├── modules/
├── services/
├── widgets/
├── assets/
└── archive/
```

Known components include:

```text
components/
├── Colors.qml
├── Basicbutton.qml.template
├── GohuFont.qml
├── GohuText.qml
├── MenuTemplate.qml.template
└── NotoText.qml
```

Modules include:

```text
Applauncher
Bluetooth
Calendar
Clock
Cpu
Gaming
Mediaplayer
Network
Notifications
Performancemode
Power
Screenshot
Sessions
Volumebar
Wallpaper
Weather
Workspaces
```

Services include:

```text
services/messaging/SessionAdapter.qml
services/weather/SpaceService.qml
services/weather/WeatherService.qml
```

Widgets include:

```text
AppControlW.qml

widgets/messanger/
├── AppSelector.qml
├── ChatFeed.qml
├── ContactList.qml
├── DiscordBackingW.qml
├── DiscordGeometry.py
└── MessagingW.qml

widgets/weather/
├── StationHome.qml
├── StationTerminal.qml
└── WeatherStationW.qml
```

`AppControlW.qml` is a major custom subsystem and should be treated as core authored code.

---

# 13. Weather Station / Observatory

Planned structure:

```text
Weather button
    ↓
Weather Station
    ↓
Observatory
```

Names:

```text
Weather Station = quick/full panel layer
Observatory     = larger full-window experience
```

Observatory planned modes:

```text
HOME
MAP
NEWS
RADIO
SKY
```

Weather Station content categories:

```text
1. Permanent
2. Favorited
3. Temporary
4. Non-critical
```

Planned features:

- wttr.in weather
- radio feeds
- news feeds
- weather maps
- wind maps
- astronomy / SKY mode
- Astroterm star data
- event/intensity heatmaps
- chaos/random view
- favorite/temporary/non-critical content logic
- future LoRa integration
- possible anti-camera / "defloc" map experiments

Current custom script:

```text
~/.local/bin/weatherstation-starmap
```

Concept:

```bash
while true; do
    astroterm
    sleep 0.2
done
```

---

# 14. Messaging / Social Layer

## Quickshell messaging UI

Custom core pieces:

```text
MessagingW.qml
Sessions.qml
AppSelector.qml
ContactList.qml
ChatFeed.qml
SessionAdapter.qml
DiscordGeometry.py
```

Current social concept supports:

```text
Session
Discord / Vesktop
future Telegram or other services
```

`MessagingW.qml` uses a Quickshell window around the messaging UI and integrates Discord/Vesktop as an external app.

Discord geometry is managed through:

```text
DiscordGeometry.py
```

using Sway IPC / geometry synchronization.

---

# 15. Session Integration

`SessionAdapter.qml` is authored project glue.

Current Session CLI path:

```text
~/.local/share/session-cli-venv/bin/session-cli
```

Current adapter behavior:

- list conversations
- select conversation
- fetch messages
- send messages
- poll conversation list
- poll selected messages
- expose errors/loading state to QML

`session-cli` details:

```text
Name: session-cli
Version: 1.7.0
Upstream: https://github.com/amanverasia/session-cli
License: MIT
```

This is third-party and should not be presented as authored code.

Classification:

```text
custom/core:
- MessagingW.qml
- Sessions.qml
- AppSelector.qml
- ContactList.qml
- ChatFeed.qml
- SessionAdapter.qml

third-party:
- Session Desktop
- session-cli
- Python dependencies

private/runtime:
- Session databases
- account data
- attachments
- local storage
- logs
- caches
```

Session is currently broken after an update and should be repaired later, not treated as fully stable yet.

---

# 16. Vesktop / Discord

Vesktop config directory was normalized to lowercase:

```text
~/.config/vesktop
```

Compatibility symlink retained:

```text
~/.config/Vesktop → ~/.config/vesktop
```

## Custom authored theme

Main theme:

```text
~/.config/vesktop/themes/neon_crt_discord_v0.1.theme.css
```

This is significant authored project material.

It includes:

- full palette
- Gohu font
- hard/square geometry
- RadialStatus integration
- server rail
- channel sidebar
- DM sidebar
- main chat
- friends
- member sidebar
- headers
- search
- message input
- user panel
- profile/activity styling
- call UI
- Nitro/Quest areas
- GIF/emoji/sticker pickers
- settings
- glow states
- live resize performance mode

Quick CSS:

```text
~/.config/vesktop/settings/quickCss.css
```

includes resize-performance rules.

## Vencord source

Current Vencord source tree is third-party and unmodified.

Do not treat it as a project fork.

## Runtime/private directories

Do not ship:

```text
sessionData/
Code Cache/
Crashpad/
Local Storage/
Session Storage/
cookies
tokens
singleton files
generated custom-vencord output
```

---

# 17. Terminal Stack

Current reference chain:

```text
Sway
 ↓
Kitty
 ↓
kitty-zellij
 ↓
Zellij
 ↓
Zsh
```

## Kitty

Current config:

```text
~/.config/kitty/
├── kitty.conf
├── theme.conf
├── weatherstattion.conf
└── backups
```

Known settings include:

- Gohu font
- purple background
- opacity around 0.8 in current config
- custom padding
- Zellij wrapper shell
- separate weather terminal profile
- no decorations / reduced shortcuts in special weather profile

Kitty is currently a likely **reference terminal**, but future alternatives may be supported through compatibility adapters.

## Zellij

Mostly default/generated config with:

```text
keybinds clear-defaults=true
default_shell "zsh"
show_startup_tips false
```

Custom launcher:

```text
~/.local/bin/kitty-zellij
```

Concept:

```bash
#!/usr/bin/env bash
exec zellij attach --create main
```

---

# 18. Zsh / Shell Layer

Active ZDOTDIR:

```text
/var/home/mapple/.config/zsh
```

This is currently established through system-level Zsh environment files.

Current active tree:

```text
~/.config/zsh/
├── .zshenv
├── .zshrc
└── generated .zcompdump files
```

## Active `.zshenv`

Current behavior:

- XDG base directories
- editor = Neovim
- GPG TTY
- `~/.local/bin` in PATH
- bat/batcat man pager

## Active `.zshrc`

Current stack includes:

```text
Oh My Zsh
Powerlevel10k
zsh-autosuggestions
zsh-syntax-highlighting
zsh-interactive-cd
zoxide
fzf
eza
bat
fd
ripgrep
fastfetch
Zinit
```

Known aliases include:

```text
ls  → eza --icons
ll  → eza -lh --icons --git
la  → eza -lah --icons --git
tv  → eza --tree --icons
cat → bat
vim → nvim
```

## Known shell cleanup items

These are inventory notes, not yet fixed:

```text
XDG_CACHED_HOME    likely typo → XDG_CACHE_HOME
F2F_DEFAULT_OPTS   likely typo → FZF_DEFAULT_OPTS
command -v fg      likely meant fd
alias grep='rg...' breaks grep-style flags like -E
```

There is also redundant/legacy root shell config:

```text
~/.zshenv
~/.zshrc
```

Root `.zshenv` contains a suspicious PATH typo:

```text
export PATH=1"$HOME/.local/bin:$PATH"
```

Root `.zshrc` currently contains duplicate:

```text
export SHELL=/bin/zsh
export SHELL=/bin/zsh
```

These are likely stale because ZDOTDIR redirects Zsh to `~/.config/zsh`.

---

# 19. ZDOTDIR Discovery

Two system files currently set ZDOTDIR.

```text
/etc/zshenv
/etc/zsh/zshenv
```

`/etc/zshenv`:

- owned by Fedora `zsh` package
- modified from packaged version

Verified with:

```text
rpm -qf /etc/zshenv
→ zsh-5.9-21.fc44.x86_64
```

and:

```text
rpm -V zsh
→ S.5....T.  c /etc/zshenv
```

`/etc/zsh/zshenv`:

- not owned by any package
- custom machine-level config

For the future public project, users should **not need to modify package-owned `/etc/zshenv`**.

The public project should reproduce the same behavior cleanly at the user level.

---

# 20. Neovim

Current editor:

```text
Neovim
AstroNvim-based configuration
```

Current main config:

```text
~/.config/nvim
```

There is also:

```text
~/.config/nvim.lazyvim.bak
```

which is legacy/backup.

Known plugin ecosystem includes:

- snacks.nvim
- mini.nvim
- heirline
- AstroLSP
- AstroUI
- many custom plugin files under `lua/plugins/`

Neovim should be a separate implementation component under:

```text
components/editor/nvim/
```

User-facing editor settings should live in:

```text
user/
```

where practical.

---

# 21. GTK / Icons / Fonts

Custom GTK theme:

```text
~/.themes/oomox-NeonRetro
```

Custom icon theme:

```text
~/.icons/oomox-NeonRetro
```

Current GTK setting:

```text
gtk-theme = oomox-NeonRetro
```

Current active icon theme:

```text
Adwaita
```

So the custom icon theme exists but is not currently active.

Current font setting:

```text
GohuFont 11 Nerd Font 11
```

Fontconfig currently aliases:

```text
sans-serif
system-ui
```

to GohuFont.

Future custom icon direction may include:

- symbolic/glyph core
- selective pixel-art accents
- eventually custom artwork

---

# 22. Small Utilities — Current Classification

## Active

### Yazi

Still actively used.

Current Sway reference:

```text
file explorer = kitty yazi
```

Classification:

```text
active external app
```

### btop

Used as an active system utility.

Current Sway floating rule exists for a btop CPU window.

Classification:

```text
active utility
```

### Fastfetch

Used in shell startup.

Classification:

```text
active terminal decoration / system info utility
```

### CAVA

Referenced by Quickshell/AppControl and still useful as an external audio visualization backend/tool.

Classification:

```text
active or backend-capable utility
```

## Dormant / TBD

### MPD

Config exists but no strong current live integration reference was found.

Classification:

```text
dormant / future media backend candidate
```

## Replaced / legacy

```text
Mako
Rofi
Wofi
Waybar
```

These appear to have been replaced by Quickshell functionality.

---

# 23. Waycal

Current checkout:

```text
~/waycal
```

Git upstream:

```text
https://github.com/ForrestKnight/waycal.git
```

Current checkout is clean/unmodified.

Historical purpose:

```text
Waybar
   ↓
Waycal
   ↓
floating calendar window
```

Waycal is not currently active because Waybar is disabled.

Classification:

```text
Dormant / legacy integration
```

Possible future paths:

- reconnect Waycal through Quickshell
- replace it with a native Quickshell calendar
- remove it entirely

---

# 24. AI / Local Models

This subsystem is currently **experimental and unfinished**.

## Hermes

Current locations:

```text
~/hermes-agent
~/.hermes/hermes-agent
~/.hermes
~/.local/bin/hermes
~/.local/bin/hermes-acp
~/.local/bin/hermes-agent
```

Both Hermes source checkouts point to:

```text
https://github.com/NousResearch/hermes-agent.git
```

Both were clean when checked.

Therefore Hermes itself is third-party, not a custom fork.

Current experimental service:

```text
~/.config/systemd/user/hermes-gateway.service
```

Current service mixes:

```text
~/hermes-agent/.venv
```

for execution with:

```text
~/.hermes
```

for working/runtime state.

This should be treated as experimental plumbing.

## Ollama

Current runtime:

```text
~/.ollama
```

Current service:

```text
~/.config/systemd/user/ollama.service
```

Current service expects:

```text
/usr/local/bin/ollama serve
```

This install assumption should be revisited later.

## Copilot

Current directory:

```text
~/.copilot
```

Not deeply inventoried yet.

## LLaMA

Current artifact:

```text
~/.local/bin/llama-cli.zip
```

Observed size was only 9 bytes.

Classification:

```text
incomplete / abandoned artifact
```

---

# 25. Developer Toolbox

Toolbox should be part of the **single normal install**, not a separate developer edition.

Purpose:

```text
Developer Toolbox
├── compilers
├── Meson
├── Ninja
├── CMake
├── development headers
├── Git/build tools
├── SwayFX source
├── SceneFX source
└── experimental/dev tools
```

The desktop should not require the Toolbox to remain running.

Build artifacts should still install into normal user-accessible locations such as:

```text
~/.local/opt/
~/.local/bin/
```

Toolbox is the build/development environment, not the runtime desktop.

---

# 26. Local Scripts / Binaries

## Custom project glue

```text
~/.local/bin/swayfx
~/.local/bin/kitty-zellij
~/.local/bin/weatherstation-starmap
```

These should eventually move into the project repo under:

```text
scripts/
```

and be deployed/symlinked by the installer.

## Third-party or installer-provided tools

Current entries include:

```text
speedtest
speedtest-cli
userpath
pipx
uv
uvx
zellij
hollywood
pipes.sh
```

These are not authored project code.

`uv`, `uvx`, and `zellij` are compiled binaries.

`speedtest`, `speedtest-cli`, `userpath`, and `pipx` are Python entry points.

## Terminal toys

### Hollywood

Current local install:

```text
~/.local/opt/hollywood
```

### pipes.sh

Current local install:

```text
~/.local/opt/pipes.sh
```

`pipes.sh` is third-party MIT software.

If redistributed or vendored, preserve attribution/license.

Prefer fetching third-party dependencies rather than copying full upstream repositories into the main project.

---

# 27. Autostart / User Services

Current autostart directory:

```text
~/.config/autostart
```

No current files were found there.

Current custom user systemd services:

```text
hermes-gateway.service
ollama.service
```

These are both part of the experimental AI subsystem.

No other hidden user services were found during this inventory pass.

---

# 28. Dormant / Legacy / Backup Material

Current known dormant or legacy pieces include:

```text
Waybar
Wofi
Rofi
Mako
Waycal
nvim.lazyvim.bak
Quickshell archive/
old Session bridge experiments
```

These should not necessarily be deleted immediately.

Recommended eventual treatment:

```text
legacy/
├── waybar/
├── rofi/
├── wofi/
├── mako/
└── waycal/
```

or preserve only documentation/reference copies outside the active runtime tree.

---

# 29. Private / Runtime Data — Never Ship

The public repo must never contain private or machine-generated runtime state.

Examples:

```text
Session databases
Session attachments
Session account data
Discord tokens
Discord cookies
Vesktop sessionData
browser profiles
Code caches
Crashpad
GPU caches
Local Storage
Session Storage
logs
MPD database
MPD pid
MPD state
MPD log
.zcompdump*
build/
build-local/
target/
node_modules/
Python virtualenvs
Ollama model blobs
machine caches
temporary files
singleton files
```

Use `.gitignore` aggressively.

---

# 30. Master Project Classification

## 1. Core authored code

```text
Quickshell shell
Quickshell modules
Quickshell widgets
AppControlW.qml
Weather Station / Observatory
Messaging UI
SessionAdapter.qml
DiscordGeometry.py
SwayFX fork changes
Discord/Vesktop custom theme
QuickCSS performance glue
```

## 2. Authored configs / themes

```text
Sway config
Neovim config
Kitty config
Zellij config
Zsh config
Powerlevel10k config
Fastfetch config
btop config
CAVA config/shaders
GTK theme
icon theme
fontconfig
shared color/font system
```

## 3. Authored glue

```text
swayfx wrapper
kitty-zellij
weatherstation-starmap
Session adapter
Discord geometry integration
future compatibility adapters
future installer scripts
```

## 4. Third-party dependencies

Examples:

```text
Sway
SceneFX
Quickshell
Kitty
Zellij
Zsh
Oh My Zsh
Powerlevel10k
Zinit
zoxide
fzf
eza
bat
fd
ripgrep
fastfetch
btop
yazi
cava
Astroterm
Vesktop
Vencord
RadialStatus
Session Desktop
session-cli
Hollywood
pipes.sh
uv
uvx
pipx
speedtest-cli
Toolbox
Hermes
Ollama
Waycal
```

## 5. Dormant / legacy

```text
Waybar
Wofi
Rofi
Mako
Waycal integration
old backups
old Session bridge experiments
```

## 6. Experimental / unfinished

```text
Hermes integration
Ollama integration
Copilot integration
LLaMA artifact
future local AI integration
future Kitty/terminal CRT shader system
future custom icon system
future LoRa/weather hardware
future generalized SwayFX animation API
```

## 7. Private / runtime

Never commit.

---

# 31. Proposed Base Repository Layout

Current preferred starting skeleton:

```text
<project>/
├── README.md
├── LICENSE
├── install.sh
│
├── user/
│   ├── appearance/
│   ├── keybinds/
│   ├── hardware/
│   ├── defaults/
│   └── features/
│
├── components/
│   ├── compositor/
│   ├── desktop-shell/
│   ├── terminal-emulator/
│   ├── shell/
│   ├── multiplexer/
│   ├── editor/
│   ├── file-manager/
│   ├── system-monitor/
│   ├── audio-visualizer/
│   ├── music-daemon/
│   └── messaging/
│
├── compatibility/
│   ├── terminal-emulator/
│   ├── compositor/
│   ├── editor/
│   ├── file-manager/
│   └── ...
│
├── integrations/
│   ├── discord/
│   ├── session/
│   ├── weather/
│   ├── media/
│   └── ai/
│
├── scripts/
│
├── installer/
│
└── docs/
    ├── architecture.md
    ├── customization.md
    ├── compatibility.md
    ├── development.md
    └── dependencies.md
```

This layout should remain flexible while the live system is migrated.

Do not over-commit to folders before real files begin moving.

---

# 32. README Philosophy

The README should make the project philosophy obvious near the top.

Suggested concept:

> This project is a reference desktop, not a glued appliance.
>
> Think of it like a LEGO set or a recipe book. The included components are the reference combination used to build and test the full experience, but they are not the only possible combination.
>
> Swap parts, rewrite parts, replace parts, fork parts, or use only the pieces you like.
>
> Some components were chosen because they expose specific capabilities required by other project features. Replacing them with more restrictive alternatives may reduce functionality. Compatibility notes document those tradeoffs so you know what to expect before changing a component.

The README should then clearly point users to:

```text
Want to change colors?       → user/appearance/
Want to change keybinds?     → user/keybinds/
Want to change monitors?     → user/hardware/
Want to change default apps? → user/defaults/
Want feature settings?       → user/features/
Want implementation details? → components/
Want compatibility info?     → compatibility/
```

---

# 33. Documentation Strategy

Documentation should be written **as migration happens**, not after everything is finished.

For each component migrated into the repo, document:

```text
1. What is it?
2. Why was it chosen?
3. What capabilities does the project depend on?
4. What user settings control it?
5. What other components depend on it?
6. What files belong to it?
7. What is safe for users to edit?
8. What is implementation plumbing?
9. What alternatives are known?
10. What compatibility status do alternatives have?
```

This turns the filesystem and documentation into a teaching tool.

---

# 34. Immediate Next Phase

Before capability-contract work, the project should establish the **base Git repository locally and on GitHub**.

The desired order is:

```text
1. Choose project/repository name
2. Create ~/.config/<project-name>/
3. Create initial architecture folders
4. Add README.md
5. Add LICENSE
6. Add placeholder install.sh
7. Add .gitignore
8. git init
9. first commit
10. create GitHub repo
11. add remote
12. push
13. begin migrating live config one component at a time
```

Do **not** move live configs before the repo exists and the skeleton is committed.

---

# 35. Migration Order — Recommended

A practical migration order:

```text
1. shared user-facing appearance/default files
2. Kitty
3. Zellij
4. Zsh
5. Sway config
6. Quickshell
7. Neovim
8. GTK/font/icon themes
9. Fastfetch/btop/CAVA/Yazi
10. Discord/Vesktop theme
11. Session integration
12. Weather Station
13. Developer Toolbox
14. SwayFX build pipeline
15. AI subsystem
16. compatibility adapters
17. legacy archive cleanup
```

This order is not mandatory.

The key rule is:

> Move one real subsystem, make it live from the repo, test it, document it, then continue.

---

# 36. Compatibility Contract Work — Later

After the base repo exists and the first components are migrated, begin documenting **capability contracts**.

Example terminal contract:

```text
required capabilities:
- launch arbitrary commands
- predictable app/window identity
- configurable fonts
- configurable colors
- transparency
- keyboard mappings
- ability to integrate with Zellij
- ability to support any project-specific terminal behavior
```

Then inspect the current Kitty config and identify:

```text
what is merely a Kitty preference
vs
what the rest of the desktop actually depends on
```

Repeat for:

```text
compositor
desktop shell
editor
file manager
media backend
messaging backend
notification system
```

---

# 37. Known Future Design Areas

Still to be designed later:

```text
project name
GitHub repo name
license choice
exact install strategy
exact package installation method
Fedora-only vs broader distro support
how much Silverblue-specific behavior to assume
Toolbox image/package manifest
reference vs adapted terminal support
Ghostty compatibility
shared config file format
config generation strategy
reload/reconfigure strategy
backup/rollback behavior
upgrade strategy
versioning
migration between project releases
SwayFX patch distribution strategy
Quickshell module boundaries
AI backend architecture
media backend architecture
icon system
shader/effect system
```

---

# 38. Current Principle Summary

The project should be:

```text
one install
one config root
one source of truth
human-readable
modular
swappable
capability-based
well documented
honest about compatibility
developer-friendly
beginner-explorable
not beginner-restricted
```

The intended culture:

> Learn what the system is made of.
>
> Learn where its files live.
>
> Learn what they do.
>
> Change them.
>
> Break things on purpose.
>
> Put them back together differently.
>
> The reference build is a starting point, not a cage.

---

# 39. Current Next Action

The very next action is:

> **Choose the project/repository name.**

Then create the base repo locally in:

```text
~/.config/<project-name>/
```

and create the matching GitHub repository.

After that, begin moving the live system into the repo one subsystem at a time while documenting:

- capabilities
- dependencies
- linked features
- compatibility expectations
- user-editable controls
- implementation details

along the way.

---

# 40. Do Not Forget

Important decisions already made:

```text
DO:
- use one installer
- include developer Toolbox in the normal install
- centralize user-editable config
- keep live config linked directly to the repo
- organize implementation by ROLE → IMPLEMENTATION
- organize user settings by human intent
- use compatibility adapters where practical
- clearly explain why reference components were chosen
- support experimentation
- warn about known capability loss
- keep docs close to implementation work

DO NOT:
- create multiple install editions
- make users hunt across random config directories
- duplicate editable config copies
- call alternatives "wrong"
- silently pretend incompatible apps are fully supported
- vendor giant third-party source trees without reason
- publish private/runtime data
- force users to modify package-owned system files
- wait until the end to document dependencies
```

---

*End of current project reference.*
