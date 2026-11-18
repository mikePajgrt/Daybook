import Foundation

/// Widths measured on screen for the wide (iPad) bar: the detail column's horizontal extent and the bar's
/// texts and switcher, set invisibly in the bar's own type. Only horizontal values: the column's height and
/// vertical position change with the bar itself and must not feed back into the bar's decision.
public struct WideBarMetrics: Equatable, Sendable {
    public var detailMinX: Double = 0
    public var detailWidth: Double = 0
    /// Probe widths, keyed by `WideBarLayout` keys and title candidates.
    public var texts: [String: Double] = [:]

    public init(detailMinX: Double = 0, detailWidth: Double = 0, texts: [String: Double] = [:]) {
        self.detailMinX = detailMinX
        self.detailWidth = detailWidth
        self.texts = texts
    }

    public func width(_ key: String) -> Double? { texts[key] }
}

/// What the wide bar shows, decided from `WideBarMetrics` alone.
public struct WideBarChoice: Hashable, Sendable {
    public var title: String
    public var pickerIsMenu: Bool
    /// The menu's up-down chevron, when the bar has room for it after the title.
    public var menuIndicator = false
    /// The middle item: where it may start and how wide it is, from after the title to before the trailing
    /// items. Fixed by the choice, so where the bar puts the item never changes the item's own width.
    /// `nil` before the bar is measured (the item is then just the switcher).
    public var slotMinX: Double?
    public var slotWidth: Double?
    /// Where the switcher starts: on the bar's middle when both sides allow it, else in the middle of the
    /// room between the title and the trailing items.
    public var pickerMinX: Double?
    /// The switcher's own width in this form.
    public var pickerWidth: Double?

    public init(title: String, pickerIsMenu: Bool, menuIndicator: Bool = false, slotMinX: Double? = nil,
                slotWidth: Double? = nil, pickerMinX: Double? = nil, pickerWidth: Double? = nil) {
        self.title = title
        self.pickerIsMenu = pickerIsMenu
        self.menuIndicator = menuIndicator
        self.slotMinX = slotMinX
        self.slotWidth = slotWidth
        self.pickerMinX = pickerMinX
        self.pickerWidth = pickerWidth
    }
}

/// The wide bar's arrangement as a pure function of measured widths. It used to pad the switcher by the
/// distance between the place it should be and where the bar had put it, measured on the padded item
/// itself; where the bar centres its middle item (an iPad app on the Mac, a wider window) every pad moved
/// the item and called for another pad, and the layout never settled (the TestFlight 0.1.0 (1) freeze).
/// Now the item's width comes from the choice alone, and the measured position only moves the switcher
/// inside it (`innerOffset`), which cannot move the item.
public enum WideBarLayout {
    public static let todayKey = "\u{1}today"
    public static let referenceKey = "\u{1}reference"
    public static let segmentedKey = "\u{1}segmented"
    public static let modeNameKey = "\u{1}mode"
    public static let modeMenuKey = "\u{1}modemenu"

    /// The bar's own geometry on iPadOS 26 at the default text size, measured on screen: where the
    /// back / Today / forward group starts beside the rail, and after the sidebar button (which joins
    /// the group) when the rail is hidden; the group without its "Dnes" (which is measured); the space
    /// between items; the plus, the filter and search with the bar's margin; the menu switcher's room
    /// around its title; and the least gap the bar keeps before the trailing items.
    public static let leadingInsetBesideRail = 20.0
    public static let leadingInsetAfterSidebarButton = 71.0
    public static let navigationGroupWithoutToday = 126.0
    public static let itemSpacing = 17.0
    public static let plusWithSpacing = 56.0
    public static let filterInGroup = 56.0
    public static let searchWithMargin = 58.0
    public static let menuPadding = 8.0
    public static let trailingGap = 16.0
    /// The fixed word "Dnes" at the default text size, against which the bar's growth is measured.
    public static let referenceAtDefaultSize = 39.5

    /// The first arrangement that fits. The title comes first and never shrinks for the switcher; then
    /// the segmented switcher, then the menu with its chevron, then the menu alone.
    public static func choose(titles: [String], filtering: Bool, railHidden: Bool, metrics m: WideBarMetrics) -> WideBarChoice {
        // Before the texts are measured, the last form, which is the shortest.
        let shortest = titles.allSatisfy({ m.width($0) != nil })
            ? titles.min { (m.width($0) ?? 0) < (m.width($1) ?? 0) } : titles.last
        let fallback = WideBarChoice(title: shortest ?? titles.last ?? "", pickerIsMenu: true)
        guard m.detailWidth > 0,
              let today = m.width(todayKey),
              let segmented = m.width(segmentedKey),
              let menuLabel = m.width(modeNameKey),
              let menuWithIndicator = m.width(modeMenuKey),
              let reference = m.width(referenceKey)
        else { return fallback }
        // The bar's buttons grow with the text a little (up to its own limit); its spacing grows with them.
        // Measured on one fixed word, so a longer word in another language is not taken for larger text.
        let scale = max(1, reference / referenceAtDefaultSize)
        let start = m.detailMinX + (railHidden ? leadingInsetAfterSidebarButton : leadingInsetBesideRail)
        let beforeTitle = start + navigationGroupWithoutToday * scale + today + itemSpacing
        let maxX = m.detailMinX + m.detailWidth
        let trailingStart = maxX - searchWithMargin * scale - plusWithSpacing * scale
            - (filtering ? filterInGroup * scale : 0)
        let middle = m.detailMinX + m.detailWidth / 2
        let roomEnd = trailingStart - trailingGap
        let forms: [(isMenu: Bool, chevron: Bool, width: Double)] = [
            (false, false, segmented), (true, true, menuWithIndicator + menuPadding), (true, false, menuLabel + menuPadding)]
        let measured = titles.compactMap { title in m.width(title).map { (title, $0) } }.sorted { $0.1 > $1.1 }
        for (title, titleWidth) in measured {
            let principalStart = beforeTitle + titleWidth + itemSpacing
            for form in forms where principalStart + form.width <= roomEnd {
                let centred = middle - form.width / 2
                let pickerStart = centred >= principalStart && centred + form.width <= roomEnd
                    ? centred : principalStart + (roomEnd - principalStart - form.width) / 2
                return WideBarChoice(title: title, pickerIsMenu: form.isMenu, menuIndicator: form.chevron,
                                     slotMinX: principalStart.rounded(.down),
                                     slotWidth: (roomEnd - principalStart).rounded(.down),
                                     pickerMinX: pickerStart.rounded(), pickerWidth: form.width)
            }
        }
        return fallback
    }

    /// The space inside the middle item before the switcher, given where the bar put the item: the
    /// switcher at `pickerMinX`, kept inside the item. It changes nothing about the item's size, so the
    /// bar's placement of the item does not depend on it.
    public static func innerOffset(for choice: WideBarChoice, itemMinX: Double) -> Double {
        guard let target = choice.pickerMinX, let width = choice.slotWidth, let picker = choice.pickerWidth,
              itemMinX > 0 else { return 0 }
        return min(max(0, target - itemMinX), max(0, width - picker)).rounded()
    }
}
