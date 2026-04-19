import SwiftUI

private let cardWidth: CGFloat = 312

struct BrightnessPanel: View {
    @ObservedObject var viewModel: BrightnessViewModel

    var body: some View {
        VStack(spacing: 8) {
            if viewModel.displays.isEmpty {
                emptyState
            } else {
                ForEach(viewModel.displays) { display in
                    DisplaySliderCard(display: display) { newValue in
                        viewModel.setBrightness(for: display.id, to: newValue)
                    }
                }
            }

            if viewModel.displays.count > 1 {
                syncToggle
            }

            footer
        }
        .padding(10)
        .fixedSize()
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "display.trianglebadge.exclamationmark")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.secondary)
            Text("No controllable displays")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(width: cardWidth)
        .padding(.vertical, 24)
        .background {
            cardBackground
        }
    }

    private var syncToggle: some View {
        HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
            Text("Sync All Displays")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
            Toggle("", isOn: $viewModel.syncEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .frame(width: cardWidth)
        .background {
            cardBackground
        }
    }

    private var footer: some View {
        Button(action: { NSApplication.shared.terminate(nil) }) {
            Text("Quit")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(width: cardWidth, alignment: .leading)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .padding(.top, 2)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(.primary.opacity(0.06))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.06), radius: 3, y: 1)
    }
}
