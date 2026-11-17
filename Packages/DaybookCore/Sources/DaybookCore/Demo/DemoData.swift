import Foundation

/// Synthetic calendars and events for demo mode and screenshots. Not real data.
public enum DemoData {
    public static let calendars: [CalendarInfo] = [
        CalendarInfo(id: "demo-work", title: "Práce", color: RGBA(r: 0.23, g: 0.51, b: 1.0),
                     sourceTitle: "Exchange", sourceKind: .exchange),
        CalendarInfo(id: "demo-home", title: "Osobní", color: RGBA(r: 1.0, g: 0.23, b: 0.31),
                     sourceTitle: "iCloud", sourceKind: .icloud),
        CalendarInfo(id: "demo-holidays", title: "Státní svátky", color: RGBA(r: 0.73, g: 0.75, b: 0.83),
                     sourceTitle: "iCloud", sourceKind: .subscribed, isReadOnly: true),
        CalendarInfo(id: "demo-family", title: "Rodina", color: RGBA(r: 0.13, g: 0.76, b: 0.54),
                     sourceTitle: "Google", sourceKind: .google),
        CalendarInfo(id: "demo-team", title: "Tým produkt", color: RGBA(r: 1.0, g: 0.69, b: 0.0),
                     sourceTitle: "Google", sourceKind: .google, isReadOnly: true, isShared: true)
    ]

    private static let titles: [String: [String]] = [
        "demo-work": ["Standup platformy", "1:1 s Tomášem", "Review roadmapy Q1", "Pohovor: senior iOS",
                      "Sprint planning", "Demo pro klienta", "Architektura sync", "Retro", "Rozpočet 2027",
                      "Workshop onboarding", "Call s dodavatelem", "Design review"],
        "demo-home": ["Běh Stromovka", "Zubař", "Fyzio", "Čtenářský klub", "Servis kola", "Angličtina",
                      "Večeře s Petrou", "Squash"],
        "demo-family": ["Ema: plavání", "Třídní schůzky", "Oběd u babičky", "Kuba: florbal", "Očkování Ema",
                        "Narozeniny táty", "Kino s dětmi"],
        "demo-team": ["Release 4.2", "Odstávka DB", "Code freeze", "Uzávěrka faktur", "All-hands"]
    ]
    private static let weekdayPicks = ["demo-work", "demo-work", "demo-work", "demo-work", "demo-work",
                                       "demo-work", "demo-home", "demo-home", "demo-family", "demo-family",
                                       "demo-team", "demo-team"]
    private static let weekendPicks = ["demo-work", "demo-home", "demo-home", "demo-home", "demo-family",
                                       "demo-family", "demo-family", "demo-team"]

    /// A small linear congruential generator, so output is identical on every run and platform.
    private struct Generator {
        var state: UInt64
        mutating func next(below bound: Int) -> Int {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Int((state >> 33) % UInt64(bound))
        }
    }

    public static func events(month: Date, calendar: Calendar) -> [EventInfo] {
        let parts = calendar.dateComponents([.year, .month], from: month)
        var generator = Generator(state: UInt64((parts.year ?? 2026) * 100 + (parts.month ?? 1)))
        let days = MonthLayout.weeks(containing: month, calendar: calendar).flatMap { $0 }
        guard let monthStart = calendar.dateInterval(of: .month, for: month)?.start else { return [] }
        var result: [EventInfo] = []

        for (dayIndex, day) in days.enumerated() {
            let weekend = calendar.isDateInWeekend(day)
            let count = weekend ? generator.next(below: 3) : 2 + generator.next(below: 7)
            var slots = Set<Int>()
            while slots.count < count { slots.insert(generator.next(below: 25)) }   // 07:30 ... 19:30
            for (index, slot) in slots.sorted().enumerated() {
                let picks = weekend ? weekendPicks : weekdayPicks
                let calendarID = picks[generator.next(below: picks.count)]
                let pool = titles[calendarID] ?? ["Událost"]
                let start = day.addingTimeInterval(7.5 * 3600 + Double(slot) * 1800)
                let minutes = [30, 60, 90][generator.next(below: 3)]
                result.append(EventInfo(
                    key: EventKey(externalID: "demo-\(dayIndex)-\(index)", occurrenceStart: start),
                    calendarID: calendarID, title: pool[generator.next(below: pool.count)],
                    start: start, end: start.addingTimeInterval(Double(minutes) * 60), isAllDay: false))
            }
        }

        func allDay(_ id: String, _ title: String, calendarID: String, dayOfMonth: Int, length: Int) {
            guard let start = calendar.date(byAdding: .day, value: dayOfMonth - 1, to: monthStart),
                  let endDay = calendar.date(byAdding: .day, value: length, to: start) else { return }
            result.append(EventInfo(key: EventKey(externalID: id, occurrenceStart: start),
                                    calendarID: calendarID, title: title,
                                    start: start, end: endDay.addingTimeInterval(-1), isAllDay: true))
        }
        allDay("demo-support", "Podpora: služba", calendarID: "demo-team", dayOfMonth: 2, length: 5)
        allDay("demo-conference", "WebExpo", calendarID: "demo-work", dayOfMonth: 11, length: 2)
        allDay("demo-holiday", "Státní svátek", calendarID: "demo-holidays", dayOfMonth: 17, length: 1)
        allDay("demo-trip", "Lisabon", calendarID: "demo-home", dayOfMonth: 26, length: 5)

        return result.sorted { ($0.start, $0.title) < ($1.start, $1.title) }
    }

    public static func store(month: Date, calendar: Calendar) -> InMemoryCalendarStore {
        InMemoryCalendarStore(calendars: calendars, events: events(month: month, calendar: calendar))
    }
}
