import SwiftUI

struct DisplaySliderCard: View {
    let display: DisplayInfo
    let onChange: (Float) -> Void

    @State private var sliderValue: Double

    init(display: DisplayInfo, onChange: @escaping (Float) -> Void) {
        self.display = display
        self.onChange = onChange
        self._sliderValue = State(initialValue: Double(display.brightness))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Display name
            Text(display.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)

            // Brightness slider row
            HStack(spacing: 12) {
                Image(systemName: "sun.min")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                GlassSlider(value: $sliderValue) { newValue in
                    onChange(Float(newValue))
                }

                Image(systemName: "sun.max")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(width: 312)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.primary.opacity(0.06))
                .overlay {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
                }
                .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
        }
        .onChange(of: display.brightness) { _, newValue in
            let newDouble = Double(newValue)
            if abs(sliderValue - newDouble) > 0.005 {
                withAnimation(.easeOut(duration: 0.15)) {
                    sliderValue = newDouble
                }
            }
        }
    }
}
