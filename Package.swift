// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "VoiceScribe",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "VoiceScribe", targets: ["VoiceScribe"]),
        .executable(name: "parakeet-smoke", targets: ["ParakeetSmoke"]),
        .executable(name: "whisper-benchmark", targets: ["WhisperBenchmark"])
    ],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio.git", exact: "0.15.5"),
        .package(url: "https://github.com/argmaxinc/WhisperKit.git", exact: "0.18.0"),
        .package(
            url: "https://github.com/exPHAT/SwiftWhisper.git",
            revision: "c340197966ebd264f3135d3955874b40f8ed58bc"
        )
    ],
    targets: [
        .target(
            name: "VoiceScribeCore",
            path: "Sources/VoiceScribeCore"
        ),
        .executableTarget(
            name: "VoiceScribe",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
                "WhisperKit",
                "SwiftWhisper",
                "VoiceScribeCore"
            ],
            path: "Sources/VoiceScribe",
            resources: [
                .copy("../../Resources")
            ]
        ),
        .executableTarget(
            name: "ParakeetSmoke",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio")
            ],
            path: "Sources/ParakeetSmoke"
        ),
        .executableTarget(
            name: "WhisperBenchmark",
            dependencies: ["WhisperKit"],
            path: "Sources/WhisperBenchmark"
        ),
        .testTarget(
            name: "VoiceScribeTests",
            dependencies: ["VoiceScribeCore"],
            path: "Tests/VoiceScribeTests"
        )
    ]
)
