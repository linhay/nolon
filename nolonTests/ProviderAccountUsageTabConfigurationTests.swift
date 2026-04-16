import XCTest
import ProviderCatalog
@testable import nolon

final class ProviderAccountUsageTabConfigurationTests: XCTestCase {
    @MainActor
    func testBDD_GivenCodexProvider_WhenResolvingAvailableTabs_ThenAccountsAppearsImmediatelyBeforeUsage() throws {
        let provider = ProviderTemplate.codex.createProvider()
        let tabs = ProviderContentTabType.availableTabs(for: provider)

        guard let accountsIndex = tabs.firstIndex(of: .accounts) else {
            return XCTFail("Expected codex tabs to include accounts: \(tabs)")
        }
        guard let usageIndex = tabs.firstIndex(of: .usage) else {
            return XCTFail("Expected codex tabs to include usage: \(tabs)")
        }

        XCTAssertEqual(accountsIndex + 1, usageIndex, "Expected accounts to appear immediately before usage, got: \(tabs)")
    }

    @MainActor
    func testBDD_GivenGeminiProvider_WhenResolvingAvailableTabs_ThenAccountsAppearsImmediatelyBeforeUsage() throws {
        let provider = ProviderTemplate.gemini.createProvider()
        let tabs = ProviderContentTabType.availableTabs(for: provider)

        guard let accountsIndex = tabs.firstIndex(of: .accounts) else {
            return XCTFail("Expected gemini tabs to include accounts: \(tabs)")
        }
        guard let usageIndex = tabs.firstIndex(of: .usage) else {
            return XCTFail("Expected gemini tabs to include usage: \(tabs)")
        }

        XCTAssertEqual(accountsIndex + 1, usageIndex, "Expected accounts to appear immediately before usage, got: \(tabs)")
    }

    @MainActor
    func testBDD_GivenClaudeProvider_WhenResolvingAvailableTabs_ThenAccountsAppearsImmediatelyBeforeUsage() throws {
        let provider = ProviderTemplate.claudeCode.createProvider()
        let tabs = ProviderContentTabType.availableTabs(for: provider)

        guard let accountsIndex = tabs.firstIndex(of: .accounts) else {
            return XCTFail("Expected claude tabs to include accounts: \(tabs)")
        }
        guard let usageIndex = tabs.firstIndex(of: .usage) else {
            return XCTFail("Expected claude tabs to include usage: \(tabs)")
        }

        XCTAssertEqual(accountsIndex + 1, usageIndex, "Expected accounts to appear immediately before usage, got: \(tabs)")
    }

    @MainActor
    func testBDD_GivenCopilotProvider_WhenResolvingAvailableTabs_ThenAccountsDoesNotAppear() throws {
        let provider = ProviderTemplate.copilot.createProvider()
        let tabs = ProviderContentTabType.availableTabs(for: provider)

        XCTAssertFalse(tabs.contains(.accounts), "Expected copilot tabs not to include accounts, got: \(tabs)")
        XCTAssertTrue(tabs.contains(.usage), "Expected copilot tabs to keep usage, got: \(tabs)")
    }

    @MainActor
    func testBDD_GivenCodexXcodeProvider_WhenResolvingAvailableTabs_ThenAccountsStillDoesNotAppear() throws {
        let provider = ProviderTemplate.codexXcode.createProvider()
        let tabs = ProviderContentTabType.availableTabs(for: provider)

        XCTAssertFalse(tabs.contains(.accounts), "Expected codexXcode tabs not to include accounts, got: \(tabs)")
    }
}
