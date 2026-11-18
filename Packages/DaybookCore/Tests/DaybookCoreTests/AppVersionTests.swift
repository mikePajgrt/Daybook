import Testing
@testable import DaybookCore

@Suite struct AppVersionTests {
    @Test func developmentBuildShowsVersionAndBuild() {
        let info: [String: Any] = ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "1", "DaybookCommit": ""]
        #expect(AppVersion.text(info: info) == "0.1.0 (1)")
    }

    @Test func releaseBuildAddsTheCommit() {
        let info: [String: Any] = ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "20261118.1045",
                                   "DaybookCommit": "1d21270"]
        #expect(AppVersion.text(info: info) == "0.1.0 (20261118.1045, 1d21270)")
        #expect(AppVersion.detail(info: info) == "20261118.1045, 1d21270")
    }

    @Test func missingValuesAreLeftOut() {
        #expect(AppVersion.text(info: ["CFBundleShortVersionString": "0.1.0"]) == "0.1.0")
        #expect(AppVersion.text(info: ["CFBundleShortVersionString": "0.1.0", "CFBundleVersion": "2",
                                       "DaybookCommit": "$(DAYBOOK_COMMIT)"]) == "0.1.0 (2)")
        #expect(AppVersion.text(info: [:]) == "")
    }
}
