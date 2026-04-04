import CoreGraphics
import Foundation

struct DisplayInfo: Identifiable, Equatable {
    let id: CGDirectDisplayID
    let name: String
    var brightness: Float  // 0.0 to 1.0

    var brightnessPercent: Int {
        Int((brightness * 100).rounded())
    }
}
