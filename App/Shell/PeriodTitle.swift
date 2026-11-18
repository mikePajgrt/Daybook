import DaybookCore
import Foundation

/// The toolbar title: the period on screen, split into its name and its year so the Mac toolbar
/// can set the year lighter. Day: full date. Week: a compact range. Month: month and year.
struct PeriodTitle {
    let name: String
    /// `nil` when the name already carries the years (a week across New Year) or when there is no room.
    let year: String?

    var joined: String { [name, year].compactMap { $0 }.joined(separator: " ") }

    /// `short` drops the year from day and week titles and abbreviates the weekday (narrow toolbars);
    /// `numeric` goes further and writes months as numbers (accessibility text sizes);
    /// `abbreviatedWeekday` shortens only the weekday.
    init(mode: ViewMode, date: Date, interval: DateInterval?, calendar: Calendar,
         short: Bool = false, numeric: Bool = false, abbreviatedWeekday: Bool = false) {
        let yearText = date.formatted(.dateTime.year())
        switch mode {
        case .month:
            let month = date.formatted(.dateTime.month(numeric ? .abbreviated : .wide))
            name = month.localizedCapitalized
            year = yearText
        case .day:
            let style: Date.FormatStyle = numeric
                ? .dateTime.weekday(.abbreviated).day().month(.defaultDigits)
                : short || abbreviatedWeekday ? .dateTime.weekday(.abbreviated).day().month(.wide)
                : .dateTime.weekday(.wide).day().month(.wide)
            name = Self.capitalizingFirst(date.formatted(style))
            year = short || numeric ? nil : yearText
        case .week:
            let start = interval?.start ?? date
            let last = interval.flatMap { calendar.date(byAdding: .day, value: -1, to: $0.end) } ?? date
            // The formatter writes the range in the app's language: "16.–22. listopadu", "Nov 16 – 22".
            let range = start..<max(last, start)
            let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: last)
            let month: Date.IntervalFormatStyle = numeric ? .interval.day().month(.defaultDigits)
                                                          : .interval.day().month(.wide)
            if sameYear {
                name = range.formatted(month)
                year = short || numeric ? nil : yearText
            } else {
                name = range.formatted(month.year())
                year = nil
            }
        }
    }

    private static func capitalizingFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).localizedUppercase + text.dropFirst()
    }
}
