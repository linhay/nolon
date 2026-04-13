import SwiftUI
import ProviderUsage
import CodexProvider
import NolonUIFoundation

extension ProviderUsageEngine {
    enum CodexAccountDisplayState: String, Sendable {
        case pending
        case healthy
        case failed
        case needsReauth
    }

    enum CodexAccountGroupingOption: String, CaseIterable, Identifiable {
        case none
        case typeInfo
        case customSQLiteGroup

        var id: String { rawValue }
    }

    enum CodexAccountSortOption: Hashable, Identifiable {
        case remainingCredits
        case expiryTime
        case name
        case quotaWindowRemaining(windowMinutes: Int)

        var id: String {
            switch self {
            case .remainingCredits:
                return "remainingCredits"
            case .expiryTime:
                return "expiryTime"
            case .name:
                return "name"
            case let .quotaWindowRemaining(windowMinutes):
                return "quotaWindowRemaining-\(windowMinutes)"
            }
        }
    }

    enum CodexSortDirection: String, CaseIterable, Identifiable {
        case descending
        case ascending

        var id: String { rawValue }
    }

    enum UsageAccountLayoutMode: String, CaseIterable, Identifiable {
        case cards
        case list

        var id: String { rawValue }
    }

    enum CodexPrimaryHeaderAction: String, CaseIterable, Identifiable {
        case refreshAll
        case login
        case importAuth
        case editConfig
        case validateConfig

        var id: String { rawValue }
    }

    struct CodexAccountDisplaySection: Identifiable {
        let id: String
        let title: String?
        let items: [ProviderAccountUsageOutcome]
    }

    enum CodexConfigEditorMode: Equatable {
        case newAPIKey
        case edit(accountID: UUID)
    }

    struct CodexConfigEditorDraft: Equatable {
        var mode: CodexConfigEditorMode
        var name: String
        var apiKey: String
        var baseURL: String
        var modelProvider: String
        var queryParamsText: String
        var headersText: String
        var httpUsageEnabled: Bool
        var httpUsageMethod: CodexHTTPMethod
        var httpUsageURL: String
        var httpUsageHeadersText: String
        var httpUsageBody: String
        var httpUsageTimeoutSeconds: String
        var httpUsageOverrideBaseURL: String
        var httpUsageOverrideAPIKey: String
        var httpUsageOverrideAccessToken: String
        var httpUsageOverrideUserID: String
        var httpUsagePlanPath: String
        var httpUsageCreditsRemainingPath: String
        var httpUsageUsedPath: String
        var httpUsageTotalPath: String
        var httpUsageCostTodayPath: String
        var httpUsageCostLast30DaysPath: String
        var httpUsageErrorMessagePath: String

        var isRelay: Bool {
            switch mode {
            case .newAPIKey, .edit:
                return !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
    }

    struct CodexImportCandidate: Identifiable, Equatable {
        let id: UUID
        let sourceFileURL: URL
        let validation: CodexAuthManager.CodexImportValidationResult
        var isSelected: Bool
        var testStatus: CodexImportConnectionTestStatus
        var testSummary: String?
        var testDetail: String?

        init(
            id: UUID = UUID(),
            sourceFileURL: URL,
            validation: CodexAuthManager.CodexImportValidationResult,
            isSelected: Bool,
            testStatus: CodexImportConnectionTestStatus,
            testSummary: String?,
            testDetail: String?
        ) {
            self.id = id
            self.sourceFileURL = sourceFileURL
            self.validation = validation
            self.isSelected = isSelected
            self.testStatus = testStatus
            self.testSummary = testSummary
            self.testDetail = testDetail
        }
    }

    enum CodexImportConnectionTestStatus: Equatable {
        case idle
        case testing
        case success
        case failure
    }

    struct CodexImportCandidateSection: Identifiable, Equatable {
        let id: String
        let title: String
        let items: [CodexImportCandidate]

        var selectableItemCount: Int {
            items.filter(\.validation.isValid).count
        }

        var selectedItemCount: Int {
            items.filter { $0.validation.isValid && $0.isSelected }.count
        }
    }

    enum CodexImportDestinationOption: String, CaseIterable, Identifiable {
        case managedSnapshots
        case customSQLiteGroup

        var id: String { rawValue }
    }

    enum CodexAddSource: String, CaseIterable, Identifiable {
        case current
        case file
        case cliLogin

        var id: String { rawValue }

        var title: String {
            switch self {
            case .current:
                return NSLocalizedString("codex.accounts.add.source.current", value: "Current auth.json", comment: "Current auth.json")
            case .file:
                return NSLocalizedString("codex.accounts.add.source.file", value: "Import auth.json file", comment: "Import auth.json file")
            case .cliLogin:
                return NSLocalizedString("codex.accounts.add.source.cli", value: "CLI Login", comment: "CLI login")
            }
        }
    }

    var codexAccountDisplaySections: [CodexAccountDisplaySection] {
        Self.makeCodexAccountDisplaySections(
            accounts: uniqueCodexAccountsInDisplayOrder(),
            outcomes: codexAccountOutcomes,
            summaries: codexAccountSummaries,
            customGroupNames: codexAccountCustomGroupNames,
            grouping: codexAccountGroupingOption,
            sorting: codexAccountSortOption,
            sortDirection: codexCurrentSortDirection,
            hideZeroQuotaAccounts: codexHideZeroQuotaAccounts,
            hideErroredAccounts: codexHideErroredAccounts
        )
    }

    var codexAccountSectionTotalCountByID: [String: Int] {
        let allSections = Self.makeCodexAccountDisplaySections(
            accounts: uniqueCodexAccountsInDisplayOrder(),
            outcomes: codexAccountOutcomes,
            summaries: codexAccountSummaries,
            customGroupNames: codexAccountCustomGroupNames,
            grouping: codexAccountGroupingOption,
            sorting: codexAccountSortOption,
            sortDirection: codexCurrentSortDirection,
            hideZeroQuotaAccounts: false,
            hideErroredAccounts: false
        )
        return Dictionary(uniqueKeysWithValues: allSections.map { ($0.id, $0.items.count) })
    }

    var hasActiveCodexAccountFilters: Bool {
        codexHideZeroQuotaAccounts || codexHideErroredAccounts
    }

    var codexSortMenuOptions: [CodexAccountSortOption] {
        Self.codexSortMenuOptions(from: codexAccountOutcomes)
    }

    var activeCodexCardKind: CodexAuthSummary.CardKind? {
        codexCardKind(accountID: activeCodexAccountId)
    }

    var codexPrimaryHeaderActions: [CodexPrimaryHeaderAction] {
        Self.codexPrimaryHeaderActions(for: activeCodexCardKind)
    }

    var codexSelectedAccountCount: Int {
        guard isCodexMultiSelectionEnabled else { return 0 }
        return selectedCodexAccountIDs.count
    }

    var canExportSelectedCodexAccounts: Bool {
        isCodexMultiSelectionEnabled && !selectedCodexAccountIDs.isEmpty
    }

    var codexSelectedImportCandidateCount: Int {
        codexImportCandidates.filter { $0.validation.isValid && $0.isSelected }.count
    }

    var canImportSelectedCodexCandidates: Bool {
        guard codexSelectedImportCandidateCount > 0 else { return false }
        if codexImportDestinationOption == .customSQLiteGroup {
            return Self.isNotBlank(codexImportCustomGroupName)
        }
        return true
    }

    var canExportSelectedCodexImportCandidates: Bool {
        codexSelectedImportCandidateCount > 0
    }

    var hasCodexImportCandidates: Bool {
        !codexImportCandidates.isEmpty
    }

    var codexImportSearchResultCount: Int {
        filteredCodexImportCandidates.count
    }

    var codexImportCandidateSections: [CodexImportCandidateSection] {
        let grouped = Dictionary(grouping: filteredCodexImportCandidates, by: { $0.validation.sourceGroupID })
        return grouped.keys.sorted { lhs, rhs in
            let leftTitle = grouped[lhs]?.first?.validation.sourceGroupLabel ?? lhs
            let rightTitle = grouped[rhs]?.first?.validation.sourceGroupLabel ?? rhs
            return leftTitle.localizedCaseInsensitiveCompare(rightTitle) == .orderedAscending
        }.map { key in
            let items = (grouped[key] ?? []).sorted {
                $0.sourceFileURL.lastPathComponent.localizedCaseInsensitiveCompare($1.sourceFileURL.lastPathComponent) == .orderedAscending
            }
            return CodexImportCandidateSection(
                id: key,
                title: items.first?.validation.sourceGroupLabel ?? key,
                items: items
            )
        }
    }
}
