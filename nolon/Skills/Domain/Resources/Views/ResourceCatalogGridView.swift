import SwiftUI
import ProviderCatalog
import NolonResourceKit
import Observation
import OSLog
#if os(macOS)
import AppKit
#endif

protocol RemoteCatalogQueryServing {
    func query(
        repository: RemoteRepository,
        kind: SkillsRepositoryFacade.RemoteCatalogKind,
        query: String?,
        limit: Int
    ) async throws -> RemoteCatalogQueryResult
}

extension RemoteCatalogQueryService: RemoteCatalogQueryServing {}

/// Resource Catalog Grid ViewModel
@MainActor
@Observable
final class ResourceCatalogGridViewModel {
    private static let logger = Logger(subsystem: "com.nolon", category: "ResourceCatalogGridViewModel")
    typealias DeleteRequestExecutor = @MainActor () async -> ResourceDeleteExecutionResult
    struct DeleteRequestPresentation: Equatable {
        let sheetRequest: ResourceDeleteRequest?
        let directConfirmationRequest: ResourceDeleteRequest?
    }
    
    struct DeleteExecutionPreview: Equatable {
        let requestID: Int
        let pendingStateBecameActive: Bool
        let resultMessage: String
        let shouldShowDeleteResultAlert: Bool
        let didRefresh: Bool
    }

    var skills: [RemoteSkill] = []
    var workflows: [RemoteWorkflow] = []
    var mcps: [RemoteMCP] = []
    var isLoading = false
    var errorMessage: String?
    var canLoadMore = false
    var isLoadingMore = false
    var loadMoreErrorMessage: String?
    var selectedSkillForDetail: RemoteSkill?
    var selectedWorkflowForDetail: RemoteWorkflow?
    var selectedMCPForDetail: RemoteMCP?
    var deleteRequest: ResourceDeleteRequest?
    var directDeleteConfirmationRequest: ResourceDeleteRequest?
    var deleteResultMessage = ""
    var isShowingDeleteResultAlert = false
    var pendingSkillDeletes: Set<String> = []
    var pendingWorkflowDeletes: Set<String> = []
    var pendingMcpDeletes: Set<String> = []

    private var currentLoadID: UUID?
    private let queryService: any RemoteCatalogQueryServing
    private let pagingStore: RemoteCatalogPagingStore
    private let itemMapper: RemoteCatalogItemMapper

    init(
        queryService: any RemoteCatalogQueryServing = RemoteCatalogQueryService(),
        pagingStore: RemoteCatalogPagingStore = RemoteCatalogPagingStore(pageSize: 20, maxLimit: 200),
        itemMapper: RemoteCatalogItemMapper = RemoteCatalogItemMapper()
    ) {
        self.queryService = queryService
        self.pagingStore = pagingStore
        self.itemMapper = itemMapper
    }

    private func mapKind(_ tab: ResourceContentTabType) -> SkillsRepositoryFacade.RemoteCatalogKind {
        switch tab {
        case .skills:
            return .skill
        case .workflows:
            return .workflow
        case .mcps:
            return .mcp
        }
    }

    // 过滤逻辑现在在这里
    func filteredSkills(searchText: String) -> [RemoteSkill] {
        if searchText.isEmpty {
            return skills
        }
        let searchLower = searchText.lowercased()
        return skills.filter { skill in
            skill.displayName.lowercased().contains(searchLower)
            || (skill.summary?.lowercased().contains(searchLower) ?? false)
        }
    }
    
    func filteredWorkflows(searchText: String) -> [RemoteWorkflow] {
        if searchText.isEmpty {
            return workflows
        }
        let searchLower = searchText.lowercased()
        return workflows.filter { workflow in
            workflow.displayName.lowercased().contains(searchLower)
            || (workflow.summary?.lowercased().contains(searchLower) ?? false)
        }
    }
    
    func filteredMCPs(searchText: String) -> [RemoteMCP] {
        if searchText.isEmpty {
            return mcps
        }
        let searchLower = searchText.lowercased()
        return mcps.filter { mcp in
            mcp.displayName.lowercased().contains(searchLower)
            || (mcp.summary?.lowercased().contains(searchLower) ?? false)
        }
    }

    func requestSkillDetail(_ skill: RemoteSkill) {
        selectedSkillForDetail = skill
    }

    func consumeSelectedSkillForDetail() -> RemoteSkill? {
        Self.consumeSkillDetailSelection(&selectedSkillForDetail)
    }

    static func consumeSkillDetailSelection(_ selection: inout RemoteSkill?) -> RemoteSkill? {
        let skill = selection
        selection = nil
        return skill
    }
    
    func loadContent(for repository: RemoteRepository?, tab: ResourceContentTabType?, searchQuery: String, cacheBuster: String) async {
        guard let repository = repository, let tab = tab else {
            skills = []
            workflows = []
            mcps = []
            errorMessage = nil
            isLoading = false
            currentLoadID = nil
            canLoadMore = false
            return
        }

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasQuery = !trimmedQuery.isEmpty
        let kind = mapKind(tab)
        let cacheKey = pagingStore.key(repositoryID: repository.id, kind: kind, query: trimmedQuery)
        let previousCacheEntry = pagingStore.entry(for: cacheKey)
        let loadID = UUID()
        currentLoadID = loadID

        if let cached = previousCacheEntry {
            applyCached(cached, for: tab)
            if pagingStore.shouldUseCachedResult(for: cacheKey, cacheBuster: cacheBuster) {
                return
            }
        } else {
            clearAllContent()
        }

        // 切换仓库/Tab 或手动刷新时：清空旧错误，避免展示上一个仓库的错误
        errorMessage = nil
        loadMoreErrorMessage = nil
        isLoading = true
        isLoadingMore = false
        let hadVisibleContentBeforeFetch = !(skills.isEmpty && workflows.isEmpty && mcps.isEmpty)

        defer {
            // 仅当本次任务仍然是最新请求时才落地 isLoading，避免竞态覆盖
            if currentLoadID == loadID {
                isLoading = false
            }
        }
        
        do {
            let cachedLimit = pagingStore.currentLimit(for: cacheKey)
            let queryResult = try await queryService.query(
                repository: repository,
                kind: kind,
                query: hasQuery ? trimmedQuery : nil,
                limit: cachedLimit
            )

            let loadMoreEnabled = repository.templateType == .clawdhub
                && queryResult.canLoadMore
                && cachedLimit < pagingStore.maxLimit

            switch tab {
            case .skills:
                let result = queryResult.items.map { itemMapper.toRemoteSkill($0) }
                guard currentLoadID == loadID else { return }
                skills = result
                canLoadMore = loadMoreEnabled
                pagingStore.saveSuccess(
                    for: cacheKey,
                    items: queryResult.items,
                    cacheBuster: cacheBuster,
                    limit: cachedLimit,
                    canLoadMore: loadMoreEnabled
                )
            case .workflows:
                let result = queryResult.items.map { itemMapper.toRemoteWorkflow($0) }
                guard currentLoadID == loadID else { return }
                workflows = result
                canLoadMore = loadMoreEnabled
                pagingStore.saveSuccess(
                    for: cacheKey,
                    items: queryResult.items,
                    cacheBuster: cacheBuster,
                    limit: cachedLimit,
                    canLoadMore: loadMoreEnabled
                )
            case .mcps:
                let result = queryResult.items.map { itemMapper.toRemoteMCP($0) }
                guard currentLoadID == loadID else { return }
                mcps = result
                canLoadMore = loadMoreEnabled
                pagingStore.saveSuccess(
                    for: cacheKey,
                    items: queryResult.items,
                    cacheBuster: cacheBuster,
                    limit: cachedLimit,
                    canLoadMore: loadMoreEnabled
                )
            }
        } catch is CancellationError {
            // 任务被取消（如用户快速切换仓库），静默忽略，不显示错误
            return
        } catch let error as URLError where error.code == .cancelled {
            // 网络请求被取消，静默忽略，不显示错误
            return
        } catch {
            guard currentLoadID == loadID else { return }
            if !hadVisibleContentBeforeFetch {
                clearAllContent()
                canLoadMore = false
            }
            errorMessage = error.localizedDescription
            let cachedItems: [SkillsRepositoryFacade.RemoteCatalogItem]
            if hadVisibleContentBeforeFetch {
                switch tab {
                case .skills:
                    cachedItems = skills.map { itemMapper.toCatalogItem($0) }
                case .workflows:
                    cachedItems = workflows.map { itemMapper.toCatalogItem($0) }
                case .mcps:
                    cachedItems = mcps.map { itemMapper.toCatalogItem($0) }
                }
            } else {
                cachedItems = []
            }
            pagingStore.saveError(
                for: cacheKey,
                items: cachedItems,
                cacheBuster: cacheBuster,
                limit: pagingStore.currentLimit(for: cacheKey),
                errorMessage: error.localizedDescription
            )
        }
    }

    func loadMore(repository: RemoteRepository?, tab: ResourceContentTabType?, searchQuery: String) async {
        guard let repository = repository, let tab = tab else { return }
        guard repository.templateType == .clawdhub else { return }

        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let kind = mapKind(tab)
        let cacheKey = pagingStore.key(repositoryID: repository.id, kind: kind, query: trimmedQuery)
        let currentLimit = pagingStore.currentLimit(for: cacheKey)
        guard let nextLimit = pagingStore.nextLimit(for: cacheKey) else { return }

        let loadID = UUID()
        currentLoadID = loadID
        isLoadingMore = true
        loadMoreErrorMessage = nil

        defer {
            if currentLoadID == loadID {
                isLoadingMore = false
            }
        }

        do {
            let queryResult = try await queryService.query(
                repository: repository,
                kind: kind,
                query: trimmedQuery.isEmpty ? nil : trimmedQuery,
                limit: nextLimit
            )
            switch tab {
            case .skills:
                let result = queryResult.items.map { itemMapper.toRemoteSkill($0) }
                guard currentLoadID == loadID else { return }
                skills = result
                let canLoad = queryResult.canLoadMore && nextLimit < pagingStore.maxLimit
                canLoadMore = canLoad
                pagingStore.saveSuccess(
                    for: cacheKey,
                    items: queryResult.items,
                    cacheBuster: pagingStore.entry(for: cacheKey)?.cacheBuster ?? "",
                    limit: nextLimit,
                    canLoadMore: canLoad
                )
            case .workflows:
                let result = queryResult.items.map { itemMapper.toRemoteWorkflow($0) }
                guard currentLoadID == loadID else { return }
                workflows = result
                let canLoad = queryResult.canLoadMore && nextLimit < pagingStore.maxLimit
                canLoadMore = canLoad
                pagingStore.saveSuccess(
                    for: cacheKey,
                    items: queryResult.items,
                    cacheBuster: pagingStore.entry(for: cacheKey)?.cacheBuster ?? "",
                    limit: nextLimit,
                    canLoadMore: canLoad
                )
            case .mcps:
                let result = queryResult.items.map { itemMapper.toRemoteMCP($0) }
                guard currentLoadID == loadID else { return }
                mcps = result
                let canLoad = queryResult.canLoadMore && nextLimit < pagingStore.maxLimit
                canLoadMore = canLoad
                pagingStore.saveSuccess(
                    for: cacheKey,
                    items: queryResult.items,
                    cacheBuster: pagingStore.entry(for: cacheKey)?.cacheBuster ?? "",
                    limit: nextLimit,
                    canLoadMore: canLoad
                )
            }
        } catch {
            guard currentLoadID == loadID else { return }
            loadMoreErrorMessage = error.localizedDescription
            let cachedItems: [SkillsRepositoryFacade.RemoteCatalogItem]
            switch tab {
            case .skills:
                cachedItems = skills.map { itemMapper.toCatalogItem($0) }
            case .workflows:
                cachedItems = workflows.map { itemMapper.toCatalogItem($0) }
            case .mcps:
                cachedItems = mcps.map { itemMapper.toCatalogItem($0) }
            }
            pagingStore.saveError(
                for: cacheKey,
                items: cachedItems,
                cacheBuster: pagingStore.entry(for: cacheKey)?.cacheBuster ?? "",
                limit: currentLimit,
                errorMessage: error.localizedDescription
            )
        }
    }

    private func applyCached(_ cached: RemoteCatalogPageEntry, for tab: ResourceContentTabType) {
        switch tab {
        case .skills:
            skills = cached.items.map { itemMapper.toRemoteSkill($0) }
            workflows = []
            mcps = []
        case .workflows:
            skills = []
            workflows = cached.items.map { itemMapper.toRemoteWorkflow($0) }
            mcps = []
        case .mcps:
            skills = []
            workflows = []
            mcps = cached.items.map { itemMapper.toRemoteMCP($0) }
        }

        errorMessage = cached.errorMessage
        isLoading = false
        canLoadMore = cached.canLoadMore
    }

    private func clearAllContent() {
        skills = []
        workflows = []
        mcps = []
        canLoadMore = false
    }

    func requestDelete(skill: RemoteSkill, repositoryTemplateType: RepositoryTemplate?) {
        requestDelete(
            Self.makeDeleteRequest(
                skill: skill,
                repositoryTemplateType: repositoryTemplateType
            )
        )
    }

    func requestDelete(workflow: RemoteWorkflow, repositoryTemplateType: RepositoryTemplate?) {
        requestDelete(
            Self.makeDeleteRequest(
                workflow: workflow,
                repositoryTemplateType: repositoryTemplateType
            )
        )
    }

    func requestDelete(mcp: RemoteMCP, repositoryTemplateType: RepositoryTemplate?) {
        requestDelete(
            Self.makeDeleteRequest(
                mcp: mcp,
                repositoryTemplateType: repositoryTemplateType
            )
        )
    }

    private func requestDelete(_ request: ResourceDeleteRequest) {
        let presentation = Self.makeDeleteRequestPresentation(for: request)
        directDeleteConfirmationRequest = presentation.directConfirmationRequest
        deleteRequest = presentation.sheetRequest
    }

    static func makeDeleteRequest(
        skill: RemoteSkill,
        repositoryTemplateType: RepositoryTemplate?
    ) -> ResourceDeleteRequest {
        ResourceDeleteRequest(
            skill: skill,
            defaultTarget: repositoryTemplateType == .globalSkills ? .allProvidersAndGlobalCache : nil
        )
    }

    static func makeDeleteRequest(
        workflow: RemoteWorkflow,
        repositoryTemplateType: RepositoryTemplate?
    ) -> ResourceDeleteRequest {
        ResourceDeleteRequest(
            workflow: workflow,
            defaultTarget: repositoryTemplateType == .globalSkills ? .allProvidersAndGlobalCache : nil
        )
    }

    static func makeDeleteRequest(
        mcp: RemoteMCP,
        repositoryTemplateType: RepositoryTemplate?
    ) -> ResourceDeleteRequest {
        ResourceDeleteRequest(
            mcp: mcp,
            defaultTarget: repositoryTemplateType == .globalSkills ? .allProvidersAndGlobalCache : nil
        )
    }

    static func makeDeleteRequestPresentation(
        for request: ResourceDeleteRequest
    ) -> DeleteRequestPresentation {
        if request.defaultTarget != nil {
            return DeleteRequestPresentation(
                sheetRequest: nil,
                directConfirmationRequest: request
            )
        }

        return DeleteRequestPresentation(
            sheetRequest: request,
            directConfirmationRequest: nil
        )
    }

    func executeDelete(
        resourceSlug: String,
        resourceType: RemoteContentType,
        target: ResourceDeleteTarget,
        globalCachePathHint: String? = nil,
        providers: [Provider],
        onRegisterDeleteRequest: ((String, RemoteContentType, Int?, Bool, String?) -> Int)?,
        onMakeDeleteRequestExecutor: ((Int) -> DeleteRequestExecutor)?,
        onPendingDeleteStateApplied: ((Bool) -> Void)? = nil,
        onRefresh: (() -> Void)? = nil,
        localized: (_ key: String, _ fallback: String) -> String = { key, fallback in
            NSLocalizedString(key, value: fallback, comment: "")
        },
        preferredLanguages: () -> [String] = { Locale.preferredLanguages }
    ) async {
        let flattenedTarget = Self.flattenDeleteTarget(target, providers: providers)
        Self.logger.info(
            "Execute delete requested. resourceType=\(resourceType.rawValue, privacy: .public) providers=\(providers.count, privacy: .public) providerIndex=\(flattenedTarget.providerIndex.map(String.init) ?? "nil", privacy: .public) removeGlobalCache=\(flattenedTarget.removeGlobalCache, privacy: .public) hasPathHint=\(globalCachePathHint != nil, privacy: .public)"
        )
        guard let onRegisterDeleteRequest, let onMakeDeleteRequestExecutor else { return }
        let requestID = onRegisterDeleteRequest(
            resourceSlug,
            resourceType,
            flattenedTarget.providerIndex,
            flattenedTarget.removeGlobalCache,
            globalCachePathHint
        )
        let executeDeleteRequest = onMakeDeleteRequestExecutor(requestID)
        switch resourceType {
        case .skill:
            pendingSkillDeletes.insert(resourceSlug)
            defer { pendingSkillDeletes.remove(resourceSlug) }
            onPendingDeleteStateApplied?(pendingSkillDeletes.contains(resourceSlug))
            let result = await executeDeleteRequest()
            presentDeleteResult(
                result,
                requestedSlug: resourceSlug,
                localized: localized,
                preferredLanguages: preferredLanguages
            )
        case .workflow:
            pendingWorkflowDeletes.insert(resourceSlug)
            defer { pendingWorkflowDeletes.remove(resourceSlug) }
            onPendingDeleteStateApplied?(pendingWorkflowDeletes.contains(resourceSlug))
            let result = await executeDeleteRequest()
            presentDeleteResult(
                result,
                requestedSlug: resourceSlug,
                localized: localized,
                preferredLanguages: preferredLanguages
            )
        case .mcp:
            pendingMcpDeletes.insert(resourceSlug)
            defer { pendingMcpDeletes.remove(resourceSlug) }
            onPendingDeleteStateApplied?(pendingMcpDeletes.contains(resourceSlug))
            let result = await executeDeleteRequest()
            presentDeleteResult(
                result,
                requestedSlug: resourceSlug,
                localized: localized,
                preferredLanguages: preferredLanguages
            )
        }

        onRefresh?()
    }

    static func previewDeleteExecution(
        resourceSlug: String,
        resourceType: RemoteContentType,
        target: ResourceDeleteTarget,
        globalCachePathHint: String? = nil,
        providers: [Provider],
        onRegisterDeleteRequest: (String, RemoteContentType, Int?, Bool, String?) -> Int,
        onMakeDeleteRequestExecutor: (Int) -> DeleteRequestExecutor,
        localized: (_ key: String, _ fallback: String) -> String = { key, fallback in
            NSLocalizedString(key, value: fallback, comment: "")
        },
        preferredLanguages: () -> [String] = { Locale.preferredLanguages }
    ) async -> DeleteExecutionPreview {
        let flattenedTarget = flattenDeleteTarget(target, providers: providers)
        let requestID = onRegisterDeleteRequest(
            resourceSlug,
            resourceType,
            flattenedTarget.providerIndex,
            flattenedTarget.removeGlobalCache,
            globalCachePathHint
        )
        let executeDeleteRequest = onMakeDeleteRequestExecutor(requestID)
        let result = await executeDeleteRequest()
        let typeName = localizedTypeName(for: resourceType, localized: localized)
        let resultMessage = buildDeleteResultMessage(
            resourceSlug: resourceSlug,
            result: result,
            typeName: typeName,
            localized: localized,
            preferredLanguages: preferredLanguages
        )

        return DeleteExecutionPreview(
            requestID: requestID,
            pendingStateBecameActive: true,
            resultMessage: resultMessage,
            shouldShowDeleteResultAlert: true,
            didRefresh: true
        )
    }

    private static func flattenDeleteTarget(
        _ target: ResourceDeleteTarget,
        providers: [Provider]
    ) -> (providerIndex: Int?, removeGlobalCache: Bool) {
        switch target {
        case let .provider(providerID):
            let providerIndex = providers.firstIndex { $0.id == providerID }
            return (providerIndex, false)
        case .allProvidersAndGlobalCache:
            return (nil, true)
        }
    }

    func presentDeleteResult(
        _ result: ResourceDeleteExecutionResult,
        requestedSlug: String,
        localized: (_ key: String, _ fallback: String) -> String = { key, fallback in
            NSLocalizedString(key, value: fallback, comment: "")
        },
        preferredLanguages: () -> [String] = { Locale.preferredLanguages }
    ) {
        let typeName = Self.localizedTypeName(for: result.resourceType, localized: localized)
        deleteResultMessage = Self.buildDeleteResultMessage(
            resourceSlug: requestedSlug,
            result: result,
            typeName: typeName,
            localized: localized,
            preferredLanguages: preferredLanguages
        )
        isShowingDeleteResultAlert = true
    }

    private static func localizedTypeName(
        for resourceType: RemoteContentType,
        localized: (_ key: String, _ fallback: String) -> String
    ) -> String {
        switch resourceType {
        case .skill:
            return localized("tab.skills", "Skills")
        case .workflow:
            return localized("tab.workflows", "Workflows")
        case .mcp:
            return localized("tab.mcps", "MCPs")
        }
    }

    nonisolated static func buildDeleteResultMessage(
        resourceSlug: String,
        result: ResourceDeleteExecutionResult,
        typeName: String,
        localized: (_ key: String, _ fallback: String) -> String,
        preferredLanguages: () -> [String]
    ) -> String {
        let localTypeName = String(typeName)
        let localResourceSlug = String(resourceSlug)
        let localPreferredLanguages = preferredLanguages()
        let localSuccessCount = String(result.successCount)
        let localAttemptedCount = String(result.attemptedCount)

        if result.failures.isEmpty {
            let localizedMarker = localized(
                "resource.delete.result.success",
                "%1$@ \"%2$@\" deleted. Removed from %3$ld provider(s)."
            )
            if usesChineseDeleteMessage(localizedMarker: localizedMarker, preferredLanguages: localPreferredLanguages) {
                return [
                    "已删除",
                    localTypeName,
                    "“",
                    localResourceSlug,
                    "”。已从 ",
                    localSuccessCount,
                    " 个 Provider 中移除。"
                ].joined()
            }
            return [
                localTypeName,
                " \"",
                localResourceSlug,
                "\" deleted. Removed from ",
                localSuccessCount,
                " provider(s)."
            ].joined()
        }

        let localFailures = result.failures
            .map { [String($0.targetName), ": ", String($0.reason)].joined() }
            .joined(separator: "\n")
        let localizedMarker = localized(
            "resource.delete.result.partial",
            "%1$@ \"%2$@\" deleted with partial failures.\nSuccess: %3$ld/%4$ld\n%5$@"
        )
        if usesChineseDeleteMessage(localizedMarker: localizedMarker, preferredLanguages: localPreferredLanguages) {
            return [
                "已删除",
                localTypeName,
                "“",
                localResourceSlug,
                "”，但部分目标失败。\n成功：",
                localSuccessCount,
                "/",
                localAttemptedCount,
                "\n",
                localFailures
            ].joined()
        }
        return [
            localTypeName,
            " \"",
            localResourceSlug,
            "\" deleted with partial failures.\nSuccess: ",
            localSuccessCount,
            "/",
            localAttemptedCount,
            "\n",
            localFailures
        ].joined()
    }

    private nonisolated static func usesChineseDeleteMessage(
        localizedMarker: String,
        preferredLanguages: [String]
    ) -> Bool {
        if preferredLanguages.contains(where: { $0.lowercased().hasPrefix("zh") }) {
            return true
        }

        return localizedMarker.unicodeScalars.contains { scalar in
            switch scalar.value {
            case 0x4E00...0x9FFF, 0x3400...0x4DBF, 0x20000...0x2A6DF:
                return true
            default:
                return false
            }
        }
    }
}

/// Detail 区域 - Grid 布局显示资源中心内容
struct ResourceCatalogGridView: View {
    @Environment(\.openWindow) private var openWindow
    private static let logger = Logger(subsystem: "com.nolon", category: "ResourceCatalogGrid")
    private static let installTimeoutNanoseconds: UInt64 = 45_000_000_000

    let repository: RemoteRepository?
    let selectedTab: ResourceContentTabType?
    @Binding var searchText: String
    let installedSlugs: Set<String>
    let installedSkills: [RemoteSkill]
    let installedWorkflowSlugs: Set<String>
    let installedMcpSlugs: Set<String>
    let providers: [Provider]
    var refreshTrigger: Int
    let targetProvider: Provider?
    let onInstall: (RemoteSkill, Provider) -> Void
    let onInstallWorkflow: ((RemoteWorkflow, Provider) -> Void)?
    let onInstallMCP: ((RemoteMCP, Provider) -> Void)?
    let onRegisterDeleteRequest: ((String, RemoteContentType, Int?, Bool, String?) -> Int)?
    let onMakeDeleteRequestExecutor: ((Int) -> ResourceCatalogGridViewModel.DeleteRequestExecutor)?
    let onRefresh: (() -> Void)?
    let onClose: (() -> Void)?
    
    @State private var viewModel = ResourceCatalogGridViewModel()
    private var watchCenter = RemoteRepositoryWatchCenter.shared
    @State private var debouncedSearchText: String = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var retryTrigger: Int = 0
    @State private var showCopiedToast: Bool = false
    @State private var pendingSkillInstalls: Set<String> = []
    @State private var pendingWorkflowInstalls: Set<String> = []
    @State private var pendingMcpInstalls: Set<String> = []
    @State private var skillInstallErrors: [String: String] = [:]
    @State private var workflowInstallErrors: [String: String] = [:]
    @State private var mcpInstallErrors: [String: String] = [:]
    
    init(
        repository: RemoteRepository?,
        selectedTab: ResourceContentTabType?,
        searchText: Binding<String>,
        installedSlugs: Set<String>,
        installedSkills: [RemoteSkill],
        installedWorkflowSlugs: Set<String>,
        installedMcpSlugs: Set<String>,
        providers: [Provider],
        refreshTrigger: Int,
        targetProvider: Provider?,
        onInstall: @escaping (RemoteSkill, Provider) -> Void,
        onInstallWorkflow: ((RemoteWorkflow, Provider) -> Void)? = nil,
        onInstallMCP: ((RemoteMCP, Provider) -> Void)? = nil,
        onRegisterDeleteRequest: ((String, RemoteContentType, Int?, Bool, String?) -> Int)? = nil,
        onMakeDeleteRequestExecutor: ((Int) -> ResourceCatalogGridViewModel.DeleteRequestExecutor)? = nil,
        onRefresh: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.repository = repository
        self.selectedTab = selectedTab
        self._searchText = searchText
        self._debouncedSearchText = State(initialValue: searchText.wrappedValue)
        self.installedSlugs = installedSlugs
        self.installedSkills = installedSkills
        self.installedWorkflowSlugs = installedWorkflowSlugs
        self.installedMcpSlugs = installedMcpSlugs
        self.providers = providers
        self.refreshTrigger = refreshTrigger
        self.targetProvider = targetProvider
        self.onInstall = onInstall
        self.onInstallWorkflow = onInstallWorkflow
        self.onInstallMCP = onInstallMCP
        self.onRegisterDeleteRequest = onRegisterDeleteRequest
        self.onMakeDeleteRequestExecutor = onMakeDeleteRequestExecutor
        self.onRefresh = onRefresh
        self.onClose = onClose
    }
    
    private let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 400), spacing: 16)
    ]

    private var isClawdhub: Bool {
        repository?.templateType == .clawdhub
    }

    private var normalizedSearchQuery: String {
        Self.resolveSearchQuery(
            isClawdhub: isClawdhub,
            debouncedSearchText: debouncedSearchText,
            searchText: searchText
        )
    }

    static func resolveSearchQuery(
        isClawdhub: Bool,
        debouncedSearchText: String,
        searchText: String
    ) -> String {
        guard isClawdhub else { return "" }
        let debounced = debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !debounced.isEmpty {
            return debounced
        }
        return searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isSearching: Bool {
        let trimmed = normalizedSearchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return isClawdhub && !trimmed.isEmpty && viewModel.isLoading
    }

    private var repoSyncToken: Int {
        watchCenter.token(for: repository)
    }

    private var cacheBuster: String {
        "\(refreshTrigger)-\(repoSyncToken)-\(normalizedSearchQuery)-\(retryTrigger)"
    }

    private var loadTaskID: String {
        "\(repository?.id ?? "")-\(selectedTab?.rawValue ?? "")-\(cacheBuster)"
    }

    var body: some View {
        contentWithDetailSheets
            .textSelection(.enabled)
    }

    @ViewBuilder
    private var mainContentView: some View {
        Group {
            if repository == nil {
                ContentUnavailableView {
                    Label {
                        Text(NSLocalizedString("detail.no_repository", comment: "Select a Repository"))
                            .dsEmptyStateTitle()
                    } icon: {
                        Image(systemName: "tray")
                            .dsEmptyStateIcon()
                    }
                }
            } else if selectedTab == nil {
                ContentUnavailableView {
                    Label {
                        Text(NSLocalizedString("detail.select_tab", comment: "Select a Tab"))
                            .dsEmptyStateTitle()
                    } icon: {
                        Image(systemName: "list.bullet")
                            .dsEmptyStateIcon()
                    }
                }
            } else {
                VStack(spacing: 12) {
                    searchBar
                    contentBody
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
    }

    private var contentWithTask: some View {
        // 使用 .task(id:) 处理仓库切换，它会自动取消旧任务并启动新任务
        // 不需要 .onChange，避免重复触发导致请求被取消
        mainContentView
            .task(id: loadTaskID) {
                await loadContent()
            }
    }

    private var contentWithSearchDebounce: some View {
        contentWithTask
            .onChange(of: searchText) { _, newValue in
                searchDebounceTask?.cancel()
                searchDebounceTask = Task {
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    if Task.isCancelled { return }
                    debouncedSearchText = newValue
                }
            }
    }

    private var contentWithPendingSync: some View {
        contentWithSearchDebounce
            .onChange(of: installedSlugs) { _, newValue in
                pendingSkillInstalls.subtract(newValue)
                for slug in newValue {
                    skillInstallErrors.removeValue(forKey: slug)
                }
            }
            .onChange(of: installedWorkflowSlugs) { _, newValue in
                pendingWorkflowInstalls.subtract(newValue)
                for slug in newValue {
                    workflowInstallErrors.removeValue(forKey: slug)
                }
            }
            .onChange(of: installedMcpSlugs) { _, newValue in
                pendingMcpInstalls.subtract(newValue)
                for slug in newValue {
                    mcpInstallErrors.removeValue(forKey: slug)
                }
            }
    }

    private var contentWithDetailSheets: some View {
        contentWithPendingSync
            .onChange(of: viewModel.selectedSkillForDetail?.slug) { _, _ in
                guard let skill = viewModel.consumeSelectedSkillForDetail() else { return }
                SkillDetailWindowCoordinator.shared.presentRemote(
                    skill: skill,
                    providers: providers,
                    targetProvider: targetProvider,
                    onInstall: { provider in
                        onInstall(skill, provider)
                    }
                )
                openWindow(id: SkillDetailWindowCoordinator.windowID)
            }
            .sheet(item: $viewModel.selectedWorkflowForDetail) { workflow in
                RemoteWorkflowDetailView(
                    workflow: workflow,
                    providers: providers,
                    targetProvider: targetProvider,
                    onInstall: { provider in
                        onInstallWorkflow?(workflow, provider)
                    }
                )
                .frame(minWidth: 920, idealWidth: 1100, maxWidth: .infinity,
                       minHeight: 620, idealHeight: 720, maxHeight: .infinity)
            }
            .sheet(item: $viewModel.selectedMCPForDetail) { mcp in
                RemoteMCPDetailView(
                    mcp: mcp,
                    providers: providers,
                    targetProvider: targetProvider,
                    onInstall: { provider in
                        onInstallMCP?(mcp, provider)
                    }
                )
                .frame(minWidth: 920, idealWidth: 1100, maxWidth: .infinity,
                       minHeight: 620, idealHeight: 720, maxHeight: .infinity)
            }
            .sheet(item: $viewModel.deleteRequest) { request in
                let resourceSlug = request.resourceSlug
                let resourceType = request.resourceType
                ResourceDeleteTargetSheet(
                    resourceName: request.displayName,
                    resourceType: request.resourceType,
                    providers: providers,
                    preferredProvider: targetProvider
                ) { target in
                    Task {
                        await handleDeleteRequest(
                            resourceSlug: resourceSlug,
                            resourceType: resourceType,
                            target: target,
                            globalCachePathHint: request.localPath
                        )
                    }
                }
            }
            .confirmationDialog(
                NSLocalizedString(
                    "resource.delete.confirm.title",
                    value: "Delete from all providers?",
                    comment: "Delete all confirmation title"
                ),
                isPresented: isShowingDirectDeleteConfirmation,
                titleVisibility: .visible,
                presenting: viewModel.directDeleteConfirmationRequest
            ) { request in
                Button(NSLocalizedString("action.delete", value: "Delete", comment: "Delete action"), role: .destructive) {
                    viewModel.directDeleteConfirmationRequest = nil
                    Task {
                        await handleDeleteRequest(
                            resourceSlug: request.resourceSlug,
                            resourceType: request.resourceType,
                            target: request.defaultTarget ?? .allProvidersAndGlobalCache,
                            globalCachePathHint: request.localPath
                        )
                    }
                }
                Button(NSLocalizedString("Cancel", comment: "Cancel"), role: .cancel) {
                    viewModel.directDeleteConfirmationRequest = nil
                }
            } message: { _ in
                Text(
                    NSLocalizedString(
                        "resource.delete.confirm.message",
                        value: "This will remove the resource from all providers and delete global cache files.",
                        comment: "Delete all confirmation message"
                    )
                )
            }
            .alert(
                NSLocalizedString("action.delete", value: "Delete", comment: "Delete action"),
                isPresented: $viewModel.isShowingDeleteResultAlert
            ) {
                Button(NSLocalizedString("ok", value: "OK", comment: "OK")) {}
            } message: {
                Text(viewModel.deleteResultMessage)
            }
            .onChange(of: viewModel.directDeleteConfirmationRequest) { _, request in
                guard UITestSupport.shouldAutoConfirmDelete,
                      let request,
                      let target = request.defaultTarget else { return }
                viewModel.directDeleteConfirmationRequest = nil
                Task {
                    await handleDeleteRequest(
                        resourceSlug: request.resourceSlug,
                        resourceType: request.resourceType,
                        target: target,
                        globalCachePathHint: request.localPath
                    )
                }
            }
    }

    private func loadContent() async {
        if let repository {
            watchCenter.ensureWatching(repository: repository)
        }
        await viewModel.loadContent(
            for: repository,
            tab: selectedTab,
            searchQuery: normalizedSearchQuery,
            cacheBuster: cacheBuster
        )
    }

    private var isShowingDirectDeleteConfirmation: Binding<Bool> {
        SwiftUI.Binding(
            get: { viewModel.directDeleteConfirmationRequest != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.directDeleteConfirmationRequest = nil
                }
            }
        )
    }

    @ViewBuilder
    private var contentBody: some View {
        let hasAnyContent = !(viewModel.skills.isEmpty && viewModel.workflows.isEmpty && viewModel.mcps.isEmpty)
        if viewModel.isLoading && !hasAnyContent {
            Image(systemName: "arrow.triangle.2.circlepath")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DesignSystem.Colors.Status.info)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.errorMessage, !hasAnyContent {
            ContentUnavailableView {
                Label {
                    Text(NSLocalizedString("remote.error.title", value: "Error Loading Data", comment: "Remote load error title"))
                        .dsEmptyStateErrorTitle()
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .dsEmptyStateIcon(color: DesignSystem.Colors.Status.error)
                }
            } description: {
                Button {
                    #if os(macOS)
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(error, forType: .string)
                    #endif
                    showCopiedToast = true
                    Task { @MainActor in
                        try? await Task.sleep(nanoseconds: 1_200_000_000)
                        showCopiedToast = false
                    }
                } label: {
                    Text(error)
                        .dsSecondaryText(font: .body)
                }
                .buttonStyle(.plain)
            } actions: {
                Button {
                    retryTrigger += 1
                } label: {
                    Text(NSLocalizedString("remote.retry", value: "Retry", comment: "Retry"))
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 10) {
                if let error = viewModel.errorMessage, !error.isEmpty {
                    inlineErrorBanner(error)
                }
                gridContent
            }
        }
    }

    private func inlineErrorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(DesignSystem.Colors.Status.warning)
            Text(message)
                .font(.callout)
                .dsSecondaryText(font: .callout)
                .lineLimit(2)
            Spacer()
            Button(NSLocalizedString("remote.retry", value: "Retry", comment: "Retry")) {
                retryTrigger += 1
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .dsCard(
            background: DesignSystem.Colors.Status.warning.opacity(0.10),
            cornerRadius: DesignSystem.Metrics.cornerRadiusM,
            borderColor: DesignSystem.Colors.Status.warning.opacity(0.28),
            borderWidth: 1
        )
        .padding(.horizontal)
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            SearchField(
                placeholder: NSLocalizedString("remote.search.placeholder", value: "Search", comment: "Search placeholder"),
                text: $searchText,
                showSearching: isSearching
            )
            .frame(maxWidth: .infinity)

            if let onRefresh {
                topActionButton(
                    systemImage: "arrow.clockwise",
                    help: NSLocalizedString("Refresh", comment: "Refresh"),
                    action: onRefresh
                )
            }
            if let onClose {
                UIResourceCenterCloseButton(action: onClose)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private func topActionButton(
        systemImage: String,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .frame(width: 32, height: 32)
                .background(
                    Circle()
                        .fill(.white.opacity(0.1))
                        .background(
                            Circle()
                                .stroke(.white.opacity(0.1), lineWidth: 1)
                        )
                )
                .background(.ultraThinMaterial, in: Circle())
        }
        .buttonStyle(.plain)
        .help(help)
        .accessibilityLabel(help)
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.headline.weight(.semibold))
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .dsBadge(
                    foreground: DesignSystem.Colors.Text.secondary,
                    background: DesignSystem.Colors.Component.controlFillSubtle
                )
            Spacer()
        }
        .padding(.top, 2)
    }

    private func sectionBlock<Content: View>(
        _ title: String,
        count: Int,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader(title, count: count)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var gridContent: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                skillsGrid
            }
            .padding(.horizontal)
            .padding(.bottom)
            // 彻底移除这里的 .searchable
            if showCopiedToast {
                ToastView(
                    text: NSLocalizedString("remote.error.copied", value: "Copied", comment: "Copied tooltip"),
                    systemImage: "doc.on.doc",
                    style: .success
                )
                .padding(.trailing, 16)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showCopiedToast)
    }
    
    @ViewBuilder
    private var skillsGrid: some View {
        let shouldClientFilter = repository?.templateType != .clawdhub
        switch selectedTab {
        case .skills:
            let mergedSkills = mergeResourceCatalogSkills(
                catalogSkills: viewModel.skills,
                installedSkills: installedSkills,
                repositoryTemplateType: repository?.templateType
            )
            let filtered = filterResourceCatalogSkills(
                mergedSkills,
                searchText: shouldClientFilter ? searchText : normalizedSearchQuery
            )
            if filtered.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty
                    ? NSLocalizedString("skills.empty", comment: "No Skills")
                    : NSLocalizedString("remote.search.no_results", value: "No Results", comment: "No search results"),
                    systemImage: searchText.isEmpty ? "square.grid.2x2" : "magnifyingglass",
                    description: Text(
                        searchText.isEmpty
                        ? NSLocalizedString("skills.empty_desc", comment: "No skills in this repository")
                        : NSLocalizedString("remote.search.no_results_desc", value: "No matching skills found", comment: "No search results description")
                    )
                        .dsSecondaryText(font: .body)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let installed = filtered.filter { installedSlugs.contains($0.slug) }
                let pending = filtered.filter { pendingSkillInstalls.contains($0.slug) && !installedSlugs.contains($0.slug) }
                let available = filtered.filter { !installedSlugs.contains($0.slug) && !pendingSkillInstalls.contains($0.slug) }
                VStack(alignment: .leading, spacing: 20) {
                    if !installed.isEmpty {
                        sectionBlock(NSLocalizedString("remote.section.installed", value: "Installed", comment: "Installed section"), count: installed.count) {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(installed) { skill in
                                    RemoteSkillCardView(
                                        skill: skill,
                                        isInstalled: true,
                                        isInstalling: false,
                                        installErrorMessage: nil,
                                        targetProvider: targetProvider,
                                        providers: providers,
                                        onInstall: { provider in
                                            onInstall(skill, provider)
                                        },
                                        onDeleteRequest: {
                                            viewModel.requestDelete(
                                                skill: skill,
                                                repositoryTemplateType: repository?.templateType
                                            )
                                        },
                                        isDeleting: viewModel.pendingSkillDeletes.contains(skill.slug),
                                        onTap: {
                                            viewModel.requestSkillDetail(skill)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    if !pending.isEmpty {
                        sectionBlock(NSLocalizedString("remote.section.installing", value: "Installing", comment: "Installing section"), count: pending.count) {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(pending) { skill in
                                    RemoteSkillCardView(
                                        skill: skill,
                                        isInstalled: false,
                                        isInstalling: true,
                                        installErrorMessage: nil,
                                        targetProvider: targetProvider,
                                        providers: providers,
                                        onInstall: { _ in },
                                        onDeleteRequest: nil,
                                        isDeleting: false,
                                        onTap: {
                                            viewModel.requestSkillDetail(skill)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    if !available.isEmpty {
                        sectionBlock(NSLocalizedString("remote.section.available", value: "Available", comment: "Available section"), count: available.count) {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(available) { skill in
                                    RemoteSkillCardView(
                                        skill: skill,
                                        isInstalled: false,
                                        isInstalling: false,
                                        installErrorMessage: skillInstallErrors[skill.slug],
                                        targetProvider: targetProvider,
                                        providers: providers,
                                        onInstall: { provider in
                                            beginSkillInstall(skill, provider: provider)
                                        },
                                        onDeleteRequest: nil,
                                        isDeleting: false,
                                        onTap: {
                                            viewModel.requestSkillDetail(skill)
                                        }
                                    )
                                }
                            }
                        }
                    }
                    loadMoreRowIfNeeded
                }
            }
            
        case .workflows:
            let filtered = shouldClientFilter ? viewModel.filteredWorkflows(searchText: searchText) : viewModel.workflows
            if filtered.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty
                    ? NSLocalizedString("remote.workflows.empty", value: "No Workflows", comment: "No workflows")
                    : NSLocalizedString("remote.search.no_results", value: "No Results", comment: "No search results"),
                    systemImage: searchText.isEmpty ? "arrow.triangle.branch" : "magnifyingglass",
                    description: Text(
                        searchText.isEmpty
                        ? NSLocalizedString("remote.workflows.empty_desc", value: "No workflows in this repository", comment: "No workflows description")
                        : NSLocalizedString("remote.search.no_results_desc", value: "No matching workflows found", comment: "No search results description")
                    )
                        .dsSecondaryText(font: .body)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let installed = filtered.filter { installedWorkflowSlugs.contains($0.slug) }
                let pending = filtered.filter { pendingWorkflowInstalls.contains($0.slug) && !installedWorkflowSlugs.contains($0.slug) }
                let available = filtered.filter { !installedWorkflowSlugs.contains($0.slug) && !pendingWorkflowInstalls.contains($0.slug) }
                VStack(alignment: .leading, spacing: 20) {
                    if !installed.isEmpty {
                        sectionBlock(NSLocalizedString("remote.section.installed", value: "Installed", comment: "Installed section"), count: installed.count) {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(installed) { workflow in
                                    RemoteWorkflowCardView(
                                        workflow: workflow,
                                        isInstalled: true,
                                        isInstalling: false,
                                        installErrorMessage: nil,
                                        isSelected: viewModel.selectedWorkflowForDetail?.slug == workflow.slug,
                                        targetProvider: targetProvider,
                                        providers: providers,
                                        onInstall: { provider in
                                            onInstallWorkflow?(workflow, provider)
                                        },
                                        onDeleteRequest: {
                                            viewModel.requestDelete(
                                                workflow: workflow,
                                                repositoryTemplateType: repository?.templateType
                                            )
                                        },
                                        isDeleting: viewModel.pendingWorkflowDeletes.contains(workflow.slug),
                                        onTap: {
                                            viewModel.selectedWorkflowForDetail = workflow
                                        }
                                    )
                                }
                            }
                        }
                    }
                    if !pending.isEmpty {
                        sectionBlock(NSLocalizedString("remote.section.installing", value: "Installing", comment: "Installing section"), count: pending.count) {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(pending) { workflow in
                                    RemoteWorkflowCardView(
                                        workflow: workflow,
                                        isInstalled: false,
                                        isInstalling: true,
                                        installErrorMessage: nil,
                                        isSelected: viewModel.selectedWorkflowForDetail?.slug == workflow.slug,
                                        targetProvider: targetProvider,
                                        providers: providers,
                                        onInstall: { _ in },
                                        onDeleteRequest: nil,
                                        isDeleting: false,
                                        onTap: {
                                            viewModel.selectedWorkflowForDetail = workflow
                                        }
                                    )
                                }
                            }
                        }
                    }
                    if !available.isEmpty {
                        sectionBlock(NSLocalizedString("remote.section.available", value: "Available", comment: "Available section"), count: available.count) {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(available) { workflow in
                                    RemoteWorkflowCardView(
                                        workflow: workflow,
                                        isInstalled: false,
                                        isInstalling: false,
                                        installErrorMessage: workflowInstallErrors[workflow.slug],
                                        isSelected: viewModel.selectedWorkflowForDetail?.slug == workflow.slug,
                                        targetProvider: targetProvider,
                                        providers: providers,
                                        onInstall: { provider in
                                            beginWorkflowInstall(workflow, provider: provider)
                                        },
                                        onDeleteRequest: nil,
                                        isDeleting: false,
                                        onTap: {
                                            viewModel.selectedWorkflowForDetail = workflow
                                        }
                                    )
                                }
                            }
                        }
                    }
                    loadMoreRowIfNeeded
                }
            }
            
        case .mcps:
            let filtered = shouldClientFilter ? viewModel.filteredMCPs(searchText: searchText) : viewModel.mcps
            if filtered.isEmpty {
                ContentUnavailableView(
                    searchText.isEmpty
                    ? NSLocalizedString("remote.mcps.empty", value: "No MCPs", comment: "No MCPs")
                    : NSLocalizedString("remote.search.no_results", value: "No Results", comment: "No search results"),
                    systemImage: searchText.isEmpty ? "server.rack" : "magnifyingglass",
                    description: Text(
                        searchText.isEmpty
                        ? NSLocalizedString("remote.mcps.empty_desc", value: "No MCPs in this repository", comment: "No MCPs description")
                        : NSLocalizedString("remote.search.no_results_desc", value: "No matching MCPs found", comment: "No search results description")
                    )
                        .dsSecondaryText(font: .body)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                let installed = filtered.filter { installedMcpSlugs.contains($0.slug) }
                let pending = filtered.filter { pendingMcpInstalls.contains($0.slug) && !installedMcpSlugs.contains($0.slug) }
                let available = filtered.filter { !installedMcpSlugs.contains($0.slug) && !pendingMcpInstalls.contains($0.slug) }
                VStack(alignment: .leading, spacing: 20) {
                    if !installed.isEmpty {
                        sectionBlock(NSLocalizedString("remote.section.installed", value: "Installed", comment: "Installed section"), count: installed.count) {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(installed) { mcp in
                                    RemoteMCPCardView(
                                        mcp: mcp,
                                        isInstalled: true,
                                        isInstalling: false,
                                        installErrorMessage: nil,
                                        isSelected: viewModel.selectedMCPForDetail?.slug == mcp.slug,
                                        targetProvider: targetProvider,
                                        providers: providers,
                                        onInstall: { provider in
                                            onInstallMCP?(mcp, provider)
                                        },
                                        onDeleteRequest: {
                                            viewModel.requestDelete(
                                                mcp: mcp,
                                                repositoryTemplateType: repository?.templateType
                                            )
                                        },
                                        isDeleting: viewModel.pendingMcpDeletes.contains(mcp.slug),
                                        onTap: {
                                            viewModel.selectedMCPForDetail = mcp
                                        }
                                    )
                                }
                            }
                        }
                    }
                    if !pending.isEmpty {
                        sectionBlock(NSLocalizedString("remote.section.installing", value: "Installing", comment: "Installing section"), count: pending.count) {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(pending) { mcp in
                                    RemoteMCPCardView(
                                        mcp: mcp,
                                        isInstalled: false,
                                        isInstalling: true,
                                        installErrorMessage: nil,
                                        isSelected: viewModel.selectedMCPForDetail?.slug == mcp.slug,
                                        targetProvider: targetProvider,
                                        providers: providers,
                                        onInstall: { _ in },
                                        onDeleteRequest: nil,
                                        isDeleting: false,
                                        onTap: {
                                            viewModel.selectedMCPForDetail = mcp
                                        }
                                    )
                                }
                            }
                        }
                    }
                    if !available.isEmpty {
                        sectionBlock(NSLocalizedString("remote.section.available", value: "Available", comment: "Available section"), count: available.count) {
                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(available) { mcp in
                                    RemoteMCPCardView(
                                        mcp: mcp,
                                        isInstalled: false,
                                        isInstalling: false,
                                        installErrorMessage: mcpInstallErrors[mcp.slug],
                                        isSelected: viewModel.selectedMCPForDetail?.slug == mcp.slug,
                                        targetProvider: targetProvider,
                                        providers: providers,
                                        onInstall: { provider in
                                            beginMCPInstall(mcp, provider: provider)
                                        },
                                        onDeleteRequest: nil,
                                        isDeleting: false,
                                        onTap: {
                                            viewModel.selectedMCPForDetail = mcp
                                        }
                                    )
                                }
                            }
                        }
                    }
                    loadMoreRowIfNeeded
                }
            }
            
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private var loadMoreRowIfNeeded: some View {
        if repository?.templateType != .clawdhub {
            EmptyView()
        } else if let message = viewModel.loadMoreErrorMessage, !message.isEmpty {
            loadMoreFooter {
                VStack(spacing: 8) {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(DesignSystem.Colors.Status.error)
                        .multilineTextAlignment(.center)
                    Button {
                        Task {
                            await viewModel.loadMore(
                                repository: repository,
                                tab: selectedTab,
                                searchQuery: normalizedSearchQuery
                            )
                        }
                    } label: {
                        Text(NSLocalizedString("remote.retry", value: "Retry", comment: "Retry"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .frame(maxWidth: 220)
                }
            }
        } else if viewModel.canLoadMore {
            loadMoreFooter {
                Button {
                    Task {
                        await viewModel.loadMore(
                            repository: repository,
                            tab: selectedTab,
                            searchQuery: normalizedSearchQuery
                        )
                    }
                } label: {
                    HStack(spacing: 8) {
                        if viewModel.isLoadingMore {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(DesignSystem.Colors.Status.info)
                        }
                        Text(
                            viewModel.isLoadingMore
                            ? NSLocalizedString("remote.load_more.loading", value: "Loading...", comment: "Loading more indicator")
                            : NSLocalizedString("remote.load_more", value: "Load More", comment: "Load more")
                        )
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
                .buttonStyle(.bordered)
                .disabled(viewModel.isLoadingMore)
                .frame(maxWidth: 240)
                .onAppear {
                    guard !viewModel.isLoadingMore else { return }
                    Task {
                        await viewModel.loadMore(
                            repository: repository,
                            tab: selectedTab,
                            searchQuery: normalizedSearchQuery
                        )
                    }
                }
            }
        } else if !viewModel.isLoading && !(viewModel.skills.isEmpty && viewModel.workflows.isEmpty && viewModel.mcps.isEmpty) {
            loadMoreFooter {
                Text(NSLocalizedString("remote.load_more.end", value: "You have reached the end.", comment: "End of list"))
                    .dsSecondaryText(font: .callout)
            }
        }
    }

    private func loadMoreFooter<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack {
            Spacer(minLength: 0)
            content()
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    private func beginSkillInstall(_ skill: RemoteSkill, provider: Provider) {
        Self.logger.info(
            "UI install click(skill). slug=\(skill.slug, privacy: .public) provider=\(provider.id, privacy: .public)"
        )
        skillInstallErrors.removeValue(forKey: skill.slug)
        pendingSkillInstalls.insert(skill.slug)
        onInstall(skill, provider)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.installTimeoutNanoseconds)
            guard pendingSkillInstalls.contains(skill.slug) else { return }
            pendingSkillInstalls.remove(skill.slug)
            if !installedSlugs.contains(skill.slug) {
                Self.logger.error(
                    "UI install timeout(skill). slug=\(skill.slug, privacy: .public) provider=\(provider.id, privacy: .public)"
                )
                skillInstallErrors[skill.slug] = NSLocalizedString(
                    "remote.install.failed.hint",
                    value: "Install timed out. Click Retry.",
                    comment: "Remote install failed hint"
                )
            }
        }
    }

    private func beginWorkflowInstall(_ workflow: RemoteWorkflow, provider: Provider) {
        Self.logger.info(
            "UI install click(workflow). slug=\(workflow.slug, privacy: .public) provider=\(provider.id, privacy: .public)"
        )
        workflowInstallErrors.removeValue(forKey: workflow.slug)
        pendingWorkflowInstalls.insert(workflow.slug)
        onInstallWorkflow?(workflow, provider)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.installTimeoutNanoseconds)
            guard pendingWorkflowInstalls.contains(workflow.slug) else { return }
            pendingWorkflowInstalls.remove(workflow.slug)
            if !installedWorkflowSlugs.contains(workflow.slug) {
                Self.logger.error(
                    "UI install timeout(workflow). slug=\(workflow.slug, privacy: .public) provider=\(provider.id, privacy: .public)"
                )
                workflowInstallErrors[workflow.slug] = NSLocalizedString(
                    "remote.install.failed.hint",
                    value: "Install timed out. Click Retry.",
                    comment: "Remote install failed hint"
                )
            }
        }
    }

    private func beginMCPInstall(_ mcp: RemoteMCP, provider: Provider) {
        Self.logger.info(
            "UI install click(mcp). slug=\(mcp.slug, privacy: .public) provider=\(provider.id, privacy: .public)"
        )
        mcpInstallErrors.removeValue(forKey: mcp.slug)
        pendingMcpInstalls.insert(mcp.slug)
        onInstallMCP?(mcp, provider)
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: Self.installTimeoutNanoseconds)
            guard pendingMcpInstalls.contains(mcp.slug) else { return }
            pendingMcpInstalls.remove(mcp.slug)
            if !installedMcpSlugs.contains(mcp.slug) {
                Self.logger.error(
                    "UI install timeout(mcp). slug=\(mcp.slug, privacy: .public) provider=\(provider.id, privacy: .public)"
                )
                mcpInstallErrors[mcp.slug] = NSLocalizedString(
                    "remote.install.failed.hint",
                    value: "Install timed out. Click Retry.",
                    comment: "Remote install failed hint"
                )
            }
        }
    }

    @MainActor
    private func handleDeleteRequest(
        resourceSlug: String,
        resourceType: RemoteContentType,
        target: ResourceDeleteTarget,
        globalCachePathHint: String? = nil
    ) async {
        await viewModel.executeDelete(
            resourceSlug: resourceSlug,
            resourceType: resourceType,
            target: target,
            globalCachePathHint: globalCachePathHint,
            providers: providers,
            onRegisterDeleteRequest: onRegisterDeleteRequest,
            onMakeDeleteRequestExecutor: onMakeDeleteRequestExecutor,
            onRefresh: onRefresh
        )
    }
}

func mergeResourceCatalogSkills(
    catalogSkills: [RemoteSkill],
    installedSkills: [RemoteSkill],
    repositoryTemplateType: RepositoryTemplate?
) -> [RemoteSkill] {
    guard repositoryTemplateType == .clawdhub else {
        return catalogSkills
    }
    let catalogSlugs = Set(catalogSkills.map(\.slug))
    let installedOnly = installedSkills.filter { !catalogSlugs.contains($0.slug) }
    return catalogSkills + installedOnly
}

func filterResourceCatalogSkills(
    _ skills: [RemoteSkill],
    searchText: String
) -> [RemoteSkill] {
    let trimmedQuery = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedQuery.isEmpty else { return skills }
    return skills.filter { skill in
        skill.displayName.localizedStandardContains(trimmedQuery)
        || (skill.summary?.localizedStandardContains(trimmedQuery) ?? false)
    }
}
