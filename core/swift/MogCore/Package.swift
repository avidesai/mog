// swift-tools-version:5.9
import PackageDescription

// MogCore — Swift port of mog-core. Pure Foundation, no dependencies, no UI.
// Data files are copied in from ../../data and ../../fixtures by ./sync-data.sh
// so the package is self-contained inside the Xcode workspace.
//
// NOT COMPILED IN THE AUTHORING ENVIRONMENT (no Swift toolchain was available).
// First task in Xcode: `swift build && swift test`, and fix whatever the compiler
// says. The logic mirrors the Python module-for-module; the fixtures decide.

let package = Package(
    name: "MogCore",
    platforms: [.iOS(.v18), .macOS(.v14)],
    products: [.library(name: "MogCore", targets: ["MogCore"])],
    targets: [
        .target(name: "MogCore", resources: [.copy("Resources")]),
        .testTarget(name: "MogCoreTests", dependencies: ["MogCore"]),
    ]
)
