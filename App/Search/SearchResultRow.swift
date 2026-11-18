import DaybookCore
import SwiftUI

/// One search result: the calendar as line and station, the title with the matched letters set in
/// a heavier weight (never in a colour: colour belongs to calendars), then date and time, the
/// calendar's name and the event's category symbols.
struct SearchResultRow: View {
    @Environment(AppModel.self) private var model
    @Environment(CategoryModel.self) private var categoryModel
    let event: EventInfo
    let query: String

    var body: some View {
        let info = model.calendarInfo(event.calendarID)
        let categories = categoryModel.categories(for: event.key)
        HStack(alignment: .center, spacing: 12) {
            StationMark(color: Theme.line(info?.color ?? Theme.fallbackLine))
                .padding(.vertical, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(emphasised(EventRowView.title(of: event)))
                    .font(.body)
                    .foregroundStyle(event.title.isEmpty ? Theme.secondaryInk : Theme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(when)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(Theme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
                if let place = event.location, !place.isEmpty {
                    Text(emphasised(place))
                        .font(.subheadline)
                        .foregroundStyle(Theme.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Found in a note or an attendee: the words that matched, so the row says why it is here.
                if let snippet = EventSearch.snippet(for: event, query: query) {
                    Label {
                        Text(emphasised(snippet.text))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } icon: {
                        Image(systemName: snippet.field == .notes ? "note.text" : "person")
                    }
                    .labelStyle(SnippetLabelStyle())
                    .font(.subheadline)
                    .foregroundStyle(Theme.secondaryInk)
                }
                HStack(spacing: 6) {
                    if let info { Text(info.title) }
                    if !categories.isEmpty {
                        CategorySymbolsView(categories: categories)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Theme.secondaryInk)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .frame(minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([EventText.spoken(event, calendar: model.calendar, calendarTitle: info?.title,
                                              categories: categories),
                             event.start.formatted(date: .complete, time: .omitted),
                             EventSearch.snippet(for: event, query: query)?.text].compactMap { $0 }.joined(separator: ", "))
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("Otevře den a podrobnosti události"))
    }

    /// "Celý den", or the time range in the app's one time format; across days, both dates.
    private var when: String {
        if event.isAllDay {
            let days = MonthLayout.dayRange(of: event, calendar: model.calendar)
            if days.lowerBound == days.upperBound { return String(localized: "Celý den") }
            return (days.lowerBound..<days.upperBound).formatted(.interval.day().month(.abbreviated))
        }
        return TimeText.span(event, calendar: model.calendar, dateStyle: .dateTime.day().month(.abbreviated))
    }

    /// The text with every match of the query in semibold.
    private func emphasised(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        for range in EventSearch.highlights(in: text, query: query) {
            guard let lower = AttributedString.Index(range.lowerBound, within: result),
                  let upper = AttributedString.Index(range.upperBound, within: result) else { continue }
            result[lower..<upper].inlinePresentationIntent = .stronglyEmphasized
        }
        return result
    }
}

/// The snippet's symbol beside its first line, small and in the line's colour.
private struct SnippetLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            configuration.icon.imageScale(.small).accessibilityHidden(true)
            configuration.title
        }
    }
}
