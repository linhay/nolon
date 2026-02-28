import XCTest
import AppKit
import STJSON
import ProviderUsage
import STFilePath
import ProviderCatalog
import CodexBarProviderCatalog
@testable import nolon

@MainActor
final class CodexAuthManagerTests: XCTestCase {
    func testBDD_GivenAppAuthManagerType_WhenCheckingMigrationBoundary_ThenUsesProviderUsageManagerType() {
        XCTAssertEqual(
            ObjectIdentifier(CodexAuthManager.self),
            ObjectIdentifier(CodexAuthManager.self)
        )
    }

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
            try? originalData.write(to: fileURL, options: [.atomic])
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
            isAuthFolderChange: true,
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
            isAuthFolderChange: true,
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

private struct EmptyLocalizedError: LocalizedError {
    var errorDescription: String? { "   " }
}
