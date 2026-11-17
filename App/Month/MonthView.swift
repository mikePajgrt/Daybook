import DaybookCore
import SwiftUI

/// The month: a weekday header and week rows of unequal height that never hide an event.
struct MonthView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDay: SelectedDay?

    @ScaledMetric(relativeTo: .caption) private var rowHeight: CGFloat = 17
    @ScaledMetric(relativeTo: .caption) private var numberHeight: CGFloat = 28

    private var compact: Bool { sizeClass == .compact }

    private var weekdaySymbols: [String] {
        let symbols = model.calendar.shortStandaloneWeekdaySymbols
        let first = model.calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        GeometryReader { outer in
            // Below this column width a time and a readable title no longer fit on one row.
            let dense = outer.size.width / 7 < 130
            if dense && dynamicTypeSize.isAccessibilitySize {
                MonthAgendaView(color: color(for:))
            } else {
                VStack(spacing: 0) {
                    weekdayHeader
                    GeometryReader { proxy in
                        grid(viewport: proxy.size.height, dense: dense)
                    }
                }
            }
        }
        .background(Theme.ground)
        .foregroundStyle(Theme.ink)
        .sheet(item: $selectedDay) { day in
            NavigationStack { DayListView(day: day.date) }
                .presentationDetents([.medium, .large])
        }
        .onAppear {
            if model.stagedScreens.contains("day") { selectedDay = SelectedDay(date: model.today) }
        }
    }

    /// Every week gets the height its fullest day needs. Space left over in the viewport
    /// is shared in proportion to that, so busy weeks stay the tall ones.
    private func heights(viewport: CGFloat, metrics: WeekMetrics) -> [CGFloat] {
        let needed = model.weeks.map(metrics.contentHeight(for:))
        let total = needed.reduce(0, +)
        guard total > 0, viewport > total else { return needed }
        return needed.map { $0 + (viewport - total) * $0 / total }
    }

    private func grid(viewport: CGFloat, dense: Bool) -> some View {
        let metrics = WeekMetrics(rowHeight: rowHeight, numberHeight: numberHeight)
        let rows = Array(zip(model.weeks, heights(viewport: viewport, metrics: metrics)))
        return ScrollViewReader { reader in
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(rows, id: \.0.id) { week, height in
                        WeekRowView(week: week, today: model.today, calendar: model.calendar,
                                    metrics: metrics, compact: dense, color: color(for:),
                                    onSelectDay: dense ? { selectedDay = SelectedDay(date: $0) } : nil)
                            .frame(height: height)
                            .id(week.id)
                    }
                }
            }
            .task(id: model.scrollKey) {
                // Open on the week that holds today; a month without today opens at its top.
                let target = model.weeks.first { $0.days.contains { $0.date == model.today } } ?? model.weeks.first
                if let target { reader.scrollTo(target.id, anchor: .top) }
            }
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
