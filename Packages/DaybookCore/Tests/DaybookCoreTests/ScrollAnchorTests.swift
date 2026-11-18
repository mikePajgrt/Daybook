import Testing
@testable import DaybookCore

@Suite struct ScrollAnchorTests {
    @Test func everyNewLayoutScrollsBackToTheAnchor() {
        var anchor = ScrollAnchor<Int>()
        anchor.anchor(on: 7)
        #expect(anchor.layoutChanged(1) == 7)      // rows laid out without events
        #expect(anchor.layoutChanged(1) == nil)    // nothing changed
        #expect(anchor.layoutChanged(2) == 7)      // events arrived, rows grew
        #expect(anchor.layoutChanged(3) == 7)      // a calendar switched in, the window resized
    }

    @Test func theUserTakingOverReleasesIt() {
        var anchor = ScrollAnchor<Int>()
        anchor.anchor(on: 7)
        anchor.release()
        #expect(anchor.target == nil)
        #expect(anchor.layoutChanged(5) == nil)
        #expect(anchor.reported(top: 3) == nil)
        // "Dnes" anchors again.
        anchor.anchor(on: 7)
        #expect(anchor.layoutChanged(6) == 7)
    }

    @Test func driftIsCorrectedAFewTimesPerLayoutOnly() {
        var anchor = ScrollAnchor<Int>()
        anchor.anchor(on: 7)
        _ = anchor.layoutChanged(1)
        #expect(anchor.reported(top: 7) == nil)    // where it should be
        #expect(anchor.reported(top: nil) == nil)  // the view's own reset while scrolling
        let corrections = (0..<10).compactMap { _ in anchor.reported(top: 2) }
        #expect(corrections.count == ScrollAnchor<Int>.correctionsPerLayout)
        // A new layout may need corrections again.
        _ = anchor.layoutChanged(2)
        #expect(anchor.reported(top: 2) == 7)
    }

    @Test func noAnchorNoScroll() {
        var anchor = ScrollAnchor<Int>()
        anchor.anchor(on: nil)
        #expect(anchor.layoutChanged(1) == nil)
        #expect(anchor.reported(top: 4) == nil)
    }
}
