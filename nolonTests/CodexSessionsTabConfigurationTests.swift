import XCTest
import ProviderCatalog
@testable import nolon

final class CodexSessionsTabConfigurationTests: XCTestCase {
    @MainActor
    func testBDD_GivenCodexProvider_WhenResolvingAvailableTabs_ThenSessionsAppearsAfterUsage() throws {
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "codex")).createProvider()
        let tabs = ProviderContentTabType.availableTabs(for: provider)

        guard let usageIndex = tabs.firstIndex(of: .usage) else {
            return XCTFail("Expected codex tabs to include usage: \(tabs)")
        }
        guard let sessionsIndex = tabs.firstIndex(of: .sessions) else {
            return XCTFail("Expected codex tabs to include sessions: \(tabs)")
        }

        XCTAssertEqual(sessionsIndex, usageIndex + 1, "Expected sessions to appear immediately after usage, got: \(tabs)")
    }

    @MainActor
    func testBDD_GivenCodexXcodeProvider_WhenResolvingAvailableTabs_ThenSessionsAppearsAfterBinary() throws {
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "codexXcode")).createProvider()
        let tabs = ProviderContentTabType.availableTabs(for: provider)

        guard let binaryIndex = tabs.firstIndex(of: .binary) else {
            return XCTFail("Expected codexXcode tabs to include binary: \(tabs)")
        }
        guard let sessionsIndex = tabs.firstIndex(of: .sessions) else {
            return XCTFail("Expected codexXcode tabs to include sessions: \(tabs)")
        }

        XCTAssertEqual(sessionsIndex, binaryIndex + 1, "Expected sessions to appear immediately after binary, got: \(tabs)")
    }
}
