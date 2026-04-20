import Foundation

enum ImageSourceType: String, Codable {
    case folder
    case favorites
    case system
}

struct ImageSource: Codable, Identifiable {
    var id: String
    var type: ImageSourceType
    /// Absolute path for `.folder` and `.favorites` types; unused for `.system`
    var path: String
    /// Whether to recurse into subdirectories (`.folder` only)
    var recursive: Bool
    var enabled: Bool

    init(
        id: String = UUID().uuidString,
        type: ImageSourceType,
        path: String = "",
        recursive: Bool = true,
        enabled: Bool = true
    ) {
        self.id = id
        self.type = type
        self.path = path
        self.recursive = recursive
        self.enabled = enabled
    }
}
