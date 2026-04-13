import SwiftUI
import ProviderCatalog
import CodexProvider
import Observation
import OSLog
import STFilePath
import NolonResourceKit
import NolonUI
import NolonUIFoundation

/// Main three-column split view for the app
/// Left 1: Provider sidebar (collapsible)
/// Left 2: Skills list for current provider
/// Left 3: Skill detail view
@MainActor
@Observable
final class MainSplitViewModel {
    fileprivate static let logger = Logger(subsystem: "com.nolon", category: "MainSplitView")
    private enum PersistenceKeys {
        static let selectedSidebarSelectionKey = "main.selected_sidebar_selection_key"
        static let selectedProviderTab = "main.selected_provider_tab"
    }

    var settings: ProviderSettings
    var repository: SkillRepository
    private(set) var installer: SkillInstaller?
    private var resourceMonitor: ProviderResourceMonitor?
    private let remoteInstallOrchestrator = RemoteInstallOrchestrator()
    private let nolonManager: NolonManager
    private var nextRegisteredDeleteRequestID = 0
    private var registeredDeleteRequests: [Int: RegisteredResourceDeleteRequest] = [:]
    private var inFlightDeleteRequestTasks: [Int: Task<ResourceDeleteExecutionResult, Never>] = [:]
    private var completedDeleteRequestResults: [Int: ResourceDeleteExecutionResult] = [:]
    private let userDefaults: UserDefaults
    private var isRestoringPersistedSelection = false

    var selectedSidebarSelectionKey: String? {
        didSet { persistSidebarSelection() }
    }
    var selectedTab: ProviderContentTabType? = .skills {
        didSet { persistSelectedTab() }
    }
    var nolonCenterViewModel = ResourceCenterViewModel(selectedTab: .skills)
    var columnVisibility: NavigationSplitViewVisibility = .all
    
    var showingSettings = false
    var refreshTrigger: Int = 0

    init(
        settings: ProviderSettings? = nil,
        repository: SkillRepository? = nil,
        nolonManager: NolonManager = .shared,
        userDefaults: UserDefaults = .standard
    ) {
        self.nolonManager = nolonManager
        self.settings = settings ?? ProviderSettings.shared
        self.repository = repository ?? SkillRepository(nolonManager: nolonManager)
        self.userDefaults = userDefaults
        restorePersistedSelection()
    }

    nonisolated deinit {}

    var selectedProviderId: Provider.ID? {
        guard case let .provider(providerID)? = selectedSidebarItem else {
            return nil
        }
        return providerID
    }

    var selectedSidebarItem: MainSidebarSelection? {
        get {
            guard let selectedSidebarSelectionKey else { return nil }
            return MainSidebarSelection(storageKey: selectedSidebarSelectionKey)
        }
        set {
            selectedSidebarSelectionKey = newValue?.storageKey
        }
    }

    var selectedProvider: Provider? {
        guard let selectedProviderId else { return nil }
        return settings.providers.first { $0.id == selectedProviderId }
    }

    var isPluginManagementSelected: Bool {
        selectedSidebarItem == .pluginManagement
    }

    var isNolonSelected: Bool {
        selectedSidebarItem == .nolon
    }

    var isAccountsSelected: Bool {
        selectedSidebarItem == .accounts
    }

    var nolonRepository: RemoteRepository {
        settings.remoteRepositories.first(where: { $0.templateType == .globalSkills }) ?? .globalSkills
    }

    @MainActor
    func openProviderFromAccounts(_ providerID: Provider.ID) {
            selectedSidebarItem = .provider(providerID)
        // 从账号中心跳转时，直接进入详情默认技能页，不停留在中间账号 tab。
        selectedTab = .skills
    }

    @MainActor
    func openProvider(providerID: Provider.ID, tab: ProviderContentTabType) {
        guard let provider = settings.providers.first(where: { $0.id == providerID }) else { return }
        selectedSidebarItem = .provider(provider.id)
        if ProviderContentTabType.availableTabs(for: provider).contains(tab) {
            selectedTab = tab
        } else {
            selectedTab = .skills
        }
    }
    
    @MainActor
    func setup() {
        let hadPersistedSelection = selectedSidebarSelectionKey != nil
        sanitizeSelectionState()
        repairNativeMcpConfigsIfNeeded()
        if hadPersistedSelection, selectedSidebarSelectionKey == nil {
            if let firstProvider = settings.providers.first {
                selectedSidebarItem = .provider(firstProvider.id)
            } else {
                selectedSidebarItem = .accounts
            }
        }
        installer = SkillInstaller(repository: repository, settings: settings)
        refreshNolonResourceCenterState()
        if !UITestSupport.isRunningUnitTests {
            resourceMonitor = ProviderResourceMonitor { [weak self] in
                self?.syncLinkedMcpProjectionForAllProviders()
                self?.refreshTrigger += 1
            }
        }
        if !UITestSupport.isRunningUnitTests,
           let initialLaunchSelection = Self.resolveInitialLaunchSelection(
            providers: settings.providers,
            selectedProviderIndex: UITestSupport.initialSelectedProviderIndex,
            initialTab: UITestSupport.initialSelectedProviderTab,
            isRunningUnitTests: UITestSupport.isRunningUnitTests
           ) {
            selectedSidebarItem = .provider(initialLaunchSelection.provider.id)
            if let initialTab = initialLaunchSelection.tab {
                selectedTab = initialTab
            }
        }
        if !UITestSupport.isRunningUnitTests {
            updateResourceMonitoring()
        }
        if !UITestSupport.isRunningUnitTests {
            Task {
                _ = try? await CodexBinaryManager.shared.discoverXcodeAgentVersions()
                _ = await CodexBinaryManager.shared.checkForRustReleaseUpdateIfNeeded(force: false)
            }
        }
    }

    static func resolveInitialLaunchSelection(
        providers: [Provider],
        selectedProviderIndex: Int?,
        initialTab: ProviderContentTabType?,
        isRunningUnitTests: Bool
    ) -> (provider: Provider, tab: ProviderContentTabType?)? {
        guard let selectedProviderIndex,
              providers.indices.contains(selectedProviderIndex) else {
            return nil
        }

        let provider = providers[selectedProviderIndex]
        guard let initialTab else {
            return (provider, nil)
        }

        if isRunningUnitTests {
            return (provider, initialTab)
        }

        let validatedTab: ProviderContentTabType?
        if ProviderContentTabType.availableTabs(for: provider).contains(initialTab) {
            validatedTab = initialTab
        } else {
            validatedTab = nil
        }
        return (provider, validatedTab)
    }

    private func restorePersistedSelection() {
        isRestoringPersistedSelection = true
        defer { isRestoringPersistedSelection = false }
        selectedSidebarSelectionKey = userDefaults.string(forKey: PersistenceKeys.selectedSidebarSelectionKey)
        if let tab = Self.persistedTab(from: userDefaults.string(forKey: PersistenceKeys.selectedProviderTab)) {
            selectedTab = tab
        } else {
            selectedTab = .skills
        }
    }

    private func sanitizeSelectionState() {
        selectedSidebarSelectionKey = Self.normalizedSidebarSelectionKey(
            selectedSidebarSelectionKey,
            providers: settings.providers
        )
        if let provider = selectedProvider,
           let selectedTab,
           ProviderContentTabType.availableTabs(for: provider).contains(selectedTab) == false {
            self.selectedTab = .skills
        }
    }

    static func normalizedSidebarSelectionKey(_ storageKey: String?, providers: [Provider]) -> String? {
        guard let storageKey,
              let selection = MainSidebarSelection(storageKey: storageKey)
        else {
            return nil
        }
        switch selection {
        case let .provider(providerID):
            return providers.contains(where: { $0.id == providerID }) ? storageKey : nil
        case .nolon:
            return storageKey
        case .accounts, .pluginManagement:
            return storageKey
        }
    }

    static func persistedTab(from rawValue: String?) -> ProviderContentTabType? {
        guard let rawValue else { return nil }
        return ProviderContentTabType(rawValue: rawValue)
    }

    private func persistSidebarSelection() {
        guard isRestoringPersistedSelection == false else { return }
        if let selectedSidebarSelectionKey {
            userDefaults.set(selectedSidebarSelectionKey, forKey: PersistenceKeys.selectedSidebarSelectionKey)
        } else {
            userDefaults.removeObject(forKey: PersistenceKeys.selectedSidebarSelectionKey)
        }
    }

    private func persistSelectedTab() {
        guard isRestoringPersistedSelection == false else { return }
        if let selectedTab {
            userDefaults.set(selectedTab.rawValue, forKey: PersistenceKeys.selectedProviderTab)
        } else {
            userDefaults.removeObject(forKey: PersistenceKeys.selectedProviderTab)
        }
    }

    @MainActor
    func updateResourceMonitoring() {
        let hasLinkedNativeMcpProvider = settings.providers.contains { provider in
            guard provider.mcpLinkEnabled,
                  let templateId = provider.templateId,
                  let template = ProviderTemplate(rawValue: templateId)
            else {
                return false
            }
            return template.supportsNativeMcpConfig
        }

        if let provider = selectedProvider {
            resourceMonitor?.startWatching(
                provider: provider,
                watchGlobalMcpCache: hasLinkedNativeMcpProvider
            )
            return
        }

        if hasLinkedNativeMcpProvider,
           let fallbackProvider = settings.providers.first {
            resourceMonitor?.startWatching(
                provider: fallbackProvider,
                watchGlobalMcpCache: true
            )
            return
        }

        resourceMonitor?.stop()
    }

    @MainActor
    private func syncLinkedMcpProjectionForAllProviders() {
        for provider in settings.providers where provider.mcpLinkEnabled {
            guard
                let templateId = provider.templateId,
                let template = ProviderTemplate(rawValue: templateId),
                template.supportsNativeMcpConfig
            else {
                continue
            }
            do {
                _ = try MCPConfigManager.syncAllCacheServersToProvider(for: template)
            } catch {
                Self.logger.error(
                    "Linked MCP projection sync failed. provider=\(provider.id, privacy: .public) template=\(template.rawValue, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    @MainActor
    private func repairNativeMcpConfigsIfNeeded() {
        var repairedTemplates = Set<String>()
        for provider in settings.providers {
            guard
                let templateId = provider.templateId,
                repairedTemplates.insert(templateId).inserted,
                let template = ProviderTemplate(rawValue: templateId),
                template.supportsNativeMcpConfig
            else {
                continue
            }
            do {
                _ = try MCPConfigManager.repairProviderMCPStateIfNeeded(for: template)
            } catch {
                Self.logger.error(
                    "Native MCP repair failed. provider=\(provider.id, privacy: .public) template=\(templateId, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    @MainActor
    func refreshNolonResourceCenterState() {
        let globalRepository = nolonRepository
        nolonCenterViewModel.selectedRepository = globalRepository
        nolonCenterViewModel.refreshInstalledResources(
            repository: repository,
            selectedRepository: globalRepository,
            fallbackTargetProvider: nil,
            settings: settings
        )
    }

    @MainActor
    func installRemoteSkill(_ skill: RemoteSkill, to provider: Provider) async {
        guard let installer = installer else { return }
        let remoteBaseURL = currentRemoteBaseURL()
        Self.logger.info(
            "Remote skill install start. slug=\(skill.slug, privacy: .public) provider=\(provider.id, privacy: .public) baseURL=\(remoteBaseURL, privacy: .public)"
        )

        do {
            try await remoteInstallOrchestrator.installSkill(
                skill,
                to: provider,
                installer: installer,
                remoteBaseURL: remoteBaseURL
            )
            Self.logger.info(
                "Remote skill install success. slug=\(skill.slug, privacy: .public) provider=\(provider.id, privacy: .public)"
            )
            refreshTrigger += 1
        } catch {
            logRemoteInstallError(
                resourceKind: "skill",
                slug: skill.slug,
                provider: provider,
                baseURL: remoteBaseURL,
                error: error
            )
            // Ideally show an alert here
        }
    }
    
    @MainActor
    func installRemoteWorkflow(_ workflow: RemoteWorkflow, to provider: Provider) async {
        let remoteBaseURL = currentRemoteBaseURL()
        Self.logger.info(
            "Remote workflow install start. slug=\(workflow.slug, privacy: .public) provider=\(provider.id, privacy: .public) baseURL=\(remoteBaseURL, privacy: .public)"
        )
        do {
            guard let installer else { return }
            try await remoteInstallOrchestrator.installWorkflow(
                workflow,
                to: provider,
                installer: installer,
                remoteBaseURL: remoteBaseURL
            )
            Self.logger.info(
                "Remote workflow install success. slug=\(workflow.slug, privacy: .public) provider=\(provider.id, privacy: .public)"
            )
            refreshTrigger += 1
        } catch {
            logRemoteInstallError(
                resourceKind: "workflow",
                slug: workflow.slug,
                provider: provider,
                baseURL: remoteBaseURL,
                error: error
            )
            // Ideally show an alert here
        }
    }
    
    @MainActor
    func installRemoteMCP(_ mcp: RemoteMCP, to provider: Provider) async {
        let remoteBaseURL = currentRemoteBaseURL()
        Self.logger.info(
            "Remote mcp install start. slug=\(mcp.slug, privacy: .public) provider=\(provider.id, privacy: .public) baseURL=\(remoteBaseURL, privacy: .public)"
        )
        do {
            try await remoteInstallOrchestrator.installMCP(
                mcp,
                to: provider,
                remoteBaseURL: remoteBaseURL
            )
            Self.logger.info(
                "Remote mcp install success. slug=\(mcp.slug, privacy: .public) provider=\(provider.id, privacy: .public)"
            )
            refreshTrigger += 1
        } catch {
            logRemoteInstallError(
                resourceKind: "mcp",
                slug: mcp.slug,
                provider: provider,
                baseURL: remoteBaseURL,
                error: error
            )
            // Ideally show an alert here
        }
    }

    @MainActor
    func deleteRemoteSkill(
        slug: String,
        providerIndex: Int?,
        removeGlobalCache: Bool,
        globalCachePathHint: String?
    ) async -> ResourceDeleteExecutionResult {
        let plan = ResourceDeletionExecutionPlan.make(
            providerIndex: providerIndex,
            removeGlobalCache: removeGlobalCache,
            providers: settings.providers,
            globalCachePathHint: globalCachePathHint
        )
        guard deletionRequestIsValid(
            providerIndex: providerIndex,
            removeGlobalCache: removeGlobalCache
        ) else {
            return invalidDeletionRequestResult(slug: slug, type: .skill)
        }
        let providerTargets = plan.resolveProviderTargets(from: settings.providers)
        Self.logger.info(
            "Delete remote skill start. inputProviderIndex=\(providerIndex.map(String.init) ?? "nil", privacy: .public) inputRemoveGlobalCache=\(removeGlobalCache, privacy: .public) settingsProviders=\(self.settings.providers.count, privacy: .public) resolvedProviderTargets=\(providerTargets.count, privacy: .public) planRemoveGlobalCache=\(plan.removeGlobalCache, privacy: .public) hasPathHint=\(globalCachePathHint != nil, privacy: .public)"
        )
        let result = await executeResourceDeletion(
            resourceSlug: slug,
            resourceType: .skill,
            plan: plan
        )
        Self.logger.info(
            "Delete remote skill result. attempted=\(result.attemptedCount, privacy: .public) success=\(result.successCount, privacy: .public) removedGlobalCache=\(result.removedGlobalCache, privacy: .public) failures=\(result.failures.count, privacy: .public)"
        )
        refreshTrigger += 1
        return result
    }

    @MainActor
    func registerDeleteRequest(
        slug: String,
        resourceType: RemoteContentType,
        providerIndex: Int?,
        removeGlobalCache: Bool,
        globalCachePathHint: String?
    ) -> Int {
        nextRegisteredDeleteRequestID += 1
        let requestID = nextRegisteredDeleteRequestID
        registeredDeleteRequests[requestID] = RegisteredResourceDeleteRequest(
            slug: slug,
            resourceType: resourceType,
            providerIndex: providerIndex,
            removeGlobalCache: removeGlobalCache,
            globalCachePathHint: globalCachePathHint
        )
        Self.logger.info(
            "Registered delete request. id=\(requestID, privacy: .public) resourceType=\(resourceType.rawValue, privacy: .public) providerIndex=\(providerIndex.map(String.init) ?? "nil", privacy: .public) removeGlobalCache=\(removeGlobalCache, privacy: .public) hasPathHint=\(globalCachePathHint != nil, privacy: .public)"
        )
        return requestID
    }

    @MainActor
    func executeRegisteredDeleteRequest(id requestID: Int) async -> ResourceDeleteExecutionResult {
        if let cachedResult = completedDeleteRequestResults[requestID] {
            Self.logger.info("Reused delete request result. id=\(requestID, privacy: .public)")
            return cachedResult
        }

        if let inFlightTask = inFlightDeleteRequestTasks[requestID] {
            Self.logger.info("Awaiting in-flight delete request. id=\(requestID, privacy: .public)")
            return await inFlightTask.value
        }

        guard let request = registeredDeleteRequests.removeValue(forKey: requestID) else {
            Self.logger.error("Delete request missing. id=\(requestID, privacy: .public)")
            return ResourceDeleteExecutionResult(
                resourceSlug: "",
                resourceType: .skill,
                attemptedCount: 0,
                successCount: 0,
                removedGlobalCache: false,
                failures: [
                    ResourceDeleteFailure(
                        targetName: "Delete Request",
                        reason: "Registered delete request not found."
                    )
                ]
            )
        }

        let task = Task { [self, request] in
            switch request.resourceType {
            case .skill:
                return await deleteRemoteSkill(
                    slug: request.slug,
                    providerIndex: request.providerIndex,
                    removeGlobalCache: request.removeGlobalCache,
                    globalCachePathHint: request.globalCachePathHint
                )
            case .workflow:
                return await deleteRemoteWorkflow(
                    slug: request.slug,
                    providerIndex: request.providerIndex,
                    removeGlobalCache: request.removeGlobalCache,
                    globalCachePathHint: request.globalCachePathHint
                )
            case .mcp:
                return await deleteRemoteMCP(
                    slug: request.slug,
                    providerIndex: request.providerIndex,
                    removeGlobalCache: request.removeGlobalCache,
                    globalCachePathHint: request.globalCachePathHint
                )
            }
        }

        inFlightDeleteRequestTasks[requestID] = task
        let result = await task.value
        inFlightDeleteRequestTasks[requestID] = nil
        completedDeleteRequestResults[requestID] = result
        return result
    }

    @MainActor
    func deleteRemoteWorkflow(
        slug: String,
        providerIndex: Int?,
        removeGlobalCache: Bool,
        globalCachePathHint: String?
    ) async -> ResourceDeleteExecutionResult {
        let plan = ResourceDeletionExecutionPlan.make(
            providerIndex: providerIndex,
            removeGlobalCache: removeGlobalCache,
            providers: settings.providers,
            globalCachePathHint: globalCachePathHint
        )
        guard deletionRequestIsValid(
            providerIndex: providerIndex,
            removeGlobalCache: removeGlobalCache
        ) else {
            return invalidDeletionRequestResult(slug: slug, type: .workflow)
        }
        let result = await executeResourceDeletion(
            resourceSlug: slug,
            resourceType: .workflow,
            plan: plan
        )
        refreshTrigger += 1
        return result
    }

    @MainActor
    func deleteRemoteMCP(
        slug: String,
        providerIndex: Int?,
        removeGlobalCache: Bool,
        globalCachePathHint: String?
    ) async -> ResourceDeleteExecutionResult {
        let plan = ResourceDeletionExecutionPlan.make(
            providerIndex: providerIndex,
            removeGlobalCache: removeGlobalCache,
            providers: settings.providers,
            globalCachePathHint: globalCachePathHint
        )
        guard deletionRequestIsValid(
            providerIndex: providerIndex,
            removeGlobalCache: removeGlobalCache
        ) else {
            return invalidDeletionRequestResult(slug: slug, type: .mcp)
        }
        let result = await executeResourceDeletion(
            resourceSlug: slug,
            resourceType: .mcp,
            plan: plan
        )
        refreshTrigger += 1
        return result
    }

    private func deletionRequestIsValid(
        providerIndex: Int?,
        removeGlobalCache: Bool
    ) -> Bool {
        (providerIndex != nil) != removeGlobalCache
    }

    private func invalidDeletionRequestResult(
        slug: String,
        type: RemoteContentType
    ) -> ResourceDeleteExecutionResult {
        ResourceDeleteExecutionResult(
            resourceSlug: slug,
            resourceType: type,
            attemptedCount: 0,
            successCount: 0,
            removedGlobalCache: false,
            failures: [
                ResourceDeleteFailure(
                    targetName: "Delete Request",
                    reason: "Invalid delete target combination."
                )
            ]
        )
    }

    private func executeResourceDeletion(
        resourceSlug: String,
        resourceType: RemoteContentType,
        plan: ResourceDeletionExecutionPlan
    ) async -> ResourceDeleteExecutionResult {
        let resolvedProviderIDs = Set(settings.providers.map(\.id))
        let targetProviders = settings.providers.filter { resolvedProviderIDs.contains($0.id) && plan.providerIDs.contains($0.id) }
        let installer = ResourceInstaller(
            globalCache: GlobalCacheRepository(nolonManager: nolonManager)
        )

        var failures: [ResourceDeleteFailure] = []
        var successCount = 0
        var removedGlobalCache = false

        for provider in targetProviders {
            do {
                try await installer.uninstall(
                    resourceSlug: resourceSlug,
                    resourceType: resourceType,
                    from: provider
                )
                successCount += 1
            } catch {
                failures.append(
                    ResourceDeleteFailure(
                        targetName: provider.name,
                        reason: error.localizedDescription
                    )
                )
            }
        }

        if plan.removeGlobalCache {
            do {
                removedGlobalCache = try await removeGlobalCacheResource(
                    slug: resourceSlug,
                    type: resourceType,
                    pathHint: plan.globalCachePathHint
                )
            } catch {
                failures.append(
                    ResourceDeleteFailure(
                        targetName: "Global Cache",
                        reason: error.localizedDescription
                    )
                )
            }
        }

        return ResourceDeleteExecutionResult(
            resourceSlug: resourceSlug,
            resourceType: resourceType,
            attemptedCount: targetProviders.count,
            successCount: successCount,
            removedGlobalCache: removedGlobalCache,
            failures: failures
        )
    }

    private func removeGlobalCacheResource(
        slug: String,
        type: RemoteContentType,
        pathHint: String?
    ) async throws -> Bool {
        var removed = false

        if let pathHint {
            let hintedPath = STPath(pathHint)
            if hintedPath.isExists || hintedPath.isSymbolicLink {
                try hintedPath.deleteIncludingBrokenSymlink()
                removed = true
            }
        }

        do {
            try await GlobalCacheRepository(nolonManager: nolonManager).removeFromCache(slug: slug, type: type)
            removed = true
        } catch {
            if !removed {
                throw error
            }
        }

        return removed
    }
    
    @MainActor
    func onResourceCenterDismissed() {
        refreshTrigger += 1
    }

    private func currentRemoteBaseURL() -> String {
        settings.remoteRepositories.first { $0.templateType == .clawdhub }?.baseURL
            ?? RepositoryTemplate.clawdhub.createRepository().baseURL
    }

    private func logRemoteInstallError(
        resourceKind: String,
        slug: String,
        provider: Provider,
        baseURL: String,
        error: Error
    ) {
        if let syncError = error as? SkillsRepositoryFacade.SyncError,
           case let .commandFailed(message) = syncError {
            Self.logger.error(
                "Remote \(resourceKind, privacy: .public) install failed(commandFailed). slug=\(slug, privacy: .public) provider=\(provider.id, privacy: .public) baseURL=\(baseURL, privacy: .public) message=\(message, privacy: .public)"
            )
            return
        }

        Self.logger.error(
            "Remote \(resourceKind, privacy: .public) install failed. slug=\(slug, privacy: .public) provider=\(provider.id, privacy: .public) baseURL=\(baseURL, privacy: .public) error=\(String(describing: error), privacy: .public)"
        )
    }
}

/// Main three-column split view for the app
/// Left 1: Provider sidebar (collapsible)
/// Left 2: Skills list for current provider
/// Left 3: Skill detail view
@MainActor
public struct MainSplitView: View, DebugPageLocatable {
    
    @Environment(\.openWindow) private var openWindow
    @State private var viewModel = MainSplitViewModel()
    @State private var urlSchemeHandler = URLSchemeHandler.shared

    public init() {}

    var debugPageMarkerItems: [PageMarkerItem] {
        var items = [PageMarkerItem(title: "Main")]
        if viewModel.isAccountsSelected {
            items.append(contentsOf: PageMarkerRouteResolver.accountsItems())
            return items
        }
        if viewModel.isPluginManagementSelected {
            items.append(contentsOf: PageMarkerRouteResolver.pluginManagementItems())
            return items
        }
        if viewModel.isNolonSelected {
            items.append(contentsOf: [
                PageMarkerItem(title: "Nolon"),
                PageMarkerItem(title: viewModel.nolonCenterViewModel.selectedTab?.localizedName ?? ResourceCenterTabID.skills.localizedName)
            ])
            return items
        }
        items.append(
            contentsOf: PageMarkerRouteResolver.providerDetailItems(
                provider: viewModel.selectedProvider,
                selectedTab: viewModel.selectedTab
            )
        )
        return items
    }

    public var body: some View {
        NolonUI.MainSplitScaffold(
            isAccountsSelected: viewModel.isAccountsSelected,
            showsOverlay: false
        ) {
            NolonUI.SplitLayoutScaffold(
                columnVisibility: .constant(.all),
                profile: NolonUI.SplitLayoutProfiles.accounts
            ) {
                ProviderSidebarView(
                    selectedItemKey: $viewModel.selectedSidebarSelectionKey,
                    settings: viewModel.settings
                )
            } content: {
                EmptyView()
            } detail: {
                NolonAccountsView(
                    settings: viewModel.settings,
                    onSelectProvider: { providerID in
                        viewModel.openProviderFromAccounts(providerID)
                    }
                )
            }
        } mainLayout: {
            NolonUI.SplitLayoutScaffold(
                columnVisibility: $viewModel.columnVisibility,
                profile: NolonUI.SplitLayoutProfiles.main
            ) {
                ProviderSidebarView(
                    selectedItemKey: $viewModel.selectedSidebarSelectionKey,
                    settings: viewModel.settings
                )
            } content: {
                if viewModel.isPluginManagementSelected {
                    NolonUI.PluginManagementNavigationView(
                        data: .init(
                            itemTitle: NSLocalizedString("plugins.navigation.title", value: "Plugin Management", comment: "Plugin management navigation title"),
                            itemSystemImage: "puzzlepiece.extension",
                            groupTitle: NSLocalizedString("plugins.navigation.group", value: "Plugins", comment: "Plugins navigation group title")
                        )
                    )
                } else if viewModel.isNolonSelected {
                    ResourceCenterTabView(
                        repository: viewModel.nolonRepository,
                        selectedTab: nolonSelectedTabBinding,
                        refreshTrigger: viewModel.nolonCenterViewModel.refreshTrigger
                    )
                } else {
                    ProviderContentTabView(
                        provider: viewModel.selectedProvider,
                        selectedTab: $viewModel.selectedTab,
                        settings: viewModel.settings,
                        refreshTrigger: viewModel.refreshTrigger
                    )
                }
            } detail: {
                if viewModel.isPluginManagementSelected {
                    PluginManagementView()
                } else if viewModel.isNolonSelected {
                    if viewModel.nolonCenterViewModel.selectedTab == .agents {
                        NolonAgentsManagementView()
                    } else {
                        ResourceCatalogGridView(
                            repository: viewModel.nolonRepository,
                            selectedTab: viewModel.nolonCenterViewModel.selectedTab,
                            searchText: nolonSearchTextBinding,
                            installedSlugs: viewModel.nolonCenterViewModel.installedSlugs,
                            installedSkills: viewModel.nolonCenterViewModel.installedSkills,
                            installedWorkflowSlugs: viewModel.nolonCenterViewModel.installedWorkflowSlugs,
                            installedMcpSlugs: viewModel.nolonCenterViewModel.installedMcpSlugs,
                            providers: viewModel.settings.providers,
                            refreshTrigger: viewModel.nolonCenterViewModel.refreshTrigger,
                            targetProvider: nil,
                            onInstall: { skill, provider in
                                Task {
                                    await viewModel.installRemoteSkill(skill, to: provider)
                                }
                            },
                            onInstallWorkflow: { workflow, provider in
                                Task {
                                    await viewModel.installRemoteWorkflow(workflow, to: provider)
                                }
                            },
                            onInstallMCP: { mcp, provider in
                                Task {
                                    await viewModel.installRemoteMCP(mcp, to: provider)
                                }
                            },
                            onRegisterDeleteRequest: { slug, resourceType, providerIndex, removeGlobalCache, globalCachePathHint in
                                viewModel.registerDeleteRequest(
                                    slug: slug,
                                    resourceType: resourceType,
                                    providerIndex: providerIndex,
                                    removeGlobalCache: removeGlobalCache,
                                    globalCachePathHint: globalCachePathHint
                                )
                            },
                            onMakeDeleteRequestExecutor: { requestID in
                                {
                                    await viewModel.executeRegisteredDeleteRequest(id: requestID)
                                }
                            },
                            onRefresh: {
                                viewModel.refreshNolonResourceCenterState()
                            },
                            onClose: nil
                        )
                    }
                } else {
                    ProviderDetailGridView(
                        provider: viewModel.selectedProvider,
                        selectedTab: viewModel.selectedTab,
                        settings: viewModel.settings,
                        refreshTrigger: viewModel.refreshTrigger,
                        onSelectProvider: { providerID in
                            viewModel.selectedSidebarItem = .provider(providerID)
                        },
                        onSelectTab: { tab in
                            viewModel.selectedTab = tab
                        },
                        onSelectNolon: {
                            viewModel.selectedSidebarItem = .nolon
                        }
                    )
                }
            }
        } overlay: {
            EmptyView()
        }
        .toolbar {
            resourceCenterToolbar
        }
        .debugPageLocator(debugPageMarkerItems)
        .sheet(isPresented: Bindable(AppCommandState.shared).showingSettings) {
            AppSettingsView()
                .frame(minWidth: 720, minHeight: 480)
        }
        .onChange(of: urlSchemeHandler.pendingURL) { _, pendingURL in
            guard let url = pendingURL else { return }
            MainSplitViewModel.logger.info("Received URL from URLSchemeHandler: \(url.absoluteString, privacy: .public)")
            
            // URLSchemeHandler already converted nln:// or nolon:// to https://
            let urlString = url.absoluteString
            MainSplitViewModel.logger.info("Setting pendingImportURL to: \(urlString, privacy: .public)")
            viewModel.settings.pendingImportURL = urlString
            MainSplitViewModel.logger.info("pendingImportURL after set: \(viewModel.settings.pendingImportURL ?? "nil", privacy: .public)")
            
            MainSplitViewModel.logger.info("Opening ResourceCenter window")
            presentResourceCenterWindow(selectedTab: .skills)
            
            // Clear the pending URL after consuming
            urlSchemeHandler.pendingURL = nil
        }
        .onAppear {
            viewModel.setup()
            if UITestSupport.shouldOpenResourceCenterOnLaunch {
                presentResourceCenterWindow(selectedTab: .skills)
            }
        }
        .onChange(of: viewModel.selectedSidebarSelectionKey) { _, _ in
            viewModel.updateResourceMonitoring()
            if viewModel.isNolonSelected {
                viewModel.refreshNolonResourceCenterState()
            }
        }
        .onChange(of: viewModel.settings.providers) { _, _ in
            viewModel.updateResourceMonitoring()
            if viewModel.isNolonSelected {
                viewModel.refreshNolonResourceCenterState()
            }
        }
        .onChange(of: viewModel.refreshTrigger) { _, _ in
            if viewModel.isNolonSelected {
                viewModel.refreshNolonResourceCenterState()
            }
        }
        .onChange(of: AppCommandState.shared.pendingNavigation) { _, pendingNavigation in
            guard let pendingNavigation else { return }
            switch pendingNavigation {
            case let .providerTab(providerID, tab):
                viewModel.openProvider(providerID: providerID, tab: tab)
            }
            AppCommandState.shared.pendingNavigation = nil
        }
    }

    private var nolonSelectedTabBinding: Binding<ResourceCenterTabID?> {
        Binding(
            get: { viewModel.nolonCenterViewModel.selectedTab },
            set: { viewModel.nolonCenterViewModel.selectedTab = $0 }
        )
    }

    private var nolonSearchTextBinding: Binding<String> {
        Binding(
            get: { viewModel.nolonCenterViewModel.searchText },
            set: { viewModel.nolonCenterViewModel.searchText = $0 }
        )
    }

    @ToolbarContentBuilder
    private var resourceCenterToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                presentResourceCenterWindow(selectedTab: .skills)
            } label: {
                Label(
                    NSLocalizedString("toolbar.clawdhub", comment: "Clawdhub"),
                    systemImage: "cloud"
                )
            }
            .help("Browse and install resources from Clawdhub")
        }
    }

    private func presentResourceCenterWindow(selectedTab: ResourceCenterTabID) {
        ResourceCenterWindowCoordinator.shared.payload = .init(
            settings: viewModel.settings,
            repository: viewModel.repository,
            targetProvider: viewModel.selectedProvider,
            selectedTab: selectedTab,
            onInstall: { skill, provider in
                Task {
                    await viewModel.installRemoteSkill(skill, to: provider)
                }
            },
            onInstallWorkflow: { workflow, provider in
                Task {
                    await viewModel.installRemoteWorkflow(workflow, to: provider)
                }
            },
            onInstallMCP: { mcp, provider in
                Task {
                    await viewModel.installRemoteMCP(mcp, to: provider)
                }
            },
            onRegisterDeleteRequest: { slug, resourceType, providerIndex, removeGlobalCache, globalCachePathHint in
                viewModel.registerDeleteRequest(
                    slug: slug,
                    resourceType: resourceType,
                    providerIndex: providerIndex,
                    removeGlobalCache: removeGlobalCache,
                    globalCachePathHint: globalCachePathHint
                )
            },
            onMakeDeleteRequestExecutor: { requestID in
                {
                    await viewModel.executeRegisteredDeleteRequest(id: requestID)
                }
            },
            onClose: {
                viewModel.onResourceCenterDismissed()
            }
        )
        openWindow(id: ResourceCenterWindowCoordinator.windowID)
    }

}

#Preview {
    MainSplitView()
}
