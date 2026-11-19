import DaybookCore
import SwiftUI

/// One timed event in a day cell: a piece of its calendar's line, a station dot, time and title.
struct EventRowView: View {
    let event: EventInfo
    let color: ThemeColor
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
        let passed = model.hasPassed(event)
        return HStack(spacing: compact ? 4 : 6) {
            StationMark(color: color, passed: passed)
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
                // A passed event steps its title back; the neighbouring month keeps its outside ink.
                .foregroundStyle(dimmed ? Theme.outsideInk(contrast) : passed ? Theme.secondaryInk : Theme.ink)
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
    let color: ThemeColor
    /// The event is over: the station is hollow, showing whatever surface is behind it.
    var passed = false

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(width: 3)
            .stationHollow(passed)
            .overlay { StationDot(color: color, passed: passed) }
    }
}

/// The 7 pt station: station white inside a 1.5 pt ring of the line, or, once the event has passed,
/// the ring alone.
struct StationDot: View {
    static let diameter: CGFloat = 7
    let color: ThemeColor
    var passed = false

    var body: some View {
        Circle()
            .fill(passed ? AnyShapeStyle(Color.clear) : AnyShapeStyle(Theme.station))
            .frame(width: Self.diameter, height: Self.diameter)
            .overlay { Circle().stroke(color, lineWidth: 1.5) }
    }
}

extension View {
    /// Cuts the station's disc out of the line under it when `passed`, so a hollow station shows the
    /// surface behind the mark (ground, weekend veil, block fill) rather than a colour of its own.
    /// `top`: the dot's top inset; `nil` centres it.
    func stationHollow(_ passed: Bool, top: CGFloat? = nil) -> some View {
        mask {
            ZStack(alignment: top == nil ? .center : .top) {
                Rectangle()
                if passed {
                    Circle()
                        .frame(width: StationDot.diameter, height: StationDot.diameter)
                        .padding(.top, top ?? 0)
                        .blendMode(.destinationOut)
                }
            }
            .compositingGroup()
        }
    }
}
