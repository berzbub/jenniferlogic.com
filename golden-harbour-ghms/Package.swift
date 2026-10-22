// swift-tools-version:5.9
import PackageDescription

// Tests the framework-free clinical logic. Run: swift test
let package = Package(
    name: "GHMSLogic",
    products: [.library(name: "GHMSLogic", targets: ["GHMSLogic"])],
    targets: [
        .target(name: "GHMSLogic", path: "GHMS/Logic"),
        .testTarget(name: "GHMSLogicTests", dependencies: ["GHMSLogic"], path: "Tests/GHMSLogicTests")
    ]
)
