import Foundation

/// Maps to NSWorkspace desktop image scaling options
enum WallpaperFitting: String, Codable {
    case fill
    case fit
    case stretch
    case center
    case tile
}

enum DisplayMode: String, Codable {
    /// Same image on every display
    case allSame
    /// A different image per display, drawn from the same source
    case allDifferent
    /// Each display has its own independent source and schedule
    case perDisplay
}

/// Per-display wallpaper settings
struct DisplayConfig: Codable, Identifiable {
    /// Matches the persistent display identifier from NSScreen.deviceDescription
    var id: String
    var fitting: WallpaperFitting
    /// Source ID override; nil means use the global source list
    var sourceID: String?
    /// When true this display rotates independently of others
    var independentRotation: Bool

    init(
        id: String,
        fitting: WallpaperFitting = .fill,
        sourceID: String? = nil,
        independentRotation: Bool = false
    ) {
        self.id = id
        self.fitting = fitting
        self.sourceID = sourceID
        self.independentRotation = independentRotation
    }
}
