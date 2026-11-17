import SwiftUI

/// One day in a single column. On Mac and iPad a month navigator sits beside it.
struct DayView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        HStack(spacing: 0) {
            TimeGridView(visibleColumns: 1, headersOpenDay: false)
            if sizeClass != .compact {
                Rectangle().fill(Theme.rule).frame(width: 1)
                MonthNavigatorView()
            }
        }
        .background(Theme.ground)
    }
}
