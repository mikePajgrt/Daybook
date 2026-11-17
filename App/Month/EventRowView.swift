import DaybookCore
import SwiftUI

/// One timed event in a day cell: a piece of its calendar's line, a station dot, time and title.
struct EventRowView: View {
    let event: EventInfo
    let color: Color
    /// Narrow columns (iPhone, iPad beside the sidebar): no time, condensed type.
    let compact: Bool
    /// The event's day belongs to the neighbouring month.
    var dimmed = false

    @Environment(\.colorSchemeContrast) private var contrast

    static func title(of event: EventInfo) -> String {
        event.title.isEmpty ? "Bez názvu" : event.title
    }

    private var font: Font {
        #if os(macOS)
        .subheadline
        #else
        compact ? .caption2 : .caption
        #endif
    }

    var body: some View {
        HStack(spacing: compact ? 4 : 6) {
            StationMark(color: color)
                .opacity(dimmed ? 0.6 : 1)
            if !compact {
                // As wide as the widest time in this font, right-aligned, so titles share one left edge.
                Text(verbatim: "00:00")
                    .hidden()
                    .overlay(alignment: .trailing) {
                        Text(event.start, format: .dateTime.hour().minute())
                            .foregroundStyle(dimmed ? Theme.outsideInk(contrast) : Theme.secondaryInk)
                            .fixedSize()
                    }
                    .monospacedDigit()
                    .fixedSize()
                    .accessibilityHidden(true)
            }
            Text(Self.title(of: event))
                .foregroundStyle(dimmed ? Theme.outsideInk(contrast) : Theme.ink)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .font(font)
        .fontWidth(compact ? .condensed : .standard)
        .padding(.leading, compact ? 4 : 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(event.start.formatted(date: .omitted, time: .shortened)), \(Self.title(of: event))")
    }
}

/// A piece of a calendar's line with the station dot that marks one event on it.
struct StationMark: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 3)
            .overlay {
                Circle()
                    .fill(Theme.station)
                    .frame(width: 7, height: 7)
                    .overlay { Circle().stroke(color, lineWidth: 1.5) }
            }
    }
}
