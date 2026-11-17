import DaybookCore
import SwiftUI

/// All-day and long events above the grid, one lane per row. It grows with its lanes and never truncates.
struct AllDayStripView: View {
    let segments: [SpanSegment]
    let dayCount: Int
    let columnWidth: CGFloat
    let laneHeight: CGFloat
    /// Paged narrow columns: every day carries its own label, because the start may be scrolled away.
    let labelsEveryDay: Bool
    let color: (String) -> Color

    static let padding: CGFloat = 4

    static func height(laneCount: Int, laneHeight: CGFloat) -> CGFloat {
        laneCount == 0 ? 0 : CGFloat(laneCount) * laneHeight + padding * 2
    }

    private var pieces: [SpanSegment] {
        labelsEveryDay ? segments.flatMap { $0.splitByDay() } : segments
    }

    var body: some View {
        let laneCount = (segments.map(\.lane).max() ?? -1) + 1
        ZStack(alignment: .topLeading) {
            ForEach(Array(pieces.enumerated()), id: \.offset) { _, span in
                SpanView(span: span, color: color(span.event.calendarID), compact: columnWidth < 130)
                    .frame(width: columnWidth * CGFloat(span.endColumn - span.startColumn + 1), height: laneHeight)
                    .offset(x: columnWidth * CGFloat(span.startColumn),
                            y: Self.padding + CGFloat(span.lane) * laneHeight)
            }
        }
        .frame(width: columnWidth * CGFloat(dayCount),
               height: Self.height(laneCount: laneCount, laneHeight: laneHeight), alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Celodenní události")
    }
}
