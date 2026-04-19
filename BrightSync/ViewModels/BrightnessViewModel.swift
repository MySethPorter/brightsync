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
    private var reapplyTask: Task<Void, Never>?

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
            if let savedValue = saved[d.stableKey] {
                d.brightness = savedValue
                service.setBrightness(for: d.id, to: savedValue)
            }
            return d
        }

        // macOS can override brightness during/after Sidecar reconfig; re-apply once
        // to win the race. Snapshot current active IDs so we don't touch displays
        // that dropped offline (e.g. Sidecar disconnected) in the interim.
        let snapshot: [(CGDirectDisplayID, Float)] = displays.compactMap { d in
            guard let v = saved[d.stableKey] else { return nil }
            return (d.id, v)
        }
        reapplyTask?.cancel()
        reapplyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self, !Task.isCancelled else { return }
            let online = Self.activeDisplayIDs()
            for (id, value) in snapshot where online.contains(id) {
                self.service.setBrightness(for: id, to: value)
            }
        }
    }

    private func persistBrightness() {
        var dict: [String: Float] = [:]
        for display in displays {
            dict[display.stableKey] = display.brightness
        }
        UserDefaults.standard.set(dict, forKey: "displayBrightnessV2")
    }

    private func savedBrightness() -> [String: Float] {
        UserDefaults.standard.dictionary(forKey: "displayBrightnessV2") as? [String: Float] ?? [:]
    }

    private static func activeDisplayIDs() -> Set<CGDirectDisplayID> {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(16, &ids, &count) == .success else { return [] }
        return Set(ids.prefix(Int(count)))
    }
}
