import DaybookCore
import SwiftUI

/// The month at accessibility text sizes on narrow screens: one full-width row per day,
/// so every event keeps its time and its whole title. Seven columns cannot hold either at that size.
struct MonthAgendaView: View {
    @Environment(AppModel.self) private var model
    let color: (String) -> Color
    /// Diameter of the interchange circle around today's number.
    @ScaledMetric(relativeTo: .title3) private var numberSize: CGFloat = 34

    private var days: [DayLayout] {
        model.weeks.flatMap(\.days).filter(\.isInMonth)
    }

    var body: some View {
        ScrollViewReader { reader in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(days, id: \.date) { day in
                        row(day)
                            .id(day.date)
                    }
                }
            }
            .task(id: model.scrollKey) {
                reader.scrollTo(model.today, anchor: .top)
            }
        }
    }

    private func row(_ day: DayLayout) -> some View {
        let events = model.events(on: day.date)
        let isToday = day.date == model.today
        return HStack(alignment: .firstTextBaseline, spacing: 12) {
            VStack(alignment: .center, spacing: 2) {
                // Today: only the number sits in the interchange circle, as in the grid.
                Text(verbatim: String(model.calendar.component(.day, from: day.date)))
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(isToday ? Theme.ground : Theme.ink)
                    .frame(minWidth: numberSize, minHeight: numberSize)
                    .background { if isToday { Circle().fill(Theme.ink) } }
                Text(day.date, format: .dateTime.weekday(.abbreviated))
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
                            Text(event.isAllDay ? "Celý den"
                                 : event.start.formatted(date: .omitted, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(Theme.secondaryInk)
                                .monospacedDigit()
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(model.calendar.isDateInWeekend(day.date) ? Theme.weekend : Color.clear)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
    }
}
