// Demo data exists in debug builds only: release builds carry no synthetic calendars.
#if DEBUG
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

    /// Accounts the demo calendars live in. Google cannot hold a new calendar.
    public static let sources: [SourceInfo] = [
        SourceInfo(id: "demo-src-icloud", title: "iCloud", kind: .icloud),
        SourceInfo(id: "demo-src-exchange", title: "Exchange", kind: .exchange),
        SourceInfo(id: "demo-src-google", title: "Google", kind: .google, allowsCalendars: false)
    ]

    /// The calendar the demo system offers for new events.
    public static let defaultCalendarID = "demo-work"

    /// The detailed event the detail and editor captures show (on the month's 17th).
    public static let detailedEventID = "demo-api"
    /// The weekly series: every Monday at 8:30, from the month's first Monday.
    public static let seriesID = "demo-weekly"

    private static let people: [Attendee] = [
        Attendee(name: "Tomáš Novák", email: "tomas.novak@example.com", status: .accepted, isOrganizer: true),
        Attendee(name: "Petra Svobodová", email: "petra.svobodova@example.com", status: .tentative),
        Attendee(name: "Jan Dvořák", email: "jan.dvorak@example.com", status: .declined),
        Attendee(name: nil, email: "design@example.com", status: .pending)
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
        allDay("demo-sitting", "Hlídání Emy", calendarID: "demo-family", dayOfMonth: 17, length: 3)

        // Fixed cases the week and day views must handle: three events overlapping on the 17th,
        // and a night shift crossing midnight from the 19th into the 20th.
        func timed(_ id: String, _ title: String, calendarID: String, dayOfMonth: Int,
                   hour: Int, minute: Int = 0, minutes: Int, location: String? = nil) {
            guard let day = calendar.date(byAdding: .day, value: dayOfMonth - 1, to: monthStart),
                  let start = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day) else { return }
            result.append(EventInfo(key: EventKey(externalID: id, occurrenceStart: start),
                                    calendarID: calendarID, title: title,
                                    start: start, end: start.addingTimeInterval(Double(minutes) * 60),
                                    isAllDay: false, location: location))
        }
        timed("demo-api", "Návrh API", calendarID: "demo-work", dayOfMonth: 17, hour: 13, minutes: 90,
              location: "Zasedačka Vltava")
        timed("demo-swim", "Ema: plavání", calendarID: "demo-family", dayOfMonth: 17, hour: 13, minute: 30,
              minutes: 90, location: "Bazén Podolí")
        timed("demo-outage", "Odstávka DB", calendarID: "demo-team", dayOfMonth: 17, hour: 14, minutes: 60)
        timed("demo-night", "Noční nasazení", calendarID: "demo-team", dayOfMonth: 19, hour: 22, minutes: 240)

        // Everything the event detail can show, on one event.
        if let index = result.firstIndex(where: { $0.key.externalID == detailedEventID }) {
            result[index].notes = "Projít návrh endpointů pro synchronizaci kategorií a rozhodnout o stránkování."
            result[index].url = URL(string: "https://example.com/navrh-api")
            result[index].alert = AlertOffset(minutesBefore: 15)
            result[index].attendees = people
            result[index].timeZoneID = calendar.timeZone.identifier
        }

        // A weekly series, so the recurring edit and delete questions can be shown.
        let firstMonday = (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: monthStart) }
            .first { calendar.component(.weekday, from: $0) == 2 }
        if let firstMonday,
           let start = calendar.date(bySettingHour: 8, minute: 30, second: 0, of: firstMonday) {
            result.append(EventInfo(key: EventKey(externalID: seriesID, occurrenceStart: start),
                                    calendarID: "demo-work", title: "Týdenní plán",
                                    start: start, end: start.addingTimeInterval(30 * 60), isAllDay: false,
                                    location: "Zasedačka Vltava", recurrence: RecurrenceRule(frequency: .weekly),
                                    attendees: Array(people.prefix(3)), alert: AlertOffset(minutesBefore: 5),
                                    timeZoneID: calendar.timeZone.identifier))
        }

        return result.sorted { ($0.start, $0.title) < ($1.start, $1.title) }
    }

    /// The month's events (exactly `events(month:calendar:)`) and generated days of `radius` months
    /// either side, so the month scrolls into its neighbours and search finds past and future events.
    /// Neighbouring days are keyed apart from the month's own.
    public static func events(month: Date, radius: Int, calendar: Calendar) -> [EventInfo] {
        var result = events(month: month, calendar: calendar)
        let covered = Period.interval(.month, containing: month, calendar: calendar)
        for offset in -radius...radius where offset != 0 {
            guard let other = calendar.date(byAdding: .month, value: offset, to: month),
                  let otherMonth = calendar.dateInterval(of: .month, for: other) else { continue }
            for event in events(month: other, calendar: calendar) where event.recurrence == nil {
                let day = calendar.startOfDay(for: event.start)
                // Only the other month's own days, and none the central month already fills. The fixed
                // timed cases (the detailed event, the overlap, the night shift) stay in the central month.
                let generated = event.key.externalID.contains(where: \.isNumber)
                guard otherMonth.start <= day, day < otherMonth.end, !(covered.start <= day && day < covered.end),
                      generated || event.isAllDay else { continue }
                result.append(event.with(key: EventKey(externalID: "demo-m\(offset)-\(event.key.externalID)",
                                                       occurrenceStart: event.key.occurrenceStart)))
            }
        }
        return result.sorted { ($0.start, $0.title) < ($1.start, $1.title) }
    }

    /// How many months either side of the demo month have events.
    public static let monthRadius = 3

    public static func store(month: Date, calendar: Calendar, access: CalendarAccess = .granted) -> InMemoryCalendarStore {
        InMemoryCalendarStore(calendars: calendars, events: events(month: month, radius: monthRadius, calendar: calendar),
                              access: access, sources: sources, defaultCalendarID: defaultCalendarID, calendar: calendar)
    }
}
#endif
