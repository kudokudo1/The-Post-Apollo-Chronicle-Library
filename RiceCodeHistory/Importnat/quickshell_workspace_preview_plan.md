# Quickshell Workspace Hover Preview — Detailed Discussion and Implementation Plan

## 1. Feature requested

The next proposed feature is a workspace hover preview.

Desired interaction:

```text
Hover workspace number
        ↓
small preview appears
        ↓
see what is on that workspace
        ↓
decide whether to switch
```

The goal is to know what is on a workspace before switching to it.

This would be added to the existing `Workspaces.qml`, not replace the workspace system.

## 2. Difficulty

Approximate complexity:

```text
Window-list preview:        moderate
Actual screenshot preview: considerably harder
Live continuously updating: advanced
```

The recommended starting point is a window-list preview.

## 3. Recommended first version: window list

Instead of immediately capturing an image, the popup could list applications/windows.

Example:

```text
┌──────────────────────────┐
│ Workspace 3              │
│                          │
│ kitty                    │
│ Firefox                  │
│ nvim                     │
└──────────────────────────┘
```

This gives useful information without compositor screenshot capture.

## 4. Why the window-list version is preferable initially

Advantages:
- Much simpler than a thumbnail.
- Does not require switching to the workspace.
- Can use Sway IPC/tree information.
- Low resource usage.
- Easy to style.
- Easy to position.
- Easy to extend later.

It fits the current architecture: Sway supplies state; QML supplies presentation.

## 5. Likely Sway data source

The likely source is:

```bash
swaymsg -t get_tree
```

The resulting JSON tree can be searched recursively.

Useful information may include:
- workspace association
- application class
- app ID
- window title
- container state

The preview can inspect this information without switching workspaces.

## 6. Conceptual data flow

```text
Sway
  │
  │ swaymsg -t get_tree
  ▼
Quickshell Process
  │
  │ JSON
  ▼
QML parsing
  │
  │ find workspace/window containers
  ▼
hovered workspace data
  │
  ▼
preview popup
```

The existing delegate already knows its workspace number through:

```qml
property int workspaceNumber: modelData.number
```

That can be used to select the correct workspace data.

## 7. Existing hover capability

The workspace button already has:

```qml
MouseArea {
    id: workspaceButtonMouse
    anchors.fill: parent
    hoverEnabled: true
}
```

That means hover behavior can use:

```qml
onEntered
```

and:

```qml
onExited
```

Conceptually:

```qml
onEntered: {
    // show preview
}

onExited: {
    // hide preview
}
```

## 8. Recommended incremental implementation

Do not build the entire preview at once.

### Stage 1 — blank popup

First implement only:

```text
hover workspace → popup appears
```

The popup can contain nothing or a placeholder.

Purpose:
- verify hover events
- verify popup positioning
- verify z-order
- verify clipping
- verify interaction with the bar
- verify that scrolling still works

### Stage 2 — workspace number

Show:

```text
Workspace 3
```

This verifies that the popup is tied to the correct workspace delegate.

### Stage 3 — query Sway tree

Add:

```bash
swaymsg -t get_tree
```

Parse the JSON and identify workspace/window containers.

### Stage 4 — populate the window list

Show entries such as:

```text
Workspace 3

kitty
Firefox
nvim
```

Later, titles can be included if useful.

### Stage 5 — style the popup

Match the existing bar:

- dark purple/black background
- cyan/white text
- subtle cyan glow
- thin cyan accent/border
- GohuFont 11 Nerd Font Mono

The popup should look like a natural part of the existing shell.

### Stage 6 — improve positioning

Position it relative to the hovered workspace button.

Possible locations:
- above the bar
- below the bar
- offset beside the workspace button

The exact position should be tuned visually.

### Stage 7 — optional icons and metadata

Possible additions:
- application icon
- title
- number of windows
- focused window
- fullscreen state
- urgency state

Only add these after the basic list works.

## 9. Conceptual popup

A finished window-list preview could look like:

```text
┌────────────────────────────┐
│ WORKSPACE 3                │
│                            │
│ kitty                      │
│ Firefox                    │
│ nvim                       │
└────────────────────────────┘
              │
         workspace 3
```

Icons can be added later if application metadata makes that practical.

## 10. Layering considerations

The workspace delegate already has:

```qml
z: workspaceButton.isActive ? 2 : 1
```

This must remain because it fixed the active workspace glow being covered by neighbors.

The preview should receive its own high z-order instead of changing the existing workspace z-order.

The preview needs to appear above:
- workspace buttons
- their glows
- the dock

## 11. Interaction with scrolling

The preview must coexist with the now-working wheel behavior.

Current interactions:

```text
click → switch to selected workspace
wheel up → previous workspace
wheel down → next workspace
hover → show preview
```

Conceptually:

```text
                 Workspace button
                       │
          ┌────────────┼────────────┐
          │            │            │
       click         wheel        hover
          │            │            │
          ▼            ▼            ▼
       switch       prev/next    preview
```

The hover popup should not capture the wheel unnecessarily.

## 12. Actual screenshot thumbnail

A more advanced feature would display a real miniature image of an inactive workspace.

Example:

```text
┌──────────────────────────────┐
│                              │
│      miniature workspace     │
│          screenshot          │
│                              │
└──────────────────────────────┘
```

This is significantly harder than a window list.

## 13. Why screenshots are harder

Sway's:

```bash
swaymsg -t get_tree
```

provides metadata about containers and windows, not simply a screenshot of an inactive workspace.

A real thumbnail likely requires compositor/Wayland capture functionality such as screencopy-style mechanisms.

Potential challenges include:
- capturing the correct content
- dealing with inactive workspaces
- rendering an image in QML
- updating thumbnails
- compositor-specific behavior
- resource usage

Therefore screenshot preview should be treated as a later project.

## 14. Live thumbnail preview

The most advanced version would continuously update a thumbnail while hovering.

Conceptually:

```text
hover workspace
      ↓
thumbnail appears
      ↓
thumbnail keeps updating
```

Potential drawbacks:
- more implementation complexity
- more CPU/GPU activity
- more compositor interaction
- more opportunities for rendering/input issues

It is unnecessary for the first useful version.

## 15. Recommended final progression

```text
1. Hover workspace
       ↓
2. Blank popup
       ↓
3. Show workspace number
       ↓
4. Query Sway tree
       ↓
5. Find windows on workspace
       ↓
6. Show window names
       ↓
7. Style popup
       ↓
8. Tune positioning
       ↓
9. Optional application icons
       ↓
10. Optional screenshot thumbnail
       ↓
11. Optional live thumbnail
```

Each stage should be tested before the next.

## 16. Do not replace the current workspace implementation

The preview should be additive.

Keep:

```qml
model: I3.workspaces
```

Keep:

```qml
property int workspaceNumber: modelData.number
```

Keep the monitor-specific color logic.

Keep the active workspace background.

Keep the existing shadow layers.

Keep:

```qml
z: workspaceButton.isActive ? 2 : 1
```

Keep click switching.

Keep the working wheel implementation:

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

## 17. Recommended first implementation step

The first actual preview change should be intentionally small:

**Hover a workspace and show a simple popup containing its workspace number.**

Do not query Sway's tree during this first step.

This isolates:
- hover detection
- popup creation
- positioning
- z-order
- visibility
- interaction with wheel scrolling

Once this works, add Sway tree parsing.

## 18. Design philosophy

The workspace preview should follow the same philosophy that produced the successful scrolling feature:

**Borrow the smallest proven mechanism and integrate it into the existing implementation.**

Do not copy a complete unrelated Quickshell bar.

Do not redesign the workspace model.

Do not introduce a large architecture unless the feature actually requires it.

Build the preview as a small addition to the existing workspace delegate and popup behavior.
