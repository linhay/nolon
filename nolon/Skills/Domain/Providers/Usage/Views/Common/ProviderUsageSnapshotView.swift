import SwiftUI
import ProviderUsage
import CodexBarProviderCatalog
import NolonUI
import NolonUIFoundation

struct ProviderUsageSnapshotView: View {
    let outcome: ProviderAccountUsageOutcome
    let creditsRefreshedAt: Date?
    let isLoading: Bool

    init(outcome: ProviderAccountUsageOutcome, creditsRefreshedAt: Date? = nil, isLoading: Bool = false) {
        self.outcome = outcome
        self.creditsRefreshedAt = creditsRefreshedAt
        self.isLoading = isLoading
    }

    var body: some View {
        NolonUI.UsageSnapshotCardView(data: cardData) {
            if case let .success(result) = outcome.outcome.result {
                ProviderQuotaSection(
                    provider: outcome.provider,
                    usage: result.usage,
                    credits: result.credits,
                    creditsRefreshedAt: creditsRefreshedAt,
                    isLoading: isLoading,
                    showsEmptyState: true
                )
            }
        }
    }

    private var identityLine: String? {
        guard case let .success(result) = outcome.outcome.result else { return nil }
        let identity = result.usage.identity?.scoped(to: outcome.provider)
        let parts: [String] = [
            identity?.accountOrganization?.trimmingCharacters(in: .whitespacesAndNewlines),
            identity?.loginMethod?.trimmingCharacters(in: .whitespacesAndNewlines),
        ].compactMap { value in
            guard let value, !value.isEmpty else { return nil }
            return value
        }
        return parts.isEmpty ? nil : parts.joined(separator: " • ")
    }

    private func identityDetails(result: ProviderFetchResult) -> (account: String?, plan: String?) {
        let identity = result.usage.identity?.scoped(to: outcome.provider)
        let account = identity?.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        let plan = identity?.plan?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            account: (account?.isEmpty == false) ? account : nil,
            plan: (plan?.isEmpty == false) ? plan : nil
        )
    }

    private var cardData: UsageSnapshotCardData {
        let providerLabel = outcome.provider.rawValue.uppercased()
        switch outcome.outcome.result {
        case let .success(result):
            let detail = identityDetails(result: result)
            return .init(
                header: .init(
                    displayName: outcome.displayName,
                    providerLabel: providerLabel,
                    identityLine: identityLine,
                    accountLine: detail.account,
                    planLine: detail.plan
                ),
                body: .success(
                    footerItems: [
                        result.fetchKind.label,
                        result.strategyKind.label,
                        result.usage.updatedAt.formatted(date: .abbreviated, time: .shortened)
                    ]
                )
            )
        case let .failure(error):
            let code = ProviderUsageIssueClassifier.classify(
                providerID: outcome.provider.rawValue,
                errorText: error.localizedDescription,
                usageErrorCode: usageErrorCode(from: error)
            )
            let hints = ProviderUsageIssueClassifier.hints(providerID: outcome.provider.rawValue, code: code)
            return .init(
                header: .init(
                    displayName: outcome.displayName,
                    providerLabel: providerLabel,
                    identityLine: nil,
                    accountLine: nil,
                    planLine: nil
                ),
                body: .error(
                    message: error.localizedDescription,
                    diagnostic: code != .unknown ? code.rawValue : nil,
                    hints: hints
                )
            )
        }
    }
}

private func usageErrorCode(from error: Error) -> String? {
    guard let usageError = error as? ProviderUsageError else {
        return nil
    }

    switch usageError {
    case .unsupported:
        return "unsupported"
    case .missingToken:
        return "missingToken"
    case .missingAccount:
        return "missingAccount"
    case .authExpired:
        return "authExpired"
    }
}

private extension ProviderFetchKind {
    var label: String {
        switch self {
        case .web:
            return NSLocalizedString("usage.source.web", value: "Web", comment: "Web")
        case .cli:
            return NSLocalizedString("usage.source.cli", value: "CLI", comment: "CLI")
        case .oauth:
            return NSLocalizedString("usage.source.oauth", value: "OAuth", comment: "OAuth")
        case .apiToken:
            return NSLocalizedString("usage.source.api_token", value: "API token", comment: "API token")
        case .localProbe:
            return NSLocalizedString("usage.source.local_probe", value: "Local probe", comment: "Local probe")
        case .webDashboard:
            return NSLocalizedString("usage.source.web_dashboard", value: "Web dashboard", comment: "Web dashboard")
        }
    }
}

private extension ProviderFetchStrategyKind {
    var label: String {
        switch self {
        case .direct:
            NSLocalizedString("usage.strategy.direct", value: "Direct", comment: "Direct fetch")
        case .fallback:
            NSLocalizedString("usage.strategy.fallback", value: "Fallback", comment: "Fallback fetch")
        }
    }
}
