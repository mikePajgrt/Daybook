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
    let color: (String) -> Color
    /// Called when a day is tapped. `nil` where tapping a day does nothing.
    let onSelectDay: ((Date) -> Void)?

    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(week.days.enumerated()), id: \.element.date) { index, day in
                dayCell(day, isLast: index == week.days.count - 1)
            }
        }
        .overlay(alignment: .topLeading) { spans }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }

    private func dayCell(_ day: DayLayout, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            dayNumber(day)
            Color.clear.frame(height: CGFloat(week.laneCount) * metrics.rowHeight)
            ForEach(day.timed) { event in
                EventRowView(event: event, color: color(event.calendarID),
                             compact: compact, dimmed: !day.isInMonth)
                    .frame(height: metrics.rowHeight)
            }
            Spacer(minLength: WeekMetrics.bottomInset)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(calendar.isDateInWeekend(day.date) ? Theme.weekend : Color.clear)
        .clipped()
        .overlay(alignment: .trailing) {
            if !isLast { Rectangle().fill(Theme.rule).frame(width: 1) }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelectDay?(day.date) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(day.date.formatted(date: .complete, time: .omitted))
    }

    private func dayNumber(_ day: DayLayout) -> some View {
        let isToday = day.date == today
        let ink = day.isInMonth ? Theme.ink : Theme.outsideInk(contrast)
        return Text(verbatim: String(calendar.component(.day, from: day.date)))
            .font((compact ? Font.footnote : Font.callout).weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(isToday ? Theme.ground : ink)
            .frame(minWidth: metrics.numberHeight - 6, minHeight: metrics.numberHeight - 6)
            .background { if isToday { Circle().fill(Theme.ink) } }
            .padding(.leading, isToday ? (compact ? 1 : 3) : (compact ? 3 : 6))
            .frame(height: metrics.numberHeight, alignment: .leading)
            .accessibilityLabel(isToday ? "Dnes" : "")
    }

    private var spans: some View {
        GeometryReader { proxy in
            let column = proxy.size.width / CGFloat(week.days.count)
            ZStack(alignment: .topLeading) {
                ForEach(week.spans) { span in
                    SpanView(span: span, color: color(span.event.calendarID), compact: compact)
                        .frame(width: column * CGFloat(span.endColumn - span.startColumn + 1),
                               height: metrics.rowHeight)
                        .offset(x: column * CGFloat(span.startColumn),
                                y: metrics.numberHeight + CGFloat(span.lane) * metrics.rowHeight)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// An all-day or multi-day event. Across several days it is a line with the title set into it;
/// within one day it is a short lozenge followed by the title.
struct SpanView: View {
    let span: SpanSegment
    let color: Color
    /// Narrow columns: tighter insets and condensed type.
    let compact: Bool

    var body: some View {
        let lead: CGFloat = span.continuesBefore ? 0 : 4
        let trail: CGFloat = span.continuesAfter ? 0 : 4
        let inset: CGFloat = compact ? 3 : 6
        HStack(spacing: compact ? 3 : 5) {
            UnevenRoundedRectangle(topLeadingRadius: lead, bottomLeadingRadius: lead,
                                   bottomTrailingRadius: 0, topTrailingRadius: 0)
                .fill(color)
                .frame(width: compact ? 6 : 10, height: 8)
            Text(EventRowView.title(of: span.event))
                .font(.caption2.weight(.semibold))
                .fontWidth(compact ? .condensed : .standard)
                .lineLimit(1)
                .layoutPriority(1)
            if span.startColumn == span.endColumn && !span.continuesAfter {
                Spacer(minLength: 0)
            } else {
                UnevenRoundedRectangle(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                       bottomTrailingRadius: trail, topTrailingRadius: trail)
                    .fill(color)
                    .frame(height: 8)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.leading, span.continuesBefore ? 0 : inset)
        .padding(.trailing, span.continuesAfter ? 0 : inset)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(EventRowView.title(of: span.event))
    }
}
