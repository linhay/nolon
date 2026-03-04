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

    private static func makeClawdhubRepository() -> RemoteRepository {
        RemoteRepository(
            id: "repo-clawdhub",
            name: "Clawdhub",
            baseURL: "https://clawdhub.com",
            templateType: .clawdhub,
            isBuiltIn: true
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
