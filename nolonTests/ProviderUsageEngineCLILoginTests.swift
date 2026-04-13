import XCTest
import AppKit
import STJSON
import ProviderUsage
import STFilePath
import ProviderCatalog
import CodexBarProviderCatalog
import NolonResourceKit
@testable import nolon

@MainActor
final class ProviderUsageEngineCLILoginTests: XCTestCase {
    func testBDD_GivenCodexUsageWatcher_WhenRebuilding_ThenProviderAuthFileIsNotWatched() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = ProviderUsageEngine(provider: provider)

        await viewModel.rebuildUsageWatcherForTesting()
        let watched = viewModel.watchedPathsForTesting()
        let providerAuthPath = URL(fileURLWithPath: "/tmp/auth.json").standardizedFileURL.path

        XCTAssertFalse(watched.contains(providerAuthPath))
    }

    func testBDD_GivenIsolatedNolonHome_WhenPreparingCLILoginHome_ThenUsesStableFolderAndForcesFileStore() throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let isolatedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-vm-login-home-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedRoot) }

        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: CodexAuthManager(rootURL: isolatedRoot)
        )
        let firstHome = try viewModel.prepareCLILoginHomeDirectory()

        let expectedHome = isolatedRoot
            .appendingPathComponent("codex", isDirectory: true)
            .appendingPathComponent("cli-login-home", isDirectory: true)
            .appendingPathComponent("codex", isDirectory: true)
            .standardizedFileURL
        XCTAssertEqual(firstHome.standardizedFileURL.path, expectedHome.path)

        let configFile = expectedHome.appendingPathComponent("config.toml")
        let configText = try String(contentsOf: configFile, encoding: .utf8)
        XCTAssertEqual(configText, "cli_auth_credentials_store = \"file\"\n")

        let staleAuthFile = expectedHome.appendingPathComponent("auth.json")
        try "{\"tokens\":{\"id_token\":\"old\",\"access_token\":\"old\"}}".write(
            to: staleAuthFile,
            atomically: true,
            encoding: .utf8
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: staleAuthFile.path))

        let secondHome = try viewModel.prepareCLILoginHomeDirectory()
        XCTAssertEqual(secondHome.standardizedFileURL.path, expectedHome.path)
        XCTAssertFalse(FileManager.default.fileExists(atPath: staleAuthFile.path))
    }

    func testBDD_GivenCodexXcodeProvider_WhenPreparingCLILoginHome_ThenUsesCodexXcodeFolder() throws {
        let provider = Provider(
            id: "codex-xcode-provider",
            kind: .vendor,
            name: "Codex (Xcode)",
            defaultSkillsPath: "/tmp/codex-xcode-skills",
            workflowPath: "/tmp/codex-xcode-prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codexXcode.rawValue
        )

        let isolatedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-vm-login-home-codex-xcode-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedRoot) }

        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: CodexAuthManager(rootURL: isolatedRoot)
        )
        let home = try viewModel.prepareCLILoginHomeDirectory()

        let expectedHome = isolatedRoot
            .appendingPathComponent("codex", isDirectory: true)
            .appendingPathComponent("cli-login-home", isDirectory: true)
            .appendingPathComponent("codex-xcode", isDirectory: true)
            .standardizedFileURL
        XCTAssertEqual(home.standardizedFileURL.path, expectedHome.path)
    }

    func testBDD_GivenCLILoginAlreadyRunning_WhenRequestingCardLoginAgain_ThenFlowRestartsWithPreferredAccount() {
        // Given
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = ProviderUsageEngine(provider: provider)
        viewModel.isRunningCLILogin = true
        viewModel.cliLoginPreferredAccountId = nil

        // When
        viewModel.requestLoginForCodexAccount(id: UUID())

        // Then
        XCTAssertTrue(viewModel.isRunningCLILogin)
        XCTAssertNotNil(viewModel.cliLoginPreferredAccountId)
    }

    func testBDD_GivenReloginPreferredAccount_WhenLoginCompletes_ThenUpdatedAccountIsActivated() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "target", relativeAuthPath: "auth/target.json")
        let activated = LoginActivationBox()
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexActivateAction: { passedAccount, passedProvider in
                await activated.record(account: passedAccount, provider: passedProvider)
            }
        )
        viewModel.cliLoginPreferredAccountId = account.id

        try? await viewModel.activateCodexAccountAfterLoginIfNeeded(account)

        let activation = await activated.value()
        XCTAssertEqual(activation?.account.id, account.id)
        XCTAssertEqual(activation?.provider.templateId, provider.templateId)
    }

    func testBDD_GivenAddAccountLogin_WhenLoginCompletes_ThenDoesNotActivateImmediately() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "added", relativeAuthPath: "auth/added.json")
        let activated = LoginActivationBox()
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexActivateAction: { passedAccount, passedProvider in
                await activated.record(account: passedAccount, provider: passedProvider)
            }
        )
        viewModel.cliLoginPreferredAccountId = nil

        try? await viewModel.activateCodexAccountAfterLoginIfNeeded(account)

        let activation = await activated.value()
        XCTAssertNil(activation)
    }

    func testBDD_GivenReloginPostLoginReload_WhenScheduled_ThenOnlyTargetAccountRefreshes() async throws {
        let isolatedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-cli-login-relogin-reload-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedRoot) }

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: isolatedRoot.appendingPathComponent("provider/skills").path,
            workflowPath: isolatedRoot.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        let authManager = CodexAuthManager(rootURL: isolatedRoot)
        let target = try await authManager.addAccount(
            name: "target",
            authJSONString: #"{"tokens":{"id_token":"target-id","access_token":"target-access"},"user":{"email":"target@example.com"}}"#
        )
        let other = try await authManager.addAccount(
            name: "other",
            authJSONString: #"{"tokens":{"id_token":"other-id","access_token":"other-access"},"user":{"email":"other@example.com"}}"#
        )

        let refreshedIDs = LockedBox<[UUID]>([])
        let viewModel = ProviderUsageEngine(
            provider: provider,
            codexAuthManager: authManager,
            codexOutcomeFetchAction: { account, _, _ in
                await refreshedIDs.set((await refreshedIDs.value()) + [account.id])
                return ProviderAccountUsageOutcome(
                    provider: .codex,
                    account: .tokenAccount(
                        .init(
                            id: account.id,
                            label: account.name,
                            token: "",
                            addedAt: account.createdAt.timeIntervalSince1970,
                            lastUsed: nil
                        )
                    ),
                    outcome: ProviderFetchOutcome(
                        fetchKind: .web,
                        result: .success(
                            .init(
                                usage: UsageSnapshot(
                                    identity: UsageIdentity(
                                        accountEmail: "\(account.name)@example.com",
                                        accountOrganization: nil,
                                        loginMethod: "oauth",
                                        plan: "plus"
                                    ),
                                    primary: RateWindow(usedPercent: 10, windowMinutes: 60),
                                    secondary: nil,
                                    tertiary: nil,
                                    updatedAt: Date()
                                ),
                                credits: CreditsSnapshot(remaining: 10, updatedAt: Date()),
                                cost: nil,
                                sourceLabel: "HTTP",
                                fetchKind: .web,
                                strategyKind: .direct
                            )
                        )
                    )
                )
            }
        )
        viewModel.cliLoginPreferredAccountId = target.id
        await viewModel.reloadCodexFromDisk(refreshUsage: false)

        viewModel.schedulePostLoginReload(preferredBackfillAccount: target)

        try await waitUntilAsync {
            let ids = await refreshedIDs.value()
            return ids.count >= 2
        }

        let ids = await refreshedIDs.value()
        XCTAssertEqual(Set(ids), Set([target.id]))
        XCTAssertFalse(ids.contains(other.id))
    }

    func testBDD_GivenCLILoginRunning_WhenLoginURLSheetDismisses_ThenLoginFlowCancelsImmediately() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = ProviderUsageEngine(provider: provider)
        viewModel.isRunningCLILogin = true
        viewModel.isShowingLoginURLSheet = true
        viewModel.loginURLForSheet = URL(string: "https://auth.openai.com/oauth/authorize?foo=bar")
        viewModel.loginModeForSheet = "CLI(AppServer)"

        viewModel.handleLoginURLSheetDismissed()

        XCTAssertFalse(viewModel.isRunningCLILogin)
        XCTAssertFalse(viewModel.isShowingLoginURLSheet)
        XCTAssertNil(viewModel.loginURLForSheet)
        XCTAssertNil(viewModel.loginModeForSheet)
    }

    func testBDD_GivenCLILoginRunning_WhenClosingLoginURLSheet_ThenLoginFlowCancelsImmediately() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = ProviderUsageEngine(provider: provider)
        viewModel.isRunningCLILogin = true
        viewModel.isShowingLoginURLSheet = true
        viewModel.loginURLForSheet = URL(string: "https://auth.openai.com/oauth/authorize?foo=bar")
        viewModel.loginModeForSheet = "CLI(AppServer)"

        viewModel.cancelCLILoginIfNeeded()

        XCTAssertFalse(viewModel.isRunningCLILogin)
        XCTAssertFalse(viewModel.isShowingLoginURLSheet)
        XCTAssertNil(viewModel.loginURLForSheet)
        XCTAssertNil(viewModel.loginModeForSheet)
    }

    func testBDD_GivenAppServerLoginFailure_WhenHandled_ThenShowsErrorWithoutDirectOAuthFallback() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = ProviderUsageEngine(provider: provider)
        viewModel.loginModeForSheet = "CLI(AppServer)"

        viewModel.handleAppServerLoginFailure(UsageViewModelTestError(message: "app-server login failed"))

        XCTAssertEqual(
            viewModel.alertTitle,
            NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
        )
        XCTAssertEqual(viewModel.alertMessage, "app-server login failed")
        XCTAssertEqual(viewModel.loginModeForSheet, "CLI(AppServer)")
    }

    func testBDD_Given401Unauthorized_WhenCheckingAuthFailure_ThenReturnsTrue() {
        let error = UsageViewModelTestError(message: "Codex protocol error: 401 Unauthorized")
        XCTAssertTrue(ProviderUsageEngine.isAuthFailure(error: error))
    }

    func testBDD_GivenRefreshTokenRevoked_WhenCheckingAuthFailure_ThenReturnsTrue() {
        let error = UsageViewModelTestError(message: "refresh_token_revoked")
        XCTAssertTrue(ProviderUsageEngine.isAuthFailure(error: error))
    }

    func testBDD_GivenTimeoutFailure_WhenCheckingAuthFailure_ThenReturnsFalse() {
        let error = UsageViewModelTestError(message: "request timed out")
        XCTAssertFalse(ProviderUsageEngine.isAuthFailure(error: error))
    }

    func testBDD_GivenAuthFailure_WhenBuildingSummary_ThenReturnsReauthMessage() {
        let error = UsageViewModelTestError(message: "401 Unauthorized")
        let summary = ProviderUsageEngine.errorSummaryText(error: error)
        XCTAssertEqual(
            summary,
            NSLocalizedString("codex.accounts.error.auth_expired", value: "Authentication expired. Please sign in again.", comment: "Codex auth expired summary")
        )
    }

    func testBDD_GivenLongProtocolError_WhenBuildingSummary_ThenReturnsTrimmedText() {
        let raw = "Codex protocol error: failed to fetch codex rate limits: GET https://chatgpt.com/backend-api/wham/usage failed"
        let error = UsageViewModelTestError(message: raw)
        let summary = ProviderUsageEngine.errorSummaryText(error: error)
        XCTAssertFalse(summary.isEmpty)
        XCTAssertTrue(summary.count <= 140)
    }

    func testBDD_GivenFailureMessage_WhenCopyErrorText_ThenPasteboardContainsOriginalText() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = ProviderUsageEngine(provider: provider)
        let message = "Codex protocol error: 401 Unauthorized"

        viewModel.copyErrorText(message)

        XCTAssertEqual(NSPasteboard.general.string(forType: .string), message)
        XCTAssertTrue(viewModel.isShowingCopyToast)
        XCTAssertEqual(
            viewModel.copyToastMessage,
            NSLocalizedString("remote.error.copied", value: "Copied", comment: "Copied tooltip")
        )
    }
}

private actor LoginActivationBox {
    private var stored: (account: CodexAuthAccount, provider: Provider)?

    func record(account: CodexAuthAccount, provider: Provider) {
        stored = (account, provider)
    }

    func value() -> (account: CodexAuthAccount, provider: Provider)? {
        stored
    }
}

@MainActor
private func waitUntilAsync(
    timeout: TimeInterval = 2.0,
    pollIntervalNanoseconds: UInt64 = 20_000_000,
    condition: () async -> Bool
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if await condition() { return }
        try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
    }
    XCTFail("Condition was not met before timeout")
}
