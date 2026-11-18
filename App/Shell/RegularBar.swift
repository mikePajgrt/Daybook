#if os(iOS)
import SwiftUI

/// What the iPad bar shows: the period title (always), the filter indicator, the view switcher and
/// the new-event button, in the widest forms that fit together.
struct RegularBarChoice: Hashable {
    enum Indicator: Hashable {
        /// Nothing is hidden.
        case none
        /// The filter symbol and how many things are hidden.
        case symbolAndCount
        /// The filter symbol alone.
        case symbol
    }

    var title: String
    var pickerIsMenu: Bool
    var indicator: Indicator
    /// "Událost" beside the plus.
    var newEventWord: Bool
}

/// Widths measured on screen: the detail column and the bar's texts and switcher, set invisibly in
/// the bar's own type (`RegularBarProbes`). Positions inside the bar are not measured: they move while
/// the bar animates its items, and a reading taken mid-animation would choose the wrong forms.
struct RegularBarMetrics: Equatable {
    /// The detail column, in global coordinates.
    var detail: CGRect = .zero
    /// Probe widths, keyed by `RegularBarProbes` keys and title candidates.
    var texts: [String: CGFloat] = [:]

    func width(_ key: String) -> CGFloat? { texts[key] }
}

enum RegularBarLayout {
    /// The bar's own geometry on iPadOS 26 at the default text size, measured on screen:
    /// where the title starts beside the rail, and after the sidebar button when the rail is hidden;
    /// the glass group's leading inset plus back and forward (the "Dnes" text is measured); the menu
    /// switcher's padding around its label; search, the plus and the bar's margin right of the switcher;
    /// and the least gap the bar leaves between the title and the group. With less than that gap
    /// (14 pt overflowed, 18 pt did not) it moves the switcher or the plus into its overflow menu.
    static let titleInsetBesideRail: CGFloat = 24
    static let titleInsetAfterSidebarButton: CGFloat = 70
    static let groupLeadingWithoutToday: CGFloat = 136
    static let menuPadding: CGFloat = 33
    static let rightOfPicker: CGFloat = 175
    /// The fixed word "Dnes" at the default text size, against which the bar's growth is measured.
    static let referenceAtDefaultSize: CGFloat = 39.5
    static let groupGap: CGFloat = 18
    static let wordGap: CGFloat = 6
    /// With the filter symbol in the title's item the bar wants more room before the group
    /// (23 pt overflowed, 26 pt did not).
    static let groupGapWithIndicator: CGFloat = 28
    /// The filter symbol sits in the title's item: the space before it and its inset each side.
    static let indicatorSpacing: CGFloat = 4
    static let indicatorInset: CGFloat = 4

    /// The first arrangement that fits, in order of what matters: the longest title, then the
    /// segmented switcher, then the filter count, then the word beside the plus.
    static func choose(titles: [String], filtering: Bool, railHidden: Bool, metrics m: RegularBarMetrics) -> RegularBarChoice {
        // The smallest arrangement, also shown until everything is measured.
        // Before the texts are measured, the last form, which is the shortest.
        let shortest = titles.allSatisfy({ m.width($0) != nil })
            ? titles.min { (m.width($0) ?? 0) < (m.width($1) ?? 0) } : titles.last
        let fallback = RegularBarChoice(title: shortest ?? titles.last ?? "", pickerIsMenu: true,
                                        indicator: filtering ? .symbol : .none, newEventWord: false)
        guard m.detail.width > 0,
              let today = m.width(RegularBarProbes.todayKey), let word = m.width(RegularBarProbes.wordKey),
              let segmented = m.width(RegularBarProbes.segmentedKey),
              let menuLabel = m.width(RegularBarProbes.modeNameKey),
              let reference = m.width(RegularBarProbes.referenceKey),
              let symbol = m.width(RegularBarProbes.symbolKey), let count = m.width(RegularBarProbes.countKey)
        else { return fallback }
        // The bar's buttons grow with the text a little (up to its own limit); its spacing grows with them.
        // Measured on one fixed word, so a longer word in another language is not taken for larger text.
        let scale = max(1, reference / referenceAtDefaultSize)
        let menu = menuLabel + menuPadding * scale
        let start = m.detail.minX + (railHidden ? titleInsetAfterSidebarButton : titleInsetBesideRail)
        let indicators: [RegularBarChoice.Indicator] = filtering ? [.symbolAndCount, .symbol] : [.none]
        // The forms say the same period; the longest that fits wins.
        let measured = titles.compactMap { title in m.width(title).map { (title, $0) } }.sorted { $0.1 > $1.1 }
        for (title, titleWidth) in measured {
            for isMenu in [false, true] {
                for indicator in indicators {
                    for showsWord in [false] {
                        var x = start + titleWidth
                        switch indicator {
                        case .none: break
                        case .symbol: x += indicatorSpacing + symbol + 2 * indicatorInset
                        case .symbolAndCount: x += indicatorSpacing + count + 2 * indicatorInset
                        }
                        x += (indicator == .none ? groupGap : groupGapWithIndicator) + groupLeadingWithoutToday * scale
                            + today + (isMenu ? menu : segmented) + rightOfPicker * scale
                        if showsWord { x += word + wordGap }
                        if x <= m.detail.maxX {
                            return RegularBarChoice(title: title, pickerIsMenu: isMenu, indicator: indicator,
                                                    newEventWord: showsWord)
                        }
                    }
                }
            }
        }
        return fallback
    }
}

/// Invisible copies of the bar's texts and switcher, measured in the bar's type at the current size.
struct RegularBarProbes: View {
    static let todayKey = "\u{1}today"
    static let referenceKey = "\u{1}reference"
    static let wordKey = "\u{1}word"
    static let segmentedKey = "\u{1}segmented"
    static let modeNameKey = "\u{1}mode"
    static let symbolKey = "\u{1}symbol"
    static let countKey = "\u{1}count"

    let titles: [String]
    let modeName: LocalizedStringKey
    let hiddenCount: Int
    let onMeasure: (String, CGFloat) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(titles, id: \.self) { title in
                measured(title) { BarTitleText(text: title) }
            }
            measured(Self.todayKey) { Text("Dnes").font(.body) }
            measured(Self.referenceKey) { Text(verbatim: "Dnes").font(.body) }
            measured(Self.wordKey) { Text("Událost").font(.body) }
            measured(Self.modeNameKey) { Text(modeName).font(.body) }
            measured(Self.symbolKey) { FilterIndicatorLabel(count: nil) }
            measured(Self.countKey) { FilterIndicatorLabel(count: hiddenCount) }
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

/// The filter symbol, with how many things are hidden when there is room.
struct FilterIndicatorLabel: View {
    let count: Int?

    var body: some View {
        // One text with the symbol inside it: a bar draws a symbol-and-text pair as its symbol alone.
        let symbol = Text(Image(systemName: "line.3.horizontal.decrease.circle.fill"))
        Group {
            if let count {
                Text("\(symbol) \(Text(count, format: .number).monospacedDigit())")
            } else {
                symbol
            }
        }
        .font(.body)
        .fixedSize()
    }
}
#endif
