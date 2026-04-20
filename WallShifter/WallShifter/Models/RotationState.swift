import Foundation

enum RotationOrder: String, Codable {
    case sequential
    case randomNoRepeat
    case random
    case newestFirst
}

struct RotationState: Codable {
    /// Index into the current ordered/shuffled image list
    var currentIndex: Int
    /// Pre-computed shuffle order (image path strings); empty when not in randomNoRepeat mode
    var shuffleQueue: [String]
    /// Ring buffer of recently shown image paths (newest at the end)
    var history: [String]
    /// Maximum number of entries to keep in history
    var historySize: Int
    var lastChangedAt: Date
    var isPaused: Bool

    init(
        currentIndex: Int = 0,
        shuffleQueue: [String] = [],
        history: [String] = [],
        historySize: Int = 20,
        lastChangedAt: Date = .distantPast,
        isPaused: Bool = false
    ) {
        self.currentIndex = currentIndex
        self.shuffleQueue = shuffleQueue
        self.history = history
        self.historySize = historySize
        self.lastChangedAt = lastChangedAt
        self.isPaused = isPaused
    }

    mutating func appendToHistory(_ path: String) {
        history.append(path)
        if history.count > historySize {
            history.removeFirst(history.count - historySize)
        }
    }
}
