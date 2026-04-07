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
        XCTAssertFalse(tabs.contains(.agents), "Expected gemini tabs not to include agents")
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
        XCTAssertFalse(tabs.contains(.agents), "Expected antigravity tabs not to include agents")
    }

    func testBDD_GivenClaudeTemplate_WhenReadingVendorTabs_ThenContainsRulesWithoutAgents() throws {
        let template = try XCTUnwrap(ProviderTemplate(rawValue: "claudeCode"))
        let tabs = template.config?.vendorTabs ?? []
        XCTAssertTrue(tabs.contains("rules"), "Expected claude vendorTabs to include 'rules', got: \(tabs)")
        XCTAssertFalse(tabs.contains("agents"), "Expected claude vendorTabs not to include 'agents', got: \(tabs)")
    }

    @MainActor
    func testBDD_GivenClaudeTemplate_WhenReadingAvailableTabs_ThenContainsRulesWithoutAgents() throws {
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "claudeCode")).createProvider()
        let tabs = ProviderContentTabType.availableTabs(for: provider)
        XCTAssertTrue(tabs.contains(.rules), "Expected claude tabs to include rules")
        XCTAssertFalse(tabs.contains(.agents), "Expected claude tabs not to include agents")
    }

    @MainActor
    func testBDD_GivenPiTemplate_WhenReadingAvailableTabs_ThenDoesNotContainAgentsOrUsage() throws {
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "pi")).createProvider()
        let tabs = ProviderContentTabType.availableTabs(for: provider)
        XCTAssertFalse(tabs.contains(.agents), "Expected pi tabs not to include agents")
        XCTAssertFalse(tabs.contains(.usage), "Expected pi tabs not to include usage")
    }
}
