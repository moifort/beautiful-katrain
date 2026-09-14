// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "Moyo",
    platforms: [.macOS("26.0")],
    targets: [
        // The bulk of the app lives in a library so the tests can import it; the
        // executable is only the @main entry point.
        .target(name: "MoyoCore", path: "Sources/MoyoCore"),
        .executableTarget(
            name: "Moyo",
            dependencies: ["MoyoCore"],
            path: "Sources/Moyo"
        ),
        .testTarget(
            name: "MoyoCoreTests",
            dependencies: ["MoyoCore"],
            path: "Tests/MoyoCoreTests"
        ),
    ]
)
