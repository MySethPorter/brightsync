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
    private var didMigrate = false

    init() {
        syncEnabled = UserDefaults.standard.bool(forKey: "syncEnabled")

        monitor.$displays
            .receive(on: RunLoop.main)
            .sink { [weak self] newDisplays in
                self?.migrateAndSeedIfNeeded(using: newDisplays)
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
        logger.info("handleDisplayChange: \(newDisplays.count) displays, \(saved.count) saved entries")
        for d in newDisplays {
            logger.info("  display id=\(d.id) name=\(d.name) stableKey=\(d.stableKey) liveBrightness=\(d.brightness)")
        }
        for (k, v) in saved {
            logger.info("  saved[\(k)]=\(v)")
        }

        displays = newDisplays.map { display in
            var d = display
            if let savedValue = saved[d.stableKey] {
                logger.info("  → restoring id=\(d.id) stableKey=\(d.stableKey) to \(savedValue)")
                d.brightness = savedValue
                service.setBrightness(for: d.id, to: savedValue)
            } else {
                logger.info("  → no saved value for stableKey=\(d.stableKey), leaving at \(d.brightness)")
            }
            return d
        }

        // macOS can override brightness during/after Sidecar reconfig; re-apply
        // on a staggered schedule to win the race. Snapshot current active IDs
        // on each pass so we don't touch displays that dropped offline.
        let snapshot: [(CGDirectDisplayID, String, Float)] = displays.compactMap { d in
            guard let v = saved[d.stableKey] else { return nil }
            return (d.id, d.stableKey, v)
        }
        reapplyTask?.cancel()
        guard !snapshot.isEmpty else { return }
        reapplyTask = Task { @MainActor [weak self] in
            for delayNs: UInt64 in [250_000_000, 750_000_000, 1_500_000_000] {
                try? await Task.sleep(nanoseconds: delayNs)
                guard let self, !Task.isCancelled else { return }
                let online = Self.activeDisplayIDs()
                for (id, key, value) in snapshot where online.contains(id) {
                    logger.info("re-apply (+\(delayNs / 1_000_000)ms): id=\(id) stableKey=\(key) → \(value)")
                    self.service.setBrightness(for: id, to: value)
                }
            }
        }
    }

    /// On first display list, migrate V1 (raw-ID keyed) entries to V2 (stable-key)
    /// using the current ID→stableKey mapping, then seed V2 from live brightness
    /// for any displays still missing. Ensures the restore path has something to
    /// look up even before the user drags a slider.
    private func migrateAndSeedIfNeeded(using current: [DisplayInfo]) {
        guard !didMigrate else { return }
        didMigrate = true

        var v2 = savedBrightness()

        let v1 = UserDefaults.standard.dictionary(forKey: "displayBrightness") as? [String: Float] ?? [:]
        if !v1.isEmpty {
            for d in current {
                if v2[d.stableKey] == nil, let v = v1[String(d.id)] {
                    v2[d.stableKey] = v
                    logger.info("migrated V1 id=\(d.id) → V2 stableKey=\(d.stableKey) value=\(v)")
                }
            }
            UserDefaults.standard.removeObject(forKey: "displayBrightness")
        }

        for d in current where v2[d.stableKey] == nil {
            v2[d.stableKey] = d.brightness
            logger.info("seeded V2 stableKey=\(d.stableKey) from live brightness \(d.brightness)")
        }

        UserDefaults.standard.set(v2, forKey: "displayBrightnessV2")
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
