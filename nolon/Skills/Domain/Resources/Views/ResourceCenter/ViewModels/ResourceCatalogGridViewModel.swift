import SwiftUI
import ProviderCatalog
import NolonResourceKit
import Observation
import OSLog

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

    private func mapKind(_ tab: ResourceCenterTabID) -> SkillsRepositoryFacade.RemoteCatalogKind {
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
    
    func loadContent(for repository: RemoteRepository?, tab: ResourceCenterTabID?, searchQuery: String, cacheBuster: String) async {
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

    func loadMore(repository: RemoteRepository?, tab: ResourceCenterTabID?, searchQuery: String) async {
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

    private func applyCached(_ cached: RemoteCatalogPageEntry, for tab: ResourceCenterTabID) {
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

