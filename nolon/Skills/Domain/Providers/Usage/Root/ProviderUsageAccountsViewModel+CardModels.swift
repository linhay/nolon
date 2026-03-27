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
                .init(
                    id: "activate",
                    actionID: .activate,
                    title: NSLocalizedString("claude.accounts.action.activate", value: "激活", comment: "Activate Claude account"),
                    systemImage: nil,
                    role: nil,
                    prominence: .primary,
                    isEnabled: true
                )
            ],
            menuActions: [
                .init(
                    id: "refresh",
                    actionID: .refresh,
                    title: NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh"),
                    systemImage: "arrow.clockwise",
                    role: nil,
                    isEnabled: true
                )
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
                showsTokenTrend: false,
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
                    accountTitle: account.email ?? account.name,
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
                    accountTitle: account.email ?? account.name,
                    usage: nil,
                    modelUsages: nil,
                    credits: nil,
                    creditsRefreshedAt: nil,
                    loginAt: account.lastLoginAt,
                    syncedAt: nil,
                    isLoading: isLoading,
                    showsEmptyState: false,
                    errorMessage: ProviderUsageErrorFormatter.detailText(error: error)
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
                .init(
                    id: "activate",
                    actionID: .activate,
                    title: NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account"),
                    systemImage: nil,
                    role: nil,
                    prominence: .primary,
                    isEnabled: true
                )
            ],
            menuActions: [
                .init(
                    id: "refresh",
                    actionID: .refresh,
                    title: NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh"),
                    systemImage: "arrow.clockwise",
                    role: nil,
                    isEnabled: !isLoading
                ),
                .init(
                    id: "delete",
                    actionID: .delete,
                    title: NSLocalizedString("codex.accounts.delete.title", value: "Delete Account", comment: "Delete account title"),
                    systemImage: "trash",
                    role: .destructive,
                    isEnabled: true
                )
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
        hasActiveGatewayCardSelection: Bool,
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

        let isPending: Bool = {
            guard let accountID else { return false }
            return pendingActivateAccount?.id == accountID
        }()

        let isActive: Bool = {
            guard let accountID else { return false }
            guard let saved = accounts.first(where: { $0.id == accountID }) else { return false }
            return isActiveAccount(saved)
        }()
        let isActivePresentation = isActive && !hasActiveGatewayCardSelection
        let isBatchSelected = isAccountSelected(id: accountID)

        let presentation = AccountCardPresentation.codex(
            isActive: isActivePresentation,
            isPending: isPending,
            isBatchSelected: isBatchSelected,
            selectableAccountCount: accounts.count
        )
        let summary = accountID.flatMap { accountSummaries[$0] }
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
        let persistedFailureDetail = summary?.lastSyncFailureMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        let failureDetail: String? = {
            if let persistedFailureDetail, !persistedFailureDetail.isEmpty { return persistedFailureDetail }
            if let liveFailureError { return ProviderUsageErrorFormatter.detailText(error: liveFailureError) }
            return nil
        }()

        let title = ProviderUsageAccountDisplayNameResolver.resolve(
            email: summary?.email,
            summaryAccountID: summary?.accountID,
            cardKind: summary.map { "\($0.cardKind)" },
            apiKeySuffix: summary?.apiKeySuffix,
            relayModelProvider: summary?.relayModelProvider,
            relayBaseURL: summary?.relayBaseURL,
            relativeAuthPath: accountID.flatMap { id in accounts.first(where: { $0.id == id })?.relativeAuthPath },
            defaultName: outcome.displayName,
            accountID: accountID
        )

        let primaryActions: [AccountCardActionViewData] = {
            guard let failureDetail else { return [] }
            var actions: [AccountCardActionViewData] = [
                .init(
                    id: "copyError",
                    actionID: .copyError,
                    title: NSLocalizedString("codex.accounts.copy_error", value: "Copy error", comment: "Copy account error"),
                    systemImage: nil,
                    role: nil,
                    prominence: canLogin ? .secondary : .primary,
                    isEnabled: true
                )
            ]
            if canLogin {
                actions.append(
                    .init(
                        id: "relogin",
                        actionID: .relogin,
                        title: NSLocalizedString("codex.accounts.relogin", value: "Re-login", comment: "Re-login account"),
                        systemImage: nil,
                        role: nil,
                        prominence: .primary,
                        isEnabled: !isLoggingIn
                    )
                )
            } else if !failureDetail.isEmpty {
                _ = failureDetail
            }
            return actions
        }()

        let menuActions: [AccountCardMenuActionViewData] = {
            var items: [AccountCardMenuActionViewData] = []
            if accountID != nil {
                items.append(
                    .init(
                        id: "refresh",
                        actionID: .refresh,
                        title: NSLocalizedString("usage.monitor.refresh", value: "Refresh", comment: "Refresh"),
                        systemImage: "arrow.clockwise",
                        role: nil,
                        isEnabled: !isRefreshing
                    )
                )
            }
            if canLogin {
                items.append(
                    .init(
                        id: "relogin-menu",
                        actionID: .relogin,
                        title: NSLocalizedString("codex.accounts.relogin", value: "Re-login", comment: "Re-login account"),
                        systemImage: "person.badge.key",
                        role: nil,
                        isEnabled: !isLoggingIn
                    )
                )
            }
            if accountID != nil {
                if !isActivePresentation {
                    items.append(
                        .init(
                            id: "activate",
                            actionID: .activate,
                            title: NSLocalizedString("codex.accounts.action.activate", value: "Activate", comment: "Activate account"),
                            systemImage: "checkmark.circle",
                            role: nil,
                            isEnabled: true
                        )
                    )
                }
                items.append(.init(id: "copy-auth-json", actionID: .copyAuthJSON, title: NSLocalizedString("codex.accounts.menu.copy_auth_json", value: "Copy auth.json", comment: "Copy auth json"), systemImage: "doc.on.doc.fill", role: nil, isEnabled: true))
                items.append(.init(id: "edit-auth-json", actionID: .editAuthJSON, title: NSLocalizedString("codex.accounts.menu.edit_auth_json", value: "Edit auth.json", comment: "Edit auth json"), systemImage: "pencil", role: nil, isEnabled: true))
                items.append(.init(id: "reveal", actionID: .revealInFinder, title: NSLocalizedString("action.show_in_finder", comment: "Show in Finder"), systemImage: "folder", role: nil, isEnabled: true))
                items.append(.init(id: "delete", actionID: .delete, title: NSLocalizedString("codex.accounts.delete.title", value: "Delete Account", comment: "Delete account title"), systemImage: "trash", role: .destructive, isEnabled: true))
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
            failureDetail: failureDetail,
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
                Task { await activateAccountImmediately(id: accountID) }
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
