import Foundation

/// Keeps a scroll view on an intended item (the month's opening week) while its layout changes under it:
/// events arriving, calendars switched in, the window or the rail resizing. The intended item is kept
/// here, apart from the scroll view's own position, which drifts when rows above it change height.
///
/// It only answers "scroll to what?"; the view does the scrolling. Re-scrolling never changes the
/// layout, and a layout that keeps reporting the wrong top item gets a bounded number of corrections,
/// so it cannot fire itself.
public struct ScrollAnchor<ID: Hashable & Sendable>: Equatable, Sendable {
    /// Corrections for one layout when the scroll view reports another item at the top.
    public static var correctionsPerLayout: Int { 3 }

    /// The item the view is anchored on, `nil` once the user took over.
    public private(set) var target: ID?
    private var layout: Int?
    private var corrections = 0

    public init() {}

    /// Opening or "Dnes": anchor on `item` (nothing when `nil`).
    public mutating func anchor(on item: ID?) {
        target = item
        corrections = 0
    }

    /// The user scrolled: the view follows them from now on.
    public mutating func release() {
        target = nil
    }

    /// The layout under the scroll view changed (`signature` sums up row heights, viewport, width and
    /// content size). Returns the item to scroll back to, or `nil` when not anchored or nothing changed.
    public mutating func layoutChanged(_ signature: Int) -> ID? {
        guard signature != layout else { return nil }
        layout = signature
        corrections = 0
        return target
    }

    /// The scroll view reports `top` at the top. Returns the item to scroll back to when it is not the
    /// anchor, at most `correctionsPerLayout` times for one layout.
    public mutating func reported(top: ID?) -> ID? {
        guard let target, let top, top != target, corrections < Self.correctionsPerLayout else { return nil }
        corrections += 1
        return target
    }
}
