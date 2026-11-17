import DaybookCore
import Foundation

/// Czech wording for event details, the editor's choices and write errors, in one place
/// so the detail, the editor and the alerts say the same thing the same way.
enum EventText {
    // MARK: When

    /// "Úterý 17. listopadu 2026, 13:00–14:30", "Celý den, úterý 17. listopadu 2026",
    /// or a range of dates for events that span days.
    static func when(_ event: EventInfo, calendar: Calendar) -> String {
        let longDay = Date.FormatStyle.dateTime.weekday(.wide).day().month(.wide).year()
        let shortDay = Date.FormatStyle.dateTime.day().month(.defaultDigits).year()
        if event.isAllDay {
            let days = MonthLayout.dayRange(of: event, calendar: calendar)
            if days.lowerBound == days.upperBound {
                return "Celý den, \(days.lowerBound.formatted(longDay))"
            }
            return "Celý den, \(days.lowerBound.formatted(shortDay)) – \(days.upperBound.formatted(shortDay))"
        }
        let time = Date.FormatStyle.dateTime.hour().minute()
        let lastInstant = event.end > event.start ? event.end.addingTimeInterval(-1) : event.end
        if calendar.isDate(event.start, inSameDayAs: lastInstant) {
            return capitalized("\(event.start.formatted(longDay)), \(event.start.formatted(time))–\(event.end.formatted(time))")
        }
        return "\(event.start.formatted(shortDay)) \(event.start.formatted(time)) – \(event.end.formatted(shortDay)) \(event.end.formatted(time))"
    }

    /// The event's time zone when it differs from the device's, e.g. "Čas: New York".
    static func zoneNote(_ event: EventInfo, calendar: Calendar) -> String? {
        guard !event.isAllDay, let id = event.timeZoneID, id != calendar.timeZone.identifier,
              let zone = TimeZone(identifier: id) else { return nil }
        return "Časové pásmo: \(zoneName(zone))"
    }

    // MARK: Recurrence

    /// "Každý týden", "Každé 2 týdny", "Každý měsíc do 30. 11. 2027".
    static func recurrence(_ rule: RecurrenceRule) -> String {
        let base = every(rule.frequency, interval: rule.interval)
        guard let end = rule.end else { return base }
        return "\(base) do \(end.formatted(.dateTime.day().month(.defaultDigits).year()))"
    }

    /// The editor's label for a frequency at an interval.
    static func every(_ frequency: RecurrenceFrequency, interval: Int) -> String {
        let n = max(1, interval)
        switch frequency {
        case .daily: return plural(n, one: "Každý den", few: "Každé \(n) dny", many: "Každých \(n) dní")
        case .weekly: return plural(n, one: "Každý týden", few: "Každé \(n) týdny", many: "Každých \(n) týdnů")
        case .monthly: return plural(n, one: "Každý měsíc", few: "Každé \(n) měsíce", many: "Každých \(n) měsíců")
        case .yearly: return plural(n, one: "Každý rok", few: "Každé \(n) roky", many: "Každých \(n) let")
        }
    }

    // MARK: Alerts

    /// "V čase začátku", "15 minut předem", "1 hodinu předem", "1 den předem".
    static func alert(_ offset: AlertOffset?) -> String {
        guard let minutes = offset?.minutesBefore else { return "Žádné" }
        if minutes == 0 { return "V čase začátku" }
        if minutes % 1440 == 0 {
            let n = minutes / 1440
            return plural(n, one: "1 den předem", few: "\(n) dny předem", many: "\(n) dní předem")
        }
        if minutes % 60 == 0 {
            let n = minutes / 60
            return plural(n, one: "1 hodinu předem", few: "\(n) hodiny předem", many: "\(n) hodin předem")
        }
        return plural(minutes, one: "1 minutu předem", few: "\(minutes) minuty předem", many: "\(minutes) minut předem")
    }

    // MARK: Attendees

    static func status(_ status: AttendeeStatus) -> String {
        switch status {
        case .accepted: "Přijde"
        case .declined: "Nepřijde"
        case .tentative: "Možná přijde"
        case .pending, .unknown: "Bez odpovědi"
        }
    }

    static func statusSymbol(_ status: AttendeeStatus) -> String {
        switch status {
        case .accepted: "checkmark.circle.fill"
        case .declined: "xmark.circle.fill"
        case .tentative: "questionmark.circle.fill"
        case .pending, .unknown: "circle.dashed"
        }
    }

    // MARK: Time zones

    /// "New York (východoamerický čas)", with the city in Czech ("Praha", not "Prague").
    static func zoneName(_ zone: TimeZone) -> String {
        let fallback = zone.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") }
            ?? zone.identifier
        let city = zone.identifier.contains("/") ? (localizedCity(zone) ?? fallback) : fallback
        let name = zone.localizedName(for: .generic, locale: czech)
        return name.map { "\(city) (\($0))" } ?? city
    }

    private static let czech = Locale(identifier: "cs_CZ")

    /// The zone's exemplar city in Czech (the "VVV" pattern), or `nil` when the formatter has none.
    private static func localizedCity(_ zone: TimeZone) -> String? {
        let formatter = DateFormatter()
        formatter.locale = czech
        formatter.timeZone = zone
        formatter.dateFormat = "VVV"
        let city = formatter.string(from: Date())
        // Without a known city the pattern falls back to an offset or an "unknown" placeholder.
        guard !city.isEmpty, !city.contains("GMT"), !city.contains("UTC"), !city.localizedCaseInsensitiveContains("nezn")
        else { return nil }
        return city
    }

    // MARK: Invitations

    static let inviteUnavailableTitle = "Editor pozvánek se neotevřel"

    /// Why the system invitation editor did not open, and what to do instead.
    static func inviteUnavailableMessage(isDemo: Bool) -> String {
        #if DEBUG
        if isDemo {
            return "V ukázkovém režimu nejsou události v systémovém kalendáři, takže se editor pozvánek neotevře."
        }
        #endif
        return "Událost se v systémovém kalendáři nepodařilo najít. Pozvěte účastníky v aplikaci Kalendář nebo zkuste událost otevřít znovu."
    }

    // MARK: Problems and errors

    static func problem(_ problem: DraftProblem) -> String {
        switch problem {
        case .endBeforeStart: "Konec je dřív než začátek. Posuňte konec."
        case .recurrenceEndsBeforeStart: "Opakování končí dřív, než událost začne. Posuňte konec opakování."
        case .invalidURL: "Adresa URL není platná. Zkontrolujte ji, třeba example.com."
        case .noCalendar: "Vyberte kalendář."
        }
    }

    static func problem(_ problem: CalendarDraftProblem) -> String {
        switch problem {
        case .emptyName: "Zadejte název kalendáře."
        case .noSource: "Vyberte účet."
        }
    }

    /// What failed and what to do, for any error a write can throw.
    static func message(for error: Error) -> String {
        guard let error = error as? CalendarStoreError else { return error.localizedDescription }
        switch error {
        case .eventNotFound:
            return "Událost už v kalendáři není. Mezitím ji nejspíš někdo smazal nebo přesunul."
        case .calendarNotFound:
            return "Vybraný kalendář už neexistuje. Vyberte jiný."
        case .calendarReadOnly:
            return "Kalendář je jen pro čtení, změny v něm uložit nejde."
        case .sourceNotFound:
            return "Účet už v zařízení není. Vyberte jiný."
        case .sourceDoesNotAllowCalendars:
            return "V tomto účtu kalendář vytvořit nejde. Vyberte iCloud, Exchange nebo kalendáře v zařízení."
        case .invalidDraft(let problems):
            return problems.map(problem).joined(separator: " ")
        case .invalidCalendar(let problems):
            return problems.map(problem).joined(separator: " ")
        case .system(let text):
            return text
        }
    }

    // MARK: Helpers

    /// Czech plural: 1, 2 to 4, 5 and more.
    static func plural(_ n: Int, one: String, few: String, many: String) -> String {
        if n == 1 { return one }
        if (2...4).contains(n) { return few }
        return many
    }

    private static func capitalized(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).localizedUppercase + text.dropFirst()
    }
}
