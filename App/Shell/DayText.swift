import Foundation

/// How a day is named for VoiceOver.
enum DayText {
    /// "Dnes, úterý 17. listopadu 2026, 5 událostí"; without a count when `count` is `nil`.
    static func spoken(_ day: Date, isToday: Bool, count: Int?) -> String {
        var parts: [String] = []
        if isToday { parts.append(String(localized: "Dnes")) }
        parts.append(day.formatted(date: .complete, time: .omitted))
        if let count {
            parts.append(count == 0 ? String(localized: "žádné události") : String(localized: "\(count) událostí"))
        }
        return parts.joined(separator: ", ")
    }
}
