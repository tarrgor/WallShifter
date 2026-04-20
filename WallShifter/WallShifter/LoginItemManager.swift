import Foundation
import ServiceManagement

/// Manages launch-at-login registration via `SMAppService` (macOS 13+).
final class LoginItemManager {

    static let shared = LoginItemManager()
    private init() {}

    @available(macOS 13, *)
    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters the app as a login item.
    /// - Parameter enabled: `true` to register, `false` to unregister.
    func setEnabled(_ enabled: Bool) {
        if #available(macOS 13, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("[LoginItemManager] Failed to \(enabled ? "register" : "unregister"): \(error)")
            }
        }
    }
}
