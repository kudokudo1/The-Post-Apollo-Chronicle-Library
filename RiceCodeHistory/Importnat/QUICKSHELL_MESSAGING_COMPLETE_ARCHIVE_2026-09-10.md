# Quickshell Messaging Complete Archive — 2026-09-10

> This single file concatenates every Markdown document from the documentation bundle. The split files remain preferable for day-to-day reference.


<!-- ===== BEGIN README.md ===== -->

# Quickshell Messaging Project Documentation

**Snapshot date:** 2026-09-10  
**Environment:** Fedora/Silverblue + Sway + Quickshell  
**Working messenger:** Session  
**Next planned messenger:** Discord

This folder is a complete handoff/archive for the messaging work completed so far. It is split into one master history plus focused deep dives so future work can resume without rediscovering the same problems.

## Source-of-truth rule

The project changed rapidly during debugging. Use this precedence whenever two notes disagree:

1. A change explicitly confirmed as correct in the conversation.
2. The newest pasted/uploaded source file.
3. Older pasted/uploaded files.
4. The historical project dossier.

The dossier is valuable for project design language and historical context, but it is **not canonical over current source**.

## Documents

- **`00_MASTER_COMPLETE_HISTORY.md`** — full project history and current state in one place.
- **`01_SESSION_INTEGRATION_DEEP_DIVE.md`** — every important Session route we explored, failed attempts, the working `session-cli` path, CDP sending, and `SessionAdapter` behavior.
- **`02_MESSAGING_WIDGET_ARCHITECTURE.md`** — detailed component structure, focus/navigation, data flow, current QML contracts, and reusable adapter model.
- **`03_QUICKSHELL_RICE_REFERENCE.md`** — Quickshell/Sway/windowing knowledge, visual conventions, crash investigation, layer-shell stacking, logging, and shell gotchas.
- **`04_FUTURE_MESSAGING_ADAPTERS.md`** — how to add Discord, Telegram, Signal, or other messaging backends without rebuilding the frontend.
- **`05_RECOVERY_GOTCHAS_AND_FORGOTTEN_DETAILS.md`** — easy-to-forget fixes and regression traps.
- **`06_CURRENT_STATE_HANDOFF.md`** — short “start here tomorrow” state summary.
- **`07_SOURCE_OF_TRUTH_AND_DIFF_NOTES.md`** — discrepancies between older uploaded files and the final accepted state.

## Fast restart

The details most likely to save hours later are:

- The directory is spelled **`widgets/messanger/`**.
- `modules/Sessions.qml` is the launcher button; `services/messaging/SessionAdapter.qml` is the Session backend adapter.
- Session is currently app index `0`; Discord is `1`; Telegram is `2`.
- The messaging root `PanelWindow` must stay `visible: true`; hide the child content and collapse the input `mask` when closed.
- Do **not** restore `visible: menuOpen` on the root messaging window; repeated toggling hit a native Qt/Quickshell crash.
- The messaging window uses `import Quickshell.Wayland` and `WlrLayershell.layer: WlrLayer.Overlay` so it stacks above the separate Power window.
- Session reads work through `session-cli`; sending requires Session Desktop launched with CDP on port `9222`.
- `Colors.black` is deep purple `#1B0623`, not literal black. There is no `Colors.background`.
- Contact hover is visual only; it must not change the selected conversation.
- The selected contact remains orange/yellow even after focus moves to the composer.
- The latest requested Session polish was a Session icon in AppSelector and magenta typed composer text. Verify those two final edits are physically saved because they were requested after the last complete file uploads.
- Discord is next. Reuse the frontend and add an adapter.

## Current architecture

```text
modules/Sessions.qml
        │
        │ toggles messagingWindow.menuOpen
        ▼
widgets/messanger/MessagingW.qml
        │
        ├── AppSelector.qml
        │      └── chooses backend
        │
        ├── ContactList.qml
        │      └── normalized conversations
        │
        └── ChatFeed.qml
               └── normalized messages + send signal

services/messaging/
        ├── SessionAdapter.qml      [working]
        ├── DiscordAdapter.qml      [planned next]
        ├── TelegramAdapter.qml     [planned]
        └── SignalAdapter.qml       [planned]
```

The long-term goal is that a new messenger mostly requires a new adapter and app metadata, not copies of ContactList/ChatFeed/composer/navigation.


<!-- ===== END README.md ===== -->

<!-- ===== BEGIN 00_MASTER_COMPLETE_HISTORY.md ===== -->

# Complete Quickshell Messaging Project History

**Snapshot:** 2026-09-10  
**Status:** Session substantially complete and proven; Discord is the next backend.

This is the master record of the messaging work. It preserves the implementation, failed experiments, discoveries, UI decisions, windowing bugs, accepted fixes, operational commands, and future direction. The focused documents beside this one go even deeper into individual areas.

---

## 1. What we set out to build

The messaging project evolved from a launcher/menu idea into a reusable multi-service messaging surface inside Quickshell.

The target interaction is:

```text
APP SELECTOR  →  CONTACT LIST  →  MESSAGE FEED / INPUT
     ←                 ←
```

The frontend should eventually work with several backends without being rebuilt for each one. Session became the first real backend and therefore the architecture prototype. Discord is next, with Telegram and Signal considered later.

Current project split:

```text
modules/
└── Sessions.qml                 # launcher/button

widgets/messanger/               # spelling is currently intentional
├── AppSelector.qml              # service selection
├── ContactList.qml              # normalized conversations
├── ChatFeed.qml                 # normalized messages + composer
└── MessagingW.qml               # window/controller/composition

services/messaging/
└── SessionAdapter.qml           # Session-specific integration
```

A future service directory may become:

```text
services/messaging/
├── MessagingBackend.qml         # optional common interface/base
├── BackendRegistry.qml          # optional backend selection layer
├── SessionAdapter.qml
├── DiscordAdapter.qml
├── TelegramAdapter.qml
└── SignalAdapter.qml
```

---

## 2. Source-of-truth rule

Many full files were pasted while the widget was being debugged. Some older files are still syntactically valid but no longer express the final behavior.

Use this precedence:

```text
explicitly accepted final change
    ↓
latest pasted/uploaded source
    ↓
older source
    ↓
historical project dossier
```

The historical dossier remains useful for visual language and old architecture, but current pasted source wins whenever they disagree.

There are three particularly important late-state discrepancies:

1. the final `MessagingW.qml` Wayland overlay fix was accepted after an uploaded file contained the attached property in the wrong place;
2. the selected contact was explicitly changed to remain orange after composer focus, even though an older ContactList upload could turn it cyan;
3. the Session AppSelector icon and magenta typed input were requested after the last complete AppSelector/ChatFeed uploads and should be verified in the working tree.

See `07_SOURCE_OF_TRUTH_AND_DIFF_NOTES.md`.

---

## 3. Environment and broader Quickshell philosophy

The rice is based around:

```text
Fedora/Silverblue
Sway
Quickshell
```

The broader architectural idea is:

```text
Sway
  │
  ▼
Quickshell
  ├── workspaces → Sway
  ├── audio      → PipeWire
  ├── network    → NetworkManager
  ├── bluetooth
  ├── clock
  ├── power
  ├── launcher
  ├── messaging
  └── other desktop-facing HUD modules
```

The project keeps a useful division:

```text
Quickshell = quick graphical controls + glanceable information
Terminal   = deeper keyboard-heavy control and work
```

The messaging surface follows that philosophy: it is a compact graphical messaging control, while service-specific heavy lifting is delegated to helper processes/adapters.

---

## 4. Visual language

The messaging widget intentionally reused the existing rice rather than inventing a generic “neon cyber” theme.

Authoritative `Colors.qml`:

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

Critical details:

```text
Colors.black = #1B0623     deep purple, not literal black
Colors.dark  = #16051F     darker purple
Colors.background does not exist
```

General state semantics:

```text
cyan     normal / information / interface / data
orange   active / focused / hot / important
yellow   selected / emphasized
magenta  pressed / special interaction
red      error / destructive / urgent
white    neutral supporting text
green    established palette color with less universal meaning
omnitrix vivid green used by specific modules, including Sessions launcher styling
```

Most messaging geometry is deliberately square:

```qml
radius: 0
```

Borders stay thin and glow carries most of the visual weight.

Typography centers on:

```text
GohuFont 11 Nerd Font Mono
```

The broader rice mixes retro-computing/CRT/terminal language, old television/PC/game UI references, celestial and occasional Christian motifs, retro-American/Japanese reinterpretations, and playful comic/anime-like energy. These are a vocabulary, not a checklist to place in every widget.

---

## 5. Power.qml as interaction reference

`Power.qml` became the strongest reference for menu interaction state.

Typical background logic:

```qml
color: pressed
    ? Colors.magenta
    : !keyboardActive && containsMouse
    ? Colors.yellow
    : selected
    ? Colors.yellow
    : Colors.black
```

Typical text logic:

```qml
color: pressed
    ? Colors.black
    : !keyboardActive && containsMouse
    ? Colors.orange
    : selected
    ? Colors.orange
    : Colors.cyan
```

Selected/hover text can use a strong orange glow:

```text
DropShadow
radius: 30
samples: 60
```

Buttons can use a smaller active shadow around:

```text
radius: 12
samples: 25
opacity: ~0.55
```

However, AppSelector was deliberately left with the broader Clock/workspace-style two-layer `RectangularShadow` glow. We reused Power's state semantics without flattening every visual effect into the exact same implementation.

---

# Part I — Session research and integration

## 6. The Session problem

The practical requirements were:

```text
1. list real Session conversations
2. load real message history
3. distinguish incoming/outgoing messages
4. keep the view reasonably fresh
5. send real messages from Quickshell
6. avoid embedding fragile Session internals throughout the QML UI
```

Several approaches were investigated before settling on the current adapter.

---

## 7. Session environment

Flatpak application id:

```text
network.loki.Session
```

Recorded Session Desktop version during the work:

```text
1.18.1
```

Session data lives under:

```text
~/.var/app/network.loki.Session/config/Session/
```

Session Desktop is Electron-based and ships resources under paths such as:

```text
/app/Session/
/app/Session/resources/app.asar
/app/Session/resources/app.asar.unpacked/
```

The inspected `app.asar` was around 125 MB.

---

## 8. Attempt 1 — direct SQLCipher/database access

The first attractive route was direct local database reading.

Why it looked good:

```text
no need for a running GUI
fast local reads
simple polling
complete control over queries
```

The Session package includes SQLCipher-related native components, and schema/query behavior was investigated.

What went wrong:

```text
decryption/HMAC/key handling did not produce a stable manual connection
```

The broader problem was maintainability. Even if a working key derivation were reverse engineered, our Quickshell config would then depend on Session's internal encrypted storage implementation.

Decision:

```text
ABANDONED as the primary route
```

Lesson:

> Do not make Quickshell responsible for Session database cryptography if a helper can provide a cleaner boundary.

---

## 9. Attempt 2 — inspect the Session Flatpak/Electron bundle

The Flatpak environment was opened and inspected.

We confirmed Electron resources and native Session modules existed inside `/app/Session`.

Tool availability inside the sandbox was checked:

```text
python3  available
node     not available
npm      not available
npx      not available
7z       not available
bsdtar   available
tar      available
unzip    available
```

This mattered because modifying/repaking an Electron app from inside its sandbox would not be a straightforward Node/asar workflow.

---

## 10. Attempt 3 — patched preload/local bridge

A more invasive path was explored: extract/modify Session's Electron preload and expose a small bridge to external code.

An extracted working directory was used around:

```text
/tmp/session-asar/
```

A test patch introduced a symbol along the lines of:

```text
window.getMessagingConversations
```

The patching step itself succeeded, proving the application could be inspected and altered enough to experiment.

Why this was rejected:

```text
Flatpak packaging complexity
update fragility
coupling to Electron internals
context-isolation/preload maintenance
need for a custom local communication channel
larger security/debug surface
```

Decision:

```text
ABANDONED as production architecture
```

Do not restart from this path unless all cleaner backend options disappear.

---

## 11. Working route — third-party session-cli

The successful backend boundary became `session-cli`.

Important distinction:

> `session-cli` is third-party software, not an official Session Foundation CLI.

Recorded package information:

```text
Name: session-cli
Version: 1.7.0
Homepage/project: github.com/amanverasia/session-cli
```

Dedicated virtual environment:

```text
/var/home/mapple/.local/share/session-cli-venv/
```

Executable:

```text
/var/home/mapple/.local/share/session-cli-venv/bin/session-cli
```

The executable launches the `session_controller.cli` Python package from that venv.

This became the preferred boundary because it already understands Session's local encrypted data and exposes JSON suitable for QML process parsing.

---

## 12. Python environment discovery

A system-Python import attempt produced:

```text
ModuleNotFoundError: No module named 'session_controller'
```

That was not a missing package in the venv; it was simply the wrong interpreter.

When inspecting the helper, use:

```bash
~/.local/share/session-cli-venv/bin/python3
```

or inspect the venv site-packages directly.

---

## 13. Conversation listing succeeded

Basic command:

```bash
CLI="$HOME/.local/share/session-cli-venv/bin/session-cli"
"$CLI" --json list
```

This returned real Session conversations.

The real conversation `Noiva` was repeatedly used as the integration/test target.

This proved the first important chain:

```text
Session local data → session-cli → JSON → external consumer
```

without our own SQLCipher implementation.

---

## 14. Message history succeeded

Representative command:

```bash
CLI="$HOME/.local/share/session-cli-venv/bin/session-cli"
CONVO_ID="..."
"$CLI" --json messages "$CONVO_ID" --limit 20
```

Actual historical messages were returned with both:

```text
incoming
outgoing
```

and timestamps.

This became the basis for the ChatFeed direction model.

---

## 15. Watch command was explored

`session-cli` also supports:

```bash
session-cli watch --convo <conversation-id>
```

with options including:

```text
--interval
--save-media
--media-dir
```

A live watch was run against the Noiva conversation and stopped manually.

We ultimately chose simple bounded polling commands from `SessionAdapter.qml` instead of maintaining a long-running streaming subprocess. It is easier to reason about and recover while the architecture is still changing.

---

## 16. Session data model discovered

Inspection of `session_controller` showed that conversation records can include concepts such as:

```text
id
type
active_at
displayNameInProfile
nickname
lastMessage
unreadCount
members
groupAdmins
avatarInProfile
approval-related fields
```

Message records can include:

```text
id
conversation_id
source
body
sent_at / timestamp
received_at
type
direction
attachments
quote
raw
```

Not every field is currently exposed to the UI. The adapter should normalize only what the generic components need.

---

## 17. Message ordering

Backend/query results tend to be newest-first, while a chat display wants:

```text
oldest
  ↓
newer
  ↓
newest
```

The Session adapter normalizes into oldest-to-newest display order.

This is an adapter responsibility. ChatFeed should not contain Session-specific sorting logic.

---

## 18. Sending required a different mechanism

Reading local data was not enough to send.

Sending through the current `session-cli` path depends on a live Session Desktop instance reachable over Chrome DevTools Protocol.

Launch command:

```bash
flatpak run network.loki.Session \
  --remote-debugging-port=9222 \
  --remote-allow-origins="*"
```

The package inspection aligned with localhost/port `9222` as the expected connection path.

Operational rule:

```text
READ: can work from local data without CDP-enabled Session UI
SEND: requires Session Desktop launched with CDP flags
```

This explains a confusing possible failure mode:

```text
contacts/messages load correctly
but send fails
```

Before changing QML, verify how Session Desktop was launched.

---

## 19. Real sends succeeded

A real CLI send to the test conversation succeeded.

Then the same route was connected to the Quickshell composer.

Working send chain:

```text
ChatFeed input
    ↓
sendRequested(conversationId, text)
    ↓
MessagingW
    ↓
SessionAdapter.sendMessage(...)
    ↓
session-cli
    ↓
Session Desktop CDP
    ↓
Session network
```

After success, adapter state updates and message/conversation refreshes bring the new message into the UI.

---

## 20. SessionAdapter responsibilities

`SessionAdapter.qml` keeps all Session-specific execution out of the reusable components.

Core responsibilities:

```text
refresh conversations
parse JSON
load selected conversation messages
normalize message direction/order
expose loading/error state
send messages
expose send state
refresh after send
```

Important send state:

```qml
property bool sending: false
property string sendError: ""
property int sendSuccessSerial: 0
signal messageSent()
```

Current polling intervals:

```text
conversations: every 5 seconds
messages: every 3 seconds
```

---

## 21. Why sendSuccessSerial exists

The composer should not clear its text merely because a send was attempted.

Before send:

```qml
pendingSendSerial = sendSuccessSerial;
sendRequested(conversation.id, text);
```

After the adapter confirms success by incrementing its serial:

```qml
if (
    pendingSendSerial >= 0
    && sendSuccessSerial > pendingSendSerial
) {
    messageInput.clear();
    pendingSendSerial = -1;
    messageInput.forceActiveFocus();
}
```

Benefits:

```text
failed send preserves typed text
success is explicit
backend remains decoupled from TextInput object
future adapters can use same contract
```

---

# Part II — Reusable messaging widget

## 22. Component responsibilities

### MessagingW.qml

Controller/window layer:

```text
owns PanelWindow
owns adapters
owns focusZone
maps selected app to backend
wires conversations/messages/send state
contains child components
owns window lifecycle workaround
owns Wayland layer choice
```

### AppSelector.qml

```text
displays services
tracks selected app
keyboard/mouse app selection
Power-like interaction states
Clock/workspace-like broad glow
```

### ContactList.qml

```text
displays normalized conversations
owns selectedIndex + selectedConversation
wraparound keyboard selection
hover visual-only
mouse select without auto-composer activation
```

### ChatFeed.qml

```text
displays normalized messages
incoming/outgoing visuals
loading/error/empty states
composer
sendRequested signal
confirmed-send clearing
```

### Sessions.qml

```text
small launcher/HUD button
opens/closes messaging window
no Session backend implementation
```

---

## 23. Shared focus-zone state machine

State:

```qml
property int focusZone: 0
readonly property int appZone: 0
readonly property int contactZone: 1
readonly property int chatZone: 2
```

Flow:

```text
APP SELECTOR
  Up/Down = choose app
  Enter/Return/Right = contacts if available
  Escape = close menu

CONTACT LIST
  Up/Down = choose contact
  Enter/Return/Right = accept contact and focus composer
  Left/Escape = AppSelector

COMPOSER
  normal text editing
  Enter/Return = send
  Escape = ContactList
```

An older idea used Left Arrow from the composer to return to contacts. The latest authoritative ChatFeed does not implement that, so Left remains normal text-cursor movement unless deliberately changed later.

---

## 24. Focus helper functions

The parent controller centralizes transitions:

```qml
function focusAppSelector() {
    focusZone = appZone;
    appSelector.keyboardActive = true;
    keyboardFocus.forceActiveFocus();
}

function focusContacts() {
    if (contactList.conversations.length === 0)
        return;

    focusZone = contactZone;
    contactList.keyboardActive = true;
    contactList.ensureValidIndex();
    keyboardFocus.forceActiveFocus();
}

function focusComposer() {
    if (!contactList.selectedConversation)
        return;

    focusZone = chatZone;
    chatFeed.focusMessageInput();
}

function acceptSelectedApp() {
    if (contactList.conversations.length > 0)
        focusContacts();
}

function activateCurrentContact() {
    if (!contactList.activateCurrent())
        return;

    focusComposer();
}

function returnToContacts() {
    if (contactList.conversations.length === 0) {
        focusAppSelector();
        return;
    }

    focusZone = contactZone;
    contactList.keyboardActive = true;
    contactList.ensureValidIndex();
    keyboardFocus.forceActiveFocus();
}
```

---

## 25. Current backend selection

Today the architecture is intentionally simple:

```text
AppSelector index 0 = Session
AppSelector index 1 = Discord, empty for now
AppSelector index 2 = Telegram, empty for now
```

Contacts:

```qml
conversations:
    appSelector.selectedIndex === 0
    ? sessionAdapter.conversations
    : []
```

Messages and state use the same pattern.

This was a good choice while proving one real backend. Once Discord is implemented, these repeated ternaries should be centralized behind `currentAdapter` or a backend registry.

---

## 26. AppSelector accepted behavior

State:

```qml
property int selectedIndex: 0
property bool keyboardActive: false
```

Apps:

```text
SESSIONS
DISCORD
TELEGRAM
```

Accepted geometry:

```text
selector region: 110 px
visible app buttons: 70 px
```

The extra root width gives glow room near the PanelWindow boundary.

Mouse/keyboard arbitration:

```qml
isHovered:
    !keyboardActive
    && mouse.containsMouse
```

Mouse entry returns control to the mouse. Keyboard movement sets `keyboardActive = true`.

Unlike ContactList, AppSelector hover may change the selected app.

---

## 27. AppSelector visuals

```text
idle:
  background deep purple
  text cyan

hover:
  background yellow
  text orange
  orange glow

selected:
  background yellow
  text orange
  orange glow

pressed:
  background magenta
  text black
  magenta glow
```

Broad `RectangularShadow` layers around spread `3` and `10` were accepted and should not be replaced with a single small Power shadow without a reason.

Final Session-section polish requested:

```text
use existing assets/Sessions.png beside SESSIONS
```

A small icon around 14×14 was proposed so it fits the 70 px button.

---

## 28. ContactList state and helpers

Public state:

```qml
property var conversations: []
property var selectedConversation: null
property int selectedIndex: -1
property bool keyboardActive: false
property bool keyboardFocused: false
signal contactClicked
```

Helpers:

```text
clearSelection()
ensureValidIndex()
selectIndex(index)
moveSelection(direction)
activateCurrent()
```

The move helper wraps at the ends.

---

## 29. ContactList header

Accepted wording:

```text
CONTACTS
CONVERSATION(S): 1
```

The literal `CONVERSATION(S):` is intentional; do not dynamically singularize/pluralize it unless the user asks.

Visual details:

```text
header height ~70
Colors.dark
square corners
CONTACTS in cyan + glow
CONVERSATION(S): in pale white at lower opacity
count in orange + glow
2 px cyan separator + glow
outer list border retained
```

The outer border was kept because otherwise the adjacent menu regions blended together too much.

---

## 30. Contact hover versus selection

This became an explicit semantic rule.

Delegate state:

```qml
property bool isSelected:
    contactRoot.selectedIndex === index

property bool isHovered:
    !contactRoot.keyboardActive
    && contactMouse.containsMouse

property bool isPressed:
    contactMouse.pressed
```

Hover changes appearance only.

Mouse entry:

```qml
contactRoot.keyboardActive = false;
```

It does not update `selectedIndex`.

Left click:

```qml
contactRoot.selectIndex(contactButton.index);
contactRoot.contactClicked();
```

This selects the conversation but does not automatically jump into the composer.

Keyboard Enter/Right is what performs the explicit activate-and-enter transition.

---

## 31. Contact selected visual persists after entering chat

Final intended contact state:

```text
selected background = yellow
selected name       = orange
selected preview    = orange
selected border     = orange
selected glow       = orange
```

This persists even when the composer has keyboard focus.

An older condition tied orange border/glow to `keyboardFocused` and changed a selected contact to cyan outside the contact zone. That is obsolete.

Persistent selection and active keyboard focus are different concepts.

---

## 32. Latest ChatFeed structure

Latest fully uploaded ChatFeed:

```text
root: transparent
background: Colors.black at opacity 0.75
header: 60 px Colors.dark
message viewport: transparent
full outer frame: 1 px cyan
```

The transparent root and viewport preserve the intended translucent surface.

---

## 33. Header avatar evolution

A generic social/contact icon was added beside the contact name.

First concept:

```text
square icon containing ጸ
```

Problems:

```text
looked too bright
configured font could fail to render the glyph
```

Final uploaded fallback:

```text
32 × 32
square
transparent fill
1 px cyan border at ~0.65 opacity
very faint cyan glow ~0.15
@ glyph
Gohu/Nerd font
cyan at ~0.85 opacity
```

The `@` glyph is safer and still reads as an account/social placeholder.

---

## 34. Message feed

Visibility requires:

```text
conversation exists
messages exist
no message-load error
```

Messages use:

```qml
property bool outgoing:
    modelData.direction === "outgoing"
```

Bubbles:

```text
Colors.dark
radius 0
max ~72% of feed
incoming = cyan border/text
outgoing = orange border/text
```

Two subtle `RectangularShadow` layers give depth without overpowering the content.

The list moves to the end as count changes.

---

## 35. Chat states

No selected conversation:

```text
SELECT A CONTACT
cyan
```

Loading:

```text
LOADING...
orange
```

Errors:

```text
red
centered/wrapped
```

Send error appears above the composer.

---

## 36. Composer

Current design:

```text
height 54
16 px left/right/bottom margins
visible only with conversation
Colors.dark
radius 0
focused border orange
otherwise cyan
close + wide RectangularShadow
```

TextInput:

```text
disabled while sending
selection = orange
selected text = black
font = GohuFont 11 Nerd Font Mono
Enter/Return = send
Escape = return to contacts
```

Placeholder:

```text
MESSAGE...
cyan at reduced opacity
```

Final requested typed-text color:

```qml
color:
    enabled
    ? Colors.magenta
    : Colors.cyan
```

The latest complete upload still showed white enabled text, so verify this final tweak in the actual working tree.

---

## 37. Send button

Enabled when:

```qml
!chatFeed.sending
&& messageInput.text.trim() !== ""
```

State:

```text
pressed: magenta background + black text
hovered: yellow background + orange text/glow
sendable: orange emphasis
not sendable: dark/cyan
```

Label:

```text
SEND
SENDING
```

---

# Part III — Native Quickshell issues and fixes

## 38. Earlier duplicate/lifecycle problem

An earlier Sway startup line was bad:

```bash
exec_always quickshell >/dev/null 2>&1 && quickshell || quickshell
```

It was replaced by:

```bash
exec_always sh -c 'pkill -x quickshell; quickshell >/tmp/quickshell.log 2>&1 &'
```

This fixed one earlier duplicate/process-lifecycle issue.

Later, similar repeated-click symptoms appeared again, but `pgrep` showed only one Quickshell process. That later crash had a different root cause.

---

## 39. Native repeated-click crash

Repeatedly opening/closing the messaging menu could kill Quickshell after a few clicks.

Environment captured in coredumps:

```text
Quickshell 0.2.1^git20260209.dacfa9d-5.fc44
Qt 6.11.2
SIGSEGV
```

Important stack path:

```text
QQuickItem::isUnderMouse
QQuickMouseArea::itemChange
QQuickItemPrivate::itemChange
QQuickItemPrivate::setEffectiveVisibleRecur
QQuickItem::setParentItem
ProxyWindowBase::completeWindow
ProxyWindowBase::createWindow
ProxyWindowBase::setVisibleDirect
...
QQuickMouseArea::clicked
```

This was decisive evidence that the crash happened during click-triggered native window visibility/creation/reparenting.

It was not caused by:

```text
Session backend
contact border
message bubble style
glow color
```

---

## 40. First crash workaround failed

The launcher toggle was delayed with `Qt.callLater`.

That did not stop the crash because the root `PanelWindow.visible` state still changed and could still enter the native window creation path.

The deferred guarded toggle is still fine to keep, but it is not the fundamental fix.

---

## 41. Successful crash workaround

Keep the root window alive permanently:

```qml
visible: true
focusable: menuOpen
```

Hide only the inner content:

```qml
Item {
    id: messagingContent
    anchors.fill: parent
    visible: messagingWindow.menuOpen
}
```

Collapse the input mask when closed:

```qml
mask: Region {
    x: 0
    y: 0

    width:
        messagingWindow.menuOpen
        ? messagingWindow.width
        : 0

    height:
        messagingWindow.menuOpen
        ? messagingWindow.height
        : 0
}
```

This avoids recreating the native surface on each click.

**Do not restore root `visible: menuOpen`.**

---

## 42. MessagingW accepted geometry

Current intended root geometry:

```text
implicitWidth: 900
implicitHeight: 1355
anchor bottom/right
bottom margin: 80
right margin: 10
exclusiveZone: 0
transparent surface
```

Columns:

```text
AppSelector: 110
ContactList: 200
ChatFeed: remaining width
```

The contact-list width was deliberately changed down from older 280-ish variants.

---

## 43. Power overlap was stacking, not placement

A screenshot showed the Power button on top of the messaging surface.

An initial attempt suggested moving the messaging panel upward. The user correctly identified that the geometry was fine and the problem was stacking.

Important concept:

```text
QML child z values do not reorder separate native PanelWindows.
```

Final fix:

```qml
import Quickshell.Wayland
```

and inside `PanelWindow`:

```qml
WlrLayershell.layer: WlrLayer.Overlay
```

The user confirmed this fix was correct.

The bottom margin remains `80`; the temporary suggestion of `150` is not canonical.

---

## 44. Invalid intermediate overlay edit

One uploaded intermediate `MessagingW.qml` accidentally contained:

```qml
import QtQuick
import Quickshell
...
WlrLayershell.layer: WlrLayer.Overlay
import Qt5Compat.GraphicalEffects
```

That is invalid because an attached property cannot sit among imports, and `Quickshell.Wayland` was missing.

Correct final header:

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../components"
import "../../services/messaging"
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: messagingWindow

    WlrLayershell.layer: WlrLayer.Overlay
```

---

## 45. Sessions launcher

`modules/Sessions.qml` is the clickable HUD element opening the messaging panel.

It uses the existing:

```text
assets/Sessions.png
```

with Omnitrix-green visual treatment.

During crash debugging, its direct toggle became a guarded deferred toggle:

```qml
Qt.callLater(function() {
    if (!sessionsDock.messagingWindow)
        return;

    sessionsDock.messagingWindow.menuOpen =
        !sessionsDock.messagingWindow.menuOpen;
});
```

Keep this for now.

Right-click is currently only a placeholder/alternate-action slot.

---

## 46. Bad imports found in Sessions.qml

Historical stale imports included paths equivalent to:

```qml
import "modules"
import "../../messanger"
```

from a location where they resolved incorrectly.

Quickshell emitted unresolvable import warnings.

They were cleanup issues but not the native SIGSEGV root cause.

---

## 47. Other warnings seen in logs

Separate cleanup items included:

```text
Network.qml: Cannot anchor to an item that isn't a parent or sibling.
Workspaces.qml: Cannot read property 'length' of undefined.
Network.qml: undefined values assigned to typed properties.
ShaderEffect warnings.
```

These are worth fixing later but were not supported by the coredump as the messaging crash trigger.

---

## 48. Normal QML editing failures encountered

During rapid rebuilds we also hit ordinary errors such as:

```text
Unexpected token
Incomplete binding
PanelWindow is not a type/unavailable
Invalid alias reference
Colors ReferenceError
menu ReferenceError
module "widgets" is not installed
```

These were development states, not architectural failures.

Useful direct debug command:

```bash
quickshell -vv -p ~/.config/quickshell/shell.qml
```

Fix the first concrete parser/runtime error before chasing secondary warnings.

---

## 49. Shell/editor gotchas

### zsh history expansion

Pasting QML with expressions such as:

```qml
!keyboardActive
```

through an unquoted shell heredoc produced:

```text
zsh: event not found
```

Safe replacement form:

```bash
cat > file.qml <<'EOF'
...
EOF
```

### grep wrapper

The user's interactive `grep` could resolve to ripgrep behavior, causing GNU grep options such as `-R` to fail.

Use:

```bash
/usr/bin/grep
```

when exact GNU behavior matters.

### terminal clipping

Long lines can be visually clipped by Zellij/terminal width. Do not assume visible truncation means file corruption.

---

# Part IV — Current accepted state and future plan

## 50. What is working now

At the Session stopping point:

```text
[working] launcher opens/closes messaging surface
[working] repeated open/close with root-window workaround
[working] messaging stacks over Power with Overlay layer
[working] AppSelector and keyboard navigation
[working] real Session conversations
[working] ContactList mouse/keyboard behavior
[working] real Session message history
[working] incoming/outgoing message styling
[working] selected contact → message load
[working] composer focus flow
[working] real message send from Quickshell
[working] send errors/sending state
[working] confirmed-success composer clearing
[working] message refresh after send
[working] header default avatar
[working] Escape navigation back through zones
```

Final visual polish requested immediately before declaring Session basically done:

```text
Session icon in AppSelector
magenta typed composer text
```

Verify those two final edits exist locally.

---

## 51. Current limitations

### Sending requires CDP-enabled Session Desktop

Reads and send do not have identical runtime requirements.

### Polling

Current Session updates are timer-based rather than event-driven.

### Hard-coded index routing

`selectedIndex === 0` appears repeatedly for Session.

### Rich message features

Attachments/replies/reactions are not yet generalized in ChatFeed.

### Placeholder right-click behavior

Contact and launcher right-click actions are not finished.

---

## 52. Future adapter contract

Every messaging backend should converge on something like:

```qml
property string backendId
property string displayName

property var conversations: []
property var messages: []

property bool conversationsLoading: false
property string conversationsError: ""

property bool messagesLoading: false
property string messagesError: ""

property bool sending: false
property string sendError: ""
property int sendSuccessSerial: 0

signal messageSent()

function refreshConversations()
function loadMessages(conversationId)
function sendMessage(conversationId, text)
```

The specific implementation can differ internally.

---

## 53. Recommended normalized conversation

```js
{
    id: "...",
    backend: "session",
    displayName: "Visible Name",
    nickname: "",
    lastMessage: "",
    unreadCount: 0,
    avatar: ""
}
```

Session's current `displayNameInProfile` can be normalized into `displayName` later while preserving compatibility during transition.

---

## 54. Recommended normalized message

```js
{
    id: "...",
    backend: "session",
    conversationId: "...",
    body: "...",
    direction: "incoming",  // or outgoing
    timestamp: 0,
    senderId: "",
    senderName: "",
    attachments: []
}
```

The critical contract for current ChatFeed is still `body` + `direction`.

---

## 55. Discord next

Correct sequence for the next session:

```text
1. investigate a maintainable Discord interface outside QML
2. prove conversation/channel listing
3. prove message reading
4. prove sending
5. define DiscordAdapter.qml
6. normalize Discord objects into existing conversation/message shapes
7. introduce currentAdapter/backend registry
8. reuse ContactList and ChatFeed unchanged as much as possible
9. test error/auth/reconnect cases
10. then add Discord icon/visual polish
```

Do not begin by cloning ChatFeed for Discord.

---

## 56. Future services

The same pattern should support:

```text
Telegram
Signal
other messaging programs with a maintainable API/helper/IPC path
```

Each service may use a different internal technique:

```text
Session → CLI + local DB reading + CDP send
Discord → API/helper/event connection, to be researched
Telegram → API/helper, to be researched
Signal → helper/CLI/API path, to be researched
```

The frontend contract should remain stable.

---

## 57. Important no-regression list

```text
DO NOT rename widgets/messanger/ casually.
DO NOT use Colors.background.
DO NOT assume Colors.black means #000000.
DO NOT let contact hover alter selectedConversation.
DO NOT auto-focus composer on a simple contact mouse click.
DO NOT make selected contact cyan when composer owns focus.
DO NOT restore root MessagingW visible: menuOpen.
DO NOT remove the closed-window zero input mask.
DO NOT solve separate PanelWindow stacking with child z values.
DO NOT remove Quickshell.Wayland / WlrLayer.Overlay from MessagingW.
DO NOT assume Session CDP is required for reads.
DO NOT describe session-cli as official Session software.
DO NOT rebuild the UI per messenger.
DO NOT silently re-add Left-arrow composer navigation.
DO NOT re-open the SQLCipher/preload routes without a new reason.
```

---

# Appendix A — Current backend wiring

```qml
ContactList {
    conversations:
        appSelector.selectedIndex === 0
        ? sessionAdapter.conversations
        : []

    onSelectedConversationChanged: {
        if (
            appSelector.selectedIndex === 0
            && selectedConversation
        ) {
            sessionAdapter.loadMessages(
                selectedConversation.id
            );
        }
    }
}
```

```qml
ChatFeed {
    conversation:
        appSelector.selectedIndex === 0
        ? contactList.selectedConversation
        : null

    messages:
        appSelector.selectedIndex === 0
        ? sessionAdapter.messages
        : []

    loading:
        appSelector.selectedIndex === 0
        ? sessionAdapter.messagesLoading
        : false

    error:
        appSelector.selectedIndex === 0
        ? sessionAdapter.messagesError
        : ""

    sending:
        appSelector.selectedIndex === 0
        ? sessionAdapter.sending
        : false

    sendError:
        appSelector.selectedIndex === 0
        ? sessionAdapter.sendError
        : ""

    sendSuccessSerial:
        appSelector.selectedIndex === 0
        ? sessionAdapter.sendSuccessSerial
        : 0

    onSendRequested: function(conversationId, text) {
        if (appSelector.selectedIndex === 0) {
            sessionAdapter.sendMessage(
                conversationId,
                text
            );
        }
    }
}
```

---

# Appendix B — Compressed chronology

```text
01. Decide to build reusable multi-service messaging surface.
02. Split UI into AppSelector / ContactList / ChatFeed / MessagingW.
03. Investigate Session local storage and SQLCipher.
04. Hit manual decryption/HMAC problems.
05. Inspect Session Flatpak/Electron files.
06. Explore app.asar/preload modification.
07. Add experimental preload bridge marker.
08. Reject patched-client architecture as fragile.
09. Install/inspect third-party session-cli.
10. Confirm real conversation listing.
11. Confirm real message history and incoming/outgoing direction.
12. Explore CLI watch mode.
13. Inspect session_controller models/queries.
14. Discover CDP requirement for sending.
15. Launch Session with remote-debugging port 9222.
16. Confirm real CLI send.
17. Create/wire SessionAdapter.
18. Poll conversations every 5 s and messages every 3 s.
19. Normalize messages oldest→newest.
20. Wire ContactList to Session conversations.
21. Wire ChatFeed to Session messages.
22. Add composer and send signal.
23. Add sendSuccessSerial so failed sends retain input.
24. Build three-zone keyboard navigation.
25. Refine mouse vs keyboard selection semantics.
26. Make contact hover visual-only.
27. Make selected contact stay orange after composer focus.
28. Refine CONTACTS / CONVERSATION(S): header.
29. Refine translucent ChatFeed and message bubbles.
30. Add generic square contact icon.
31. Replace unreliable ጸ glyph with @ and reduce brightness.
32. Investigate repeated click crash.
33. Rule out duplicate Quickshell process for later crash.
34. Read native coredump showing ProxyWindowBase create/visibility path.
35. Try Qt.callLater-only toggle; still crashes.
36. Keep root PanelWindow permanently visible.
37. Hide child content and collapse input mask when closed.
38. See Power window stack over messaging.
39. User identifies stacking rather than placement.
40. Add Quickshell.Wayland + WlrLayer.Overlay correctly.
41. User confirms overlay fix.
42. Request Session icon in AppSelector.
43. Request magenta typed composer text.
44. Declare Session section essentially done.
45. Plan Discord next.
```

---

# Appendix C — Operational commands

Session CLI:

```bash
CLI="$HOME/.local/share/session-cli-venv/bin/session-cli"
"$CLI" --json list
"$CLI" --json messages "$CONVO_ID" --limit 20
"$CLI" watch --convo "$CONVO_ID"
```

Session Desktop for sending:

```bash
flatpak run network.loki.Session \
  --remote-debugging-port=9222 \
  --remote-allow-origins="*"
```

Quickshell debugging:

```bash
pgrep -x -a quickshell
quickshell -vv -p ~/.config/quickshell/shell.qml
```

Sway startup baseline:

```bash
exec_always sh -c 'pkill -x quickshell; quickshell >/tmp/quickshell.log 2>&1 &'
```

Reliable grep:

```bash
/usr/bin/grep
```

Safe QML heredoc:

```bash
cat > target.qml <<'EOF'
# QML goes here; zsh will not expand ! expressions.
EOF
```

---

## Final takeaway

Session did more than become the first working messenger. It established the architecture for the entire future messaging widget:

```text
backend-specific complexity behind adapters
reusable normalized frontend
central navigation state
persistent selection semantics
confirmed send state
crash-aware native window lifecycle
Wayland-aware surface stacking
existing rice visual language reused consistently
```

That is the baseline to protect while implementing Discord.


<!-- ===== END 00_MASTER_COMPLETE_HISTORY.md ===== -->

<!-- ===== BEGIN 01_SESSION_INTEGRATION_DEEP_DIVE.md ===== -->

# Session Integration Deep Dive

**Purpose:** preserve every important Session-specific discovery, failed route, successful route, command, assumption, and lesson from the integration work.

---

## 1. Final Session architecture

The working design is:

```text
Session local data
      │
      │ read
      ▼
third-party session-cli
      │
      ├───────────────┐
      │               │
      │ send          │ list/messages
      ▼               │
Session Desktop       │
CDP on localhost      │
port 9222             │
      │               │
      └───────┬───────┘
              ▼
      SessionAdapter.qml
              │
        normalized state
              │
      ┌───────┴────────┐
      ▼                ▼
 ContactList.qml   ChatFeed.qml
```

The core decision was to keep Session-specific mechanics behind one adapter/helper boundary rather than make QML understand Session's encrypted storage or Electron internals.

---

## 2. Installed Session environment

Flatpak application id:

```text
network.loki.Session
```

Recorded desktop version during the work:

```text
1.18.1
```

The relevant user data/config tree is:

```text
~/.var/app/network.loki.Session/config/Session/
```

Session Desktop is an Electron application. The installed Flatpak contained paths such as:

```text
/app/Session/
/app/Session/session-desktop
/app/Session/resources/
/app/Session/resources/app.asar
/app/Session/resources/app.asar.unpacked/
```

The inspected `app.asar` was approximately 125 MB.

The unpacked resources included a Signal SQLCipher native module, confirming that encrypted local storage was a meaningful part of the app's data stack.

---

## 3. Initial IPC/service discovery

Before committing to database or Electron reverse engineering, the environment was checked for an obvious Session-specific user service/DBus interface.

Commands around `busctl --user` and process inspection showed the expected Flatpak/session infrastructure but no obvious convenient Session messaging API that Quickshell could simply consume.

That made these routes the main candidates:

```text
A. direct local database
B. Session/Electron internal bridge
C. external helper/CLI
```

---

## 4. Attempt A — direct SQLCipher database access

### Goal

Open Session's local encrypted database ourselves and query conversations/messages directly.

### Why it was attractive

```text
no dependency on a running Session GUI
very fast local reads
potentially easy QML polling
full control over fields and queries
```

### What we learned

Session's local storage contains sufficient data for the desired UI. Database/package inspection exposed concepts corresponding to conversations, messages, timestamps, direction, profile names, previews, unread counts, members, and other metadata.

The app ships SQLCipher-related native functionality, and the later successful `session-cli` package also depends on `sqlcipher3`, reinforcing that encrypted SQLite/SQLCipher access is the underlying read mechanism.

### What failed

Our own attempts to open/decrypt the database did not produce a stable usable connection. We ran into encryption/HMAC/decryption failures while trying to reproduce the expected SQLCipher parameters/key handling.

The important conclusion was not merely “one command failed.” The larger problem was architectural:

```text
If we own Session's database decryption, every Session storage change becomes our problem.
```

Even a successful reverse-engineered key path would leave the Quickshell rice tightly coupled to Session's internal encrypted data format.

### Decision

```text
ABANDONED as the primary integration route.
```

### Rule for the future

Do not restart manual SQLCipher work merely because the local DB looks tempting. Only reconsider it if the helper path becomes impossible and there is a clear reason to accept the maintenance burden.

---

## 5. Attempt B — inspect Session's Flatpak and Electron resources

We entered the Session Flatpak shell and inspected its app directory.

Representative approach:

```bash
flatpak run --command=sh network.loki.Session
```

This confirmed the Electron application layout and let us inspect packaged resources.

### Tool availability inside the sandbox

Observed during the investigation:

```text
python3  /usr/bin/python3
node     not found
npm      not found
npx      not found
7z       not found
bsdtar   available
tar       available
unzip     available
```

This mattered because standard Electron/asar development assumptions did not hold inside the Flatpak runtime.

### Resource checks

Host-side paths such as `/app/Session/...` naturally failed when checked outside the Flatpak namespace, while the same paths were visible from a Flatpak shell. This reinforced the need to keep host/sandbox path contexts straight during debugging.

---

## 6. Attempt C — app.asar/preload bridge experiment

### Goal

Use Session's own running Electron application as the integration point by exposing a small custom JavaScript bridge.

### Work performed

Resources were extracted/copied into a temporary working area around:

```text
/tmp/session-asar/
```

A preload file was modified to add a marker/function along the lines of:

```text
window.getMessagingConversations
```

The patching operation reported success, demonstrating that an internal bridge was technically possible to experiment with.

### Why it was tempting

A preload bridge could theoretically provide:

```text
live application state
conversation access
message access
send actions
possibly less custom SQLCipher handling
```

### Why it was rejected

The path was too fragile for a desktop rice integration:

```text
Session updates could overwrite or invalidate the patch
internal preload APIs can change
Flatpak packaging complicates deployment
context isolation/security boundaries add complexity
we would need a stable local IPC/HTTP surface of our own
we would effectively maintain a forked/modified desktop client
```

### Decision

```text
ABANDONED.
```

The bridge experiment was useful research but not a maintainable production boundary.

---

## 7. Discovery of third-party session-cli

The successful route was a dedicated helper already built to understand Session's data.

Installed package information recorded during inspection:

```text
Name: session-cli
Version: 1.7.0
Summary: Python CLI/library for programmatic Session control
Project/homepage: github.com/amanverasia/session-cli
```

The package was isolated in:

```text
/var/home/mapple/.local/share/session-cli-venv/
```

Executable:

```text
/var/home/mapple/.local/share/session-cli-venv/bin/session-cli
```

Its launcher points to the venv Python and imports:

```python
from session_controller.cli import main
```

Package dependencies observed included SQLCipher and websocket-related libraries.

### Important trust/wording note

`session-cli` is **not official Session Foundation software**. It is a third-party integration dependency. Documentation and future code comments should be honest about that distinction.

---

## 8. Wrong-interpreter debugging detour

We tried importing `session_controller` with the normal system Python and got:

```text
ModuleNotFoundError: No module named 'session_controller'
```

This was because the package lived in the dedicated venv.

Correct inspection pattern:

```bash
"$HOME/.local/share/session-cli-venv/bin/python3" - <<'PY'
import session_controller
from pathlib import Path
print(Path(session_controller.__file__).resolve().parent)
PY
```

Lesson:

```text
When inspecting helper internals, use the helper's interpreter.
```

---

## 9. grep/ripgrep debugging detour

During package inspection, a recursive command written for GNU grep failed with:

```text
rg: unrecognized flag -R
```

because interactive `grep` behavior was wrapped/aliased to ripgrep.

Reliable approach:

```bash
/usr/bin/grep -RniE ...
```

This is preserved because it affected Session package investigation repeatedly.

---

## 10. First successful conversation read

Define the helper:

```bash
CLI="$HOME/.local/share/session-cli-venv/bin/session-cli"
```

List conversations:

```bash
"$CLI" --json list
```

This returned actual Session conversation objects.

The conversation/contact `Noiva` was used as the main real-world test target.

This was a major milestone because it proved:

```text
we did not need to solve SQLCipher ourselves to get reliable read access
```

---

## 11. Message history read

Representative command:

```bash
CONVO_ID="..."
"$CLI" --json messages "$CONVO_ID" --limit 20
```

The returned history contained both incoming and outgoing messages and usable timestamps.

A small Python print test demonstrated message rows such as:

```text
2026-09-08 ... | incoming
2026-09-08 ... | outgoing
```

This gave the UI the exact distinction it needed for bubble styling/alignment.

---

## 12. session-cli watch mode

The CLI help showed a watch interface:

```text
session-cli watch [-h] [--convo CONVO]
                  [--interval INTERVAL]
                  [--save-media]
                  [--media-dir MEDIA_DIR]
```

A watch was run for the real test conversation:

```bash
"$CLI" watch --convo "$CONVO_ID"
```

The process reported that it was watching for new messages and was later stopped with Ctrl+C.

### Why the final adapter did not use watch

A long-running streaming child process introduces lifecycle/parsing/restart complexity. For the first implementation, bounded periodic commands were simpler and robust enough.

Current choice:

```text
QML-side periodic refresh via SessionAdapter processes/timers
```

Future optimization can revisit event/watch streams if necessary.

---

## 13. What session_controller revealed about conversations

Inspection of the installed helper package exposed richer conversation data than the first UI uses.

Observed/useful concepts included:

```text
id
type
active_at
displayNameInProfile
nickname
lastMessage
unreadCount
members
groupAdmins
avatarInProfile
approval-related state
```

Current UI naming preference is roughly:

```text
displayNameInProfile
    fallback → nickname
    fallback → id
```

For future multi-backend work, SessionAdapter should eventually normalize this into a generic `displayName` so ChatFeed/ContactList stop knowing Session-specific field names.

---

## 14. What session_controller revealed about messages

Observed/useful concepts included:

```text
id
conversation_id
source
body
sent_at / timestamp
received_at
type
direction
attachments
quote
raw
```

For the current feed, the minimum practical contract is:

```js
{
    id: "...",
    body: "...",
    direction: "incoming" | "outgoing",
    timestamp: 0
}
```

The richer data should stay available to the adapter for future attachments/replies without making the first ChatFeed complicated.

---

## 15. Chronological normalization

The CLI/database query path often presents recent messages first.

A chat feed expects:

```text
oldest → newest
```

`SessionAdapter.qml` therefore normalizes/reverses/sorts messages before exposing them to ChatFeed.

This decision should become part of the generic adapter contract so every backend hands ChatFeed the same ordering.

---

## 16. Sending was a separate problem from reading

Reading works from local Session data through `session-cli`.

Sending requires interaction with a running Session Desktop application.

The route that worked uses Chrome DevTools Protocol.

Session Desktop launch command:

```bash
flatpak run network.loki.Session \
  --remote-debugging-port=9222 \
  --remote-allow-origins="*"
```

The helper package inspection aligned with:

```text
host: localhost
port: 9222
```

### Crucial diagnostic distinction

```text
If contacts/messages work but send does not:
check CDP launch before rewriting SessionAdapter.
```

A normally launched Session Desktop may leave the interface in a half-working state where reads succeed but send fails.

---

## 17. Successful send outside Quickshell

Before trusting the QML layer, a real message send was proven through the helper route.

That established:

```text
session-cli → Session Desktop CDP → real Session send
```

Only after this proof was the send path wired into ChatFeed/SessionAdapter.

This is an important methodology to repeat for Discord: prove the backend outside QML first.

---

## 18. Successful send from Quickshell

Final user flow:

```text
select Session
select contact
enter composer
write message
press Enter or click SEND
```

Technical flow:

```text
ChatFeed.trySend()
    ↓
sendRequested(conversation.id, text)
    ↓
MessagingW onSendRequested
    ↓
sessionAdapter.sendMessage(conversationId, text)
    ↓
session-cli send
    ↓
CDP-enabled Session Desktop
```

A real Quickshell send was confirmed.

---

## 19. SessionAdapter public state

Important current properties include the general read state plus send state.

Send contract:

```qml
property bool sending: false
property string sendError: ""
property int sendSuccessSerial: 0

signal messageSent()
```

This is intentionally easy for a generic ChatFeed to consume.

---

## 20. Conversation refresh interval

Current periodic conversation refresh:

```text
5000 ms / 5 seconds
```

This keeps previews/conversations reasonably fresh without excessive process churn.

---

## 21. Message refresh interval

Current selected-conversation refresh:

```text
3000 ms / 3 seconds
```

That produces a usable near-live chat feel without a persistent watch process.

---

## 22. Send success behavior

On successful send, the adapter should:

```text
set sending false
clear send error
increment sendSuccessSerial
emit messageSent
refresh selected messages
refresh conversations/previews
```

On failure:

```text
set sending false
populate sendError
do not increment success serial
```

---

## 23. Why the composer uses a serial handshake

ChatFeed stores:

```qml
pendingSendSerial = sendSuccessSerial;
```

before emitting its send request.

It clears only if:

```qml
sendSuccessSerial > pendingSendSerial
```

This means a failed send leaves the typed message intact.

That is better than optimistic clearing because backend failures can be caused by something as simple as Session Desktop not being launched with CDP.

---

## 24. Selected conversation message loading

Current Session-specific connection:

```qml
onSelectedConversationChanged: {
    if (
        appSelector.selectedIndex === 0
        && selectedConversation
    ) {
        sessionAdapter.loadMessages(
            selectedConversation.id
        );
    }
}
```

This is a good separation of responsibility:

```text
ContactList decides which conversation is selected.
SessionAdapter decides how its messages are acquired.
```

Future generic form:

```text
currentAdapter.loadMessages(selectedConversation.id)
```

---

## 25. Current Session-to-UI bindings

Contact list:

```qml
conversations:
    appSelector.selectedIndex === 0
    ? sessionAdapter.conversations
    : []
```

Chat conversation:

```qml
conversation:
    appSelector.selectedIndex === 0
    ? contactList.selectedConversation
    : null
```

Messages:

```qml
messages:
    appSelector.selectedIndex === 0
    ? sessionAdapter.messages
    : []
```

State:

```qml
loading:
    appSelector.selectedIndex === 0
    ? sessionAdapter.messagesLoading
    : false

error:
    appSelector.selectedIndex === 0
    ? sessionAdapter.messagesError
    : ""

sending:
    appSelector.selectedIndex === 0
    ? sessionAdapter.sending
    : false

sendError:
    appSelector.selectedIndex === 0
    ? sessionAdapter.sendError
    : ""

sendSuccessSerial:
    appSelector.selectedIndex === 0
    ? sessionAdapter.sendSuccessSerial
    : 0
```

Send:

```qml
onSendRequested: function(conversationId, text) {
    if (appSelector.selectedIndex === 0) {
        sessionAdapter.sendMessage(
            conversationId,
            text
        );
    }
}
```

---

## 26. Why Session-specific logic was not placed in ChatFeed

If ChatFeed ran `session-cli` itself, it would immediately become a Session UI rather than a messaging UI.

That would cause:

```text
backend commands mixed with layout code
future Discord duplication
backend changes risking visual regressions
harder error handling
harder testing
```

The adapter boundary was one of the most important design improvements of the whole effort.

---

## 27. Security and operational notes

CDP gives automation access to a live Electron application.

Treat it as a local integration endpoint:

```text
keep it local
avoid exposing/forwarding port 9222
avoid logging sensitive full message content unnecessarily
avoid publishing private conversation/session IDs
keep helper dependencies isolated in the venv
record known-good versions before upgrades
```

`--remote-allow-origins="*"` is being used for this local integration. It should not be interpreted as permission to expose the debugging endpoint to untrusted networks.

---

## 28. Useful commands to preserve

### Define CLI

```bash
CLI="$HOME/.local/share/session-cli-venv/bin/session-cli"
```

### List conversations

```bash
"$CLI" --json list
```

### Read messages

```bash
"$CLI" --json messages "$CONVO_ID" --limit 20
```

### Watch

```bash
"$CLI" watch --convo "$CONVO_ID"
```

### Inspect helper package correctly

```bash
"$HOME/.local/share/session-cli-venv/bin/python3" - <<'PY'
import session_controller
from pathlib import Path
print(Path(session_controller.__file__).resolve().parent)
PY
```

### Launch Session with send support

```bash
flatpak run network.loki.Session \
  --remote-debugging-port=9222 \
  --remote-allow-origins="*"
```

---

## 29. What not to repeat

### Do not assume direct SQLCipher is the simplest route

It already failed to become a stable maintainable solution.

### Do not patch preload/app.asar by default

We already explored that direction. It creates unnecessary update and sandbox coupling.

### Do not call session-cli official Session software

It is third-party.

### Do not assume send and read have the same runtime requirements

They do not in the current implementation.

### Do not clear composer text on send attempt

Wait for confirmed adapter success.

### Do not make generic QML know Session field names forever

Move toward normalized names as more adapters are added.

---

## 30. Upgrade/recovery test checklist

After a Session Desktop or helper update:

```text
[ ] session-cli --json list returns conversations
[ ] Noiva/known conversation data shape still parses
[ ] messages command returns body + direction + timestamps
[ ] incoming/outgoing strings are unchanged or remapped
[ ] message ordering is normalized oldest→newest
[ ] Session Desktop starts on localhost:9222 with CDP flags
[ ] standalone helper send works
[ ] Quickshell send works
[ ] failed send preserves composer text
[ ] successful send increments serial once
[ ] successful send clears composer once
[ ] messages refresh after send
[ ] conversation preview refreshes after send
```

---

## 31. Session completion state

By the time the Session section was declared essentially done, we had proven:

```text
real conversation listing
real message history
incoming/outgoing direction
polling refresh
selected conversation loading
real message send
send failure/success state
success-driven composer clearing
UI integration
header/avatar presentation
keyboard/mouse navigation
```

The two final visual requests were:

```text
Session icon in AppSelector using assets/Sessions.png
magenta text while typing in the composer
```

Those should be verified in the current working files because they were requested after the latest complete uploads.

---

## 32. The reusable process Session taught us

For every future service:

```text
1. research outside QML
2. prove a read path
3. prove a send path
4. reject fragile integration routes early
5. isolate backend dependencies
6. build one adapter
7. normalize data
8. wire existing UI
9. test failure state
10. add service-specific polish last
```

That process is more important than any Session-specific command and should guide the Discord work.


<!-- ===== END 01_SESSION_INTEGRATION_DEEP_DIVE.md ===== -->

<!-- ===== BEGIN 02_MESSAGING_WIDGET_ARCHITECTURE.md ===== -->

# Messaging Widget Architecture

**Scope:** structure, ownership, navigation, current QML contracts, visual-state behavior, backend boundaries, and the shape future adapters should plug into.

---

## 1. Current tree

The active directory spelling is:

```text
widgets/messanger/
```

Do not silently rename it to `messenger` while imports and generated module paths depend on the current spelling.

```text
modules/
└── Sessions.qml

widgets/messanger/
├── AppSelector.qml
├── ContactList.qml
├── ChatFeed.qml
└── MessagingW.qml

services/messaging/
└── SessionAdapter.qml
```

---

## 2. Responsibility boundaries

### `modules/Sessions.qml`

Launcher only.

```text
owns the dock/HUD button
holds a messagingWindow reference
toggles messagingWindow.menuOpen
uses assets/Sessions.png
contains no Session message parsing/send implementation
```

### `MessagingW.qml`

Controller + native window.

```text
owns PanelWindow
owns backend adapter instances
owns focusZone state machine
wires selected backend to generic child components
owns window open/close behavior
owns crash-safe visibility strategy
owns Wayland layer-shell stacking
```

### `AppSelector.qml`

Service selection.

```text
displays Session / Discord / Telegram
tracks selectedIndex
arbitrates mouse vs keyboard app selection
renders selected/hover/pressed states
```

### `ContactList.qml`

Generic conversation browser.

```text
displays conversations array
owns selectedIndex
owns selectedConversation
provides wraparound selection helpers
hover is visual only
mouse click selects without automatically entering composer
```

### `ChatFeed.qml`

Generic conversation content + composer.

```text
displays messages array
renders incoming/outgoing states
shows empty/loading/error states
owns TextInput and send button
emits sendRequested
waits for send-success serial before clearing text
```

### `SessionAdapter.qml`

Backend-specific implementation.

```text
runs session-cli
parses JSON
normalizes conversations/messages
polls Session data
sends through the helper
exposes errors/loading/sending/success state
```

---

## 3. Main architectural principle

```text
backend-specific complexity belongs behind adapters
```

Generic visual components should consume normalized objects, not know how Session/Discord/Telegram stores or transmits data.

Ideal direction:

```text
service backend
      ↓
adapter
      ↓
normalized conversation/message state
      ↓
MessagingW
      ↓
ContactList + ChatFeed
```

---

## 4. Current window geometry

Accepted `MessagingW` geometry:

```qml
implicitWidth: 900
implicitHeight: 1355

anchors {
    top: false
    bottom: true
    right: true
    left: false
}

margins {
    top: 0
    bottom: 80
    right: 10
    left: 0
}

exclusiveZone: 0
color: "transparent"
surfaceFormat.opaque: false
```

Column widths:

```qml
property int appSelectorWidth: 110
property int contactListWidth: 200
```

Layout:

```text
┌───────────┬────────────────────┬──────────────────────────────────────┐
│ App       │ Contact            │ ChatFeed                             │
│ Selector  │ List               │                                      │
│ 110       │ 200                │ remaining width                      │
└───────────┴────────────────────┴──────────────────────────────────────┘
```

---

## 5. Native window lifecycle invariant

The root `PanelWindow` must stay alive:

```qml
visible: true
focusable: menuOpen
```

The visible UI is a child:

```qml
Item {
    id: messagingContent
    anchors.fill: parent
    visible: messagingWindow.menuOpen
}
```

Closed input mask:

```qml
mask: Region {
    x: 0
    y: 0

    width:
        messagingWindow.menuOpen
        ? messagingWindow.width
        : 0

    height:
        messagingWindow.menuOpen
        ? messagingWindow.height
        : 0
}
```

Reason: root `visible: menuOpen` repeatedly triggered a native Qt/Quickshell `PanelWindow` creation/reparenting crash.

This is an architectural invariant, not just styling.

---

## 6. Wayland stacking invariant

Imports:

```qml
import Quickshell.Wayland
```

Inside the root object:

```qml
WlrLayershell.layer: WlrLayer.Overlay
```

Reason: the separate Power `PanelWindow` otherwise stacked above the messaging menu where their surfaces overlap.

QML child `z` does not reorder separate native windows.

---

## 7. Focus zones

Current shared state:

```qml
property int focusZone: 0
readonly property int appZone: 0
readonly property int contactZone: 1
readonly property int chatZone: 2
```

State flow:

```text
┌────────────────┐
│  APP SELECTOR  │
└───────┬────────┘
        │ Enter / Return / Right
        ▼
┌────────────────┐
│  CONTACT LIST  │
└───────┬────────┘
        │ Enter / Return / Right
        ▼
┌────────────────┐
│    COMPOSER    │
└────────────────┘

ContactList --Left/Escape--> AppSelector
Composer ----Escape-------> ContactList
```

The latest current ChatFeed does not override Left Arrow in the composer. That preserves normal cursor movement.

---

## 8. Why navigation belongs in MessagingW

Without a shared parent controller, child components would independently call `forceActiveFocus()` and easily fight one another.

The parent knows:

```text
which logical zone is active
whether a selected app has contacts
whether a contact exists
whether the composer can be entered
when the menu is opening/closing
```

This makes navigation predictable and testable.

---

## 9. Focus helper API

```qml
function focusAppSelector() {
    focusZone = appZone;
    appSelector.keyboardActive = true;
    keyboardFocus.forceActiveFocus();
}

function focusContacts() {
    if (contactList.conversations.length === 0)
        return;

    focusZone = contactZone;
    contactList.keyboardActive = true;
    contactList.ensureValidIndex();
    keyboardFocus.forceActiveFocus();
}

function focusComposer() {
    if (!contactList.selectedConversation)
        return;

    focusZone = chatZone;
    chatFeed.focusMessageInput();
}

function acceptSelectedApp() {
    if (contactList.conversations.length > 0)
        focusContacts();
}

function activateCurrentContact() {
    if (!contactList.activateCurrent())
        return;

    focusComposer();
}

function returnToContacts() {
    if (contactList.conversations.length === 0) {
        focusAppSelector();
        return;
    }

    focusZone = contactZone;
    contactList.keyboardActive = true;
    contactList.ensureValidIndex();
    keyboardFocus.forceActiveFocus();
}
```

---

## 10. Keyboard controller

A parent `Item` receives navigation keys when focus is not in the composer.

Its focus condition is conceptually:

```qml
focus:
    messagingWindow.menuOpen
    && messagingWindow.focusZone !== messagingWindow.chatZone
```

This allows the actual TextInput to own focus when in `chatZone`.

---

## 11. AppSelector keyboard behavior

When `focusZone === appZone`:

```text
Up       previous app, wrap
Down     next app, wrap
Enter    accept selected app
Return   accept selected app
Right    accept selected app
Escape   close messaging menu
```

`acceptSelectedApp()` only enters contacts if contacts exist.

That is useful today because selecting Discord or Telegram should not force the user into an empty contact focus zone.

---

## 12. ContactList keyboard behavior

When `focusZone === contactZone`:

```text
Up       previous contact, wrap
Down     next contact, wrap
Enter    activate selected contact and enter composer
Return   same
Right    same
Left     AppSelector
Escape   AppSelector
```

---

## 13. Composer keyboard behavior

TextInput:

```text
Enter  → send
Return → send
Escape → emit composerEscapeRequested
```

Parent handles:

```qml
onComposerEscapeRequested: {
    messagingWindow.returnToContacts();
}
```

Do not silently re-add a Left Arrow handler from an older design unless normal cursor-left behavior is intentionally being sacrificed.

---

## 14. AppSelector public state

```qml
property int selectedIndex: 0
property bool keyboardActive: false
```

Current apps:

```text
0 SESSIONS
1 DISCORD
2 TELEGRAM
```

Session is currently the only live backend.

---

## 15. AppSelector mouse/keyboard arbitration

A selected/highlighted app can be driven by mouse or keyboard.

Hover is gated with:

```qml
property bool isHovered:
    !appSelector.keyboardActive
    && appMouse.containsMouse
```

Mouse entry:

```qml
appSelector.keyboardActive = false;
appSelector.selectedIndex = index;
```

Keyboard movement sets:

```qml
appSelector.keyboardActive = true;
```

This prevents a stationary pointer from immediately overriding a keyboard selection.

---

## 16. AppSelector visual states

Accepted state language:

```text
idle:
    fill = Colors.black
    text = Colors.cyan

hover:
    fill = Colors.yellow
    text = Colors.orange
    glow = orange

selected:
    fill = Colors.yellow
    text = Colors.orange
    glow = orange

pressed:
    fill = Colors.magenta
    text = Colors.black
    glow = magenta
```

Text glow follows the stronger Power-style selected/hover treatment.

The button's broad glow uses two `RectangularShadow` layers rather than a single Power-style shadow.

---

## 17. Why AppSelector is 110 px wide

Visible buttons are about 70 px wide, but the selector's root is around 110 px.

Purpose:

```text
give the close/wide glow breathing room at the PanelWindow edge
```

This was visually tested and accepted.

---

## 18. Final intended Session app icon

At the end of Session work, the Session AppSelector row was to reuse:

```text
assets/Sessions.png
```

Suggested treatment:

```text
~14 × 14 image
left of SESSIONS text
PreserveAspectFit
smooth: false
subtle state-aware glow
```

Discord/Telegram can remain text-only until their implementation reaches the polish stage.

Because a complete post-edit AppSelector file was not uploaded afterward, verify this addition exists in the local working tree.

---

## 19. ContactList public contract

```qml
property var conversations: []
property var selectedConversation: null
property int selectedIndex: -1
property bool keyboardActive: false
property bool keyboardFocused: false
signal contactClicked
```

Nothing here inherently depends on Session.

---

## 20. ContactList helpers

### `clearSelection()`

```text
selectedIndex = -1
selectedConversation = null
```

Used when switching apps/backends.

### `ensureValidIndex()`

If there are no conversations:

```text
index = -1
conversation = null
```

If the index is invalid but conversations exist:

```text
select index 0
set selectedConversation to conversations[0]
```

### `selectIndex(index)`

Validates, synchronizes `selectedIndex`, `ListView.currentIndex`, `selectedConversation`, and scroll position.

### `moveSelection(direction)`

Wraps from end to start and start to end.

### `activateCurrent()`

Ensures a valid selected row and exposes its conversation as the active one.

---

## 21. Why both selectedIndex and selectedConversation exist

```text
selectedIndex         = navigation/ListView state
selectedConversation  = actual data object used by backend/ChatFeed
```

The helpers keep these synchronized.

Avoid directly mutating one without the other.

---

## 22. Contact hover is deliberately different from app hover

AppSelector hover may change `selectedIndex`.

ContactList hover may **not** change actual conversation selection.

Contact delegate state:

```qml
property bool isSelected:
    contactRoot.selectedIndex === index

property bool isHovered:
    !contactRoot.keyboardActive
    && contactMouse.containsMouse

property bool isPressed:
    contactMouse.pressed
```

Mouse entry only does:

```qml
contactRoot.keyboardActive = false;
```

This lets the user inspect rows visually without changing the message feed.

---

## 23. Contact click semantics

Left click:

```qml
contactRoot.selectIndex(contactButton.index);
contactRoot.contactClicked();
```

Then MessagingW:

```text
sets focusZone = contactZone
sets contactList.keyboardActive = false
returns focus to keyboard controller
```

It does **not** automatically jump to the composer.

This separation was explicitly desired.

Right-click currently logs/acts as a placeholder for future contact actions.

---

## 24. ContactList root and header

Root:

```text
Colors.black
radius 0
1 px border
cyan normally
orange while contact zone is keyboard focused
clip true
```

Header text:

```text
CONTACTS
CONVERSATION(S): <count>
```

The literal static `CONVERSATION(S):` wording and colon are intentional.

Header style:

```text
height ~70
Colors.dark
title cyan + cyan glow
label pale white at ~0.70 opacity
count orange + orange glow
2 px cyan separator + glow
```

The outer border remains because the three adjacent areas blended together too much without it.

---

## 25. Contact selected/hover/pressed visuals

Background:

```qml
color:
    isPressed ? Colors.magenta
    : isHovered ? Colors.yellow
    : isSelected ? Colors.yellow
    : Colors.black
```

Name:

```qml
color:
    isPressed ? Colors.black
    : isHovered ? Colors.orange
    : isSelected ? Colors.orange
    : Colors.cyan
```

Preview:

```qml
color:
    isPressed ? Colors.black
    : isHovered ? Colors.orange
    : isSelected ? Colors.orange
    : Colors.white
```

Preview stays somewhat subdued when not pressed.

---

## 26. Persistent selected border/glow

Final intended border:

```qml
border.width:
    isSelected || isHovered || isPressed
    ? 1
    : 0

border.color:
    isPressed ? Colors.magenta
    : isHovered ? Colors.orange
    : isSelected ? Colors.orange
    : "transparent"
```

Final selected glow:

```text
pressed = magenta
hover   = orange
selected = orange
idle    = none
```

A selected row stays orange after keyboard focus moves into ChatFeed.

This is the difference between persistent selection and current focus zone.

---

## 27. ChatFeed public contract

```qml
property var conversation: null
property var messages: []
property bool loading: false
property string error: ""

property bool sending: false
property string sendError: ""
property int sendSuccessSerial: 0

signal sendRequested(string conversationId, string text)
signal composerEscapeRequested

property int pendingSendSerial: -1
```

This is already mostly backend-neutral.

---

## 28. Latest ChatFeed base layers

Latest fully uploaded source:

```text
root Rectangle: transparent
radius: 0
chatBackground: Colors.black opacity 0.75
messageViewport: transparent
chatFrame: transparent + 1 px cyan border
```

Do not casually make the entire feed opaque; its translucency is part of the intended composition.

---

## 29. Chat header

Header:

```text
height 60
Colors.dark
radius 0
2 px cyan separator + glow
```

Name fallback order currently:

```text
displayNameInProfile
nickname
id
```

No conversation:

```text
SELECT A CONTACT
```

---

## 30. Default contact/avatar icon

Current uploaded fallback:

```text
32 × 32
visible only with conversation
square
transparent fill
cyan border opacity ~0.65
faint cyan glow opacity ~0.15
@ glyph
Gohu/Nerd font 18 bold
cyan at ~0.85 opacity
```

History:

```text
first glyph ጸ → visually bright and could fail due to font coverage
final glyph @ → reliable default account/social symbol
```

The fallback should remain even after real avatar support is added.

---

## 31. Chat message model expected today

Minimum:

```js
{
    body: "message",
    direction: "incoming" | "outgoing"
}
```

Future useful fields:

```js
{
    id,
    conversationId,
    timestamp,
    senderId,
    senderName,
    avatar,
    attachments
}
```

---

## 32. Message bubble visuals

Direction:

```qml
property bool outgoing:
    modelData.direction === "outgoing"
```

Layout:

```text
outgoing → right
incoming → left
max bubble width ≈ 72% of feed
```

Color:

```text
bubble fill: Colors.dark
outgoing border/text: orange
incoming border/text: cyan
radius: 0
```

Glow:

```text
close RectangularShadow spread ~2 opacity ~0.18
wide RectangularShadow spread ~7 opacity ~0.04
```

---

## 33. Empty/loading/error states

No conversation:

```text
SELECT A CONTACT
cyan
```

Loading with no messages:

```text
LOADING...
orange
```

Message error:

```text
red
wrapped
centered
```

Send error appears above composer and also uses red.

---

## 34. Composer contract

Visible only when `conversation !== null`.

Geometry:

```text
height 54
left/right/bottom margins 16
Colors.dark
radius 0
```

Focus:

```text
active focus → orange border/glow
idle → cyan border/glow
```

TextInput:

```text
enabled = !sending
selection = orange
selectedText = black
font = GohuFont 11 Nerd Font Mono
```

Final requested enabled text:

```qml
color:
    enabled
    ? Colors.magenta
    : Colors.cyan
```

Placeholder stays:

```text
MESSAGE...
cyan at lower opacity
```

---

## 35. Send validation

`trySend()` rejects:

```text
no conversation
already sending
blank/whitespace-only text
```

Then:

```qml
pendingSendSerial = sendSuccessSerial;
sendRequested(conversation.id, text);
```

No Session-specific command appears here.

---

## 36. Confirmed-success clearing

The input is cleared only when the adapter success serial increases beyond the stored pre-send serial.

On success:

```text
clear text
pendingSendSerial = -1
refocus input
scroll feed to end after model refresh
```

On failure:

```text
retain text
show sendError
```

This behavior should be preserved for all future backends.

---

## 37. Current Session-specific backend routing

Contacts:

```qml
conversations:
    appSelector.selectedIndex === 0
    ? sessionAdapter.conversations
    : []
```

Conversation message load:

```qml
onSelectedConversationChanged: {
    if (appSelector.selectedIndex === 0 && selectedConversation) {
        sessionAdapter.loadMessages(selectedConversation.id);
    }
}
```

ChatFeed state:

```text
conversation → selected Session conversation at index 0, otherwise null
messages → sessionAdapter.messages at index 0, otherwise []
loading/error/sending/sendError/sendSuccessSerial → Session state at index 0
```

Send:

```qml
onSendRequested: function(conversationId, text) {
    if (appSelector.selectedIndex === 0) {
        sessionAdapter.sendMessage(conversationId, text);
    }
}
```

---

## 38. Why index routing was okay initially

It allowed the first backend to be proven without building an abstraction based on guesses.

Now that Session is known and Discord is next, enough common behavior exists to justify centralizing the switch.

---

## 39. Recommended common adapter interface

```qml
property string backendId: ""
property string displayName: ""

property var conversations: []
property var messages: []

property bool conversationsLoading: false
property string conversationsError: ""

property bool messagesLoading: false
property string messagesError: ""

property bool sending: false
property string sendError: ""
property int sendSuccessSerial: 0

signal messageSent()

function refreshConversations() {}
function loadMessages(conversationId) {}
function sendMessage(conversationId, text) {}
```

Adapters can internally poll, subscribe to events, call HTTP APIs, run CLIs, or use local IPC. The UI should not care.

---

## 40. Recommended normalized conversation model

```js
{
    id: "backend-unique-id",
    backend: "session",
    displayName: "Visible Name",
    nickname: "",
    lastMessage: "preview",
    unreadCount: 0,
    avatar: ""
}
```

Optional later:

```js
{
    kind: "dm" | "group" | "channel",
    parentId: "",
    parentName: "",
    muted: false,
    pinned: false
}
```

---

## 41. Recommended normalized message model

```js
{
    id: "message-id",
    backend: "session",
    conversationId: "conversation-id",
    body: "text",
    direction: "incoming",
    timestamp: 0,
    senderId: "",
    senderName: "",
    avatar: "",
    attachments: []
}
```

Adapter ordering contract:

```text
oldest → newest
```

---

## 42. Recommended currentAdapter migration

Conceptually:

```qml
readonly property var currentAdapter:
    appSelector.selectedIndex === 0
    ? sessionAdapter
    : appSelector.selectedIndex === 1
    ? discordAdapter
    : appSelector.selectedIndex === 2
    ? telegramAdapter
    : null
```

Then generic bindings become:

```qml
conversations:
    currentAdapter
    ? currentAdapter.conversations
    : []
```

Exact QML object-reference typing should be tested on the installed Quickshell/Qt version rather than assumed.

The architecture goal is a single switch point.

---

## 43. Component invariants to test after every refactor

```text
MessagingW:
    root PanelWindow stays alive and overlay-layered

AppSelector:
    app selection determines backend
    keyboard and mouse do not fight

ContactList:
    hover never mutates actual selected conversation
    click selects but does not auto-enter composer

ChatFeed:
    no service-specific process commands
    failed send retains text
    successful send clears after confirmation

Adapter:
    exposes normalized objects
    hides backend-specific mechanics

Sessions launcher:
    opens/closes only
```

---

## 44. What Discord should not force us to rewrite

A successful architecture means Discord should not require copies of:

```text
ContactList selection logic
ChatFeed bubble layout
composer send state
focus-zone navigation
PanelWindow crash workaround
Wayland stacking fix
```

If Discord needs new generic data—such as channel parent names—that should be added as optional normalized metadata rather than forking the frontend.


<!-- ===== END 02_MESSAGING_WIDGET_ARCHITECTURE.md ===== -->

<!-- ===== BEGIN 03_QUICKSHELL_RICE_REFERENCE.md ===== -->

# Quickshell Rice Reference

**Scope:** Quickshell/Sway knowledge accumulated during the messaging work, plus the project-wide visual and interaction conventions that the messaging UI relies on.

---

## 1. General project philosophy

The rice uses Quickshell as a desktop-facing control and information layer on top of Sway.

```text
Sway
  │
  ▼
Quickshell
  ├── workspaces
  ├── clock
  ├── power
  ├── audio
  ├── network
  ├── bluetooth
  ├── launcher
  ├── messaging
  └── other HUD modules
```

The broad division is:

```text
Quickshell = graphical quick controls + glanceable state
Terminal   = deeper, keyboard-heavy control and work
```

That principle is reflected in messaging: QML is the visible control surface; service-specific work is delegated to adapters/helpers.

---

## 2. Visual identity

The design language should not be flattened into generic “cyberpunk neon.” The project has a more specific mixture of influences:

```text
retro computing / CRT / terminal
old television and old PC interfaces
sparse HUD / instrument panels
celestial/night-sky atmosphere
Christian motifs in some parts of the rice
retro-American visual language
Japanese reinterpretations of Western/retro motifs
game UI
anime/comic energy
playful old-display personality
```

Use these as a vocabulary. A messaging panel does not need every motif simultaneously.

---

## 3. Authoritative Colors.qml

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
NO Colors.background
Colors.black is deep purple
Colors.dark is darker purple
```

Do not “correct” `Colors.black` to `#000000` because of the property name.

---

## 4. Color semantics

The UI broadly uses:

```text
cyan      normal / interface / information / data
orange    active / focused / hot
yellow    selected / emphasized
magenta   pressed / special interaction
red       urgent / error / destructive
white     neutral secondary information
green     available project accent
omnitrix  vivid green used by selected modules
blue      available project accent
black     deep-purple foundation
dark      deeper purple internal surface
```

Not every module must use every color.

---

## 5. Geometry and visual weight

Strong current preferences:

```text
radius: 0 almost everywhere
thin borders
transparent/translucent large surfaces
visual weight from glow rather than thick frames
```

The messaging UI follows this throughout:

```text
square app buttons
square contact rows
square message bubbles
square composer
square default avatar
```

---

## 6. Typography

Primary family used in messaging:

```text
GohuFont 11 Nerd Font Mono
```

This provides the terminal/pixel feel.

Caution: a font family name does not guarantee every Unicode block. The early `ጸ` default avatar could disappear because the chosen font did not reliably include that glyph. `@` became the safer fallback.

---

## 7. Power.qml as interaction grammar

Power became the reference for interaction states.

Typical fill:

```qml
color: pressed
    ? Colors.magenta
    : !keyboardActive && containsMouse
    ? Colors.yellow
    : selected
    ? Colors.yellow
    : Colors.black
```

Typical text:

```qml
color: pressed
    ? Colors.black
    : !keyboardActive && containsMouse
    ? Colors.orange
    : selected
    ? Colors.orange
    : Colors.cyan
```

Typical selected/hover text glow:

```text
DropShadow
color orange
opacity 1
radius 30
samples 60
```

Typical active button glow:

```text
pressed magenta
hover orange
selected orange
idle none
radius 12
samples 25
opacity ~0.55 active
```

Destructive actions in Power may use red instead of magenta.

---

## 8. Clock/workspace-style broad glow

Some modules intentionally use two `RectangularShadow` layers:

```text
close glow: spread ~3
wide glow:  spread ~10
```

AppSelector ended up using this broader visual treatment while keeping Power-like state colors.

This distinction was explicitly preferred. Do not refactor all effects into one universal shadow merely for code uniformity.

---

## 9. Mouse versus keyboard state

A recurring pattern is:

```qml
property bool keyboardActive: false

property bool isHovered:
    !keyboardActive
    && mouse.containsMouse
```

Keyboard navigation sets `keyboardActive = true`.

Mouse entry/activity sets `keyboardActive = false`.

This stops a stationary pointer from immediately overriding keyboard selection.

ContactList adds an additional rule: its hover is visual only and must not change actual contact selection.

---

## 10. Persistent selection versus active focus

A key UI lesson from ContactList:

```text
selected item != item currently owning keyboard focus
```

The selected conversation persists while the composer has focus.

Therefore its selected styling must remain visible:

```text
yellow fill
orange text
orange border/glow
```

Do not tie persistent selected styling completely to `keyboardFocused`.

---

## 11. PanelWindow is a native surface

A `PanelWindow` is not just another QML Rectangle.

Two bugs reinforced this distinction:

1. changing root `visible` repeatedly triggered native window creation/reparenting and a crash;
2. child `z` values could not solve stacking between MessagingW and Power because they are separate native Wayland surfaces.

When a bug concerns appearance/disappearance or one panel covering another, reason at the native surface/layer-shell level.

---

## 12. Messaging native crash

The later repeated-click crash produced coredumps rather than a normal QML exception.

Environment captured:

```text
Quickshell 0.2.1^git20260209.dacfa9d-5.fc44
Qt 6.11.2
SIGSEGV
```

Important stack sequence:

```text
QQuickItem::isUnderMouse
QQuickMouseArea::itemChange
QQuickItemPrivate::itemChange
QQuickItemPrivate::setEffectiveVisibleRecur
QQuickItem::setParentItem
ProxyWindowBase::completeWindow
ProxyWindowBase::createWindow
ProxyWindowBase::setVisibleDirect
...
QQuickMouseArea::clicked
```

This tied the crash to click-triggered visibility/window lifecycle changes.

---

## 13. Failed partial crash fix

The launcher toggle was wrapped in `Qt.callLater()`.

This changed timing but did not remove the native create/destroy path, so the crash still occurred.

Lesson:

```text
deferring a dangerous lifecycle operation is not the same as removing it
```

---

## 14. Accepted PanelWindow lifecycle workaround

Keep the native window alive:

```qml
visible: true
focusable: menuOpen
```

Hide only the visual child:

```qml
Item {
    anchors.fill: parent
    visible: messagingWindow.menuOpen
}
```

Collapse input area while closed:

```qml
mask: Region {
    x: 0
    y: 0
    width: messagingWindow.menuOpen ? messagingWindow.width : 0
    height: messagingWindow.menuOpen ? messagingWindow.height : 0
}
```

This avoids hitting `ProxyWindowBase::createWindow()` on every toggle.

This is the current baseline and should be preserved unless a future Quickshell/Qt upgrade proves the bug gone and there is a reason to simplify.

---

## 15. Input mask behavior

Closed state:

```text
native window exists
content hidden
focusable false
mask 0×0
pointer passes through
```

Open state:

```text
native window exists
content visible
focusable true
mask full window
```

This pattern may be useful for other menus if they hit similar lifecycle bugs.

---

## 16. Wayland layer-shell stacking

A screenshot showed the Power button drawing over the messaging panel.

The position was correct; the surfaces were on a stacking order where Power won.

QML `z` only orders items inside an item/window hierarchy. It does not reorder independent Wayland surfaces.

Accepted solution:

```qml
import Quickshell.Wayland
```

and:

```qml
PanelWindow {
    WlrLayershell.layer: WlrLayer.Overlay
}
```

The user confirmed this as correct.

---

## 17. Attached property placement

A malformed intermediate file accidentally placed:

```qml
WlrLayershell.layer: WlrLayer.Overlay
```

between import lines.

Correct:

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland
...

PanelWindow {
    WlrLayershell.layer: WlrLayer.Overlay
}
```

Attached properties belong in an object body.

---

## 18. Window placement baseline

After the stacking diagnosis, the messaging position stayed:

```text
bottom/right anchored
bottom margin 80
right margin 10
```

An intermediate suggestion used a larger bottom margin to move the panel, but that was rejected because placement was not the problem.

---

## 19. Earlier Sway startup lifecycle issue

There was a separate earlier repeated-click/process problem associated with Quickshell startup.

Bad pattern:

```bash
exec_always quickshell >/dev/null 2>&1 && quickshell || quickshell
```

Accepted replacement:

```bash
exec_always sh -c 'pkill -x quickshell; quickshell >/tmp/quickshell.log 2>&1 &'
```

This ensures the old process is killed before a fresh one starts and gives a log file.

Do not confuse this earlier issue with the later native PanelWindow crash. During the later crash, `pgrep -x -a quickshell` showed only one process.

---

## 20. Useful Quickshell diagnostics

Process check:

```bash
pgrep -x -a quickshell
```

Verbose launch:

```bash
quickshell -vv -p ~/.config/quickshell/shell.qml
```

Sway-started log:

```text
/tmp/quickshell.log
```

Native crash: inspect coredump/backtrace before changing unrelated QML.

---

## 21. Why coredump investigation mattered

Before the stack was available, plausible suspects included:

```text
contact borders
glow effects
Session polling
mouse hover logic
duplicate processes
```

The native backtrace sharply narrowed the real problem to the window visibility path.

General rule:

> If Quickshell terminates with SIGSEGV instead of reporting a QML error, get native evidence first.

---

## 22. Known unrelated warnings

Logs also contained other issues worth cleaning up later:

```text
Network.qml: Cannot anchor to an item that isn't a parent or sibling.
Workspaces.qml: Cannot read property 'length' of undefined.
Network.qml: undefined values assigned to typed properties.
ShaderEffect-related warnings.
```

These should not be blamed for the messaging crash without new evidence.

---

## 23. Stale/unresolvable imports

`Sessions.qml` at one point had bad relative imports such as:

```qml
import "modules"
import "../../messanger"
```

from a location where those paths resolved incorrectly.

Quickshell reported unresolvable import warnings.

Removing unused/bad imports was correct cleanup, but again not the native crash fix.

---

## 24. Common parser/runtime errors hit while editing

During rapid QML iteration we encountered ordinary issues such as:

```text
Unexpected token
Incomplete binding
PanelWindow unavailable / not a type
invalid alias reference
Colors ReferenceError
menu ReferenceError
module not installed
```

Recommended debugging order:

```text
1. find the first concrete QML error
2. fix syntax/import/type issue
3. reload
4. then evaluate remaining warnings
5. only then investigate behavioral bugs
```

---

## 25. zsh history expansion gotcha

QML uses negation frequently:

```qml
!keyboardActive
```

When pasted into an unquoted zsh heredoc, `!` can trigger history expansion and produce:

```text
zsh: event not found
```

Safe:

```bash
cat > SomeFile.qml <<'EOF'
... QML ...
EOF
```

The quoted heredoc delimiter prevents shell expansion.

A Python heredoc is another safe replacement route.

---

## 26. grep alias/wrapper gotcha

The user's command environment can make `grep` act like ripgrep.

GNU-style recursive flags can then fail.

When a command depends on GNU grep semantics, use:

```bash
/usr/bin/grep
```

This saved time during `session-cli` package inspection.

---

## 27. Visually clipped terminal output

Long lines shown in a narrow terminal/Zellij pane may appear truncated.

Do not infer file corruption from a visually clipped line.

Use tools such as:

```bash
nl -ba file.qml
sed -n 'START,ENDp' file.qml
cat file.qml
```

or enable editor wrapping.

---

## 28. Transparency lesson

The desired UI is not a stack of opaque purple rectangles.

In ChatFeed, the successful direction is:

```text
root transparent
message viewport transparent
one controlled translucent Colors.black background
```

Latest uploaded background opacity:

```text
0.75
```

MessagingW also has a subtle outer/background layer around `0.20` opacity.

---

## 29. Borders and glow lesson

Thin borders provide structural separation, especially where adjacent menus meet.

The ContactList outer cyan border was kept because removing it caused panels to visually merge.

Glow should support state rather than replace all structure.

Good balance used here:

```text
1 px structural border
2 px major header separator
state-dependent shadows
```

---

## 30. Static text decisions matter

The user explicitly preferred:

```text
CONVERSATION(S):
```

including the colon, instead of dynamic singular/plural wording.

Do not “improve” intentional copy without checking the visual/voice decision.

---

## 31. AppSelector and ContactList use different hover semantics

This is easy to forget because their visual states look related.

```text
AppSelector hover:
    may update selected app

ContactList hover:
    visual highlight only
    must not update selectedConversation
```

The distinction supports browsing contacts without constantly changing the active message feed.

---

## 32. Current messaging import header

Accepted conceptual form:

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../components"
import "../../services/messaging"
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: messagingWindow
    WlrLayershell.layer: WlrLayer.Overlay
```

Preserve the Wayland import and attached property.

---

## 33. Quickshell debugging checklist

```text
[ ] Is the import path correct relative to this file?
[ ] Is there only one Quickshell process?
[ ] What is the first actual parser/runtime error?
[ ] Is the problem inside one QML tree or between native surfaces?
[ ] Is a PanelWindow being created/destroyed repeatedly?
[ ] Is the Wayland layer correct?
[ ] Is a hidden permanent window intercepting pointer input?
[ ] Is its mask actually zero while closed?
[ ] Is pointer hover fighting keyboard selection?
[ ] Is persistent selection being confused with focus?
[ ] Is glow clipped because the parent/window is too narrow?
[ ] Is terminal line clipping misleading us?
[ ] Is zsh expanding QML `!` before it reaches the file?
[ ] Is `grep` actually GNU grep?
[ ] Does a native SIGSEGV need coredump analysis?
```

---

## 34. Project rules worth preserving

```text
Prefer square geometry.
Use thin borders.
Use glow for emphasis.
Use Colors.qml rather than ad-hoc hex values where possible.
Keep the actual palette meanings intact.
Use Gohu/Nerd typography consistently.
Reuse established state semantics.
Do not force every module to use an identical glow implementation.
Centralize navigation decisions.
Keep backend logic behind adapters.
Respect native PanelWindow lifecycle.
Treat Wayland layer-shell as distinct from QML item z-order.
Use evidence from logs/coredumps before rewriting working components.
```


<!-- ===== END 03_QUICKSHELL_RICE_REFERENCE.md ===== -->

<!-- ===== BEGIN 04_FUTURE_MESSAGING_ADAPTERS.md ===== -->

# Future Messaging Adapters and Expansion Plan

**Next backend:** Discord  
**Later candidates:** Telegram, Signal, and other programs with a maintainable API/helper/IPC path.

The Session work established the key rule for everything that comes next:

> Add a backend adapter, not another copy of the messaging UI.

---

## 1. Current state versus target state

Today:

```text
AppSelector.selectedIndex
        │
        ├── 0 → SessionAdapter [working]
        ├── 1 → empty Discord placeholder
        └── 2 → empty Telegram placeholder
```

Target:

```text
AppSelector
    │
    ▼
backend id / registry / currentAdapter
    │
    ├── SessionAdapter
    ├── DiscordAdapter
    ├── TelegramAdapter
    └── SignalAdapter
             │
             ▼
       normalized contract
             │
      ┌──────┴──────┐
      ▼             ▼
 ContactList      ChatFeed
```

---

## 2. Why the adapter boundary matters

Messaging systems differ in:

```text
authentication
conversation/channel models
local storage
network/API models
message fields
live update mechanisms
sending mechanisms
rate limits
attachments
replies/reactions
error behavior
connection lifecycle
```

Those differences belong behind adapters.

The frontend should deal with concepts such as:

```text
conversation
message
loading
error
sending
success
```

rather than Discord guild APIs, Session SQLCipher, Telegram update IDs, or Signal helper commands.

---

## 3. Recommended common adapter contract

A practical generic adapter should expose:

```qml
property string backendId: ""
property string displayName: ""

property var conversations: []
property var messages: []

property bool conversationsLoading: false
property string conversationsError: ""

property bool messagesLoading: false
property string messagesError: ""

property bool sending: false
property string sendError: ""
property int sendSuccessSerial: 0

signal messageSent()

function refreshConversations() {}
function loadMessages(conversationId) {}
function sendMessage(conversationId, text) {}
```

Optional later:

```qml
property bool connected: false
property string connectionState: ""
property string fatalError: ""

property bool supportsAttachments: false
property bool supportsReplies: false
property bool supportsReactions: false
property bool supportsEditing: false
property bool supportsDeletion: false
property bool supportsTypingState: false
property bool supportsReadReceipts: false
```

Do not add capability flags until they solve a real need, but this is the direction.

---

## 4. Normalized conversation model

Recommended minimum:

```js
{
    id: "backend-unique-conversation-id",
    backend: "discord",
    displayName: "Visible Name",
    nickname: "",
    lastMessage: "Preview text",
    unreadCount: 0,
    avatar: ""
}
```

Optional generic metadata:

```js
{
    kind: "dm" | "group" | "channel" | "thread",
    parentId: "",
    parentName: "",
    muted: false,
    pinned: false,
    updatedAt: 0
}
```

The generic UI should prefer `displayName` rather than backend-specific keys such as Session's `displayNameInProfile`.

During migration, an adapter can expose both old and normalized keys to avoid a giant frontend rewrite.

---

## 5. Normalized message model

Recommended:

```js
{
    id: "message-id",
    backend: "discord",
    conversationId: "conversation-id",
    body: "message body",
    direction: "incoming",
    timestamp: 0,
    senderId: "",
    senderName: "",
    avatar: "",
    attachments: []
}
```

Critical current invariant:

```text
direction = "incoming" or "outgoing"
```

because ChatFeed already uses that distinction for styling/alignment.

---

## 6. Ordering contract

Every adapter should expose messages in:

```text
oldest → newest
```

Session already normalizes its data this way.

Do not make ChatFeed know that one backend returns newest-first and another returns oldest-first.

---

## 7. Generic send lifecycle

All adapters should preserve the current successful Session contract.

When sending:

```text
1. reject invalid/blank send at ChatFeed layer
2. adapter sets sending = true
3. adapter clears prior sendError
4. adapter attempts backend send
5. success:
      sending = false
      increment sendSuccessSerial
      emit messageSent
      refresh messages
      refresh conversation preview if needed
6. failure:
      sending = false
      set sendError
      do not increment success serial
```

ChatFeed then clears text only when the success serial increases.

This behavior is generic and should not be weakened for Discord.

---

## 8. Replace repeated index ternaries

Current code repeats:

```qml
appSelector.selectedIndex === 0
    ? sessionAdapter.foo
    : ...
```

That was acceptable for one backend. With Discord it becomes cumbersome and error-prone.

A first migration can be conceptually simple:

```qml
readonly property var currentAdapter:
    appSelector.selectedIndex === 0
    ? sessionAdapter
    : appSelector.selectedIndex === 1
    ? discordAdapter
    : appSelector.selectedIndex === 2
    ? telegramAdapter
    : null
```

Then:

```qml
conversations:
    currentAdapter
    ? currentAdapter.conversations
    : []
```

and:

```qml
onSendRequested: function(conversationId, text) {
    if (currentAdapter)
        currentAdapter.sendMessage(conversationId, text);
}
```

The exact QML object-reference implementation must be tested on the installed Quickshell/Qt version. The important architecture is **one backend switch point** rather than many ternaries.

---

## 9. Move identity away from permanent integer meaning

Today:

```text
0 = Session
1 = Discord
2 = Telegram
```

This becomes fragile if app order changes.

Long-term AppSelector metadata should include a stable id:

```js
{
    id: "session",
    name: "SESSIONS",
    icon: "..."
}
```

and:

```js
{
    id: "discord",
    name: "DISCORD",
    icon: "..."
}
```

The UI can still have a visual index, but backend routing should eventually use stable identity.

---

# Discord plan

## 10. Do backend research before QML

Do not begin Discord day by editing ChatFeed.

First answer outside Quickshell:

```text
What supported/maintainable interface will provide DMs/channels?
How will authentication work?
How are messages listed?
How are messages sent?
Is a helper process needed?
Can events be streamed or should we poll?
How should guild/channel/thread hierarchy be represented?
What behavior is permitted by Discord's platform/API?
```

Choose a legitimate maintainable integration rather than scraping/patching a desktop client by default.

---

## 11. Discord phase A — proof outside QML

Before creating a real adapter, prove:

```text
[ ] authentication works
[ ] list messaging targets works
[ ] fetch messages works
[ ] send text works
[ ] errors can be detected cleanly
[ ] reconnect/retry behavior is understood
```

Only then move the proven calls into `DiscordAdapter.qml` or a helper used by it.

This repeats the best lesson from Session: isolate backend uncertainty before involving the UI.

---

## 12. Discord phase B — adapter skeleton

Create:

```text
services/messaging/DiscordAdapter.qml
```

with the same core public state as SessionAdapter.

Initial milestone should be plain text only.

```text
conversations/channels
messages
send text
loading/errors
```

Do not block first integration on avatars, reactions, attachment upload, or complex guild hierarchy.

---

## 13. Discord conversation modeling

Discord has more hierarchy than a simple one-to-one messenger:

```text
guild/server
channel
thread
DM
group DM
user
```

For the first version, flatten the things the user can message into the generic `conversations` list.

Examples:

```js
{
    id: "channel-id",
    displayName: "general",
    kind: "channel",
    parentName: "Server Name",
    backend: "discord"
}
```

```js
{
    id: "dm-id",
    displayName: "Friend",
    kind: "dm",
    parentName: "",
    backend: "discord"
}
```

Later, the UI can add a hierarchy/filter without invalidating ChatFeed.

---

## 14. Discord message direction

The adapter should determine outgoing messages by comparing the author/account identity with the active logged-in identity, then normalize to:

```text
outgoing
incoming
```

ChatFeed should not know Discord user-id semantics.

---

## 15. Discord authentication and secrets

Do not hardcode credentials/tokens in:

```text
AppSelector.qml
ChatFeed.qml
committed rice files
```

Prefer a supported auth method and an appropriate helper/secret boundary.

At minimum:

```text
keep credentials out of version control
avoid printing them in Quickshell logs
avoid putting them in visible QML properties if unnecessary
```

Do not treat unsupported account automation as equivalent to an official/supported API route; research the correct platform path first.

---

## 16. Discord events versus polling

Session currently polls because that was the easiest reliable integration.

Discord may have a more natural event-driven path.

The adapter is free to use:

```text
websocket/gateway events
HTTP requests
local helper process
polling
```

as long as it exposes the same UI state.

That is exactly why the adapter boundary exists.

---

## 17. Discord error states worth modeling

Likely categories to keep separate internally:

```text
not authenticated
permission denied
backend/helper unavailable
network offline
timeout
rate limited
conversation unavailable
send rejected
connection lost
```

The first UI can still present a generic readable error string, but the adapter should avoid turning every failure into an indistinguishable empty list.

---

## 18. Discord first milestone definition

Success should mean:

```text
select DISCORD
→ see a list of usable messaging targets
→ select one
→ see real recent text messages
→ incoming/outgoing styling is correct
→ enter composer
→ send a real text message
→ success clears input
→ failure retains input
```

If that works, the adapter architecture is proven across two fundamentally different services.

---

# Telegram / Signal / other services

## 19. Repeat the adapter process, not the Session method

The reusable process is:

```text
research service interface
prove read externally
prove send externally
choose least fragile helper/API/IPC
normalize data
implement adapter
register app
reuse UI
```

Do not assume future services should use SQLCipher, CDP, or a CLI just because Session did. Those are Session implementation details.

---

## 20. Per-backend capabilities

Eventually adapters may expose capabilities:

```qml
property bool supportsAttachments: false
property bool supportsReplies: false
property bool supportsReactions: false
property bool supportsEditing: false
property bool supportsDeletion: false
property bool supportsTypingState: false
property bool supportsReadReceipts: false
```

The generic UI can show controls only when supported.

Do not prematurely require every service to implement every feature.

---

## 21. Attachment normalization

Future generic shape:

```js
{
    id: "",
    kind: "image" | "file" | "video" | "audio" | "unknown",
    name: "",
    url: "",
    localPath: "",
    mimeType: "",
    size: 0
}
```

ChatFeed can later add attachment delegates without knowing backend-specific JSON.

---

## 22. Avatar normalization

Conversation object:

```text
avatar
```

Message object optionally:

```text
avatar
senderName
```

ChatFeed should continue to provide the square `@` fallback if the avatar is absent or fails to load.

---

## 23. Unread state

Recommended generic field:

```text
unreadCount
```

This can be displayed in ContactList without service-specific branches.

Do not confuse it with the header's total `CONVERSATION(S):` count.

---

## 24. Connection state

With multiple networked backends it will become useful to expose:

```qml
property bool connected
property string connectionState
property string fatalError
```

This lets the UI distinguish:

```text
empty conversation list
```

from:

```text
backend failed to connect
```

---

## 25. Account identity

Future multi-account support should not overload app index.

Possible backend instance metadata:

```js
{
    backendId: "discord",
    accountId: "...",
    displayName: "Discord — Personal"
}
```

This is not required for the first Discord pass, but stable backend/account identity will scale better than fixed integer positions.

---

## 26. Backend lifecycle optimization later

Possible future policy:

```text
menu closed:
    pause or reduce refresh

menu open:
    refresh active service

selected backend:
    full event/message updates

unselected backends:
    lower-frequency conversation/unread refresh or pause
```

Do not optimize before correctness. Session's current 5 s/3 s polling is acceptable as a proven baseline.

---

## 27. Failure isolation

A broken backend must not break the entire messaging menu.

Desired behavior:

```text
Discord auth fails
    ↓
Discord displays a useful error
    ↓
user can still switch to Session and use it
```

Therefore adapters should own their own loading/error/process state.

---

## 28. AppSelector future metadata

A richer app model can eventually contain:

```js
{
    id: "session",
    name: "SESSIONS",
    icon: "../../assets/Sessions.png",
    enabled: true
}
```

and:

```js
{
    id: "discord",
    name: "DISCORD",
    icon: "../../assets/Discord.png",
    enabled: true
}
```

Visual selection remains generic.

---

## 29. Features that should remain service-neutral

Avoid backend names in:

```text
ContactList selection helpers
contact hover behavior
persistent selection styling
ChatFeed message bubble logic
composer validation
send-success serial logic
focus-zone state machine
PanelWindow crash workaround
Wayland stacking fix
```

Service-specific pieces should be limited to:

```text
adapter implementation
backend registration
service icon/name
optional generic metadata fields
```

---

## 30. Testing matrix for every new adapter

```text
[ ] backend unavailable
[ ] authentication unavailable/invalid
[ ] backend starts/connects
[ ] conversations load
[ ] zero conversations is handled
[ ] app switch clears old selection
[ ] app switch does not show stale old backend messages
[ ] select target by mouse
[ ] hover does not accidentally select contact
[ ] select target by keyboard
[ ] messages load
[ ] oldest→newest order correct
[ ] incoming direction correct
[ ] outgoing direction correct
[ ] long text wraps
[ ] empty send blocked
[ ] send normal message
[ ] sending state disables input as intended
[ ] send failure shows error and retains text
[ ] send success increments serial and clears text once
[ ] refreshed message appears
[ ] conversation preview refreshes if supported
[ ] Escape returns to contacts
[ ] contact Left/Escape returns to apps
[ ] repeated panel open/close does not crash
[ ] Power remains below messaging window
[ ] switching back to Session still works
```

---

## 31. Recommended implementation milestones

### Milestone 1 — Session

Done/near-complete.

### Milestone 2 — Discord text parity

```text
list targets
read messages
send text
```

### Milestone 3 — currentAdapter/backend registry

Remove scattered Session-only ternaries.

### Milestone 4 — generic richer data

```text
displayName
avatars
unread counts
timestamps
parent channel/server labels
```

### Milestone 5 — richer messaging features

```text
attachments
replies
reactions
```

only where adapters support them.

### Milestone 6 — Telegram/Signal

Repeat adapter process.

---

## 32. Definition of architectural success

Adding a future messenger should look mostly like:

```text
create adapter
prove backend
add app metadata
register adapter
```

not:

```text
copy ContactList
copy ChatFeed
copy composer
copy navigation
copy window
maintain four divergent frontends forever
```

The Session work already paid the cost of building the reusable shell. Future integrations should preserve that investment.


<!-- ===== END 04_FUTURE_MESSAGING_ADAPTERS.md ===== -->

<!-- ===== BEGIN 05_RECOVERY_GOTCHAS_AND_FORGOTTEN_DETAILS.md ===== -->

# Recovery, Gotchas, and Easy-to-Forget Details

**Snapshot date:** 2026-09-10  
**Purpose:** preserve the small but critical details most likely to be forgotten after a break or accidentally reverted during a refactor.

This file is intentionally practical. If the messaging widget suddenly behaves strangely after a future edit, check this before re-investigating old problems from scratch.

---

## 1. The directory is spelled `messanger`

Current path:

```text
widgets/messanger/
```

Not:

```text
widgets/messenger/
```

That spelling is already embedded in imports/module discovery. Do not casually rename the directory without updating every reference.

---

## 2. `Sessions.qml` is only the launcher

This naming is easy to misread later.

```text
modules/Sessions.qml
```

is the small Quickshell button that toggles the messaging panel.

The Session messenger backend is:

```text
services/messaging/SessionAdapter.qml
```

The launcher should not absorb backend logic.

---

## 3. Never restore `visible: menuOpen` on the root messaging PanelWindow

This is the largest regression hazard in the project.

The old/simple pattern was:

```qml
PanelWindow {
    visible: menuOpen
}
```

Repeated opening and closing eventually produced a native Qt/Quickshell crash.

The accepted workaround is:

```qml
PanelWindow {
    visible: true
    focusable: menuOpen

    mask: Region {
        width: menuOpen ? messagingWindow.width : 0
        height: menuOpen ? messagingWindow.height : 0
    }

    Item {
        id: messagingContent
        anchors.fill: parent
        visible: menuOpen
    }
}
```

The native surface stays alive. Only the contents and input region effectively disappear.

---

## 4. The repeated-click crash was proven with a native backtrace

The important stack path included:

```text
QQuickItem::isUnderMouse
QQuickMouseArea::itemChange
QQuickItemPrivate::itemChange
QQuickItemPrivate::setEffectiveVisibleRecur
QQuickItem::setParentItem
ProxyWindowBase::completeWindow
ProxyWindowBase::createWindow
ProxyWindowBase::setVisibleDirect
...
QQuickMouseArea::clicked
```

Recorded environment during the crash investigation:

```text
Quickshell: 0.2.1^git20260209.dacfa9d-5.fc44
Qt:         6.11.2
signal:     SIGSEGV
```

That evidence is why this should be treated as a native window-lifecycle issue rather than a random styling bug.

---

## 5. `Qt.callLater()` by itself did not solve the native crash

We tried deferring the launcher toggle:

```qml
Qt.callLater(function() {
    messagingWindow.menuOpen =
        !messagingWindow.menuOpen;
});
```

The crash still occurred because the root window was still being hidden/shown and therefore recreated/reparented.

The guarded `Qt.callLater()` launcher form can remain, but it is not the core fix.

---

## 6. There were two different “repeated click” problems

Do not merge these into one diagnosis.

### Earlier problem: Quickshell startup/lifecycle

Bad Sway startup line:

```bash
exec_always quickshell >/dev/null 2>&1 && quickshell || quickshell
```

Replacement:

```bash
exec_always sh -c 'pkill -x quickshell; quickshell >/tmp/quickshell.log 2>&1 &'
```

That addressed an earlier process/lifecycle problem.

### Later problem: PanelWindow visibility crash

Later, `pgrep -x -a quickshell` showed only one actual Quickshell instance, and a coredump pointed to `ProxyWindowBase::createWindow()` during click-triggered visibility changes.

Different symptom cause, different fix.

---

## 7. MessagingW must be on the Wayland Overlay layer

The messaging panel and Power module are separate native `PanelWindow`s.

The final accepted fix is:

```qml
import Quickshell.Wayland
```

and inside the root `PanelWindow`:

```qml
WlrLayershell.layer: WlrLayer.Overlay
```

The user confirmed this was the correct fix for the Power button appearing above the messaging window.

---

## 8. QML `z` cannot fix stacking between separate PanelWindows

A child can have:

```qml
z: 999999
```

and still lose to another native Wayland surface.

Use `z` for sibling/items within one QML scene. Use Wayland layer-shell properties for native surface stacking.

---

## 9. Do not put `WlrLayershell.layer` between imports

A malformed intermediate edit briefly looked like:

```qml
import QtQuick
import Quickshell
import QtQuick.Effects
WlrLayershell.layer: WlrLayer.Overlay
import Qt5Compat.GraphicalEffects
```

That is invalid QML.

Correct:

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../components"
import "../../services/messaging"
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: messagingWindow

    WlrLayershell.layer: WlrLayer.Overlay
}
```

---

## 10. The Power overlap was not a geometry problem

An intermediate suggestion moved the messaging window farther upward by changing the bottom margin to `150`.

The user correctly identified the real problem as stacking.

Accepted position remains:

```qml
margins {
    top: 0
    bottom: 80
    right: 10
    left: 0
}
```

Do not restore `bottom: 150` unless the layout is intentionally changed for a new reason.

---

## 11. Preserve the current MessagingW dimensions

Accepted baseline:

```text
implicitWidth:  900
implicitHeight: 1355
bottom margin:  80
right margin:   10
```

Current column widths:

```qml
property int appSelectorWidth: 110
property int contactListWidth: 200
```

Older files used a 280 px contact list. Current intended width is 200.

---

## 12. AppSelector is 110 px even though buttons are 70 px

This is deliberate.

```text
selector region = 110 px
visible button  = 70 px
```

The extra horizontal room prevents broad glow from feeling clipped against the `PanelWindow` boundary.

Do not “optimize” the selector back to 70 px unless glow clipping is handled another way.

---

## 13. There is no `Colors.background`

Authoritative singleton properties are:

```text
red
orange
yellow
green
omnitrix
cyan
blue
magenta
white
black
dark
```

An intermediate assistant-generated snippet mistakenly used `Colors.background`. Do not reuse it.

---

## 14. `Colors.black` is deep purple, not literal black

```text
Colors.black = #1B0623
Colors.dark  = #16051F
```

The names are historical/project-specific. Do not replace them with `#000000` simply because of the property name.

---

## 15. Current color values

```text
red       #D16041
orange    #ED981A
yellow    #F2BE4E
green     #9ECE6A
omnitrix  #00F782
cyan      #55CFCA
blue      #5B5FD4
magenta   #C74EC7
white     #DCF3FA
black     #1B0623
dark      #16051F
```

---

## 16. Latest uploaded ChatFeed background opacity is `0.75`

Older versions used values such as `0.85`.

Latest uploaded full ChatFeed had:

```qml
Rectangle {
    id: chatBackground
    anchors.fill: parent
    color: Colors.black
    opacity: 0.75
}
```

The root and message viewport remain transparent.

---

## 17. The chat fallback avatar is `@`, not `ጸ`

The first idea used:

```text
ጸ
```

It could fail to appear because the configured Gohu Nerd Font did not reliably cover the glyph.

The fallback became:

```text
@
```

in a subtle square cyan frame.

The icon was also deliberately dimmed after the first version looked too bright.

---

## 18. Contact hover is visual only

This rule is easy to accidentally destroy by copying AppSelector logic.

AppSelector:

```text
hover may update app selection
```

ContactList:

```text
hover changes appearance only
```

Do not change `selectedIndex` or `selectedConversation` merely because the pointer enters a contact delegate.

---

## 19. Clicking a contact does not automatically enter the composer

Left click currently means:

```text
select contact
keep contact zone active
```

Keyboard Enter/Return/Right means:

```text
activate selected contact
move focus into composer
```

This separation is intentional.

---

## 20. Selected contact stays orange after entering ChatFeed

Persistent selection should remain visually obvious when keyboard focus moves away from ContactList.

Final intended selected state:

```text
background = yellow
name       = orange
preview    = orange
border     = orange
glow       = orange
```

An older ContactList condition changed the selected glow/border to cyan when `keyboardFocused` became false. That is obsolete.

---

## 21. Keep the static header wording

Accepted:

```text
CONTACTS
CONVERSATION(S): <count>
```

Do not dynamically swap between `CONVERSATION` and `CONVERSATIONS` unless requested. The static parenthetical form and colon were explicitly preferred.

---

## 22. Composer Left Arrow is currently normal text navigation

An earlier design considered:

```text
Left Arrow in composer → return to contacts
```

The latest actual ChatFeed does not implement that handler.

Current behavior:

```text
Escape → ContactList
Left   → TextInput cursor movement
```

Do not silently add the older Left-arrow override back.

---

## 23. Final two Session polish changes should be verified in the working tree

Immediately before the Session section was declared essentially finished, two final changes were requested:

```text
1. add assets/Sessions.png beside SESSIONS in AppSelector
2. make typed composer text magenta
```

The intended composer line is:

```qml
color:
    enabled
    ? Colors.magenta
    : Colors.cyan
```

The most recent complete ChatFeed upload predates that one-line change and still showed white enabled text.

Likewise, a full post-change AppSelector source was not uploaded afterward.

So these are **final intended changes that should be verified locally**, not assumptions about the last uploaded snapshots.

---

## 24. Session send support requires CDP-enabled Session Desktop

If contacts and messages load but sending fails, check this before touching QML:

```bash
flatpak run network.loki.Session \
  --remote-debugging-port=9222 \
  --remote-allow-origins="*"
```

The current send route uses Session Desktop through Chrome DevTools Protocol.

---

## 25. Session reads and sends have different runtime requirements

Current behavior:

```text
read conversations/messages:
    session-cli can use local Session data

send:
    session-cli needs live Session Desktop with CDP
```

A missing CDP listener can therefore create a “reads work, sends fail” state without indicating that `SessionAdapter.qml` is broken.

---

## 26. `session-cli` is third-party

Recorded package:

```text
session-cli 1.7.0
```

Installed under:

```text
~/.local/share/session-cli-venv/
```

Executable:

```text
~/.local/share/session-cli-venv/bin/session-cli
```

Do not call it an official Session Foundation CLI.

---

## 27. The direct SQLCipher route was intentionally abandoned

We already investigated manual local database access and hit encryption/HMAC/decryption problems.

Do not reopen that path merely because it looks architecturally “cleaner.” It would make the rice responsible for Session's private storage implementation and crypto details.

The third-party CLI boundary is the working maintainable route today.

---

## 28. The patched preload/local bridge route was intentionally abandoned

We also inspected and patched an extracted Session preload/application resource, including a bridge concept around a function like:

```text
window.getMessagingConversations
```

That work proved some internal integration was possible but was rejected because it is brittle across Session updates, Flatpak packaging, sandbox changes, and Electron internals.

Do not start there again unless every cleaner backend path disappears.

---

## 29. Use the venv Python when inspecting `session_controller`

System Python produced:

```text
ModuleNotFoundError: No module named 'session_controller'
```

Use:

```bash
~/.local/share/session-cli-venv/bin/python3
```

or directly inspect the venv site-packages.

---

## 30. Use `/usr/bin/grep` when GNU grep behavior matters

The interactive `grep` command can be wrapped/aliased to ripgrep.

Observed failure:

```text
rg: unrecognized flag -R
```

Reliable:

```bash
/usr/bin/grep -RniE ...
```

---

## 31. Quote heredocs containing QML `!`

Raw QML can contain expressions like:

```qml
!keyboardActive
```

In zsh, an unquoted heredoc may perform history expansion and produce:

```text
zsh: event not found
```

Use:

```bash
cat > file.qml <<'EOF'
...
EOF
```

The quoted delimiter is important.

---

## 32. Terminal clipping is not proof of file corruption

Long QML lines can be visually clipped in a narrow Zellij/terminal pane.

Do not rewrite a file because a ternary or import looks cut off on-screen.

Verify with actual file output (`nl`, `sed`, editor wrapping, etc.).

---

## 33. Stale `Sessions.qml` imports caused warnings

At one point imports such as:

```qml
import "modules"
import "../../messanger"
```

resolved incorrectly from the module's directory and produced Quickshell scanner warnings.

They were cleanup problems, not the native SIGSEGV cause.

Keep only imports that actually resolve from the current file location.

---

## 34. Known unrelated Quickshell warnings remain worth cleaning later

Observed warnings included:

```text
Network.qml: Cannot anchor to an item that isn't a parent or sibling.
Workspaces.qml: Cannot read property 'length' of undefined.
Network.qml: unable to assign undefined to typed values.
ShaderEffect/member warnings.
```

These were present around the crash investigation but were not supported by the coredump as the messaging crash trigger.

---

## 35. Current backend index assumptions are fragile

Today:

```text
0 = Session
1 = Discord
2 = Telegram
```

`MessagingW.qml` still contains repeated checks like:

```qml
appSelector.selectedIndex === 0
```

If the AppSelector is reordered before a backend registry/current-adapter abstraction is added, the UI may silently point at the wrong service.

Generalize this during Discord work.

---

## 36. `sendSuccessSerial` is deliberate

Do not replace this with “clear the text immediately when Send is clicked.”

Current behavior:

```text
press Send
→ backend attempts send
→ success serial increments only on confirmed success
→ composer clears
```

If the send fails, the user's typed text remains available.

Future adapters should preserve this contract.

---

## 37. Session polling is expected today

Current intervals:

```text
conversations: 5 seconds
messages:      3 seconds
```

A future backend can use events/websockets internally without requiring ChatFeed to change.

---

## 38. Do not flatten Power-style and Clock-style glow into one effect

Messaging borrowed two related but distinct visual patterns:

```text
Power:
    state colors / selection behavior reference

Clock/workspace:
    broader layered RectangularShadow glow
```

AppSelector's broad glow was explicitly preferred after experimentation.

---

## 39. Right-click actions are still placeholders

Contact right-click currently logs/does little useful work.

The Sessions launcher also has an alternate/right-click placeholder path.

Do not interpret those as broken backend functionality.

---

## 40. Source-of-truth rule

When versions disagree:

```text
latest explicitly accepted behavior
    > latest uploaded source
    > older uploaded source
    > historical dossier
```

Read `07_SOURCE_OF_TRUTH_AND_DIFF_NOTES.md` before restoring a historical file.

---

## 41. Before starting Discord

Run this checklist:

```text
[ ] Session contacts still load
[ ] Session messages still load
[ ] Session send works with CDP-enabled desktop client
[ ] messaging menu survives repeated open/close
[ ] messaging draws over Power
[ ] selected contact stays orange while composer has focus
[ ] AppSelector Session icon exists
[ ] typed composer text is magenta
[ ] current QML directory is backed up or committed
```

If all of those are true, there is a strong known-good baseline before adding a second backend.


<!-- ===== END 05_RECOVERY_GOTCHAS_AND_FORGOTTEN_DETAILS.md ===== -->

<!-- ===== BEGIN 06_CURRENT_STATE_HANDOFF.md ===== -->

# Current State Handoff — Start Here Next Session

**Snapshot date:** 2026-09-10  
**Next planned work:** Discord

This is the shortest useful restart document. Read this first tomorrow, then open the deeper files only when needed.

---

## 1. Where the project stands

The Session section is considered essentially complete.

Current architecture:

```text
modules/Sessions.qml
        │
        ▼
widgets/messanger/MessagingW.qml
        ├── AppSelector.qml
        ├── ContactList.qml
        └── ChatFeed.qml
                 │
                 ▼
services/messaging/SessionAdapter.qml
                 │
                 ▼
             session-cli
```

Real Session conversations and messages were displayed, and real message sending through the Quickshell composer was confirmed.

---

## 2. Files that matter most

```text
modules/Sessions.qml

widgets/messanger/AppSelector.qml
widgets/messanger/ContactList.qml
widgets/messanger/ChatFeed.qml
widgets/messanger/MessagingW.qml

services/messaging/SessionAdapter.qml

components/Colors.qml
assets/Sessions.png
```

Remember the folder is spelled:

```text
messanger
```

---

## 3. MessagingW accepted baseline

The final accepted root needs:

```qml
import Quickshell.Wayland
```

and inside `PanelWindow`:

```qml
WlrLayershell.layer: WlrLayer.Overlay
```

Geometry:

```text
implicitWidth: 900
implicitHeight: 1355
anchor: bottom-right
bottom margin: 80
right margin: 10
exclusiveZone: 0
```

Columns:

```text
AppSelector = 110 px
ContactList = 200 px
ChatFeed    = remaining width
```

---

## 4. Do not break the crash workaround

The root native window stays alive:

```qml
visible: true
focusable: menuOpen
```

Only the inner content is hidden:

```qml
Item {
    id: messagingContent
    anchors.fill: parent
    visible: messagingWindow.menuOpen
}
```

Closed input area collapses through:

```qml
mask: Region {
    width:
        messagingWindow.menuOpen
        ? messagingWindow.width
        : 0

    height:
        messagingWindow.menuOpen
        ? messagingWindow.height
        : 0
}
```

**Never change the root back to `visible: menuOpen` without deliberately re-evaluating the native crash.**

---

## 5. Why the Overlay layer is there

The Power module is a different native `PanelWindow`.

The messaging window originally appeared underneath the Power button where the two surfaces overlapped.

This was not a placement issue and cannot be fixed with child `z` values.

The accepted solution:

```qml
WlrLayershell.layer: WlrLayer.Overlay
```

The user explicitly confirmed the result was correct.

---

## 6. Focus zones

```qml
readonly property int appZone: 0
readonly property int contactZone: 1
readonly property int chatZone: 2
```

Flow:

```text
AppSelector
    │ Enter / Right
    ▼
ContactList
    │ Enter / Right
    ▼
Composer
```

Back navigation:

```text
ContactList Left/Escape → AppSelector
Composer Escape         → ContactList
```

Current ChatFeed does **not** override Left Arrow in the composer, so Left remains normal text cursor movement.

---

## 7. AppSelector current behavior

Apps:

```text
0 SESSIONS
1 DISCORD
2 TELEGRAM
```

Session is currently the only live backend.

State language:

```text
idle     deep purple + cyan
hover    yellow + orange
selected yellow + orange
pressed  magenta + black
```

The selector region is 110 px wide while buttons are 70 px so broad glow has room.

Final intended Session polish:

```text
assets/Sessions.png
small icon beside SESSIONS
```

Because a full AppSelector file was not uploaded after that last tweak, verify it is actually saved in the working tree.

---

## 8. ContactList behavior to preserve

Critical rule:

```text
hover != selection
```

Mouse hover is visual only.

Left click:

```text
select contact
stay in contact focus zone
```

Enter/Return/Right:

```text
activate selected contact
focus composer
```

Header wording:

```text
CONTACTS
CONVERSATION(S): <count>
```

Keep `CONVERSATION(S):` static.

Selected row stays:

```text
yellow background
orange text
orange preview
orange border
a persistent orange glow
```

even after keyboard focus moves into the composer.

---

## 9. ChatFeed current visual baseline

Latest complete uploaded ChatFeed:

```text
root: transparent
background: Colors.black at opacity 0.75
header: 60 px, Colors.dark
fallback avatar: 32x32 square @
message viewport: transparent
incoming messages: cyan
outgoing messages: orange
composer: Colors.dark
focused composer border/glow: orange
full frame: 1 px cyan
```

The fallback avatar changed from `ጸ` to `@` because the former could disappear with the configured font. Its glow was also reduced because the first version was too bright.

---

## 10. Final typed-text color request

Immediately before stopping Session work, typed composer text was changed/intended to be:

```qml
color:
    enabled
    ? Colors.magenta
    : Colors.cyan
```

The `MESSAGE...` placeholder remains cyan.

The last full ChatFeed upload predates that one-line change, so verify it locally tomorrow.

---

## 11. Session backend operational facts

CLI:

```text
~/.local/share/session-cli-venv/bin/session-cli
```

Recorded CLI version:

```text
1.7.0
```

This is a **third-party** CLI, not official Session Foundation software.

List conversations:

```bash
~/.local/share/session-cli-venv/bin/session-cli --json list
```

Read messages:

```bash
~/.local/share/session-cli-venv/bin/session-cli \
  --json messages "$CONVO_ID" --limit 20
```

Session test conversation used during development:

```text
Noiva
```

---

## 12. Session sending requirement

Sending requires Session Desktop running with CDP:

```bash
flatpak run network.loki.Session \
  --remote-debugging-port=9222 \
  --remote-allow-origins="*"
```

Useful diagnostic:

```text
contacts/messages work + send fails
    → first check whether Session Desktop was launched with CDP
```

Reading and sending do not have identical runtime requirements.

---

## 13. Session adapter behavior

Important exposed send state:

```qml
property bool sending: false
property string sendError: ""
property int sendSuccessSerial: 0
signal messageSent()
```

Current polling:

```text
conversations every 5 s
messages every 3 s
```

Messages are normalized oldest-to-newest for display.

On successful send, the adapter refreshes messages/conversations and increments `sendSuccessSerial`.

---

## 14. Why the composer waits for `sendSuccessSerial`

Current flow:

```text
user presses Send
→ ChatFeed remembers current serial
→ adapter attempts send
→ success increments serial
→ ChatFeed clears input and restores focus
```

Failure does not clear the typed text.

Preserve this behavior when Discord is added.

---

## 15. Things already tried and abandoned for Session

Do not restart these by default:

```text
manual SQLCipher/database decryption
patched Session preload / custom localhost bridge
```

Both were explored. The first ran into decryption/HMAC problems; the second was too coupled to Electron/Flatpak internals and update-fragile.

The working boundary is `session-cli` behind `SessionAdapter.qml`.

---

## 16. Current hard-coded backend mapping

`MessagingW.qml` still contains mappings such as:

```qml
conversations:
    appSelector.selectedIndex === 0
    ? sessionAdapter.conversations
    : []
```

and equivalent conditions for messages/loading/errors/sending/send-success.

That was intentionally simple while only Session was live.

Discord is the right time to centralize this into a `currentAdapter` or backend registry.

---

## 17. First Discord milestone

Do **not** start by redesigning the frontend.

Start outside QML:

```text
1. identify a maintainable Discord integration route
2. prove target/conversation/channel listing
3. prove message reading
4. prove message sending
5. understand auth and live-update behavior
6. only then create DiscordAdapter.qml
```

Then wire Discord into the same ContactList and ChatFeed.

---

## 18. Recommended first architecture refactor during Discord work

Conceptually introduce:

```qml
readonly property var currentAdapter:
    appSelector.selectedIndex === 0
    ? sessionAdapter
    : appSelector.selectedIndex === 1
    ? discordAdapter
    : null
```

Then generic bindings become:

```qml
conversations:
    currentAdapter
    ? currentAdapter.conversations
    : []
```

Test the exact QML object-reference pattern in the installed Quickshell/Qt version rather than assuming every JS/QML object arrangement is valid.

---

## 19. Known unrelated warnings

Do not mistake these for a regression in the messaging backend:

```text
Network.qml invalid anchor warning
Workspaces.qml undefined .length warning
Network.qml undefined assignment warnings
ShaderEffect warnings
```

They are separate cleanup work.

---

## 20. Tomorrow-start checklist

Before changing anything:

```text
[ ] back up / commit the current config
[ ] verify Session icon is present in AppSelector
[ ] verify composer typed text is magenta
[ ] open/close messaging repeatedly and confirm no crash
[ ] confirm messaging draws over Power
[ ] confirm Session conversations load
[ ] confirm Session message history loads
[ ] launch Session with CDP and confirm one send
[ ] confirm selected contact remains orange in composer
[ ] confirm Escape returns composer → contacts
```

If all pass, freeze that as the Session baseline and begin Discord adapter research.


<!-- ===== END 06_CURRENT_STATE_HANDOFF.md ===== -->

<!-- ===== BEGIN 07_SOURCE_OF_TRUTH_AND_DIFF_NOTES.md ===== -->

# Source of Truth and Diff Notes

**Snapshot date:** 2026-09-10

This ledger exists because several complete files were uploaded during different stages of the project, and a few important final fixes happened **after** the most recent full upload of a component.

A syntactically complete older file can therefore still be wrong for the current project.

---

## 1. Precedence rule

When sources disagree, use this order:

```text
1. explicitly accepted final behavior/change
2. newest uploaded/pasted source
3. older uploaded/pasted source
4. historical project dossier
```

The dossier is context and history, not an automatic replacement for current files.

---

## 2. MessagingW: malformed Overlay edit vs accepted final fix

The last uploaded MessagingW during the stacking edit briefly contained this invalid arrangement:

```qml
import QtQuick
import Quickshell
import "../../components"
import "../../services/messaging"
import QtQuick.Effects
WlrLayershell.layer: WlrLayer.Overlay
import Qt5Compat.GraphicalEffects
```

Issues:

```text
- WlrLayershell attached property was placed between imports
- Quickshell.Wayland was not imported
```

Final accepted version:

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../components"
import "../../services/messaging"
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: messagingWindow

    WlrLayershell.layer: WlrLayer.Overlay

    ...
}
```

The user confirmed this version as correct.

**Canonical state:** Overlay property inside the PanelWindow, with `Quickshell.Wayland` imported.

---

## 3. MessagingW: `bottom: 150` was not accepted

A screenshot showed the Power button rendering above the messaging panel.

An intermediate suggestion interpreted it as placement and proposed:

```qml
bottom: 150
```

The user correctly clarified:

```text
stacking issue, not placement issue
```

The fix was the Overlay layer, not geometry.

**Canonical geometry:**

```qml
margins {
    top: 0
    bottom: 80
    right: 10
    left: 0
}
```

---

## 4. MessagingW: root visibility changed permanently after the crash

Historical/simple versions used:

```qml
visible: menuOpen
```

That is obsolete.

Final crash-safe design:

```qml
visible: true
focusable: menuOpen
```

plus:

```qml
Item {
    visible: messagingWindow.menuOpen
}
```

and a zero/full dynamic `mask: Region`.

**Canonical state:** root native window always visible/alive.

---

## 5. MessagingW: width changes

Older variants contained values such as:

```text
implicitWidth: 1000
implicitHeight: 700
AppSelector width: 70
ContactList width: 280
```

Current intended values:

```text
implicitWidth: 900
implicitHeight: 1355
appSelectorWidth: 110
contactListWidth: 200
```

The selector's extra width is intentional glow space.

---

## 6. ContactList: selected border/glow no longer depends on keyboard focus

An older complete ContactList used logic equivalent to:

```qml
contactButton.isSelected && contactRoot.keyboardFocused
    ? Colors.orange
    : contactButton.isSelected
    ? Colors.cyan
    : ...
```

The user later clarified the selected row should remain orange after entering the chat feed/composer.

Final intended border:

```qml
border.color:
    contactButton.isPressed
    ? Colors.magenta
    : contactButton.isHovered
    ? Colors.orange
    : contactButton.isSelected
    ? Colors.orange
    : "transparent"
```

Final intended selected glow is also orange regardless of `keyboardFocused`.

**Canonical state:** selected means persistent orange/yellow styling across focus zones.

---

## 7. ContactList: hover must not select

AppSelector hover does change app selection, but ContactList hover does not.

If an older/generalized hover implementation sets:

```qml
selectedIndex = index
```

from `onEntered`, that is wrong for current ContactList semantics.

**Canonical state:** contact hover is visual only.

---

## 8. Contact click vs activation

Current intended mouse behavior:

```text
left click → select contact, stay in contact zone
```

Current keyboard activation:

```text
Enter / Return / Right → activate current contact and focus composer
```

Do not restore any older behavior that automatically moves to the composer on a mouse click unless intentionally redesigned.

---

## 9. Contact header wording

Accepted header:

```text
CONTACTS
CONVERSATION(S): <count>
```

A dynamic singular/plural implementation may look cleaner, but the user explicitly preferred the static parenthetical wording and colon.

**Canonical text:** `CONVERSATION(S):`

---

## 10. ChatFeed background opacity

Historical/current variants used different background opacity values.

The latest complete uploaded ChatFeed uses:

```qml
color: Colors.black
opacity: 0.75
```

Earlier `0.85` descriptions should be treated as old state.

**Canonical uploaded value:** `0.75`.

---

## 11. Chat fallback avatar sequence

### First version

```text
square 34x34-ish icon
ጸ glyph
bright cyan glow
```

### Feedback

The icon was too bright, then the glyph was not reliably visible.

### Latest complete uploaded ChatFeed

```text
32 × 32
square
transparent interior
1 px cyan border at opacity ~0.65
very faint cyan glow ~0.15
@ glyph
```

**Canonical fallback glyph:** `@`.

---

## 12. ChatFeed typed text: upload vs final intent

Latest complete uploaded ChatFeed still contains:

```qml
color:
    enabled
    ? Colors.white
    : Colors.cyan
```

After that upload, the user requested:

```text
make the text you input into the text bar magenta
```

Final intended line:

```qml
color:
    enabled
    ? Colors.magenta
    : Colors.cyan
```

The user then considered the Session section essentially finished.

Because no full post-change ChatFeed was uploaded afterward:

```text
STATUS = FINAL INTENDED / VERIFY LOCAL WORKING TREE
```

Do not falsely claim the last uploaded ChatFeed already contains magenta input.

---

## 13. AppSelector Session icon: upload vs final intent

Before the last polish request, AppSelector contained entries for:

```text
SESSIONS
DISCORD
TELEGRAM
```

Then the user requested an icon for the Session button.

Final intended addition:

```text
assets/Sessions.png
```

shown as a small icon beside `SESSIONS`.

A full post-change AppSelector file was not uploaded after that request.

```text
STATUS = FINAL INTENDED / VERIFY LOCAL WORKING TREE
```

---

## 14. AppSelector glow should not be reverted to the wrong style

During visual iteration, AppSelector settled on:

```text
Power-style interaction colors
+
Clock/workspace-style broad two-layer RectangularShadow glow
```

The user explicitly said the broader version was better.

Do not replace it with only the Power menu's single smaller `DropShadow` unless specifically requested.

---

## 15. Composer Left Arrow: old plan vs actual current source

At one point navigation planning considered:

```text
Left Arrow in message input → return to contacts
```

The latest authoritative ChatFeed does not contain `Keys.onLeftPressed`.

Current actual/intended behavior is therefore:

```text
Escape → contacts
Left   → normal cursor movement
```

Unless a future explicit request changes this, do not reintroduce the older plan.

---

## 16. `Colors.background` is never canonical

An intermediate assistant answer accidentally used:

```qml
Colors.background
```

The authoritative singleton has no such property.

Use actual palette names such as:

```qml
Colors.black
Colors.dark
```

depending on the surface.

---

## 17. Current authoritative Colors singleton

```qml
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
```

`Colors.black` is deep purple, not literal black.

---

## 18. Sessions launcher toggle

Older launcher code directly toggled:

```qml
messagingWindow.menuOpen =
    !messagingWindow.menuOpen;
```

During crash debugging, a guarded deferred form was introduced:

```qml
Qt.callLater(function() {
    if (!sessionsDock.messagingWindow)
        return;

    sessionsDock.messagingWindow.menuOpen =
        !sessionsDock.messagingWindow.menuOpen;
});
```

Important nuance:

```text
Qt.callLater alone did not solve the native crash.
```

But the guarded form is still the preferred launcher code for now.

---

## 19. Session backend current index

Current mapping:

```text
0 = Session
1 = Discord
2 = Telegram
```

Current `MessagingW.qml` still uses Session-specific ternaries based on index `0`.

This should be generalized during Discord integration.

Until then, do not reorder the AppSelector list casually.

---

## 20. Session CLI status

Working/current integration boundary:

```text
third-party session-cli
```

Recorded version:

```text
1.7.0
```

Venv:

```text
~/.local/share/session-cli-venv/
```

Executable:

```text
~/.local/share/session-cli-venv/bin/session-cli
```

Manual SQLCipher and patched-preload approaches are historical, not current architecture.

---

## 21. Session read/send split

Canonical operational rule:

```text
READ:
    local data through session-cli

SEND:
    Session Desktop must be running with CDP flags
```

CDP launch:

```bash
flatpak run network.loki.Session \
  --remote-debugging-port=9222 \
  --remote-allow-origins="*"
```

---

## 22. Session message order

The UI expects:

```text
oldest → newest
```

Adapter normalization should preserve that even if a backend naturally returns newest-first.

Do not move Session-specific sorting into ChatFeed.

---

## 23. Polling values

Current accepted Session polling:

```text
conversations = 5 seconds
messages      = 3 seconds
```

Future event-driven adapters can internally behave differently without changing the generic UI.

---

## 24. Historical dossier usage

Use the dossier for:

```text
visual philosophy
palette history
Power interaction language
Clock/workspace glow language
older module context
rice-wide architecture
```

Do not use it as a literal current `MessagingW.qml` replacement.

---

## 25. Recommended local verification commands

Because the last two visual tweaks were not followed by new full-file uploads, verify the actual working tree before Discord work:

```bash
/usr/bin/grep -n "Sessions.png" \
  ~/.config/quickshell/widgets/messanger/AppSelector.qml

/usr/bin/grep -n "Colors.magenta" \
  ~/.config/quickshell/widgets/messanger/ChatFeed.qml

/usr/bin/grep -n "Quickshell.Wayland" \
  ~/.config/quickshell/widgets/messanger/MessagingW.qml

/usr/bin/grep -n "WlrLayer.Overlay" \
  ~/.config/quickshell/widgets/messanger/MessagingW.qml

/usr/bin/grep -n "visible: true" \
  ~/.config/quickshell/widgets/messanger/MessagingW.qml

/usr/bin/grep -n "contactListWidth" \
  ~/.config/quickshell/widgets/messanger/MessagingW.qml
```

Expected important results:

```text
AppSelector contains Sessions.png
ChatFeed enabled input uses Colors.magenta
MessagingW imports Quickshell.Wayland
MessagingW sets WlrLayer.Overlay inside PanelWindow
MessagingW root stays visible: true
contactListWidth is 200
```

---

## 26. Biggest recovery warning

A complete older QML file is especially dangerous because it looks trustworthy.

Restoring one can silently reintroduce:

```text
root PanelWindow visibility crash
Power stacking bug
280 px contact width
70 px selector clipping
cyan selected-contact state after focus moves
missing Session icon
white composer input text
old avatar/glow
```

Use this ledger before replacing a current component with any historical copy.


<!-- ===== END 07_SOURCE_OF_TRUTH_AND_DIFF_NOTES.md ===== -->
