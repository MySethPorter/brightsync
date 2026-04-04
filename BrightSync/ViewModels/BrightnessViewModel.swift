import Combine
import CoreGraphics
import Foundation
import os.log

private let logger = Logger(subsystem: "com.eriknielsen.brightsync", category: "BrightnessViewModel")

@MainActor
final class BrightnessViewModel: ObservableObject {
    @Published var displays: [DisplayInfo] = []
    @Published var syncEnabled: Bool {
        didSet {
            UserDefaults.standard.set(syncEnabled, forKey: "syncEnabled")
            if syncEnabled, let first = displays.first {
                setAllBrightness(to: first.brightness)
            }
        }
    }

    private let monitor = DisplayMonitor()
    private let service = DisplayService.shared
    private var cancellables = Set<AnyCancellable>()

    init() {
        syncEnabled = UserDefaults.standard.bool(forKey: "syncEnabled")

        monitor.$displays
            .receive(on: RunLoop.main)
            .sink { [weak self] newDisplays in
                self?.handleDisplayChange(newDisplays)
            }
            .store(in: &cancellables)

        // Refresh slider positions when brightness changes externally (F1/F2 keys)
        NotificationCenter.default.publisher(for: .brightnessChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshBrightness()
            }
            .store(in: &cancellables)
    }

    func setBrightness(for displayID: CGDirectDisplayID, to value: Float) {
        if syncEnabled {
            setAllBrightness(to: value)
        } else {
            service.setBrightness(for: displayID, to: value)
            if let idx = displays.firstIndex(where: { $0.id == displayID }) {
                displays[idx].brightness = value
            }
        }
        persistBrightness()
    }

    func refreshBrightness() {
        for i in displays.indices {
            if let current = service.getBrightness(for: displays[i].id) {
                displays[i].brightness = current
            }
        }
    }

    // MARK: - Private

    private func setAllBrightness(to value: Float) {
        for i in displays.indices {
            service.setBrightness(for: displays[i].id, to: value)
            displays[i].brightness = value
        }
    }

    private func handleDisplayChange(_ newDisplays: [DisplayInfo]) {
        let saved = savedBrightness()
        displays = newDisplays.map { display in
            var d = display
            if let savedValue = saved[String(d.id)] {
                d.brightness = savedValue
                service.setBrightness(for: d.id, to: savedValue)
            }
            return d
        }
    }

    private func persistBrightness() {
        var dict: [String: Float] = [:]
        for display in displays {
            dict[String(display.id)] = display.brightness
        }
        UserDefaults.standard.set(dict, forKey: "displayBrightness")
    }

    private func savedBrightness() -> [String: Float] {
        UserDefaults.standard.dictionary(forKey: "displayBrightness") as? [String: Float] ?? [:]
    }
}
