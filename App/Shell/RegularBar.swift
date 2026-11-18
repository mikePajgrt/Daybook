import SwiftUI

#if os(iOS)
/// What the iPad bar shows: back / Today / forward and the period on the left, the view switcher in the
/// middle, the new event, the filter count and search on the right; the title and switcher in the
/// widest forms that fit together.
struct RegularBarChoice: Hashable {
    var title: String
    var pickerIsMenu: Bool
    /// The menu's up-down chevron, when the bar has room for it after the title.
    var menuIndicator = false
    /// The switcher sits in the middle of the bar; otherwise right after the title.
    var centred = false
}

/// Widths measured on screen: the detail column, where the bar placed the middle item, and the bar's
/// texts and switcher, set invisibly in the bar's own type (`RegularBarProbes`).
struct RegularBarMetrics: Equatable {
    /// The detail column, in global coordinates.
    var detail: CGRect = .zero
    /// Where the bar starts the middle item; the switcher is padded from there to the bar's middle.
    var principalMinX: CGFloat = 0
    /// Probe widths, keyed by `RegularBarProbes` keys and title candidates.
    var texts: [String: CGFloat] = [:]

    func width(_ key: String) -> CGFloat? { texts[key] }
}

enum RegularBarLayout {
    /// The bar's own geometry on iPadOS 26 at the default text size, measured on screen: where the
    /// back / Today / forward group starts beside the rail, and after the sidebar button (which joins
    /// the group) when the rail is hidden; the group without its "Dnes" (which is measured); the space
    /// between items; the plus, the filter and search with the bar's margin; the menu switcher's room
    /// around its title; and the least gap the bar keeps before the trailing items.
    static let leadingInsetBesideRail: CGFloat = 20
    static let leadingInsetAfterSidebarButton: CGFloat = 71
    static let navigationGroupWithoutToday: CGFloat = 126
    static let itemSpacing: CGFloat = 17
    static let plusWithSpacing: CGFloat = 56
    static let filterInGroup: CGFloat = 56
    static let searchWithMargin: CGFloat = 58
    static let menuPadding: CGFloat = 8
    static let trailingGap: CGFloat = 16
    /// The fixed word "Dnes" at the default text size, against which the bar's growth is measured.
    static let referenceAtDefaultSize: CGFloat = 39.5

    /// The first arrangement that fits. The title comes first and never shrinks for the switcher; then
    /// the segmented switcher, then the menu with its chevron, then the menu alone; each in the bar's
    /// middle where both sides hold their items, else right after the title.
    static func choose(titles: [String], filtering: Bool, railHidden: Bool, metrics m: RegularBarMetrics) -> RegularBarChoice {
        // Before the texts are measured, the last form, which is the shortest.
        let shortest = titles.allSatisfy({ m.width($0) != nil })
            ? titles.min { (m.width($0) ?? 0) < (m.width($1) ?? 0) } : titles.last
        let fallback = RegularBarChoice(title: shortest ?? titles.last ?? "", pickerIsMenu: true)
        guard m.detail.width > 0,
              let today = m.width(RegularBarProbes.todayKey),
              let segmented = m.width(RegularBarProbes.segmentedKey),
              let menuLabel = m.width(RegularBarProbes.modeNameKey),
              let menuWithIndicator = m.width(RegularBarProbes.modeMenuKey),
              let reference = m.width(RegularBarProbes.referenceKey)
        else { return fallback }
        // The bar's buttons grow with the text a little (up to its own limit); its spacing grows with them.
        // Measured on one fixed word, so a longer word in another language is not taken for larger text.
        let scale = max(1, reference / referenceAtDefaultSize)
        let start = m.detail.minX + (railHidden ? leadingInsetAfterSidebarButton : leadingInsetBesideRail)
        let beforeTitle = start + navigationGroupWithoutToday * scale + today + itemSpacing
        let trailingStart = m.detail.maxX - searchWithMargin * scale - plusWithSpacing * scale
            - (filtering ? filterInGroup * scale : 0)
        let middle = m.detail.midX
        let forms: [(isMenu: Bool, chevron: Bool, width: CGFloat)] = [
            (false, false, segmented), (true, true, menuWithIndicator + menuPadding), (true, false, menuLabel + menuPadding)]
        let measured = titles.compactMap { title in m.width(title).map { (title, $0) } }.sorted { $0.1 > $1.1 }
        for (title, titleWidth) in measured {
            let principalStart = beforeTitle + titleWidth + itemSpacing
            for form in forms {
                for centred in [true, false] {
                    let pickerStart = centred ? middle - form.width / 2 : principalStart
                    guard pickerStart >= principalStart,
                          pickerStart + form.width + trailingGap <= trailingStart else { continue }
                    return RegularBarChoice(title: title, pickerIsMenu: form.isMenu, menuIndicator: form.chevron,
                                            centred: centred)
                }
            }
        }
        return fallback
    }

    /// The space before the switcher that puts its middle on the bar's middle.
    static func centringPad(for choice: RegularBarChoice, metrics m: RegularBarMetrics) -> CGFloat {
        guard choice.centred, m.principalMinX > 0 else { return 0 }
        let width: CGFloat?
        if choice.pickerIsMenu {
            width = m.width(choice.menuIndicator ? RegularBarProbes.modeMenuKey : RegularBarProbes.modeNameKey)
                .map { $0 + menuPadding }
        } else {
            width = m.width(RegularBarProbes.segmentedKey)
        }
        guard let width else { return 0 }
        return max(0, m.detail.midX - width / 2 - m.principalMinX)
    }
}

/// Invisible copies of the bar's texts and switcher, measured in the bar's type at the current size.
struct RegularBarProbes: View {
    static let todayKey = "\u{1}today"
    static let referenceKey = "\u{1}reference"
    static let segmentedKey = "\u{1}segmented"
    static let modeNameKey = "\u{1}mode"
    static let modeMenuKey = "\u{1}modemenu"

    let titles: [String]
    let modeName: LocalizedStringKey
    let onMeasure: (String, CGFloat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(titles, id: \.self) { title in
                measured(title) { BarTitleText(text: title) }
            }
            measured(Self.todayKey) { Text("Dnes").font(.body) }
            measured(Self.referenceKey) { Text(verbatim: "Dnes").font(.body) }
            measured(Self.modeNameKey) { Text(modeName).font(.body) }
            measured(Self.modeMenuKey) { ModeMenuTitle(name: modeName, indicator: true).font(.body) }
            measured(Self.segmentedKey) {
                Picker("Zobrazení", selection: .constant(0)) {
                    Text("Den").tag(0)
                    Text("Týden").tag(1)
                    Text("Měsíc").tag(2)
                }
                .pickerStyle(.segmented)
            }
        }
        .dynamicTypeSize(...BarTitleText.largestSize)
        .hidden()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private func measured<Content: View>(_ key: String, @ViewBuilder _ content: () -> Content) -> some View {
        content()
            .fixedSize()
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { onMeasure(key, $0) }
    }
}

/// The period title as the iPad bar sets it: the inline title's type, growing only a little with
/// the text size, as the bar's own title does.
struct BarTitleText: View {
    static let largestSize = DynamicTypeSize.xxLarge
    let text: String

    var body: some View {
        Text(text)
            .font(.headline)
            .lineLimit(1)
            .fixedSize()
            .dynamicTypeSize(...Self.largestSize)
    }
}

#endif

/// The switcher's menu title: the current view and the up-down chevron of a pop-up menu, so it does not
/// read as an action like "Dnes" beside it. One text, since a bar draws a symbol-and-text pair as its
/// symbol alone. The full period title comes first: where both do not fit, the chevron gives way.
struct ModeMenuTitle: View {
    let name: LocalizedStringKey
    /// The chevron goes when the bar needs its width for the full period title.
    var indicator = true

    var body: some View {
        if indicator {
            Text("\(Text(name))\u{2009}\(Text(Image(systemName: "chevron.up.chevron.down")).font(.caption2.weight(.bold)))")
        } else {
            Text(name)
        }
    }
}
