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

    @Test("BDD: Given line chart style when switching between daily and intraday tabs then chart style stays unchanged")
    func testBDD_GivenLineChartStyle_WhenSwitchingBetweenDailyAndIntradayTabs_ThenChartStyleStaysUnchanged() {
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

        root.tokenTrendViewModel.setChartStyle(.line)
        root.tokenTrendViewModel.selectDay("2026-04-22")

        #expect(root.tokenTrendViewModel.activeContentTab == .intraday)
        #expect(root.tokenTrendViewModel.chartStyle == .line)

        root.tokenTrendViewModel.setContentTab(.daily)
        #expect(root.tokenTrendViewModel.activeContentTab == .daily)
        #expect(root.tokenTrendViewModel.chartStyle == .line)

        root.tokenTrendViewModel.setContentTab(.intraday)
        #expect(root.tokenTrendViewModel.activeContentTab == .intraday)
        #expect(root.tokenTrendViewModel.chartStyle == .line)
    }

    @Test("BDD: Given different providers when reading intraday buckets then exposed options follow provider precision")
    func testBDD_GivenDifferentProviders_WhenReadingIntradayBuckets_ThenOptionsFollowProviderPrecision() {
        let codexProvider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let geminiProvider = Provider(
            id: "gemini",
            kind: .vendor,
            name: "Gemini",
            defaultSkillsPath: "/tmp/gemini/skills",
            workflowPath: "/tmp/gemini/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.gemini.rawValue
        )

        let codexRoot = ProviderUsageRootViewModel(provider: codexProvider)
        let geminiRoot = ProviderUsageRootViewModel(provider: geminiProvider)

        #expect(codexRoot.tokenTrendViewModel.availableIntradayBuckets == [.minute1, .minute5, .minute10, .minute15, .minute30, .hour1])
        #expect(geminiRoot.tokenTrendViewModel.availableIntradayBuckets == [.minute1, .minute5, .minute10, .minute15, .minute30, .hour1])
    }

    @Test("BDD: Given metric mode switch when toggling token trend metric then view model exposes the selected mode")
    func testBDD_GivenMetricModeSwitch_WhenTogglingTokenTrendMetric_ThenViewModelExposesSelectedMode() throws {
        let provider = Provider(
            id: "codex-\(UUID().uuidString)",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let suiteName = "ProviderTokenTrendViewModelParityTests.metricMode.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        let store = ProviderUsageTokenTrendPreferencesStore(providerID: provider.id, userDefaults: defaults)

        let engine = ProviderUsageEngine(provider: provider)
        let state = ProviderUsageStateStore(provider: provider, engine: engine)
        let viewModel = ProviderTokenTrendViewModel(state: state, preferencesStore: store)

        #expect(viewModel.metricMode == .tokens)

        viewModel.setMetricMode(.requests)
        #expect(viewModel.metricMode == .requests)
        #expect(store.metricMode == .requests)

        defaults.removePersistentDomain(forName: suiteName)
    }
}
