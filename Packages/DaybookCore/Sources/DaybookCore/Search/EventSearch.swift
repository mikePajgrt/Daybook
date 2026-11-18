import Foundation

/// One day of search results: the events that start on it.
public struct SearchDay: Hashable, Sendable, Identifiable {
    /// The day's local midnight.
    public let day: Date
    /// Sorted by start, then title. Never truncated.
    public let events: [EventInfo]

    public var id: Date { day }
}

/// Finding events by words. Every word of the query must appear in the title, the location,
/// the notes or an attendee's name or e-mail, ignoring case and diacritics ("schuzka" finds "Schůzka").
public enum EventSearch {
    /// The query's words, folded for comparison. Empty when the query holds no word.
    public static func terms(_ query: String) -> [String] {
        fold(query).split(whereSeparator: \.isWhitespace).map(String.init)
    }

    /// Whether every term appears in at least one of the event's searchable fields.
    public static func matches(_ event: EventInfo, terms: [String]) -> Bool {
        guard !terms.isEmpty else { return false }
        let fields = searchableText(of: event)
        return terms.allSatisfy { term in fields.contains { $0.contains(term) } }
    }

    /// The events matching `query`, grouped by the day they start: today and later days first,
    /// in order, then earlier days with the most recent first. Duplicates (by key) are dropped.
    public static func results(_ events: [EventInfo], query: String, today: Date, calendar: Calendar) -> [SearchDay] {
        let terms = terms(query)
        guard !terms.isEmpty else { return [] }
        var seen = Set<EventKey>()
        var byDay: [Date: [EventInfo]] = [:]
        for event in events where matches(event, terms: terms) && seen.insert(event.key).inserted {
            byDay[calendar.startOfDay(for: event.start), default: []].append(event)
        }
        let start = calendar.startOfDay(for: today)
        let upcoming = byDay.keys.filter { $0 >= start }.sorted()
        let past = byDay.keys.filter { $0 < start }.sorted(by: >)
        return (upcoming + past).map { day in
            SearchDay(day: day, events: (byDay[day] ?? []).sorted { ($0.start, $0.title) < ($1.start, $1.title) })
        }
    }

    /// Where the query's words occur in `text`, as ranges of the original string, in order and not overlapping.
    public static func highlights(in text: String, query: String) -> [Range<String.Index>] {
        let terms = terms(query)
        guard !terms.isEmpty else { return [] }
        // The folded text, and for each of its characters the original character it came from.
        var folded: [Character] = []
        var origin: [String.Index] = []
        for index in text.indices {
            for character in fold(String(text[index])) {
                folded.append(character)
                origin.append(index)
            }
        }
        var marked = Array(repeating: false, count: folded.count)
        for term in terms {
            let needle = Array(term)
            guard !needle.isEmpty, needle.count <= folded.count else { continue }
            var position = 0
            while position + needle.count <= folded.count {
                if Array(folded[position..<position + needle.count]) == needle {
                    for offset in position..<position + needle.count { marked[offset] = true }
                    position += needle.count
                } else {
                    position += 1
                }
            }
        }
        var ranges: [Range<String.Index>] = []
        var position = 0
        while position < folded.count {
            guard marked[position] else { position += 1; continue }
            var end = position
            while end + 1 < folded.count && marked[end + 1] { end += 1 }
            let lower = origin[position]
            let upper = text.index(after: origin[end])
            if let last = ranges.last, last.upperBound >= lower {
                ranges[ranges.count - 1] = last.lowerBound..<max(last.upperBound, upper)
            } else {
                ranges.append(lower..<upper)
            }
            position = end + 1
        }
        return ranges
    }

    // MARK: Why it matched

    /// Where a result matched when its title and place do not show it: a note or an attendee.
    public struct Snippet: Hashable, Sendable {
        public enum Field: Hashable, Sendable { case notes, attendee }
        public let field: Field
        /// One line of the field around the match; "…" marks text left out before it.
        public let text: String
    }

    /// The note or attendee that holds a word of `query` missing from the title and the place, so a
    /// result can say why it was found. `nil` when the title and place already show every word.
    public static func snippet(for event: EventInfo, query: String) -> Snippet? {
        let terms = terms(query)
        let shown = fold(event.title + " " + (event.location ?? ""))
        guard let term = terms.first(where: { !shown.contains($0) }) else { return nil }
        if let notes = event.notes, fold(notes).contains(term) {
            let line = notes.split(whereSeparator: \.isNewline).map(String.init)
                .first { fold($0).contains(term) } ?? notes
            return Snippet(field: .notes, text: excerpt(line, around: term, wordsBefore: 3))
        }
        for person in event.attendees {
            for text in [person.name, person.email].compactMap({ $0 }) where fold(text).contains(term) {
                return Snippet(field: .attendee, text: text)
            }
        }
        return nil
    }

    /// `line` from a few whole words before the first occurrence of the folded `term`.
    private static func excerpt(_ line: String, around term: String, wordsBefore: Int) -> String {
        guard let match = highlights(in: line, query: term).first else { return line }
        let words = line[..<match.lowerBound].split(whereSeparator: \.isWhitespace)
        guard words.count > wordsBefore, let first = words.suffix(wordsBefore).first else {
            return line.trimmingCharacters(in: .whitespaces)
        }
        return "…" + line[first.startIndex...].trimmingCharacters(in: .whitespaces)
    }

    // MARK: Range

    /// From local midnight `years` years before today to the end of the day `years` years after it.
    public static func range(around today: Date, years: Int = 5, calendar: Calendar) -> DateInterval {
        let day = calendar.startOfDay(for: today)
        let start = calendar.date(byAdding: .year, value: -years, to: day) ?? day
        let lastDay = calendar.date(byAdding: .year, value: years, to: day) ?? day
        let end = calendar.date(byAdding: .day, value: 1, to: lastDay) ?? lastDay
        return DateInterval(start: start, end: end)
    }

    /// `range` cut into consecutive pieces of at most `maxYears` calendar years. EventKit shortens a
    /// predicate longer than four years, so a search reads one piece at a time. Calendar arithmetic
    /// keeps the edges at local midnight across clock changes.
    public static func chunks(of range: DateInterval, maxYears: Int = 4, calendar: Calendar) -> [DateInterval] {
        var result: [DateInterval] = []
        var start = range.start
        while start < range.end {
            guard let next = calendar.date(byAdding: .year, value: max(1, maxYears), to: start), next > start else { break }
            let end = min(next, range.end)
            result.append(DateInterval(start: start, end: end))
            start = end
        }
        return result
    }

    // MARK: Folding

    private static func searchableText(of event: EventInfo) -> [String] {
        var fields = [event.title, event.location ?? "", event.notes ?? ""]
        for person in event.attendees {
            if let name = person.name { fields.append(name) }
            if let email = person.email { fields.append(email) }
        }
        return fields.filter { !$0.isEmpty }.map(fold)
    }

    private static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
