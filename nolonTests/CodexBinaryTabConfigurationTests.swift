import XCTest
import ProviderCatalog
@testable import nolon

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
        XCTAssertTrue(
            tabs.contains("rules"),
            "Expected codex vendorTabs to include 'rules', got: \(tabs)"
        )
        XCTAssertTrue(
            tabs.contains("agents"),
            "Expected codex vendorTabs to include 'agents', got: \(tabs)"
        )
    }

    @MainActor
    func testBDD_GivenCodexTemplate_WhenReadingAvailableTabs_ThenContainsAdvancedAndBinary() throws {
        // Given
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "codex")).createProvider()

        // When
        let tabs = ProviderContentTabType.availableTabs(for: provider)

        // Then
        XCTAssertTrue(tabs.contains(.binary), "Expected codex tabs to include binary")
        XCTAssertTrue(tabs.contains(.advanced), "Expected codex tabs to include advanced")
        XCTAssertTrue(tabs.contains(.rules), "Expected codex tabs to include rules")
        XCTAssertTrue(tabs.contains(.agents), "Expected codex tabs to include agents")
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
        XCTAssertTrue(
            tabs.contains("rules"),
            "Expected codexXcode vendorTabs to include 'rules', got: \(tabs)"
        )
        XCTAssertTrue(
            tabs.contains("agents"),
            "Expected codexXcode vendorTabs to include 'agents', got: \(tabs)"
        )
    }

    @MainActor
    func testBDD_GivenCodexXcodeTemplate_WhenReadingAvailableTabs_ThenContainsAdvancedAndBinary() throws {
        // Given
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "codexXcode")).createProvider()

        // When
        let tabs = ProviderContentTabType.availableTabs(for: provider)

        // Then
        XCTAssertTrue(tabs.contains(.binary), "Expected codexXcode tabs to include binary")
        XCTAssertTrue(tabs.contains(.advanced), "Expected codexXcode tabs to include advanced")
        XCTAssertTrue(tabs.contains(.rules), "Expected codexXcode tabs to include rules")
        XCTAssertTrue(tabs.contains(.agents), "Expected codexXcode tabs to include agents")
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

    @MainActor
    func testBDD_GivenNonCodexTemplate_WhenReadingAvailableTabs_ThenDoesNotContainAdvancedTab() throws {
        // Given
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "copilot")).createProvider()

        // When
        let tabs = ProviderContentTabType.availableTabs(for: provider)

        // Then
        XCTAssertFalse(tabs.contains(.advanced), "Expected non-codex tabs not to include advanced")
        XCTAssertFalse(tabs.contains(.rules), "Expected non-codex tabs not to include rules")
        XCTAssertFalse(tabs.contains(.agents), "Expected non-codex tabs not to include agents")
    }

}
