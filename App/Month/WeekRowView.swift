import DaybookCore
import SwiftUI

/// One week of the month: seven day cells, with multi-day events drawn across them as lines.
struct WeekRowView: View {
    let week: WeekLayout
    let today: Date
    let calendar: Calendar
    let compact: Bool
    let color: (String) -> Color
    /// Called when a day is tapped. `nil` where tapping a day does nothing.
    let onSelectDay: ((Date) -> Void)?

    @ScaledMetric(relativeTo: .caption) private var rowHeight: CGFloat = 17
    @ScaledMetric(relativeTo: .caption) private var numberHeight: CGFloat = 28

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            ForEach(Array(week.days.enumerated()), id: \.element.date) { index, day in
                dayCell(day, isLast: index == week.days.count - 1)
            }
        }
        .frame(minHeight: numberHeight + rowHeight * 2, alignment: .top)
        .overlay(alignment: .topLeading) { spans }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
    }

    private func dayCell(_ day: DayLayout, isLast: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            dayNumber(day)
            Color.clear.frame(height: CGFloat(week.laneCount) * rowHeight)
            ForEach(day.timed) { event in
                EventRowView(event: event, color: color(event.calendarID), compact: compact)
                    .frame(height: rowHeight)
            }
            Spacer(minLength: 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(calendar.isDateInWeekend(day.date) ? Theme.weekend : Color.clear)
        .opacity(day.isInMonth ? 1 : 0.45)
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
        return Text(day.date, format: .dateTime.day())
            .font(.callout.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(isToday ? Theme.ground : Theme.ink)
            .padding(.horizontal, isToday ? 6 : 0)
            .padding(.vertical, 2)
            .background { if isToday { Capsule().fill(Theme.ink) } }
            .padding(.leading, compact ? 3 : 6)
            .frame(height: numberHeight, alignment: .leading)
            .accessibilityLabel(isToday ? "Dnes" : "")
    }

    private var spans: some View {
        GeometryReader { proxy in
            let column = proxy.size.width / CGFloat(week.days.count)
            ZStack(alignment: .topLeading) {
                ForEach(week.spans) { span in
                    SpanView(span: span, color: color(span.event.calendarID))
                        .frame(width: column * CGFloat(span.endColumn - span.startColumn + 1), height: rowHeight)
                        .offset(x: column * CGFloat(span.startColumn),
                                y: numberHeight + CGFloat(span.lane) * rowHeight)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// An all-day or multi-day event: a horizontal line with rounded ends where the event really starts and ends.
struct SpanView: View {
    let span: SpanSegment
    let color: Color

    var body: some View {
        let lead: CGFloat = span.continuesBefore ? 0 : 4
        let trail: CGFloat = span.continuesAfter ? 0 : 4
        ZStack(alignment: .leading) {
            UnevenRoundedRectangle(topLeadingRadius: lead, bottomLeadingRadius: lead,
                                   bottomTrailingRadius: trail, topTrailingRadius: trail)
                .fill(color)
                .frame(height: 8)
                .padding(.leading, span.continuesBefore ? 0 : 6)
                .padding(.trailing, span.continuesAfter ? 0 : 6)
            Text(EventRowView.title(of: span.event))
                .font(.caption2.weight(.semibold))
                .lineLimit(1)
                .padding(.horizontal, 4)
                .background(Theme.ground)
                .padding(.leading, 16)
                .padding(.trailing, 10)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(EventRowView.title(of: span.event))
    }
}
