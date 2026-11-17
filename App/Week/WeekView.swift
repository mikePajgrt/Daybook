import SwiftUI

/// The week: seven day columns; on iPhone three at a time, paged horizontally.
struct WeekView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        TimeGridView(visibleColumns: sizeClass == .compact ? 3 : 7, headersOpenDay: true)
    }
}
