import XCTest
import NolonResourceKit
@testable import nolon

@MainActor
final class MainSplitViewModelTests: XCTestCase {
    private var fixture: TestFixture!

    override func setUpWithError() throws {
        fixture = try TestFixture()
    }

    override func tearDownWithError() throws {
        fixture.cleanup()
    }

    func testResourceCenterOverlayOuterInset_IsForty() {
        XCTAssertEqual(ResourceCenterOverlayLayout.outerInset, 40)
    }

    func testBDD_GivenGlobalSkill_WhenDeleteRemoteSkillWithGlobalCachePlan_ThenFolderAndInstalledStateDisappear() async throws {
        let source = try fixture.createSampleSkill(id: "gemini", name: "Gemini")
        let repository = SkillRepository(nolonManager: fixture.nolonManager)
        _ = try repository.importSkill(from: source)

        let viewModel = MainSplitViewModel(
            settings: fixture.providerSettings,
            repository: repository,
            nolonManager: fixture.nolonManager
        )
        let statusService = InstalledResourceStatusService(nolonManager: fixture.nolonManager)

        XCTAssertTrue(fixture.fileManager.fileExists(atPath: fixture.nolonManager.skillsURL.appendingPathComponent("gemini").path))
        XCTAssertEqual(
            try statusService.installedSkillIDs(
                provider: nil,
                repository: repository,
                settings: fixture.providerSettings
            ),
            ["gemini"]
        )

        let result = await viewModel.deleteRemoteSkill(
            slug: "gemini",
            providerIndex: nil,
            removeGlobalCache: true,
            globalCachePathHint: nil
        )

        XCTAssertTrue(result.removedGlobalCache)
        XCTAssertFalse(fixture.fileManager.fileExists(atPath: fixture.nolonManager.skillsURL.appendingPathComponent("gemini").path))
        XCTAssertEqual(
            try statusService.installedSkillIDs(
                provider: nil,
                repository: repository,
                settings: fixture.providerSettings
            ),
            []
        )
    }

    func testBDD_GivenHintedGlobalSkillPath_WhenDeleteRemoteSkillWithGlobalCachePlan_ThenHintedFolderDisappears() async throws {
        let hintedRoot = fixture.tempRoot.appendingPathComponent("hinted-root", isDirectory: true)
        let hintedSkillFolder = hintedRoot.appendingPathComponent("gemini", isDirectory: true)
        try fixture.fileManager.createDirectory(at: hintedSkillFolder, withIntermediateDirectories: true)
        try """
        ---
        name: Gemini
        description: hinted skill
        version: 1.0.0
        ---
        """.write(
            to: hintedSkillFolder.appendingPathComponent("SKILL.md"),
            atomically: true,
            encoding: .utf8
        )

        let viewModel = MainSplitViewModel(
            settings: fixture.providerSettings,
            repository: SkillRepository(nolonManager: fixture.nolonManager),
            nolonManager: fixture.nolonManager
        )

        let result = await viewModel.deleteRemoteSkill(
            slug: "gemini",
            providerIndex: nil,
            removeGlobalCache: true,
            globalCachePathHint: hintedSkillFolder.path
        )

        XCTAssertTrue(result.removedGlobalCache)
        XCTAssertFalse(fixture.fileManager.fileExists(atPath: hintedSkillFolder.path))
    }

    func testBDD_GivenRegisteredGlobalDeleteRequest_WhenExecuteRegisteredDeleteRequest_ThenFolderDisappears() async throws {
        let source = try fixture.createSampleSkill(id: "gemini", name: "Gemini")
        let repository = SkillRepository(nolonManager: fixture.nolonManager)
        _ = try repository.importSkill(from: source)

        let viewModel = MainSplitViewModel(
            settings: fixture.providerSettings,
            repository: repository,
            nolonManager: fixture.nolonManager
        )

        let requestID = viewModel.registerDeleteRequest(
            slug: "gemini",
            resourceType: .skill,
            providerIndex: nil,
            removeGlobalCache: true,
            globalCachePathHint: nil
        )

        let result = await viewModel.executeRegisteredDeleteRequest(id: requestID)

        XCTAssertTrue(result.removedGlobalCache)
        XCTAssertFalse(fixture.fileManager.fileExists(atPath: fixture.nolonManager.skillsURL.appendingPathComponent("gemini").path))
    }

    func testBDD_GivenExecutedDeleteRequest_WhenExecuteRegisteredDeleteRequestAgain_ThenReusePreviousResult() async throws {
        let source = try fixture.createSampleSkill(id: "gemini", name: "Gemini")
        let repository = SkillRepository(nolonManager: fixture.nolonManager)
        _ = try repository.importSkill(from: source)

        let viewModel = MainSplitViewModel(
            settings: fixture.providerSettings,
            repository: repository,
            nolonManager: fixture.nolonManager
        )

        let requestID = viewModel.registerDeleteRequest(
            slug: "gemini",
            resourceType: .skill,
            providerIndex: nil,
            removeGlobalCache: true,
            globalCachePathHint: nil
        )

        let firstResult = await viewModel.executeRegisteredDeleteRequest(id: requestID)
        let secondResult = await viewModel.executeRegisteredDeleteRequest(id: requestID)

        XCTAssertEqual(secondResult, firstResult)
        XCTAssertTrue(secondResult.removedGlobalCache)
        XCTAssertFalse(secondResult.hasFailure)
    }

    func testBDD_GivenConcurrentDeleteExecutions_WhenExecuteRegisteredDeleteRequestTwice_ThenReuseInFlightResult() async throws {
        let source = try fixture.createSampleSkill(id: "gemini", name: "Gemini")
        let repository = SkillRepository(nolonManager: fixture.nolonManager)
        _ = try repository.importSkill(from: source)

        let viewModel = MainSplitViewModel(
            settings: fixture.providerSettings,
            repository: repository,
            nolonManager: fixture.nolonManager
        )

        let requestID = viewModel.registerDeleteRequest(
            slug: "gemini",
            resourceType: .skill,
            providerIndex: nil,
            removeGlobalCache: true,
            globalCachePathHint: nil
        )

        async let firstResult = viewModel.executeRegisteredDeleteRequest(id: requestID)
        async let secondResult = viewModel.executeRegisteredDeleteRequest(id: requestID)
        let results = try await [firstResult, secondResult]

        XCTAssertEqual(results[0], results[1])
        XCTAssertTrue(results[0].removedGlobalCache)
        XCTAssertFalse(results[0].hasFailure)
        XCTAssertFalse(fixture.fileManager.fileExists(atPath: fixture.nolonManager.skillsURL.appendingPathComponent("gemini").path))
    }

    func testBDD_GivenInvalidDeleteCombination_WhenDeleteRemoteSkill_ThenReturnFailureWithoutCrash() async {
        let viewModel = MainSplitViewModel(
            settings: fixture.providerSettings,
            repository: SkillRepository(nolonManager: fixture.nolonManager),
            nolonManager: fixture.nolonManager
        )

        let result = await viewModel.deleteRemoteSkill(
            slug: "gemini",
            providerIndex: nil,
            removeGlobalCache: false,
            globalCachePathHint: nil
        )

        XCTAssertEqual(result.attemptedCount, 0)
        XCTAssertEqual(result.successCount, 0)
        XCTAssertFalse(result.removedGlobalCache)
        XCTAssertEqual(result.failures.first?.targetName, "Delete Request")
    }
}
