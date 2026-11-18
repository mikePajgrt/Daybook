import DaybookCore
import Foundation

/// Every time of day the app writes, in one format: the hour axis, single start times and ranges
/// all say "8:30" (Czech) or "08:30" (British English) the same way, never mixing the two.
enum TimeText {
    /// The locale's hours and minutes.
    static let style = Date.FormatStyle.dateTime.hour().minute()

    /// "8:30".
    static func time(_ date: Date) -> String { date.formatted(style) }

    /// "13:00–14:30": both ends in the one format, joined by an en dash.
    static func range(_ start: Date, _ end: Date) -> String {
        "\(time(start))–\(time(max(start, end)))"
    }

    /// Whether a timed event ends on the day it starts. An event ending at midnight still belongs to its start day.
    static func endsOnStartDay(_ event: EventInfo, calendar: Calendar) -> Bool {
        let lastInstant = event.end > event.start ? event.end.addingTimeInterval(-1) : event.end
        return calendar.isDate(event.start, inSameDayAs: lastInstant)
    }

    /// The range of a timed event: "13:00–14:30" within a day; across days each end with its date,
    /// "19. 11. 22:00 – 20. 11. 2:00", the date written in `dateStyle`.
    static func span(_ event: EventInfo, calendar: Calendar,
                     dateStyle: Date.FormatStyle = .dateTime.day().month(.defaultDigits)) -> String {
        if endsOnStartDay(event, calendar: calendar) { return range(event.start, event.end) }
        let end = max(event.start, event.end)
        return "\(event.start.formatted(dateStyle)) \(time(event.start)) – \(end.formatted(dateStyle)) \(time(end))"
    }
}
