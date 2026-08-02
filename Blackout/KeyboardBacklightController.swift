import Foundation

final class KeyboardBacklightController {
    static let shared = KeyboardBacklightController()
    private var restoreBrightness: Float = 0
    private var restoreAfterBlackout = false

    @discardableResult
    func turnOffForBlackout() -> Bool {
        let currentBrightness = KeyboardBacklightBridge.brightness()
        guard currentBrightness >= 0 else { return false }
        guard currentBrightness > 0.001 else {
            restoreAfterBlackout = false
            return true
        }
        restoreBrightness = currentBrightness
        guard KeyboardBacklightBridge.setBrightness(0) else {
            return false
        }
        restoreAfterBlackout = true
        return true
    }

    func restoreAfterBlackoutIfNeeded() {
        guard restoreAfterBlackout else { return }
        restoreAfterBlackout = false
        let currentBrightness = KeyboardBacklightBridge.brightness()
        guard currentBrightness >= 0 else { return }
        guard currentBrightness <= 0.001 else { return }
        _ = KeyboardBacklightBridge.setBrightness(restoreBrightness)
    }
}
