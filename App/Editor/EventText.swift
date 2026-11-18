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
                return String(localized: "Celý den, \(days.lowerBound.formatted(longDay))")
            }
            return String(localized: "Celý den, \((days.lowerBound..<days.upperBound).formatted(.interval.day().month(.defaultDigits).year()))")
        }
        if TimeText.endsOnStartDay(event, calendar: calendar) {
            return capitalized("\(event.start.formatted(longDay)), \(TimeText.range(event.start, event.end))")
        }
        return TimeText.span(event, calendar: calendar, dateStyle: shortDay)
    }

    /// The event's time zone when it differs from the device's, e.g. "Čas: New York".
    static func zoneNote(_ event: EventInfo, calendar: Calendar) -> String? {
        guard !event.isAllDay, let id = event.timeZoneID, id != calendar.timeZone.identifier,
              let zone = TimeZone(identifier: id) else { return nil }
        return String(localized: "Časové pásmo: \(zoneName(zone))")
    }

    // MARK: VoiceOver

    /// What VoiceOver says for an event wherever it is drawn: time, title, calendar, categories.
    /// "13:00 až 14:30, Návrh API, kalendář Práce, kategorie Porady a Soustředěná práce".
    static func spoken(_ event: EventInfo, calendar: Calendar, calendarTitle: String?, categories: [Category]) -> String {
        var parts: [String] = []
        if event.isAllDay {
            parts.append(String(localized: "celý den"))
        } else {
            parts.append(TimeText.span(event, calendar: calendar))
        }
        parts.append(EventRowView.title(of: event))
        if let calendarTitle { parts.append(String(localized: "kalendář \(calendarTitle)")) }
        if let spoken = CategoryText.spoken(categories) { parts.append(spoken) }
        return parts.joined(separator: ", ")
    }

    // MARK: Recurrence

    /// "Každý týden", "Každé 2 týdny", "Každý měsíc do 30. 11. 2027".
    static func recurrence(_ rule: RecurrenceRule) -> String {
        let base = every(rule.frequency, interval: rule.interval)
        guard let end = rule.end else { return base }
        return String(localized: "\(base) do \(end.formatted(.dateTime.day().month(.defaultDigits).year()))")
    }

    /// The editor's label for a frequency at an interval.
    static func every(_ frequency: RecurrenceFrequency, interval: Int) -> String {
        let n = max(1, interval)
        switch frequency {
        // Plural forms (Czech one, few, other) come from the string catalog.
        case .daily: return String(localized: "Každých \(n) dní")
        case .weekly: return String(localized: "Každých \(n) týdnů")
        case .monthly: return String(localized: "Každých \(n) měsíců")
        case .yearly: return String(localized: "Každých \(n) let")
        }
    }

    // MARK: Alerts

    /// "V čase začátku", "15 minut předem", "1 hodinu předem", "1 den předem".
    static func alert(_ offset: AlertOffset?) -> String {
        guard let minutes = offset?.minutesBefore else { return String(localized: "Žádné") }
        if minutes == 0 { return String(localized: "V čase začátku") }
        if minutes % 1440 == 0 {
            let n = minutes / 1440
            return String(localized: "\(n) dní předem")
        }
        if minutes % 60 == 0 {
            let n = minutes / 60
            return String(localized: "\(n) hodin předem")
        }
        return String(localized: "\(minutes) minut předem")
    }

    // MARK: Attendees

    static func status(_ status: AttendeeStatus) -> String {
        switch status {
        case .accepted: String(localized: "Přijde")
        case .declined: String(localized: "Nepřijde")
        case .tentative: String(localized: "Možná přijde")
        case .pending, .unknown: String(localized: "Bez odpovědi")
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

    /// "New York (východoamerický čas)", with the city in the app's language ("Praha" in Czech).
    static func zoneName(_ zone: TimeZone) -> String {
        let fallback = zone.identifier.split(separator: "/").last.map { $0.replacingOccurrences(of: "_", with: " ") }
            ?? zone.identifier
        let city = zone.identifier.contains("/") ? (localizedCity(zone) ?? fallback) : fallback
        let name = zone.localizedName(for: .generic, locale: czech)
        return name.map { "\(city) (\($0))" } ?? city
    }

    /// The app's language: Czech city names in Czech, English ones in English.
    private static var czech: Locale { Locale.current }

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

    static let inviteUnavailableTitle = String(localized: "Editor pozvánek se neotevřel")

    /// Why the system invitation editor did not open, and what to do instead.
    static func inviteUnavailableMessage(isDemo: Bool) -> String {
        #if DEBUG
        if isDemo {
            return String(localized: "V ukázkovém režimu nejsou události v systémovém kalendáři, takže se editor pozvánek neotevře.")
        }
        #endif
        return String(localized: "Událost se v systémovém kalendáři nepodařilo najít. Pozvěte účastníky v aplikaci Kalendář nebo zkuste událost otevřít znovu.")
    }

    // MARK: Problems and errors

    static func problem(_ problem: DraftProblem) -> String {
        switch problem {
        case .endBeforeStart: String(localized: "Konec je dřív než začátek. Posuňte konec.")
        case .recurrenceEndsBeforeStart: String(localized: "Opakování končí dřív, než událost začne. Posuňte konec opakování.")
        case .invalidURL: String(localized: "Adresa URL není platná. Zkontrolujte ji, třeba example.com.")
        case .noCalendar: String(localized: "Vyberte kalendář.")
        }
    }

    static func problem(_ problem: CalendarDraftProblem) -> String {
        switch problem {
        case .emptyName: String(localized: "Zadejte název kalendáře.")
        case .noSource: String(localized: "Vyberte účet.")
        }
    }

    /// What failed and what to do, for any error a write can throw.
    static func message(for error: Error) -> String {
        guard let error = error as? CalendarStoreError else { return error.localizedDescription }
        switch error {
        case .eventNotFound:
            return String(localized: "Událost už v kalendáři není. Mezitím ji nejspíš někdo smazal nebo přesunul.")
        case .calendarNotFound:
            return String(localized: "Vybraný kalendář už neexistuje. Vyberte jiný.")
        case .calendarReadOnly:
            return String(localized: "Kalendář je jen pro čtení, změny v něm uložit nejde.")
        case .sourceNotFound:
            return String(localized: "Účet už v zařízení není. Vyberte jiný.")
        case .sourceDoesNotAllowCalendars:
            return String(localized: "V tomto účtu kalendář vytvořit nejde. Vyberte iCloud, Exchange nebo kalendáře v zařízení.")
        case .invalidDraft(let problems):
            return problems.map(problem).joined(separator: " ")
        case .invalidCalendar(let problems):
            return problems.map(problem).joined(separator: " ")
        case .system(let text):
            return text
        }
    }

    // MARK: Helpers

    private static func capitalized(_ text: String) -> String {
        guard let first = text.first else { return text }
        return String(first).localizedUppercase + text.dropFirst()
    }
}
