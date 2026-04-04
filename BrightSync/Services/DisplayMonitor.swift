import AppKit
import Combine
import CoreGraphics
import Foundation
import os.log

private let logger = Logger(subsystem: "com.eriknielsen.brightsync", category: "DisplayMonitor")

/// Enumerates connected displays and watches for connect/disconnect events.
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
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        CGGetOnlineDisplayList(16, &displayIDs, &count)

        let service = DisplayService.shared
        displays = (0..<Int(count)).compactMap { i in
            let id = displayIDs[i]
            let name = screenName(for: id) ?? "Display \(i + 1)"
            guard let brightness = service.getBrightness(for: id) else { return nil }
            return DisplayInfo(id: id, name: name, brightness: brightness)
        }

        logger.info("Found \(self.displays.count) controllable display(s)")
    }

    private func screenName(for displayID: CGDirectDisplayID) -> String? {
        NSScreen.screens.first { screen in
            let num = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
            return num == displayID
        }?.localizedName
    }
}
