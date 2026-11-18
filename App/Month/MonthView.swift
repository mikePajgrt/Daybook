import DaybookCore
import SwiftUI

/// The month: a weekday header over one continuous column of weeks of unequal height that never hide
/// an event. The column holds the focused month and three months either side; scrolling carries on
/// into them, and the title and the dimming follow the month that owns most of the viewport.
/// Back, Today and forward re-centre the window.
struct MonthView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedDay: SelectedDay?
    /// The week at the top of the viewport; setting it scrolls there.
    @State private var topWeek: Date?
    /// The user is dragging or the scroll is coasting: only then does the title follow the scroll.
    @State private var userScrolls = false
    /// The weeks on screen, as the scroll view reports them; the title follows the month owning most of them.
    @State private var visibleWeeks: [Date] = []
    @State private var viewport: CGFloat = 0

    @ScaledMetric(relativeTo: .caption) private var rowHeight: CGFloat = 17
    @ScaledMetric(relativeTo: .caption) private var numberHeight: CGFloat = 28

    private var compact: Bool { sizeClass == .compact }

    private var weekdaySymbols: [String] {
        let symbols = model.calendar.shortStandaloneWeekdaySymbols
        let first = model.calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    /// The month on screen, whose days are drawn in full ink.
    private var shownMonth: DateInterval? { model.calendar.dateInterval(of: .month, for: model.focusedDate) }

    var body: some View {
        GeometryReader { outer in
            // Below this column width a time and a readable title no longer fit on one row.
            let dense = outer.size.width / 7 < 130
            if dense && dynamicTypeSize.isAccessibilitySize {
                AgendaView(days: monthDays, color: color(for:))
            } else {
                VStack(spacing: 0) {
                    weekdayHeader
                    GeometryReader { proxy in
                        grid(viewport: proxy.size.height, dense: dense)
                    }
                }
            }
        }
        .background(Theme.ground)
        .foregroundStyle(Theme.ink)
        .sheet(item: $selectedDay) { day in
            NavigationStack { DayListView(day: day.date) }
                .presentationDetents([.medium, .large])
                .presentationBackground(Theme.rail)
        }
        #if DEBUG
        .onAppear {
            if model.stagedScreens.contains("day") { selectedDay = SelectedDay(date: model.today) }
        }
        #endif
    }

    /// The days of the month the window is centred on, for the agenda at accessibility sizes.
    private var monthDays: [Date] {
        model.weeks.flatMap(\.days).filter(\.isInMonth).map(\.date)
    }

    /// The weeks covering the month the window is centred on.
    private var centreWeekIDs: Set<Date> {
        Set(MonthLayout.weeks(containing: model.windowCenter, calendar: model.calendar).compactMap(\.first))
    }

    /// Every week gets the height its fullest day needs. When the centred month needs less than the
    /// viewport, the spare height is shared in proportion to need, so busy weeks stay the tall ones and
    /// the month fills the screen; its neighbours are scaled alike so the column reads as one.
    private func heights(viewport: CGFloat, metrics: WeekMetrics) -> [CGFloat] {
        let needed = model.weeks.map(metrics.contentHeight(for:))
        let centre = centreWeekIDs
        let total = zip(model.weeks, needed).filter { centre.contains($0.0.id) }.map(\.1).reduce(0, +)
        guard total > 0, viewport > total else { return needed }
        let scale = viewport / total
        return needed.map { $0 * scale }
    }

    /// The week the month opens on: today's week on iPhone when the centred month holds today, where the
    /// month does not fit; the month's first week where the whole month is meant to be scanned at once.
    private var openingWeek: Date? {
        let first = MonthLayout.weeks(containing: model.windowCenter, calendar: model.calendar).first?.first
        guard compact else { return first }
        let today = model.weeks.first { $0.days.contains { $0.date == model.today } }?.id
        if let today, centreWeekIDs.contains(today) { return today }
        return first
    }

    private func grid(viewport: CGFloat, dense: Bool) -> some View {
        let metrics = WeekMetrics(rowHeight: rowHeight, numberHeight: numberHeight)
        let rowHeights = heights(viewport: viewport, metrics: metrics)
        let rows = Array(zip(model.weeks, rowHeights))
        let month = shownMonth
        return ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(rows, id: \.0.id) { week, height in
                    WeekRowView(week: week, today: model.today, calendar: model.calendar,
                                metrics: metrics, compact: dense, color: color(for:), month: month,
                                // iPhone: a tap on a day opens the day sheet. Mac and iPad: the day number opens the day view.
                                onSelectDay: compact ? { selectedDay = SelectedDay(date: $0) } : nil,
                                onOpenDay: compact ? nil : { model.show(day: $0) },
                                // Mac and iPad: double-click on empty space creates an event that day.
                                onCreateEvent: compact ? nil : { model.beginNewEvent(onDay: $0) },
                                eventsOpenDetail: !compact)
                        .frame(height: height)
                        .id(week.id)
                }
            }
            .scrollTargetLayout()
            // Reduce Motion: a calendar switched off crossfades the month instead of closing rows up.
            .modifier(CrossfadeOnFilter())
        }
        .onAppear { self.viewport = viewport }
        .onChange(of: viewport) { self.viewport = viewport }
        .scrollPosition(id: $topWeek, anchor: .top)
        .onScrollPhaseChange { _, phase in
            userScrolls = phase == .interacting || phase == .decelerating
            // The scroll came to rest: the month on screen settles with it.
            if phase == .idle { followTitle(heights: rowHeights) }
        }
        // The weeks at least half on screen, as the scroll view itself reports them.
        .onScrollTargetVisibilityChange(idType: Date.self, threshold: 0.5) { ids in
            visibleWeeks = ids
            if userScrolls { followTitle(heights: rowHeights) }
        }
        .task(id: model.scrollKey) {
            topWeek = openingWeek
            #if DEBUG
            if model.stagedScreens.contains("scrolled") { await stageScroll() }
            #endif
        }
    }

    /// Makes the month that owns most of the visible weeks the month on screen.
    private func followTitle(heights: [CGFloat]) {
        let visible = Set(visibleWeeks)
        guard let owner = Self.owner(weeks: model.weeks.filter { visible.contains($0.id) },
                                     heights: zip(model.weeks, heights).filter { visible.contains($0.0.id) }.map(\.1),
                                     calendar: model.calendar) else { return }
        model.scrolled(toMonth: owner)
    }

    /// The month whose weeks take the most height among `weeks` (the ones on screen); a week belongs to
    /// the month of its middle day.
    static func owner(weeks: [WeekLayout], heights: [CGFloat], calendar: Calendar) -> Date? {
        var shares: [Date: CGFloat] = [:]
        for (week, height) in zip(weeks, heights) {
            if let month = MonthLayout.owner(of: week.days.map(\.date), calendar: calendar) {
                shares[month, default: 0] += height
            }
        }
        return shares.max { $0.value < $1.value }?.key
    }

    #if DEBUG
    /// Debug staging: scrolls down across the month's end, as a user would, so the capture shows the
    /// title and the dimming following the month that now owns the screen.
    private func stageScroll() async {
        // After the events have filled in, so the rows have their real heights.
        try? await Task.sleep(for: .milliseconds(1500))
        guard let next = model.calendar.date(byAdding: .month, value: 1, to: model.windowCenter),
              let nextStart = model.calendar.dateInterval(of: .month, for: next)?.start,
              let index = model.weeks.firstIndex(where: { $0.days.contains { $0.date == nextStart } }) else { return }
        // The week before the one holding the 1st at the top: the old month's last week, then the new month.
        withAnimation { topWeek = model.weeks[max(0, index - 1)].id }
        try? await Task.sleep(for: .milliseconds(900))
        let metrics = WeekMetrics(rowHeight: rowHeight, numberHeight: numberHeight)
        followTitle(heights: heights(viewport: viewport, metrics: metrics))
    }
    #endif

    private var weekdayHeader: some View {
        HStack(spacing: 0) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.secondaryInk)
                    .padding(.leading, compact ? 3 : 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.rule).frame(height: 1) }
        .accessibilityHidden(true)
    }

    private func color(for calendarID: String) -> Color {
        Theme.line(model.color(of: calendarID))
    }
}
