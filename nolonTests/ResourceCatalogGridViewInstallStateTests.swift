import XCTest
@testable import nolon

final class ResourceCatalogGridViewInstallStateTests: XCTestCase {
    func testApplyInstallFailure_RemovesPendingAndStoresErrorMessage() {
        let error = NSError(
            domain: "ResourceCatalogGridViewInstallStateTests",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "SKILL.md not found in 'scale'"]
        )

        let result = ResourceCatalogGridView.applyInstallFailure(
            slug: "scale",
            pending: ["scale", "other"],
            errors: [:],
            error: error
        )

        XCTAssertFalse(result.pending.contains("scale"))
        XCTAssertTrue(result.pending.contains("other"))
        XCTAssertEqual(result.errors["scale"], "SKILL.md not found in 'scale'")
    }

    func testInstallFailureMessage_FallsBackToRetryHintWhenErrorDescriptionIsEmpty() {
        let error = NSError(domain: "ResourceCatalogGridViewInstallStateTests", code: 2)

        let message = ResourceCatalogGridView.installFailureMessage(for: error)

        XCTAssertEqual(message, "Install timed out. Click Retry.")
    }
}
