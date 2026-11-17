import DaybookCore
import SwiftUI

/// One timed event in a day cell: a piece of its calendar's line, a station dot, time and title.
struct EventRowView: View {
    let event: EventInfo
    let color: Color
    /// iPhone width: no time, condensed type.
    let compact: Bool

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
            Rectangle()
                .fill(color)
                .frame(width: 3)
                .overlay {
                    Circle()
                        .fill(Theme.station)
                        .frame(width: 7, height: 7)
                        .overlay { Circle().stroke(color, lineWidth: 1.5) }
                }
            if !compact {
                Text(event.start, format: .dateTime.hour().minute())
                    .foregroundStyle(Theme.secondaryInk)
                    .monospacedDigit()
            }
            Text(Self.title(of: event))
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
