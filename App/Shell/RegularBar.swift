import DaybookCore
import SwiftUI

#if os(iOS)
// The bar's decision (title form, switcher form, where the switcher goes) is `WideBarLayout` in DaybookCore,
// a pure function of the widths measured here and the detail column's horizontal extent.

/// Invisible copies of the bar's texts and switcher, measured in the bar's type at the current size.
struct RegularBarProbes: View {
    static let todayKey = WideBarLayout.todayKey
    static let referenceKey = WideBarLayout.referenceKey
    static let segmentedKey = WideBarLayout.segmentedKey
    static let modeNameKey = WideBarLayout.modeNameKey
    static let modeMenuKey = WideBarLayout.modeMenuKey

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
