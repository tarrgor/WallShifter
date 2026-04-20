import AppKit

/// Captures the system wallpaper URLs for all connected displays before WallShifter
/// makes any changes, and restores them on quit.
///
/// Must be initialized before `WallpaperEngine` ever touches a display.
final class SystemWallpaperStore {

    // MARK: - Private

    /// Keyed by `NSScreen.displayID` (a stable UInt32 identifier).
    private var snapshot: [CGDirectDisplayID: URL] = [:]

    // MARK: - Init

    init() {
        captureSnapshot()
    }

    // MARK: - Snapshot

    private func captureSnapshot() {
        for screen in NSScreen.screens {
            guard let url = NSWorkspace.shared.desktopImageURL(for: screen) else { continue }
            let displayID = screen.displayID
            snapshot[displayID] = url
        }
        print("[SystemWallpaperStore] Captured \(snapshot.count) display(s).")
    }

    // MARK: - Restore

    /// Restores all captured wallpaper URLs. Call from `applicationWillTerminate`.
    func restore() {
        for screen in NSScreen.screens {
            let displayID = screen.displayID
            guard let originalURL = snapshot[displayID] else { continue }
            do {
                try NSWorkspace.shared.setDesktopImageURL(originalURL, for: screen, options: [:])
            } catch {
                print("[SystemWallpaperStore] Failed to restore display \(displayID): \(error)")
            }
        }
        print("[SystemWallpaperStore] Restore complete.")
    }
}

// MARK: - NSScreen convenience

private extension NSScreen {
    /// Returns the `CGDirectDisplayID` for this screen, which is stable across
    /// display reconnects within the same session.
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return (deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
    }
}
