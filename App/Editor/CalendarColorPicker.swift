import DaybookCore
import SwiftUI

/// Calendar colour: a row of presets that read on both grounds, then the system colour picker
/// for any other colour.
struct CalendarColorPicker: View {
    @Binding var color: RGBA
    @Environment(\.self) private var environment

    private static let names = ["Červená", "Oranžová", "Jantarová", "Zelená", "Tyrkysová", "Modrá", "Fialová", "Růžová"]

    var body: some View {
        // One row of eight where the card is wide enough (iPad, Mac), otherwise two rows of four;
        // either way the swatches spread across the card's width.
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { swatches(0..<8) }
            VStack(spacing: 4) {
                HStack(spacing: 4) { swatches(0..<4) }
                HStack(spacing: 4) { swatches(4..<8) }
            }
        }
        .padding(.vertical, 2)
        ColorPicker("Vlastní barva", selection: Binding(get: { Color(color) }, set: { color = rgba($0) }),
                    supportsOpacity: false)
    }

    private func swatches(_ range: Range<Int>) -> some View {
        ForEach(range, id: \.self) { index in
            let preset = Palette.calendarPresets[index]
            let selected = isClose(preset, color)
            Button { color = preset } label: {
                Circle()
                    .fill(Color(preset))
                    .frame(width: 28, height: 28)
                    .padding(4)
                    .overlay { if selected { Circle().stroke(Theme.ink, lineWidth: 2) } }
                    .frame(minWidth: 44, maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Self.names[index])
            .accessibilityAddTraits(selected ? .isSelected : [])
        }
    }

    private func rgba(_ value: Color) -> RGBA {
        let resolved = value.resolve(in: environment)
        return RGBA(r: Double(resolved.red), g: Double(resolved.green), b: Double(resolved.blue))
    }

    private func isClose(_ a: RGBA, _ b: RGBA) -> Bool {
        abs(a.r - b.r) < 0.01 && abs(a.g - b.g) < 0.01 && abs(a.b - b.b) < 0.01
    }
}
