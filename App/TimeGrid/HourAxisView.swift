import SwiftUI

/// Hour labels in the gutter, each centred on its rule. Scroll targets carry the id `"hour-<h>"`.
struct HourAxisView: View {
    let metrics: TimeGridMetrics
    let width: CGFloat
    let calendar: Calendar
    let day: Date

    static func id(hour: Int) -> String { "hour-\(hour)" }

    var body: some View {
        VStack(spacing: 0) {
            Color.clear.frame(height: metrics.inset)
            ForEach(0..<24, id: \.self) { hour in
                Color.clear
                    .frame(height: metrics.hourHeight)
                    .overlay(alignment: .topTrailing) {
                        label(hour)
                            .frame(height: metrics.inset * 2)
                            .offset(y: -metrics.inset)
                    }
            }
            Color.clear.frame(height: metrics.inset)
        }
        .background(alignment: .top) {
            // Scroll targets start where each hour's label starts, half a label above its rule,
            // so scrolling to an hour shows its label whole.
            VStack(spacing: 0) {
                ForEach(0..<24, id: \.self) { hour in
                    Color.clear.frame(height: metrics.hourHeight).id(Self.id(hour: hour))
                }
            }
        }
        .frame(width: width)
        .accessibilityHidden(true)
    }

    private func label(_ hour: Int) -> some View {
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day) ?? day
        return Text(TimeText.time(date))
            .font(.caption2)
            .monospacedDigit()
            .foregroundStyle(Theme.secondaryInk)
            .lineLimit(1)
            .padding(.trailing, 6)
    }
}
