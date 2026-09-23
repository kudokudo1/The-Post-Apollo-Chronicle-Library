# Meta Apollo Logos — Repository Architecture & Migration Plan

> Working project architecture as of 2026-09-17.
>
> This document focuses on **how the project should be organized, installed, edited, migrated, and maintained**.
> It is intentionally separate from the naming/design-language document.

---

# 1. Core Goal

Meta Apollo Logos should become a **single installable desktop ecosystem** built from modular pieces.

The project should be:

- easy to install
- easy to inspect
- easy to modify
- easy to fork
- easy to learn from
- modular enough that users can replace individual components
- honest about which replacements are fully compatible and which are not

The user should be able to treat the project like a **LEGO set** or **recipe book**:

> The included build is the reference build, not the only valid build.

---

# 2. One Install, Not Multiple Editions

The project should have one normal installation path.

Avoid:

```text
minimal install
full install
developer install
advanced install
AI install
```

Prefer:

```bash
git clone <repo-url> ~/.config/<project-name>
cd ~/.config/<project-name>
./install.sh
```

The installer can install everything needed for the reference experience.

If a user never touches a feature, that is fine.

Examples:

- AI tooling can remain unused.
- The developer Toolbox can remain unused.
- Weather features can remain unused.
- Discord/Session integrations can remain unused.
- Extra utilities can remain unused.

The project should favor **simple installation over combinatorial installer complexity**.

---

# 3. Dogfood the Public Layout

The developer machine should use the same layout as the public project.

The repository should eventually live directly inside the central config root:

```text
~/.config/<project-name>/
```

The developer should not have:

```text
special development copy
        ↓
later translated into public copy
```

Instead:

```text
public repo clone
        =
developer's live config source
```

The migration process should be:

```text
current live config
        ↓
move into repo
        ↓
normal app config path becomes symlink
        ↓
test
        ↓
commit
        ↓
document
```

This makes the local setup a continuous test of the public user experience.

---

# 4. Centralized Configuration

A central design rule:

> **User-editable configuration should be centralized, readable, and discoverable.**

Users should not have to hunt through random application directories to find settings.

The single source of truth should live under:

```text
~/.config/<project-name>/
```

Normal application paths can symlink into that tree.

Example:

```text
~/.config/sway
    → ~/.config/<project-name>/components/compositor/sway

~/.config/kitty
    → ~/.config/<project-name>/components/terminal-emulator/kitty

~/.config/quickshell
    → ~/.config/<project-name>/components/desktop-shell/quickshell
```

The project should avoid editable duplicate copies.

Bad:

```text
repo copy
≠
live copy
```

Good:

```text
repo copy
=
live copy
```

---

# 5. Human-Readable Two-Layer Layout

The project should not mix application names and abstract categories at the same level.

Instead, use two main layers:

```text
user/
components/
```

## `user/`

This is the human-facing control panel.

It should answer:

> What do I want to change?

Proposed structure:

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

## `components/`

This is the implementation layer.

It should answer:

> What program actually provides this role?

Rule:

```text
ROLE
└── IMPLEMENTATION
```

Example:

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

This creates a clear learning path:

```text
WHAT I WANT TO CHANGE
        ↓
user/
        ↓
WHAT PART OF THE SYSTEM DOES IT
        ↓
components/
        ↓
HOW THAT PROGRAM ACTUALLY WORKS
```

---

# 6. One Source of Truth for User Settings

The project should not define the same concept independently in several apps.

Example:

```text
user/appearance/colors.conf
```

should conceptually drive:

```text
Sway
Quickshell
Kitty
Discord/Vesktop
Fastfetch
other themed components
```

Likewise:

```text
user/hardware/displays.conf
user/defaults/apps.conf
user/keybinds/desktop.conf
```

should represent the human decision once.

Individual components should consume, import, source, or be generated from those user-facing settings.

---

# 7. Swappable Components

Swapping an application should not require users to manually split its configuration into several different locations.

The user should ideally be able to change something like:

```text
# user/defaults/apps.conf

terminal=ghostty
editor=nvim
file-manager=yazi
```

and let the project resolve the correct implementation.

The project should not require a second external configuration organizer.

The architecture should already know where each implementation belongs.

---

# 8. Compatibility Layer

The project should depend on **capabilities**, not only application names.

Instead of:

```text
I require Kitty.
```

the project should think:

```text
I require a terminal capable of:
- launching arbitrary commands
- predictable app/window identity
- custom fonts
- custom colors
- transparency
- keyboard mapping
- integration with the rest of the stack
```

Proposed structure:

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

Possible compatibility labels:

| Label | Meaning |
|---|---|
| Reference | Main implementation used to build/test the project |
| Native Supported | Alternative already provides required capabilities |
| Adapted Supported | Alternative works fully through project glue |
| Partial | Known missing functionality |
| Unknown | Not tested; experimentation encouraged |

Example:

```text
Kitty   → Reference
Ghostty → Adapted Supported
```

if the project later provides a shim for missing features.

---

# 9. Reference Build Philosophy

The project should never imply that an alternative app is "wrong."

Instead, explain:

- what the project is built around
- why that component was chosen
- what capabilities other features depend on
- what happens if it is replaced
- whether the replacement is native, adapted, partial, or unknown

Example wording:

> This project is built and tested around Kitty. Other terminals can be used, but some features depend on capabilities Kitty provides. Compatibility notes explain known tradeoffs.

If the project later includes a forked terminal or specially adapted terminal, that may become the new reference.

---

# 10. Close Alternatives and Adapters

If an alternative is very close to the reference implementation, the project may provide compatibility glue.

Example:

```text
Ghostty supports:
✔ feature A
✔ feature B
✔ feature C
✘ project-specific feature D
```

Then the project may provide:

```text
wrapper
config generator
bridge service
adapter script
plugin
```

to fill the missing gap.

The goal is:

```text
swap implementation
        ↓
keep project behavior
```

when realistically possible.

---

# 11. Proposed Repository Skeleton

Current preferred base skeleton:

```text
<project>/
├── README.md
├── LICENSE
├── .gitignore
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
├── installer/
│
└── docs/
    ├── architecture.md
    ├── customization.md
    ├── compatibility.md
    ├── development.md
    └── dependencies.md
```

This is a starting structure, not a prison.

Real files should drive final folder decisions.

---

# 12. Main Combined Repo vs Individual Repos

The project will likely grow into an ecosystem of repositories.

The combined project should provide the complete reference environment.

Individual components may eventually have their own repositories, for example:

```text
terminal / Kitty config repo
Fastfetch config repo
SwayFX fork/config repo
Quickshell shell repo
Discord/Vesktop theme repo
Neovim config repo
```

The combined repo should be able to bring those pieces together.

Possible long-term relationship:

```text
individual component repos
        ↓
combined reference project
        ↓
single install
```

Exactly how the combined repo consumes those component repos is not final yet.

Possible options to evaluate later:

- Git submodules
- pinned releases
- installer fetches
- subtree/vendor snapshots
- generated manifests

Avoid committing giant third-party upstream source trees unless necessary.

---

# 13. Current Major Authored Components

Known authored/core project pieces include:

```text
Quickshell shell
Quickshell modules
AppControlW.qml
Weather Station / Observatory
Messaging UI
SessionAdapter.qml
DiscordGeometry.py
SwayFX animation/fork work
Discord/Vesktop Neon CRT theme
QuickCSS resize/performance glue
custom integration scripts
```

Known user-authored config areas include:

```text
Sway
Kitty
Zellij
Zsh
Neovim/AstroNvim
Fastfetch
btop
CAVA
GTK theme
fontconfig
Discord/Vesktop theme
```

---

# 14. Current Custom Glue

Current important custom scripts:

```text
~/.local/bin/swayfx
~/.local/bin/kitty-zellij
~/.local/bin/weatherstation-starmap
```

These should eventually move into:

```text
scripts/
```

inside the project and be linked/deployed by the installer.

---

# 15. Developer Toolbox

The developer Toolbox should be included in the normal single installation.

Purpose:

```text
Developer Toolbox
├── compilers
├── Meson
├── Ninja
├── CMake
├── development headers
├── source trees
├── SwayFX build dependencies
├── SceneFX build dependencies
└── debugging/experimental tools
```

The runtime desktop should not depend on the Toolbox staying open.

Build products should install into normal user paths such as:

```text
~/.local/opt/
~/.local/bin/
```

---

# 16. Legacy / Dormant Material

Known dormant or replaced pieces include:

```text
Waybar
Wofi
Rofi
Mako
Waycal
old Quickshell backups
old Neovim backup
old Session bridge experiments
```

Waycal was historically used as:

```text
Waybar
   ↓
Waycal
   ↓
floating calendar window
```

It is currently dormant because Waybar is not active.

---

# 17. Experimental Areas

Current unfinished areas include:

```text
Hermes
Ollama
Copilot
local LLaMA experiments
AI integration
future terminal CRT shaders
future custom icon system
future LoRa/weather hardware
future generalized SwayFX animation API
```

These should not be treated as stable reference capabilities yet.

---

# 18. Private / Runtime Data

Never commit:

```text
Session account/database data
Session attachments
Discord tokens/cookies
Vesktop sessionData
browser profiles
Code caches
Crashpad
GPU caches
Local Storage
Session Storage
logs
MPD pid/state/database/log
.zcompdump files
build directories
target directories
node_modules
virtualenvs
Ollama model blobs
machine caches
singleton/runtime files
```

The `.gitignore` should be written early and aggressively.

---

# 19. Documentation While Migrating

Do not wait until the project is finished to document it.

For every component moved into the repo, document:

```text
1. What is it?
2. Why was it chosen?
3. What capabilities does the project use?
4. What user settings control it?
5. What other features depend on it?
6. What files belong to it?
7. What is safe to edit?
8. What is plumbing?
9. What alternatives exist?
10. What compatibility class does each alternative have?
```

This lets capabilities, dependencies, and linked features be documented while they are fresh.

---

# 20. Recommended Migration Workflow

For each subsystem:

```text
inspect current live config
        ↓
identify authored vs third-party vs runtime
        ↓
define destination in project tree
        ↓
move/copy into project repo
        ↓
replace old live path with symlink
        ↓
reload/test
        ↓
commit
        ↓
document dependencies and capabilities
```

Do one subsystem at a time.

Do not migrate the whole machine in one destructive operation.

---

# 21. Suggested Migration Order

A reasonable order:

```text
1. create base repo
2. establish shared user-facing settings
3. Kitty
4. Zellij
5. Zsh
6. Sway config
7. Quickshell
8. Neovim
9. Fastfetch / btop / CAVA / Yazi
10. GTK / fonts / icons
11. Vesktop / Discord theme
12. Session integration
13. Weather Station
14. Developer Toolbox
15. SwayFX build pipeline
16. AI subsystem
17. compatibility adapters
18. legacy cleanup
```

The exact order can change.

---

# 22. Immediate Next Steps

Before migrating real files:

```text
1. choose final working repo/directory name
2. create ~/.config/<project-name>/
3. create base folder skeleton
4. add README.md
5. add LICENSE
6. add .gitignore
7. add placeholder install.sh
8. git init
9. make first commit
10. create matching GitHub repo
11. push
12. migrate the first live component
```

The project should be usable locally before its architecture becomes complicated.

---

# 23. Core Principles to Keep

```text
ONE INSTALL
ONE CONFIG ROOT
ONE SOURCE OF TRUTH
HUMAN-READABLE
MODULAR
SWAPPABLE
CAPABILITY-BASED
REFERENCE, NOT RESTRICTION
DOCUMENT AS YOU BUILD
DOGFOOD THE PUBLIC LAYOUT
```

The filesystem itself should help teach users how the desktop works.

