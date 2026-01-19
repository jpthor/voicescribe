// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VoiceScribe",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VoiceScribe", targets: ["VoiceScribe"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", from: "0.8.0")
    ],
    targets: [
        .executableTarget(
            name: "VoiceScribe",
            dependencies: ["WhisperKit"],
            path: "Sources/VoiceScribe",
            resources: [
                .copy("../../Resources")
            ]
        )
    ]
)
