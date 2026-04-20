import Foundation
import Combine

/// Drives automatic wallpaper rotation via a `DispatchSourceTimer`.
///
/// Lifecycle: create → call `start()` → receive `next()` / `previous()` from UI.
/// Persists `RotationState` to `~/Library/Application Support/WallShifter/rotation.json`
/// after every change so a relaunch continues the sequence.
final class WallpaperEngine: ObservableObject {

    // MARK: - Dependencies

    private let sourceManager: SourceManager
    private let displayManager: DisplayManager
    private let configStore: ConfigStore
    weak var menuBarManager: MenuBarManager?

    // MARK: - State

    private(set) var rotationState: RotationState {
        didSet { persistState() }
    }

    var isPaused: Bool {
        get { rotationState.isPaused }
        set {
            guard rotationState.isPaused != newValue else { return }
            rotationState.isPaused = newValue
            menuBarManager?.isPaused = newValue
            if newValue {
                stopTimer()
                menuBarManager?.nextChangeDate = nil
            } else {
                scheduleTimer()
            }
        }
    }

    // MARK: - Private

    private var timer: DispatchSourceTimer?
    private var cancellables = Set<AnyCancellable>()
    private let stateURL: URL
    private var pendingChangeOnLaunch = false

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    // MARK: - Init

    init(sourceManager: SourceManager,
         displayManager: DisplayManager,
         configStore: ConfigStore) {
        self.sourceManager = sourceManager
        self.displayManager = displayManager
        self.configStore = configStore
        stateURL = WallpaperEngine.resolveStateURL()
        rotationState = WallpaperEngine.loadState(from: stateURL) ?? RotationState()

        // Invalidate the shuffle queue when the image list changes.
        // Also trigger the first wallpaper if images became available after start() was called
        // (e.g. app launched before a source was configured, or the async scan beat start()).
        // `.receive(on:)` defers delivery so the @Published willSet has committed and
        // sourceManager.allImages holds the new value by the time the sink body runs.
        sourceManager.$allImages
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] images in
                guard let self else { return }
                self.rotationState.shuffleQueue = []
                let shouldChange = !images.isEmpty && !self.isPaused &&
                    (self.rotationState.lastChangedAt == .distantPast || self.pendingChangeOnLaunch)
                if shouldChange {
                    self.pendingChangeOnLaunch = false
                    self.showNext()
                }
            }
            .store(in: &cancellables)

        // Restart the timer whenever the user changes the rotation interval in Preferences.
        // Uses receive(on:) so the @Published willSet has committed before we read the new value.
        configStore.$config
            .map { $0.schedule.intervalSeconds }
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self, !self.isPaused else { return }
                self.restartTimer()
            }
            .store(in: &cancellables)
    }

    deinit {
        stopTimer()
    }

    // MARK: - Public interface

    /// Begins the rotation cycle. Pass `changeOnLaunch: true` to show the first
    /// wallpaper immediately; otherwise waits for the first timer fire.
    func start(changeOnLaunch: Bool) {
        guard !isPaused else { return }
        if changeOnLaunch || rotationState.lastChangedAt == .distantPast {
            if sourceManager.allImages.isEmpty {
                // Images not yet loaded; the $allImages sink will fire the change once they arrive.
                pendingChangeOnLaunch = changeOnLaunch
            } else {
                showNext()
            }
        }
        scheduleTimer()
    }

    /// Advances to the next wallpaper and resets the countdown.
    func next() {
        showNext()
        restartTimer()
    }

    /// Steps back to the previous wallpaper (from history) and resets the countdown.
    func previous() {
        showPrevious()
        restartTimer()
    }

    // MARK: - Private: selection logic

    private func showNext() {
        let images = sourceManager.allImages
        guard !images.isEmpty else {
            print("[WallpaperEngine] No images available.")
            return
        }
        applyWallpaper(pickNext(from: images))
    }

    private func showPrevious() {
        guard rotationState.history.count >= 2 else { return }
        // history tail is the current image; one before it is "previous"
        let path = rotationState.history[rotationState.history.count - 2]
        applyWallpaper(URL(fileURLWithPath: path), recordInHistory: false)
    }

    private func pickNext(from images: [URL]) -> URL {
        switch configStore.config.order {
        case .sequential:
            let index = (rotationState.currentIndex + 1) % images.count
            rotationState.currentIndex = index
            return images[index]

        case .randomNoRepeat:
            if rotationState.shuffleQueue.isEmpty {
                rotationState.shuffleQueue = images.map(\.path).shuffled()
            }
            let path = rotationState.shuffleQueue.removeFirst()
            return URL(fileURLWithPath: path)

        case .random:
            return images.randomElement()!

        case .newestFirst:
            let sorted = images.sorted {
                modDate($0) > modDate($1)
            }
            let index = min(rotationState.currentIndex + 1, sorted.count - 1)
            rotationState.currentIndex = index
            return sorted[index]
        }
    }

    private func modDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private func applyWallpaper(_ url: URL, recordInHistory: Bool = true) {
        let screens = displayManager.screens
        guard !screens.isEmpty else { return }

        switch configStore.config.displayMode {
        case .allSame:
            for screen in screens {
                displayManager.setWallpaper(url, on: screen)
            }

        case .allDifferent:
            let images = sourceManager.allImages
            guard !images.isEmpty else { return }
            // Use the already-picked url for the first screen; pick fresh images for the rest.
            for (i, screen) in screens.enumerated() {
                let wallpaper = i == 0 ? url : pickNext(from: images)
                displayManager.setWallpaper(wallpaper, on: screen)
            }

        case .perDisplay:
            // Basic per-display: use picked URL for all displays
            // Full independent-rotation support can be layered on later
            for screen in screens {
                displayManager.setWallpaper(url, on: screen)
            }
        }

        if recordInHistory {
            rotationState.appendToHistory(url.path)
        }
        rotationState.lastChangedAt = Date()
    }

    // MARK: - Private: timer

    private func scheduleTimer() {
        stopTimer()
        let interval = configStore.config.schedule.intervalSeconds
        let fireDate = Date(timeIntervalSinceNow: interval)
        menuBarManager?.nextChangeDate = fireDate

        let t = DispatchSource.makeTimerSource(queue: .main)
        t.schedule(deadline: .now() + interval, repeating: interval)
        t.setEventHandler { [weak self] in
            guard let self else { return }
            self.showNext()
            let next = Date(timeIntervalSinceNow: self.configStore.config.schedule.intervalSeconds)
            self.menuBarManager?.nextChangeDate = next
        }
        t.resume()
        timer = t
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
        menuBarManager?.nextChangeDate = nil
    }

    private func restartTimer() {
        guard !isPaused else { return }
        scheduleTimer()
    }

    // MARK: - Private: persistence

    private func persistState() {
        do {
            let data = try WallpaperEngine.encoder.encode(rotationState)
            try data.write(to: stateURL, options: .atomic)
        } catch {
            print("[WallpaperEngine] Failed to save state: \(error)")
        }
    }

    private static func loadState(from url: URL) -> RotationState? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let state = try? decoder.decode(RotationState.self, from: data)
        else { return nil }
        return state
    }

    private static func resolveStateURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("WallShifter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("rotation.json")
    }
}
