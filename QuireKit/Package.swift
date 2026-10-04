// swift-tools-version: 6.2
import PackageDescription

// The model, merging and compression shared by every Quire PDF app. Apps
// own only their UI; anything that decides what ends up in the merged file
// lives here, so the platforms cannot disagree about it.
let package = Package(
    name: "QuireKit",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "QuireKit", targets: ["QuireKit"]),
    ],
    targets: [
        .target(
            name: "QuireKit",
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
        .testTarget(
            name: "QuireKitTests",
            dependencies: ["QuireKit"],
            swiftSettings: [.defaultIsolation(MainActor.self)]
        ),
    ]
)
