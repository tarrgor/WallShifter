# WallShifter — Concept Document

## Overview

WallShifter is a macOS menu bar application that manages desktop wallpaper rotation and transitions. It runs as a lightweight background process, giving users fine-grained control over when, how, and from where wallpapers are applied. When the app is stopped, macOS reverts to its system wallpaper settings as if WallShifter was never active.

---

## Core Goals

- Run silently in the background with minimal resource usage
- Provide a clean, native-feeling menu bar interface
- Restore system wallpaper state cleanly on exit
- Support multiple display configurations
- Be fully configurable without opening a separate settings window (everything accessible from the menu bar)

---

## Application Architecture

### Process Model

WallShifter runs as a **menu bar agent** (`LSUIElement = YES` in `Info.plist`), meaning:
- No Dock icon
- No app switcher entry
- Visible only as a menu bar icon
- Launched at login via a `LaunchAgent` plist (optional, user-configurable)

### Technology Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI Framework | SwiftUI + AppKit (NSStatusItem, NSMenu) |
| Wallpaper API | `NSWorkspace` / `NSScreen` wallpaper APIs |
| Persistence | `UserDefaults` + JSON config file |
| Scheduling | `Foundation.Timer` / `DispatchSourceTimer` |
| Image Loading | `NSImage` with lazy loading |
| Sandboxing | Disabled (requires file system access beyond sandbox limits) |
| Distribution | Direct download (DMG) or Mac App Store (sandboxed variant) |

---

## Feature Set

### 1. Wallpaper Sources

Users can configure one or more **sources** from which wallpapers are drawn:

| Source Type | Description |
|---|---|
| **Local Folder** | A folder on disk; WallShifter watches it for new/removed images |
| **Favorites List** | A manually curated list of individual image files |
| **System Library** | Pull from macOS's built-in wallpaper collection |

Each source can be enabled or disabled independently.

### 2. Change Triggers

The moment a new wallpaper is applied can be triggered by:

| Trigger | Description |
|---|---|
| **Time Interval** | Every N minutes/hours (e.g., every 10 minutes) |
| **On Login** | Change once when the user logs in |
| **On Wake** | Change when the Mac wakes from sleep |
| **On App Launch** | Apply a wallpaper immediately when WallShifter starts |
| **Manual** | User triggers a change via the menu bar |
| **Combined** | Any combination of the above |

### 3. Selection Order

When picking the next image from the source:

- **Sequential** — cycle through images in alphabetical/filename order
- **Random (no repeat)** — shuffle without repeating until all images have been shown
- **Random** — fully random, may repeat
- **Newest First** — prioritise recently added/modified images

### 4. Display Targeting

On multi-monitor setups:

- **All Displays Same** — apply the same image to every screen
- **All Displays Different** — pick a separate image per display from the same source
- **Per-Display Configuration** — each display has its own independent source, trigger, and order settings

### 5. Wallpaper Fitting Options

Maps directly to the `NSWorkspace` fitting options:

- Fill
- Fit
- Stretch
- Center
- Tile

Configurable per display.

### 6. Transition Behavior

- **Instant** — no animation (fastest, least distraction)
- **Fade** — cross-fade between old and new wallpaper using a brief overlay window (custom-rendered; macOS does not natively expose transition animations via the wallpaper API)

### 7. Time-of-Day Scheduling (Optional / Advanced)

Users can define **time windows** during which WallShifter is active or uses a specific sub-source:

- Example: Use bright landscape photos between 08:00–18:00, dark/low-contrast images between 18:00–08:00
- Pairs naturally with system dark/light mode changes

### 8. Exclusion Rules

- Skip images below a minimum resolution threshold (e.g., ignore anything smaller than 1920×1080)
- Skip images whose aspect ratio does not match the primary display
- Skip hidden files (dotfiles)

---

## Menu Bar Interface

The menu bar icon changes state to reflect the app's status:

| State | Icon Appearance |
|---|---|
| Active, rotating | Filled wallpaper icon |
| Paused | Icon with a pause badge |
| Error (missing folder, etc.) | Icon with a warning badge |

### Menu Structure

```
[WallShifter Icon]
├── Current Wallpaper: "mountain_sunset.jpg"        (non-interactive label)
├── Next change in: 7 minutes                       (non-interactive label, live countdown)
├── ─────────────────────────────────────────
├── Next Wallpaper                                  (⌘ → triggers immediate change)
├── Previous Wallpaper                              (⌘ ← goes back one)
├── Pause / Resume                                  (toggle)
├── ─────────────────────────────────────────
├── Preferences…                                    (opens preferences panel)
│   ├── Sources
│   │   ├── Add Folder…
│   │   ├── [Folder Path]  ✓ Enabled  [Remove]
│   │   └── …
│   ├── Schedule
│   │   ├── Change Every: [10] [minutes ▼]
│   │   ├── Also change on wake  ☑
│   │   └── Also change on login ☑
│   ├── Order
│   │   └── ○ Sequential  ● Random (no repeat)  ○ Random
│   ├── Display
│   │   ├── All displays: same image  /  different images
│   │   └── Fit: [Fill ▼]
│   └── Advanced
│       ├── Launch at Login  ☑
│       ├── Minimum resolution: [1920] × [1080]
│       └── Transition: ● Instant  ○ Fade
├── ─────────────────────────────────────────
├── Reveal in Finder                                (shows current image in Finder)
├── Copy Image Path                                 (copies path to clipboard)
├── ─────────────────────────────────────────
└── Quit WallShifter                                (restores system wallpaper)
```

---

## Preferences Panel

A native SwiftUI settings window (invoked via "Preferences…") organises settings into tabs:

### Tab: Sources
- List of configured sources with enable/disable toggles
- Add / remove buttons
- Drag to reorder (determines priority when sources are merged)
- Per-source: folder path, recursive subfolders toggle, file type filter

### Tab: Schedule
- Interval picker (spinner + unit dropdown: seconds / minutes / hours)
- Checkboxes for additional triggers (wake, login, app launch)
- Time-of-day ranges (optional; can be hidden behind an "Advanced" disclosure group)

### Tab: Displays
- Visual representation of detected displays
- Per-display: source assignment, fitting mode, independent rotation toggle

### Tab: Advanced
- Launch at login toggle (writes/removes a `LaunchAgent` plist)
- Transition style
- History size (how many "previous" wallpapers to remember)
- Minimum image resolution filter
- Log level (for debugging)

---

## State Management

### Active State

WallShifter maintains an internal **rotation state**:

```
{
  currentIndex: Int,
  shuffleQueue: [String],   // pre-computed shuffle order
  history: [String],        // last N applied images (for "Previous")
  lastChangedAt: Date,
  isPaused: Bool
}
```

This state is persisted to disk so that if WallShifter is relaunched, it continues from where it left off rather than restarting the sequence.

### System Wallpaper Restoration

Before WallShifter first applies a wallpaper, it reads and saves the current system wallpaper path for each display using `NSWorkspace.shared.desktopImageURL(for:)`. On quit, it restores these saved paths. This ensures that "Quit WallShifter" is a clean, lossless operation.

---

## File Watching

WallShifter uses `DispatchSource.makeFileSystemObjectSource` (or `FSEventStream` via `CoreServices`) to monitor configured folders for:
- New image files added → immediately eligible for rotation
- Image files removed → removed from the rotation queue; if currently displayed, triggers a change
- Folder renamed or deleted → surfaced as an error in the menu bar icon

---

## Image History

A circular buffer (default: 20 entries) records which images have been displayed. This powers:
- The "Previous Wallpaper" action
- A future "History" submenu showing thumbnails of recent wallpapers

---

## Error Handling

| Scenario | Behaviour |
|---|---|
| Configured folder not found | Menu bar icon shows warning badge; menu shows error message with a "Locate Folder…" action |
| No eligible images in source | Warning shown; rotation paused |
| Image file unreadable | Skipped silently; logged |
| All images exhausted (sequential) | Cycle restarts from beginning |
| Display disconnected mid-session | State saved; resumes when display reconnects |

---

## Privacy & Permissions

WallShifter requires:

- **Full Disk Access** (or targeted folder access via `NSOpenPanel` security-scoped bookmarks) to read images from arbitrary user-chosen folders
- No network access required
- No personal data collected or transmitted

Security-scoped bookmarks are stored in `UserDefaults` so access to chosen folders persists across app relaunches without prompting the user repeatedly.

---

## Launch at Login

WallShifter manages its own login item:

- **macOS 13+**: Uses `SMAppService.mainApp` (Service Management framework) — the preferred modern approach
- **macOS 12 and earlier**: Falls back to writing a `LaunchAgent` plist to `~/Library/LaunchAgents/`

The preference toggle in the app reflects the current registration state and updates it live.

---

## Configuration File

Beyond `UserDefaults`, a human-readable JSON config at `~/Library/Application Support/WallShifter/config.json` stores the full configuration. This allows:
- Manual editing by power users
- Backup and restore
- Sharing configurations between Macs

```json
{
  "sources": [
    {
      "id": "abc123",
      "type": "folder",
      "path": "/Users/alice/Pictures/Wallpapers",
      "recursive": true,
      "enabled": true
    }
  ],
  "schedule": {
    "intervalSeconds": 600,
    "changeOnWake": true,
    "changeOnLogin": true
  },
  "order": "randomNoRepeat",
  "displays": {
    "mode": "allSame",
    "fitting": "fill"
  },
  "advanced": {
    "transition": "instant",
    "historySize": 20,
    "minResolution": { "width": 1920, "height": 1080 },
    "launchAtLogin": true
  }
}
```

---

## Project Structure

```
WallShifter/
├── WallShifterApp.swift          # App entry point, AppDelegate, NSStatusItem setup
├── MenuBarManager.swift          # Builds and updates the NSMenu
├── WallpaperEngine.swift         # Core rotation logic, scheduling, history
├── SourceManager.swift           # Manages image sources, file watching
├── DisplayManager.swift          # Multi-display detection and targeting
├── SystemWallpaperStore.swift    # Saves/restores system wallpaper state
├── ConfigStore.swift             # Reads/writes config.json and UserDefaults
├── LoginItemManager.swift        # SMAppService / LaunchAgent abstraction
├── Views/
│   ├── PreferencesView.swift     # Top-level preferences window (SwiftUI)
│   ├── SourcesTab.swift
│   ├── ScheduleTab.swift
│   ├── DisplaysTab.swift
│   └── AdvancedTab.swift
├── Models/
│   ├── AppConfig.swift           # Codable config model
│   ├── ImageSource.swift
│   ├── RotationState.swift
│   └── DisplayConfig.swift
├── Assets.xcassets/
│   ├── AppIcon.appiconset/
│   └── MenuBarIcons/             # Template images for menu bar states
└── Supporting Files/
    ├── Info.plist                # LSUIElement = YES
    └── WallShifter.entitlements
```

---

## Minimum System Requirements

- macOS 13 Ventura or later (for `SMAppService` and SwiftUI improvements)
- Apple Silicon or Intel (Universal Binary)

---

## Future Enhancements (Out of Scope for v1)

- **iCloud Sync** — sync configuration and history across Macs
- **Dynamic Wallpapers** — support Apple's `.heic` dynamic wallpaper format
- **Siri Shortcuts** — expose actions (next wallpaper, pause) to Shortcuts.app
- **Widgets** — show current/upcoming wallpaper in a Notification Centre widget
- **Hotkey Support** — global keyboard shortcuts for next/previous/pause
- **Image Preview** — thumbnail preview of the next scheduled wallpaper in the menu
- **History Browser** — a dedicated window showing a scrollable grid of recent wallpapers with the ability to re-apply any of them
- **URL Source** — pull images from a remote URL or RSS feed (e.g., NASA APOD)
