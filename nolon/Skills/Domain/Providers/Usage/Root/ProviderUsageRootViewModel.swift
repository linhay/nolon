import Observation
import Foundation
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog

@MainActor
@Observable
final class ProviderUsageRootViewModel {
    enum GenericHeaderAction: String, Identifiable {
        case claudeMigrate
        case signIn
        case cliLogin
        case refresh

        var id: String { rawValue }
    }

    let state: ProviderUsageStateStore
    let accountsViewModel: ProviderUsageAccountsViewModel
    let tokenTrendViewModel: ProviderTokenTrendViewModel
    let importExportViewModel: CodexImportExportViewModel
    let loginFlowViewModel: ProviderLoginFlowViewModel

    var provider: Provider { state.provider }
    var usageProvider: UsageProvider? { state.usageProvider }
    var usageNavigationTitle: String {
        if provider.templateId == "codex" || provider.templateId == "codexXcode" {
            return NSLocalizedString("tab.account_usage", value: "账号与用量", comment: "Account and usage")
        }
        return NSLocalizedString("tab.usage", value: "Usage", comment: "Usage")
    }
    var debugPageMarkerItems: [PageMarkerItem] {
        [
            PageMarkerItem(title: provider.displayName),
            PageMarkerItem(title: ProviderContentTabType.usage.localizedName(for: provider))
        ]
    }
    var tokenTrendDebugPageMarkerItems: [PageMarkerItem] {
        debugPageMarkerItems + [
            PageMarkerItem(
                title: NSLocalizedString(
                    "usage.token_trend.title",
                    value: "历史 Token 消耗",
                    comment: "Token trend section title"
                )
            )
        ]
    }
    var genericHeaderActions: [GenericHeaderAction] {
        let showsDashboardSignIn = ProviderUsageLoginPolicy.shouldShowDashboardSignIn(
            for: provider,
            dashboardURL: loginFlowViewModel.dashboardURL
        )

        if usageProvider == .claude {
            var actions: [GenericHeaderAction] = [.claudeMigrate]
            if showsDashboardSignIn {
                actions.append(.signIn)
            }
            return actions
        }

        if ProviderUsageLoginPolicy.shouldUseCLILogin(for: provider) {
            return [.cliLogin, .refresh]
        }

        if showsDashboardSignIn {
            return [.signIn]
        }

        return [.refresh]
    }

    convenience init(provider: Provider) {
        let engine = ProviderUsageEngine(provider: provider)
        self.init(provider: provider, engine: engine)
    }

    convenience init(
        provider: Provider,
        usageMonitor: ProviderUsageMonitorService,
        codexActivateAction: @escaping UsageEngineCodexActivateAction
    ) {
        let engine = ProviderUsageEngine(
            provider: provider,
            usageMonitor: usageMonitor,
            codexActivateAction: codexActivateAction
        )
        self.init(provider: provider, engine: engine)
    }

    init(provider: Provider, engine: any AnyUsageEngine) {
        let state = ProviderUsageStateStore(provider: provider, engine: engine)
        self.state = state
        self.accountsViewModel = ProviderUsageAccountsViewModel(state: state)
        self.tokenTrendViewModel = ProviderTokenTrendViewModel(state: state)
        self.importExportViewModel = CodexImportExportViewModel(state: state)
        self.loginFlowViewModel = ProviderLoginFlowViewModel(state: state)
    }

    init(state: ProviderUsageStateStore) {
        self.state = state
        self.accountsViewModel = ProviderUsageAccountsViewModel(state: state)
        self.tokenTrendViewModel = ProviderTokenTrendViewModel(state: state)
        self.importExportViewModel = CodexImportExportViewModel(state: state)
        self.loginFlowViewModel = ProviderLoginFlowViewModel(state: state)
    }

    func load() async {
        await loadPage()
    }

    func loadIfNeeded() async -> Bool {
        await loadPageIfNeeded()
    }

    func loadAccounts() async {
        await state.accountsEngine.load()
    }

    @discardableResult
    func loadAccountsIfNeeded() async -> Bool {
        await state.accountsEngine.loadIfNeeded()
    }

    func loadUsage() async {
        await state.metricsEngine.loadUsage()
    }

    @discardableResult
    func loadUsageIfNeeded() async -> Bool {
        await state.metricsEngine.loadUsageIfNeeded()
    }

    func loadPage() async {
        await loadAccounts()
        await loadUsage()
    }

    @discardableResult
    func loadPageIfNeeded() async -> Bool {
        let didLoadAccounts = await loadAccountsIfNeeded()
        let didLoadUsage = await loadUsageIfNeeded()
        return didLoadAccounts || didLoadUsage
    }
}
