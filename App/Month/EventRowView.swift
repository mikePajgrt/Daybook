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
    @Environment(CategoryModel.self) private var categoryModel
    @Environment(AppModel.self) private var model

    static func title(of event: EventInfo) -> String {
        event.title.isEmpty ? String(localized: "Bez názvu") : event.title
    }

    private var font: Font {
        #if os(macOS)
        .subheadline
        #else
        compact ? .caption2 : .caption
        #endif
    }

    var body: some View {
        let categories = categoryModel.categories(for: event.key)
        return HStack(spacing: compact ? 4 : 6) {
            StationMark(color: color)
                .opacity(dimmed ? 0.6 : 1)
            if !compact {
                // As wide as the widest time in this font, right-aligned, so titles share one left edge.
                Text(verbatim: "00:00")
                    .hidden()
                    .overlay(alignment: .trailing) {
                        Text(TimeText.time(event.start))
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
                .withCategorySymbols(categories, spacing: compact ? 2 : 4)
            Spacer(minLength: 0)
        }
        .font(font)
        .fontWidth(compact ? .condensed : .standard)
        .padding(.leading, compact ? 4 : 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(EventText.spoken(event, calendar: model.calendar,
                                             calendarTitle: model.calendarInfo(event.calendarID)?.title,
                                             categories: categories))
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
