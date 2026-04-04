import Cocoa
import Combine
import os.log

private let logger = Logger(subsystem: "com.eriknielsen.brightsync", category: "BrightnessKeyManager")

/// Monitors brightness changes from F1/F2 keys (handled natively by macOS)
/// and syncs all other displays to match.
///
/// macOS handles brightness keys at a level below CGEventTap, so we can't intercept them.
/// Instead, we poll the main display brightness at a fast interval and propagate changes.
final class BrightnessKeyManager {
    private var timer: Timer?
    private var lastKnownBrightness: [CGDirectDisplayID: Float] = [:]
    private let service = DisplayService.shared

    /// Called on main thread when a display's brightness changed externally.
    var onBrightnessChanged: (() -> Void)?

    func start() {
        // Poll every 100ms — fast enough to feel responsive to F1/F2 presses
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.checkForChanges()
        }
        // Seed initial values
        seedBrightness()
        logger.info("Brightness monitor started")
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        logger.info("Brightness monitor stopped")
    }

    private func seedBrightness() {
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetOnlineDisplayList(16, &displayIDs, &count)

        for i in 0..<Int(count) {
            let id = displayIDs[i]
            if let brightness = service.getBrightness(for: id) {
                lastKnownBrightness[id] = brightness
            }
        }
    }

    private func checkForChanges() {
        let syncEnabled = UserDefaults.standard.bool(forKey: "syncEnabled")

        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetOnlineDisplayList(16, &displayIDs, &count)

        let controllableIDs: [(CGDirectDisplayID, Float)] = (0..<Int(count)).compactMap { i in
            let id = displayIDs[i]
            guard let brightness = service.getBrightness(for: id) else { return nil }
            return (id, brightness)
        }

        // Check if any display's brightness changed externally (e.g. via F1/F2)
        var changed = false

        for (id, current) in controllableIDs {
            if let last = lastKnownBrightness[id], abs(current - last) > 0.005 {
                changed = true
                lastKnownBrightness[id] = current

                // In sync mode: propagate to all other displays
                if syncEnabled {
                    for (otherId, _) in controllableIDs where otherId != id {
                        service.setBrightness(for: otherId, to: current)
                        lastKnownBrightness[otherId] = current
                    }
                }
                break  // Handle one change per cycle to avoid feedback loops
            } else {
                lastKnownBrightness[id] = current
            }
        }

        if changed {
            DispatchQueue.main.async { [weak self] in
                self?.onBrightnessChanged?()
            }
        }
    }

    deinit { stop() }
}
