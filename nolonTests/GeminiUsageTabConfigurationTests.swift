import XCTest
import ProviderCatalog
@testable import nolon

final class GeminiUsageTabConfigurationTests: XCTestCase {
    func testBDD_GivenGeminiTemplate_WhenReadingVendorTabs_ThenContainsUsageTab() throws {
        let template = try XCTUnwrap(ProviderTemplate(rawValue: "gemini"))
        let tabs = template.config?.vendorTabs ?? []
        XCTAssertTrue(tabs.contains("usage"), "Expected gemini vendorTabs to include 'usage', got: \(tabs)")
    }

    @MainActor
    func testBDD_GivenGeminiTemplate_WhenReadingAvailableTabs_ThenContainsUsage() throws {
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "gemini")).createProvider()
        let tabs = ProviderContentTabType.availableTabs(for: provider)
        XCTAssertTrue(tabs.contains(.usage), "Expected gemini tabs to include usage")
    }

    func testBDD_GivenAntigravityTemplate_WhenReadingVendorTabs_ThenContainsUsageTab() throws {
        let template = try XCTUnwrap(ProviderTemplate(rawValue: "antigravity"))
        let tabs = template.config?.vendorTabs ?? []
        XCTAssertTrue(tabs.contains("usage"), "Expected antigravity vendorTabs to include 'usage', got: \(tabs)")
    }

    @MainActor
    func testBDD_GivenAntigravityTemplate_WhenReadingAvailableTabs_ThenContainsUsage() throws {
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "antigravity")).createProvider()
        let tabs = ProviderContentTabType.availableTabs(for: provider)
        XCTAssertTrue(tabs.contains(.usage), "Expected antigravity tabs to include usage")
    }
}
