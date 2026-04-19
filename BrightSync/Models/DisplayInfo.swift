import CoreGraphics
import Foundation

struct DisplayInfo: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
    var brightness: Float  // 0.0 to 1.0

    var brightnessPercent: Int {
        Int((brightness * 100).rounded())
    }

    var stableKey: String { id.stableKey }
}

extension CGDirectDisplayID {
    /// Persistence key derived from EDID vendor/model/serial so it survives
    /// CGDirectDisplayID reassignment across reconfigurations (Sidecar connect
    /// can renumber displays, stranding raw-ID-keyed state).
    var stableKey: String {
        let vendor = CGDisplayVendorNumber(self)
        let model = CGDisplayModelNumber(self)
        let serial = CGDisplaySerialNumber(self)
        if vendor != 0 || model != 0 || serial != 0 {
            return "v\(vendor)-m\(model)-s\(serial)"
        }
        return "id-\(self)"
    }
}
