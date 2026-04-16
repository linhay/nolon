import Observation
import Foundation
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog

enum ProviderUsagePageMode: Equatable, Sendable {
    case combined
    case accounts
    case usage

    var id: String {
        switch self {
        case .combined:
            "combined"
        case .accounts:
            "accounts"
        case .usage:
            "usage"
        }
    }

    var showsAccountsContent: Bool {
        self != .usage
    }

    var showsUsageContent: Bool {
        self != .accounts
    }
}

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
        navigationTitle(for: .combined)
    }
    var debugPageMarkerItems: [PageMarkerItem] {
        debugPageMarkerItems(for: .combined)
    }
    var tokenTrendDebugPageMarkerItems: [PageMarkerItem] {
        tokenTrendDebugPageMarkerItems(for: .combined)
    }

    func navigationTitle(for pageMode: ProviderUsagePageMode) -> String {
        switch pageMode {
        case .accounts:
            return NSLocalizedString("tab.accounts", value: "Accounts", comment: "Accounts")
        case .usage:
            return NSLocalizedString("tab.usage", value: "Usage", comment: "Usage")
        case .combined:
            if provider.templateId == "codex" || provider.templateId == "codexXcode" {
                return NSLocalizedString("tab.account_usage", value: "账号与用量", comment: "Account and usage")
            }
            return NSLocalizedString("tab.usage", value: "Usage", comment: "Usage")
        }
    }

    func debugPageMarkerItems(for pageMode: ProviderUsagePageMode) -> [PageMarkerItem] {
        let pageTitle: String = switch pageMode {
        case .combined:
            ProviderContentTabType.usage.localizedName(for: provider)
        case .accounts:
            ProviderContentTabType.accounts.localizedName(for: provider)
        case .usage:
            ProviderContentTabType.usage.localizedName(for: provider)
        }

        return [
            PageMarkerItem(title: provider.displayName),
            PageMarkerItem(title: pageTitle)
        ]
    }

    func tokenTrendDebugPageMarkerItems(for pageMode: ProviderUsagePageMode) -> [PageMarkerItem] {
        debugPageMarkerItems(for: pageMode) + [
            PageMarkerItem(
                title: NSLocalizedString(
                    "usage.token_trend.title",
                    value: "历史 Token 消耗",
                    comment: "Token trend section title"
                )
            )
        ]
    }

    func load(for pageMode: ProviderUsagePageMode) async {
        switch pageMode {
        case .combined:
            await loadPage()
        case .accounts:
            await loadAccounts()
        case .usage:
            await loadUsage()
        }
    }

    @discardableResult
    func loadIfNeeded(for pageMode: ProviderUsagePageMode) async -> Bool {
        switch pageMode {
        case .combined:
            await loadPageIfNeeded()
        case .accounts:
            await loadAccountsIfNeeded()
        case .usage:
            await loadUsageIfNeeded()
        }
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

        if provider.templateId == "copilot" {
            var actions: [GenericHeaderAction] = []
            if showsDashboardSignIn {
                actions.append(.signIn)
            }
            actions.append(.refresh)
            return actions
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
