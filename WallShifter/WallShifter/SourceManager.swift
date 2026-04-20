import Foundation
import Combine

/// Enumerates image files from all enabled `ImageSource`s and watches folders for live changes.
///
/// `allImages` is always updated on the main actor. File-system work runs on a
/// background queue; only plain value types are captured so no actor isolation
/// boundary is crossed in the background.
final class SourceManager: ObservableObject {

    @Published private(set) var allImages: [URL] = []

    private let configStore: ConfigStore
    private var cancellables = Set<AnyCancellable>()
    private var fsEventStream: FSEventStreamRef?

    private static let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "tiff", "tif", "gif", "webp"
    ]

    // MARK: - Init

    init(configStore: ConfigStore) {
        self.configStore = configStore
        refresh()

        // Re-enumerate when sources list changes.
        // `.receive(on: DispatchQueue.main)` defers delivery to the next run-loop turn so
        // that the @Published willSet has completed and configStore.config holds the new value
        // by the time refresh() reads it.
        configStore.$config
            .map { $0.sources.map { [$0.id, $0.path, $0.enabled.description, $0.recursive.description].joined() } }
            .removeDuplicates()
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &cancellables)
    }

    deinit {
        stopFSEventStream()
    }

    // MARK: - Public

    func refresh() {
        // Resolve all data that requires main-actor access before dispatching to background
        let sources = configStore.config.sources.filter(\.enabled)
        var resolvedEntries: [(source: ImageSource, resolvedURL: URL?)] = []
        for source in sources {
            let url: URL?
            if source.type == .folder || source.type == .favorites {
                if !source.path.isEmpty {
                    url = URL(fileURLWithPath: source.path)
                } else {
                    url = configStore.resolveBookmark(for: source.id)
                }
            } else {
                url = nil // system sources don't need resolution
            }
            resolvedEntries.append((source, url))
        }

        let watchedPaths: [String] = resolvedEntries
            .filter { $0.source.type == .folder }
            .compactMap { $0.resolvedURL?.path }

        DispatchQueue.global(qos: .utility).async { [resolvedEntries, weak self] in
            var seen = Set<URL>()
            var results: [URL] = []
            for entry in resolvedEntries {
                for url in SourceManager.imageURLs(for: entry.source, resolvedURL: entry.resolvedURL) {
                    if seen.insert(url).inserted {
                        results.append(url)
                    }
                }
            }
            DispatchQueue.main.async {
                self?.allImages = results
                self?.restartFSEventStream(paths: watchedPaths)
            }
        }
    }

    // MARK: - Private: enumeration (nonisolated, safe to call from background)

    private static func imageURLs(for source: ImageSource, resolvedURL: URL?) -> [URL] {
        switch source.type {
        case .folder:
            guard let url = resolvedURL else { return [] }
            return enumerateFolder(url, recursive: source.recursive)
        case .favorites:
            // Individual bookmarks not yet implemented
            return []
        case .system:
            return enumerateFolder(URL(fileURLWithPath: "/Library/Desktop Pictures"), recursive: true)
        }
    }

    private static func enumerateFolder(_ url: URL, recursive: Bool) -> [URL] {
        var options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
        if !recursive { options.insert(.skipsSubdirectoryDescendants) }
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: options
        ) else { return [] }

        var results: [URL] = []
        for case let fileURL as URL in enumerator {
            if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                results.append(fileURL)
            }
        }
        return results
    }

    // MARK: - FSEventStream

    private func restartFSEventStream(paths: [String]) {
        stopFSEventStream()
        guard !paths.isEmpty else { return }

        var ctx = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            // Callback runs on .main (see FSEventStreamSetDispatchQueue below)
            Unmanaged<SourceManager>.fromOpaque(info).takeUnretainedValue().refresh()
        }

        guard let stream = FSEventStreamCreate(
            nil,
            callback,
            &ctx,
            paths as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            2.0, // coalesce events over 2 seconds
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else { return }

        // Use main queue so the callback can safely call refresh() on @MainActor
        FSEventStreamSetDispatchQueue(stream, .main)
        FSEventStreamStart(stream)
        fsEventStream = stream
    }

    private func stopFSEventStream() {
        guard let stream = fsEventStream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        fsEventStream = nil
    }
}
