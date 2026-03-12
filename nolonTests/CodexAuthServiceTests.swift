import XCTest
import AppKit
import STJSON
import ProviderUsage
import STFilePath
import ProviderCatalog
import CodexBarProviderCatalog
@testable import nolon

actor AsyncGate {
    private var continuation: CheckedContinuation<Void, Never>?

    func wait() async {
        await withCheckedContinuation { continuation in
            self.continuation = continuation
        }
    }

    func open() {
        continuation?.resume()
        continuation = nil
    }
}

@MainActor
final class CodexAuthManagerTests: XCTestCase {
    func testBDD_GivenRealCodexAccount_WhenStoringUsageCache_ThenUsageCacheIsPersisted() async throws {
        let service = CodexAuthManager()
        let accounts = try await service.loadAccounts()
        if accounts.isEmpty {
            throw XCTSkip("No codex accounts found under ~/.nolon/codex/auth")
        }

        let account = accounts[0]
        let file = await service.accountAuthFile(account)
        let fileURL = file.url
        let originalData = try Data(contentsOf: fileURL)
        defer {
            do {
                try originalData.write(to: fileURL, options: [.atomic])
            } catch {
                XCTFail("Failed to restore original auth file: \(error)")
            }
        }

        let usage = UsageSnapshot(
            identity: UsageIdentity(accountEmail: "bdd@example.com", accountOrganization: nil, loginMethod: "oauth", plan: "plus"),
            primary: nil,
            secondary: nil,
            tertiary: nil,
            updatedAt: Date()
        )
        let credits = CreditsSnapshot(remaining: 42, updatedAt: Date())
        let cache = CodexAuthUsageCache(
            cachedAt: Date(),
            creditsRefreshedAt: credits.updatedAt,
            fetchKind: .cli,
            strategyKind: .direct,
            sourceLabel: "CLI",
            usage: usage,
            credits: credits,
            cost: nil
        )

        try await service.storeUsageCache(cache, for: account)

        let loaded = try await service.loadUsageCache(for: account)
        XCTAssertEqual(loaded, cache)

        let data = try Data(contentsOf: fileURL)
        let json = try JSON(data: data)
        XCTAssertNotEqual(json["nolon"]["usage_cache"], JSON.null)
    }

    func testBDD_GivenAuthFolderContainsTransientArtifacts_WhenLoadingAccounts_ThenOnlyStableJSONSnapshotsAreReturned() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-auth-folder-reload-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let account = try await service.addAccount(
            name: "stable",
            authJSONString: #"{"tokens":{"id_token":"id","access_token":"access"},"user":{"email":"stable@example.com"}}"#
        )

        let authFolder = service.nolonCodexAuthFolder().url
        let tempArtifactURL = authFolder.appendingPathComponent(".dat.nosync2F9A.Hb0Ce3")
        let orphanedJSONURL = authFolder.appendingPathComponent("orphaned.json")
        try Data("temp".utf8).write(to: tempArtifactURL)
        try Data("not-json".utf8).write(to: orphanedJSONURL)

        let loadedAccounts = try await service.loadAccounts()

        XCTAssertEqual(loadedAccounts.map(\.id), [account.id])
        XCTAssertEqual(loadedAccounts.map(\.name), [account.name])
    }
}

final class CodexAuthChangeSuppressionStoreTests: XCTestCase {
    func testBDD_GivenUnseenEvent_WhenCheckingSuppression_ThenEventIsNotSuppressed() {
        // Given
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()

        // When
        let suppressed = store.shouldSuppress(path: "/tmp/auth/modified.json", now: now)

        // Then
        XCTAssertFalse(suppressed)
    }

    func testBDD_GivenMarkedEventWithinWindow_WhenCheckingSuppression_ThenEventIsSuppressed() {
        // Given
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()
        store.mark(filePath: "/tmp/auth/auth.json", folderPath: "/tmp/auth", ttl: 1.0, now: now)

        // When
        let suppressed = store.shouldSuppress(path: "/tmp/auth/auth.json", now: now.addingTimeInterval(0.2))

        // Then
        XCTAssertTrue(suppressed)
    }

    func testBDD_GivenMarkedEventAfterWindow_WhenCheckingSuppression_ThenEventIsNotSuppressed() {
        // Given
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()
        store.mark(filePath: "/tmp/auth/auth.json", folderPath: "/tmp/auth", ttl: 0.5, now: now)

        // When
        let suppressed = store.shouldSuppress(path: "/tmp/auth/auth.json", now: now.addingTimeInterval(0.6))

        // Then
        XCTAssertFalse(suppressed)
    }

    func testBDD_GivenTwoDifferentEvents_WhenCheckingSuppression_ThenOnlyMarkedEventIsSuppressed() {
        // Given
        var store = CodexAuthChangeSuppressionStore()
        let now = Date()
        store.mark(filePath: "/tmp/auth/a.json", folderPath: "/tmp/auth", ttl: 1.0, now: now)

        // When
        let suppressedMarked = store.shouldSuppress(path: "/tmp/auth/a.json", now: now.addingTimeInterval(0.1))
        let suppressedUnmarked = store.shouldSuppress(path: "/tmp/other/b.json", now: now.addingTimeInterval(0.1))

        // Then
        XCTAssertTrue(suppressedMarked)
        XCTAssertFalse(suppressedUnmarked)
    }
}

@MainActor
final class CodexAuthTokenExtractionTests: XCTestCase {
    func testBDD_GivenAccountSnapshot_WhenReadingTokenPair_ThenReturnsIdAndAccessToken() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-auth-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let raw = """
        {
          "tokens": {
            "id_token": "id-token-value",
            "access_token": "access-token-value"
          }
        }
        """
        let account = try await service.addAccount(name: "test", authJSONString: raw)

        let pair = try await service.readTokenPair(for: account)

        XCTAssertEqual(pair?.idToken, "id-token-value")
        XCTAssertEqual(pair?.accessToken, "access-token-value")
    }
}

@MainActor
final class CodexAuthActiveAccountRegistryTests: XCTestCase {
    func testBDD_GivenRuntimeActivatedAccount_WhenAuthFileMissing_ThenActiveAccountIdUsesRegistry() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-active-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let account = try await service.addAccount(
            name: "runtime",
            authJSONString: #"{"tokens":{"id_token":"id","access_token":"access"}}"#
        )
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: root.appendingPathComponent("provider/skills").path,
            workflowPath: root.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await service.setActiveAccount(account, for: provider)
        let active = await service.activeAccountId(for: provider)

        XCTAssertEqual(active, account.id)
    }
}

@MainActor
final class CodexAuthCompatSyncTests: XCTestCase {
    func testBDD_GivenSelectedSnapshot_WhenActivating_ThenProviderAuthIsSymlinkedToSnapshot() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-compat-sync-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let account = try await service.addAccount(
            name: "work",
            authJSONString: #"{"tokens":{"id_token":"id-1","access_token":"access-1"},"nolon":{"usage_cache":{"fetch_kind":"api"}}}"#
        )
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: root.appendingPathComponent("provider/skills").path,
            workflowPath: root.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )

        try await service.activateAccount(account, for: provider)
        let maybeAuthFile = await service.authFile(for: provider)
        let authFile = try XCTUnwrap(maybeAuthFile)
        XCTAssertTrue(authFile.isSymbolicLink)
        let destination = try authFile.destinationOfSymbolicLink()
        let snapshotFile = await service.accountAuthFile(account)
        XCTAssertEqual(
            STPath.standardizedPath(destination.url.path).path,
            STPath.standardizedPath(snapshotFile.url.path).path
        )
    }

    func testBDD_GivenFreshCLILogin_WhenFinalizing_ThenSyncsProviderAuthAndMarksActive() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-cli-finalize-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let providerRoot = root.appendingPathComponent("provider", isDirectory: true)
        try FileManager.default.createDirectory(at: providerRoot, withIntermediateDirectories: true)

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: providerRoot.appendingPathComponent("skills").path,
            workflowPath: providerRoot.appendingPathComponent("prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )

        let authURL = providerRoot.appendingPathComponent("auth.json")
        let raw = #"{"tokens":{"id_token":"id-2","access_token":"access-2"},"user":{"email":"cli@example.com"}}"#
        try raw.write(to: authURL, atomically: true, encoding: .utf8)

        let account = try await service.finalizeCLILogin(provider: provider, newAccountName: "cli")
        let active = await service.activeAccountId(for: provider)

        XCTAssertEqual(active, account.id)
        let authRawValue = try await service.readAuthJSONString(from: provider)
        let authRaw = try XCTUnwrap(authRawValue)
        XCTAssertTrue(authRaw.contains("\"id_token\":\"id-2\""))
        XCTAssertTrue(authRaw.contains("\"access_token\":\"access-2\""))
    }

    func testBDD_GivenPreferredAccount_WhenUpsertingCLILogin_ThenUpdatesPreferredSnapshot() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-cli-upsert-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let service = CodexAuthManager(rootURL: root)
        let target = try await service.addAccount(
            name: "target",
            authJSONString: #"{"tokens":{"id_token":"old-id","access_token":"old-access"},"user":{"email":"a@example.com"}}"#
        )
        _ = try await service.addAccount(
            name: "other",
            authJSONString: #"{"tokens":{"id_token":"other","access_token":"other"},"user":{"email":"b@example.com"}}"#
        )

        let updated = try await service.upsertAccountFromCLILogin(
            authJSONString: #"{"tokens":{"id_token":"new-id","access_token":"new-access"},"user":{"email":"b@example.com"}}"#,
            preferredAccountID: target.id
        )

        XCTAssertEqual(updated.id, target.id)
        let pair = try await service.readTokenPair(for: updated)
        XCTAssertEqual(pair?.idToken, "new-id")
        XCTAssertEqual(pair?.accessToken, "new-access")
    }
}

@MainActor
final class ProviderUsageViewModelCLILoginTests: XCTestCase {
    func testBDD_GivenCodexUsageWatcher_WhenRebuilding_ThenProviderAuthFileIsNotWatched() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = ProviderUsageViewModel(provider: provider)

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

        let previousNolonHome = getenv("NOLON_HOME").map { String(cString: $0) }
        setenv("NOLON_HOME", isolatedRoot.path, 1)
        defer {
            if let previousNolonHome {
                setenv("NOLON_HOME", previousNolonHome, 1)
            } else {
                unsetenv("NOLON_HOME")
            }
        }

        let viewModel = ProviderUsageViewModel(provider: provider)
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

    func testBDD_GivenCLILoginAlreadyRunning_WhenRequestingCardLoginAgain_ThenFlowRestartsWithPreferredAccount() {
        // Given
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = ProviderUsageViewModel(provider: provider)
        viewModel.isRunningCLILogin = true
        viewModel.cliLoginPreferredAccountId = nil

        // When
        viewModel.requestLoginForCodexAccount(id: UUID())

        // Then
        XCTAssertTrue(viewModel.isRunningCLILogin)
        XCTAssertNotNil(viewModel.cliLoginPreferredAccountId)
    }

    func testBDD_GivenCLILoginRunning_WhenLoginURLSheetDismisses_ThenLoginFlowCancelsImmediately() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = ProviderUsageViewModel(provider: provider)
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
        let viewModel = ProviderUsageViewModel(provider: provider)
        viewModel.isRunningCLILogin = true
        viewModel.isShowingLoginURLSheet = true
        viewModel.loginURLForSheet = URL(string: "https://auth.openai.com/oauth/authorize?foo=bar")
        viewModel.loginModeForSheet = "CLI(AppServer)"

        viewModel.closeCLILoginSheet()

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
        let viewModel = ProviderUsageViewModel(provider: provider)
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
        XCTAssertTrue(ProviderUsageViewModel.isAuthFailure(error: error))
    }

    func testBDD_GivenRefreshTokenRevoked_WhenCheckingAuthFailure_ThenReturnsTrue() {
        let error = UsageViewModelTestError(message: "refresh_token_revoked")
        XCTAssertTrue(ProviderUsageViewModel.isAuthFailure(error: error))
    }

    func testBDD_GivenTimeoutFailure_WhenCheckingAuthFailure_ThenReturnsFalse() {
        let error = UsageViewModelTestError(message: "request timed out")
        XCTAssertFalse(ProviderUsageViewModel.isAuthFailure(error: error))
    }

    func testBDD_GivenAuthFailure_WhenBuildingSummary_ThenReturnsReauthMessage() {
        let error = UsageViewModelTestError(message: "401 Unauthorized")
        let summary = ProviderUsageViewModel.errorSummaryText(error: error)
        XCTAssertEqual(
            summary,
            NSLocalizedString("codex.accounts.error.auth_expired", value: "Authentication expired. Please sign in again.", comment: "Codex auth expired summary")
        )
    }

    func testBDD_GivenLongProtocolError_WhenBuildingSummary_ThenReturnsTrimmedText() {
        let raw = "Codex protocol error: failed to fetch codex rate limits: GET https://chatgpt.com/backend-api/wham/usage failed"
        let error = UsageViewModelTestError(message: raw)
        let summary = ProviderUsageViewModel.errorSummaryText(error: error)
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
        let viewModel = ProviderUsageViewModel(provider: provider)
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

@MainActor
final class ProviderUsageViewModelAuthSignalAggregationTests: XCTestCase {
    func testBDD_GivenBurstAuthSignals_WhenDebouncedByCombine_ThenOnlyOneReloadIsTriggered() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = ProviderUsageViewModel(provider: provider)

        viewModel.emitCodexAuthReloadSignalForTesting()
        viewModel.emitCodexAuthReloadSignalForTesting()
        try? await Task.sleep(nanoseconds: 900_000_000)

        XCTAssertEqual(viewModel.codexDiskReloadCountForTesting, 1)
    }

    func testBDD_GivenSpacedAuthSignals_WhenDebouncedByCombine_ThenEachWindowTriggersReload() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = ProviderUsageViewModel(provider: provider)

        viewModel.emitCodexAuthReloadSignalForTesting()
        try? await Task.sleep(nanoseconds: 450_000_000)
        viewModel.emitCodexAuthReloadSignalForTesting()
        try? await Task.sleep(nanoseconds: 900_000_000)

        XCTAssertEqual(viewModel.codexDiskReloadCountForTesting, 2)
    }
}

@MainActor
final class ProviderUsageViewModelActivationTests: XCTestCase {
    func testBDD_GivenActivationSuccess_WhenConfirmActivate_ThenClearsPendingAndReloadRuns() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let reloadFlag = AsyncFlagBox()
        let viewModel = ProviderUsageViewModel(
            provider: provider,
            codexActivateAction: { _, _ in
                CodexAuthActivationResult(
                    runtimeSwitched: true,
                    runtimeErrorDescription: nil
                )
            },
            postActivationLoadAction: {
                await reloadFlag.setTrue()
            }
        )
        viewModel.pendingActivateCodexAccount = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")

        await viewModel.confirmActivate()

        XCTAssertNil(viewModel.pendingActivateCodexAccount)
        XCTAssertNil(viewModel.alertTitle)
        XCTAssertNil(viewModel.alertMessage)
        let reloaded = await reloadFlag.value()
        XCTAssertTrue(reloaded)
    }

    func testBDD_GivenRuntimeSwitchFailure_WhenConfirmActivate_ThenActivationContinuesAndReloadRuns() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let reloadFlag = AsyncFlagBox()
        let viewModel = ProviderUsageViewModel(
            provider: provider,
            codexActivateAction: { _, _ in
                CodexAuthActivationResult(
                    runtimeSwitched: false,
                    runtimeErrorDescription: "runtime switch failed"
                )
            },
            postActivationLoadAction: {
                await reloadFlag.setTrue()
            }
        )
        viewModel.pendingActivateCodexAccount = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")

        await viewModel.confirmActivate()

        XCTAssertNil(viewModel.pendingActivateCodexAccount)
        XCTAssertNil(viewModel.alertMessage)
        let reloaded = await reloadFlag.value()
        XCTAssertTrue(reloaded)
    }

    func testBDD_GivenActivationFailure_WhenConfirmActivate_ThenShowsActivationAlert() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let viewModel = ProviderUsageViewModel(
            provider: provider,
            codexActivateAction: { _, _ in
                throw ActivationTestError.failed
            },
            postActivationLoadAction: { }
        )
        viewModel.pendingActivateCodexAccount = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")

        await viewModel.confirmActivate()

        XCTAssertNotNil(viewModel.pendingActivateCodexAccount)
        XCTAssertEqual(
            viewModel.alertTitle,
            NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
        )
        XCTAssertEqual(
            viewModel.alertMessage,
            NSLocalizedString("codex.accounts.error.activate", value: "Failed to activate this account.", comment: "Error message")
        )
    }
}

@MainActor
final class ProviderUsageViewModelDeleteTests: XCTestCase {
    func testBDD_GivenAccountId_WhenRequestDelete_ThenPendingDeleteAndConfirmAreSet() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")
        let viewModel = ProviderUsageViewModel(provider: provider)
        viewModel.codexAccounts = [account]

        viewModel.requestDeleteCodexAccount(id: account.id)

        XCTAssertEqual(viewModel.pendingDeleteCodexAccount?.id, account.id)
        XCTAssertTrue(viewModel.isShowingDeleteConfirm)
    }

    func testBDD_GivenDeleteSuccess_WhenConfirmDelete_ThenClearsPendingAndRunsReload() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")
        let reloadFlag = AsyncFlagBox()
        let deletedId = LockedBox<UUID?>(nil)
        let viewModel = ProviderUsageViewModel(
            provider: provider,
            codexDeleteAction: { id in
                await deletedId.set(id)
            },
            postDeleteLoadAction: {
                await reloadFlag.setTrue()
            }
        )
        viewModel.pendingDeleteCodexAccount = account
        viewModel.isShowingDeleteConfirm = true

        await viewModel.confirmDeleteCodexAccount()

        let removedID = await deletedId.value()
        XCTAssertEqual(removedID, account.id)
        XCTAssertNil(viewModel.pendingDeleteCodexAccount)
        XCTAssertFalse(viewModel.isShowingDeleteConfirm)
        XCTAssertNil(viewModel.alertTitle)
        XCTAssertNil(viewModel.alertMessage)
        let reloaded = await reloadFlag.value()
        XCTAssertTrue(reloaded)
    }

    func testBDD_GivenDeleteFailure_WhenConfirmDelete_ThenShowsDeleteAlert() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "work", relativeAuthPath: "auth/work.json")
        let viewModel = ProviderUsageViewModel(
            provider: provider,
            codexDeleteAction: { _ in
                throw EmptyLocalizedError()
            },
            postDeleteLoadAction: {}
        )
        viewModel.pendingDeleteCodexAccount = account
        viewModel.isShowingDeleteConfirm = true

        await viewModel.confirmDeleteCodexAccount()

        XCTAssertEqual(viewModel.pendingDeleteCodexAccount?.id, account.id)
        XCTAssertTrue(viewModel.isShowingDeleteConfirm)
        XCTAssertEqual(
            viewModel.alertTitle,
            NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
        )
        XCTAssertEqual(
            viewModel.alertMessage,
            NSLocalizedString("codex.accounts.error.delete", value: "Failed to delete this account.", comment: "Error message")
        )
    }

    func testBDD_GivenDeletingNonActiveAccount_WhenConfirmDeleteWithoutHook_ThenDoesNotRefreshRemainingSnapshot() async throws {
        let isolatedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-delete-no-refresh-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedRoot) }

        let previousNolonHome = getenv("NOLON_HOME").map { String(cString: $0) }
        setenv("NOLON_HOME", isolatedRoot.path, 1)
        defer {
            if let previousNolonHome {
                setenv("NOLON_HOME", previousNolonHome, 1)
            } else {
                unsetenv("NOLON_HOME")
            }
        }

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: isolatedRoot.appendingPathComponent("provider/skills").path,
            workflowPath: isolatedRoot.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )

        let service = CodexAuthManager(rootURL: isolatedRoot)
        let active = try await service.addAccount(
            name: "active",
            authJSONString: #"{"tokens":{"id_token":"active-id","access_token":"active-access"},"user":{"email":"active@example.com"}}"#
        )
        let removable = try await service.addAccount(
            name: "removable",
            authJSONString: #"{"tokens":{"id_token":"remove-id","access_token":"remove-access"},"user":{"email":"remove@example.com"}}"#
        )
        try await service.setActiveAccount(active, for: provider)

        let canonicalAccounts = try await service.loadAccounts()
        let canonicalActive = try XCTUnwrap(canonicalAccounts.first(where: { $0.id == active.id }))
        let canonicalRemovable = try XCTUnwrap(canonicalAccounts.first(where: { $0.id == removable.id }))
        let activeFileURL = await service.accountAuthFile(canonicalActive).url
        let before = try Data(contentsOf: activeFileURL)

        let viewModel = ProviderUsageViewModel(provider: provider)
        viewModel.settings.webTimeoutSeconds = 1
        viewModel.codexAccounts = [canonicalActive, canonicalRemovable]
        viewModel.pendingDeleteCodexAccount = canonicalRemovable
        viewModel.isShowingDeleteConfirm = true

        await viewModel.confirmDeleteCodexAccount()

        XCTAssertEqual(viewModel.codexAccounts.map(\.id), [active.id])
        XCTAssertNil(viewModel.pendingDeleteCodexAccount)
        XCTAssertFalse(viewModel.isShowingDeleteConfirm)
        XCTAssertNil(viewModel.alertTitle)
        XCTAssertNil(viewModel.alertMessage)

        let updatedAccounts = try await service.loadAccounts()
        let remaining = try XCTUnwrap(updatedAccounts.first(where: { $0.id == active.id }))
        let updatedActiveFileURL = await service.accountAuthFile(remaining).url
        let after = try Data(contentsOf: updatedActiveFileURL)
        XCTAssertEqual(before, after)
    }
}

@MainActor
final class ProviderUsageViewModelManualRefreshTests: XCTestCase {
    func testBDD_GivenCachedCodexUsage_WhenLoadStarts_ThenCachedCardsAppearBeforePreflightFinishes() async throws {
        let isolatedRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-codex-cached-load-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: isolatedRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: isolatedRoot) }

        let previousNolonHome = getenv("NOLON_HOME").map { String(cString: $0) }
        setenv("NOLON_HOME", isolatedRoot.path, 1)
        defer {
            if let previousNolonHome {
                setenv("NOLON_HOME", previousNolonHome, 1)
            } else {
                unsetenv("NOLON_HOME")
            }
        }

        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: isolatedRoot.appendingPathComponent("provider/skills").path,
            workflowPath: isolatedRoot.appendingPathComponent("provider/prompts").path,
            installMethod: .symlink,
            templateId: "codex"
        )
        let service = CodexAuthManager(rootURL: isolatedRoot)
        let added = try await service.addAccount(
            name: "cached",
            authJSONString: #"{"tokens":{"id_token":"cached-id","access_token":"cached-access"},"user":{"email":"cached@example.com"}}"#
        )
        let loadedAccounts = try await service.loadAccounts()
        let account = try XCTUnwrap(loadedAccounts.first(where: { $0.id == added.id }))
        let cache = CodexAuthUsageCache(
            cachedAt: Date(),
            creditsRefreshedAt: nil,
            fetchKind: .web,
            strategyKind: .direct,
            sourceLabel: "HTTP",
            usage: UsageSnapshot(
                identity: UsageIdentity(
                    accountEmail: "cached@example.com",
                    accountOrganization: nil,
                    loginMethod: "oauth",
                    plan: "free"
                ),
                primary: RateWindow(usedPercent: 30, windowMinutes: 60),
                secondary: nil,
                tertiary: nil,
                updatedAt: Date()
            ),
            credits: CreditsSnapshot(remaining: 12, updatedAt: Date()),
            cost: nil
        )
        try await service.storeUsageCache(cache, for: account)

        let gate = AsyncGate()
        let viewModel = ProviderUsageViewModel(
            provider: provider,
            codexPreflightAction: { _, forceBackup, reason in
                XCTAssertTrue(forceBackup)
                XCTAssertEqual(reason, "usage_load")
                await gate.wait()
                return nil
            },
            codexOutcomeFetchAction: { account, _, _ in
                ProviderAccountUsageOutcome(
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
                                        accountEmail: "fresh@example.com",
                                        accountOrganization: nil,
                                        loginMethod: "oauth",
                                        plan: "free"
                                    ),
                                    primary: RateWindow(usedPercent: 10, windowMinutes: 60),
                                    secondary: nil,
                                    tertiary: nil,
                                    updatedAt: Date()
                                ),
                                credits: CreditsSnapshot(remaining: 24, updatedAt: Date()),
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

        let loadTask = Task { await viewModel.load() }

        try await waitUntil { !viewModel.codexAccountOutcomes.isEmpty }
        XCTAssertTrue(viewModel.isLoading)
        let cachedOutcome = try XCTUnwrap(viewModel.codexAccountOutcomes.first)
        guard case let .success(cachedResult) = cachedOutcome.outcome.result else {
            return XCTFail("Expected cached success outcome before preflight finished")
        }
        XCTAssertEqual(cachedResult.usage.identity?.accountEmail, "cached@example.com")
        XCTAssertEqual(cachedResult.credits?.remaining, 12)
        XCTAssertEqual(cachedResult.fetchKind, .web)

        await gate.open()
        await loadTask.value

        let refreshedOutcome = try XCTUnwrap(viewModel.codexAccountOutcomes.first)
        guard case let .success(refreshedResult) = refreshedOutcome.outcome.result else {
            return XCTFail("Expected refreshed success outcome after load finished")
        }
        XCTAssertEqual(refreshedResult.usage.identity?.accountEmail, "fresh@example.com")
        XCTAssertEqual(refreshedResult.credits?.remaining, 24)
        XCTAssertFalse(viewModel.isLoading)
    }

    func testBDD_GivenUsageViewAppearsAgain_WhenHandlingAppear_ThenDoesNotTriggerCodexRefresh() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let account = CodexAuthAccount(name: "test", relativeAuthPath: "auth/test.json")
        let refreshCount = LockedBox<Int>(0)
        let viewModel = ProviderUsageViewModel(
            provider: provider,
            codexOutcomeFetchAction: { account, _, _ in
                await refreshCount.set((await refreshCount.value()) + 1)
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
                        fetchKind: .cli,
                        result: .failure(UsageViewModelTestError(message: "should not refresh on appear"))
                    )
                )
            }
        )
        viewModel.codexAccounts = [account]
        viewModel.activeCodexAccountId = account.id

        await viewModel.handleUsageViewAppear()

        let count = await refreshCount.value()
        XCTAssertEqual(count, 0)
        XCTAssertTrue(viewModel.codexRefreshingAccountIds.isEmpty)
    }

    func testBDD_GivenHeaderRefresh_WhenCodexMultiAccount_ThenRefreshActionRunsForAllAccounts() async {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let failed = CodexAuthAccount(name: "failed", relativeAuthPath: "auth/failed.json")
        let healthy = CodexAuthAccount(name: "healthy", relativeAuthPath: "auth/healthy.json")
        let refreshedIDs = LockedBox<[UUID]>([])

        let viewModel = ProviderUsageViewModel(
            provider: provider,
            codexRefreshAllAction: { accounts in
                await refreshedIDs.set(accounts.map(\.id))
            }
        )
        viewModel.codexAccounts = [failed, healthy]
        viewModel.activeCodexAccountId = healthy.id
        viewModel.codexAccountSummaries = [
            failed.id: CodexAuthSummary(lastSyncFailedAt: Date(), lastSyncFailureMessage: "401 Unauthorized"),
            healthy.id: CodexAuthSummary(lastSyncSucceededAt: Date())
        ]

        await viewModel.refreshFromHeader()

        let ids = await refreshedIDs.value()
        XCTAssertEqual(ids, [healthy.id, failed.id])
    }

    func testBDD_GivenFailedAccount_WhenResolvingHeaderRefreshTargets_ThenDoesNotSkipIt() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let failed = CodexAuthAccount(name: "failed", relativeAuthPath: "auth/failed.json")
        let normal = CodexAuthAccount(name: "normal", relativeAuthPath: "auth/normal.json")
        let viewModel = ProviderUsageViewModel(provider: provider)
        viewModel.codexAccounts = [failed, normal]
        viewModel.codexAccountSummaries = [
            failed.id: CodexAuthSummary(lastSyncFailedAt: Date(), lastSyncFailureMessage: "auth expired")
        ]

        let targets = viewModel.codexHeaderRefreshTargets()

        XCTAssertEqual(Set(targets.map(\.id)), Set([failed.id, normal.id]))
    }

    func testBDD_GivenCodexXcodeProvider_WhenCreatingUsageViewModel_ThenItMapsToCodexUsageProvider() {
        let provider = Provider(
            name: "Codex (Xcode)",
            defaultSkillsPath: "/tmp/codex-xcode/skills",
            workflowPath: "/tmp/codex-xcode/prompts",
            installMethod: .symlink,
            templateId: "codexXcode"
        )

        let viewModel = ProviderUsageViewModel(provider: provider)

        XCTAssertEqual(viewModel.usageProvider, .codex)
        XCTAssertTrue(viewModel.isMultiAccountEnabled)
    }

    func testBDD_GivenAccountRefreshCompletes_WhenRefreshingCodexAccount_ThenRefreshingStateClears() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "test", relativeAuthPath: "auth/test.json")
        let viewModel = ProviderUsageViewModel(
            provider: provider,
            codexOutcomeFetchAction: { account, _, _ in
                try? await Task.sleep(nanoseconds: 80_000_000)
                let outcome = ProviderFetchOutcome(fetchKind: .cli, result: .failure(UsageViewModelTestError(message: "network done")))
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
                    outcome: outcome
                )
            }
        )
        viewModel.codexAccounts = [account]

        viewModel.refreshCodexAccount(id: account.id)

        try await waitUntil { viewModel.codexRefreshingAccountIds.contains(account.id) }
        try await waitUntil { !viewModel.codexRefreshingAccountIds.contains(account.id) }
        XCTAssertFalse(viewModel.codexRefreshingAccountIds.contains(account.id))
    }

    func testBDD_GivenAccountRefreshHangs_WhenRefreshingCodexAccount_ThenRefreshingStateClearsAfterTimeout() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "test", relativeAuthPath: "auth/test.json")
        let viewModel = ProviderUsageViewModel(
            provider: provider,
            codexOutcomeFetchAction: { account, _, _ in
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                let outcome = ProviderFetchOutcome(fetchKind: .cli, result: .failure(UsageViewModelTestError(message: "late result")))
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
                    outcome: outcome
                )
            },
            codexRefreshTimeoutGraceSeconds: 0,
            initialSettingsOverride: UsageMonitorProviderSettings(
                sourceMode: .auto,
                includeCredits: false,
                webTimeoutSeconds: 1,
                autoRefreshIntervalMinutes: 0,
                costWindowDays: 30
            )
        )
        viewModel.codexAccounts = [account]

        await viewModel.refreshCodexAccountImmediately(id: account.id)

        XCTAssertFalse(viewModel.codexRefreshingAccountIds.contains(account.id))

        let refreshed: ProviderAccountUsageOutcome = try XCTUnwrap(
            viewModel.codexAccountOutcomes.first(where: {
                if case let .tokenAccount(tokenAccount) = $0.account {
                    return tokenAccount.id == account.id
                }
                return false
            })
        )
        if case let .failure(error) = refreshed.outcome.result {
            let nsError = error as NSError
            XCTAssertEqual(nsError.domain, "ProviderUsageViewModel.CodexRefresh")
            XCTAssertEqual(nsError.code, 408)
        } else {
            XCTFail("Expected timeout failure outcome")
        }
    }

    func testBDD_GivenHeaderRefreshInProgress_WhenTappingRefreshAgain_ThenCanInterruptAndRefreshAgain() async throws {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )
        let account = CodexAuthAccount(name: "test", relativeAuthPath: "auth/test.json")
        let startedCount = AsyncIntBox(0)
        let viewModel = ProviderUsageViewModel(
            provider: provider,
            codexRefreshAllAction: { _ in
                await startedCount.increment()
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 20_000_000)
                }
            }
        )
        viewModel.codexAccounts = [account]

        viewModel.handleHeaderRefreshButtonTap()
        try await waitUntilAsync { await startedCount.value() >= 1 }
        try await waitUntil { viewModel.isCodexHeaderRefreshing }

        viewModel.handleHeaderRefreshButtonTap()
        try await waitUntil { !viewModel.isCodexHeaderRefreshing }

        viewModel.handleHeaderRefreshButtonTap()
        try await waitUntilAsync { await startedCount.value() >= 2 }
        try await waitUntil { viewModel.isCodexHeaderRefreshing }
        XCTAssertTrue(viewModel.isCodexHeaderRefreshing)

        viewModel.handleHeaderRefreshButtonTap()
        try await waitUntil { !viewModel.isCodexHeaderRefreshing }
    }

    @MainActor
    private func waitUntil(
        timeout: TimeInterval = 2.0,
        pollIntervalNanoseconds: UInt64 = 20_000_000,
        condition: () -> Bool
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            try await Task.sleep(nanoseconds: pollIntervalNanoseconds)
        }
        XCTFail("Condition was not met before timeout")
    }

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
}

@MainActor
final class ProviderUsageViewModelOutcomeOrderingTests: XCTestCase {
    func testBDD_GivenOutcomeOrderMismatch_WhenReplacingByAccountId_ThenUsageDoesNotDriftAcrossAccounts() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let first = CodexAuthAccount(name: "first", relativeAuthPath: "auth/first.json")
        let second = CodexAuthAccount(name: "second", relativeAuthPath: "auth/second.json")
        let viewModel = ProviderUsageViewModel(provider: provider)

        viewModel.codexAccounts = [first, second]
        viewModel.codexAccountOutcomes = [makeOutcome(account: second, label: "old-second"), makeOutcome(account: first, label: "old-first")]
        viewModel.reorderCodexAccountOutcomesForDisplay()

        viewModel.replaceCodexOutcome(makeOutcome(account: second, label: "new-second"), for: second.id)

        XCTAssertEqual(viewModel.codexAccountOutcomes.count, 2)
        let firstLabel = viewModel.codexAccountOutcomes[0].displayName
        let secondLabel = viewModel.codexAccountOutcomes[1].displayName
        XCTAssertEqual(firstLabel, "old-first")
        XCTAssertEqual(secondLabel, "new-second")
    }

    func testBDD_GivenDuplicatedAccountOutcomes_WhenReordering_ThenKeepsLatestWithoutCrash() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let first = CodexAuthAccount(name: "first", relativeAuthPath: "auth/first.json")
        let second = CodexAuthAccount(name: "second", relativeAuthPath: "auth/second.json")
        let viewModel = ProviderUsageViewModel(provider: provider)

        viewModel.codexAccounts = [first, second]
        viewModel.codexAccountOutcomes = [
            makeOutcome(account: first, label: "old-first"),
            makeOutcome(account: first, label: "new-first"),
            makeOutcome(account: second, label: "old-second")
        ]

        viewModel.reorderCodexAccountOutcomesForDisplay()

        XCTAssertEqual(viewModel.codexAccountOutcomes.count, 2)
        XCTAssertEqual(viewModel.codexAccountOutcomes[0].displayName, "new-first")
        XCTAssertEqual(viewModel.codexAccountOutcomes[1].displayName, "old-second")
    }

    func testBDD_GivenDuplicatedCodexAccounts_WhenReordering_ThenDisplayOutcomesRemainUniqueByAccountID() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let duplicated = CodexAuthAccount(name: "duplicated", relativeAuthPath: "auth/duplicated.json")
        let normal = CodexAuthAccount(name: "normal", relativeAuthPath: "auth/normal.json")
        let viewModel = ProviderUsageViewModel(provider: provider)

        viewModel.codexAccounts = [duplicated, duplicated, normal]
        viewModel.codexAccountOutcomes = [
            makeOutcome(account: duplicated, label: "duplicated"),
            makeOutcome(account: normal, label: "normal")
        ]

        viewModel.reorderCodexAccountOutcomesForDisplay()

        XCTAssertEqual(viewModel.codexAccountOutcomes.count, 2)
        XCTAssertEqual(Set(viewModel.codexAccountOutcomes.map(\.id)).count, 2)
        XCTAssertEqual(viewModel.codexAccountOutcomes.map(\.displayName), ["duplicated", "normal"])
    }

    func testBDD_GivenStaleOutcomeWithoutSnapshot_WhenReordering_ThenDropsStaleOutcomeCard() {
        let provider = Provider(
            name: "Codex",
            defaultSkillsPath: "/tmp/codex-skills",
            workflowPath: "/tmp/codex-prompts",
            installMethod: .symlink,
            templateId: "codex"
        )

        let existing = CodexAuthAccount(name: "existing", relativeAuthPath: "auth/existing.json")
        let stale = CodexAuthAccount(name: "stale", relativeAuthPath: "auth/stale.json")
        let viewModel = ProviderUsageViewModel(provider: provider)

        viewModel.codexAccounts = [existing]
        viewModel.codexAccountOutcomes = [
            makeOutcome(account: existing, label: "existing"),
            makeOutcome(account: stale, label: "stale")
        ]

        viewModel.reorderCodexAccountOutcomesForDisplay()

        XCTAssertEqual(viewModel.codexAccountOutcomes.count, 1)
        XCTAssertEqual(viewModel.codexAccountOutcomes.first?.displayName, "existing")
    }

    private func makeOutcome(account: CodexAuthAccount, label: String) -> ProviderAccountUsageOutcome {
        let usage = UsageSnapshot(
            identity: UsageIdentity(accountEmail: "\(label)@example.com", accountOrganization: nil, loginMethod: "oauth", plan: "plus"),
            primary: nil,
            secondary: nil,
            tertiary: nil,
            updatedAt: Date()
        )
        let result = ProviderFetchResult(
            usage: usage,
            credits: nil,
            cost: nil,
            sourceLabel: "CLI",
            fetchKind: .cli,
            strategyKind: .direct
        )
        let outcome = ProviderFetchOutcome(fetchKind: .cli, result: .success(result))
        return ProviderAccountUsageOutcome(
            provider: .codex,
            account: .tokenAccount(
                .init(
                    id: account.id,
                    label: label,
                    token: "",
                    addedAt: Date().timeIntervalSince1970,
                    lastUsed: nil
                )
            ),
            outcome: outcome
        )
    }
}

@MainActor
final class CodexUsageCardPresentationPolicyTests: XCTestCase {
    func testBDD_GivenHealthyState_WhenMappingStatusKind_ThenReturnsHealthy() {
        let kind = CodexUsageCardPresentationPolicy.statusKind(for: .healthy)
        XCTAssertEqual(kind, .healthy)
    }

    func testBDD_GivenNeedsReauthState_WhenMappingStatusKind_ThenReturnsError() {
        let kind = CodexUsageCardPresentationPolicy.statusKind(for: .needsReauth)
        XCTAssertEqual(kind, .error)
    }

    func testBDD_GivenFailedState_WhenMappingStatusKind_ThenReturnsError() {
        let kind = CodexUsageCardPresentationPolicy.statusKind(for: .failed)
        XCTAssertEqual(kind, .error)
    }

    func testBDD_GivenPendingState_WhenMappingStatusKind_ThenReturnsPending() {
        let kind = CodexUsageCardPresentationPolicy.statusKind(for: .pending)
        XCTAssertEqual(kind, .pending)
    }

    func testBDD_GivenReauthWithLoginAction_WhenComputingLayout_ThenReturnsDualEqualWidth() {
        let layout = CodexUsageCardPresentationPolicy.actionLayout(needsReauth: true, hasLoginAction: true)
        XCTAssertEqual(layout, .dualEqualWidth)
    }

    func testBDD_GivenReauthWithoutLoginAction_WhenComputingLayout_ThenReturnsSingleFullWidth() {
        let layout = CodexUsageCardPresentationPolicy.actionLayout(needsReauth: true, hasLoginAction: false)
        XCTAssertEqual(layout, .singleFullWidth)
    }

    func testBDD_GivenNonReauthFailure_WhenComputingLayout_ThenReturnsSingleFullWidth() {
        let layout = CodexUsageCardPresentationPolicy.actionLayout(needsReauth: false, hasLoginAction: true)
        XCTAssertEqual(layout, .singleFullWidth)
    }
}

final class CodexAuthEventPolicyTests: XCTestCase {
    func testBDD_GivenKnownAccountFileRenamedToTrash_WhenEvaluatingPolicy_ThenRenameIsIgnored() {
        // Given
        let changedPath = "/Users/test/.Trash/personal-account.json"
        let knownFiles: Set<String> = ["personal-account.json", "work-account.json"]

        // When
        let ignored = CodexAuthEventPolicy.shouldIgnoreKnownAuthRename(
            changedPath: changedPath,
            kind: .renamed,
            isAuthFolderChange: false,
            isAuthFileChange: false,
            knownAuthFileNames: knownFiles
        )

        // Then
        XCTAssertTrue(ignored)
    }

    func testBDD_GivenUnknownRenamedFile_WhenEvaluatingPolicy_ThenRenameIsNotIgnored() {
        // Given
        let changedPath = "/Users/test/.Trash/unknown.json"
        let knownFiles: Set<String> = ["personal-account.json", "work-account.json"]

        // When
        let ignored = CodexAuthEventPolicy.shouldIgnoreKnownAuthRename(
            changedPath: changedPath,
            kind: .renamed,
            isAuthFolderChange: false,
            isAuthFileChange: false,
            knownAuthFileNames: knownFiles
        )

        // Then
        XCTAssertFalse(ignored)
    }

    func testBDD_GivenActiveAuthFileRenamed_WhenEvaluatingPolicy_ThenRenameIsNotIgnored() {
        // Given
        let changedPath = "/Users/test/.codex/auth.json"
        let knownFiles: Set<String> = ["auth.json"]

        // When
        let ignored = CodexAuthEventPolicy.shouldIgnoreKnownAuthRename(
            changedPath: changedPath,
            kind: .renamed,
            isAuthFolderChange: true,
            isAuthFileChange: true,
            knownAuthFileNames: knownFiles
        )

        // Then
        XCTAssertFalse(ignored)
    }

    func testBDD_GivenKnownAccountRenameInsideAuthFolder_WhenEvaluatingPolicy_ThenRenameIsNotIgnored() {
        // Given
        let changedPath = "/Users/test/.nolon/codex/auth/personal-account.json"
        let knownFiles: Set<String> = ["personal-account.json", "work-account.json"]

        // When
        let ignored = CodexAuthEventPolicy.shouldIgnoreKnownAuthRename(
            changedPath: changedPath,
            kind: .renamed,
            isAuthFolderChange: true,
            isAuthFileChange: false,
            knownAuthFileNames: knownFiles
        )

        // Then
        XCTAssertFalse(ignored)
    }
}

private enum ActivationTestError: Error {
    case failed
}

private struct UsageViewModelTestError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

private actor AsyncFlagBox {
    private var flag = false

    func setTrue() {
        flag = true
    }

    func value() -> Bool {
        flag
    }
}

private actor LockedBox<T: Sendable> {
    private var stored: T

    init(_ value: T) {
        self.stored = value
    }

    func set(_ value: T) {
        stored = value
    }

    func value() -> T {
        stored
    }
}

private actor AsyncIntBox {
    private var stored: Int

    init(_ value: Int) {
        stored = value
    }

    func increment() {
        stored += 1
    }

    func value() -> Int {
        stored
    }
}

private struct EmptyLocalizedError: LocalizedError {
    var errorDescription: String? { "   " }
}
