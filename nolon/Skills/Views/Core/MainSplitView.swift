import SwiftUI
import ProviderCatalog
import CodexProvider
import Combine
import OSLog
import STFilePath
import NolonResourceKit

/// Main three-column split view for the app
/// Left 1: Provider sidebar (collapsible)
/// Left 2: Skills list for current provider
/// Left 3: Skill detail view
@MainActor
@Observable
final class MainSplitViewModel {
    fileprivate static let logger = Logger(subsystem: "com.nolon", category: "MainSplitView")

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

    var selectedSidebarItem: MainSidebarSelection?
    var selectedTab: ProviderContentTabType? = .skills
    var columnVisibility: NavigationSplitViewVisibility = .all
    
    var showingSettings = false
    var showingResourceCenter = false
    var refreshTrigger: Int = 0

    init(
        settings: ProviderSettings? = nil,
        repository: SkillRepository? = nil,
        nolonManager: NolonManager = .shared
    ) {
        self.nolonManager = nolonManager
        self.settings = settings ?? ProviderSettings.shared
        self.repository = repository ?? SkillRepository(nolonManager: nolonManager)
    }

    var selectedProviderId: Provider.ID? {
        guard case let .provider(providerID)? = selectedSidebarItem else {
            return nil
        }
        return providerID
    }

    var selectedProvider: Provider? {
        guard let selectedProviderId else { return nil }
        return settings.providers.first { $0.id == selectedProviderId }
    }

    var isPluginManagementSelected: Bool {
        selectedSidebarItem == .pluginManagement
    }
    
    @MainActor
    func setup() {
        installer = SkillInstaller(repository: repository, settings: settings)
        resourceMonitor = ProviderResourceMonitor { [weak self] in
            self?.refreshTrigger += 1
        }
        if let uiTestProviderIndex = UITestSupport.initialSelectedProviderIndex,
           settings.providers.indices.contains(uiTestProviderIndex) {
            selectedSidebarItem = .provider(settings.providers[uiTestProviderIndex].id)
        }
        updateResourceMonitoring()
        Task {
            _ = try? await CodexBinaryManager.shared.discoverXcodeAgentVersions()
            _ = await CodexBinaryManager.shared.checkForRustReleaseUpdateIfNeeded(force: false)
        }
    }

    @MainActor
    func updateResourceMonitoring() {
        guard let provider = selectedProvider else {
            resourceMonitor?.stop()
            return
        }
        resourceMonitor?.startWatching(provider: provider)
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

    @MainActor
    func presentResourceCenter() {
        showingResourceCenter = true
    }

    @MainActor
    func dismissResourceCenter() {
        guard showingResourceCenter else { return }
        showingResourceCenter = false
        onResourceCenterDismissed()
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
public struct MainSplitView: View {
    
    @State private var viewModel = MainSplitViewModel()

    public init() {}

    public var body: some View {
        ZStack {
            NavigationSplitView(columnVisibility: $viewModel.columnVisibility) {
                // Left 1: Provider sidebar
                ProviderSidebarView(
                    selectedItem: $viewModel.selectedSidebarItem,
                    settings: viewModel.settings
                )
            } content: {
                if viewModel.isPluginManagementSelected {
                    PluginManagementNavigationView()
                } else {
                    // Left 2: Skills/Workflows tab navigation
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
                } else {
                    // Left 3: Grid cards (skills or workflows)
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
                        }
                    )
                }
            }
            .navigationSplitViewStyle(.balanced)
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    // Resource Center button
                    Button {
                        viewModel.presentResourceCenter()
                    } label: {
                        Label(
                            NSLocalizedString("toolbar.clawdhub", comment: "Clawdhub"),
                            systemImage: "cloud"
                        )
                    }
                    .help("Browse and install resources from Clawdhub")
                }
            }

            if viewModel.showingResourceCenter {
                resourceCenterOverlay
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    .zIndex(10)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.showingResourceCenter)

        .sheet(isPresented: Bindable(AppCommandState.shared).showingSettings) {
            AppSettingsView()
                .frame(minWidth: 720, minHeight: 480)
        }
        .onExitCommand {
            viewModel.dismissResourceCenter()
        }
        .onReceive(URLSchemeHandler.shared.$pendingURL) { pendingURL in
            guard let url = pendingURL else { return }
            MainSplitViewModel.logger.info("Received URL from URLSchemeHandler: \(url.absoluteString, privacy: .public)")
            
            // URLSchemeHandler already converted nln:// or nolon:// to https://
            let urlString = url.absoluteString
            MainSplitViewModel.logger.info("Setting pendingImportURL to: \(urlString, privacy: .public)")
            viewModel.settings.pendingImportURL = urlString
            MainSplitViewModel.logger.info("pendingImportURL after set: \(viewModel.settings.pendingImportURL ?? "nil", privacy: .public)")
            
            MainSplitViewModel.logger.info("Opening ResourceCenterView overlay")
            viewModel.presentResourceCenter()
            
            // Clear the pending URL after consuming
            URLSchemeHandler.shared.pendingURL = nil
        }
        .onAppear {
            viewModel.setup()
            if UITestSupport.shouldOpenResourceCenterOnLaunch {
                viewModel.presentResourceCenter()
            }
        }
        .onChange(of: viewModel.selectedSidebarItem) { _, _ in
            viewModel.updateResourceMonitoring()
        }
        .onReceive(viewModel.settings.$providers) { _ in
            viewModel.updateResourceMonitoring()
        }
    }

    @ViewBuilder
    private var resourceCenterOverlay: some View {
        ZStack {
            DesignSystem.Colors.Overlay.scrim
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.dismissResourceCenter()
                }

            ResourceCenterView(
                settings: viewModel.settings,
                repository: viewModel.repository,
                targetProvider: viewModel.selectedProvider,
                selectedTab: .skills,
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
                }
            )
            .dsGlassPanel(cornerRadius: DesignSystem.Metrics.cornerRadiusXL)
            .padding(ResourceCenterOverlayLayout.outerInset)
        }
    }

}

private struct PluginManagementNavigationView: View {
    var body: some View {
        List {
            Label(
                NSLocalizedString("plugins.navigation.title", value: "Plugin Management", comment: "Plugin management navigation title"),
                systemImage: "puzzlepiece.extension"
            )
        }
        .listStyle(.sidebar)
        .navigationTitle(
            NSLocalizedString("plugins.navigation.group", value: "Plugins", comment: "Plugins navigation group title")
        )
    }
}

enum ResourceCenterOverlayLayout {
    static let outerInset: CGFloat = 40
}

#Preview {
    MainSplitView()
}
