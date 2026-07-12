import Foundation

public struct ModelMetadata {
    public static let defaultModel = "parakeet-unified-en"

    public static let availableModels = [
        defaultModel,
        "tiny",
        "base",
        "small",
        "medium",
        "large-v3-v20240930_626MB",
        "large-v3"
    ]

    public static func displayName(for model: String) -> String {
        switch model {
        case defaultModel: return "Parakeet Unified English"
        case "tiny": return "Tiny"
        case "base": return "Base"
        case "small": return "Small"
        case "medium": return "Medium"
        case "large-v3-v20240930_626MB": return "Large v3 Optimized"
        case "large-v3": return "Large v3"
        default: return model.capitalized
        }
    }

    public static func description(for model: String) -> String {
        switch model {
        case defaultModel: return "Recommended • fastest accurate English dictation"
        case "tiny": return "Fastest • ~0.1s per 10s audio"
        case "base": return "Balanced • ~0.1s per 10s audio"
        case "small": return "Accurate • ~0.2s per 10s audio"
        case "medium": return "Very accurate • ~0.6s per 10s audio"
        case "large-v3-v20240930_626MB": return "Best accuracy • optimized for Apple Silicon"
        case "large-v3": return "Best accuracy • ~1.1s per 10s audio"
        default: return ""
        }
    }

    public static func estimatedSize(for model: String) -> String {
        switch model {
        case defaultModel: return "~565 MB"
        case "tiny": return "~75 MB"
        case "base": return "~145 MB"
        case "small": return "~480 MB"
        case "medium": return "~1.5 GB"
        case "large-v3-v20240930_626MB": return "~626 MB"
        case "large-v3": return "~3 GB"
        default: return "Unknown"
        }
    }

    public static func isValidModel(_ model: String) -> Bool {
        availableModels.contains(model)
    }
}
