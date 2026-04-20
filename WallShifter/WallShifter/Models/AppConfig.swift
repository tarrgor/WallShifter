import Foundation

struct ScheduleConfig: Codable {
    var intervalSeconds: TimeInterval
    var changeOnWake: Bool
    var changeOnLogin: Bool
    var changeOnLaunch: Bool

    init(
        intervalSeconds: TimeInterval = 600,
        changeOnWake: Bool = true,
        changeOnLogin: Bool = true,
        changeOnLaunch: Bool = true
    ) {
        self.intervalSeconds = intervalSeconds
        self.changeOnWake = changeOnWake
        self.changeOnLogin = changeOnLogin
        self.changeOnLaunch = changeOnLaunch
    }
}

struct MinResolution: Codable {
    var width: Int
    var height: Int

    init(width: Int = 1920, height: Int = 1080) {
        self.width = width
        self.height = height
    }
}

enum TransitionStyle: String, Codable {
    case instant
    case fade
}

struct AdvancedConfig: Codable {
    var transition: TransitionStyle
    var historySize: Int
    var minResolution: MinResolution
    var launchAtLogin: Bool

    init(
        transition: TransitionStyle = .instant,
        historySize: Int = 20,
        minResolution: MinResolution = MinResolution(),
        launchAtLogin: Bool = false
    ) {
        self.transition = transition
        self.historySize = historySize
        self.minResolution = minResolution
        self.launchAtLogin = launchAtLogin
    }
}

struct AppConfig: Codable {
    var sources: [ImageSource]
    var schedule: ScheduleConfig
    var order: RotationOrder
    var displayMode: DisplayMode
    var fitting: WallpaperFitting
    var displays: [DisplayConfig]
    var advanced: AdvancedConfig

    init(
        sources: [ImageSource] = [],
        schedule: ScheduleConfig = ScheduleConfig(),
        order: RotationOrder = .randomNoRepeat,
        displayMode: DisplayMode = .allSame,
        fitting: WallpaperFitting = .fill,
        displays: [DisplayConfig] = [],
        advanced: AdvancedConfig = AdvancedConfig()
    ) {
        self.sources = sources
        self.schedule = schedule
        self.order = order
        self.displayMode = displayMode
        self.fitting = fitting
        self.displays = displays
        self.advanced = advanced
    }
}
