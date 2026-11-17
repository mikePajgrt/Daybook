// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "DaybookCore",
    platforms: [.iOS(.v18), .macOS(.v15)],
    products: [
        .library(name: "DaybookCore", targets: ["DaybookCore"])
    ],
    targets: [
        .target(name: "DaybookCore"),
        .testTarget(name: "DaybookCoreTests", dependencies: ["DaybookCore"])
    ],
    swiftLanguageModes: [.v5]
)
