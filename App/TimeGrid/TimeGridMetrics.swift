import CoreGraphics

/// Vertical geometry of the time grid, shared by the hour axis and every day column.
/// The owner scales the values with Dynamic Type.
struct TimeGridMetrics {
    let hourHeight: CGFloat
    /// Room above the first rule and below the last, so the 0:00 label is not cut in half.
    let inset: CGFloat

    func y(minute: Int) -> CGFloat { inset + CGFloat(minute) * hourHeight / 60 }

    var gridHeight: CGFloat { y(minute: 24 * 60) + inset }

    /// Blocks are never shorter than half an hour, matching `AppModel.minimumBlockDuration`.
    var minimumBlockHeight: CGFloat { hourHeight / 2 }
}
