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
            switch SMAppService.mainApp.status {
            case .enabled, .requiresApproval:
                return true
            case .notRegistered, .notFound:
                return false
            @unknown default:
                return false
            }
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
        do {
            if enabled {
                switch service.status {
                case .enabled:
                    return
                case .requiresApproval:
                    SMAppService.openSystemSettingsLoginItems()
                case .notRegistered, .notFound:
                    try service.register()
                    if service.status == .requiresApproval {
                        SMAppService.openSystemSettingsLoginItems()
                    }
                @unknown default:
                    try service.register()
                }
            } else {
                switch service.status {
                case .enabled, .requiresApproval:
                    try service.unregister()
                case .notRegistered, .notFound:
                    break
                @unknown default:
                    break
                }
            }
        } catch {
            NSLog(
                "Blackout: unable to update launch-at-login: %@",
                "\(error)"
            )
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
        guard legacyWasEnabled else {
            defaults.set(true, forKey: Self.migrationKey)
            return
        }

        do {
            try SMAppService.mainApp.register()

            // Remove the old registration only after the replacement succeeds.
            _ = SMLoginItemSetEnabled(
                Self.legacyIdentifier as CFString,
                false
            )
            defaults.set(true, forKey: Self.migrationKey)
        } catch {
            NSLog(
                "Blackout: login item migration failed: %@",
                "\(error)"
            )
        }
    }
}
