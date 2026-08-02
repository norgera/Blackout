import ServiceManagement

final class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()

    var isAvailable: Bool {
        if #available(macOS 13.0, *) { return true }
        return false
    }

    var isEnabled: Bool {
        guard #available(macOS 13.0, *) else { return false }

        switch SMAppService.mainApp.status {
        case .enabled, .requiresApproval:
            return true
        default:
            return false
        }
    }

    func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else { return }

        let service = SMAppService.mainApp
        do {
            if enabled {
                if service.status == .requiresApproval {
                    SMAppService.openSystemSettingsLoginItems()
                } else if service.status != .enabled {
                    try service.register()
                }
            } else if service.status == .enabled {
                try service.unregister()
            }
        } catch {
            NSLog("Blackout: unable to update launch-at-login: %@", "\(error)")
        }
    }
}
