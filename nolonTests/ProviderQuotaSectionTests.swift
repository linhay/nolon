import XCTest
import ProviderUsage
import CodexBarProviderCatalog
@testable import nolon

final class ProviderQuotaSectionTests: XCTestCase {
    func testBDD_GivenCodexDescriptorUsesResetsAtLabel_WhenCheckingStringCatalog_ThenUsageMetricResetsAtExists() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("nolon/Localizable.xcstrings")
        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: Any])

        XCTAssertNotNil(strings["usage.metric.resets_at"])
    }

    func testBDD_GivenExplicitWindows_WhenResolvingDisplayWindows_ThenPrefersWindowsOverLegacyFields() {
        let usage = UsageSnapshot(
            identity: nil,
            windows: [
                UsageWindow(
                    id: "gemini-2.5-pro",
                    title: "gemini-2.5-pro",
                    window: RateWindow(usedPercent: 12)
                ),
            ],
            primary: RateWindow(usedPercent: 30),
            secondary: RateWindow(usedPercent: 40),
            tertiary: nil,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let windows = ProviderQuotaSection.displayWindows(for: usage, provider: .gemini)

        XCTAssertEqual(windows.map(\.id), ["gemini-2.5-pro"])
        XCTAssertEqual(windows.first?.title, "gemini-2.5-pro")
        XCTAssertEqual(windows.first?.window.usedPercent, 12)
    }

    func testBDD_GivenLegacyWindows_WhenResolvingDisplayWindows_ThenFallsBackToProviderLabels() {
        let usage = UsageSnapshot(
            identity: nil,
            windows: [],
            primary: RateWindow(usedPercent: 10),
            secondary: RateWindow(usedPercent: 20),
            tertiary: RateWindow(usedPercent: 30),
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let windows = ProviderQuotaSection.displayWindows(for: usage, provider: .codex)

        XCTAssertEqual(windows.map(\.id), ["primary", "secondary", "tertiary"])
        XCTAssertEqual(windows.map(\.title), ["Session", "Weekly", "Other"])
    }
}
