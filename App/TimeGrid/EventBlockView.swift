import DaybookCore
import SwiftUI

/// One timed event in the grid: its calendar's line on the left with a station dot,
/// then the title (always), the time and the place when the block has room.
/// Text never breaks inside a word: the title wraps onto as many lines as the block holds when its
/// longest word fits the width, and otherwise holds one line with a tail ellipsis. The time shows only
/// when it fits on one line, and the place only when its first word fits whole.
struct EventBlockView: View {
    let placement: TimedPlacement
    let color: RGBA
    let calendarTitle: String?
    /// The block's width.
    let width: CGFloat
    /// One width for the whole grid: condensed when its day columns are narrow.
    let condensed: Bool

    /// Widths of the title's longest word and of the place's first word, measured in the block's type.
    @State private var longestTitleWord: CGFloat = 0
    @State private var firstPlaceWord: CGFloat = 0

    /// Room for text: the block less the line, the dot's overhang and the text insets.
    private var textWidth: CGFloat { width - 13 }

    /// Wrapping only happens between words: when a word is wider than the block, one line and an ellipsis.
    private var titleWraps: Bool { longestTitleWord > 0 && longestTitleWord <= textWidth }

    private var location: String? {
        guard let location = placement.event.location, !location.isEmpty else { return nil }
        return location
    }

    private static func words(_ text: String) -> [String] {
        text.split(whereSeparator: \.isWhitespace).map(String.init)
    }

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
        .background { probes }
        .background(Theme.blockFill(color))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel([title, timeRange, placement.event.location, calendarTitle]
            .compactMap { $0 }.joined(separator: ", "))
    }

    /// Invisible measurements of the words that decide wrapping, in the same type as the text.
    private var probes: some View {
        let firstPlace = location.flatMap { Self.words($0).first } ?? ""
        return ZStack {
            // One word per line: the stack is as wide as the widest word.
            VStack(spacing: 0) {
                ForEach(Array(Self.words(title).enumerated()), id: \.offset) { _, word in Text(word) }
            }
                .font(.caption.weight(.semibold))
                .fixedSize()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { longestTitleWord = $0 }
            Text(firstPlace)
                .font(.caption2)
                .fixedSize()
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { firstPlaceWord = $0 }
        }
        .fontWidth(condensed ? .condensed : .standard)
        .hidden()
        .accessibilityHidden(true)
    }

    @ViewBuilder private func details(time: Bool, place: Bool) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title)
                .font(.caption.weight(.semibold))
                // As many whole-word lines as the block's height holds; the last one ends in an ellipsis.
                .lineLimit(titleWraps ? nil : 1)
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
            // A place whose first word does not fit is dropped rather than shown as a stub.
            if place, let location, firstPlaceWord > 0, firstPlaceWord <= textWidth {
                Text(location)
                    .font(.caption2)
                    .lineLimit(1)
                    .foregroundStyle(Theme.blockSecondaryInk)
            }
        }
        .fontWidth(condensed ? .condensed : .standard)
    }
}
