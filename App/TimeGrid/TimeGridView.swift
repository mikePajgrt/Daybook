import DaybookCore
import SwiftUI

/// The week and day views: day headers and the all-day strip on top, then the hours scrolling below.
/// When there are more days than fit (at most `visibleColumns`, and no column narrower than
/// `minimumColumnWidth`), the days page horizontally a day at a time, with the header and strip
/// following, while the hour axis stays put.
struct TimeGridView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let visibleColumns: Int
    /// Clicking a day header opens that day's view (week view only).
    let headersOpenDay: Bool

    @ScaledMetric(relativeTo: .caption) private var hourHeight: CGFloat = 52
    @ScaledMetric(relativeTo: .caption2) private var labelInset: CGFloat = 9
    @ScaledMetric(relativeTo: .caption2) private var gutterWidth: CGFloat = 46
    @ScaledMetric(relativeTo: .caption2) private var laneHeight: CGFloat = 20
    @State private var offsetX: CGFloat = 0
    @State private var leadingDay: Date?

    /// A day column is never narrower than this: below it titles and times have no room.
    static let minimumColumnWidth: CGFloat = 110
    /// Below this column width the grid sets condensed type.
    static let condensedBelow: CGFloat = 130

    var body: some View {
        // Grid columns cannot hold an accessibility-size title without breaking it letter by letter,
        // on any width: there the days become full-width rows, the way the month does.
        if dynamicTypeSize.isAccessibilitySize {
            AgendaView(days: model.gridDays, color: color(for:))
                .background(Theme.ground)
                .foregroundStyle(Theme.ink)
        } else {
            grid
        }
    }

    @ViewBuilder private var grid: some View {
        let days = model.gridDays
        let metrics = TimeGridMetrics(hourHeight: hourHeight, inset: labelInset)
        GeometryReader { proxy in
            let area = max(0, proxy.size.width - gutterWidth)
            let fitting = Int(area / Self.minimumColumnWidth)
            let shown = max(1, min(visibleColumns, days.count, fitting))
            let column = area / CGFloat(shown)
            let pages = days.count > shown
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 0) {
                    Color.clear.frame(width: gutterWidth, height: 1)
                    VStack(alignment: .leading, spacing: 0) {
                        headers(days, column: column)
                        AllDayStripView(segments: model.allDaySegments, dayCount: days.count,
                                        columnWidth: column, laneHeight: laneHeight,
                                        pinnedOffset: pages ? offsetX : nil, color: color(for:))
                            .modifier(CrossfadeOnFilter())
                    }
                    .frame(width: column * CGFloat(days.count), alignment: .leading)
                    .offset(x: pages ? -offsetX : 0)
                    .frame(width: area, alignment: .leading)
                    .clipped()
                }
                Rectangle().fill(Theme.rule).frame(height: 1)
                ScrollViewReader { reader in
                    ScrollView(.vertical) {
                        HStack(alignment: .top, spacing: 0) {
                            HourAxisView(metrics: metrics, width: gutterWidth, calendar: model.calendar,
                                         day: days.first ?? model.today)
                            if pages {
                                ScrollView(.horizontal) {
                                    columns(days, metrics: metrics, column: column)
                                        .scrollTargetLayout()
                                        .modifier(CrossfadeOnFilter())
                                }
                                .scrollTargetBehavior(.viewAligned)
                                .scrollPosition(id: $leadingDay, anchor: .leading)
                                .scrollIndicators(.hidden)
                                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x } action: { _, x in
                                    offsetX = x
                                }
                                .frame(width: area)
                            } else {
                                columns(days, metrics: metrics, column: column)
                                    .modifier(CrossfadeOnFilter())
                            }
                        }
                    }
                    .task(id: model.scrollKey) {
                        leadingDay = days.contains(model.today) ? model.today : days.first
                        reader.scrollTo(HourAxisView.id(hour: openingHour(days)), anchor: .top)
                    }
                }
            }
        }
        .background(Theme.ground)
        .foregroundStyle(Theme.ink)
    }

    /// One hour before now on a period that holds today, so the current-time line shows with context;
    /// 7:00 on any other period.
    private func openingHour(_ days: [Date]) -> Int {
        guard days.contains(model.today) else { return 7 }
        let hour = model.calendar.component(.hour, from: model.now(Date()))
        return max(0, hour - 1)
    }

    private func headers(_ days: [Date], column: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(days, id: \.self) { day in
                DayHeaderView(day: day, isToday: day == model.today, calendar: model.calendar,
                              onOpen: headersOpenDay ? { model.show(day: day) } : nil)
                    .frame(width: column)
            }
        }
    }

    private func columns(_ days: [Date], metrics: TimeGridMetrics, column: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(days.enumerated()), id: \.element) { index, day in
                DayColumnView(placements: index < model.placements.count ? model.placements[index] : [],
                              metrics: metrics, width: column,
                              isWeekend: model.calendar.isDateInWeekend(day),
                              isToday: day == model.today,
                              isLast: index == days.count - 1,
                              nowMinute: { nowMinute(on: day, clock: $0) },
                              color: rgba(for:),
                              condensed: column < Self.condensedBelow,
                              calendarTitle: { model.calendarInfo($0)?.title },
                              onCreate: sizeClass == .compact ? nil : { minute in
                                  model.beginNewEvent(at: TimeGridLayout.slotStart(day: day, minute: minute,
                                                                                   calendar: model.calendar))
                              })
                    .id(day)
                    .accessibilityLabel(DayText.spoken(day, isToday: day == model.today, count: model.events(on: day).count))
            }
        }
    }

    private func nowMinute(on day: Date, clock: Date) -> Int {
        let now = model.now(clock)
        let parts = model.calendar.dateComponents([.hour, .minute], from: now)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    private func rgba(for calendarID: String) -> RGBA { model.color(of: calendarID) }

    private func color(for calendarID: String) -> Color { Theme.line(rgba(for: calendarID)) }
}

/// Under Reduce Motion a calendar or category switch crossfades the content instead of moving blocks:
/// the content is replaced (new identity) inside an opacity transition. Otherwise nothing changes.
struct CrossfadeOnFilter: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .id(reduceMotion ? model.filterRevision : 0)
            .transition(.opacity)
    }
}
