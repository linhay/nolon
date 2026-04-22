import Testing
import Foundation
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import NolonUIFoundation
@testable import nolon

@MainActor
struct ProviderUsageRootLoadBoundaryTests {
    @Test("BDD: Given root usage page when loading accounts if needed then usage metrics stays idle")
    func testBDD_GivenRootUsagePage_WhenLoadingAccountsIfNeeded_ThenUsageMetricsStaysIdle() async {
        let provider = makeProvider(templateId: ProviderTemplate.gemini.rawValue)
        let accounts = MockAccountsEngine()
        let metrics = MockMetricsEngine()
        let root = ProviderUsageRootViewModel(
            state: ProviderUsageStateStore(
                provider: provider,
                engine: MockAnyUsageEngine(
                    provider: provider,
                    usageProvider: .gemini,
                    accounts: accounts,
                    metrics: metrics
                )
            )
        )

        let didLoad = await root.loadAccountsIfNeeded()

        #expect(didLoad)
        #expect(accounts.loadIfNeededCallCount == 1)
        #expect(metrics.loadUsageIfNeededCallCount == 0)
    }

    @Test("BDD: Given root usage page when loading usage if needed then accounts stays idle")
    func testBDD_GivenRootUsagePage_WhenLoadingUsageIfNeeded_ThenAccountsStaysIdle() async {
        let provider = makeProvider(templateId: ProviderTemplate.gemini.rawValue)
        let accounts = MockAccountsEngine()
        let metrics = MockMetricsEngine()
        let root = ProviderUsageRootViewModel(
            state: ProviderUsageStateStore(
                provider: provider,
                engine: MockAnyUsageEngine(
                    provider: provider,
                    usageProvider: .gemini,
                    accounts: accounts,
                    metrics: metrics
                )
            )
        )

        let didLoad = await root.loadUsageIfNeeded()

        #expect(didLoad)
        #expect(accounts.loadIfNeededCallCount == 0)
        #expect(metrics.loadUsageIfNeededCallCount == 1)
    }

    @Test("BDD: Given root usage page when loading whole page if needed then accounts and usage each run once")
    func testBDD_GivenRootUsagePage_WhenLoadingWholePageIfNeeded_ThenAccountsAndUsageEachRunOnce() async {
        let provider = makeProvider(templateId: ProviderTemplate.gemini.rawValue)
        let accounts = MockAccountsEngine()
        let metrics = MockMetricsEngine()
        let root = ProviderUsageRootViewModel(
            state: ProviderUsageStateStore(
                provider: provider,
                engine: MockAnyUsageEngine(
                    provider: provider,
                    usageProvider: .gemini,
                    accounts: accounts,
                    metrics: metrics
                )
            )
        )

        let firstDidLoad = await root.loadPageIfNeeded()
        let secondDidLoad = await root.loadPageIfNeeded()

        #expect(firstDidLoad)
        #expect(!secondDidLoad)
        #expect(accounts.loadIfNeededCallCount == 2)
        #expect(metrics.loadUsageIfNeededCallCount == 2)
    }

    @Test("BDD: Given accounts page mode when loading if needed then only accounts engine runs")
    func testBDD_GivenAccountsPageMode_WhenLoadingIfNeeded_ThenOnlyAccountsEngineRuns() async {
        let provider = makeProvider(templateId: ProviderTemplate.gemini.rawValue)
        let accounts = MockAccountsEngine()
        let metrics = MockMetricsEngine()
        let root = ProviderUsageRootViewModel(
            state: ProviderUsageStateStore(
                provider: provider,
                engine: MockAnyUsageEngine(
                    provider: provider,
                    usageProvider: .gemini,
                    accounts: accounts,
                    metrics: metrics
                )
            )
        )

        let didLoad = await root.loadIfNeeded(for: .accounts)

        #expect(didLoad)
        #expect(accounts.loadIfNeededCallCount == 1)
        #expect(metrics.loadUsageIfNeededCallCount == 0)
    }

    @Test("BDD: Given usage page mode when loading if needed then only usage engine runs")
    func testBDD_GivenUsagePageMode_WhenLoadingIfNeeded_ThenOnlyUsageEngineRuns() async {
        let provider = makeProvider(templateId: ProviderTemplate.gemini.rawValue)
        let accounts = MockAccountsEngine()
        let metrics = MockMetricsEngine()
        let root = ProviderUsageRootViewModel(
            state: ProviderUsageStateStore(
                provider: provider,
                engine: MockAnyUsageEngine(
                    provider: provider,
                    usageProvider: .gemini,
                    accounts: accounts,
                    metrics: metrics
                )
            )
        )

        let didLoad = await root.loadIfNeeded(for: .usage)

        #expect(didLoad)
        #expect(accounts.loadIfNeededCallCount == 0)
        #expect(metrics.loadUsageIfNeededCallCount == 1)
    }

    @Test("BDD: Given combined page mode when loading if needed then accounts and usage both run")
    func testBDD_GivenCombinedPageMode_WhenLoadingIfNeeded_ThenAccountsAndUsageBothRun() async {
        let provider = makeProvider(templateId: ProviderTemplate.gemini.rawValue)
        let accounts = MockAccountsEngine()
        let metrics = MockMetricsEngine()
        let root = ProviderUsageRootViewModel(
            state: ProviderUsageStateStore(
                provider: provider,
                engine: MockAnyUsageEngine(
                    provider: provider,
                    usageProvider: .gemini,
                    accounts: accounts,
                    metrics: metrics
                )
            )
        )

        let didLoad = await root.loadIfNeeded(for: .combined)

        #expect(didLoad)
        #expect(accounts.loadIfNeededCallCount == 1)
        #expect(metrics.loadUsageIfNeededCallCount == 1)
    }

    private func makeProvider(templateId: String) -> Provider {
        Provider(
            id: "provider-\(UUID().uuidString)",
            kind: .vendor,
            name: "Provider",
            defaultSkillsPath: "/tmp/provider/skills",
            workflowPath: "/tmp/provider/prompts",
            vendorCategory: .original,
            templateId: templateId
        )
    }
}

@MainActor
private final class MockAnyUsageEngine: AnyUsageEngine {
    let provider: Provider
    let usageProvider: UsageProvider?
    let accounts: any ProviderUsageAccountsEngineProtocol
    let metrics: any ProviderUsageMetricsEngineProtocol
    let codex: any ProviderUsageCodexEngineProtocol
    let claude: any ProviderUsageClaudeEngineProtocol
    let gemini: any ProviderUsageGeminiEngineProtocol

    init(
        provider: Provider,
        usageProvider: UsageProvider?,
        accounts: any ProviderUsageAccountsEngineProtocol,
        metrics: any ProviderUsageMetricsEngineProtocol
    ) {
        let backing = ProviderUsageEngine(provider: provider)
        self.provider = provider
        self.usageProvider = usageProvider
        self.accounts = accounts
        self.metrics = metrics
        self.codex = backing
        self.claude = backing
        self.gemini = backing
    }
}

@MainActor
private final class MockAccountsEngine: ProviderUsageAccountsEngineProtocol {
    var outcomes: [ProviderAccountUsageOutcome] = []
    var settings = UsageMonitorProviderSettings()
    var isLoading = false
    var isShowingCopyToast = false
    var copyToastMessage = ""
    var alertTitle: String?
    var alertMessage: String?
    var accountLayoutMode: UsageAccountLayoutMode = .cards
    var isRunningCLILogin = false
    var isShowingLogin = false
    var dashboardURL: URL?
    var loginModeForSheet: String?
    var isShowingLoginURLSheet = false
    var loginURLForSheet: URL?
    var loadCallCount = 0
    var loadIfNeededCallCount = 0
    var loadIfNeededResults: [Bool] = [true, false]

    func load() async {
        loadCallCount += 1
    }

    func loadIfNeeded() async -> Bool {
        loadIfNeededCallCount += 1
        guard !loadIfNeededResults.isEmpty else { return false }
        return loadIfNeededResults.removeFirst()
    }

    func performAutoRefresh() async {}
    func performScheduledRefresh(now: Date) async {}
    func scheduledRefreshPollInterval(now: Date) -> TimeInterval { 60 }
    func updateSettings(_ settings: UsageMonitorProviderSettings) { self.settings = settings }
    func handleHeaderRefreshButtonTap() {}
    func setAccountLayoutMode(_ mode: UsageAccountLayoutMode) { accountLayoutMode = mode }
    func startLoginFlow() {}
    func cancelCLILoginIfNeeded() {}
    func handleLoginURLSheetDismissed() {}
    func copyLoginURL() {}
    func reopenLoginURLInBrowser() {}
}

@MainActor
private final class MockMetricsEngine: ProviderUsageMetricsEngineProtocol {
    var tokenTrendRange: UsageEngineTokenTrendRange = .days30
    var tokenTrendSnapshot: ProviderTokenTrendSnapshot?
    var tokenTrendRefreshStatus: ProviderTokenTrendRefreshStatusData?
    var tokenTrendErrorMessage: String?
    var isLoadingTokenTrend = false
    var tokenTrendCapability: ProviderUsageCurveCapability = .dailyWithIntradayDrilldown
    var selectedTokenTrendDayKey: String?
    var intradayBucket: ProviderIntradayBucket = .minute30
    var intradaySnapshot: ProviderIntradayUsageSnapshot?
    var intradayErrorMessage: String?
    var isLoadingIntraday = false
    var shouldShowTokenTrendLoadingSkeleton = false
    var loadUsageCallCount = 0
    var loadUsageIfNeededCallCount = 0
    var loadUsageIfNeededResults: [Bool] = [true, false]

    func loadUsage() async {
        loadUsageCallCount += 1
    }

    func loadUsageIfNeeded() async -> Bool {
        loadUsageIfNeededCallCount += 1
        guard !loadUsageIfNeededResults.isEmpty else { return false }
        return loadUsageIfNeededResults.removeFirst()
    }

    func setTokenTrendRange(_ range: UsageEngineTokenTrendRange) {
        tokenTrendRange = range
    }

    func refreshTokenTrendNow() {}
    func selectTokenTrendDay(_ dayKey: String?) { selectedTokenTrendDayKey = dayKey }
    func setIntradayBucket(_ bucket: ProviderIntradayBucket) { intradayBucket = bucket }
    func refreshIntradayNow() {}
    func refreshIntradayPanelNow() {}
}
