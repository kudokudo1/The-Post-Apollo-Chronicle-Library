# Quickshell Workspace Bar — Detailed Project Record

## Project goal

Build an upgraded Quickshell replacement for the current Waybar while preserving the existing visual style and adding functionality.

Development preferences:
- Work incrementally.
- Make one meaningful change at a time.
- Use the user's existing code as the base.
- Avoid giant rewrites and unnecessary architecture.
- Preserve working visual/effect layers.
- Test each change before proceeding.

## Current configuration structure

```text
~/.config/quickshell/
├── shell.qml
├── components/
│   ├── Colors.qml
│   └── qmldira
├── modules/
│   ├── Clock.qml
│   ├── Power.qml
│   └── Workspaces.qml
└── archive/
    ├── 3
    ├── shell.qml.backup
    └── shell.qml.blue
```

Important files:
- `shell.qml`: main panel/window.
- `modules/Workspaces.qml`: workspace dock.
- `modules/Clock.qml`: clock module.
- `modules/Power.qml`: power button/menu.
- `components/Colors.qml`: shared colors.
- `components/qmldira`: singleton registration for Colors.
- `archive/3`: old Power button.

## Quickshell version and APIs

The system is running Quickshell 0.2.1, Fedora's package build.

Relevant APIs include:
- `Quickshell.I3`
- `I3.workspaces`
- `I3.focusedWorkspace`
- `I3.monitors`
- `I3.focusedMonitor`
- `I3Workspace.number`
- `I3Workspace.activate()`

`I3.workspaces` is an `ObjectModel<I3Workspace>` containing Sway workspaces. `number` is preferred over the deprecated `num`.

## Original Waybar visual language

Font:

```text
GohuFont 11 Nerd Font Mono
```

Main colors:

```text
Cyan:   #55CFCA
Orange: #ED981A
Light:  #DCF3FA
Purple: #1B0623
```

General appearance:
- Transparent overall bar.
- Dark purple module backgrounds.
- Light/cyan text.
- Small margins and padding.
- Very small radius.
- Cyan glow around modules.
- Workspace container has a cyan rectangular glow.
- Active workspace uses orange on DP-5.
- HDMI-A-1 workspaces use white when inactive and yellow when active.
- Clock uses cyan text/icon glow.

## Main shell geometry

The main shell uses `PanelWindow` with top anchoring and:

```qml
margins {
    left: 200
    right: 200
    bottom: 3
}

WlrLayershell.layer: WlrLayer.Bottom
implicitHeight: 70
color: "transparent"
```

Temporary black/cyan scaffolding remains in the shell for geometry/effect tuning.

The panel was temporarily changed to `WlrLayer.Top` while investigating wheel input. It did not solve scrolling, so the intended layer is `WlrLayer.Bottom`.

## Workspace requirements

The workspace system should:
1. Show workspaces that actually exist.
2. Add/remove buttons dynamically.
3. Grow/shrink with the workspace list.
4. Show all currently existing workspaces from both monitors.
5. Eventually be cloneable to a second monitor.

The user does not want workspace filtering limited to the current output.

## Monitor-specific workspace colors

Outputs:

```text
DP-5
HDMI-A-1
```

Example:

```text
DP-5:     1, 2, 5
HDMI-A-1: 4, 9, 10
```

The main dock should show all six.

DP-5:
- inactive = cyan
- active = orange

HDMI-A-1:
- inactive = white
- active = yellow

This combined-monitor behavior was successfully implemented.

## Workspace dock structure

Current sizing:

```qml
implicitWidth: workspaceRow.implicitWidth + 13
implicitHeight: workspaceRow.implicitHeight + 8
```

Current row:

```qml
RowLayout {
    id: workspaceRow
    anchors.fill: parent
    anchors.margins: 4
    spacing: 3
}
```

Model:

```qml
Repeater {
    model: I3.workspaces
}
```

Each delegate:

```qml
Rectangle {
    id: workspaceButton
    width: 25
    height: 46
    color: "transparent"
}
```

The active delegate deliberately has higher z-order:

```qml
z: workspaceButton.isActive ? 2 : 1
```

## Important active-glow layering fix

The active workspace glow originally had a hard right edge because neighboring delegates painted over it.

The successful fix was:

```qml
z: workspaceButton.isActive ? 2 : 1
```

on the entire workspace delegate.

Keep this.

## Workspace background layers

Active background:

```qml
Rectangle {
    id: workspaceisActiveButtonBackground
    anchors.centerIn: parent
    width: parent.width
    height: parent.height
    clip: false
    z: 0
    opacity: 0.7
    color: workspaceButton.isActive ? Colors.dark : "transparent"
}
```

Enlarged shadow source:

```qml
Rectangle {
    id: workspaceButtonBackground
    anchors.centerIn: parent
    width: parent.width + 8
    height: parent.height + 8
    clip: false
    z: -1
    color: Colors.dark
    opacity: workspaceButton.isActive ? 0.0 : 0.0
}
```

The enlarged rectangle can remain invisible while acting as the shadow source.

## Workspace text and color logic

The number is:

```qml
Text {
    id: workspaceText
    anchors.centerIn: parent
    text: workspaceButton.workspaceNumber

    property color workspaceColor:
        modelData.monitor.name === "HDMI-A-1"
        ? (
            workspaceButton.isActive
            ? Colors.yellow
            : Colors.white
        )
        : (
            workspaceButton.isActive
            ? Colors.orange
            : Colors.cyan
        )

    color: workspaceText.workspaceColor
    font.pixelSize: 20
}
```

## Existing active text glow

```qml
DropShadow {
    anchors.fill: workspaceText
    source: workspaceText
    visible: workspaceButton.isActive
    horizontalOffset: 0
    verticalOffset: 0
    radius: 21
    samples: 37
    opacity: 0.9
    color: workspaceText.workspaceColor
}
```

## New subtle cyan text glow

The user wanted a subtle cyan/blue glow based on the clock's glow:

```qml
DropShadow {
    id: clockGlowIcon
    source: clockIcon
    anchors.fill: clockIcon
    horizontalOffset: 0
    verticalOffset: 0
    radius: 14
    samples: 13
    z: 1
    opacity: 0.5
    color: Colors.cyan
    transparentBorder: true
}
```

The workspace version was added as:

```qml
DropShadow {
    id: workspaceGlow
    source: workspaceText
    anchors.fill: workspaceText
    horizontalOffset: 0
    verticalOffset: 0
    radius: 14
    samples: 13
    z: 1
    opacity: 0.7
    color: Colors.cyan
    transparentBorder: true
}
```

Recommended refinement so active workspaces do not have both cyan and orange/yellow glows:

```qml
opacity: workspaceButton.isActive ? 0.0 : 0.5
```

This gives:
- inactive DP-5 = cyan text + subtle cyan glow
- inactive HDMI-A-1 = white text + subtle cyan glow
- active DP-5 = orange text + orange glow
- active HDMI-A-1 = yellow text + yellow glow

## Dock shadow

Working dock shadow:

```qml
RectangularShadow {
    anchors.fill: workspacesDock
    width: workspacesDock.width + 2
    height: workspacesDock.height + 2
    spread: 3
    z: -1
    opacity: 0.4
    color: Colors.cyan
}

RectangularShadow {
    anchors.fill: workspacesDock
    width: workspacesDock.width + 2
    height: workspacesDock.height + 2
    spread: 10
    z: -1
    opacity: 0.07
    color: Colors.cyan
}
```

The user said this shadow is working perfectly. Keep the second spread at `10`.

## Workspace click behavior

Each delegate contains a process:

```qml
Process {
    id: switchWorkspace

    command: [
        "swaymsg",
        "workspace",
        workspaceButton.workspaceNumber.toString()
    ]
}
```

Clicking runs it:

```qml
onClicked: {
    console.log(
        "Workspace",
        workspaceButton.workspaceNumber,
        "clicked"
    )

    switchWorkspace.running = true
}
```

## Failed scrolling approaches

Several custom approaches were tried:
- QML index calculation using `scrollTarget`.
- Searching the `I3.workspaces` list for the current index.
- A dock-wide `WheelHandler`.
- A dock-wide `MouseArea`.
- Various `acceptedButtons` configurations.
- Changing the panel layer from Bottom to Top.

The custom index-based approach did not work reliably.

Changing the panel to Top did not solve the issue.

## Successful scrolling solution

A separate Quickshell workspace module from another person was used as a reference.

The useful mechanism was:

```qml
onWheel: function(wheel) {
    if (wheel.angleDelta.y > 0) {
        switchWorkspace.command = [
            "swaymsg",
            "workspace",
            "prev"
        ]
    } else {
        switchWorkspace.command = [
            "swaymsg",
            "workspace",
            "next"
        ]
    }

    switchWorkspace.running = true
}
```

Only this mechanism was borrowed; the other person's module was not copied wholesale.

## Current scroll implementation

The user's current module now has:

```qml
Process {
    id: scrollWorkspace

    command: [
        "swaymsg",
        "workspace",
        "next"
    ]

    stdout: StdioCollector {
        onStreamFinished: {
            console.log("SCROLL:", text)
        }
    }
}
```

And the existing workspace button `MouseArea` has:

```qml
onWheel: function(wheel) {
    if (wheel.angleDelta.y > 0) {
        scrollWorkspace.command = [
            "swaymsg",
            "workspace",
            "prev"
        ];
    } else {
        scrollWorkspace.command = [
            "swaymsg",
            "workspace",
            "next"
        ];
    }

    scrollWorkspace.running = true;
    wheel.accepted = true;
}
```

This works.

The interaction is now:

```text
click → swaymsg workspace <number>
wheel up → swaymsg workspace prev
wheel down → swaymsg workspace next
```

## Current status

Working:
- Dynamic `I3.workspaces` model.
- Combined workspaces from both outputs.
- Monitor-specific colors.
- Active workspace styling.
- Active z-order/glow behavior.
- Dock cyan rectangular shadow.
- Subtle cyan text glow.
- Click-to-switch.
- Mouse-wheel switching.
- Sway `prev`/`next` scrolling.

Not yet implemented:
- Hover workspace preview.
- Actual workspace thumbnail/screenshot.
- Second-monitor cloned module.
- Final cleanup of debug/test processes.
- Additional menus/functionality.

## Development rule

The successful scrolling change reinforced the project's preferred method:

1. Find a small proven mechanism.
2. Integrate only that mechanism into the existing code.
3. Preserve working visual and behavioral layers.
4. Test.
5. Move to the next feature only after the current one works.
