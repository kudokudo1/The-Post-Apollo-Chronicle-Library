# Quickshell Power Menu
## Development History & Current Working Configuration

> **Status:** Working  
> **Environment:** Quickshell + QML + Sway  
> **Current design:** Bottom-right `PanelWindow` with independently positioned power button, menu, and confirmation screens.

---

# 1. Project Overview

This project is a custom power menu written in QML for **Quickshell**, intended to work alongside **Sway**.

The menu provides four primary actions:

- **Lock** — runs `swaylock`
- **Logout** — runs `swaymsg exit`
- **Reboot** — opens a reboot confirmation screen
- **Shutdown** — opens a shutdown confirmation screen

The interface uses a cyberpunk/neon-style visual design based around:

- Cyan
- Magenta
- Yellow
- Orange
- Red
- Black

The current implementation intentionally keeps the power button and menu positioned independently rather than building the interface entirely from nested anchors.

Quickshell's `PanelWindow` is designed for panels/widgets attached to screen edges, and Quickshell's `Process` type can be used to launch commands from QML. citeturn0search0turn0search1

---

# 2. Design Philosophy

The most important design decision made during development was to treat the `PanelWindow` as a small invisible canvas.

The current window is:

```qml
implicitWidth: 220
implicitHeight: 290
```

Inside that area:

```text
220 × 290 PanelWindow
┌──────────────────────────────┐
│                              │
│      ┌──────────────┐        │
│      │   POWER      │        │
│      │    MENU      │        │
│      └──────────────┘        │
│                              │
│                    ┌──────┐  │
│                    │  ⏻   │  │
│                    └──────┘  │
└──────────────────────────────┘
```

The power button uses:

```qml
x: 155
y: 230
```

The menu uses:

```qml
x: 35
y: 20
```

This gives direct control over the physical placement of the two elements.

### Why this approach was retained

During development, several more interconnected positioning approaches were considered. The independent positioning model proved easier to reason about:

```qml
powerButton.x = 155
powerButton.y = 230

powerMenu.x = 35
powerMenu.y = 20
```

Rather than having the menu's position depend on the button's position, each element has its own coordinates.

This makes future visual adjustments straightforward.

---

# 3. Initial Power Button

The first major component was the power button.

The button is a `Rectangle`:

```qml
Rectangle {
    id: powerButton
    radius: width / 100
    width: 50
    height: 50
    z: 1
    x: 155
    y: 230
}
```

The power symbol is supplied by a `Text` element:

```qml
Text {
    anchors.centerIn: parent
    text: "⏻"
    font.pixelSize: 35
}
```

The button uses a `MouseArea` for interaction:

```qml
MouseArea {
    id: powerMouse
    width: parent.width
    height: parent.height
    hoverEnabled: true
}
```

Hover and press states were added to make the button visually interactive.

---

# 4. Power Button Interaction Development

The button eventually settled on three pieces of state:

```qml
property bool menuOpen: false
property int clickCount: 0
property int pressCount: 0
```

The counters were useful while debugging mouse interaction.

The current click handler is deliberately simple:

```qml
onClicked: {
    clickCount++
    menuOpen = !menuOpen
    console.log("Menu open:", menuOpen)
}
```

This means:

```text
closed → click → open
open   → click → closed
```

Importantly, `menuOpen` controls the visibility of the main power menu, but it was **not** tied into the confirmation-state logic.

That separation was intentional.

---

# 5. Mouse Debugging

Mouse interaction was tested using:

```qml
onEntered: console.log("Mouse entered button")
onExited: console.log("Mouse left button")
onPressed: pressCount++
```

This made it possible to distinguish between:

- The mouse actually reaching the button
- A press occurring
- A click being registered

These debug counters/logs were especially useful while the power button was being positioned independently inside the small `PanelWindow`.

---

# 6. Building the Main Power Menu

The main menu became a separate `Rectangle`:

```qml
Rectangle {
    id: powerMenu
    width: 150
    height: 200
    z: 1
    color: Colors.black
    x: 35
    y: 20
    visible: menuOpen
}
```

The important relationship is:

```qml
visible: menuOpen
```

The power button controls `menuOpen`, and the menu follows that state.

The menu itself contains a `Column` called:

```qml
id: menuItems
```

The menu contains:

1. Header
2. Divider
3. Lock
4. Logout
5. Reboot
6. Shutdown

---

# 7. Menu Header

The menu header was kept deliberately simple:

```qml
Text {
    text: "POWER MENU"
    color: Colors.cyan
    font.pixelSize: 20
    anchors.horizontalCenter: parent.horizontalCenter
}
```

A cyan divider was placed underneath:

```qml
Rectangle {
    width: parent.width - 20
    height: 2
    color: Colors.cyan
    anchors.horizontalCenter: parent.horizontalCenter
}
```

This established the basic visual hierarchy.

---

# 8. Lock Action

The Lock button runs:

```qml
Process {
    id: lockProcess
    command: ["swaylock"]
}
```

The click handler is:

```qml
onClicked: {
    console.log("Lock clicked!")
    menuOpen = false
    lockProcess.running = true
}
```

The menu closes before starting the lock command.

---

# 9. Logout Action

Logout uses:

```qml
Process {
    id: logoutProcess
    command: ["swaymsg", "exit"]
}
```

Its handler is:

```qml
onClicked: {
    console.log("Logout clicked!")
    logoutProcess.running = true
}
```

Unlike Lock, the current implementation does not explicitly set:

```qml
menuOpen = false
```

because the logout command itself exits the Sway session.

---

# 10. Reboot Confirmation

Reboot was deliberately designed as a two-step action.

The first click does **not** immediately reboot the system.

Instead:

```qml
onClicked: {
    console.log("Reboot clicked!")
    confirmReboot = true
}
```

The root property controlling this state is:

```qml
property bool confirmReboot: false
```

The actual reboot process is separate:

```qml
Process {
    id: rebootProcess
    command: ["systemctl", "reboot"]
}
```

The confirmation screen eventually runs:

```qml
rebootProcess.running = true
```

This gives the user an opportunity to cancel.

---

# 11. Shutdown Confirmation

Shutdown follows the same pattern.

The process is:

```qml
Process {
    id: shutdownProcess
    command: ["systemctl", "poweroff"]
}
```

The first click only changes state:

```qml
onClicked: {
    console.log("Shutdown clicked!")
    confirmShutdown = true
}
```

The actual shutdown occurs only after confirmation:

```qml
shutdownProcess.running = true
```

This prevents an accidental single click from immediately powering off the system.

---

# 12. The Confirmation-State Bug

One of the most important debugging stages involved the relationship between:

```qml
confirmShutdown
```

and:

```qml
confirmReboot
```

The intended behavior was:

```text
Normal menu
     │
     ├── Reboot ──→ Reboot confirmation
     │
     └── Shutdown → Shutdown confirmation
```

When a confirmation screen is active, the normal menu should disappear.

The correct condition is:

```qml
visible: !confirmShutdown && !confirmReboot
```

This means:

```text
confirmShutdown = false
confirmReboot   = false
        ↓
normal menu visible

confirmShutdown = true
        ↓
normal menu hidden

confirmReboot = true
        ↓
normal menu hidden
```

---

# 13. The Typo That Caused the Reboot Problem

A particularly important development/debugging issue was a typo in the visibility condition.

The incorrect code was:

```qml
visible: !confirmShutdown && !confrimReboot
```

The problem is:

```text
confrimReboot
```

The actual property is:

```text
confirmReboot
```

The letters were transposed.

The correct version is:

```qml
visible: !confirmShutdown && !confirmReboot
```

This was significant because the reboot confirmation state itself was being changed correctly:

```qml
confirmReboot = true
```

but the normal menu was checking a different, misspelled property name.

The final correction restored the intended state relationship.

---

# 14. Why the Confirmation States Were Not Tied to `menuOpen`

During development, an alternative approach was considered where `menuOpen` would control or reset the confirmation states.

That approach was intentionally **not adopted**.

The current design keeps three states conceptually separate:

```text
menuOpen
confirmShutdown
confirmReboot
```

Their responsibilities are:

### `menuOpen`

Controls whether the power menu is open.

```qml
visible: menuOpen
```

### `confirmShutdown`

Controls whether the shutdown confirmation UI is displayed.

```qml
visible: confirmShutdown
```

### `confirmReboot`

Controls whether the reboot confirmation UI is displayed.

```qml
visible: confirmReboot
```

This separation makes the state machine easier to understand.

---

# 15. Confirmation UI Structure

The shutdown confirmation is a separate `Column`:

```qml
Column {
    id: shutdownConfirm
    width: parent.width
    visible: confirmShutdown
}
```

The reboot confirmation is another sibling:

```qml
Column {
    id: rebootConfirm
    width: parent.width
    visible: confirmReboot
}
```

Each screen contains:

```text
QUESTION
   │
   ├── Cancel
   │
   └── CONFIRM!
```

---

# 16. Shutdown Cancel

The shutdown Cancel button does:

```qml
onClicked: {
    console.log("Shutdown cancelled!")
    confirmShutdown = false
}
```

It does not modify `menuOpen`.

This is intentional: the confirmation state is simply cleared.

---

# 17. Reboot Cancel

The reboot Cancel button does:

```qml
onClicked: {
    console.log("Reboot cancelled!")
    confirmReboot = false
}
```

Again, it only clears the confirmation state.

---

# 18. Confirmation Actions

Shutdown confirmation:

```qml
onClicked: {
    console.log("Shutdown confirmed!")
    shutdownProcess.running = true
}
```

Reboot confirmation:

```qml
onClicked: {
    console.log("Reboot confirmed!")
    rebootProcess.running = true
}
```

The potentially destructive commands are therefore separated from the first button press.

---

# 19. Visual Styling

The menu uses a black background:

```qml
color: Colors.black
```

The primary neon accent is cyan:

```qml
color: Colors.cyan
```

Interaction states use:

```text
Normal    → cyan/black
Hover     → yellow/orange
Pressed   → magenta
Shutdown  → red
```

For example:

```qml
color: shutdownMouse.pressed ? Colors.red
     : shutdownMouse.containsMouse ? Colors.yellow
     : Colors.black
```

Text follows the same interactive philosophy.

---

# 20. Power Button Glow

The power button has two visual effects.

### DropShadow

```qml
DropShadow {
    source: powerButton
    anchors.centerIn: powerButton
    width: powerButton.width
    height: powerButton.height
    opacity: 0.3
    horizontalOffset: 0
    verticalOffset: 0
    radius: 19
    samples: 17
    z: 1
    color: Colors.cyan
    transparentBorder: true
}
```

### RectangularShadow

```qml
RectangularShadow {
    anchors.fill: powerButton
    width: powerButton.width
    height: powerButton.height
    opacity: 0.5
    spread: 1
    z: -1
    color: Colors.cyan
}
```

The combination gives the button its neon appearance.

---

# 21. Power Menu Glow

The menu also has two shadow effects.

The main glow is:

```qml
DropShadow {
    id: powerMenuGlow
    source: powerMenu
    anchors.fill: powerMenu
    width: powerMenu.width
    height: powerMenu.height
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
```

The important part is:

```qml
visible: menuOpen
opacity: menuOpen ? 0.5 : 0
```

This keeps the glow synchronized with the menu's open/closed state.

A second rectangular shadow provides additional neon depth:

```qml
RectangularShadow {
    anchors.centerIn: powerMenu
    width: powerMenu.width
    height: powerMenu.height
    spread: 3
    z: -3
    visible: menuOpen
    opacity: menuOpen ? 0.7 : 0
    color: Colors.cyan
}
```

---

# 22. Shadow Development Note

There was an earlier point where the menu glow was being debugged because the `DropShadow` was associated with the same menu object that contained the shadow.

The working configuration keeps the shadow explicitly controlled by:

```qml
visible: menuOpen
```

and:

```qml
opacity: menuOpen ? 0.5 : 0
```

This became part of the stable working configuration.

If the glow is modified later, this relationship should be changed carefully.

---

# 23. Current Layout

The final layout can be thought of as three visual zones:

```text
PanelWindow: 220 × 290

┌──────────────────────────────┐
│                              │
│    ┌──────────────────┐      │
│    │    POWER MENU    │      │
│    ├──────────────────┤      │
│    │ Lock             │      │
│    │ Logout            │      │
│    │ Reboot            │      │
│    │ Shutdown          │      │
│    └──────────────────┘      │
│                              │
│                    ┌──────┐  │
│                    │  ⏻   │  │
│                    └──────┘  │
└──────────────────────────────┘
```

Coordinates:

```text
PanelWindow
  width  = 220
  height = 290

Power button
  x = 155
  y = 230
  width  = 50
  height = 50

Power menu
  x = 35
  y = 20
  width  = 150
  height = 200
```

---

# 24. Current State Model

The current implementation uses three independent booleans:

```qml
property bool menuOpen: false
property bool confirmShutdown: false
property bool confirmReboot: false
```

Conceptually:

```text
                  ┌───────────────┐
                  │   menuOpen    │
                  └───────┬───────┘
                          │
                     Main Menu
                          │
             ┌────────────┴────────────┐
             │                         │
          Reboot                    Shutdown
             │                         │
             ▼                         ▼
      confirmReboot             confirmShutdown
             │                         │
        ┌────┴────┐              ┌─────┴─────┐
        │         │              │           │
      Cancel   Confirm         Cancel      Confirm
        │         │              │           │
        ▼         ▼              ▼           ▼
      Menu     Reboot           Menu      Shutdown
```

This is the logical model of the working implementation.

---

# 25. Current QML

The following is the current complete working configuration.

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
                     : powerMouse.containsMouse ? Colors.cyan
                     : Colors.white
            }

            MouseArea {
                id: powerMouse
                width: parent.width
                height: parent.height
                hoverEnabled: true

                onEntered: console.log("Mouse entered button")
                onExited: console.log("Mouse left button")

                onPressed: pressCount++

                onClicked: {
                    clickCount++
                    menuOpen = !menuOpen
                    console.log("Menu open:", menuOpen)
                }
            }
        }

        DropShadow {
            source: powerButton
            anchors.centerIn: powerButton
            width: powerButton.width
            height: powerButton.height
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

    Rectangle {
        id: powerMenu
        width: 150
        height: 200
        z: 1
        color: Colors.black
        x: 35
        y: 20
        visible: menuOpen

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
                     : lockMouse.containsMouse ? Colors.yellow
                     : Colors.black

                Text {
                    text: "Lock"
                    anchors.centerIn: parent
                    color: lockMouse.pressed ? Colors.black
                         : lockMouse.containsMouse ? Colors.orange
                         : Colors.cyan
                    font.pixelSize: 20
                }

                MouseArea {
                    id: lockMouse
                    anchors.fill: parent
                    hoverEnabled: true

                    onClicked: {
                        console.log("Lock clicked!")
                        menuOpen = false
                        lockProcess.running = true
                    }
                }
            }

            Rectangle {
                id: logoutButton
                width: parent.width
                height: 30
                color: logoutMouse.pressed ? Colors.magenta
                     : logoutMouse.containsMouse ? Colors.yellow
                     : Colors.black

                Text {
                    text: "Logout"
                    anchors.centerIn: parent
                    color: logoutMouse.pressed ? Colors.black
                         : logoutMouse.containsMouse ? Colors.orange
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
                }
            }

            Rectangle {
                id: rebootButton
                width: parent.width
                height: 30
                color: rebootMouse.pressed ? Colors.magenta
                     : rebootMouse.containsMouse ? Colors.yellow
                     : Colors.black

                Text {
                    text: "Reboot"
                    anchors.centerIn: parent
                    color: rebootMouse.pressed ? Colors.black
                         : rebootMouse.containsMouse ? Colors.orange
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
                }
            }

            Rectangle {
                id: shutdownButton
                width: parent.width
                height: 30
                color: shutdownMouse.pressed ? Colors.red
                     : shutdownMouse.containsMouse ? Colors.yellow
                     : Colors.black

                Text {
                    text: "Shutdown"
                    anchors.centerIn: parent
                    color: shutdownMouse.pressed ? Colors.black
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
                }
            }
        }

        DropShadow {
            id: powerMenuGlow
            source: powerMenu
            anchors.fill: powerMenu
            width: powerMenu.width
            height: powerMenu.height
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
            width: powerMenu.width
            height: powerMenu.height
            spread: 3
            z: -3
            visible: menuOpen
            opacity: menuOpen ? 0.7 : 0
            color: Colors.cyan
        }
    }

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
                 : cancelshutdownMouse.containsMouse ? Colors.yellow
                 : Colors.black

            Text {
                text: "Cancel"
                color: cancelshutdownMouse.pressed ? Colors.black
                     : cancelshutdownMouse.containsMouse ? Colors.orange
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
        }

        Rectangle {
            id: confirmshutdownButton
            width: parent.width
            height: 30
            color: confirmshutdownMouse.pressed ? Colors.red
                 : confirmshutdownMouse.containsMouse ? Colors.yellow
                 : Colors.black

            Text {
                text: "CONFIRM!"
                color: confirmshutdownMouse.pressed ? Colors.black
                     : confirmshutdownMouse.containsMouse ? Colors.orange
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
        }
    }

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
                 : cancelrebootMouse.containsMouse ? Colors.yellow
                 : Colors.black

            Text {
                text: "Cancel"
                color: cancelrebootMouse.pressed ? Colors.black
                     : cancelrebootMouse.containsMouse ? Colors.orange
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
        }

        Rectangle {
            id: confirmrebootButton
            width: parent.width
            height: 30
            color: confirmrebootMouse.pressed ? Colors.red
                 : confirmrebootMouse.containsMouse ? Colors.yellow
                 : Colors.black

            Text {
                text: "CONFIRM!"
                color: confirmrebootMouse.pressed ? Colors.black
                     : confirmrebootMouse.containsMouse ? Colors.orange
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
        }
    }
}
```

---

# 26. Development Timeline

## Stage 1 — Create the Panel

A small bottom-right `PanelWindow` was established.

The initial dimensions became:

```qml
implicitWidth: 220
implicitHeight: 290
```

The panel was made transparent:

```qml
color: "transparent"
```

The window was attached to:

```qml
bottom: true
right: true
```

with:

```qml
bottom: 10
right: 10
```

margins.

---

## Stage 2 — Position the Power Button

The power button was placed manually:

```qml
x: 155
y: 230
```

This became the basis for the independent-positioning strategy.

---

## Stage 3 — Add Mouse Interaction

A `MouseArea` was added.

Debug output was introduced:

```qml
console.log("Mouse entered button")
console.log("Mouse left button")
console.log("Menu open:", menuOpen)
```

This confirmed that the button was receiving mouse input.

---

## Stage 4 — Create the Main Menu

A separate 150 × 200 rectangle was created:

```qml
x: 35
y: 20
```

The menu was initially controlled by:

```qml
visible: menuOpen
```

---

## Stage 5 — Add Menu Actions

The four actions were implemented:

```text
Lock
Logout
Reboot
Shutdown
```

Each received its own `MouseArea`.

---

## Stage 6 — Connect Sway/System Commands

The `Process` objects were added:

```qml
["swaylock"]
["swaymsg", "exit"]
["systemctl", "reboot"]
["systemctl", "poweroff"]
```

This connected the visual interface to the actual system actions.

---

## Stage 7 — Add Confirmation Screens

Reboot and Shutdown were changed from immediate execution to confirmation-based actions.

Two state properties were introduced:

```qml
property bool confirmShutdown: false
property bool confirmReboot: false
```

---

## Stage 8 — Hide the Normal Menu During Confirmation

The normal menu was changed to:

```qml
visible: !confirmShutdown && !confirmReboot
```

This established the intended mutually exclusive visual states.

---

## Stage 9 — Debug the Reboot State

A problem appeared where reboot confirmation was activated but the normal menu did not disappear.

The cause was found to be a spelling mistake:

```qml
confrimReboot
```

instead of:

```qml
confirmReboot
```

The typo was corrected.

---

## Stage 10 — Preserve Independent State

An attempt to more tightly couple confirmation states with `menuOpen` was considered but rejected.

The final architecture intentionally leaves:

```text
menuOpen
confirmShutdown
confirmReboot
```

as separate pieces of state.

---

## Stage 11 — Add Neon Effects

Cyan `DropShadow` and `RectangularShadow` effects were added to:

- Power button
- Power menu

The menu glow was explicitly synchronized with:

```qml
menuOpen
```

---

## Stage 12 — Final Working State

The final implementation was tested and confirmed working.

The current design is now considered the baseline version.

Future changes should preferably be incremental so that the working state remains easy to recover.

---

# 27. Known Structural Details

There is one important architectural detail to remember.

The confirmation columns:

```qml
shutdownConfirm
rebootConfirm
```

are siblings of:

```qml
powerMenu
```

They are **not children of `powerMenu`**.

Therefore:

```qml
width: parent.width
```

inside the confirmation columns refers to the `PanelWindow`, not the 150-pixel-wide `powerMenu`.

Likewise, their:

```qml
anchors.top: parent.top
```

anchor them to the `PanelWindow`.

This is not a bug in the current working configuration; it is simply an important detail to remember if the confirmation screens are repositioned later.

---

# 28. Debugging Lessons

## Check exact property names

QML property names are case-sensitive and spelling-sensitive.

For example:

```qml
confirmReboot
```

and:

```qml
confrimReboot
```

are not equivalent.

When a state change appears to work but the UI does not respond, check both:

1. Where the state is changed
2. Every place where that state is referenced

---

## Separate state from appearance

The current design makes it easier to debug because each visual component has a clear state variable.

Example:

```qml
visible: menuOpen
```

versus:

```qml
visible: confirmReboot
```

This is easier to follow than having one property indirectly control everything.

---

## Keep positioning explicit when it helps

The independent coordinates:

```qml
powerButton.x = 155
powerButton.y = 230

powerMenu.x = 35
powerMenu.y = 20
```

are intentionally simple.

There is no requirement to replace them with more complicated anchor relationships just because anchors are available.

---

# 29. Future Development Ideas

These are possible future improvements, not part of the current working baseline.

### Animation

The menu could eventually animate:

- Fade in/out
- Slide in/out
- Scale
- Glow intensity

### Better component organization

The repeated button structure could eventually be extracted into a reusable component.

For example:

```text
components/
├── PowerButton.qml
├── MenuButton.qml
├── ConfirmButton.qml
└── Colors.qml
```

Quickshell supports breaking larger configurations into multiple QML files, which can make a growing shell easier to maintain. citeturn0search1turn0search5

### Unified confirmation component

The reboot and shutdown confirmation screens are currently separate.

They could eventually share a reusable confirmation component.

### More power actions

Possible future entries:

```text
Lock
Logout
Suspend
Hibernate
Reboot
Shutdown
```

### Keyboard support

The menu could eventually support keyboard navigation and Escape-to-cancel behavior.

---

# 30. Baseline Rule

The current working version should be treated as the **known-good baseline**.

Before making a major change:

1. Save a copy of this version.
2. Make one logical change at a time.
3. Test the change.
4. Keep the state variables separate unless there is a clear reason to combine them.
5. Preserve the independent positioning unless the layout requirements change.

---

# 31. Quick Reference

## Window

```text
220 × 290
bottom-right
10 px bottom margin
10 px right margin
```

## Power Button

```text
50 × 50
x = 155
y = 230
```

## Power Menu

```text
150 × 200
x = 35
y = 20
```

## State

```qml
menuOpen
confirmShutdown
confirmReboot
```

## Commands

```text
Lock     → swaylock
Logout   → swaymsg exit
Reboot   → systemctl reboot
Shutdown → systemctl poweroff
```

## Correct menu visibility

```qml
visible: !confirmShutdown && !confirmReboot
```

## Most important typo to avoid

```text
WRONG: confrimReboot
RIGHT: confirmReboot
```

---

# 32. Current Project Status

**Working baseline established.**

The current implementation successfully combines:

- Quickshell `PanelWindow`
- QML state properties
- Sway commands
- Quickshell `Process`
- Mouse interaction
- Independent manual positioning
- Reboot confirmation
- Shutdown confirmation
- Neon visual effects
- Separate menu and confirmation states

The project is now at the point where new functionality can be added incrementally without needing to redesign the existing working structure.
