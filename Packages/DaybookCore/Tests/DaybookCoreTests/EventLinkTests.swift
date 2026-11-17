import Foundation
import Testing
@testable import DaybookCore

/// Event URLs come from other people's invitations: only web and mail links may be opened.
@Suite struct EventLinkTests {
    func openable(_ text: String) -> Bool {
        EventLink.isOpenable(URL(string: text)!)
    }

    @Test func webAndMailLinksOpen() {
        #expect(openable("http://example.com/a"))
        #expect(openable("HTTPS://Example.com/a"))
        #expect(openable("mailto:petra@example.com"))
        #expect(openable("MailTo:petra@example.com"))
    }

    @Test func everyOtherSchemeStaysText() {
        #expect(!openable("tel:+420123456789"))
        #expect(!openable("file:///etc/passwd"))
        #expect(!openable("javascript:alert(1)"))
        #expect(!openable("someapp://do-something"))
        #expect(!openable("example.com/no-scheme"))
    }
}
