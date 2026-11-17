import DaybookCore
import SwiftUI

/// One timed event in the grid: its calendar's line on the left with a station dot,
/// then the title (always), the time and the place when the block has room.
/// Text never breaks inside a word: narrow blocks hold the title on one line with a tail ellipsis,
/// and the time shows only when it fits on one line.
struct EventBlockView: View {
    let placement: TimedPlacement
    let color: RGBA
    let calendarTitle: String?
    /// The block's width.
    let width: CGFloat
    /// One width for the whole grid: condensed when its day columns are narrow.
    let condensed: Bool

    /// Below this width a second title line would only hold a word fragment.
    private var titleLines: Int { width < 140 ? 1 : 2 }

    private var title: String { EventRowView.title(of: placement.event) }

    private var timeRange: String {
        let start = placement.event.start.formatted(date: .omitted, time: .shortened)
        let end = placement.event.end.formatted(date: .omitted, time: .shortened)
        return "\(start) – \(end)"
    }

    var body: some View {
        let line = Color(color)
        HStack(alignment: .top, spacing: 0) {
            Rectangle()
                .fill(line)
                .frame(width: 3)
                .overlay(alignment: .top) {
                    Circle()
                        .fill(Theme.station)
                        .frame(width: 7, height: 7)
                        .overlay { Circle().stroke(line, lineWidth: 1.5) }
                        .padding(.top, 4)
                }
                // The dot is wider than the line: inset the line so the clip keeps the dot whole.
                .padding(.leading, 2)
            ViewThatFits(in: .vertical) {
                details(time: true, place: true)
                details(time: true, place: false)
                details(time: false, place: false)
            }
            .padding(.leading, 5)
            .padding(.trailing, 3)
            .padding(.vertical, 2)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Theme.blockFill(color))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, timeRange, placement.event.location, calendarTitle]
            .compactMap { $0 }.joined(separator: ", "))
    }

    @ViewBuilder private func details(time: Bool, place: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption.weight(.semibold))
                .lineLimit(titleLines)
                .truncationMode(.tail)
                .foregroundStyle(Theme.ink)
            if time {
                // The whole range on one line, else the start alone, else nothing.
                ViewThatFits(in: .horizontal) {
                    Text(timeRange).fixedSize()
                    Text(placement.event.start, format: .dateTime.hour().minute()).fixedSize()
                    Color.clear.frame(width: 0, height: 0)
                }
                .font(.caption2)
                .monospacedDigit()
                .foregroundStyle(Theme.blockSecondaryInk)
            }
            if place, let location = placement.event.location, !location.isEmpty {
                Text(location)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(Theme.blockSecondaryInk)
            }
        }
        .fontWidth(condensed ? .condensed : .standard)
    }
}
