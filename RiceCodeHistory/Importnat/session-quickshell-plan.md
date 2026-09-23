# Session Desktop → Quickshell Messaging Integration
## Investigation Plan, Findings, Architecture, and Current Checkpoint

> **Purpose:** This document is a recovery/context file. If the chat runs out of context, feed this Markdown back to ChatGPT so work can resume from the exact point reached here.
>
> **Current goal:** Make Quickshell's `ContactList.qml` show real Session Desktop conversations/contact names and eventually support messaging through a reusable `SessionAdapter`, without unnecessarily reimplementing Session's encrypted database layer.

---

# 1. Overall Goal

The Quickshell rice has a messaging window with three main areas:

```text
┌──────────────┬────────────────────┬──────────────────────────────┐
│ App Selector │ Contact List       │ Chat Feed                    │
│              │                    │                              │
│ SESSIONS     │ Friend/contact     │ Messages                     │
│ DISCORD      │ conversations      │                              │
│ TELEGRAM     │ conversations      │                              │
│              │                    │                              │
└──────────────┴────────────────────┴──────────────────────────────┘
```

The immediate backend target is **Session Desktop**.

The desired architecture is:

```text
Quickshell UI
    │
    ▼
SessionAdapter.qml
    │
    ▼
small local bridge / adapter
    │
    ▼
Session Desktop's existing APIs/data layer
    │
    ▼
Session's ConversationModel / ConvoHub
    │
    ▼
Session's SQLCipher database
```

The important design principle is:

> **Use Session's own data layer where possible instead of independently reverse-engineering/decrypting its database.**

---

# 2. Quickshell Architecture

Current Quickshell structure:

```text
~/.config/quickshell/
├── archive/
├── assets/
├── components/
├── modules/
├── services/
│   └── messaging/
│       └── SessionAdapter.qml
├── widgets/
│   └── messanger/
│       ├── AppSelector.qml
│       ├── ChatFeed.qml
│       ├── ContactList.qml
│       └── MessagingW.qml
└── shell.qml
```

Note the directory spelling:

```text
messanger
```

(one `e` after the `g`).

The intended separation is:

```text
widgets/messanger/
    UI only

services/messaging/
    service adapters / backend integration
```

Eventually the messaging service layer may become:

```text
services/messaging/
├── MessagingBackend.qml
├── SessionAdapter.qml
├── DiscordAdapter.qml
├── TelegramAdapter.qml
└── SignalAdapter.qml
```

Do **not** implement all of this yet. Session is the current investigation target.

---

# 3. Messaging Window

Current `MessagingW.qml` is a `PanelWindow`.

The working basic structure was:

```qml
import QtQuick
import Quickshell
import "../../components"
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

PanelWindow {
    id: messagingWindow

    property bool menuOpen: false

    implicitWidth: 1000
    implicitHeight: 700

    color: "transparent"
    surfaceFormat.opaque: false
    focusable: true
    visible: menuOpen

    property int appSelectorWidth: 70
    property int contactListWidth: 280

    AppSelector {
        id: appSelector
        width: messagingWindow.appSelectorWidth
        height: parent.height
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        z: 3
    }

    ContactList {
        id: contactList
        width: messagingWindow.contactListWidth
        height: parent.height
        anchors.left: appSelector.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        z: 2
    }

    ChatFeed {
        id: chatFeed
        anchors.left: contactList.right
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        z: 1
    }
}
```

Temporary colors/z-order were used while debugging geometry. The three-column layout worked.

---

# 4. Keyboard Handling — WORKING

Direct `Keys` handlers on the `PanelWindow` did not work reliably.

The working solution is a focusable `Item` inside `MessagingW.qml`:

```qml
Item {
    id: keyboardFocus
    anchors.fill: parent
    focus: messagingWindow.menuOpen

    Keys.onEscapePressed: {
        messagingWindow.menuOpen = false
    }

    Keys.onUpPressed: {
        if (appSelector.selectedIndex > 0) {
            appSelector.selectedIndex--
        } else {
            appSelector.selectedIndex =
                appSelector.messagingApps.length - 1
        }
    }

    Keys.onDownPressed: {
        if (appSelector.selectedIndex <
            appSelector.messagingApps.length - 1) {
            appSelector.selectedIndex++
        } else {
            appSelector.selectedIndex = 0
        }
    }

    Keys.onReturnPressed: {
        console.log(
            "Selected:",
            appSelector.messagingApps[
                appSelector.selectedIndex
            ].name
        )
    }

    Keys.onEnterPressed: {
        console.log(
            "Selected:",
            appSelector.messagingApps[
                appSelector.selectedIndex
            ].name
        )
    }

    z: 100
}

onMenuOpenChanged: {
    if (menuOpen) {
        keyboardFocus.forceActiveFocus()
    }
}
```

**Do not replace this with direct `PanelWindow` Keys handlers unless there is a reason.**

Mouse clicks still work even though the focus item has high `z`.

---

# 5. Sessions Launcher

`shell.qml` currently wires the messaging window roughly as:

```qml
Sessions {
    x: 1963
    y: 8
    messagingWindow: messagingWindow
}

MessagingW {
    id: messagingWindow
}
```

`Sessions` left click toggles:

```qml
messagingWindow.menuOpen = !messagingWindow.menuOpen;
```

The `Sessions` module is therefore a launcher/button for the messaging menu, not a logout/session-management module.

Right-click is currently reserved for a future function.

---

# 6. AppSelector

Current `AppSelector.qml` uses:

```qml
property int selectedIndex: 0

property var messagingApps: [
    { name: "SESSIONS" },
    { name: "DISCORD" },
    { name: "TELEGRAM" }
]
```

Current visual/state model:

- idle:
  - black background
  - cyan text
  - no glow
- hover:
  - yellow background
  - orange text
  - orange glow
- selected:
  - yellow background
  - orange text
  - orange glow
- pressed:
  - magenta background
  - black text
  - magenta glow

This was based on the existing Power menu and Clock component.

Clock-derived glow values:

```text
button size: 151 x 50
text size: 20px
DropShadow radius: 14
DropShadow samples: 15
text pressed opacity: 1.0
text hover opacity: 0.8
text idle: 0.0 for messaging selection
RectangularShadow spread: 3
  pressed: 0.6
  hover: 0.5
  idle: 0.0
RectangularShadow spread: 10
  pressed: 0.12
  hover: 0.09
  idle: 0.0
```

Power menu is the source of truth for the state/color logic.

---

# 7. Visual Theme

Main palette:

```text
background  #1B0623
cyan        #55CFCA
orange      #ED981A
yellow/gold #F2BE4E
white       #DCF3FA
red         #D16041
indigo      #5B5FD4
magenta     #C74EC7
green       #9ece6a
```

Style:

- deep purple foundation
- cyan interface/information
- orange active/focus
- gold/yellow selection/emphasis
- magenta special/pressed
- red destructive
- pale cyan/white neutral
- strong glow
- square or barely rounded
- monospace/pixel/terminal aesthetic

Font commonly used:

```text
GohuFont 11 Nerd Font Mono
```

---

# 8. Session Desktop Installation

Session Desktop is installed as a Flatpak:

```text
Session Desktop
network.loki.Session
version 1.18.1
stable
flathub
system
```

Running:

```bash
which session
```

returns no executable.

The Flatpak contains:

```text
/app/Session/session-desktop
```

and other Electron/Chromium executables.

Session reports Electron version:

```text
Electron 40.0.0
```

The application is currently running normally through Flatpak.

---

# 9. Session Data Location

Session's Flatpak config/data location is:

```text
~/.var/app/network.loki.Session/config/Session/
```

Database files:

```text
~/.var/app/network.loki.Session/config/Session/sql/db.sqlite
~/.var/app/network.loki.Session/config/Session/sql/db.sqlite-wal
~/.var/app/network.loki.Session/config/Session/sql/db.sqlite-shm
```

Observed approximate sizes during investigation:

```text
db.sqlite       ~2.7 MB
db.sqlite-wal   ~4.6 MB
db.sqlite-shm   ~32 KB
```

The main Session process has the database open:

```text
session-d 38682 ... db.sqlite
session-d 38682 ... db.sqlite-wal
```

This is important because Session is actively using the DB/WAL.

---

# 10. Database Is NOT Plain SQLite

Attempting:

```bash
sqlite3 ~/.var/app/network.loki.Session/config/Session/sql/db.sqlite '.tables'
```

returned:

```text
Error: file is not a database
```

`file db.sqlite` reports:

```text
data
```

The first bytes were:

```text
7b 69 f6 07 ea a6 81 01 25 5e 66 f8 4c 5e ce ea
95 dd ba 38 f6 f9 9a ac 81 06 76 bb 20 c3 83 a6
```

It does not contain the normal SQLite header:

```text
SQLite format 3
```

Conclusion:

> Session's DB is encrypted/obfuscated and should not be treated as ordinary SQLite.

---

# 11. Session Uses SQLCipher

Source inspection established that Session Desktop uses SQLCipher.

Relevant architecture:

```text
Session Desktop
    │
    ▼
@signalapp/sqlcipher
    │
    ▼
native SQLCipher addon
    │
    ▼
encrypted db.sqlite
```

The installed package:

```text
@signalapp/sqlcipher
version 3.1.0
```

Package characteristics:

```text
type: module
main: dist/index.cjs
```

Dependencies include:

```text
node-addon-api
node-gyp-build
```

Native prebuild found inside the Flatpak:

```text
/app/Session/resources/app.asar.unpacked/node_modules/@signalapp/sqlcipher/prebuilds/linux-x64/@signalapp+sqlcipher.node
```

Approximate size:

```text
2.2 MB
```

It is an ELF x86-64 native library.

Its CJS wrapper uses:

```js
const addon = node-gyp-build(ROOT_DIR);
```

and opens the DB through the native addon.

---

# 12. Session's Native libsession Utility

Inside the Flatpak:

```text
/app/Session/resources/app.asar.unpacked/node_modules/libsession_util_nodejs/
```

exists.

Native addon:

```text
/app/Session/resources/app.asar.unpacked/node_modules/libsession_util_nodejs/build/Release/libsession_util_nodejs.node
```

Approximate size:

```text
4.85 MB
```

It is also an ELF native addon.

Session therefore has both:

```text
libsession_util_nodejs
@signalapp/sqlcipher
```

inside its packaged application.

---

# 13. Flatpak Shell Findings

Running:

```bash
flatpak run --command=sh network.loki.Session
```

opens a minimal shell inside the Flatpak.

Inside it:

```bash
node --version
```

returned:

```text
sh: node: command not found
```

So there is no standalone `node` executable available from the Flatpak shell.

However, the packaged application contains Node/Electron resources and native Node addons.

Important:

> Do NOT launch `/app/Session/session-desktop` directly with `--version` just to inspect it.

Direct invocation bypassed normal Flatpak/Chromium sandbox setup and produced a Chromium SUID sandbox error.

We do **not** want to solve that by chmod'ing anything or disabling the sandbox.

---

# 14. Session Launcher

Inside the Flatpak, the file:

```text
/app/Session/resources/launcher-script.sh
```

contains approximately:

```bash
#!/usr/bin/env bash

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

exec "$SCRIPT_DIR/session-desktop-bin" "$([[ $UNPRIVILEGED_USERNS_ENABLED == 0 ]] && echo '--no-sandbox')" "$@"
```

However:

```text
/app/Session/session-desktop-bin
```

does not exist.

The actual executable is:

```text
/app/Session/session-desktop
```

The launcher script did not provide a useful external bridge.

---

# 15. Session Electron Main Process

Source was extracted to:

```text
/tmp/session-asar/
```

The relevant source tree is:

```text
/tmp/session-asar/ts/
```

The Electron main process is:

```text
/tmp/session-asar/ts/mains/main_node.js
```

Main window configuration contains:

```js
const windowOptions = {
  show: true,
  minWidth,
  minHeight,
  fullscreen: false,
  backgroundColor: colors_1.THEMES.CLASSIC_DARK.COLOR1,
  webPreferences: {
    nodeIntegration: true,
    enableRemoteModule: true,
    nodeIntegrationInWorker: true,
    contextIsolation: false,
    preload: path_1.default.join(
      (0, getRootPath_1.getAppRootPath)(),
      'preload.js'
    ),
    nativeWindowOpen: true,
    spellcheck: await getSpellCheckSetting(),
    backgroundThrottling: false
  },
  ...
};
```

This is significant.

Session's renderer has:

```text
nodeIntegration: true
contextIsolation: false
nodeIntegrationInWorker: true
```

So the renderer/preload environment has substantial Node/Electron integration.

---

# 16. Session Preload

Actual preload file:

```text
/tmp/session-asar/preload.js
```

Main process explicitly loads:

```js
preload: path.join(getAppRootPath(), 'preload.js')
```

The preload starts with:

```js
const { clipboard, ipcRenderer: ipc, webFrame } =
  require('electron/main');
```

It also imports Session internals:

```js
const { Storage } = require('./ts/util/storage');
const { isTestNet, isTestIntegration } =
  require('./ts/shared/env_vars');
const { setupI18n } = require('./ts/util/i18n/i18n');
const { UserUtils } = require('./ts/session/utils');
```

Most importantly:

```js
const data = require('./ts/data/dataInit');
data.initData();
```

The preload also imports:

```js
const { ConvoHub } =
  require('./ts/session/conversations/ConversationController');
```

and exposes:

```js
window.getConversationController = ConvoHub.use;
```

This is currently one of the most promising discoveries.

---

# 17. What Preload Does NOT Expose

A search:

```bash
rg -n \
  "data\.|window\..*data|ConvoHub|initData|callChannel|getAllConversations|getConversationById|getMessagesByConversation|getLastMessagesByConversation" \
  /tmp/session-asar/preload.js
```

found:

```text
256:data.initData();
258:const { ConvoHub } = require('./ts/session/conversations/ConversationController');
273:window.getConversationController = ConvoHub.use;
```

There was no direct:

```text
window.getAllConversations
window.getMessagesByConversation
```

etc.

So:

> The preload initializes the SQL/data IPC system, but does not directly export the `data` API to `window`.

It does export:

```js
window.getConversationController = ConvoHub.use;
```

---

# 18. Session Data IPC Architecture

The file:

```text
/tmp/session-asar/ts/data/dataInit.js
```

was inspected.

It dynamically creates SQL data-channel functions.

Important details:

```js
const channelsToMake = new Set([
  'shutdown',
  'close',
  'removeDB',
  ...
  'getConversationById',
  'getAllConversations',
  ...
  'getMessagesByConversation',
  'getLastMessagesByConversation',
  ...
]);
```

The SQL IPC channel key is:

```js
const SQL_CHANNEL_KEY = 'sql-channel';
```

`makeChannel(fnName)` creates functions that do:

```js
electron.ipcRenderer.send(
  SQL_CHANNEL_KEY,
  jobId,
  fnName,
  ...args
);
```

and wait for:

```text
sql-channel-done
```

The renderer therefore calls SQL operations through Electron IPC.

`initData()` does:

```js
channelsToMake.forEach(makeChannel);
```

and listens for:

```text
sql-channel-done
```

This means the renderer gets an internal API through the dynamic `channels` object.

---

# 19. data/channels.js

The file:

```text
/tmp/session-asar/ts/data/channels.js
```

is basically:

```js
Object.defineProperty(exports, "__esModule", {
  value: true
});

exports.channels = {};
```

Searches for IPC/channel definitions there only found the export.

Conclusion:

> `channels.js` is a dynamic registry. `dataInit.js` populates it at runtime.

---

# 20. SQL Main-Process IPC

The source:

```text
/tmp/session-asar/ts/node/sql_channel.js
```

was inspected.

It listens on Electron main-process IPC for:

```text
sql-channel
```

The basic flow is:

```text
renderer
  │
  │ ipcRenderer.send(
  │   'sql-channel',
  │   jobId,
  │   fnName,
  │   args...
  │ )
  ▼
Electron main process
  │
  │ ipcMain.on('sql-channel', ...)
  ▼
sqlNode[callName]
  │
  ▼
SQLCipher-backed DB function
  │
  ▼
event.sender.send(
    'sql-channel-done',
    jobId,
    error,
    result
)
```

This is an internal Electron IPC channel, not an external Unix socket.

---

# 21. Session SQL Initialization

The relevant file:

```text
/tmp/session-asar/ts/node/sql.js
```

contains:

```js
openAndSetUpSQLCipher(filePath, { key })
```

which calls:

```js
signalMigrations.openAndMigrateDatabase(filePath, key)
```

`initializeSql({ configDir, key, passwordAttempt })` sets the DB path to:

```text
${configDir}/sql/db.sqlite
```

and initializes SQLCipher.

The application therefore owns the correct process of:

```text
locating DB
    ↓
opening SQLCipher
    ↓
keying database
    ↓
migration
    ↓
WAL setup
    ↓
integrity/schema handling
    ↓
global DB instance
```

---

# 22. Session DB Key Handling

In:

```text
/tmp/session-asar/ts/mains/main_node.js
```

the default key is obtained with:

```js
function getDefaultSQLKey() {
  let key = userConfig.get('key');

  if (!key) {
    console.log(
      'key/initialize: Generating new encryption key, since we did not find it on disk'
    );

    key = crypto.randomBytes(32).toString('hex');

    ...
  }

  ...
}
```

Then:

```js
showMainWindow(sqlKey, passwordAttempt = false)
```

calls:

```js
sqlNode.initializeSql({
  configDir: userDataPath,
  key: sqlKey,
  passwordAttempt
});
```

There is also a password-window path:

```js
ipcMain.on('password-window-login', async (event, passPhrase) => {
  const passwordAttempt = true;
  await showMainWindow(passPhrase, passwordAttempt);
});
```

Important security conclusion:

> **Do not print, expose, or manually manipulate the Session encryption key.**

---

# 23. SQLCipher Migration Code

Relevant file:

```text
/tmp/session-asar/ts/node/migration/signalMigrations.js
```

`openAndMigrateDatabase(filePath, key)` attempts SQLCipher DB initialization.

The normal path:

```js
db = new sqlcipher_1.default(filePath, openDbOptions);
keyDatabase(db, key);
switchToWAL(db);
migrateSchemaVersion(db);
db.pragma('secure_delete = ON');
return db;
```

Fallback paths use:

```text
cipher_compatibility = 3
```

and:

```text
cipher_migrate
```

The keying function is:

```js
function keyDatabase(db, key) {
  const deriveKey = database_utility_1.HEX_KEY.test(key);
  const value = deriveKey
    ? `'${key}'`
    : `"x'${key}'"`;

  const pragramToRun = `key = ${value}`;
  db.pragma(pragramToRun);
}
```

WAL setup:

```js
function switchToWAL(db) {
  db.pragma('journal_mode = WAL');
  db.pragma('synchronous = FULL');
}
```

This is another reason not to have Quickshell independently poke the live database.

---

# 24. ConversationController

The file:

```text
/tmp/session-asar/ts/session/conversations/ConversationController.js
```

was inspected.

It imports:

```js
const data_1 = require("../../data/data");
const conversation_1 = require("../../models/conversation");
```

It defines:

```js
const getConvoHub = () => {
  if (instance) {
    return instance;
  }

  instance = new ConvoController();
  return instance;
};
```

The controller stores:

```js
class ConvoController {
  conversations;
  _initialFetchComplete = false;
  _convoHubInitialPromise;

  constructor() {
    this.conversations = [];
  }
}
```

It has methods such as:

```text
get(id)
getOrThrow(id)
getUnsafe(id)
getOrCreate(id, type)
getNicknameOrRealUsernameOrPlaceholder(pubKey)
getOrCreateAndWait(...)
deleteBlindedContact(...)
deleteLegacyGroup(...)
deleteGroup(...)
```

The important methods:

```js
get(id)
```

requires the initial fetch to be complete, then:

```js
return this.conversations.find(m => m.id === id);
```

There is also:

```js
getNicknameOrRealUsernameOrPlaceholder(pubKey)
```

which gets a conversation and calls:

```js
conversation.getNicknameOrRealUsernameOrPlaceholder();
```

---

# 25. Critical ConvoHub Discovery

Search found:

```text
/tmp/session-asar/ts/session/conversations/ConversationController.js:369
```

with:

```js
const convoModels = await data_1.Data.getAllConversations();
```

This is extremely important.

The flow is:

```text
ConvoHub initialization
        │
        ▼
Data.getAllConversations()
        │
        ▼
Session SQL/data IPC
        │
        ▼
SQLCipher DB
        │
        ▼
ConversationModel objects
        │
        ▼
ConvoHub.conversations[]
```

So Session already transforms DB rows into its own conversation models.

That is preferable to directly reading encrypted DB files.

---

# 26. ConvoHub Export

At the bottom of `ConversationController.js`:

```js
exports.ConvoHub = {
  use: getConvoHub
};
```

And preload does:

```js
window.getConversationController = ConvoHub.use;
```

Therefore the renderer has access to:

```js
window.getConversationController()
```

which should return the singleton `ConvoController`.

**This is the current most promising API surface to investigate.**

---

# 27. External IPC Investigation

Session's main process was inspected from the host.

Process:

```text
PID 38682
/app/Session/session-desktop
```

Other Session/Electron processes were also running, including:

```text
zygote
renderer
network utility
audio utility
chrome_crashpad_handler
```

`flatpak ps` showed Session running in the Flatpak runtime.

The main process environment included:

```text
FLATPAK_ID=network.loki.Session
HOME=/var/home/mapple
USER=mapple
XDG_CONFIG_HOME=/var/home/mapple/.var/app/network.loki.Session/config
XDG_DATA_HOME=/var/home/mapple/.var/app/network.loki.Session/data
XDG_CACHE_HOME=/var/home/mapple/.var/app/network.loki.Session/cache
XDG_RUNTIME_DIR=/run/user/1000
XDG_SESSION_DESKTOP=sway
XDG_SESSION_TYPE=wayland
PATH=/app/bin:/app/bin:/usr/bin
```

The process command line is:

```text
/app/Session/session-desktop
```

No obvious Session-specific external Unix socket was found under:

```text
~/.var/app/network.loki.Session/config/Session
```

Searches for:

```text
*.sock
*.socket
*.ipc
```

returned nothing useful.

The DB and WAL are open by Session's main process.

Conclusion so far:

> No obvious external socket/API has been discovered yet.

This does NOT prove there is no external IPC. It only means none has been found in the obvious locations.

---

# 28. Important Security / Safety Constraints

Do NOT:

```text
chmod the Electron/Chromium sandbox
```

Do NOT:

```text
launch Session with --no-sandbox
```

Do NOT:

```text
write/rekey Session's database
```

Do NOT:

```text
modify db.sqlite
```

Do NOT:

```text
print or expose Session's encryption key
```

Do NOT:

```text
kill Session's database process just to inspect the DB
```

Prefer:

```text
read-only
existing Session APIs
existing ConversationModel/ConvoHub
existing Electron process
```

Avoid fighting the WAL or opening the encrypted DB concurrently unless there is no cleaner route.

---

# 29. Why We Are NOT Building a Raw SQLCipher Helper Yet

A tempting approach would be:

```text
Quickshell
   ↓
Node helper
   ↓
@signalapp/sqlcipher
   ↓
key
   ↓
db.sqlite
```

But this has several problems:

1. Need the correct Session DB key.
2. Need to reproduce Session's key handling.
3. Need SQLCipher compatibility/migration behavior.
4. Need to safely deal with WAL.
5. Need to understand schema/version.
6. Session already has an active DB owner.
7. It duplicates Session's own data/model layer.
8. It may break when Session changes internals.

Therefore:

> First try to reuse Session's existing conversation/data layer.

---

# 30. Current Best Candidate Architecture

The most promising route currently looks like:

```text
                 SESSION DESKTOP
┌────────────────────────────────────────────────────┐
│                                                    │
│  Electron main process                             │
│       │                                            │
│       ├── SQLCipher                                │
│       │      │                                     │
│       │      └── encrypted db.sqlite               │
│       │                                            │
│       └── Data.getAllConversations()               │
│                    │                               │
│                    ▼                               │
│              ConversationModel[]                   │
│                    │                               │
│                    ▼                               │
│                 ConvoHub                            │
│                    │                               │
│       preload: window.getConversationController   │
│                    │                               │
└────────────────────┼───────────────────────────────┘
                     │
                     ▼
             local bridge/helper
                     │
                     ▼
             SessionAdapter.qml
                     │
                     ▼
              ContactList.qml
```

The exact bridge mechanism is **not decided yet**.

---

# 31. Current Investigation Checklist

## Phase 1 — Storage
Status: **DONE**

- [x] Find Session installation.
- [x] Find Flatpak data directory.
- [x] Find `db.sqlite`.
- [x] Confirm DB is actively used.
- [x] Confirm WAL is actively used.

## Phase 2 — Database Internals
Status: **DONE**

- [x] Confirm DB is not ordinary SQLite.
- [x] Identify SQLCipher.
- [x] Find `@signalapp/sqlcipher`.
- [x] Find native SQLCipher addon.
- [x] Find `libsession_util_nodejs`.
- [x] Find DB key initialization.
- [x] Find migration/compatibility handling.
- [x] Find WAL behavior.

## Phase 3 — Session Data API
Status: **MOSTLY DONE**

- [x] Find `dataInit.js`.
- [x] Find `SQL_CHANNEL_KEY`.
- [x] Find `getAllConversations`.
- [x] Find `getConversationById`.
- [x] Find `getMessagesByConversation`.
- [x] Find `getLastMessagesByConversation`.
- [x] Find main-process SQL IPC.
- [x] Find `Data.getAllConversations()` use in ConversationController.
- [ ] Determine exact conversation object fields needed by ContactList.
- [ ] Determine how names/nicknames are represented.
- [ ] Determine how unread/last-message data is represented.

## Phase 4 — Renderer / Electron Bridge
Status: **CURRENT**

- [x] Find main window config.
- [x] Confirm `nodeIntegration: true`.
- [x] Confirm `contextIsolation: false`.
- [x] Find preload.
- [x] Confirm preload calls `data.initData()`.
- [x] Confirm preload exposes `window.getConversationController`.
- [ ] Determine exactly what `window.getConversationController()` returns in the running renderer.
- [ ] Determine whether the renderer can access `controller.conversations`.
- [ ] Determine whether those ConversationModel objects can be serialized to an external bridge.
- [ ] Determine a safe bridge mechanism.

## Phase 5 — External API / IPC
Status: **PARTIALLY DONE**

- [x] Inspect obvious config sockets.
- [x] Inspect Session processes.
- [x] Inspect process environment.
- [x] Confirm DB file handles.
- [ ] Search for localhost listening ports.
- [ ] Search for additional Electron IPC mechanisms useful to an external helper.
- [ ] Check D-Bus only if evidence suggests Session exposes something there.
- [ ] Check command-line IPC if evidence appears.
- [ ] Avoid assuming Electron IPC can be called directly from an unrelated process.

## Phase 6 — Choose Bridge
Status: **NOT STARTED**

Potential options, in preferred order:

1. Existing Session renderer/API bridge.
2. Small Session-side helper/bridge using existing Electron runtime.
3. A safe local IPC interface created by a helper.
4. Direct SQLCipher helper only as a last resort.

## Phase 7 — SessionAdapter
Status: **NOT STARTED**

Eventually implement:

```text
services/messaging/SessionAdapter.qml
```

It should provide normalized data to the UI.

Potential normalized fields:

```text
id
name
nickname
type
lastMessage
timestamp
unreadCount
avatar/profile data
```

Only include fields that Session actually provides.

## Phase 8 — ContactList
Status: **NOT STARTED**

Replace hardcoded names with real Session data.

Potential flow:

```text
SessionAdapter
    ↓
ContactList
    ↓
Repeater/ListView
    ↓
real conversations
```

## Phase 9 — ChatFeed
Status: **NOT STARTED**

Eventually:

```text
selected conversation
    ↓
SessionAdapter
    ↓
messages
    ↓
ChatFeed
```

## Phase 10 — Sending
Status: **NOT STARTED**

Only after reading works reliably.

---

# 32. Immediate Next Step

The last command output we inspected was `ConversationController.js`.

The next thing to inspect is the initialization around line 335–395:

```bash
sed -n '335,395p' /tmp/session-asar/ts/session/conversations/ConversationController.js
```

Then inspect `ConversationModel`:

```bash
rg -n \
  "class ConversationModel|getConversationModelProps|getNicknameOrRealUsernameOrPlaceholder|displayName|name|nickname|profile" \
  /tmp/session-asar/ts/models/conversation.js
```

Then:

```bash
sed -n '1,260p' /tmp/session-asar/ts/models/conversation.js
```

The goal is to determine:

```text
What does each ConversationModel contain?
How is the contact's display name determined?
Where is nickname/name/profile information stored?
How are last messages/unread state represented?
```

Do **not** start writing `SessionAdapter.qml` until this is understood.

---

# 33. Current Exact Checkpoint

At the moment this document was created:

```text
Quickshell UI                         DONE / WORKING
    │
    ▼
MessagingW                           DONE / WORKING
    │
    ▼
AppSelector                           DONE / WORKING
    │
    ▼
ContactList                           PLACEHOLDER
    │
    ▼
SessionAdapter                        EMPTY
    │
    ▼
Session Desktop                      INSTALLED + RUNNING
    │
    ▼
Encrypted SQLCipher DB               CONFIRMED
    │
    ▼
Session Data API                     CONFIRMED
    │
    ▼
ConvoHub                             CONFIRMED
    │
    ▼
window.getConversationController     CONFIRMED
    │
    ▼
ConversationModel fields              NEXT INVESTIGATION
    │
    ▼
Bridge mechanism                      NOT DECIDED
```

The strongest discovery so far is:

```js
window.getConversationController = ConvoHub.use;
```

combined with:

```js
const convoModels = await data_1.Data.getAllConversations();
```

This suggests Session itself already performs the difficult work of decrypting/loading/normalizing conversations, and the next task is figuring out how to safely access those already-loaded objects.

---

# 34. Commands / Paths Reference

## Session Flatpak

```text
network.loki.Session
```

## Session executable

```text
/app/Session/session-desktop
```

## Session data

```text
~/.var/app/network.loki.Session/config/Session/
```

## DB

```text
~/.var/app/network.loki.Session/config/Session/sql/db.sqlite
```

## WAL

```text
~/.var/app/network.loki.Session/config/Session/sql/db.sqlite-wal
```

## Extracted ASAR

```text
/tmp/session-asar/
```

## Main process

```text
/tmp/session-asar/ts/mains/main_node.js
```

## Preload

```text
/tmp/session-asar/preload.js
```

## Data initialization

```text
/tmp/session-asar/ts/data/dataInit.js
```

## Dynamic channel registry

```text
/tmp/session-asar/ts/data/channels.js
```

## SQL IPC

```text
/tmp/session-asar/ts/node/sql_channel.js
```

## SQL layer

```text
/tmp/session-asar/ts/node/sql.js
```

## SQLCipher migration

```text
/tmp/session-asar/ts/node/migration/signalMigrations.js
```

## Conversation controller

```text
/tmp/session-asar/ts/session/conversations/ConversationController.js
```

## Conversation model

```text
/tmp/session-asar/ts/models/conversation.js
```

## Quickshell Session adapter

```text
~/.config/quickshell/services/messaging/SessionAdapter.qml
```

---

# 35. Resume Instructions for Future Chat

If this document is pasted into a new chat, the assistant should understand:

1. The user is building a Quickshell messaging UI.
2. Session Desktop is the first real messaging backend.
3. Session is a Flatpak.
4. Its database is SQLCipher-encrypted.
5. Direct SQLite access failed because the DB is encrypted.
6. Session contains native SQLCipher and libsession utilities.
7. Session uses an Electron renderer with Node integration.
8. The preload initializes Session's data API.
9. The preload exposes:
   ```js
   window.getConversationController = ConvoHub.use;
   ```
10. `ConvoHub` internally loads:
    ```js
    Data.getAllConversations()
    ```
11. Therefore the preferred route is to reuse Session's already-loaded conversation layer.
12. Do not jump directly to decrypting/reimplementing SQLCipher.
13. The immediate next investigation is `ConversationModel` fields and how `ConvoHub` initializes.
14. After that, determine a safe bridge from Session to Quickshell.
15. Then implement `SessionAdapter.qml`.
16. Then connect `ContactList.qml`.
17. Later implement `ChatFeed.qml` and sending.

**Current exact next commands:**

```bash
sed -n '335,395p' /tmp/session-asar/ts/session/conversations/ConversationController.js
```

```bash
rg -n \
  "class ConversationModel|getConversationModelProps|getNicknameOrRealUsernameOrPlaceholder|displayName|name|nickname|profile" \
  /tmp/session-asar/ts/models/conversation.js
```

```bash
sed -n '1,260p' /tmp/session-asar/ts/models/conversation.js
```

Paste the outputs back into the conversation and continue from there.
