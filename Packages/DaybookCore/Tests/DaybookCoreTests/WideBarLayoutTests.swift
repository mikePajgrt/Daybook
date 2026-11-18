import Foundation
import Testing
@testable import DaybookCore

@Suite struct WideBarLayoutTests {
    /// Title forms from longest to shortest, as the bar offers them, with plausible widths.
    static let titles = ["Úterý 17. listopadu 2026", "Út 17. listopadu 2026", "Út 17. 11. 2026", "Út 17. 11.", "17. 11."]
    static let titleWidths: [Double] = [220, 190, 130, 90, 60]

    static func metrics(width: Double, minX: Double = 0, titleScale: Double = 1) -> WideBarMetrics {
        var texts: [String: Double] = [WideBarLayout.todayKey: 39.5, WideBarLayout.referenceKey: 39.5,
                                       WideBarLayout.segmentedKey: 190, WideBarLayout.modeNameKey: 48,
                                       WideBarLayout.modeMenuKey: 62]
        for (title, w) in zip(titles, titleWidths) { texts[title] = w * titleScale }
        return WideBarMetrics(detailMinX: minX, detailWidth: width, texts: texts)
    }

    /// Rank of a form: the segmented control, the menu with its chevron, the menu alone.
    static func formRank(_ c: WideBarChoice) -> Int { !c.pickerIsMenu ? 2 : (c.menuIndicator ? 1 : 0) }

    @Test func theDecisionIsAPureFunctionOfTheMeasurements() {
        for width in stride(from: 300.0, through: 1400, by: 7) {
            let m = Self.metrics(width: width, minX: 50)
            let a = WideBarLayout.choose(titles: Self.titles, filtering: true, railHidden: false, metrics: m)
            let b = WideBarLayout.choose(titles: Self.titles, filtering: true, railHidden: false, metrics: m)
            #expect(a == b)
        }
    }

    /// Wider never gives a shorter title or a smaller switcher, so resizing a window cannot flip between
    /// two forms at one width.
    @Test func widerNeverGivesLess() {
        for filtering in [false, true] {
            for railHidden in [false, true] {
                for scale in [0.8, 1.0, 1.4, 2.0] {
                    var previous: WideBarChoice?
                    for width in stride(from: 300.0, through: 1600, by: 3) {
                        let c = WideBarLayout.choose(titles: Self.titles, filtering: filtering, railHidden: railHidden,
                                                     metrics: Self.metrics(width: width, titleScale: scale))
                        if let p = previous {
                            let titleNow = Self.titles.firstIndex(of: c.title) ?? 99
                            let titleBefore = Self.titles.firstIndex(of: p.title) ?? 99
                            #expect(titleNow <= titleBefore, "width \(width): title got shorter")
                            if titleNow == titleBefore {
                                #expect(Self.formRank(c) >= Self.formRank(p), "width \(width): switcher got smaller")
                            }
                        }
                        previous = c
                    }
                }
            }
        }
    }

    /// The middle item's width comes from the choice alone, and the switcher lands inside it.
    @Test func theItemIsSizedByTheChoiceAndHoldsTheSwitcher() {
        for width in stride(from: 400.0, through: 1400, by: 11) {
            let c = WideBarLayout.choose(titles: Self.titles, filtering: false, railHidden: true,
                                         metrics: Self.metrics(width: width))
            guard let slotMinX = c.slotMinX, let slotWidth = c.slotWidth, let picker = c.pickerMinX,
                  let pickerWidth = c.pickerWidth else { continue }
            #expect(picker >= slotMinX - 1 && picker + pickerWidth <= slotMinX + slotWidth + 1, "width \(width)")
        }
    }

    /// Where the bar puts the middle item depends on the item's width, differently per platform: iPad
    /// keeps it after the leading items, a bar that centres its middle item (an iPad app on the Mac) moves
    /// it as it widens. The old code padded the item by the distance to its measured position, so the
    /// item's width depended on that position and the loop could run forever. Now the item's width is
    /// fixed and the measured position only moves the switcher inside it: one pass settles.
    @Test func layoutSettlesInOnePassWhateverTheBarDoes() {
        typealias Placement = (_ itemWidth: Double, _ leadingEnd: Double, _ trailingStart: Double, _ barMid: Double) -> Double
        let pinned: Placement = { _, leadingEnd, _, _ in leadingEnd }
        let centring: Placement = { w, leadingEnd, trailingStart, mid in
            let centred = (mid - w / 2).rounded()
            return centred >= leadingEnd && centred + w <= trailingStart ? centred : leadingEnd
        }
        for placement in [pinned, centring] {
            for width in stride(from: 500.0, through: 1400, by: 13) {
                for leadingError in [-30.0, 0, 25] {
                    let m = Self.metrics(width: width)
                    let c = WideBarLayout.choose(titles: Self.titles, filtering: false, railHidden: true, metrics: m)
                    guard let slotMinX = c.slotMinX, let slotWidth = c.slotWidth else { continue }
                    // The real bar's leading end differs from the model's by `leadingError` (other metrics).
                    let leadingEnd = slotMinX + leadingError
                    var offsets: [Double] = []
                    var itemMinX = 0.0
                    for _ in 0..<4 {
                        // The item's width does not depend on the offset: it is the slot.
                        itemMinX = placement(slotWidth, leadingEnd, width - 100, width / 2)
                        offsets.append(WideBarLayout.innerOffset(for: c, itemMinX: itemMinX))
                    }
                    #expect(Set(offsets).count == 1, "width \(width): offsets \(offsets)")
                    #expect(offsets[0] >= 0 && offsets[0] <= slotWidth)
                }
            }
        }
    }

    @Test func beforeMeasuringTheShortestTitleAndTheMenu() {
        let c = WideBarLayout.choose(titles: Self.titles, filtering: false, railHidden: false, metrics: WideBarMetrics())
        #expect(c.title == "17. 11.")
        #expect(c.pickerIsMenu)
        #expect(c.slotWidth == nil)
        #expect(WideBarLayout.innerOffset(for: c, itemMinX: 300) == 0)
    }
}
