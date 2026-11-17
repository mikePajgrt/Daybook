import SwiftUI

/// Weekday and day number above one column; today's number sits in the interchange circle.
struct DayHeaderView: View {
    let day: Date
    let isToday: Bool
    let calendar: Calendar
    /// Opens the day's own view. `nil` in the day view itself.
    let onOpen: (() -> Void)?

    @ScaledMetric(relativeTo: .callout) private var circle: CGFloat = 26

    var body: some View {
        if let onOpen {
            Button(action: onOpen) { label }
                .buttonStyle(.plain)
                .accessibilityHint("Otevře den")
        } else {
            label
        }
    }

    private var label: some View {
        HStack(spacing: 4) {
            Text(day, format: .dateTime.weekday(.abbreviated))
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.secondaryInk)
            Text(verbatim: String(calendar.component(.day, from: day)))
                .font(.callout.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(isToday ? Theme.ground : Theme.ink)
                .frame(minWidth: circle, minHeight: circle)
                .background { if isToday { Circle().fill(Theme.ink) } }
            Spacer(minLength: 0)
        }
        .padding(.leading, 6)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isToday ? "Dnes, \(day.formatted(date: .complete, time: .omitted))"
                                    : day.formatted(date: .complete, time: .omitted))
    }
}
