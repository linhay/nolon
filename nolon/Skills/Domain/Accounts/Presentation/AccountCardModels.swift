import Foundation
import SwiftUI
import ProviderUsage
import CodexBarProviderCatalog
import NolonUIFoundation

enum AccountCardActionID: String, Equatable, Sendable {
    case activate
    case refresh
    case edit
    case relogin
    case validate
    case copyError
    case copyAccountID
    case copyAuthPath
    case copyAuthJSON
    case editAuthJSON
    case revealInFinder
    case delete
}

enum AccountCardTapBehavior: Equatable, Sendable {
    case none
    case activate
    case toggleSelection
    case openProvider
}

struct AccountRecordID: Hashable, Equatable {
    let provider: UsageProvider
    let rawValue: String
}

enum AccountRecordSource: Equatable, Sendable {
    case local
    case migrated
    case imported
    case ccSwitch
    case detected
    case unknown
}

enum AccountActivationState: Equatable, Sendable {
    case inactive
    case active
    case pending
    case transitioning
    case selected
}

enum AccountHealthState: Equatable, Sendable {
    case healthy
    case warning
    case failed
    case loading
    case empty
    case unsupported
}

struct AccountIdentity: Equatable, Sendable {
    let displayName: String
    let subtitle: String?
    let meta: String?
}

enum AccountRecordFieldKind: Equatable, Sendable {
    case kv
    case message
    case code
}

struct AccountRecordField: Identifiable, Equatable, Sendable {
    let id: String
    let kind: AccountRecordFieldKind
    let label: String?
    let value: String
    let auxiliary: String?
    let tone: AccountSummaryCardBadgeTone?
}

struct AccountModelUsage: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let remainingPercent: Double
    let resetsAt: Date?
}

struct AccountRecordQuota: Equatable {
    let provider: UsageProvider
    let accountTitle: String?
    let usage: UsageSnapshot?
    let modelUsages: [AccountModelUsage]?
    let credits: CreditsSnapshot?
    let creditsRefreshedAt: Date?
    let loginAt: Date?
    let syncedAt: Date?
    let isLoading: Bool
    let showsEmptyState: Bool
    let errorMessage: String?

    init(
        provider: UsageProvider,
        accountTitle: String?,
        usage: UsageSnapshot?,
        modelUsages: [AccountModelUsage]? = nil,
        credits: CreditsSnapshot?,
        creditsRefreshedAt: Date?,
        loginAt: Date?,
        syncedAt: Date?,
        isLoading: Bool,
        showsEmptyState: Bool,
        errorMessage: String?
    ) {
        self.provider = provider
        self.accountTitle = accountTitle
        self.usage = usage
        self.modelUsages = modelUsages
        self.credits = credits
        self.creditsRefreshedAt = creditsRefreshedAt
        self.loginAt = loginAt
        self.syncedAt = syncedAt
        self.isLoading = isLoading
        self.showsEmptyState = showsEmptyState
        self.errorMessage = errorMessage
    }
}

struct AccountRecord: Identifiable, Equatable {
    let id: AccountRecordID
    let providerName: String
    let source: AccountRecordSource
    let identity: AccountIdentity
    let activationState: AccountActivationState
    let healthState: AccountHealthState
    let bodyFields: [AccountRecordField]
    let detailFields: [AccountRecordField]
    let quota: AccountRecordQuota?
    let accessibilityLabel: String
}

protocol ProviderAccountRecordConvertible {
    var providerUsage: UsageProvider { get }
    var accountRecordRawID: String { get }
    var accountSortDate: Date { get }
    var accountAccessibilityName: String { get }
    func accountSource() -> AccountRecordSource
    func accountIdentity() -> AccountIdentity
    func accountHealth(quota: AccountRecordQuota?) -> AccountHealthState
    func accountBodyFields(quota: AccountRecordQuota?) -> [AccountRecordField]
    func accountDetailFields(quota: AccountRecordQuota?) -> [AccountRecordField]
}

extension ClaudeAccount: ProviderAccountRecordConvertible {
    var providerUsage: UsageProvider { .claude }
    var accountRecordRawID: String { id.uuidString.lowercased() }
    var accountSortDate: Date { updatedAt }
    var accountAccessibilityName: String { name }

    func accountSource() -> AccountRecordSource {
        switch source {
        case .manual:
            return .local
        case .migrated:
            return .migrated
        case .ccSwitch:
            return .ccSwitch
        }
    }

    func accountIdentity() -> AccountIdentity {
        .init(
            displayName: name,
            subtitle: baseURL,
            meta: updatedAt.formatted(date: .abbreviated, time: .shortened)
        )
    }

    func accountHealth(quota _: AccountRecordQuota?) -> AccountHealthState {
        switch lastValidationStatus {
        case .some(true):
            return .healthy
        case .some(false):
            return .failed
        case .none:
            return .warning
        }
    }

    func accountBodyFields(quota _: AccountRecordQuota?) -> [AccountRecordField] {
        [
            .init(
                id: "source",
                kind: .kv,
                label: NSLocalizedString("accounts.provider.source", value: "Source", comment: "Account source"),
                value: source.rawValue,
                auxiliary: nil,
                tone: nil
            )
        ]
    }

    func accountDetailFields(quota _: AccountRecordQuota?) -> [AccountRecordField] {
        []
    }
}

extension GeminiAuthAccount: ProviderAccountRecordConvertible {
    var providerUsage: UsageProvider { providerID }
    var accountRecordRawID: String { id.uuidString.lowercased() }
    var accountSortDate: Date { lastLoginAt ?? createdAt }
    var accountAccessibilityName: String { name }

    func accountSource() -> AccountRecordSource { .local }

    func accountIdentity() -> AccountIdentity {
        return .init(
            displayName: name,
            subtitle: AccountDisplayTextSupport.subtitle(email, project),
            meta: (lastLoginAt ?? createdAt).formatted(date: .abbreviated, time: .shortened)
        )
    }

    func accountHealth(quota: AccountRecordQuota?) -> AccountHealthState {
        quota?.errorMessage == nil ? .healthy : .failed
    }

    func accountBodyFields(quota: AccountRecordQuota?) -> [AccountRecordField] {
        guard quota == nil else { return [] }
        return [
            .init(
                id: "method",
                kind: .kv,
                label: NSLocalizedString("accounts.provider.method", value: "Method", comment: "Account method"),
                value: method.rawValue,
                auxiliary: nil,
                tone: nil
            ),
            .init(
                id: "project",
                kind: .kv,
                label: NSLocalizedString("accounts.provider.project", value: "Project", comment: "Account project"),
                value: project ?? NSLocalizedString("generic.unknown", value: "Unknown", comment: "Unknown"),
                auxiliary: location,
                tone: nil
            )
        ]
    }

    func accountDetailFields(quota _: AccountRecordQuota?) -> [AccountRecordField] {
        [
            .init(
                id: "runtime",
                kind: .code,
                label: NSLocalizedString("accounts.provider.runtime_home", value: "Runtime Home", comment: "Runtime home"),
                value: runtimeHomeRelativePath,
                auxiliary: nil,
                tone: nil
            )
        ]
    }
}

enum AccountRecordBuilder {
    struct SummaryUsageAccountAdapter: ProviderAccountRecordConvertible {
        let usageProvider: UsageProvider
        let summary: NolonAccountsViewModel.AccountUsageSummary

        var providerUsage: UsageProvider { usageProvider }
        var accountRecordRawID: String { summary.id }
        var accountSortDate: Date { summary.latestUpdatedAt ?? .distantPast }
        var accountAccessibilityName: String { summary.accountLabel }

        func accountSource() -> AccountRecordSource { .local }

        func accountIdentity() -> AccountIdentity {
            .init(
                displayName: AccountDisplayTextSupport.title(
                    primary: summary.accountEmail,
                    fallback: summary.accountLabel
                ),
                subtitle: summary.plan,
                meta: summary.latestUpdatedAt?.formatted(date: .abbreviated, time: .shortened)
            )
        }

        func accountHealth(quota _: AccountRecordQuota?) -> AccountHealthState {
            summary.errorMessage == nil ? .healthy : .failed
        }

        func accountBodyFields(quota _: AccountRecordQuota?) -> [AccountRecordField] {
            []
        }

        func accountDetailFields(quota _: AccountRecordQuota?) -> [AccountRecordField] {
            summary.isSnapshotOnly ? [
                .init(
                    id: "snapshotOnly",
                    kind: .message,
                    label: nil,
                    value: NSLocalizedString("accounts.provider.readonly", value: "Read-only summary", comment: "Read-only summary"),
                    auxiliary: nil,
                    tone: nil
                )
            ] : []
        }
    }

    static func providerAccount<Account: ProviderAccountRecordConvertible>(
        providerName: String,
        account: Account,
        isActive: Bool,
        quota: AccountRecordQuota? = nil
    ) -> AccountRecord {
        AccountRecord(
            id: .init(provider: account.providerUsage, rawValue: account.accountRecordRawID),
            providerName: providerName,
            source: account.accountSource(),
            identity: account.accountIdentity(),
            activationState: isActive ? .active : .inactive,
            healthState: account.accountHealth(quota: quota),
            bodyFields: account.accountBodyFields(quota: quota),
            detailFields: account.accountDetailFields(quota: quota),
            quota: quota,
            accessibilityLabel: "\(providerName) \(account.accountAccessibilityName)"
        )
    }

    static func claude(
        providerName: String,
        account: ClaudeAccount,
        isActive: Bool
    ) -> AccountRecord {
        providerAccount(providerName: providerName, account: account, isActive: isActive)
    }

    static func gemini(
        providerName: String,
        account: GeminiAuthAccount,
        isActive: Bool,
        quota: AccountRecordQuota?
    ) -> AccountRecord {
        providerAccount(providerName: providerName, account: account, isActive: isActive, quota: quota)
    }

    static func summaryUsageAccount(
        providerName: String,
        usageProvider: UsageProvider,
        summary: NolonAccountsViewModel.AccountUsageSummary,
        isActive: Bool
    ) -> AccountRecord {
        let adapter = SummaryUsageAccountAdapter(usageProvider: usageProvider, summary: summary)
        let snapshot = summary.errorMessage == nil ? UsageSnapshot(
            identity: UsageIdentity(
                accountEmail: summary.accountEmail,
                accountOrganization: nil,
                loginMethod: nil,
                plan: summary.plan
            ),
            primary: summary.primaryUsedPercent.map { RateWindow(usedPercent: $0) },
            secondary: nil,
            tertiary: nil,
            updatedAt: summary.latestUpdatedAt ?? Date()
        ) : nil

        return providerAccount(
            providerName: providerName,
            account: adapter,
            isActive: isActive,
            quota: .init(
                provider: usageProvider,
                accountTitle: AccountDisplayTextSupport.title(
                    primary: summary.accountEmail,
                    fallback: summary.accountLabel
                ),
                usage: snapshot,
                credits: nil,
                creditsRefreshedAt: nil,
                loginAt: nil,
                syncedAt: summary.latestUpdatedAt,
                isLoading: false,
                showsEmptyState: snapshot == nil,
                errorMessage: summary.errorMessage
            )
        )
    }

    static func codexUsage(
        outcome: ProviderAccountUsageOutcome,
        summary: CodexAuthSummary?,
        presentation: AccountCardPresentation,
        title: String,
        creditsRefreshedAt: Date?,
        isRefreshing: Bool,
        canRelogin: Bool
    ) -> AccountRecord {
        let isSelfManagedConfiguredAccount = summary?.cardKind?.isSelfManagedConfiguredAccount == true
        let liveFailureError: Error? = {
            if case let .failure(error) = outcome.outcome.result { return error }
            return nil
        }()
        let failurePresentation = CodexAccountFailurePresentationBuilder.build(
            liveFailureError: isSelfManagedConfiguredAccount ? nil : liveFailureError,
            persistedFailureMessage: isSelfManagedConfiguredAccount ? nil : summary?.lastSyncFailureMessage,
            canRelogin: isSelfManagedConfiguredAccount ? false : canRelogin
        )
        let displayState: AccountHealthState = {
            if isSelfManagedConfiguredAccount {
                return .healthy
            }
            if failurePresentation.hasFailure, failurePresentation.isAuthFailure {
                return .warning
            }
            if failurePresentation.hasPersistedFailure && canRelogin {
                return .warning
            }
            if case .failure = outcome.outcome.result {
                return .failed
            }
            return .healthy
        }()

        let quota: AccountRecordQuota? = {
            switch outcome.outcome.result {
            case let .success(result):
                if isSelfManagedConfiguredAccount, !codexShouldShowUsageSection(usage: result.usage, credits: result.credits) {
                    return nil
                }
                return .init(
                    provider: outcome.provider,
                    accountTitle: title,
                    usage: result.usage,
                    credits: result.credits,
                    creditsRefreshedAt: creditsRefreshedAt,
                    loginAt: summary?.lastLoginAt,
                    syncedAt: result.usage.updatedAt,
                    isLoading: isRefreshing,
                    showsEmptyState: false,
                    errorMessage: nil
                )
            case .failure:
                if isSelfManagedConfiguredAccount {
                    return nil
                }
                return .init(
                    provider: outcome.provider,
                    accountTitle: title,
                    usage: nil,
                    credits: nil,
                    creditsRefreshedAt: nil,
                    loginAt: summary?.lastLoginAt,
                    syncedAt: nil,
                    isLoading: isRefreshing,
                    showsEmptyState: false,
                    errorMessage: failurePresentation.detail
                )
            }
        }()

        let detailFields: [AccountRecordField] = {
            if isSelfManagedConfiguredAccount {
                return []
            }
            guard let failureSummary = failurePresentation.summary else { return [] }
            var fields: [AccountRecordField] = [
                .init(
                    id: "failureSummary",
                    kind: .message,
                    label: nil,
                    value: failureSummary,
                    auxiliary: nil,
                    tone: displayState == .warning ? .warning : .neutral
                ),
            ]
            if let failureDetail = failurePresentation.detail,
               failureDetail != failureSummary
            {
                fields.append(
                    .init(
                        id: "failureDetail",
                        kind: .message,
                        label: nil,
                        value: failureDetail,
                        auxiliary: nil,
                        tone: .neutral
                    )
                )
            }
            return fields
        }()

        return AccountRecord(
            id: .init(provider: .codex, rawValue: outcome.id),
            providerName: "Codex",
            source: .local,
            identity: .init(
                displayName: title,
                subtitle: codexSubtitleText(title: title, email: summary?.email, plan: summary?.plan),
                meta: summary?.lastLoginAt?.formatted(date: .abbreviated, time: .shortened)
            ),
            activationState: codexActivationState(from: presentation.selectionStyle),
            healthState: displayState,
            bodyFields: [],
            detailFields: detailFields,
            quota: quota,
            accessibilityLabel: "Codex \(title)"
        )
    }

    static func empty(providerName: String, usageProvider: UsageProvider, providerID: String) -> AccountRecord {
        AccountRecord(
            id: .init(provider: usageProvider, rawValue: "\(providerID).empty"),
            providerName: providerName,
            source: .unknown,
            identity: .init(
                displayName: NSLocalizedString("accounts.summary.none", value: "No account", comment: "No account"),
                subtitle: nil,
                meta: nil
            ),
            activationState: .inactive,
            healthState: .empty,
            bodyFields: [
                .init(
                    id: "empty",
                    kind: .message,
                    label: nil,
                    value: NSLocalizedString("accounts.empty.description", value: "Manage supported provider accounts from one place.", comment: "Accounts subtitle"),
                    auxiliary: nil,
                    tone: nil
                )
            ],
            detailFields: [],
            quota: nil,
            accessibilityLabel: "\(providerName) empty"
        )
    }

    private static func codexActivationState(from style: AccountCardSelectionStyle) -> AccountActivationState {
        switch style {
        case .neutral:
            return .inactive
        case .active:
            return .active
        case .pending:
            return .pending
        case .transitioning:
            return .transitioning
        case .selected:
            return .selected
        }
    }

    static func codexSubtitleText(title: String, email: String?, plan: String?) -> String? {
        AccountDisplayTextSupport.codexSubtitle(title: title, email: email, plan: plan)
    }

    private static func codexShouldShowUsageSection(
        usage: UsageSnapshot,
        credits: CreditsSnapshot?
    ) -> Bool {
        !usage.allWindows.isEmpty || credits != nil
    }
}

enum AccountCardRowStyle: Equatable {
    case metric
    case kv
    case message
    case code
}

struct AccountCardRowViewData: Identifiable, Equatable {
    let id: String
    let style: AccountCardRowStyle
    let title: String?
    let value: String
    let auxiliary: String?
    let tint: AccountSummaryCardBadgeTone?
}

struct AccountCardActionViewData: Identifiable, Equatable {
    enum Prominence: Equatable {
        case primary
        case secondary
    }

    let id: String
    let actionID: AccountCardActionID
    let title: String
    let systemImage: String?
    let role: ButtonRole?
    let prominence: Prominence
    let isEnabled: Bool
}

struct AccountCardMenuActionViewData: Identifiable, Equatable {
    let id: String
    let actionID: AccountCardActionID
    let title: String
    let systemImage: String?
    let role: ButtonRole?
    let isEnabled: Bool
}

struct AccountCardFooterViewData: Equatable {
    let leadingTag: String?
    let trailingText: String?
}

struct AccountCardQuotaViewData: Equatable {
    let provider: UsageProvider
    let accountTitle: String?
    let usage: UsageSnapshot?
    let modelUsages: [AccountModelUsage]?
    let credits: CreditsSnapshot?
    let creditsRefreshedAt: Date?
    let loginAt: Date?
    let syncedAt: Date?
    let isLoading: Bool
    let showsEmptyState: Bool
    let errorMessage: String?
    let onRefreshActionID: AccountCardActionID?

    init(
        provider: UsageProvider,
        accountTitle: String?,
        usage: UsageSnapshot?,
        modelUsages: [AccountModelUsage]? = nil,
        credits: CreditsSnapshot?,
        creditsRefreshedAt: Date?,
        loginAt: Date?,
        syncedAt: Date?,
        isLoading: Bool,
        showsEmptyState: Bool,
        errorMessage: String?,
        onRefreshActionID: AccountCardActionID?
    ) {
        self.provider = provider
        self.accountTitle = accountTitle
        self.usage = usage
        self.modelUsages = modelUsages
        self.credits = credits
        self.creditsRefreshedAt = creditsRefreshedAt
        self.loginAt = loginAt
        self.syncedAt = syncedAt
        self.isLoading = isLoading
        self.showsEmptyState = showsEmptyState
        self.errorMessage = errorMessage
        self.onRefreshActionID = onRefreshActionID
    }
}

enum AccountCardBodyContent: Equatable {
    case quota(AccountCardQuotaViewData)
    case rows([AccountCardRowViewData])
}

struct AccountCardViewData: Identifiable, Equatable {
    let id: String
    let recordID: AccountRecordID
    let presentation: AccountCardPresentation
    let header: AccountSummaryCardHeaderModel
    let body: AccountCardBodyContent
    let detailRows: [AccountCardRowViewData]
    let primaryActions: [AccountCardActionViewData]
    let menuActions: [AccountCardMenuActionViewData]
    let footer: AccountCardFooterViewData?
    let tapBehavior: AccountCardTapBehavior
    let accessibilityLabel: String
}

@MainActor
enum AccountCardViewDataMapper {
    static func map(
        record: AccountRecord,
        primaryActions: [AccountCardActionViewData] = [],
        menuActions: [AccountCardMenuActionViewData] = [],
        footer: AccountCardFooterViewData? = nil,
        quotaRefreshActionID: AccountCardActionID? = nil,
        tapBehavior: AccountCardTapBehavior = .openProvider
    ) -> AccountCardViewData {
        AccountCardViewData(
            id: record.id.rawValue,
            recordID: record.id,
            presentation: presentation(for: record.activationState),
            header: .init(
                eyebrow: record.providerName,
                title: record.identity.displayName,
                subtitle: record.identity.subtitle,
                meta: record.identity.meta,
                badge: badge(for: record)
            ),
            body: body(for: record, quotaRefreshActionID: quotaRefreshActionID),
            detailRows: record.detailFields.map(row),
            primaryActions: deduplicatedPrimaryActions(primaryActions, tapBehavior: tapBehavior),
            menuActions: menuActions,
            footer: footer,
            tapBehavior: tapBehavior,
            accessibilityLabel: record.accessibilityLabel
        )
    }

    private static func deduplicatedPrimaryActions(
        _ primaryActions: [AccountCardActionViewData],
        tapBehavior: AccountCardTapBehavior
    ) -> [AccountCardActionViewData] {
        guard tapBehavior == .activate else { return primaryActions }
        return primaryActions.filter { $0.actionID != .activate }
    }

    private static func body(for record: AccountRecord, quotaRefreshActionID: AccountCardActionID?) -> AccountCardBodyContent {
        if let quota = record.quota {
            return .quota(
                .init(
                    provider: quota.provider,
                    accountTitle: quota.accountTitle,
                    usage: quota.usage,
                    modelUsages: quota.modelUsages,
                    credits: quota.credits,
                    creditsRefreshedAt: quota.creditsRefreshedAt,
                    loginAt: quota.loginAt,
                    syncedAt: quota.syncedAt,
                    isLoading: quota.isLoading,
                    showsEmptyState: quota.showsEmptyState,
                    errorMessage: quota.errorMessage,
                    onRefreshActionID: quotaRefreshActionID
                )
            )
        }
        return .rows(record.bodyFields.map(row))
    }

    private static func row(_ field: AccountRecordField) -> AccountCardRowViewData {
        AccountCardRowViewData(
            id: field.id,
            style: rowStyle(for: field.kind),
            title: field.label,
            value: field.value,
            auxiliary: field.auxiliary,
            tint: field.tone
        )
    }

    private static func rowStyle(for kind: AccountRecordFieldKind) -> AccountCardRowStyle {
        switch kind {
        case .kv:
            return .kv
        case .message:
            return .message
        case .code:
            return .code
        }
    }

    private static func presentation(for activationState: AccountActivationState) -> AccountCardPresentation {
        switch activationState {
        case .inactive:
            return .neutral
        case .active:
            return .active
        case .pending:
            return .pending
        case .transitioning:
            return .transitioning
        case .selected:
            return .selected
        }
    }

    private static func badge(for record: AccountRecord) -> AccountSummaryCardBadgeModel? {
        switch record.healthState {
        case .warning:
            return .init(
                text: NSLocalizedString("codex.accounts.status.reauth_needed", value: "Needs re-login", comment: "Account status reauth"),
                tone: .warning
            )
        default:
            break
        }

        if record.activationState == .active {
            return .init(
                text: NSLocalizedString("accounts.summary.active", value: "已激活", comment: "Active badge"),
                tone: .active
            )
        }

        return nil
    }
}
