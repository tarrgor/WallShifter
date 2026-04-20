# WallShifter

A lightweight macOS menu bar app that automatically rotates your desktop wallpaper. WallShifter runs silently in the background — no Dock icon, no clutter — and restores your original system wallpaper the moment you quit.

---

## Features

- **Menu bar only** — no Dock icon, no app switcher entry
- **Multiple wallpaper sources** — local folders, favourites lists, or the macOS system library
- **Flexible scheduling** — change every N minutes/hours, on login, on wake, or manually
- **Smart rotation orders** — sequential, random (no repeat), fully random, or newest-first
- **Multi-display support** — same image on all screens, different images per screen, or fully independent per-display configuration
- **Wallpaper fitting** — Fill, Fit, Stretch, Center, or Tile, configurable per display
- **Live menu bar countdown** — see exactly when the next change will happen
- **Back one wallpaper** — instantly undo the last change
- **Clean quit** — your original system wallpaper is restored when WallShifter exits
- **Launch at login** — optional, managed entirely within the app

---

## Requirements

- macOS 13 Ventura or later
- Apple Silicon or Intel (Universal Binary)

---

## Installation

### Download

Download the latest release DMG from the [Releases](../../releases) page, open it, and drag **WallShifter** to your Applications folder.

### Build from Source

```bash
git clone <repo-url>
open WallShifter/WallShifter.xcodeproj
```

Then build and run from Xcode, or via the command line:

```bash
xcodebuild -project WallShifter/WallShifter.xcodeproj \
           -scheme WallShifter \
           -configuration Release \
           archive
```

---

## Getting Started

1. **Launch WallShifter** — a small icon appears in your menu bar.
2. **Click the icon → Preferences… → Sources → Add Folder…** and select a folder containing your wallpapers.
3. **Set your schedule** in the Schedule tab (e.g. every 10 minutes).
4. WallShifter will start rotating immediately.

---

## Menu Bar

Clicking the WallShifter icon in the menu bar gives you full control:

| Item | Action |
|---|---|
| **Current Wallpaper** | Shows the filename of the active wallpaper (non-interactive) |
| **Next change in: …** | Live countdown to the next automatic change |
| **Next Wallpaper** | Apply the next wallpaper immediately |
| **Previous Wallpaper** | Revert to the wallpaper shown before the last change |
| **Pause / Resume** | Temporarily suspend or resume automatic rotation |
| **Preferences…** | Open the preferences panel |
| **Reveal in Finder** | Show the current image file in Finder |
| **Copy Image Path** | Copy the full file path to the clipboard |
| **Quit WallShifter** | Exit the app and restore your original system wallpaper |

The menu bar icon reflects the current state:

| Icon | Meaning |
|---|---|
| Normal | Active and rotating |
| Pause badge | Rotation is paused |
| Warning badge | An error occurred (e.g. a source folder is missing) |

---

## Preferences

### Sources

Add one or more image sources. Each source can be individually enabled or disabled.

| Source Type | Description |
|---|---|
| **Local Folder** | A folder on disk; WallShifter watches it live for new or removed images |
| **Favourites List** | A hand-picked list of individual image files |
| **System Library** | Images from macOS's built-in wallpaper collection |

Per-folder options include recursive subfolders and file type filtering.

### Schedule

- **Change Every** — set an interval in seconds, minutes, or hours
- **Change on Wake** — apply a new wallpaper when the Mac wakes from sleep
- **Change on Login** — apply a new wallpaper at each login
- **Time-of-Day Ranges** *(advanced)* — use different sources at different times of day

### Displays

- **All displays: same image** — one wallpaper across every screen
- **All displays: different images** — a separate image drawn per screen from the same source
- **Per-display configuration** — each screen has its own source, schedule, and rotation order

### Advanced

- **Launch at Login** — register WallShifter as a login item
- **Transition** — Instant or Fade between wallpapers
- **History Size** — how many previous wallpapers to remember (default: 20)
- **Minimum Resolution** — skip images below a specified resolution

---

## Configuration File

WallShifter stores its full configuration as human-readable JSON at:

```
~/Library/Application Support/WallShifter/config.json
```

You can edit this file manually, back it up, or copy it to another Mac.

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

## Privacy

WallShifter requires access to the folders you add as sources. Access is granted through the system's standard **Open Panel** dialog and is remembered across relaunches via security-scoped bookmarks stored in `UserDefaults`.

- **No network access** required or requested
- **No personal data** collected or transmitted
- WallShifter is **not sandboxed**, which is necessary to apply wallpapers across arbitrary user-chosen folders without constant permission prompts

---

## Uninstalling

1. Quit WallShifter (your original wallpaper is restored automatically).
2. Delete the app from `/Applications`.
3. Optionally remove stored data:

```bash
rm -rf ~/Library/Application\ Support/WallShifter
```

If you enabled **Launch at Login**, disable it in Preferences → Advanced before quitting, or it will be cleaned up automatically on delete on macOS 13+.

---

## Roadmap

The following features are planned for future releases:

- Global keyboard shortcuts for Next / Previous / Pause
- Thumbnail preview of the next wallpaper in the menu
- History browser — a scrollable grid of recently used wallpapers
- Siri Shortcuts integration
- iCloud configuration sync
- URL / RSS image source (e.g. NASA Astronomy Picture of the Day)
- Dynamic wallpaper (`.heic`) support
