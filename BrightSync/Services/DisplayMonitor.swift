import AppKit
import Combine
import CoreGraphics
import Foundation
import os.log

private let logger = Logger(subsystem: "com.eriknielsen.brightsync", category: "DisplayMonitor")

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
        logger.info("didChangeScreenParametersNotification fired")
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            guard !Task.isCancelled else { return }
            logger.info("debounce elapsed, refreshing displays")
            refresh()
        }
    }

    func refresh() {
        let service = DisplayService.shared

        var infos: [(displayID: CGDirectDisplayID, baseName: String, isMain: Bool, brightness: Float)] = []

        for screen in NSScreen.screens {
            guard let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
                continue
            }
            guard let brightness = service.getBrightness(for: displayID) else { continue }
            // Strip existing numbering like " (2)" from the localized name
            let baseName = screen.localizedName.replacingOccurrences(of: #"\s*\(\d+\)$"#, with: "", options: .regularExpression)
            let isMain = (screen == NSScreen.main)
            infos.append((displayID, baseName, isMain, brightness))
        }

        // Renumber displays that share the same base name, with main display as (1)
        var nameCount: [String: Int] = [:]
        for info in infos { nameCount[info.baseName, default: 0] += 1 }

        var nameCounter: [String: Int] = [:]
        // Sort: main display first, then by display ID for stability
        let sorted = infos.sorted { a, b in
            if a.isMain != b.isMain { return a.isMain }
            return a.displayID < b.displayID
        }

        displays = sorted.map { info in
            let name: String
            if nameCount[info.baseName, default: 0] > 1 {
                let num = (nameCounter[info.baseName, default: 0]) + 1
                nameCounter[info.baseName] = num
                name = "\(info.baseName) (\(num))"
            } else {
                name = info.baseName
            }
            return DisplayInfo(id: info.displayID, name: name, brightness: info.brightness)
        }

        logger.info("Found \(self.displays.count) controllable display(s)")
    }
}
