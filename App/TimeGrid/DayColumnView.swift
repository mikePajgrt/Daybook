import DaybookCore
import SwiftUI

/// One day of the time grid: hour rules, its events side by side where they overlap,
/// and on today the current-time line with the interchange circle.
struct DayColumnView: View {
    let placements: [TimedPlacement]
    let metrics: TimeGridMetrics
    let width: CGFloat
    let isWeekend: Bool
    let isToday: Bool
    let isLast: Bool
    /// Wall-clock minutes of the current time on `date`.
    let nowMinute: (Date) -> Int
    let color: (String) -> RGBA
    /// Condensed type for the whole grid when its columns are narrow.
    let condensed: Bool
    let calendarTitle: (String) -> String?

    private static let gap: CGFloat = 2

    var body: some View {
        ZStack(alignment: .topLeading) {
            HourRules(metrics: metrics)
                .stroke(Theme.rule, lineWidth: 1)
            ForEach(placements) { placement in
                block(placement)
            }
            if isToday {
                TimelineView(.everyMinute) { context in
                    NowLine()
                        .offset(y: metrics.y(minute: nowMinute(context.date)) - NowLine.diameter / 2)
                }
            }
        }
        .frame(width: width, height: metrics.gridHeight, alignment: .topLeading)
        .background(isWeekend ? Theme.weekend : Color.clear)
        .overlay(alignment: .trailing) {
            if !isLast { Rectangle().fill(Theme.rule).frame(width: 1) }
        }
        .accessibilityElement(children: .contain)
    }

    private func block(_ placement: TimedPlacement) -> some View {
        let usable = width - Self.gap * 2
        let slot = usable / CGFloat(max(placement.columnCount, 1))
        let top = metrics.y(minute: placement.startMinute)
        let natural = metrics.y(minute: placement.endMinute) - top
        let height = max(natural, metrics.minimumBlockHeight) - 1
        let blockWidth = max(slot - Self.gap, 1)
        return EventBlockView(placement: placement, color: color(placement.event.calendarID),
                              calendarTitle: calendarTitle(placement.event.calendarID), width: blockWidth,
                              condensed: condensed)
            .frame(width: blockWidth, height: max(height, 1))
            .offset(x: Self.gap + slot * CGFloat(placement.column), y: top)
    }
}

/// A hairline at every hour.
private struct HourRules: Shape {
    let metrics: TimeGridMetrics

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for hour in 0...24 {
            let y = metrics.y(minute: hour * 60)
            path.move(to: CGPoint(x: rect.minX, y: y))
            path.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return path
    }
}

/// The current time: an ink line starting at the interchange circle.
struct NowLine: View {
    static let diameter: CGFloat = 11

    var body: some View {
        HStack(spacing: 0) {
            Circle()
                .fill(Theme.ink)
                .overlay { Circle().stroke(Theme.ground, lineWidth: 2) }
                .frame(width: Self.diameter, height: Self.diameter)
            Rectangle()
                .fill(Theme.ink)
                .frame(height: 2)
        }
        .frame(height: Self.diameter)
        .accessibilityElement()
        .accessibilityLabel("Teď")
    }
}
