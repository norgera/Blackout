import Foundation

final class KeyboardBacklightController {
    static let shared = KeyboardBacklightController()
    private let recoveryStore = KeyboardBacklightRecoveryStore()

    @discardableResult
    func turnOffForBlackout() -> Bool {
        let currentBrightness = KeyboardBacklightBridge.brightness()
        guard currentBrightness >= 0 else { return false }
        guard currentBrightness > 0.001 else {
            return true
        }
        guard recoveryStore.save(currentBrightness) else {
            return false
        }
        guard KeyboardBacklightBridge.setBrightness(0) else {
            return false
        }
        return true
    }

    func restoreAfterBlackoutIfNeeded() {
        guard let restoreBrightness = recoveryStore.load() else {
            return
        }
        let currentBrightness = KeyboardBacklightBridge.brightness()
        guard currentBrightness >= 0 else { return }

        guard currentBrightness <= 0.001 else {
            recoveryStore.clear()
            return
        }

        if KeyboardBacklightBridge.setBrightness(restoreBrightness) {
            recoveryStore.clear()
        }
    }
}

private final class KeyboardBacklightRecoveryStore {
    private struct Record: Codable {
        let brightness: Float
    }

    private let fileManager = FileManager.default
    private let fileURL: URL?

    init() {
        fileURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first?
            .appendingPathComponent("Blackout", isDirectory: true)
            .appendingPathComponent("KeyboardBacklightRecovery.plist")
    }

    func save(_ brightness: Float) -> Bool {
        guard let fileURL else { return false }
        do {
            try fileManager.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let data = try PropertyListEncoder().encode(
                Record(brightness: brightness)
            )
            try data.write(to: fileURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    func load() -> Float? {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let record = try? PropertyListDecoder().decode(
                  Record.self,
                  from: data
              ) else {
            return nil
        }
        return record.brightness
    }

    func clear() {
        guard let fileURL else { return }
        try? fileManager.removeItem(at: fileURL)
    }
}
