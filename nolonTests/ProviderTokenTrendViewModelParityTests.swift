import Testing
import Foundation
import ProviderCatalog
import ProviderUsage
import NolonUIFoundation
@testable import nolon

@MainActor
struct ProviderTokenTrendViewModelParityTests {
    @Test("BDD: Given root and engine state when reading token trend state then values stay parity")
    func testBDD_GivenRootAndEngineState_WhenReadingTokenTrendState_ThenValuesStayParity() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)

        #expect(root.tokenTrendViewModel.tokenTrendRange == root.state.metricsEngine.tokenTrendRange)
        #expect(root.tokenTrendViewModel.tokenTrendSnapshot == root.state.metricsEngine.tokenTrendSnapshot)
        #expect(root.tokenTrendViewModel.tokenTrendCapability == root.state.metricsEngine.tokenTrendCapability)
        #expect(root.tokenTrendViewModel.selectedDayKey == root.state.metricsEngine.selectedTokenTrendDayKey)
        #expect(root.tokenTrendViewModel.intradayBucket == root.state.metricsEngine.intradayBucket)
        #expect(root.tokenTrendViewModel.intradaySnapshot == root.state.metricsEngine.intradaySnapshot)
    }

    @Test("BDD: Given persisted chart style when creating token trend view model then chart style restores from preferences")
    func testBDD_GivenPersistedChartStyle_WhenCreatingTokenTrendViewModel_ThenChartStyleRestoresFromPreferences() throws {
        let provider = Provider(
            id: "codex-\(UUID().uuidString)",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let suiteName = "ProviderTokenTrendViewModelParityTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let store = ProviderUsageTokenTrendPreferencesStore(providerID: provider.id, userDefaults: defaults)
        store.chartStyle = .line

        let engine = ProviderUsageEngine(provider: provider)
        let state = ProviderUsageStateStore(provider: provider, engine: engine)
        let viewModel = ProviderTokenTrendViewModel(state: state, preferencesStore: store)

        #expect(viewModel.chartStyle == .line)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test("BDD: Given selected day when toggling token trend drilldown then content tab follows selection")
    func testBDD_GivenSelectedDay_WhenTogglingTokenTrendDrilldown_ThenContentTabFollowsSelection() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)

        root.tokenTrendViewModel.selectDay("2026-04-22")
        #expect(root.tokenTrendViewModel.activeContentTab == .intraday)

        root.tokenTrendViewModel.selectDay(nil)
        #expect(root.tokenTrendViewModel.activeContentTab == .daily)
    }
}
