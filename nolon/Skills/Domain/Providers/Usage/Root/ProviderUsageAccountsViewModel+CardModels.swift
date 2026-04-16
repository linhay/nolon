import Foundation
import SwiftUI
import NolonUIFoundation
import ProviderUsage
import CodexBarProviderCatalog

struct ProviderUsageCodexCardModel {
    let accountID: UUID?
    let data: AccountCardViewData
    let presentation: AccountCardPresentation
    let failureDetail: String?
    let canRefresh: Bool
    let canLogin: Bool
}

enum ProviderUsageUnifiedAccountProvider: String {
    case claude
    case gemini
}

struct ProviderUsageCapabilities {
    let isCodexFamily: Bool
    let showsTokenTrend: Bool
    let usesUnifiedCardSkeleton: Bool
    let showsUnifiedImportCallout: Bool
}

struct ProviderUsageUnifiedAccountCardModel: Identifiable {
    let provider: ProviderUsageUnifiedAccountProvider
    let accountID: UUID
    let data: AccountCardViewData
    let isActive: Bool
    let onTap: () async -> Void
    let onAction: (AccountCardActionID) async -> Void

    var id: String { "\(provider.rawValue)-\(accountID.uuidString)" }
}

@MainActor
extension ProviderUsageAccountsViewModel.ClaudeState {
    func makeCardData(account: ClaudeAccount) -> (data: AccountCardViewData, isActive: Bool) {
        let isActive = isActiveAccount(account)
        let record = AccountRecordBuilder.claude(
            providerName: "Claude",
            account: account,
            isActive: isActive
        )
        let data = AccountCardViewDataMapper.map(
            record: record,
            primaryActions: isActive ? [] : [
                AccountCardActionFactory.primaryActivateAction(
                    title: NSLocalizedString("claude.accounts.action.activate", value: "激活", comment: "Activate Claude account")
                )
            ],
            menuActions: [
                AccountCardActionFactory.menuEditAction(
                    title: NSLocalizedString("claude.accounts.action.edit", value: "编辑", comment: "Edit Claude account")
                ),
                AccountCardActionFactory.menuRefreshAction(isEnabled: true)
            ],
            tapBehavior: isActive ? .none : .activate
        )
        return (data: data, isActive: isActive)
    }
}

@MainActor
extension ProviderUsageAccountsViewModel {
    var preferredUnifiedCardLiveOutcome: ProviderAccountUsageOutcome? {
        outcomes.first { outcome in
            if case .success = outcome.outcome.result {
                return true
            }
            return false
        } ?? outcomes.first
    }

    var capabilities: ProviderUsageCapabilities {
        guard let usageProvider else {
            return .init(
                isCodexFamily: false,
                showsTokenTrend: false,
                usesUnifiedCardSkeleton: true,
                showsUnifiedImportCallout: false
            )
        }
        switch usageProvider {
        case .codex:
            return .init(
                isCodexFamily: true,
                showsTokenTrend: true,
                usesUnifiedCardSkeleton: true,
                showsUnifiedImportCallout: false
            )
        case .claude:
            return .init(
                isCodexFamily: false,
                showsTokenTrend: true,
                usesUnifiedCardSkeleton: true,
                showsUnifiedImportCallout: false
            )
        case .gemini, .antigravity:
            return .init(
                isCodexFamily: false,
                showsTokenTrend: true,
                usesUnifiedCardSkeleton: true,
                showsUnifiedImportCallout: gemini.shouldShowImportAction
            )
        default:
            return .init(
                isCodexFamily: false,
                showsTokenTrend: false,
                usesUnifiedCardSkeleton: true,
                showsUnifiedImportCallout: false
            )
        }
    }

    func unifiedAccountSectionTitle(defaultProviderName: String) -> String? {
        guard let usageProvider else { return nil }
        switch usageProvider {
        case .claude:
            return NSLocalizedString("claude.accounts.title", value: "Claude Accounts", comment: "Claude accounts title")
        case .gemini, .antigravity:
            return defaultProviderName
        default:
            return nil
        }
    }

    var unifiedAccountEmptyState: (title: String, systemImage: String, description: String)? {
        guard usageProvider == .claude else { return nil }
        return (
            title: NSLocalizedString("claude.accounts.empty.title", value: "No Claude accounts", comment: "Empty Claude accounts title"),
            systemImage: "person.crop.circle.badge.exclamationmark",
            description: NSLocalizedString(
                "claude.accounts.empty.desc",
                value: "Use \"迁移\" or \"从 cc-switch 导入\" to add accounts.",
                comment: "Empty Claude accounts description"
            )
        )
    }

    func unifiedAccountCards(
        providerName: String,
        liveOutcome: ProviderAccountUsageOutcome?,
        isLoading: Bool
    ) -> [ProviderUsageUnifiedAccountCardModel] {
        guard let usageProvider else { return [] }
        switch usageProvider {
        case .claude:
            return claude.accounts.map { account in
                let model = claude.makeCardData(account: account)
                return .init(
                    provider: .claude,
                    accountID: account.id,
                    data: model.data,
                    isActive: model.isActive,
                    onTap: { [claude] in
                        guard !model.isActive else { return }
                        await claude.activateAccount(id: account.id)
                    },
                    onAction: { [claude] action in
                        switch action {
                        case .activate:
                            await claude.activateAccount(id: account.id)
                        case .edit:
                            claude.beginEditAccount(id: account.id)
                        case .refresh:
                            await self.load()
                        default:
                            break
                        }
                    }
                )
            }
        case .gemini, .antigravity:
            return gemini.accounts.map { account in
                let model = gemini.makeCardData(
                    account: account,
                    providerName: providerName,
                    liveOutcome: liveOutcome,
                    isLoading: isLoading
                )
                return .init(
                    provider: .gemini,
                    accountID: account.id,
                    data: model.data,
                    isActive: model.isActive,
                    onTap: { [gemini] in
                        guard !model.isActive else { return }
                        await gemini.activateAccount(id: account.id)
                    },
                    onAction: { [gemini] action in
                        switch action {
                        case .activate:
                            await gemini.activateAccount(id: account.id)
                        case .refresh:
                            await self.load()
                        case .delete:
                            await gemini.deleteAccount(id: account.id)
                        default:
                            break
                        }
                    }
                )
            }
        default:
            return []
        }
    }

    func displayedOutcomesForUnifiedAccounts() -> [ProviderAccountUsageOutcome] {
        guard let usageProvider else { return [] }
        if usageProvider == .claude {
            return ProviderUsageEngine.displayedClaudeUsageOutcomes(
                hasClaudeAccounts: !claude.accounts.isEmpty,
                outcomes: outcomes
            ).filter { outcome in
                if case let .failure(error) = outcome.outcome.result,
                   let usageError = error as? ProviderUsageError,
                   usageError == .unsupported(.claude) {
                    return false
                }
                return true
            }
        }
        return ProviderUsageEngine.displayedGenericUsageOutcomes(
            usageProvider: usageProvider,
            hasGeminiAccounts: !gemini.accounts.isEmpty,
            outcomes: outcomes
        )
    }
}

@MainActor
extension ProviderUsageAccountsViewModel.GeminiState {
    func makeCardData(
        account: GeminiAuthAccount,
        providerName: String,
        liveOutcome: ProviderAccountUsageOutcome?,
        isLoading: Bool
    ) -> (data: AccountCardViewData, isActive: Bool) {
        let isActive = isActiveAccount(account)
        let quota: AccountRecordQuota? = {
            guard isActive, let liveOutcome else { return nil }

            switch liveOutcome.outcome.result {
            case let .success(result):
                let modelUsages: [AccountModelUsage]? = {
                    let windows = result.usage.allWindows
                    guard !windows.isEmpty else { return nil }
                    return windows.map { item in
                        .init(
                            id: item.id,
                            title: item.title,
                            remainingPercent: item.window.remainingPercent,
                            resetsAt: item.window.resetsAt
                        )
                    }
                }()
                return .init(
                    provider: liveOutcome.provider,
                    accountTitle: AccountDisplayTextSupport.title(
                        primary: account.email,
                        fallback: account.name
                    ),
                    usage: result.usage,
                    modelUsages: modelUsages,
                    credits: result.credits,
                    creditsRefreshedAt: nil,
                    loginAt: account.lastLoginAt,
                    syncedAt: result.usage.updatedAt,
                    isLoading: isLoading,
                    showsEmptyState: false,
                    errorMessage: nil
                )
            case let .failure(error):
                return .init(
                    provider: liveOutcome.provider,
                    accountTitle: AccountDisplayTextSupport.title(
                        primary: account.email,
                        fallback: account.name
                    ),
                    usage: nil,
                    modelUsages: nil,
                    credits: nil,
                    creditsRefreshedAt: nil,
                    loginAt: account.lastLoginAt,
                    syncedAt: nil,
                    isLoading: isLoading,
                    showsEmptyState: false,
                    errorMessage: ProviderUsageErrorPresentationSupport.displayText(error: error)
                )
            }
        }()

        let record = AccountRecordBuilder.gemini(
            providerName: providerName,
            account: account,
            isActive: isActive,
            quota: quota
        )
        let data = AccountCardViewDataMapper.map(
            record: record,
            primaryActions: isActive ? [] : [
                AccountCardActionFactory.primaryActivateAction(
                    title: NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account"),
                )
            ],
            menuActions: [
                AccountCardActionFactory.menuRefreshAction(isEnabled: !isLoading),
                AccountCardActionFactory.menuDeleteAction()
            ],
            quotaRefreshActionID: nil,
            tapBehavior: isActive ? .none : .activate
        )
        return (data: data, isActive: isActive)
    }
}

@MainActor
extension ProviderUsageAccountsViewModel.CodexState {
    func makeUsageCardModel(
        outcome: ProviderAccountUsageOutcome,
        isRunningCLILogin: Bool
    ) -> ProviderUsageCodexCardModel {
        let accountID: UUID? = {
            switch outcome.account {
            case .default:
                return nil
            case let .tokenAccount(account):
                return account.id
            }
        }()

        let interactionState = interactionState(accountID: accountID)
        let isBatchSelected = isAccountSelected(id: accountID)
        let presentation = AccountCardPresentation.codex(
            state: interactionState.presentationState(
                isBatchSelected: isBatchSelected,
                selectableAccountCount: accounts.count
            )
        )
        let summary = accountID.flatMap { accountSummaries[$0] }
        let isSelfManagedConfiguredAccount = summary?.cardKind?.isSelfManagedConfiguredAccount == true
        let isRefreshing = accountID.map { refreshingAccountIds.contains($0) } ?? false
        let canLogin = accountSupportsLogin(accountID: accountID)
        let isLoggingIn = accountID != nil
            && isRunningCLILogin
            && cliLoginPreferredAccountId == accountID
        let creditsRefreshedAt = creditsRefreshedAt(for: outcome, activeAccountID: activeAccountId)

        let liveFailureError: Error? = {
            if case let .failure(error) = outcome.outcome.result { return error }
            return nil
        }()
        let failurePresentation = CodexAccountFailurePresentationBuilder.build(
            liveFailureError: isSelfManagedConfiguredAccount ? nil : liveFailureError,
            persistedFailureMessage: isSelfManagedConfiguredAccount ? nil : summary?.lastSyncFailureMessage,
            canRelogin: isSelfManagedConfiguredAccount ? false : canLogin
        )
        let title = AccountDisplayTextSupport.codexTitle(
            summary: summary,
            relativeAuthPath: accountID.flatMap { id in accounts.first(where: { $0.id == id })?.relativeAuthPath },
            defaultName: outcome.displayName,
            accountID: accountID
        )

        let primaryActions: [AccountCardActionViewData] = {
            guard !isSelfManagedConfiguredAccount else { return [] }
            guard let failureDetailRaw = failurePresentation.rawDetail else { return [] }
            var actions: [AccountCardActionViewData] = [CodexAccountActionFactory.primaryCopyErrorAction(canRelogin: canLogin)]
            if canLogin {
                actions.append(CodexAccountActionFactory.primaryReloginAction(isEnabled: !isLoggingIn))
            } else if !failureDetailRaw.isEmpty {
                _ = failureDetailRaw
            }
            return actions
        }()

        let menuActions: [AccountCardMenuActionViewData] = {
            var items: [AccountCardMenuActionViewData] = []
            if accountID != nil {
                items.append(CodexAccountActionFactory.menuRefreshAction(isEnabled: !isRefreshing))
            }
            if canLogin {
                items.append(CodexAccountActionFactory.menuReloginAction(isEnabled: !isLoggingIn))
            }
            if accountID != nil {
                if interactionState.allowsActivationRequest {
                    items.append(CodexAccountActionFactory.menuActivateAction())
                }
                items.append(CodexAccountActionFactory.menuCopyAuthJSONAction())
                items.append(CodexAccountActionFactory.menuEditAuthJSONAction())
                items.append(CodexAccountActionFactory.menuRevealInFinderAction())
                items.append(CodexAccountActionFactory.menuDeleteAction())
            }
            return items
        }()

        let record = AccountRecordBuilder.codexUsage(
            outcome: outcome,
            summary: summary,
            presentation: presentation,
            title: title,
            creditsRefreshedAt: creditsRefreshedAt,
            isRefreshing: isRefreshing,
            canRelogin: canLogin
        )

        let data = AccountCardViewDataMapper.map(
            record: record,
            primaryActions: primaryActions,
            menuActions: menuActions,
            footer: isLoggingIn ? .init(
                leadingTag: nil,
                trailingText: NSLocalizedString("codex.accounts.add.cli.running", value: "Logging in…", comment: "CLI login running status")
            ) : nil,
            quotaRefreshActionID: nil,
            tapBehavior: .none
        )

        return .init(
            accountID: accountID,
            data: data,
            presentation: presentation,
            failureDetail: failurePresentation.rawDetail,
            canRefresh: accountID != nil,
            canLogin: canLogin
        )
    }

    func handleUsageCardAction(
        _ action: AccountCardActionID,
        model: ProviderUsageCodexCardModel
    ) {
        switch action {
        case .refresh:
            guard model.canRefresh, let accountID = model.accountID else { return }
            refreshAccount(id: accountID)
        case .relogin:
            guard model.canLogin, let accountID = model.accountID else { return }
            requestLoginForAccount(id: accountID)
        case .activate:
            if let accountID = model.accountID {
                requestActivateAccount(id: accountID)
            }
        case .copyError:
            if let detail = model.failureDetail {
                copyErrorText(detail)
            }
        case .revealInFinder:
            if let accountID = model.accountID {
                revealAccountInFinder(id: accountID)
            }
        case .copyAuthJSON:
            if let accountID = model.accountID {
                copyAccountAuthJSON(id: accountID)
            }
        case .editAuthJSON:
            if let accountID = model.accountID {
                editAccountAuthJSON(id: accountID)
            }
        case .delete:
            if let accountID = model.accountID {
                requestDeleteAccount(id: accountID)
            }
        default:
            break
        }
    }

    private func creditsRefreshedAt(
        for outcome: ProviderAccountUsageOutcome,
        activeAccountID: UUID?
    ) -> Date? {
        switch outcome.account {
        case let .tokenAccount(account):
            return accountCreditsRefreshedAt[account.id]
        case .default:
            if let activeAccountID {
                return accountCreditsRefreshedAt[activeAccountID]
            }
            return nil
        }
    }
}
