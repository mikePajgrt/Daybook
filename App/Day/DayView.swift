import SwiftUI

/// One day in a single column. On Mac and iPad a month navigator sits beside it when the day keeps
/// enough room; otherwise the navigator moves to the bottom of the sidebar.
struct DayView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.horizontalSizeClass) private var sizeClass

    static let navigatorWidth: CGFloat = 300
    /// The day keeps at least this much width when the navigator sits beside it.
    static let minimumDayWidth: CGFloat = 400

    var body: some View {
        GeometryReader { proxy in
            let beside = sizeClass != .compact && proxy.size.width - Self.navigatorWidth - 1 >= Self.minimumDayWidth
            HStack(spacing: 0) {
                TimeGridView(visibleColumns: 1, headersOpenDay: false)
                if beside {
                    Rectangle().fill(Theme.rule).frame(width: 1)
                    MonthNavigatorView()
                        .padding(12)
                        .frame(width: Self.navigatorWidth)
                        .frame(maxHeight: .infinity, alignment: .top)
                        .background(Theme.rail)
                }
            }
            .onAppear { model.dayNavigatorInSidebar = sizeClass != .compact && !beside }
            .onChange(of: beside) { model.dayNavigatorInSidebar = sizeClass != .compact && !beside }
        }
        .background(Theme.ground)
        .onDisappear { model.dayNavigatorInSidebar = false }
    }
}
