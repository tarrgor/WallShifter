# WallShifter — Implementation Plan

## Phase 1 — App Skeleton (Foundation)

These must happen first — everything else builds on top.

### Step 1: Convert the app entry point ✅ Done
- Rewrite `WallShifterApp.swift` to use `@NSApplicationDelegateAdaptor` with a custom `AppDelegate : NSObject, NSApplicationDelegate`
- Remove `WindowGroup` / `ContentView` entirely
- Replace with `Settings { PreferencesView() }` scene (stub view for now)

### Step 2: Configure `Info.plist` + entitlements ✅ Done
- Add `LSUIElement = YES` (Boolean) to suppress Dock icon and app switcher entry
- Create `WallShifter.entitlements` **without** `com.apple.security.app-sandbox`
- Note: The current template likely has no explicit `Info.plist` — it needs to be added to the Xcode project

### Step 3: Create the data models (`Models/`) ✅ Done
Four `Codable` structs that drive everything else:
- `AppConfig.swift` — top-level config (sources, schedule, order, displays, advanced)
- `ImageSource.swift` — folder/favorites/system source descriptor
- `RotationState.swift` — index, shuffleQueue, history ring buffer, lastChangedAt, isPaused
- `DisplayConfig.swift` — per-display fitting, source assignment, independent rotation flag

---

## Phase 2 — Core Services

### Step 4: `ConfigStore` ✅ Done
- Reads/writes `~/Library/Application Support/WallShifter/config.json`
- Provides `@Published var config: AppConfig` for SwiftUI bindings
- Bridges security-scoped bookmarks to `UserDefaults`

### Step 5: `SystemWallpaperStore` ✅ Done
- On first launch, snapshots current `NSWorkspace.shared.desktopImageURL(for:)` for all `NSScreen.screens`
- `applicationWillTerminate` restores all saved URLs
- Must run **before** `WallpaperEngine` ever touches a display

### Step 6: `DisplayManager` ✅ Done
- Wraps `NSScreen.screens` enumeration
- Observes `NSApplication.didChangeScreenParametersNotification` for hot-plug/unplug events
- Associates each screen with its `DisplayConfig`

---

## Phase 3 — Menu Bar + Engine

### Step 7: `MenuBarManager` ✅ Done
- Creates `NSStatusItem` with a template image
- Builds the initial `NSMenu` (hardcoded stubs — "Next Wallpaper", "Pause", "Preferences…", "Quit")
- Wires "Quit" to `SystemWallpaperStore.restore()` then `NSApp.terminate()`
- Adds a live-updating countdown label (via a 1-second `Timer`)

### Step 8: `SourceManager` ✅ Done
- Enumerates image files (jpg/png/heic/tiff/gif) from each enabled `ImageSource`
- Sets up `FSEventStream` or `DispatchSource` file watchers for folder sources
- Exposes `var allImages: [URL]` (merged, deduplicated list)

### Step 9: `WallpaperEngine` ✅ Done
- Owns a `DispatchSourceTimer` for interval-based rotation
- Implements `next()` / `previous()` using `RotationState`
- Calls `DisplayManager` → `NSWorkspace.shared.setDesktopImageURL(_:for:options:)`
- Persists `RotationState` to disk after every change

---

## Phase 4 — Preferences UI + Login Item

### Step 10: Stub `PreferencesView` with tabs ✅ Done
- `SourcesTab` — list + add/remove folder sources via `NSOpenPanel`
- `ScheduleTab` — interval picker, wake/login toggles
- `DisplaysTab` — display mode and fitting
- `AdvancedTab` — launch at login, history size, transition style

### Step 11: `LoginItemManager` ✅ Done
- macOS 13+: `SMAppService.mainApp.register()` / `.unregister()`
- Reflects current state in the `AdvancedTab` toggle

---

## Recommended Start Order

```
1. WallShifterApp.swift (entry point conversion)
2. Info.plist + entitlements
3. Models (AppConfig, ImageSource, RotationState, DisplayConfig)
4. ConfigStore
5. SystemWallpaperStore
6. DisplayManager
7. MenuBarManager (basic, static)
8. SourceManager
9. WallpaperEngine
10. Preferences UI
11. LoginItemManager
```

The dependency chain is strict at the top: the app won't even launch correctly as a menu bar agent until steps 1–2 are done. Steps 3–6 are pure logic with no UI, so they're safe to build and test in isolation before wiring the menu bar.
