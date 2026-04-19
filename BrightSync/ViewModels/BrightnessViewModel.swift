import AppKit
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
    private var persistDebounceTask: Task<Void, Never>?
    private var didMigrate = false
    private var knownStableKeys: Set<String> = []

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
        // and debounce-persist the result so F1/F2 intent isn't lost if a display
        // later disconnects and reconnects.
        NotificationCenter.default.publisher(for: .brightnessChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.refreshBrightness()
                self?.scheduleDebouncedPersist()
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
        let currentKeys = Set(newDisplays.map(\.stableKey))
        let firstPass = knownStableKeys.isEmpty
        let newlyAppeared = firstPass ? [] : newDisplays.filter { !knownStableKeys.contains($0.stableKey) }

        logger.info("handleDisplayChange: \(newDisplays.count) displays, \(saved.count) saved entries, firstPass=\(firstPass), newlyAppeared=\(newlyAppeared.count)")
        for d in newDisplays {
            logger.info("  display id=\(d.id) name=\(d.name) stableKey=\(d.stableKey, privacy: .public) liveBrightness=\(d.brightness)")
        }
        for (k, v) in saved {
            logger.info("  saved[\(k, privacy: .public)]=\(v)")
        }

        // On first enumeration after launch, just record what's here. Existing
        // displays keep whatever brightness the OS has — we don't force them
        // back to persisted values on cold launch. Subsequent reconfigurations
        // only restore brightness for displays that are actually new (unplug/
        // replug of an external, or a display added that we've seen before).
        displays = newDisplays.map { display in
            var d = display
            if firstPass {
                logger.info("  → first pass: leaving id=\(d.id) at live \(d.brightness)")
            } else if knownStableKeys.contains(d.stableKey) {
                logger.info("  → existing display id=\(d.id) stableKey=\(d.stableKey, privacy: .public): leaving at live \(d.brightness)")
            } else if let savedValue = saved[d.stableKey] {
                logger.info("  → new display id=\(d.id) stableKey=\(d.stableKey, privacy: .public): restoring to \(savedValue)")
                d.brightness = savedValue
                service.setBrightness(for: d.id, to: savedValue)
            } else {
                logger.info("  → new display id=\(d.id) stableKey=\(d.stableKey, privacy: .public): no saved value, leaving at \(d.brightness)")
            }
            return d
        }

        knownStableKeys = currentKeys

        // Single re-apply 500ms later, scoped to newly-connected displays only.
        // Handles the case where macOS briefly overrides brightness right after
        // a reconnect. Existing displays are never touched by this path.
        let snapshot: [(CGDirectDisplayID, String, Float)] = newlyAppeared.compactMap { d in
            guard let v = saved[d.stableKey] else { return nil }
            return (d.id, d.stableKey, v)
        }
        reapplyTask?.cancel()
        guard !snapshot.isEmpty else { return }
        reapplyTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self, !Task.isCancelled else { return }
            let online = Self.activeDisplayIDs()
            for (id, key, value) in snapshot where online.contains(id) {
                logger.info("re-apply new display: id=\(id) stableKey=\(key, privacy: .public) → \(value)")
                self.service.setBrightness(for: id, to: value)
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

    private func scheduleDebouncedPersist() {
        persistDebounceTask?.cancel()
        persistDebounceTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let self, !Task.isCancelled else { return }
            logger.info("debounced persist: writing \(self.displays.count) displays to V2")
            self.persistBrightness()
        }
    }

    private static func activeDisplayIDs() -> Set<CGDirectDisplayID> {
        var ids = [CGDirectDisplayID](repeating: 0, count: 16)
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(16, &ids, &count) == .success else { return [] }
        return Set(ids.prefix(Int(count)))
    }
}
