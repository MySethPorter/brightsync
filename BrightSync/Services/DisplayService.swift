import CoreGraphics
import Foundation
import os.log

private let logger = Logger(subsystem: "com.eriknielsen.brightsync", category: "DisplayService")

/// Brightness engine using the private DisplayServices framework via dlopen.
/// Supports Apple Studio Display and built-in displays.
final class DisplayService {
    static let shared = DisplayService()

    private typealias GetBrightnessFn = @convention(c) (CGDirectDisplayID, UnsafeMutablePointer<Float>) -> Int32
    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32

    private let _get: GetBrightnessFn?
    private let _set: SetBrightnessFn?

    var isAvailable: Bool { _get != nil && _set != nil }

    private init() {
        let handle = dlopen(
            "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices",
            RTLD_NOW
        )
        if let handle,
           let getSym = dlsym(handle, "DisplayServicesGetBrightness"),
           let setSym = dlsym(handle, "DisplayServicesSetBrightness") {
            _get = unsafeBitCast(getSym, to: GetBrightnessFn.self)
            _set = unsafeBitCast(setSym, to: SetBrightnessFn.self)
        } else {
            logger.warning("DisplayServices framework not available")
            _get = nil
            _set = nil
        }
    }

    func getBrightness(for displayID: CGDirectDisplayID) -> Float? {
        guard let fn = _get else { return nil }
        var value: Float = 0
        let result = fn(displayID, &value)
        guard result == 0 else {
            logger.debug("Failed to read brightness for display \(displayID): error \(result)")
            return nil
        }
        return value
    }

    func setBrightness(for displayID: CGDirectDisplayID, to value: Float) {
        guard let fn = _set else { return }
        let clamped = min(max(value, 0.0), 1.0)
        let result = fn(displayID, clamped)
        if result != 0 {
            logger.warning("Failed to set brightness for display \(displayID): error \(result)")
        }
    }
}
