import XCTest
import NolonResourceKit
@testable import nolon

final class ResourceCenterRepositoryVisibilityTests: XCTestCase {
    func testBDD_GivenBuiltInGlobalAndClawdhub_WhenResolveVisibleRepositories_ThenGlobalIsHidden() {
        let visible = resourceCenterVisibleRepositories([.globalSkills, .clawdhub])

        XCTAssertEqual(visible.map(\.templateType), [.clawdhub])
    }

    func testBDD_GivenGitHubRepository_WhenBuildDisplayName_ThenShowsRepoNameOnly() {
        let repository = RemoteRepository(
            name: "fallback",
            templateType: .git,
            gitURL: "https://github.com/openai/super-long-repository-name-for-testing-layout.git"
        )

        XCTAssertEqual(
            repositoryDisplayName(repository),
            "super-long-repository-name-for-testing-layout"
        )
        XCTAssertEqual(repositorySecondaryLine(repository), "openai")
    }

    func testBDD_GivenGitLabRepository_WhenBuildDisplayName_ThenShowsRepoNameOnly() {
        let repository = RemoteRepository(
            name: "fallback",
            templateType: .git,
            gitURL: "https://gitlab.com/flowup/tooling-repository.git"
        )

        XCTAssertEqual(repositoryDisplayName(repository), "tooling-repository")
        XCTAssertEqual(repositorySecondaryLine(repository), "flowup")
    }
}
