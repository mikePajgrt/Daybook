import Testing

/// Each CloudKit environment syncs into its own file; only Release builds in Production use the original
/// "Categories-cloud", which TestFlight installs already have.
@Suite struct CloudStoreNameTests {
    @Test func releaseProductionKeepsTheOriginalFile() {
        #expect(CategoryContainer.cloudStoreName(environment: "Production", debugBuild: false) == "Categories-cloud")
    }

    @Test func aDebugBuildInProductionHasItsOwnFile() {
        #expect(CategoryContainer.cloudStoreName(environment: "Production", debugBuild: true)
            == "Categories-cloud-production-debug")
    }

    @Test func developmentNeverSharesAFileWithProduction() {
        for debug in [false, true] {
            #expect(CategoryContainer.cloudStoreName(environment: "Development", debugBuild: debug)
                == "Categories-cloud-development")
        }
        // Anything but "Production" is Development.
        #expect(CategoryContainer.cloudStoreName(environment: "", debugBuild: true) == "Categories-cloud-development")
    }
}
