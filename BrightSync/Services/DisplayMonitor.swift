import AppKit
import Combine
import CoreGraphics
import Foundation
import os.log

private let logger = Logger(subsystem: "com.eriknielsen.brightsync", category: "DisplayMonitor")

/// Enumerates connected displays and watches for connect/disconnect events.
/// Uses NSScreen.screens order to match Apple's display numbering.
@MainActor
final class DisplayMonitor: ObservableObject {
    @Published var displays: [DisplayInfo] = []
    private var debounceTask: Task<Void, Never>?

    init() {
        refresh()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        debounceTask?.cancel()
    }

    @objc private func screenChanged() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)  // 300ms debounce
            guard !Task.isCancelled else { return }
            refresh()
        }
    }

    func refresh() {
        let service = DisplayService.shared

        // Enumerate via NSScreen.screens to preserve Apple's display ordering and naming
        displays = NSScreen.screens.compactMap { screen in
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                return nil
            }
            let name = screen.localizedName
            guard let brightness = service.getBrightness(for: displayID) else { return nil }
            return DisplayInfo(id: displayID, name: name, brightness: brightness)
        }

        logger.info("Found \(self.displays.count) controllable display(s)")
    }
}
