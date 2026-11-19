import DaybookCore
import SwiftUI

/// Any view at accessibility text sizes on narrow screens: one full-width row per day,
/// so every event keeps its time and its whole title. Neither seven month columns nor
/// time-grid columns can hold them at that size.
struct AgendaView: View {
    @Environment(AppModel.self) private var model
    @Environment(CategoryModel.self) private var categoryModel
    let days: [Date]
    let color: (String) -> ThemeColor
    /// Diameter of the interchange circle around today's number.
    @ScaledMetric(relativeTo: .title3) private var numberSize: CGFloat = 34

    /// The day at the top; setting it scrolls there.
    @State private var topDay: Date?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(days, id: \.self) { day in
                    row(day)
                        .id(day)
                }
            }
            .scrollTargetLayout()
        }
        .scrollPosition(id: $topDay, anchor: .top)
        // Also when the days arrive: the month's are laid out after the view first appears.
        .task(id: "\(model.scrollKey)-\(days.count)") {
            // Today at the top, as the month opens; another period opens on its first day. Set again
            // once the rows have their heights, which come with the events.
            let target = days.contains(model.today) ? model.today : days.first
            topDay = target
            try? await Task.sleep(for: .milliseconds(400))
            topDay = nil
            await Task.yield()
            topDay = target
        }
        #if os(iOS)
        // An opaque bar on the ground: with the soft scroll edge, large digits blurred through the title.
        .themeToolbarBackground(Theme.ground, for: .navigationBar)
        .toolbarBackgroundVisibility(.visible, for: .navigationBar)
        #endif
    }

    private func row(_ day: Date) -> some View {
        let events = model.events(on: day)
        let isToday = day == model.today
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .center, spacing: 2) {
                // Today: only the number sits in the interchange circle, as in the grid.
                Text(verbatim: String(model.calendar.component(.day, from: day)))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? Theme.ground : Theme.ink)
                    .frame(minWidth: numberSize, minHeight: numberSize)
                    .background { if isToday { Circle().fill(Theme.ink) } }
                Text(day, format: .dateTime.weekday(.abbreviated))
                    .font(.caption)
                    .foregroundStyle(Theme.secondaryInk)
            }
            .frame(minWidth: 64, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(events) { event in
                    let passed = model.hasPassed(event)
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        StationMark(color: color(event.calendarID), passed: passed)
                            .frame(height: 14)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(EventRowView.title(of: event))
                                .font(.body)
                                .foregroundStyle(passed ? Theme.secondaryInk : Theme.ink)
                            Text(when(event, on: day))
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryInk)
                                .monospacedDigit()
                            let categories = categoryModel.categories(for: event.key)
                            if !categories.isEmpty {
                                CategorySymbolsView.names(categories)
                                    .font(.caption)
                                    .foregroundStyle(Theme.secondaryInk)
                            }
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(EventText.spoken(event, calendar: model.calendar,
                                                         calendarTitle: model.calendarInfo(event.calendarID)?.title,
                                                         categories: categoryModel.categories(for: event.key)))
                    .opensEventDetail(event)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(model.calendar.isDateInWeekend(day) ? AnyShapeStyle(Theme.weekend) : AnyShapeStyle(Color.clear))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(DayText.spoken(day, isToday: isToday, count: events.count))
    }

    /// "Celý den" for all-day events; the start time, or the span for events that cross midnight.
    private func when(_ event: EventInfo, on day: Date) -> String {
        if event.isAllDay { return String(localized: "Celý den") }
        if TimeText.endsOnStartDay(event, calendar: model.calendar) { return TimeText.time(event.start) }
        return TimeText.span(event, calendar: model.calendar)
    }
}
