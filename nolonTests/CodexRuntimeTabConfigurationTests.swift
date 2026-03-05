import XCTest
import ProviderCatalog
@testable import nolon

final class CodexRuntimeTabConfigurationTests: XCTestCase {
    func testBDD_GivenCodexTemplate_WhenReadingVendorTabs_ThenContainsRuntimeTab() throws {
        let template = try XCTUnwrap(ProviderTemplate(rawValue: "codex"))
        let tabs = template.config?.vendorTabs ?? []
        XCTAssertTrue(tabs.contains("runtime"), "Expected codex vendorTabs to include 'runtime', got: \(tabs)")
    }

    func testBDD_GivenCodexXcodeTemplate_WhenReadingVendorTabs_ThenContainsRuntimeTab() throws {
        let template = try XCTUnwrap(ProviderTemplate(rawValue: "codexXcode"))
        let tabs = template.config?.vendorTabs ?? []
        XCTAssertTrue(tabs.contains("runtime"), "Expected codexXcode vendorTabs to include 'runtime', got: \(tabs)")
    }

    @MainActor
    func testBDD_GivenCodexProvider_WhenResolvingAvailableTabs_ThenRuntimeAppearsAfterUsage() throws {
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "codex")).createProvider()
        let tabs = ProviderContentTabType.availableTabs(for: provider)

        guard let usageIndex = tabs.firstIndex(of: .usage) else {
            return XCTFail("Expected codex tabs to include usage: \(tabs)")
        }
        guard let runtimeIndex = tabs.firstIndex(of: .runtime) else {
            return XCTFail("Expected codex tabs to include runtime: \(tabs)")
        }
        XCTAssertEqual(runtimeIndex, usageIndex + 1, "Expected runtime to appear immediately after usage, got: \(tabs)")
    }

    @MainActor
    func testBDD_GivenCodexXcodeProvider_WhenResolvingAvailableTabs_ThenRuntimeAppearsAfterBinary() throws {
        let provider = try XCTUnwrap(ProviderTemplate(rawValue: "codexXcode")).createProvider()
        let tabs = ProviderContentTabType.availableTabs(for: provider)

        guard let binaryIndex = tabs.firstIndex(of: .binary) else {
            return XCTFail("Expected codexXcode tabs to include binary: \(tabs)")
        }
        guard let runtimeIndex = tabs.firstIndex(of: .runtime) else {
            return XCTFail("Expected codexXcode tabs to include runtime: \(tabs)")
        }
        XCTAssertEqual(runtimeIndex, binaryIndex + 1, "Expected runtime to appear immediately after binary, got: \(tabs)")
        XCTAssertFalse(tabs.contains(.usage), "codexXcode should not implicitly enable usage tab in this phase")
    }
}
