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
    let gatewayCardsViewModel: CodexGatewayCardsViewModel

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
    var gatewayCardsDebugPageMarkerItems: [PageMarkerItem] {
        debugPageMarkerItems + [
            PageMarkerItem(
                title: NSLocalizedString(
                    "codex.gateway.cards.title",
                    value: "网关卡片",
                    comment: "Gateway cards section title"
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

    init(provider: Provider) {
        let engine = ProviderUsageEngine(provider: provider)
        let state = ProviderUsageStateStore(provider: provider, engine: engine)
        self.state = state
        self.accountsViewModel = ProviderUsageAccountsViewModel(state: state)
        self.tokenTrendViewModel = ProviderTokenTrendViewModel(state: state)
        self.importExportViewModel = CodexImportExportViewModel(state: state)
        self.loginFlowViewModel = ProviderLoginFlowViewModel(state: state)
        self.gatewayCardsViewModel = CodexGatewayCardsViewModel(state: state)
    }

    init(
        provider: Provider,
        usageMonitor: ProviderUsageMonitorService,
        codexActivateAction: @escaping ProviderUsageEngine.CodexActivateAction
    ) {
        let engine = ProviderUsageEngine(
            provider: provider,
            usageMonitor: usageMonitor,
            codexActivateAction: codexActivateAction
        )
        let state = ProviderUsageStateStore(provider: provider, engine: engine)
        self.state = state
        self.accountsViewModel = ProviderUsageAccountsViewModel(state: state)
        self.tokenTrendViewModel = ProviderTokenTrendViewModel(state: state)
        self.importExportViewModel = CodexImportExportViewModel(state: state)
        self.loginFlowViewModel = ProviderLoginFlowViewModel(state: state)
        self.gatewayCardsViewModel = CodexGatewayCardsViewModel(state: state)
    }

    init(state: ProviderUsageStateStore) {
        self.state = state
        self.accountsViewModel = ProviderUsageAccountsViewModel(state: state)
        self.tokenTrendViewModel = ProviderTokenTrendViewModel(state: state)
        self.importExportViewModel = CodexImportExportViewModel(state: state)
        self.loginFlowViewModel = ProviderLoginFlowViewModel(state: state)
        self.gatewayCardsViewModel = CodexGatewayCardsViewModel(state: state)
    }

    func load() async {
        await accountsViewModel.load()
    }

    func loadIfNeeded() async -> Bool {
        await accountsViewModel.loadIfNeeded()
    }
}
