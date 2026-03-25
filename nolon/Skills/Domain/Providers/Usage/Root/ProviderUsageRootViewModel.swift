import Observation
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog

@MainActor
@Observable
final class ProviderUsageRootViewModel {
    let state: ProviderUsageStateStore
    let accountsViewModel: ProviderUsageAccountsViewModel
    let tokenTrendViewModel: ProviderTokenTrendViewModel
    let importExportViewModel: CodexImportExportViewModel
    let loginFlowViewModel: ProviderLoginFlowViewModel
    let gatewayCardsViewModel: CodexGatewayCardsViewModel

    var provider: Provider { state.provider }
    var usageProvider: UsageProvider? { state.usageProvider }

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
