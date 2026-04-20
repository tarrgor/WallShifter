import AppKit
import Combine

/// Manages the list of connected displays and associates each with its `DisplayConfig`.
///
/// Observes `NSApplication.didChangeScreenParametersNotification` so it stays in sync
/// when monitors are connected or disconnected at runtime.
final class DisplayManager: ObservableObject {

    // MARK: - Published state

    /// The currently connected screens.
    @Published private(set) var screens: [NSScreen] = []

    // MARK: - Dependencies

    private let configStore: ConfigStore

    // MARK: - Private

    private var notificationObserver: Any?

    // MARK: - Init

    init(configStore: ConfigStore) {
        self.configStore = configStore
        refreshScreens()
        notificationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refreshScreens()
        }
    }

    deinit {
        if let observer = notificationObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Screen management

    /// Returns the `DisplayConfig` for `screen`, creating and persisting a default one if absent.
    func config(for screen: NSScreen) -> DisplayConfig {
        let id = screen.persistentID
        if let existing = configStore.config.displays.first(where: { $0.id == id }) {
            return existing
        }
        let newConfig = DisplayConfig(id: id)
        configStore.config.displays.append(newConfig)
        return newConfig
    }

    /// Applies `imageURL` as the wallpaper on `screen` using the fitting from its `DisplayConfig`.
    func setWallpaper(_ imageURL: URL, on screen: NSScreen) {
        let displayConfig = config(for: screen)
        let options = makeOptions(for: displayConfig.fitting)
        do {
            try NSWorkspace.shared.setDesktopImageURL(imageURL, for: screen, options: options)
        } catch {
            print("[DisplayManager] Failed to set wallpaper on \(screen.persistentID): \(error)")
        }
    }

    // MARK: - Private helpers

    private func refreshScreens() {
        screens = NSScreen.screens
        // Ensure every connected screen has an entry in config.
        for screen in screens {
            _ = config(for: screen)
        }
        print("[DisplayManager] \(screens.count) screen(s) active.")
    }

    private func makeOptions(for fitting: WallpaperFitting) -> [NSWorkspace.DesktopImageOptionKey: Any] {
        var options: [NSWorkspace.DesktopImageOptionKey: Any] = [:]
        switch fitting {
        case .fill:
            options[.imageScaling] = NSImageScaling.scaleProportionallyUpOrDown.rawValue
            options[.allowClipping] = true
        case .fit:
            options[.imageScaling] = NSImageScaling.scaleProportionallyUpOrDown.rawValue
            options[.allowClipping] = false
        case .stretch:
            options[.imageScaling] = NSImageScaling.scaleAxesIndependently.rawValue
        case .center:
            options[.imageScaling] = NSImageScaling.scaleNone.rawValue
        case .tile:
            // NSWorkspace has no native tile option; scale to none and let the system tile
            options[.imageScaling] = NSImageScaling.scaleNone.rawValue
        }
        return options
    }
}

// MARK: - NSScreen convenience

extension NSScreen {
    /// A stable string identifier derived from the display's `CGDirectDisplayID`.
    var persistentID: String {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        let displayID = (deviceDescription[key] as? NSNumber)?.uint32Value ?? 0
        return String(displayID)
    }
}
