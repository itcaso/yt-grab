// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "YT-Grab",
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "YT-Grab", targets: ["AudioGrab"])
    ],
    targets: [
        .executableTarget(
            name: "AudioGrab",
            path: "Sources/AudioGrab",
            exclude: ["Resources"],
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-strict-concurrency=minimal"])
            ]
        ),
        .testTarget(
            name: "AudioGrabTests",
            dependencies: ["AudioGrab"],
            path: "Tests/AudioGrabTests"
        )
    ]
)
