import DaybookCore
import SwiftUI

/// One timed event in the grid: its calendar's line on the left with a station dot,
/// then the title (always), the time and the place when the block has room.
struct EventBlockView: View {
    let placement: TimedPlacement
    let color: Color
    let calendarTitle: String?
    /// The block's width. Narrow blocks set condensed type that shrinks a little rather than
    /// breaking a word letter by letter.
    let width: CGFloat

    private var narrow: Bool { width < 90 }

    private var title: String { EventRowView.title(of: placement.event) }

    private var timeRange: String {
        let start = placement.event.start.formatted(date: .omitted, time: .shortened)
        let end = placement.event.end.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(color)
                .frame(width: 3)
                .overlay(alignment: .top) {
                    Circle()
                        .fill(Theme.station)
                        .frame(width: 7, height: 7)
                        .overlay { Circle().stroke(color, lineWidth: 1.5) }
                        .padding(.top, 4)
                }
            ViewThatFits(in: .vertical) {
                details(time: true, place: true)
                details(time: true, place: false)
                details(time: false, place: false)
            }
            .padding(.leading, narrow ? 4 : 6)
            .padding(.trailing, narrow ? 1 : 3)
            .padding(.vertical, 2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // Opaque, so hour rules do not run through the text.
        .background { ZStack { Theme.ground; Theme.blockFill(color) } }
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, timeRange, placement.event.location, calendarTitle]
            .compactMap { $0 }.joined(separator: ", "))
    }

    @ViewBuilder private func details(time: Bool, place: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font((narrow ? Font.caption2 : Font.caption).weight(.semibold))
                .fontWidth(narrow ? .condensed : .standard)
                .minimumScaleFactor(narrow ? 0.7 : 1)
                .foregroundStyle(Theme.ink)
            if time {
                Text(timeRange)
                    .font(.caption2)
                    .fontWidth(narrow ? .condensed : .standard)
                    .monospacedDigit()
                    .foregroundStyle(Theme.blockSecondaryInk)
            }
            if place, let location = placement.event.location, !location.isEmpty {
                Text(location)
                    .font(.caption2)
                    .foregroundStyle(Theme.blockSecondaryInk)
            }
        }
    }
}
