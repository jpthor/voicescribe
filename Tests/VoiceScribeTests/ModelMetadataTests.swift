import XCTest
@testable import VoiceScribeCore

final class ModelMetadataTests: XCTestCase {

    func testDefaultModelIsRecommendedEnglishModel() {
        XCTAssertEqual(ModelMetadata.defaultModel, "parakeet-unified-en")
        XCTAssertTrue(ModelMetadata.isValidModel(ModelMetadata.defaultModel))
    }

    func testAvailableModels() {
        let models = ModelMetadata.availableModels

        XCTAssertEqual(models.count, 7)
        XCTAssertEqual(models.first, ModelMetadata.defaultModel)
        XCTAssertTrue(models.contains("parakeet-unified-en"))
        XCTAssertTrue(models.contains("tiny"))
        XCTAssertTrue(models.contains("base"))
        XCTAssertTrue(models.contains("small"))
        XCTAssertTrue(models.contains("medium"))
        XCTAssertTrue(models.contains("large-v3-v20240930_626MB"))
        XCTAssertTrue(models.contains("large-v3"))
    }

    func testDisplayNames() {
        XCTAssertEqual(ModelMetadata.displayName(for: "parakeet-unified-en"), "Parakeet Unified English")
        XCTAssertEqual(ModelMetadata.displayName(for: "tiny"), "Tiny")
        XCTAssertEqual(ModelMetadata.displayName(for: "base"), "Base")
        XCTAssertEqual(ModelMetadata.displayName(for: "small"), "Small")
        XCTAssertEqual(ModelMetadata.displayName(for: "medium"), "Medium")
        XCTAssertEqual(ModelMetadata.displayName(for: "large-v3-v20240930_626MB"), "Large v3 Optimized")
        XCTAssertEqual(ModelMetadata.displayName(for: "large-v3"), "Large v3")
    }

    func testDisplayNameUnknownModel() {
        XCTAssertEqual(ModelMetadata.displayName(for: "unknown"), "Unknown")
        XCTAssertEqual(ModelMetadata.displayName(for: "custom-model"), "Custom-Model")
    }

    func testDescriptions() {
        XCTAssertTrue(ModelMetadata.description(for: "parakeet-unified-en").contains("Recommended"))
        XCTAssertTrue(ModelMetadata.description(for: "tiny").contains("Fastest"))
        XCTAssertTrue(ModelMetadata.description(for: "base").contains("Balanced"))
        XCTAssertTrue(ModelMetadata.description(for: "small").contains("Accurate"))
        XCTAssertTrue(ModelMetadata.description(for: "medium").contains("Very accurate"))
        XCTAssertTrue(ModelMetadata.description(for: "large-v3-v20240930_626MB").contains("Best accuracy"))
        XCTAssertTrue(ModelMetadata.description(for: "large-v3").contains("Best accuracy"))
    }

    func testDescriptionUnknownModel() {
        XCTAssertEqual(ModelMetadata.description(for: "unknown"), "")
    }

    func testEstimatedSizes() {
        XCTAssertEqual(ModelMetadata.estimatedSize(for: "parakeet-unified-en"), "~565 MB")
        XCTAssertEqual(ModelMetadata.estimatedSize(for: "tiny"), "~75 MB")
        XCTAssertEqual(ModelMetadata.estimatedSize(for: "base"), "~145 MB")
        XCTAssertEqual(ModelMetadata.estimatedSize(for: "small"), "~480 MB")
        XCTAssertEqual(ModelMetadata.estimatedSize(for: "medium"), "~1.5 GB")
        XCTAssertEqual(ModelMetadata.estimatedSize(for: "large-v3-v20240930_626MB"), "~626 MB")
        XCTAssertEqual(ModelMetadata.estimatedSize(for: "large-v3"), "~3 GB")
    }

    func testEstimatedSizeUnknownModel() {
        XCTAssertEqual(ModelMetadata.estimatedSize(for: "unknown"), "Unknown")
    }

    func testIsValidModel() {
        XCTAssertTrue(ModelMetadata.isValidModel("parakeet-unified-en"))
        XCTAssertTrue(ModelMetadata.isValidModel("tiny"))
        XCTAssertTrue(ModelMetadata.isValidModel("base"))
        XCTAssertTrue(ModelMetadata.isValidModel("small"))
        XCTAssertTrue(ModelMetadata.isValidModel("medium"))
        XCTAssertTrue(ModelMetadata.isValidModel("large-v3-v20240930_626MB"))
        XCTAssertTrue(ModelMetadata.isValidModel("large-v3"))

        XCTAssertFalse(ModelMetadata.isValidModel("unknown"))
        XCTAssertFalse(ModelMetadata.isValidModel(""))
        XCTAssertFalse(ModelMetadata.isValidModel("large"))
        XCTAssertFalse(ModelMetadata.isValidModel("TINY"))
    }

    func testModelSizesIncrease() {
        let sizes = ["tiny", "base", "small", "medium", "large-v3"]
        var previousSize = 0

        for model in sizes {
            let sizeStr = ModelMetadata.estimatedSize(for: model)
            let numericValue = extractNumericValue(from: sizeStr)
            XCTAssertGreaterThan(numericValue, previousSize, "Model \(model) should be larger than previous")
            previousSize = numericValue
        }
    }

    private func extractNumericValue(from sizeString: String) -> Int {
        let digits = sizeString.filter { $0.isNumber || $0 == "." }
        if let value = Double(digits) {
            if sizeString.contains("GB") {
                return Int(value * 1000)
            }
            return Int(value)
        }
        return 0
    }
}
