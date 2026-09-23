# Post-Apollo Media Library Idea

## Status

**Future project — parked for later.**

Current priority remains the **Zellij receiver / DVD-player style terminal panel**. This document preserves the media-library idea so it can be picked up later without losing the concept.

---

## Core Idea

Build a separate **Post-Apollo graphical media-library application** that treats digital media like physical media.

Instead of showing files as a normal list or grid, the app presents media as:

- DVD cases
- CD jewel cases
- Box sets
- Shelves or racks
- Physical discs inside cases

The goal is to make browsing local digital media feel like using a real physical collection.

---

## Basic Interaction

### Library View

The user sees shelves filled with physical-looking cases.

Examples:

- Movies appear as DVD/Blu-ray style cases.
- Albums appear as CD jewel cases.
- TV series could appear as box sets.
- Other media types could later get their own physical format.

The cases should use artwork when available.

### Selecting a Case

Clicking a case could:

1. Pull it forward from the shelf.
2. Enlarge or focus it.
3. Optionally allow viewing the front/back cover.
4. Open the case.
5. Reveal the disc inside.

### Disc Interaction

The disc can be grabbed with the mouse and dragged into a virtual media deck.

```text
Shelf
  ↓
Select case
  ↓
Case moves forward
  ↓
Open case
  ↓
Grab disc
  ↓
Drag disc to player
  ↓
Insert animation
  ↓
Playback begins
```

The insertion/ejection animation should feel tactile and physical rather than like clicking a modern play button.

---

## Storage Model

The app should **index media, not import or duplicate it**.

Users choose one or more folders such as:

```text
~/Videos
~/Music
~/Media/Movies
/mnt/storage/TV
```

The application recursively scans those folders and builds a library index.

The original files remain exactly where they already are.

The app stores only things such as:

- File paths
- Media metadata
- Artwork/cache
- Duration
- Titles
- Album/series information
- Playback position
- Library organization
- User preferences

This avoids maintaining a second copy of the user's media.

---

## File Watching

Selected media folders should eventually be monitored for changes.

Examples:

- New movie added → new case appears.
- File deleted → case disappears.
- File renamed → index updates.
- Artwork added → case artwork updates.

A full-system scan is technically possible, but **user-selected folders should be the default**.

---

## Playback

### Local Files

Use **mpv** as the playback backend.

When a disc is inserted, the application simply gives mpv the indexed file path.

```text
Virtual DVD
    ↓
Media entry
    ↓
/home/user/Videos/movie.mkv
    ↓
mpv
```

### Playback Screen

Playback does not need to occur inside the tiny virtual DVD-player display.

The intended design is:

- The **main screen / terminal display** becomes the playback surface.
- The **receiver/DVD panel** remains the control hardware.
- The panel can switch between Zellij controls and media controls.

---

## Possible Future Sources

The same physical-media interface could eventually represent more than local files.

### Jellyfin

Jellyfin could act as a media backend while Post-Apollo remains the custom frontend.

Instead of storing a local path, a case could reference a Jellyfin media item.

Jellyfin would handle things such as:

- Library metadata
- Remote libraries
- Transcoding
- Streaming
- Multiple devices

Post-Apollo would handle:

- Shelves
- Cases
- Disc interactions
- Physical-media metaphor
- Playback controls

### YouTube / Web Media

YouTube or other supported web sources could later be implemented through source adapters.

A virtual disc could represent:

- A YouTube video
- A playlist
- An internet radio stream
- Another supported media source

The player should prefer official APIs or existing extractors rather than fragile scraping whenever possible.

DRM-heavy services such as Netflix would require a different integration approach and should not be treated like raw downloadable media.

---

## Graphics Approach

This project should be a **real graphical application**, not a pure terminal UI.

The terminal is appropriate for the Zellij receiver/control system, but the physical library benefits from:

- Smooth animation
- Image artwork
- Shadows
- Rotation
- Layering
- Drag-and-drop
- Case-opening animations
- Disc movement
- Shelf perspective

The project does **not** need a graphics engine written from scratch.

Use an existing lightweight 2D graphics/UI framework.

Potential implementation direction:

- **Rust** for the eventual main application.
- A lightweight 2D rendering/UI library.
- Python could be used for early experiments if useful.

---

## Relationship to Zellij

The Zellij project and media-library project should remain separate but interoperable.

### Zellij Side

Zellij becomes the retro receiver/DVD-player control panel.

It can eventually have two main personalities:

#### Zellij Mode

Buttons control terminal functions such as:

- Quit
- Session
- Pane
- Tab
- Move
- Resize
- Scroll
- Search
- Lock

The physical button layout should resemble a real DVD player or AV receiver rather than a modern toolbar.

A **SESSION dial** can behave like an old channel selector.

Turning it changes between Zellij sessions.

### Media Mode

A master **MODE / SOURCE** switch changes the same physical panel into media controls.

The same buttons can then map to things such as:

- Play/pause
- Stop
- Previous
- Next
- Seek
- Volume
- Eject
- Library
- Track/chapter controls

Switching modes changes what the controls do rather than changing the physical chassis.

---

## Session Dial Idea

The Zellij receiver should include a stepped rotary **SESSION** dial.

Desired behavior:

- Click and hold the knob.
- Drag the mouse around its center.
- Cursor angle determines dial position.
- Dial snaps between session numbers.
- Clockwise selects the next session.
- Counter-clockwise selects the previous session.

The motion does not need to be perfectly analog.

A slightly stepped/detented feel is desirable because it resembles real hardware.

A nearby display can show:

```text
SESSION 03
dev
```

while the knob itself represents the numbered channel/session position.

---

## Design Philosophy

The project should follow the Post-Apollo / Metapollo principles.

### Power

The physical metaphor should not reduce capability. The application should remain practical as a serious media manager.

### Human

The user should understand what the system is doing and remain in control of where media is stored and how it is accessed.

### Tactile

Controls should feel like physical controls:

- Knobs
- Buttons
- Dials
- Trays
- Cases
- Discs
- Switches
- Lamps

Interaction should provide visible feedback.

### Nostalgic / Retro

Borrow from:

- DVD players
- CD players
- AV receivers
- CRT televisions
- VCRs
- Hi-fi equipment
- Physical media shelves

The goal is not to reproduce one specific device exactly, but to use the industrial design language of that era.

### Modular

Separate responsibilities:

```text
Library/indexer
      │
      ├── Local folder source
      ├── Jellyfin source
      └── Web source adapters

Media UI
      │
      ├── Shelves
      ├── Cases
      └── Disc interaction

Playback
      │
      └── mpv

Zellij Receiver
      │
      ├── Zellij mode
      └── Media mode
```

This allows pieces to evolve independently.

### Serious

Although the interface is playful and physical, it should still function as real software rather than being purely decorative.

---

## Suggested Development Order Later

When this project is resumed:

1. Create a simple graphical window.
2. Hard-code a shelf with several fake DVD cases.
3. Add case selection and pull-forward animation.
4. Add case opening.
5. Add a draggable disc.
6. Add a virtual player/drop target.
7. Connect disc insertion to mpv.
8. Add folder scanning.
9. Generate cases from real local files.
10. Add metadata and artwork.
11. Add file watching.
12. Connect the Zellij receiver's Media mode.
13. Add Jellyfin support.
14. Add optional web-source adapters.
15. Expand the physical-media interaction system.

---

## Current Decision

**Do not build this yet.**

First finish the Zellij receiver/DVD-player panel and establish its visual layout, controls, session dial, mode system, and interaction model.

Once that is solid, return to this document and build the media-library application as a separate Post-Apollo project.
