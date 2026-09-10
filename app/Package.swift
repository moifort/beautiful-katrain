// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "BeautifulKaTrain",
    platforms: [.macOS("26.0")],
    targets: [
        // The bulk of the app lives in a library so the tests can import it; the
        // executable is only the @main entry point.
        .target(name: "BeautifulKaTrainCore", path: "Sources/BeautifulKaTrainCore"),
        .executableTarget(
            name: "BeautifulKaTrain",
            dependencies: ["BeautifulKaTrainCore"],
            path: "Sources/BeautifulKaTrain"
        ),
        .testTarget(
            name: "BeautifulKaTrainCoreTests",
            dependencies: ["BeautifulKaTrainCore"],
            path: "Tests/BeautifulKaTrainCoreTests"
        ),
    ]
)
