import ServiceManagement

final class LaunchAtLoginService {
    static let shared = LaunchAtLoginService()
    private static let legacyIdentifier = "com.norgera.Blackout.LoginItem"
    private static let migrationKey = "migratedLegacyLoginItem"

    private init() {
        migrateLegacyRegistrationIfNeeded()
    }

    var isAvailable: Bool {
        true
    }

    var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return isLegacyEnabled
    }

    func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            _ = SMLoginItemSetEnabled(
                Self.legacyIdentifier as CFString,
                enabled
            )
            return
        }
        let service = SMAppService.mainApp
        if enabled {
            if service.status == .requiresApproval {
                SMAppService.openSystemSettingsLoginItems()
            } else if service.status != .enabled {
                try? service.register()
            }
        } else if service.status == .enabled ||
                    service.status == .requiresApproval {
            try? service.unregister()
        }
    }

    private var isLegacyEnabled: Bool {
        guard let jobs = SMCopyAllJobDictionaries(kSMDomainUserLaunchd)?
            .takeRetainedValue() as? [[String: Any]] else {
            return false
        }
        return jobs.contains {
            $0["Label"] as? String == Self.legacyIdentifier &&
            ($0["OnDemand"] as? Bool ?? false)
        }
    }

    private func migrateLegacyRegistrationIfNeeded() {
        guard #available(macOS 13.0, *) else { return }
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: Self.migrationKey) else { return }
        let legacyWasEnabled = isLegacyEnabled
        _ = SMLoginItemSetEnabled(
            Self.legacyIdentifier as CFString,
            false
        )
        if legacyWasEnabled && SMAppService.mainApp.status != .enabled {
            try? SMAppService.mainApp.register()
        }
        defaults.set(true, forKey: Self.migrationKey)
    }
}
