import DaybookCore
import SwiftUI

/// A small month for picking the day the day view shows. Drawn from the month model in the world's
/// marks rather than with the system date picker, whose system-blue selection was the loudest colour
/// on screen and read like a calendar line: today carries the interchange circle, the shown day a ring.
struct MonthNavigatorView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.colorSchemeContrast) private var contrast
    /// The month on display; follows the day view until the user pages it.
    @State private var month: Date?

    @ScaledMetric(relativeTo: .footnote) private var cell: CGFloat = 32

    private var shownMonth: Date { month ?? model.focusedDate }

    private var weekdaySymbols: [String] {
        let symbols = model.calendar.veryShortStandaloneWeekdaySymbols
        let first = model.calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        let weeks = MonthLayout.weeks(containing: shownMonth, calendar: model.calendar)
        let monthInterval = model.calendar.dateInterval(of: .month, for: shownMonth)
        let focusedDay = model.calendar.startOfDay(for: model.focusedDate)
        VStack(spacing: 6) {
            HStack {
                Text(shownMonth.formatted(.dateTime.month(.wide).year()).localizedCapitalized)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                chevron("Předchozí měsíc", symbol: "chevron.left") { page(by: -1) }
                chevron("Další měsíc", symbol: "chevron.right") { page(by: 1) }
            }
            .buttonStyle(.borderless)
            .foregroundStyle(Theme.ink)
            HStack(spacing: 0) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.secondaryInk)
                        .frame(maxWidth: .infinity)
                }
            }
            .accessibilityHidden(true)
            ForEach(weeks, id: \.self) { week in
                HStack(spacing: 0) {
                    ForEach(week, id: \.self) { day in
                        let inMonth = monthInterval.map { day >= $0.start && day < $0.end } ?? true
                        dayButton(day, inMonth: inMonth, isShown: day == focusedDay)
                    }
                }
            }
        }
        .onChange(of: model.focusedDate) { month = nil }
    }

    private func dayButton(_ day: Date, inMonth: Bool, isShown: Bool) -> some View {
        let isToday = day == model.today
        let ink = inMonth ? Theme.ink : Theme.outsideInk(contrast)
        return Button { model.show(day: day) } label: {
            Text(verbatim: String(model.calendar.component(.day, from: day)))
                .font(.footnote.weight(isToday || isShown ? .bold : .regular))
                .monospacedDigit()
                .foregroundStyle(isToday ? Theme.ground : ink)
                .frame(width: cell, height: cell)
                .background {
                    if isToday { Circle().fill(Theme.ink) }
                }
                .overlay {
                    if isShown { Circle().stroke(Theme.ink, lineWidth: 1.5).padding(isToday ? -3 : 0) }
                }
                .frame(maxWidth: .infinity, minHeight: max(cell + 4, Self.minimumTarget))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted))
        .accessibilityAddTraits(isShown ? .isSelected : [])
    }

    /// Touch screens get 44 pt targets; the Mac keeps the compact month.
    #if os(iOS)
    private static let minimumTarget: CGFloat = 44
    #else
    private static let minimumTarget: CGFloat = 0
    #endif

    private func chevron(_ label: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(minWidth: Self.minimumTarget, minHeight: Self.minimumTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(label)
        .help(label)
    }

    private func page(by count: Int) {
        month = model.calendar.date(byAdding: .month, value: count, to: shownMonth)
    }
}
