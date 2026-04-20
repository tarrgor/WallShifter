import Foundation
import Combine

/// Manages persistent storage of `AppConfig` and security-scoped bookmarks.
///
/// Config is stored at `~/Library/Application Support/WallShifter/config.json`.
/// Security-scoped bookmarks (one per `ImageSource.id`) are stored in `UserDefaults`
/// under the key `"bookmark.<sourceID>"`.
final class ConfigStore: ObservableObject {

    @Published var config: AppConfig

    // MARK: - Private

    private let configURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let saveQueue = DispatchQueue(label: "com.wallshifter.config-save", qos: .utility)
    private var saveCancellable: AnyCancellable?

    // MARK: - Init

    init() {
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        configURL = ConfigStore.resolveConfigURL()

        if let loaded = ConfigStore.load(from: configURL, decoder: decoder) {
            config = loaded
        } else {
            config = AppConfig()
        }

        saveCancellable = $config
            .dropFirst()
            .debounce(for: .milliseconds(500), scheduler: saveQueue)
            .sink { [weak self] snapshot in self?.persist(snapshot) }
    }

    // MARK: - Config persistence

    private func persist(_ config: AppConfig) {
        do {
            let data = try encoder.encode(config)
            try data.write(to: configURL, options: .atomic)
        } catch {
            print("[ConfigStore] Failed to save config: \(error)")
        }
    }

    /// Immediately persists the current config, bypassing the debounce delay.
    /// Call from `applicationWillTerminate` to ensure in-flight changes are not lost.
    func saveNow() {
        let snapshot = config
        saveQueue.sync { self.persist(snapshot) }
    }

    private static func load(from url: URL, decoder: JSONDecoder) -> AppConfig? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        do {
            let data = try Data(contentsOf: url)
            return try decoder.decode(AppConfig.self, from: data)
        } catch {
            print("[ConfigStore] Failed to load config: \(error)")
            return nil
        }
    }

    private static func resolveConfigURL() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let dir = appSupport.appendingPathComponent("WallShifter", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("config.json")
    }

    // MARK: - Security-scoped bookmarks

    private static func bookmarkKey(for sourceID: String) -> String {
        "bookmark.\(sourceID)"
    }

    /// Stores a security-scoped bookmark for the given source ID.
    func saveBookmark(_ bookmarkData: Data, for sourceID: String) {
        UserDefaults.standard.set(bookmarkData, forKey: ConfigStore.bookmarkKey(for: sourceID))
    }

    /// Creates and stores a security-scoped bookmark for `url`, associating it with `sourceID`.
    /// Returns `false` if bookmark creation fails.
    @discardableResult
    func createAndSaveBookmark(for url: URL, sourceID: String) -> Bool {
        do {
            let data = try url.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            saveBookmark(data, for: sourceID)
            return true
        } catch {
            print("[ConfigStore] Failed to create bookmark for \(url.path): \(error)")
            return false
        }
    }

    /// Resolves a stored security-scoped bookmark for `sourceID`.
    /// Starts and stops access around the resolution so callers get a stable URL.
    /// Returns `nil` if no bookmark exists or resolution fails.
    func resolveBookmark(for sourceID: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: ConfigStore.bookmarkKey(for: sourceID)) else {
            return nil
        }
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                // Refresh the bookmark so it doesn't expire
                createAndSaveBookmark(for: url, sourceID: sourceID)
            }
            return url
        } catch {
            print("[ConfigStore] Failed to resolve bookmark for \(sourceID): \(error)")
            return nil
        }
    }

    /// Removes the bookmark for a source that has been deleted.
    func removeBookmark(for sourceID: String) {
        UserDefaults.standard.removeObject(forKey: ConfigStore.bookmarkKey(for: sourceID))
    }
}
