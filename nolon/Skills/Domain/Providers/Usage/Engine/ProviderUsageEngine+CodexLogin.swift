import SwiftUI
import AppKit
import ProviderCatalog
import Observation
import WebKit
import ProviderUsage
import CodexBarProviderCatalog
import CodexProvider
import UniformTypeIdentifiers
import OSLog
import Combine
import NolonResourceKit
import NolonCoreCLIKit
import NolonUIFoundation
import GRDB
@preconcurrency import STFilePath
import STJSON

extension ProviderUsageEngine {
    func startLoginFlow() {
        if isRunningCLILogin {
            cancelCLILoginIfNeeded()
        }
        if usageProvider == .codex {
            startCLILoginFlow()
            return
        }
        if usageProvider == .gemini || usageProvider == .antigravity {
            Task { [weak self] in
                await self?.startGeminiLoginFlowAfterImportCheck()
            }
        }
    }

    func copyLoginURL() {
        guard let raw = loginURLForSheet?.absoluteString, !raw.isEmpty else { return }
        copyText(raw)
    }

    func copyErrorText(_ raw: String) {
        let trimmed = Self.trimmed(raw)
        guard Self.isNotBlank(raw) else { return }
        copyText(trimmed)
    }

    func copyCodexAccountPath(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        copyText(account.relativeAuthPath)
    }

    func copyCodexAccountAuthJSON(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        guard let data = codexAuthManager.accountAuthDataWithoutMaterialization(for: account),
              let raw = CodexAuthInspectionSupport.rawJSONString(from: data)
        else { return }
        copyText(raw)
    }

    func editCodexAccountAuthJSON(id: UUID) {
        if codexAccountSupportsEditing(accountID: id) {
            beginEditCodexConfiguredAccount(id: id)
            return
        }
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        guard let data = codexAuthManager.accountAuthDataWithoutMaterialization(for: account),
              let fileURL = CodexAuthInspectionSupport.writeInspectionFile(accountID: account.id, data: data)
        else { return }
        NSWorkspace.shared.open(fileURL)
    }

    func copyText(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        showCopyToast()
    }

    static func isAuthFailure(error: Error) -> Bool {
        CodexAuthFailureClassifier.isAuthFailure(errorText: errorDetailText(error: error))
    }

    static func errorSummaryText(error: Error, maxLength: Int = 140) -> String {
        ProviderUsageErrorPresentationSupport.summaryText(error: error, maxLength: maxLength)
    }

    static func errorDetailText(error: Error) -> String {
        ProviderUsageErrorPresentationSupport.detailText(error: error)
    }

    func reopenLoginURLInBrowser() {
        guard let url = loginURLForSheet else { return }
        NSWorkspace.shared.open(url)
    }

    func beginAddAccount(_ source: CodexAddSource) {
        addAccountSource = source
        if source != .cliLogin {
            cancelCLILoginIfNeeded()
        }
        switch source {
        case .current:
            Task { await confirmAddAccount() }
        case .file:
            importedAuthFileURL = nil
            isShowingAuthFileImporter = true
        case .cliLogin:
            startCLILoginFlow()
        }
    }

    func confirmAddAccount() async {
        guard usageProvider == .codex else { return }
        guard addAccountSource != .cliLogin else {
            startCLILoginFlow()
            return
        }

        do {
            let authJSONString: String
            switch addAccountSource {
            case .current:
                guard let raw = try await codexAuthManager.readAuthJSONString(from: provider) else {
                    alertTitle = NSLocalizedString("codex.accounts.add.title", value: "Add Account", comment: "Add account title")
                    alertMessage = NSLocalizedString("codex.accounts.current.none", value: "Current: No auth.json found.", comment: "Current auth summary")
                    return
                }
                authJSONString = raw
            case .file:
                guard let url = importedAuthFileURL else {
                    alertTitle = NSLocalizedString("codex.accounts.add.title", value: "Add Account", comment: "Add account title")
                    alertMessage = NSLocalizedString("codex.accounts.add.error.no_file", value: "Select an auth.json file first.", comment: "Error")
                    return
                }
                authJSONString = try readAuthJSONString(fromImportedFileURL: url)
            case .cliLogin:
                return
            }

            let finalName = codexAuthManager.deriveAccountName(fromAuthJSONString: authJSONString)
            _ = try await codexAuthManager.addAccount(name: finalName, authJSONString: authJSONString)
            await load()
        } catch {
            alertTitle = NSLocalizedString("codex.accounts.add.title", value: "Add Account", comment: "Add account title")
            let fallback = NSLocalizedString("codex.accounts.error.add", value: "Failed to add this account.", comment: "Error message")
            let message = Self.trimmed(error.localizedDescription)
            alertMessage = Self.isNotBlank(message) ? message : fallback
        }
    }

    func cancelCLILoginIfNeeded() {
        cliLoginSessionId = nil
        cliLoginTask?.cancel()
        cliLoginTask = nil
        cleanupCLILoginArtifacts()
        isRunningCLILogin = false
        cliLoginStatus = nil
        cliLoginPreferredAccountId = nil
        isShowingLoginURLSheet = false
        loginURLForSheet = nil
        loginModeForSheet = nil
        isShowingGeminiImportConfirm = false
        pendingGeminiImportCandidate = nil
    }

    func handleLoginURLSheetDismissed() {
        guard isRunningCLILogin else { return }
        cancelCLILoginIfNeeded()
    }

    func cleanupCLILoginArtifacts() {
        cliLoginHandle?.cancel()
        cliLoginHandle = nil
        geminiLoginHandle?.cancel()
        geminiLoginHandle = nil
        cliLoginHomeDir = nil
    }

    func finalizeCLILoginSessionIfNeeded(sessionId: UUID) {
        guard cliLoginSessionId == sessionId else { return }
        cliLoginTask = nil
        cliLoginSessionId = nil
        cleanupCLILoginArtifacts()
        isRunningCLILogin = false
        cliLoginStatus = nil
        cliLoginPreferredAccountId = nil
        isShowingLoginURLSheet = false
        loginURLForSheet = nil
        loginModeForSheet = nil
    }

    func resetCodexMultiAccountState() {
        codexAccounts = []
        codexAccountOutcomes = []
        codexAccountSummaries = [:]
        codexAccountCustomGroupNames = [:]
        codexAccountCreditsRefreshedAt = [:]
        codexRefreshingAccountIds = []
        codexRefreshedAccountIdsInSession = []
        currentCodexAuthHashHex = nil
        codexAuthFilePath = nil
        activeCodexAccountId = nil
        codexScheduledRefreshLastAt = [:]
        codexScheduledRefreshFailureStreak = [:]
        pendingActivateCodexAccount = nil
        activatingCodexAccountId = nil
        pendingDeleteCodexAccount = nil
        isShowingDeleteConfirm = false
        isCodexMultiSelectionEnabled = false
        selectedCodexAccountIDs = []
        dismissCodexImportSheet()
    }



    func startCLILoginFlow(preferredAccountId: UUID? = nil) {
        guard usageProvider == .codex else { return }
        guard !isRunningCLILogin else { return }

        let sessionId = UUID()
        cliLoginSessionId = sessionId
        isRunningCLILogin = true
        cliLoginStatus = NSLocalizedString("codex.accounts.add.cli.running", value: "Logging in…", comment: "CLI login running status")
        cliLoginPreferredAccountId = preferredAccountId

        cliLoginTask?.cancel()
        cliLoginTask = Task { [weak self] in
            guard let self else { return }
            await self.runUnifiedLoginFlow(sessionId: sessionId)
        }
    }

    func runUnifiedLoginFlow(sessionId: UUID) async {
        defer {
            finalizeCLILoginSessionIfNeeded(sessionId: sessionId)
        }
        do {
            try await runAppServerLoginFlow(sessionId: sessionId)
            return
        } catch {
            guard cliLoginSessionId == sessionId else { return }
            Self.logger.error("App-server login failed. Falling back to direct CLI login. error=\(String(describing: error), privacy: .public)")
            await runCLILoginFlow(sessionId: sessionId, shouldFinalizeSession: false)
        }
    }

    func handleAppServerLoginFailure(_ error: Error) {
        alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
        alertMessage = error.localizedDescription
    }

    func runAppServerLoginFlow(sessionId: UUID) async throws {
        guard cliLoginSessionId == sessionId else { return }
        let loginHome = try prepareCLILoginHomeDirectory()
        cliLoginHomeDir = loginHome
        var env = ProcessInfo.processInfo.environment
        if let managedEnv = try? await CodexBinaryManager.shared.launchEnvironmentVariables() {
            env.merge(managedEnv) { _, new in new }
        }
        env["CODEX_HOME"] = loginHome.path
        let service = CodexAccountRuntimeService(
            executable: env["CODEX_CLI_PATH"] ?? "codex",
            environment: env
        )
        defer { Task { await service.shutdown() } }

        try await service.initialize(clientName: "codex", clientVersion: "1.0.0")
        let started = try await service.startChatGPTLogin()
        loginURLForSheet = started.authURL
        loginModeForSheet = "CLI(AppServer)"
        isShowingLoginURLSheet = true
        cliLoginStatus = NSLocalizedString("codex.accounts.add.cli.waiting", value: "Waiting for auth.json…", comment: "CLI login waiting status")
        let authResult = try await CodexLoginRunner.awaitAuthResultPreferFile(
            codexHome: STFolder(loginHome),
            timeoutSeconds: cliLoginTimeoutSeconds,
            pollIntervalSeconds: 0.2,
            completionWaiter: {
                try await service.awaitChatGPTLoginCompletion(loginID: started.loginID, timeout: self.cliLoginTimeoutSeconds)
            }
        )
        let account = try await codexAuthManager.recordCLILoginSnapshot(
            authJSONString: authResult.authJSONString,
            preferredAccountID: cliLoginPreferredAccountId,
            loginAt: Date()
        )
        try await activateCodexAccountAfterLoginIfNeeded(account)
        schedulePostLoginReload(preferredBackfillAccount: account)
    }

    func runCLILoginFlow(sessionId: UUID, shouldFinalizeSession: Bool = true) async {
        defer {
            if shouldFinalizeSession {
                finalizeCLILoginSessionIfNeeded(sessionId: sessionId)
            }
        }

        do {
            let loginHome = try prepareCLILoginHomeDirectory()
            cliLoginHomeDir = loginHome
            Self.logger.info("CLI login started. home=\(loginHome.path, privacy: .public)")

            var env = ProcessInfo.processInfo.environment
            if let managedEnv = try? await CodexBinaryManager.shared.launchEnvironmentVariables() {
                env.merge(managedEnv) { _, new in new }
            }

            let runner = CodexLoginRunner()
            cliLoginHandle = try runner.startLogin(environment: env, codexHome: loginHome)
            Self.logger.info("CLI login process launched.")
            loginModeForSheet = "Direct OAuth"

            cliLoginStatus = NSLocalizedString("codex.accounts.add.cli.waiting", value: "Waiting for auth.json…", comment: "CLI login waiting status")

            let fileManager = FileManager.default
            let authFile = loginHome.appendingPathComponent("auth.json")
            let deadline = Date().addingTimeInterval(cliLoginTimeoutSeconds)
            let processExitGraceSeconds: TimeInterval = 4
            var processExitedAt: Date?
            while !Task.isCancelled {
                guard cliLoginSessionId == sessionId else { return }
                if fileManager.fileExists(atPath: authFile.path),
                   let data = try? Data(contentsOf: authFile),
                   !data.isEmpty {
                    break
                }

                if let urlRaw = cliLoginHandle?.loginURL, let url = URL(string: urlRaw) {
                    if loginURLForSheet?.absoluteString != url.absoluteString {
                        loginURLForSheet = url
                        isShowingLoginURLSheet = true
                    }
                }

                if let handle = cliLoginHandle, !handle.isRunning {
                    if processExitedAt == nil {
                        processExitedAt = Date()
                        Self.logger.info("CLI login process exited; waiting for auth.json grace period.")
                    } else if Date().timeIntervalSince(processExitedAt!) >= processExitGraceSeconds {
                        Self.logger.info("CLI login exited before auth.json was created.")
                        alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
                        alertMessage = NSLocalizedString(
                            "codex.accounts.add.cli.error.no_auth",
                            value: "Login did not create auth.json.",
                            comment: "CLI login did not create auth.json"
                        )
                        return
                    }
                }

                if Date() >= deadline {
                    Self.logger.info("CLI login timed out waiting for auth.json.")
                    alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
                    alertMessage = NSLocalizedString(
                        "codex.accounts.add.cli.error.no_auth",
                        value: "Login did not create auth.json.",
                        comment: "CLI login did not create auth.json"
                    )
                    return
                }

                try await Task.sleep(nanoseconds: 250_000_000)
            }

            guard !Task.isCancelled else { return }

            let data = try Data(contentsOf: authFile)
            guard let raw = String(data: data, encoding: .utf8) else {
                alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
                alertMessage = NSLocalizedString("codex.accounts.add.cli.error.no_auth", value: "Login did not create auth.json.", comment: "CLI login did not create auth.json")
                return
            }

            let account = try await codexAuthManager.recordCLILoginSnapshot(
                authJSONString: raw,
                preferredAccountID: cliLoginPreferredAccountId,
                loginAt: Date()
            )
            try await activateCodexAccountAfterLoginIfNeeded(account)
            Self.logger.info("CLI login completed; account persisted. accountId=\(account.id.uuidString, privacy: .public)")

            cliLoginHandle?.cancel()
            cliLoginHandle = nil
            cliLoginHomeDir = nil

            schedulePostLoginReload(preferredBackfillAccount: account)
        } catch {
            if error is CancellationError {
                Self.logger.info("CLI login task cancelled.")
                return
            }
            guard cliLoginSessionId == sessionId else { return }
            alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
            alertMessage = error.localizedDescription
        }
    }

    func activateCodexAccountAfterLoginIfNeeded(_ account: CodexAuthAccount) async throws {
        guard cliLoginPreferredAccountId != nil else { return }
        try await codexActivateAction(account, provider)
    }

    func schedulePostLoginReload(preferredBackfillAccount account: CodexAuthAccount? = nil) {
        Task { [weak self] in
            guard let self else { return }
            if let account {
                _ = await self.probeLoginSnapshotUsageAndBackfillEmailIfMissing(account: account)
            }
            if self.cliLoginPreferredAccountId != nil {
                await self.reloadCodexFromDisk(refreshUsage: false)
            } else {
                await self.load()
            }
            guard let accountID = account?.id,
                  let refreshedAccount = self.codexAccounts.first(where: { $0.id == accountID })
            else { return }
            // Force one immediate usage refresh for the newly logged-in snapshot.
            await self.refreshCodexAccountOutcome(refreshedAccount)
        }
    }

    func probeLoginSnapshotUsageAndBackfillEmailIfMissing(account: CodexAuthAccount) async -> ProviderAccountUsageOutcome {
        guard let authURL = codexAuthSourceURL(for: account) else {
            return Self.codexMissingAuthSourceOutcome(for: account)
        }
        let outcome = await codexOutcomeFetchAction(account, settings, authURL)

        if case let .success(result) = outcome.outcome.result,
           let email = result.usage.identity?.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines),
           Self.isNotBlank(email)
        {
            _ = try? await codexAuthManager.backfillEmailIfMissing(for: account, email: email)
        }
        return outcome
    }

    func requestActivateCodexAccount(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }) else { return }
        activatingCodexAccountId = nil
        pendingActivateCodexAccount = account
        isShowingActivateConfirm = true
    }

    func activateCodexAccountImmediately(id: UUID) async {
        requestActivateCodexAccount(id: id)
    }

    func codexInteractionState(accountID: UUID?) -> CodexAccountInteractionState {
        guard let accountID else { return .inactive }
        if activatingCodexAccountId != nil {
            return activatingCodexAccountId == accountID ? .switching : .inactive
        }
        if pendingActivateCodexAccount?.id == accountID {
            return .awaitingConfirmation
        }
        guard let account = codexAccounts.first(where: { $0.id == accountID }) else {
            return .inactive
        }
        return isActiveCodexAccount(account) ? .active : .inactive
    }

    func shouldActivateCodexAccountOnTap(id: UUID) -> Bool {
        codexInteractionState(accountID: id).allowsActivationRequest
    }

    func codexCardKind(accountID: UUID?) -> CodexAuthSummary.CardKind? {
        guard let accountID else { return nil }
        return codexAccountSummaries[accountID]?.cardKind
    }

    func codexAccountSupportsLogin(accountID: UUID?) -> Bool {
        codexCardKind(accountID: accountID) == .chatgptAccount
    }

    func codexAccountSupportsEditing(accountID: UUID?) -> Bool {
        switch codexCardKind(accountID: accountID) {
        case .officialAPIKey, .relayProfile:
            return true
        default:
            return false
        }
    }

    func beginEditActiveCodexConfiguredAccount() {
        guard let activeCodexAccountId else { return }
        beginEditCodexConfiguredAccount(id: activeCodexAccountId)
    }

    func validateActiveCodexConfiguredAccount() {
        guard let activeCodexAccountId,
              let account = codexAccounts.first(where: { $0.id == activeCodexAccountId }),
              codexAccountSupportsEditing(accountID: activeCodexAccountId),
              !codexRefreshingAccountIds.contains(activeCodexAccountId)
        else {
            return
        }

        codexRefreshingAccountIds.insert(activeCodexAccountId)
        Task { [weak self] in
            guard let self else { return }
            defer { self.codexRefreshingAccountIds.remove(activeCodexAccountId) }

            do {
                let validationMessage = try await self.codexConfiguredAccountValidateAction(account)
                self.alertTitle = NSLocalizedString("codex.accounts.action.validate", value: "Validate", comment: "Validate configured account")
                self.alertMessage = validationMessage
            } catch {
                self.alertTitle = NSLocalizedString("codex.accounts.action.validate", value: "Validate", comment: "Validate configured account")
                self.alertMessage = Self.errorSummaryText(error: error)
            }
        }
    }

    func reconcileCodexSelections() {
        let validIDs = Set(codexAccounts.map(\.id))
        selectedCodexAccountIDs = selectedCodexAccountIDs.intersection(validIDs)
        if selectedCodexAccountIDs.isEmpty, !isCodexMultiSelectionEnabled {
            return
        }
        if validIDs.isEmpty {
            setCodexMultiSelectionEnabled(false)
        }
    }

    func orderedUniqueValidAccountIDs(_ accountIDs: [UUID], validAccountIDs: Set<UUID>) -> [UUID] {
        var seen: Set<UUID> = []
        var result: [UUID] = []
        for id in accountIDs {
            if !validAccountIDs.contains(id) { continue }
            if seen.contains(id) { continue }
            seen.insert(id)
            result.append(id)
        }
        return result
    }

    func selectedCodexAccountIDsInDisplayOrder() -> [UUID] {
        codexAccounts
            .map(\.id)
            .filter { selectedCodexAccountIDs.contains($0) }
    }

    func isCodexSectionCollapsed(_ sectionID: String) -> Bool {
        collapsedCodexSectionIDs.contains(sectionID)
    }

    func toggleCodexSection(_ sectionID: String) {
        collapsedCodexSectionIDs = GenericSelectionStateResolver.resolveMultiSelection(
            current: collapsedCodexSectionIDs,
            tapped: sectionID
        )
    }

    func selectCodexSortOption(_ option: CodexAccountSortOption) {
        let next = GenericSelectionStateResolver.resolveSortSelection(
            currentKey: codexAccountSortOption,
            currentAscending: codexCurrentSortDirection == .ascending,
            tappedKey: option,
            defaultAscendingForTappedKey: Self.defaultCodexSortDirection(for: option) == .ascending
        )
        codexAccountSortOption = next.key
        codexCurrentSortDirection = next.ascending ? .ascending : .descending
    }

    func codexDirection(for option: CodexAccountSortOption) -> CodexSortDirection {
        option == codexAccountSortOption ? codexCurrentSortDirection : Self.defaultCodexSortDirection(for: option)
    }

    func requestDeleteCodexAccount(id: UUID) {
        guard let account = codexAccounts.first(where: { $0.id == id }) else {
            codexAccountOutcomes.removeAll { outcome in
                switch outcome.account {
                case let .tokenAccount(account):
                    return account.id == id
                case .default:
                    return false
                }
            }
            return
        }
        pendingDeleteCodexAccount = account
        isShowingDeleteConfirm = true
    }

    static func defaultCodexExportArchiveName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "codex-accounts-\(formatter.string(from: now)).zip"
    }

    static func defaultCodexImportExportArchiveName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "codex-import-\(formatter.string(from: now)).zip"
    }

    func requestLoginForCodexAccount(id: UUID) {
        if isRunningCLILogin {
            Self.logger.info("CLI login restart requested for account \(id.uuidString, privacy: .public).")
            cancelCLILoginIfNeeded()
        }
        startCLILoginFlow(preferredAccountId: id)
    }

    func confirmActivate() async {
        guard let account = pendingActivateCodexAccount else { return }
        pendingActivateCodexAccount = nil
        isShowingActivateConfirm = false
        activatingCodexAccountId = account.id
        await performCodexActivation(account)
    }

    func performCodexActivation(_ account: CodexAuthAccount) async {
        do {
            try await codexActivateAction(account, provider)
            pendingActivateCodexAccount = nil
            activeCodexAccountId = account.id
            if let postActivationLoadAction {
                await postActivationLoadAction()
            } else {
                await load()
            }
            activatingCodexAccountId = nil
        } catch {
            activatingCodexAccountId = nil
            pendingActivateCodexAccount = nil
            alertTitle = NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
            alertMessage = NSLocalizedString("codex.accounts.error.activate", value: "Failed to activate this account.", comment: "Error message")
        }
    }

    func confirmDeleteCodexAccount() async {
        guard let account = pendingDeleteCodexAccount else { return }
        do {
            if let codexDeleteAction {
                try await codexDeleteAction(account.id)
            } else {
                try await codexAuthManager.deleteAccount(id: account.id, provider: provider)
            }

            pendingDeleteCodexAccount = nil
            isShowingDeleteConfirm = false

            if let postDeleteLoadAction {
                await postDeleteLoadAction()
            } else {
                await reloadCodexFromDisk(refreshUsage: false)
            }
        } catch {
            let fallback = NSLocalizedString("codex.accounts.error.delete", value: "Failed to delete this account.", comment: "Error message")
            let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            alertTitle = NSLocalizedString("codex.accounts.title", value: "Accounts", comment: "Codex accounts title")
            alertMessage = Self.isNotBlank(message) ? message : fallback
        }
    }

    func isActiveCodexAccount(_ account: CodexAuthAccount) -> Bool {
        if let activeCodexAccountId {
            return account.id == activeCodexAccountId
        }
        guard let currentCodexAuthHashHex else { return false }
        guard let data = codexAuthManager.accountAuthData(for: account),
              let raw = String(data: data, encoding: .utf8)
        else { return false }
        return CodexAuthAccount.hashHex(for: raw) == currentCodexAuthHashHex
    }

}
