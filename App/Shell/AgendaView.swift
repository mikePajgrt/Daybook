import DaybookCore
import SwiftUI

/// Any view at accessibility text sizes on narrow screens: one full-width row per day,
/// so every event keeps its time and its whole title. Neither seven month columns nor
/// time-grid columns can hold them at that size.
struct AgendaView: View {
    @Environment(AppModel.self) private var model
    @Environment(CategoryModel.self) private var categoryModel
    let days: [Date]
    let color: (String) -> Color
    /// Diameter of the interchange circle around today's number.
    @ScaledMetric(relativeTo: .title3) private var numberSize: CGFloat = 34

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(days, id: \.self) { day in
                        row(day)
                            .id(day)
                    }
                }
            }
            .task(id: model.scrollKey) {
                if let target = days.contains(model.today) ? model.today : days.first {
                    reader.scrollTo(target, anchor: .top)
                }
            }
        }
        #if os(iOS)
        // An opaque bar on the ground: with the soft scroll edge, large digits blurred through the title.
        .toolbarBackground(Theme.ground, for: .navigationBar)
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
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        StationMark(color: color(event.calendarID))
                            .frame(height: 14)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(EventRowView.title(of: event))
                                .font(.body)
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
        .background(model.calendar.isDateInWeekend(day) ? Theme.weekend : Color.clear)
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
