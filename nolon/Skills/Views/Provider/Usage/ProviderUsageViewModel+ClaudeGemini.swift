import Foundation
import ProviderCatalog
import ProviderUsage
import CodexBarProviderCatalog
import OSLog

@MainActor
extension ProviderUsageViewModel {
    func migrateClaudeFromCurrentSettings() async {
        guard usageProvider == .claude else { return }
        do {
            guard let imported = try await claudeAccountManager.importFromCurrentSettings(provider: provider) else {
                alertTitle = NSLocalizedString("claude.accounts.title", value: "Claude Accounts", comment: "Claude accounts title")
                alertMessage = NSLocalizedString(
                    "claude.accounts.migrate.empty",
                    value: "No Claude settings were found to migrate.",
                    comment: "No Claude settings found to migrate"
                )
                return
            }

            _ = try await claudeAccountManager.activateAccount(id: imported.id, provider: provider)
            await load()

            alertTitle = NSLocalizedString("claude.accounts.title", value: "Claude Accounts", comment: "Claude accounts title")
            alertMessage = NSLocalizedString(
                "claude.accounts.migrate.success",
                value: "Migration completed and the imported account is now active.",
                comment: "Claude migration success message"
            )
        } catch {
            alertTitle = NSLocalizedString("claude.accounts.title", value: "Claude Accounts", comment: "Claude accounts title")
            alertMessage = error.localizedDescription
        }
    }

    func importClaudeFromCCSwitch() async {
        guard usageProvider == .claude else { return }
        do {
            let report = try await claudeAccountManager.importFromCCSwitch()
            if report.totalCandidates == 0 {
                alertTitle = NSLocalizedString("claude.accounts.title", value: "Claude Accounts", comment: "Claude accounts title")
                alertMessage = NSLocalizedString(
                    "claude.accounts.cc_switch.empty",
                    value: "No Claude accounts were found in cc-switch.",
                    comment: "No Claude accounts found in cc-switch"
                )
                return
            }

            if try await claudeAccountManager.activeAccountID() == nil {
                let accounts = try await claudeAccountManager.loadAccounts()
                if let latest = accounts.max(by: { $0.updatedAt < $1.updatedAt }) {
                    _ = try await claudeAccountManager.activateAccount(id: latest.id, provider: provider)
                }
            }

            await load()

            let format = NSLocalizedString(
                "claude.accounts.cc_switch.report",
                value: "Imported %d, replaced %d, skipped %d.",
                comment: "Claude cc-switch import report"
            )
            alertTitle = NSLocalizedString("claude.accounts.title", value: "Claude Accounts", comment: "Claude accounts title")
            alertMessage = String(
                format: format,
                report.importedCount,
                report.replacedCount,
                report.skippedCount
            )
        } catch {
            alertTitle = NSLocalizedString("claude.accounts.title", value: "Claude Accounts", comment: "Claude accounts title")
            alertMessage = error.localizedDescription
        }
    }

    func isActiveClaudeAccount(_ account: ClaudeAccount) -> Bool {
        account.id == activeClaudeAccountId
    }

    func activateClaudeAccount(id: UUID) async {
        guard usageProvider == .claude else { return }
        do {
            _ = try await claudeAccountManager.activateAccount(id: id, provider: provider)
            await load()
        } catch {
            alertTitle = NSLocalizedString("claude.accounts.title", value: "Claude Accounts", comment: "Claude accounts title")
            alertMessage = error.localizedDescription
        }
    }

    func isActiveGeminiAccount(_ account: GeminiAuthAccount) -> Bool {
        account.id == activeGeminiAccountId
    }

    func activateGeminiAccount(id: UUID) async {
        guard let usageProvider, usageProvider == .gemini || usageProvider == .antigravity else { return }
        do {
            _ = try await geminiAuthStore.activate(provider: usageProvider, accountID: id)
            await load()
        } catch {
            alertTitle = provider.name
            alertMessage = error.localizedDescription
        }
    }

    func deleteGeminiAccount(id: UUID) async {
        guard let usageProvider, usageProvider == .gemini || usageProvider == .antigravity else { return }
        do {
            try await geminiAuthStore.delete(provider: usageProvider, accountID: id)
            await load()
        } catch {
            alertTitle = provider.name
            alertMessage = error.localizedDescription
        }
    }

    func presentGeminiImportConfirmation() {
        guard let candidate = detectedGeminiImportCandidate else { return }
        pendingGeminiImportCandidate = candidate
        isShowingGeminiImportConfirm = true
    }

    func continueGeminiOAuthLoginWithoutImport() {
        isShowingGeminiImportConfirm = false
        pendingGeminiImportCandidate = nil
        startGeminiOAuthLoginFlow()
    }

    func importGeminiGlobalSessionAfterConfirmation() async {
        guard let usageProvider, usageProvider == .gemini || usageProvider == .antigravity else { return }
        isShowingGeminiImportConfirm = false
        pendingGeminiImportCandidate = nil

        do {
            let imported = try await geminiAuthStore.importFromCLIGlobalSession(
                provider: usageProvider,
                environment: ProcessInfo.processInfo.environment
            )
            if imported != nil {
                detectedGeminiImportCandidate = nil
                await load()
                return
            }
            startGeminiOAuthLoginFlow()
        } catch {
            alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
            alertMessage = error.localizedDescription
        }
    }

    var shouldShowGeminiImportAction: Bool {
        Self.shouldShowGeminiImportAction(
            usageProvider: usageProvider,
            outcomes: outcomes,
            candidateAvailable: detectedGeminiImportCandidate != nil
        )
    }

    static func shouldShowGeminiImportAction(
        usageProvider: UsageProvider?,
        outcomes: [ProviderAccountUsageOutcome],
        candidateAvailable: Bool
    ) -> Bool {
        _ = outcomes
        return usageProvider == .gemini && candidateAvailable
    }

    func refreshGeminiImportCandidateAvailabilityIfNeeded(for usageProvider: UsageProvider) async {
        guard usageProvider == .gemini else {
            detectedGeminiImportCandidate = nil
            return
        }

        do {
            detectedGeminiImportCandidate = try await geminiAuthStore.globalSessionImportCandidate(
                provider: usageProvider,
                environment: ProcessInfo.processInfo.environment
            )
        } catch {
            detectedGeminiImportCandidate = nil
            Self.logger.error("Gemini import candidate refresh failed: \(String(describing: error), privacy: .public)")
        }
    }

    func startGeminiLoginFlowAfterImportCheck() async {
        guard let usageProvider, usageProvider == .gemini || usageProvider == .antigravity else { return }
        guard !isRunningCLILogin else { return }

        guard usageProvider == .gemini else {
            startGeminiOAuthLoginFlow()
            return
        }

        if let candidate = detectedGeminiImportCandidate {
            pendingGeminiImportCandidate = candidate
            isShowingGeminiImportConfirm = true
            return
        }

        do {
            if let candidate = try await geminiAuthStore.globalSessionImportCandidate(
                provider: usageProvider,
                environment: ProcessInfo.processInfo.environment
            ) {
                detectedGeminiImportCandidate = candidate
                pendingGeminiImportCandidate = candidate
                isShowingGeminiImportConfirm = true
                return
            }
            detectedGeminiImportCandidate = nil
        } catch {
            detectedGeminiImportCandidate = nil
            Self.logger.error("Gemini import candidate check failed: \(String(describing: error), privacy: .public)")
        }

        startGeminiOAuthLoginFlow()
    }

    func startGeminiOAuthLoginFlow() {
        guard let usageProvider, usageProvider == .gemini || usageProvider == .antigravity else { return }
        guard !isRunningCLILogin else { return }

        let sessionID = UUID()
        cliLoginSessionId = sessionID
        isRunningCLILogin = true
        cliLoginStatus = NSLocalizedString("codex.accounts.add.cli.running", value: "Logging in…", comment: "CLI login running status")

        cliLoginTask?.cancel()
        cliLoginTask = Task { [weak self] in
            guard let self else { return }
            await self.runGeminiLoginFlow(sessionId: sessionID, usageProvider: usageProvider)
        }
    }

    private func runGeminiLoginFlow(sessionId: UUID, usageProvider: UsageProvider) async {
        defer {
            finalizeCLILoginSessionIfNeeded(sessionId: sessionId)
        }

        do {
            let accountID = UUID()
            let runtimeHome = try await geminiAuthStore.runtimeHomeURL(provider: usageProvider, accountID: accountID)
            let runner = GeminiLoginRunner()
            let handle = try runner.startOAuthLogin(
                provider: usageProvider,
                accountID: accountID,
                runtimeHomeURL: runtimeHome
            )
            geminiLoginHandle = handle
            loginModeForSheet = "Gemini OAuth"
            cliLoginStatus = NSLocalizedString(
                "codex.accounts.add.cli.waiting",
                value: "Waiting for auth.json…",
                comment: "CLI login waiting status"
            )

            let tokenFile = runtimeHome
                .appendingPathComponent(".gemini", isDirectory: true)
                .appendingPathComponent("mcp-oauth-tokens-v2.json")
            let deadline = Date().addingTimeInterval(cliLoginTimeoutSeconds)
            let processExitGraceSeconds: TimeInterval = 4
            var processExitedAt: Date?

            while !Task.isCancelled {
                guard cliLoginSessionId == sessionId else { return }

                if FileManager.default.fileExists(atPath: tokenFile.path),
                   let data = try? Data(contentsOf: tokenFile),
                   !data.isEmpty {
                    break
                }

                if let urlRaw = handle.loginURL, let url = URL(string: urlRaw) {
                    if loginURLForSheet?.absoluteString != url.absoluteString {
                        loginURLForSheet = url
                        isShowingLoginURLSheet = true
                    }
                }

                if !handle.isRunning {
                    if processExitedAt == nil {
                        processExitedAt = Date()
                    } else if Date().timeIntervalSince(processExitedAt!) >= processExitGraceSeconds {
                        throw GeminiLoginError.authNotCompleted
                    }
                }

                if Date() >= deadline {
                    throw GeminiLoginError.loginTimedOut
                }

                try await Task.sleep(nanoseconds: 250_000_000)
            }

            guard !Task.isCancelled else { return }

            let defaultName = usageProvider == .antigravity ? "Antigravity OAuth" : "Gemini OAuth"
            _ = try await geminiAuthStore.upsertAccount(
                provider: usageProvider,
                accountID: accountID,
                name: defaultName,
                method: .oauthPersonal,
                markActive: true,
                updateLastLoginAt: true
            )

            await load()
        } catch {
            if error is CancellationError { return }
            guard cliLoginSessionId == sessionId else { return }
            alertTitle = NSLocalizedString("codex.cli_login.title", value: "CLI Login", comment: "CLI login title")
            alertMessage = error.localizedDescription
        }
    }
}
