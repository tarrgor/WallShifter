# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Status

This project is at its initial scaffold stage — an Xcode-generated SwiftUI template. The full intended architecture is specified in `CONCEPT.md` at the repo root. All feature development should follow that document.

## Build & Run

This is a native macOS Xcode project. There is no build script; use Xcode or `xcodebuild`:

```bash
# Build
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project WallShifter/WallShifter.xcodeproj -scheme WallShifter -configuration Debug build

# Run tests (once tests exist)
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project WallShifter/WallShifter.xcodeproj -scheme WallShifter -configuration Debug test

# Archive (release)
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project WallShifter/WallShifter.xcodeproj -scheme WallShifter -configuration Release archive
```

Open `WallShifter/WallShifter.xcodeproj` in Xcode to develop interactively.

## Intended Architecture

The app must be restructured from the current SwiftUI window template into a **menu bar agent**. Key architectural changes required:

### App Entry Point
- `WallShifterApp.swift` must be converted to use `NSApplicationDelegate` via `@NSApplicationDelegateAdaptor` and set `LSUIElement = YES` in `Info.plist` to suppress the Dock icon and window
- The `WindowGroup` scene must be replaced with `Settings { PreferencesView() }` (for the preferences panel) — no main window

### Core Components (to be created per CONCEPT.md)

| File | Responsibility |
|---|---|
| `MenuBarManager` | Owns `NSStatusItem`; builds and live-updates `NSMenu`; drives the countdown label |
| `WallpaperEngine` | Scheduling (`DispatchSourceTimer`), rotation logic, history ring buffer, pause/resume |
| `SourceManager` | Enumerates image files from configured sources; owns `FSEventStream` watchers for live folder changes |
| `DisplayManager` | Detects connected `NSScreen`s; applies wallpapers via `NSWorkspace` APIs; handles per-display configuration |
| `SystemWallpaperStore` | Reads and caches system wallpaper URLs before first change; restores them on quit |
| `ConfigStore` | Reads/writes `~/Library/Application Support/WallShifter/config.json`; bridges to `UserDefaults` for security-scoped bookmarks |
| `LoginItemManager` | Wraps `SMAppService.mainApp` (macOS 13+) with a fallback to `LaunchAgent` plist |

### Key macOS APIs in Use
- `NSWorkspace.shared.setDesktopImageURL(_:for:options:)` — apply wallpaper per display
- `NSWorkspace.shared.desktopImageURL(for:)` — read current system wallpaper (used by `SystemWallpaperStore`)
- `NSScreen.screens` — enumerate connected displays
- `FSEventStream` or `DispatchSource.makeFileSystemObjectSource` — watch folders for image changes
- `SMAppService` (ServiceManagement) — login item registration
- `NSOpenPanel` + security-scoped bookmarks — persistent access to user-chosen folders without repeated prompts

### Sandboxing
The app must **not** be sandboxed (`WallShifter.entitlements` should not include `com.apple.security.app-sandbox`). Arbitrary folder access is granted through `NSOpenPanel` security-scoped bookmarks stored in `UserDefaults`.

### State Persistence
Rotation state (current index, shuffle queue, history, last-changed date) is persisted to disk so a relaunch continues the sequence rather than restarting it. Config lives in a human-readable JSON file (see `CONCEPT.md` for schema).

### Clean Quit
`SystemWallpaperStore` must capture wallpaper URLs for all displays before WallShifter ever modifies them. `applicationWillTerminate` must restore those URLs, so quitting the app is a lossless operation from the user's perspective.

## Workflow Rules

- After implementing any step from `PLAN.md`, immediately update that step's line in `PLAN.md` to mark it `✅ Done`.
- After every code change, build the project to catch compilation errors before moving on. Fix any errors before proceeding to the next step:
  ```bash
  /Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -project WallShifter/WallShifter.xcodeproj -scheme WallShifter -configuration Debug build
  ```
