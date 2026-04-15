import Foundation
import ProviderUsage
import CodexBarProviderCatalog
import STJSON

@MainActor
extension ProviderUsageEngine {
    static func displayedGenericUsageOutcomes(
        usageProvider: UsageProvider?,
        hasGeminiAccounts: Bool,
        outcomes: [ProviderAccountUsageOutcome]
    ) -> [ProviderAccountUsageOutcome] {
        if (usageProvider == .gemini || usageProvider == .antigravity), hasGeminiAccounts {
            return []
        }
        if usageProvider == .copilot,
           outcomes.contains(where: { outcome in
               if case .tokenAccount = outcome.account {
                   return true
               }
               return false
           }) {
            return outcomes.filter { outcome in
                guard case .default = outcome.account,
                      case let .failure(error) = outcome.outcome.result,
                      let usageError = error as? ProviderUsageError,
                      usageError == .missingToken(.copilot) else {
                    return true
                }
                return false
            }
        }
        return outcomes
    }

    static func displayedClaudeUsageOutcomes(
        hasClaudeAccounts: Bool,
        outcomes: [ProviderAccountUsageOutcome]
    ) -> [ProviderAccountUsageOutcome] {
        outcomes.filter { outcome in
            guard
                !hasClaudeAccounts,
                case let .failure(error) = outcome.outcome.result,
                let usageError = error as? ProviderUsageError,
                usageError == .missingAccount(.claude)
            else {
                return true
            }
            return false
        }
    }

    static func shouldForceRefreshOnAppearForFailedOutcomes(
        _ outcomes: [ProviderAccountUsageOutcome]
    ) -> Bool {
        outcomes.contains { outcome in
            if case .failure = outcome.outcome.result {
                return true
            }
            return false
        }
    }

    static func makeCodexAccountDisplaySections(
        accounts: [CodexAuthAccount],
        outcomes: [ProviderAccountUsageOutcome],
        summaries: [UUID: CodexAuthSummary],
        customGroupNames: [UUID: String] = [:],
        grouping: CodexAccountGroupingOption,
        sorting: CodexAccountSortOption,
        sortDirection: CodexSortDirection = .descending,
        hideZeroQuotaAccounts: Bool = false,
        hideErroredAccounts: Bool = false
    ) -> [CodexAccountDisplaySection] {
        let outcomeByID = Dictionary(
            outcomes.compactMap { outcome -> (UUID, ProviderAccountUsageOutcome)? in
                guard case let .tokenAccount(account) = outcome.account else { return nil }
                return (account.id, outcome)
            },
            uniquingKeysWith: { current, _ in current }
        )

        let items = accounts.compactMap { account -> (CodexAuthAccount, ProviderAccountUsageOutcome, CodexAuthSummary?)? in
            guard let outcome = outcomeByID[account.id] else { return nil }
            if hideZeroQuotaAccounts, shouldHideCodexAccountForZeroQuota(outcome: outcome) {
                return nil
            }
            if hideErroredAccounts, shouldHideCodexAccountForError(outcome: outcome, summary: summaries[account.id]) {
                return nil
            }
            return (account, outcome, summaries[account.id])
        }
        .sorted { lhs, rhs in
            compareCodexDisplayItems(
                lhs,
                rhs,
                sorting: sorting,
                sortDirection: sortDirection
            )
        }

        switch grouping {
        case .none:
            return [.init(id: "all", title: nil, items: items.map(\.1))]
        case .typeInfo:
            let grouped = Dictionary(grouping: items) { item in
                codexGroupingKey(account: item.0, summary: item.2, customGroupName: customGroupNames[item.0.id])
            }
            return grouped.keys.sorted().map { key in
                let items = grouped[key, default: []]
                let title = items.first.map {
                    codexGroupingTitle(account: $0.0, summary: $0.2, customGroupName: customGroupNames[$0.0.id])
                } ?? key
                return .init(id: key, title: title, items: items.map(\.1))
            }
        case .customSQLiteGroup:
            let hasExplicitCustomGroup = items.contains { item in
                let name = customGroupNames[item.0.id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return !name.isEmpty
            }
            guard hasExplicitCustomGroup else {
                // If no account has custom group metadata, fall back to plan/provider grouping
                // to avoid collapsing everything into a single "未分组" section.
                return makeCodexAccountDisplaySections(
                    accounts: accounts,
                    outcomes: outcomes,
                    summaries: summaries,
                    customGroupNames: customGroupNames,
                    grouping: .typeInfo,
                    sorting: sorting,
                    sortDirection: sortDirection,
                    hideZeroQuotaAccounts: hideZeroQuotaAccounts,
                    hideErroredAccounts: hideErroredAccounts
                )
            }
            let grouped = Dictionary(grouping: items) { item in
                codexCustomSQLiteGroupingKey(accountID: item.0.id, customGroupNames: customGroupNames)
            }
            return grouped.keys.sorted().map { key in
                let sectionItems = grouped[key, default: []]
                let title = sectionItems.first.map {
                    codexCustomSQLiteGroupingTitle(accountID: $0.0.id, customGroupNames: customGroupNames)
                } ?? key
                return .init(id: key, title: title, items: sectionItems.map(\.1))
            }
        }
    }

    static func codexSortMenuOptions(from outcomes: [ProviderAccountUsageOutcome]) -> [CodexAccountSortOption] {
        let windows = availableQuotaWindowSortOptions(from: outcomes)
        return [.remainingCredits, .expiryTime, .name] + windows
    }

    static func codexSortMenuItemTitle(
        for option: CodexAccountSortOption,
        direction: CodexSortDirection?
    ) -> String {
        let base: String
        switch option {
        case .remainingCredits:
            base = NSLocalizedString("codex.accounts.sorting.remaining_credits", value: "按剩余额度", comment: "Sort by remaining credits")
        case .expiryTime:
            base = NSLocalizedString("codex.accounts.sorting.expiry_time", value: "按到期时间", comment: "Sort by expiry time")
        case .name:
            base = NSLocalizedString("codex.accounts.sorting.name", value: "按名称", comment: "Sort by name")
        case let .quotaWindowRemaining(windowMinutes):
            let period = codexWindowSortPeriodText(windowMinutes: windowMinutes)
            base = String(
                format: NSLocalizedString("codex.accounts.sorting.window_remaining", value: "按 %@ 剩余比例", comment: "Sort by remaining percent in a quota window"),
                period
            )
        }

        guard let direction else {
            return base
        }

        let indicator = switch direction {
        case .ascending: "↑"
        case .descending: "↓"
        }
        return "\(base) \(indicator)"
    }

    static func defaultCodexSortDirection(for option: CodexAccountSortOption) -> CodexSortDirection {
        switch option {
        case .remainingCredits, .quotaWindowRemaining:
            return .descending
        case .expiryTime, .name:
            return .ascending
        }
    }

    static func codexPrimaryHeaderActions(
        for activeCardKind: CodexAuthSummary.CardKind?
    ) -> [CodexPrimaryHeaderAction] {
        switch activeCardKind {
        case .officialAPIKey, .relayProfile:
            return [.refreshAll, .login, .importAuth, .editConfig, .validateConfig]
        case .chatgptAccount, .none:
            return [.refreshAll, .login, .importAuth]
        }
    }

    static func codexConfigEditorTitle(
        for mode: CodexConfigEditorMode
    ) -> String {
        switch mode {
        case .newAPIKey:
            return NSLocalizedString("codex.accounts.config.new_api_key", value: "New API Key", comment: "New API key title")
        case .edit:
            return NSLocalizedString("codex.accounts.config.edit", value: "Edit Config", comment: "Edit config title")
        }
    }

    static func codexConfigEditorSubtitle(
        for mode: CodexConfigEditorMode
    ) -> String {
        switch mode {
        case .newAPIKey:
            return NSLocalizedString(
                "codex.accounts.config.subtitle.api_key",
                value: "填写 model_provider、API Key、Base URL。model_provider 默认 nolon，API Key 必填，Base URL 选填。",
                comment: "API key config subtitle"
            )
        case .edit:
            return NSLocalizedString(
                "codex.accounts.config.subtitle.edit",
                value: "填写 model_provider、API Key、Base URL。model_provider 默认 nolon，API Key 必填，Base URL 选填。",
                comment: "Edit config subtitle"
            )
        }
    }

    static func codexConfigEditorPrimaryActionTitle(
        for mode: CodexConfigEditorMode
    ) -> String {
        switch mode {
        case .newAPIKey:
            return NSLocalizedString("generic.create", value: "Create", comment: "Create")
        case .edit:
            return NSLocalizedString("generic.save", value: "Save", comment: "Save")
        }
    }

    static func parseKeyValueLines(_ text: String) throws -> [String: String] {
        var result: [String: String] = [:]
        let lines = text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { String($0) }

        for rawLine in lines {
            let line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else {
                throw NSError(
                    domain: "ProviderUsageEngine.CodexConfig",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "Invalid key=value line: \(line)"]
                )
            }
            let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                throw NSError(
                    domain: "ProviderUsageEngine.CodexConfig",
                    code: 2,
                    userInfo: [NSLocalizedDescriptionKey: "Key cannot be empty."]
                )
            }
            result[key] = value
        }
        return result
    }

    static func serializeKeyValueLines(_ values: [String: String]) -> String {
        values.keys.sorted().compactMap { key in
            guard let value = values[key] else { return nil }
            return "\(key)=\(value)"
        }
        .joined(separator: "\n")
    }

    static func formatTimeoutSeconds(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.1f", value)
    }

    static func stringDictionary(from json: JSON?) -> [String: String] {
        guard let dictionary = json?.dictionaryObject else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in dictionary {
            result[key] = String(describing: value)
        }
        return result
    }

    private static func shouldHideCodexAccountForZeroQuota(
        outcome: ProviderAccountUsageOutcome
    ) -> Bool {
        guard let longestWindow = longestQuotaWindow(from: outcome) else { return false }
        return longestWindow.remainingPercent <= 0
    }

    private static func shouldHideCodexAccountForError(
        outcome: ProviderAccountUsageOutcome,
        summary: CodexAuthSummary?
    ) -> Bool {
        if summary?.cardKind?.isSelfManagedConfiguredAccount == true {
            return false
        }
        if case .failure = outcome.outcome.result {
            return true
        }
        let persistedFailureText = summary?.lastSyncFailureMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let persistedFailureText, !persistedFailureText.isEmpty {
            return true
        }
        if summary?.lastSyncFailedAt != nil {
            return true
        }
        return false
    }

    private static func compareCodexDisplayItems(
        _ lhs: (CodexAuthAccount, ProviderAccountUsageOutcome, CodexAuthSummary?),
        _ rhs: (CodexAuthAccount, ProviderAccountUsageOutcome, CodexAuthSummary?),
        sorting: CodexAccountSortOption,
        sortDirection: CodexSortDirection = .descending
    ) -> Bool {
        switch sorting {
        case .remainingCredits:
            let lhsAmount = creditsRemaining(from: lhs.1)
            let rhsAmount = creditsRemaining(from: rhs.1)
            switch (lhsAmount, rhsAmount) {
            case let (lhs?, rhs?) where lhs != rhs:
                switch sortDirection {
                case .descending:
                    return lhs > rhs
                case .ascending:
                    return lhs < rhs
                }
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                break
            }
        case .expiryTime:
            let lhsExpiry = expirySortDate(from: lhs.1)
            let rhsExpiry = expirySortDate(from: rhs.1)
            switch (lhsExpiry, rhsExpiry) {
            case let (lhs?, rhs?) where lhs != rhs:
                switch sortDirection {
                case .descending:
                    return lhs > rhs
                case .ascending:
                    return lhs < rhs
                }
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                break
            }
        case let .quotaWindowRemaining(windowMinutes):
            let lhsAmount = quotaWindowRemainingPercent(from: lhs.1, windowMinutes: windowMinutes)
            let rhsAmount = quotaWindowRemainingPercent(from: rhs.1, windowMinutes: windowMinutes)
            switch (lhsAmount, rhsAmount) {
            case let (lhs?, rhs?) where lhs != rhs:
                switch sortDirection {
                case .descending:
                    return lhs > rhs
                case .ascending:
                    return lhs < rhs
                }
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                break
            }
        case .name:
            let lhsName = codexDisplayName(account: lhs.0, outcome: lhs.1, summary: lhs.2)
            let rhsName = codexDisplayName(account: rhs.0, outcome: rhs.1, summary: rhs.2)
            let compare = lhsName.localizedCaseInsensitiveCompare(rhsName)
            if compare != .orderedSame {
                switch sortDirection {
                case .descending:
                    return compare == .orderedDescending
                case .ascending:
                    return compare == .orderedAscending
                }
            }
            return lhs.0.id.uuidString < rhs.0.id.uuidString
        }

        let lhsName = codexDisplayName(account: lhs.0, outcome: lhs.1, summary: lhs.2)
        let rhsName = codexDisplayName(account: rhs.0, outcome: rhs.1, summary: rhs.2)
        let compare = lhsName.localizedCaseInsensitiveCompare(rhsName)
        if compare != .orderedSame {
            return compare == .orderedAscending
        }
        return lhs.0.id.uuidString < rhs.0.id.uuidString
    }

    private static func codexDisplayName(
        account: CodexAuthAccount,
        outcome: ProviderAccountUsageOutcome,
        summary: CodexAuthSummary?
    ) -> String {
        let outcomeName = outcome.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !outcomeName.isEmpty {
            return outcomeName
        }
        let email = summary?.email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !email.isEmpty {
            return email
        }
        let accountName = account.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !accountName.isEmpty {
            return accountName
        }
        return account.id.uuidString
    }

    static func codexGroupingKey(account: CodexAuthAccount, summary: CodexAuthSummary?, customGroupName: String? = nil) -> String {
        codexGroupingTitle(account: account, summary: summary, customGroupName: customGroupName)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    static func codexGroupingTitle(account: CodexAuthAccount, summary: CodexAuthSummary?, customGroupName: String? = nil) -> String {
        if let customGroupName = customGroupName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !customGroupName.isEmpty
        {
            return customGroupName
        }
        switch summary?.cardKind {
        case .officialAPIKey:
            return "OpenAI"
        case .relayProfile:
            let provider = summary?.relayModelProvider?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !provider.isEmpty {
                return normalizedRelayProviderTitle(provider)
            }
            let baseURL = summary?.relayBaseURL?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if let host = URL(string: baseURL)?.host, !host.isEmpty {
                return host
            }
            return NSLocalizedString("codex.accounts.group.unknown", value: "Unknown", comment: "Unknown codex account group")
        case .chatgptAccount, .none:
            let plan = summary?.plan?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !plan.isEmpty {
                return plan
            }
            if let explicitKind = summary?.cardKind, explicitKind == .officialAPIKey {
                return "OpenAI"
            }
            return NSLocalizedString("codex.accounts.group.unknown", value: "Unknown", comment: "Unknown codex account group")
        }
    }

    static func codexCustomSQLiteGroupingTitle(accountID: UUID, customGroupNames: [UUID: String]) -> String {
        let name = customGroupNames[accountID]?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let name, !name.isEmpty {
            return name
        }
        return NSLocalizedString("codex.accounts.grouping.custom.default", value: "未分组", comment: "Default custom sqlite group title")
    }

    static func codexCustomSQLiteGroupingKey(accountID: UUID, customGroupNames: [UUID: String]) -> String {
        codexCustomSQLiteGroupingTitle(accountID: accountID, customGroupNames: customGroupNames)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func creditsRemaining(from outcome: ProviderAccountUsageOutcome) -> Double? {
        guard case let .success(result) = outcome.outcome.result else { return nil }
        return result.credits?.remaining
    }

    private static func quotaWindowRemainingPercent(
        from outcome: ProviderAccountUsageOutcome,
        windowMinutes: Int
    ) -> Double? {
        guard case let .success(result) = outcome.outcome.result else { return nil }
        let windows = result.usage.allWindows.map(\.window)
        return windows
            .first(where: { $0.windowMinutes == windowMinutes })?
            .remainingPercent
    }

    private static func longestQuotaWindow(
        from outcome: ProviderAccountUsageOutcome
    ) -> RateWindow? {
        guard case let .success(result) = outcome.outcome.result else { return nil }
        return result.usage.allWindows
            .map(\.window)
            .filter { ($0.windowMinutes ?? 0) > 0 }
            .max { lhs, rhs in
                (lhs.windowMinutes ?? 0) < (rhs.windowMinutes ?? 0)
            }
    }

    private static func expirySortDate(from outcome: ProviderAccountUsageOutcome) -> Date? {
        guard case let .success(result) = outcome.outcome.result else { return nil }
        let windows = result.usage.allWindows.map(\.window)
        return windows.compactMap(\.resetsAt).min()
    }

    private static func availableQuotaWindowSortOptions(
        from outcomes: [ProviderAccountUsageOutcome]
    ) -> [CodexAccountSortOption] {
        let values = outcomes.compactMap { outcome -> [Int]? in
            guard case let .success(result) = outcome.outcome.result else { return nil }
            return result.usage.allWindows
                .map(\.window.windowMinutes)
                .compactMap { $0 }
                .filter { $0 > 0 }
        }

        return Array(Set(values.flatMap { $0 })).sorted().map { .quotaWindowRemaining(windowMinutes: $0) }
    }

    static func normalizedRelayProviderTitle(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return trimmed }
        let lowercased = trimmed.lowercased()
        if trimmed == lowercased || trimmed == trimmed.uppercased() {
            return lowercased.localizedCapitalized
        }
        return trimmed
    }

    private static func codexWindowSortPeriodText(windowMinutes: Int) -> String {
        let weekMinutes = 7 * 24 * 60
        let dayMinutes = 24 * 60
        if windowMinutes % weekMinutes == 0 {
            return "\(windowMinutes / weekMinutes)w"
        }
        if windowMinutes % dayMinutes == 0 {
            return "\(windowMinutes / dayMinutes)d"
        }
        if windowMinutes % 60 == 0 {
            return "\(windowMinutes / 60)h"
        }
        return "\(windowMinutes)m"
    }
}
