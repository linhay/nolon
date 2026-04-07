import XCTest
import NolonResourceKit
import ProviderCatalog
@testable import nolon

@MainActor
final class MainSplitViewModelTests: XCTestCase {
    private var fixture: TestFixture!

    override func setUpWithError() throws {
        fixture = try TestFixture()
        UITestSupport.environmentOverride = nil
    }

    override func tearDownWithError() throws {
        UITestSupport.environmentOverride = nil
        fixture.cleanup()
    }

    func testResourceCenterWindowID_IsStable() {
        XCTAssertEqual(ResourceCenterWindowCoordinator.windowID, "resource-center")
    }

    func testBDD_GivenNolonSelectionKey_WhenNormalize_ThenKeyIsRetained() {
        let normalized = MainSplitViewModel.normalizedSidebarSelectionKey(
            MainSidebarSelection.nolon.storageKey,
            providers: fixture.providerSettings.providers
        )

        XCTAssertEqual(normalized, MainSidebarSelection.nolon.storageKey)
    }

    func testBDD_GivenFixtureProviders_WhenLookingUpCodexIndex_ThenLookupSucceedsWithoutSetup() {
        let codexIndex = fixture.providerSettings.providers.firstIndex { $0.templateId == "codex" }
        XCTAssertNotNil(codexIndex)
    }

    func testBDD_GivenUITestLaunchSelection_WhenEnvironmentOverrideIsAssigned_ThenAssignmentSucceeds() {
        let codexIndex = fixture.providerSettings.providers.firstIndex { $0.templateId == "codex" }
        XCTAssertNotNil(codexIndex)

        UITestSupport.environmentOverride = [
            "NOLON_UI_TEST_SELECTED_PROVIDER_INDEX": String(codexIndex!),
            "NOLON_UI_TEST_SELECTED_PROVIDER_TAB": "usage"
        ]

        XCTAssertEqual(UITestSupport.initialSelectedProviderIndex, codexIndex)
        XCTAssertEqual(UITestSupport.initialSelectedProviderTab, .usage)
    }

    func testBDD_GivenFixtureDependencies_WhenSkillInstallerConstructs_ThenConstructionSucceeds() {
        _ = SkillInstaller(
            repository: SkillRepository(nolonManager: fixture.nolonManager),
            settings: fixture.providerSettings,
            nolonManager: fixture.nolonManager
        )
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

    func testBDD_GivenGlobalWorkflow_WhenDeleteRemoteWorkflowWithGlobalCachePlan_ThenFileDisappears() async throws {
        let workflowURL = fixture.nolonManager.userWorkflowsURL.appendingPathComponent("daily-sync.md")
        try "# Daily Sync\n".write(to: workflowURL, atomically: true, encoding: .utf8)

        let viewModel = MainSplitViewModel(
            settings: fixture.providerSettings,
            repository: SkillRepository(nolonManager: fixture.nolonManager),
            nolonManager: fixture.nolonManager
        )

        let result = await viewModel.deleteRemoteWorkflow(
            slug: "daily-sync",
            providerIndex: nil,
            removeGlobalCache: true,
            globalCachePathHint: nil
        )

        XCTAssertTrue(result.removedGlobalCache)
        XCTAssertFalse(fixture.fileManager.fileExists(atPath: workflowURL.path))
    }

    func testBDD_GivenGlobalMCP_WhenDeleteRemoteMCPWithGlobalCachePlan_ThenFileDisappears() async throws {
        let mcpURL = fixture.nolonManager.mcpsURL.appendingPathComponent("xcode.json")
        try "{}".write(to: mcpURL, atomically: true, encoding: .utf8)

        let viewModel = MainSplitViewModel(
            settings: fixture.providerSettings,
            repository: SkillRepository(nolonManager: fixture.nolonManager),
            nolonManager: fixture.nolonManager
        )

        let result = await viewModel.deleteRemoteMCP(
            slug: "xcode",
            providerIndex: nil,
            removeGlobalCache: true,
            globalCachePathHint: nil
        )

        XCTAssertTrue(result.removedGlobalCache)
        XCTAssertFalse(fixture.fileManager.fileExists(atPath: mcpURL.path))
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

    func testBDD_GivenRegisteredGlobalWorkflowDeleteRequest_WhenExecuteRegisteredDeleteRequest_ThenWorkflowFileDisappears() async throws {
        let workflowURL = fixture.nolonManager.userWorkflowsURL.appendingPathComponent("daily-sync.md")
        try "# Daily Sync\n".write(to: workflowURL, atomically: true, encoding: .utf8)

        let viewModel = MainSplitViewModel(
            settings: fixture.providerSettings,
            repository: SkillRepository(nolonManager: fixture.nolonManager),
            nolonManager: fixture.nolonManager
        )

        let requestID = viewModel.registerDeleteRequest(
            slug: "daily-sync",
            resourceType: .workflow,
            providerIndex: nil,
            removeGlobalCache: true,
            globalCachePathHint: nil
        )

        let result = await viewModel.executeRegisteredDeleteRequest(id: requestID)

        XCTAssertTrue(result.removedGlobalCache)
        XCTAssertFalse(fixture.fileManager.fileExists(atPath: workflowURL.path))
    }

    func testBDD_GivenRegisteredGlobalMCPDeleteRequest_WhenExecuteRegisteredDeleteRequest_ThenMCPFileDisappears() async throws {
        let mcpURL = fixture.nolonManager.mcpsURL.appendingPathComponent("xcode.json")
        try "{}".write(to: mcpURL, atomically: true, encoding: .utf8)

        let viewModel = MainSplitViewModel(
            settings: fixture.providerSettings,
            repository: SkillRepository(nolonManager: fixture.nolonManager),
            nolonManager: fixture.nolonManager
        )

        let requestID = viewModel.registerDeleteRequest(
            slug: "xcode",
            resourceType: .mcp,
            providerIndex: nil,
            removeGlobalCache: true,
            globalCachePathHint: nil
        )

        let result = await viewModel.executeRegisteredDeleteRequest(id: requestID)

        XCTAssertTrue(result.removedGlobalCache)
        XCTAssertFalse(fixture.fileManager.fileExists(atPath: mcpURL.path))
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
        let results = await [firstResult, secondResult]

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

    func testBDD_GivenUITestLaunchSelection_WhenResolved_ThenSelectedProviderAndUsageTabAreApplied() {
        let codexIndex = fixture.providerSettings.providers.firstIndex { $0.templateId == "codex" }
        guard let codexIndex else {
            XCTFail("Missing codex provider fixture")
            return
        }
        UITestSupport.environmentOverride = [
            "NOLON_UI_TEST_SELECTED_PROVIDER_INDEX": String(codexIndex),
            "NOLON_UI_TEST_SELECTED_PROVIDER_TAB": "usage"
        ]

        let selection = MainSplitViewModel.resolveInitialLaunchSelection(
            providers: fixture.providerSettings.providers,
            selectedProviderIndex: UITestSupport.initialSelectedProviderIndex,
            initialTab: UITestSupport.initialSelectedProviderTab,
            isRunningUnitTests: true
        )

        XCTAssertEqual(selection?.provider.templateId, "codex")
        XCTAssertEqual(selection?.tab, .usage)
    }

    func testBDD_GivenUITestLaunchSelectionForOpenCodeAgents_WhenResolved_ThenAgentsTabIsApplied() {
        let providerIndex = fixture.providerSettings.providers.firstIndex { $0.templateId == "opencode" }
        guard let providerIndex else {
            XCTFail("Missing opencode provider fixture")
            return
        }

        let selection = MainSplitViewModel.resolveInitialLaunchSelection(
            providers: fixture.providerSettings.providers,
            selectedProviderIndex: providerIndex,
            initialTab: .agents,
            isRunningUnitTests: false
        )

        XCTAssertEqual(selection?.provider.templateId, "opencode")
        XCTAssertEqual(selection?.tab, .agents)
    }

    func testBDD_GivenUITestLaunchSelectionForClaudeAgents_WhenResolved_ThenFallsBackWithoutInvalidAgentsTab() {
        let providerIndex = fixture.providerSettings.providers.firstIndex { $0.templateId == "claudeCode" }
        guard let providerIndex else {
            XCTFail("Missing claudeCode provider fixture")
            return
        }

        let selection = MainSplitViewModel.resolveInitialLaunchSelection(
            providers: fixture.providerSettings.providers,
            selectedProviderIndex: providerIndex,
            initialTab: .agents,
            isRunningUnitTests: false
        )

        XCTAssertEqual(selection?.provider.templateId, "claudeCode")
        XCTAssertNil(selection?.tab)
    }

    func testBDD_GivenPersistedProviderSelectionKey_WhenValidating_ThenKeepSelection() {
        let codexProvider = fixture.providerSettings.providers.first { $0.templateId == "codex" }
        XCTAssertNotNil(codexProvider)
        let storageKey = "provider:\(codexProvider!.id)"

        let result = MainSplitViewModel.normalizedSidebarSelectionKey(
            storageKey,
            providers: fixture.providerSettings.providers
        )

        XCTAssertEqual(result, storageKey)
    }

    func testBDD_GivenPersistedUnknownProviderSelectionKey_WhenValidating_ThenDropSelection() {
        let result = MainSplitViewModel.normalizedSidebarSelectionKey(
            "provider:missing-provider-id",
            providers: fixture.providerSettings.providers
        )

        XCTAssertNil(result)
    }

    func testBDD_GivenPersistedTabRawValue_WhenValidating_ThenResolveKnownTabOrNil() {
        let valid = MainSplitViewModel.persistedTab(from: ProviderContentTabType.usage.rawValue)
        let invalid = MainSplitViewModel.persistedTab(from: "not-a-tab")

        XCTAssertEqual(valid, ProviderContentTabType.usage)
        XCTAssertNil(invalid)
    }

}
