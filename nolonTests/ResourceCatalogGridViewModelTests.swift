import XCTest
import NolonResourceKit
import ProviderCatalog
@testable import nolon

final class ResourceCatalogGridViewModelTests: XCTestCase {
    @MainActor
    func testLoadContentMCPs_IncludesBuiltInXcodeMCPKitPlugin() async {
        let service = MockRemoteCatalogQueryService(
            responses: [
                .success(
                    .init(
                        items: [],
                        canLoadMore: false
                    )
                )
            ]
        )
        let viewModel = ResourceCatalogGridViewModel(queryService: service)
        let repository = Self.makeClawdhubRepository()

        await viewModel.loadContent(
            for: repository,
            tab: ResourceContentTabType.mcps,
            searchQuery: "",
            cacheBuster: "v1"
        )

        let plugin = viewModel.mcps.first(where: { $0.slug == "xcodemcpkit" })
        XCTAssertNotNil(plugin)
        XCTAssertEqual(plugin?.displayName, "XcodeMCPKit")
        XCTAssertEqual(plugin?.configuration?.command, "xcode-mcp-server")
    }

    @MainActor
    func testLoadContentFailure_WithCachedItems_KeepsContentAndShowsInlineError() async {
        let service = MockRemoteCatalogQueryService(
            responses: [
                .success(
                    .init(
                        items: [Self.makeSkillItem(slug: "skill-a")],
                        canLoadMore: true
                    )
                ),
                .failure(TestError(message: "network down"))
            ]
        )
        let viewModel = ResourceCatalogGridViewModel(queryService: service)
        let repository = Self.makeClawdhubRepository()

        await viewModel.loadContent(for: repository, tab: ResourceContentTabType.skills, searchQuery: "", cacheBuster: "v1")
        XCTAssertEqual(viewModel.skills.count, 1)
        XCTAssertTrue(viewModel.canLoadMore)

        await viewModel.loadContent(for: repository, tab: ResourceContentTabType.skills, searchQuery: "", cacheBuster: "v2")

        XCTAssertEqual(viewModel.skills.count, 1)
        XCTAssertEqual(viewModel.skills.first?.slug, "skill-a")
        XCTAssertEqual(viewModel.errorMessage, "network down")
        XCTAssertTrue(viewModel.canLoadMore)
    }

    @MainActor
    func testLoadMoreFailure_UsesLoadMoreErrorWithoutReplacingMainError() async {
        let service = MockRemoteCatalogQueryService(
            responses: [
                .success(
                    .init(
                        items: [Self.makeSkillItem(slug: "skill-a")],
                        canLoadMore: true
                    )
                ),
                .failure(TestError(message: "load more failed"))
            ]
        )
        let viewModel = ResourceCatalogGridViewModel(queryService: service)
        let repository = Self.makeClawdhubRepository()

        await viewModel.loadContent(for: repository, tab: ResourceContentTabType.skills, searchQuery: "", cacheBuster: "v1")
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertTrue(viewModel.canLoadMore)

        await viewModel.loadMore(repository: repository, tab: ResourceContentTabType.skills, searchQuery: "")

        XCTAssertEqual(viewModel.skills.count, 1)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertEqual(viewModel.loadMoreErrorMessage, "load more failed")
    }

    @MainActor
    func testExecuteDelete_Skill_TracksPendingStateAndPresentsResult() async {
        let viewModel = ResourceCatalogGridViewModel()
        let providers = [Self.makeProvider(id: "provider-a", name: "Provider A")]
        var refreshed = false
        var capturedRequestID: Int?
        var nextRequestID = 40

        await viewModel.executeDelete(
            resourceSlug: "gemini",
            resourceType: .skill,
            target: .provider("provider-a"),
            providers: providers,
            onRegisterDeleteRequest: { slug, resourceType, providerIndex, removeGlobalCache, globalCachePathHint in
                XCTAssertEqual(slug, "gemini")
                XCTAssertEqual(resourceType, .skill)
                XCTAssertEqual(providerIndex, 0)
                XCTAssertFalse(removeGlobalCache)
                XCTAssertNil(globalCachePathHint)
                let requestID = nextRequestID
                nextRequestID += 1
                capturedRequestID = requestID
                return requestID
            },
            onMakeDeleteRequestExecutor: { requestID in
                XCTAssertEqual(requestID, capturedRequestID)
                return {
                    XCTAssertTrue(viewModel.pendingSkillDeletes.contains("gemini"))
                    return ResourceDeleteExecutionResult(
                        resourceSlug: "",
                        resourceType: .skill,
                        attemptedCount: 1,
                        successCount: 1,
                        removedGlobalCache: false,
                        failures: []
                    )
                }
            },
            onRefresh: {
                refreshed = true
            },
            localized: { key, fallback in
                switch key {
                case "tab.skills":
                    return "Skills"
                case "resource.delete.result.success":
                    return "%1$@ \"%2$@\" deleted. Removed from %3$ld provider(s)."
                default:
                    return fallback
                }
            },
            preferredLanguages: { ["en"] }
        )

        XCTAssertFalse(viewModel.pendingSkillDeletes.contains("gemini"))
        XCTAssertEqual(viewModel.deleteResultMessage, "Skills \"gemini\" deleted. Removed from 1 provider(s).")
        XCTAssertTrue(viewModel.isShowingDeleteResultAlert)
        XCTAssertTrue(refreshed)
    }

    @MainActor
    func testBDD_GivenGlobalSkillsRepositoryDelete_WhenRequestDelete_ThenUseDirectGlobalConfirmationAndKeepPathHint() async {
        let viewModel = ResourceCatalogGridViewModel()
        let skill = RemoteSkill(
            slug: "gemini",
            displayName: "Gemini CLI",
            summary: "summary",
            latestVersion: "1.0.0",
            updatedAt: Date(timeIntervalSince1970: 0),
            downloads: 1,
            stars: 2,
            localPath: "/tmp/.nolon/skills/gemini"
        )

        viewModel.requestDelete(skill: skill, repositoryTemplateType: .globalSkills)

        XCTAssertNil(viewModel.deleteRequest)
        XCTAssertEqual(viewModel.directDeleteConfirmationRequest?.resourceSlug, "gemini")
        XCTAssertEqual(viewModel.directDeleteConfirmationRequest?.localPath, "/tmp/.nolon/skills/gemini")
        XCTAssertEqual(viewModel.directDeleteConfirmationRequest?.defaultTarget, .allProvidersAndGlobalCache)
    }

    @MainActor
    func testBDD_GivenGlobalDeleteExecution_WhenExecuteDelete_ThenPlanCarriesPathHint() async {
        let viewModel = ResourceCatalogGridViewModel()
        let providers = [Self.makeProvider(id: "provider-a", name: "Provider A")]

        await viewModel.executeDelete(
            resourceSlug: "gemini",
            resourceType: .skill,
            target: .allProvidersAndGlobalCache,
            globalCachePathHint: "/tmp/.nolon/skills/gemini",
            providers: providers,
            onRegisterDeleteRequest: { _, resourceType, providerIndex, removeGlobalCache, globalCachePathHint in
                XCTAssertEqual(resourceType, .skill)
                XCTAssertNil(providerIndex)
                XCTAssertTrue(removeGlobalCache)
                XCTAssertEqual(globalCachePathHint, "/tmp/.nolon/skills/gemini")
                return 99
            },
            onMakeDeleteRequestExecutor: { requestID in
                XCTAssertEqual(requestID, 99)
                return {
                    ResourceDeleteExecutionResult(
                        resourceSlug: "",
                        resourceType: .skill,
                        attemptedCount: 1,
                        successCount: 1,
                        removedGlobalCache: true,
                        failures: []
                    )
                }
            },
            preferredLanguages: { ["en"] }
        )
    }

    @MainActor
    func testBDD_GivenDeleteExecutorFactory_WhenExecuteDelete_ThenRequestIDNeverCrossesAsyncBoundary() async {
        let viewModel = ResourceCatalogGridViewModel()
        let providers = [Self.makeProvider(id: "provider-a", name: "Provider A")]
        var registeredIDs: [Int] = []
        var executedClosures = 0

        await viewModel.executeDelete(
            resourceSlug: "gemini",
            resourceType: .skill,
            target: .provider("provider-a"),
            providers: providers,
            onRegisterDeleteRequest: { _, _, providerIndex, removeGlobalCache, _ in
                XCTAssertEqual(providerIndex, 0)
                XCTAssertFalse(removeGlobalCache)
                registeredIDs.append(41)
                return 41
            },
            onMakeDeleteRequestExecutor: { requestID in
                XCTAssertEqual(requestID, 41)
                return {
                    executedClosures += 1
                    return ResourceDeleteExecutionResult(
                        resourceSlug: "",
                        resourceType: .skill,
                        attemptedCount: 1,
                        successCount: 1,
                        removedGlobalCache: false,
                        failures: []
                    )
                }
            },
            preferredLanguages: { ["en"] }
        )

        XCTAssertEqual(registeredIDs, [41])
        XCTAssertEqual(executedClosures, 1)
    }

    private static func makeClawdhubRepository() -> RemoteRepository {
        RemoteRepository(
            id: "repo-clawdhub",
            name: "Clawdhub",
            baseURL: "https://clawdhub.com",
            templateType: .clawdhub,
            isBuiltIn: true
        )
    }

    private static func makeProvider(id: String, name: String) -> Provider {
        Provider(
            id: id,
            name: name,
            defaultSkillsPath: "/tmp/\(id)/skills",
            workflowPath: "/tmp/\(id)/workflows",
            installMethod: .symlink,
            templateId: nil
        )
    }

    private static func makeSkillItem(slug: String) -> SkillsRepositoryFacade.RemoteCatalogItem {
        SkillsRepositoryFacade.RemoteCatalogItem(
            kind: .skill,
            slug: slug,
            displayName: slug,
            summary: "summary",
            latestVersion: "1.0.0",
            updatedAt: nil,
            downloads: 1,
            stars: 1,
            installs: nil,
            localPath: nil
        )
    }
}

private final class MockRemoteCatalogQueryService: RemoteCatalogQueryServing {
    enum Response {
        case success(RemoteCatalogQueryResult)
        case failure(Error)
    }

    private var responses: [Response]
    private var index: Int = 0

    init(responses: [Response]) {
        self.responses = responses
    }

    func query(
        repository: RemoteRepository,
        kind: SkillsRepositoryFacade.RemoteCatalogKind,
        query: String?,
        limit: Int
    ) async throws -> RemoteCatalogQueryResult {
        guard index < responses.count else {
            throw TestError(message: "mock response exhausted")
        }
        let response = responses[index]
        index += 1
        switch response {
        case let .success(result):
            return result
        case let .failure(error):
            throw error
        }
    }
}

private struct TestError: LocalizedError {
    let message: String

    var errorDescription: String? {
        message
    }
}
