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
}
