import DaybookCore
import SwiftUI

/// Heights shared by every week row, scaled with Dynamic Type by the owner.
struct WeekMetrics {
    let rowHeight: CGFloat
    let numberHeight: CGFloat
    static let bottomInset: CGFloat = 6

    /// The height a week needs so that its fullest day shows every event.
    func contentHeight(for week: WeekLayout) -> CGFloat {
        numberHeight + CGFloat(max(week.rowCount, 1)) * rowHeight + Self.bottomInset
    }
}

/// One week of the month: seven day cells, with multi-day events drawn across them as lines.
/// The owner sets the row's height; it must be at least `metrics.contentHeight(for:)`.
struct WeekRowView: View {
    let week: WeekLayout
    let today: Date
    let calendar: Calendar
    let metrics: WeekMetrics
    let compact: Bool
    let color: (String) -> ThemeColor
    /// The month on screen: its day numbers are in full ink, the others in outside ink. Events are drawn
    /// alike in both; only a passed event steps back.
    let month: DateInterval?
    /// Called when a day is tapped. `nil` where tapping a day does nothing.
    let onSelectDay: ((Date) -> Void)?
    /// Called when a day number is clicked (Mac, iPad: opens that day's view). `nil` leaves the number inert.
    var onOpenDay: ((Date) -> Void)? = nil
    /// Called when empty space in a day is double-clicked (Mac, iPad: creates an event). `nil` disables it.
    var onCreateEvent: ((Date) -> Void)? = nil
    /// Offered with `onCreateEvent` in the empty space's context menu (Mac, iPad). `nil` leaves it out.
    var onCreateAllDayEvent: ((Date) -> Void)? = nil
    /// Clicking an event opens its detail (Mac, iPad). On iPhone a tap opens the day instead.
    var eventsOpenDetail = false

    @Environment(\.colorSchemeContrast) private var contrast

    private func isInMonth(_ day: DayLayout) -> Bool {
        month.map { day.date >= $0.start && day.date < $0.end } ?? day.isInMonth
    }

    /// How many events a day shows, timed and spanning, for VoiceOver.
    private func eventCount(column: Int) -> Int {
        week.days[column].timed.count + week.spans.filter { $0.startColumn <= column && column <= $0.endColumn }.count
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(week.days.enumerated()), id: \.element.date) { index, day in
                dayCell(day, column: index, isLast: index == week.days.count - 1)
            }
        }
        .overlay(alignment: .topLeading) { spans }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
        .overlay(alignment: .topLeading) { todayOutline }
    }

    /// Today's whole cell is outlined in ink, square-cut like the grid it sits in. Drawn above the
    /// rules and the span lines, so the square stays unbroken when a line runs through the day.
    private var todayOutline: some View {
        GeometryReader { proxy in
            if let column = week.days.firstIndex(where: { $0.date == today }) {
                let width = proxy.size.width / CGFloat(week.days.count)
                Rectangle()
                    .strokeBorder(Theme.ink, lineWidth: contrast == .increased ? 2 : 1.5)
                    .frame(width: width, height: proxy.size.height)
                    .padding(.leading, width * CGFloat(column))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func dayCell(_ day: DayLayout, column: Int, isLast: Bool) -> some View {
        let inMonth = isInMonth(day)
        return VStack(alignment: .leading, spacing: 0) {
            dayNumber(day, inMonth: inMonth)
            Color.clear.frame(height: CGFloat(week.laneCount) * metrics.rowHeight)
            ForEach(day.timed) { event in
                EventRowView(event: event, color: color(event.calendarID), compact: compact)
                    .frame(height: metrics.rowHeight)
                    .opensEventDetail(event, when: eventsOpenDetail)
            }
            Spacer(minLength: WeekMetrics.bottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(calendar.isDateInWeekend(day.date) ? AnyShapeStyle(Theme.weekend) : AnyShapeStyle(Color.clear))
        .clipped()
        .overlay(alignment: .trailing) {
            if !isLast { Rectangle().fill(Theme.rule).frame(width: 1) }
        }
        .modifier(DayCellTaps(day: day.date, onSelect: onSelectDay, onCreate: onCreateEvent,
                              onCreateAllDay: onCreateAllDayEvent))
        // A day is one group: its date and how many events it has, then the events themselves.
        .accessibilityElement(children: .contain)
        .accessibilityLabel(DayText.spoken(day.date, isToday: day.date == today, count: eventCount(column: column)))
    }

    @ViewBuilder private func dayNumber(_ day: DayLayout, inMonth: Bool) -> some View {
        if let onOpenDay {
            Button { onOpenDay(day.date) } label: {
                numberLabel(day, inMonth: inMonth)
                    // iPad: the number is small; its target reaches 44 pt around it without moving anything.
                    .contentShape(Rectangle().inset(by: Self.targetOutset))
            }
                .buttonStyle(.plain)
                .accessibilityLabel(DayText.spoken(day.date, isToday: day.date == today, count: nil))
                .accessibilityHint(Text("Otevře den"))
                #if os(macOS)
                .pointerStyle(.link)
                #endif
        } else {
            numberLabel(day, inMonth: inMonth)
                .accessibilityHidden(true)
        }
    }

    #if os(iOS)
    private static let targetOutset: CGFloat = -8
    #else
    private static let targetOutset: CGFloat = 0
    #endif

    private func numberLabel(_ day: DayLayout, inMonth: Bool) -> some View {
        let isToday = day.date == today
        let ink = inMonth ? Theme.ink : Theme.outsideInk(contrast)
        let font = (compact ? Font.footnote : Font.callout).weight(.semibold)
        let dayOfMonth = calendar.component(.day, from: day.date)
        return HStack(spacing: compact ? 2 : 4) {
            Text(verbatim: String(dayOfMonth))
                .font(font)
                .monospacedDigit()
                .foregroundStyle(isToday ? Theme.ground : ink)
                .frame(minWidth: metrics.numberHeight - 6, minHeight: metrics.numberHeight - 6)
                .background { if isToday { Circle().fill(Theme.ink) } }
            // The 1st carries its month's name, so where one month ends and the next begins stays findable
            // in the continuous column, also when both months are in full ink.
            if dayOfMonth == 1 {
                Text(day.date, format: .dateTime.month(.abbreviated))
                    .font(font)
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .fixedSize()
                    .accessibilityHidden(true)
            }
        }
        // Today's circle keeps the same 3 pt from the cell's leading edge as from its top, clear of the outline.
        .padding(.leading, isToday || compact ? 3 : 6)
        .frame(height: metrics.numberHeight, alignment: .leading)
        .animation(.default, value: inMonth)
    }

    private var spans: some View {
        GeometryReader { proxy in
            let column = proxy.size.width / CGFloat(week.days.count)
            ZStack(alignment: .topLeading) {
                ForEach(week.spans) { span in
                    SpanView(span: span, color: color(span.event.calendarID), compact: compact)
                        .frame(width: column * CGFloat(span.endColumn - span.startColumn + 1),
                               height: metrics.rowHeight)
                        .opensEventDetail(span.event, when: eventsOpenDetail)
                        // Padding rather than offset, so a popover points at the line itself.
                        .padding(.leading, column * CGFloat(span.startColumn))
                        .padding(.top, metrics.numberHeight + CGFloat(span.lane) * metrics.rowHeight)
                }
            }
        }
        // On iPhone the lines are drawing only: a tap belongs to the day under them.
        .allowsHitTesting(eventsOpenDetail)
    }
}

/// Taps on a day cell: one tap selects the day (iPhone), a double click on empty space creates
/// an event there (Mac, iPad), and its context menu offers a timed or an all-day event that day.
/// Events inside the cell take their own clicks and context menus first.
private struct DayCellTaps: ViewModifier {
    let day: Date
    let onSelect: ((Date) -> Void)?
    let onCreate: ((Date) -> Void)?
    let onCreateAllDay: ((Date) -> Void)?

    func body(content: Content) -> some View {
        if let onSelect {
            content.contentShape(Rectangle()).onTapGesture { onSelect(day) }
        } else if let onCreate {
            content.contentShape(Rectangle())
                .onTapGesture(count: 2) { onCreate(day) }
                .contextMenu {
                    Button("Nová událost", systemImage: "plus") { onCreate(day) }
                    if let onCreateAllDay {
                        Button("Nová celodenní událost", systemImage: "calendar.badge.plus") { onCreateAllDay(day) }
                    }
                }
                .accessibilityAction(named: Text("Nová událost v tento den")) { onCreate(day) }
        } else {
            content
        }
    }
}

/// An all-day or multi-day event. Across several days it is a line with the title set into it;
/// within one day it is a short lozenge followed by the title.
struct SpanView: View {
    let span: SpanSegment
    let color: ThemeColor
    /// Narrow columns: tighter insets and condensed type.
    let compact: Bool
    /// Moves the label along the line (paged columns keep it at the visible edge).
    /// The line runs on unbroken before it.
    var labelOffset: CGFloat = 0

    @Environment(CategoryModel.self) private var categoryModel
    @Environment(AppModel.self) private var model

    var body: some View {
        let categories = categoryModel.categories(for: span.event.key)
        let passed = model.hasPassed(span.event)
        // Wholly passed: the line mixed halfway into the ground, opaque (full strength under Increased Contrast).
        let line = passed ? Theme.passedSpanLine(model.color(of: span.event.calendarID)) : color
        let lead: CGFloat = span.continuesBefore ? 0 : 4
        let trail: CGFloat = span.continuesAfter ? 0 : 4
        let inset: CGFloat = compact ? 3 : 6
        HStack(spacing: compact ? 3 : 5) {
            // The line's start, lengthened by the label's slide so the line stays unbroken up to the label.
            UnevenRoundedRectangle(topLeadingRadius: lead, bottomLeadingRadius: lead,
                                   bottomTrailingRadius: 0, topTrailingRadius: 0)
                .fill(line)
                .frame(width: (compact ? 6 : 10) + max(0, labelOffset), height: 8)
            Text(EventRowView.title(of: span.event))
                .font(.caption2.weight(.semibold))
                .fontWidth(compact ? .condensed : .standard)
                .lineLimit(1)
                .foregroundStyle(passed ? Theme.secondaryInk : Theme.ink)
                .withCategorySymbols(categories, spacing: 3)
                .font(.caption2)
                .layoutPriority(1)
            if span.startColumn == span.endColumn && !span.continuesAfter {
                Spacer(minLength: 0)
            } else {
                UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                       bottomTrailingRadius: trail, topTrailingRadius: trail)
                    .fill(line)
                    .frame(height: 8)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.leading, span.continuesBefore ? 0 : inset)
        .padding(.trailing, span.continuesAfter ? 0 : inset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(EventText.spoken(span.event, calendar: model.calendar,
                                             calendarTitle: model.calendarInfo(span.event.calendarID)?.title,
                                             categories: categories))
    }
}
