import XCTest
import ProviderCatalog

final class CodexBinaryTabConfigurationTests: XCTestCase {
    func testBDD_GivenCodexTemplate_WhenReadingVendorTabs_ThenContainsBinaryTab() throws {
        // Given
        let template = try XCTUnwrap(ProviderTemplate(rawValue: "codex"))
        let tabs = template.config?.vendorTabs ?? []

        // When / Then
        XCTAssertTrue(
            tabs.contains("binary"),
            "Expected codex vendorTabs to include 'binary', got: \(tabs)"
        )
    }

    func testBDD_GivenCodexXcodeTemplate_WhenReadingVendorTabs_ThenContainsBinaryTab() throws {
        // Given
        let template = try XCTUnwrap(ProviderTemplate(rawValue: "codexXcode"))
        let tabs = template.config?.vendorTabs ?? []

        // When / Then
        XCTAssertTrue(
            tabs.contains("binary"),
            "Expected codexXcode vendorTabs to include 'binary', got: \(tabs)"
        )
    }

    func testBDD_GivenNonCodexTemplate_WhenReadingVendorTabs_ThenDoesNotContainBinaryTab() throws {
        // Given
        let template = try XCTUnwrap(ProviderTemplate(rawValue: "copilot"))
        let tabs = template.config?.vendorTabs ?? []

        // When / Then
        XCTAssertFalse(
            tabs.contains("binary"),
            "Expected non-codex template not to include 'binary', got: \(tabs)"
        )
    }

}
