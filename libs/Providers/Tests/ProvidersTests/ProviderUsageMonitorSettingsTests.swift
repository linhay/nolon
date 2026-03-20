import Foundation
import Testing
@testable import ProviderUsage

@Suite("ProviderUsageMonitorSettings")
struct ProviderUsageMonitorSettingsTests {
    @Test("Effective cost window prefers selected value")
    func effectiveCostWindowPrefersSelected() {
        let settings = ProviderUsageMonitorSettings(costWindowDays: 30)

        let window = settings.effectiveCostWindowDays(selected: 7)

        #expect(window == 7)
    }

    @Test("Effective cost window falls back to settings when selected nil")
    func effectiveCostWindowFallsBackToSettings() {
        let settings = ProviderUsageMonitorSettings(costWindowDays: 14)

        let window = settings.effectiveCostWindowDays(selected: nil)

        #expect(window == 14)
    }

    @Test("Decode legacy settings defaults codex list layout to card mode")
    func decodeLegacySettingsDefaultsCodexListLayoutToCardMode() throws {
        let json = #"{"sourceMode":"auto","includeCredits":false,"webTimeoutSeconds":30,"autoRefreshIntervalMinutes":0,"costWindowDays":30,"codexHideZeroQuotaAccounts":false}"#
        let data = Data(json.utf8)

        let decoded = try JSONDecoder().decode(ProviderUsageMonitorSettings.self, from: data)

        #expect(decoded.codexUseListLayout == false)
    }

    @Test("Codex list layout flag round-trips through Codable")
    func codexListLayoutFlagRoundTripsThroughCodable() throws {
        let settings = ProviderUsageMonitorSettings(codexUseListLayout: true)

        let encoded = try JSONEncoder().encode(settings)
        let decoded = try JSONDecoder().decode(ProviderUsageMonitorSettings.self, from: encoded)

        #expect(decoded.codexUseListLayout == true)
    }
}
