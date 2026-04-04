import SwiftUI

/// A custom slider matching the macOS Control Center thick-track style.
struct GlassSlider: View {
    @Binding var value: Double
    var range: ClosedRange<Double> = 0...1
    var onChange: ((Double) -> Void)?

    @State private var isDragging = false

    private let trackHeight: CGFloat = 5
    private let thumbSize: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let usable = width - thumbSize
            let fraction = (value - range.lowerBound) / (range.upperBound - range.lowerBound)
            let clamped = min(max(fraction, 0), 1)
            let offset = usable * CGFloat(clamped)

            ZStack(alignment: .leading) {
                // Background track
                Capsule()
                    .fill(.primary.opacity(0.12))
                    .frame(height: trackHeight)

                // Filled track
                Capsule()
                    .fill(.primary.opacity(0.7))
                    .frame(width: max(offset + thumbSize / 2, trackHeight), height: trackHeight)

                // Thumb
                Circle()
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(width: thumbSize, height: thumbSize)
                    .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
                    .offset(x: offset)
                    .scaleEffect(isDragging ? 1.08 : 1.0)
                    .animation(.easeOut(duration: 0.15), value: isDragging)
            }
            .frame(height: max(thumbSize, trackHeight))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        isDragging = true
                        let x = gesture.location.x - thumbSize / 2
                        let fraction = Double(x / usable)
                        let newClamped = min(max(fraction, 0), 1)
                        let newValue = range.lowerBound + newClamped * (range.upperBound - range.lowerBound)
                        value = newValue
                        onChange?(newValue)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )
        }
        .frame(height: thumbSize)
    }
}
