import DaybookCore
import SwiftUI

/// The month: a weekday header and week rows of unequal height that never hide an event.
struct MonthView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selectedDay: SelectedDay?

    private var compact: Bool { sizeClass == .compact }

    private var weekdaySymbols: [String] {
        let symbols = model.calendar.shortStandaloneWeekdaySymbols
        let first = model.calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        VStack(spacing: 0) {
            weekdayHeader
            GeometryReader { proxy in
                // Below this column width a time and a readable title no longer fit on one row.
                let dense = proxy.size.width / 7 < 130
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(model.weeks) { week in
                            WeekRowView(week: week, today: model.today, calendar: model.calendar,
                                        compact: dense, color: color(for:),
                                        onSelectDay: dense ? { selectedDay = SelectedDay(date: $0) } : nil)
                                .frame(maxHeight: .infinity)
                        }
                    }
                    .frame(minHeight: proxy.size.height)
                }
            }
        }
        .background(Theme.ground)
        .foregroundStyle(Theme.ink)
        .sheet(item: $selectedDay) { day in
            NavigationStack { DayListView(day: day.date) }
                .presentationDetents([.medium, .large])
        }
    }

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryInk)
                    .padding(.leading, compact ? 3 : 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
        .accessibilityHidden(true)
    }

    private func color(for calendarID: String) -> Color {
        Color(model.calendarInfo(calendarID)?.color ?? RGBA(r: 0.56, g: 0.56, b: 0.58))
    }
}
