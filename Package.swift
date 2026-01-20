// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VoiceScribe",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "VoiceScribe", targets: ["VoiceScribe"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.8.0")
    ],
    targets: [
        .target(
            name: "VoiceScribeCore",
            path: "Sources/VoiceScribeCore"
        ),
        .executableTarget(
            name: "VoiceScribe",
            dependencies: ["WhisperKit", "VoiceScribeCore"],
            path: "Sources/VoiceScribe",
            resources: [
                .copy("../../Resources")
            ]
        ),
        .testTarget(
            name: "VoiceScribeTests",
            dependencies: ["VoiceScribeCore"],
            path: "Tests/VoiceScribeTests"
        )
    ]
)
