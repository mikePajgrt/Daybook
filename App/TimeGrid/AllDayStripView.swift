import DaybookCore
import SwiftUI

/// All-day and long events above the grid, one lane per row. It grows with its lanes and never truncates.
struct AllDayStripView: View {
    let segments: [SpanSegment]
    let dayCount: Int
    let columnWidth: CGFloat
    let laneHeight: CGFloat
    /// Paged columns: how far the days are scrolled. Each event's label then slides along its line
    /// to stay at the visible leading edge, so one label per event is always readable.
    /// `nil` when every day is on screen.
    let pinnedOffset: CGFloat?
    let color: (String) -> ThemeColor

    static let padding: CGFloat = 4

    static func height(laneCount: Int, laneHeight: CGFloat) -> CGFloat {
        laneCount == 0 ? 0 : CGFloat(laneCount) * laneHeight + padding * 2
    }

    var body: some View {
        let laneCount = (segments.map(\.lane).max() ?? -1) + 1
        ZStack(alignment: .topLeading) {
            ForEach(segments) { span in
                let x = columnWidth * CGFloat(span.startColumn)
                let width = columnWidth * CGFloat(span.endColumn - span.startColumn + 1)
                // Slide the label to the visible edge, but never past the start of the event's last day.
                let slide = pinnedOffset.map { min(max(0, $0 - x), max(0, width - columnWidth)) } ?? 0
                SpanView(span: span, color: color(span.event.calendarID),
                         compact: columnWidth < TimeGridView.condensedBelow, labelOffset: slide)
                    .frame(width: width, height: laneHeight)
                    .opensEventDetail(span.event)
                    // Padding rather than offset, so a popover points at the line itself.
                    .padding(.leading, x)
                    .padding(.top, Self.padding + CGFloat(span.lane) * laneHeight)
            }
        }
        .frame(width: columnWidth * CGFloat(dayCount),
               height: Self.height(laneCount: laneCount, laneHeight: laneHeight), alignment: .topLeading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Celodenní události")
    }
}
