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
            let monthStyle: Date.FormatStyle = numeric
                ? .dateTime.day().month(.defaultDigits) : .dateTime.day().month(.wide)
            let sameYear = calendar.component(.year, from: start) == calendar.component(.year, from: last)
            let sameMonth = sameYear && calendar.component(.month, from: start) == calendar.component(.month, from: last)
            if sameMonth {
                // "16.–22. listopadu"
                name = "\(calendar.component(.day, from: start)).–\(last.formatted(monthStyle))"
                year = short || numeric ? nil : yearText
            } else if sameYear {
                name = "\(start.formatted(monthStyle)) – \(last.formatted(monthStyle))"
                year = short || numeric ? nil : yearText
            } else {
                let withYear = monthStyle.year()
                name = "\(start.formatted(withYear)) – \(last.formatted(withYear))"
                year = nil
            }
        }
    }

    private static func capitalizingFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).localizedUppercase + text.dropFirst()
    }
}
