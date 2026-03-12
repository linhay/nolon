import SwiftUI
import ProviderUsage
import CodexBarProviderCatalog

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
        VStack(alignment: .leading, spacing: 12) {
            header

            switch outcome.outcome.result {
            case let .success(result):
                usageContent(result: result)
            case let .failure(error):
                errorContent(error)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .dsCard()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(outcome.displayName)
                    .font(.headline)

                Spacer()

                Text(outcome.provider.rawValue.uppercased())
                    .font(.caption)
                    .dsTertiaryText(font: .caption)
            }

            if let identity = identityLine {
                Text(identity)
                    .font(.subheadline)
                    .dsSecondaryText(font: .subheadline)
                    .textSelection(.enabled)
            }

            if case let .success(result) = outcome.outcome.result {
                identityDetails(result: result)
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

    private func identityDetails(result: ProviderFetchResult) -> some View {
        let identity = result.usage.identity?.scoped(to: outcome.provider)

        return VStack(alignment: .leading, spacing: 4) {
            if let email = identity?.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
                keyValueRow(
                    title: NSLocalizedString("usage.metric.account", value: "Account", comment: "Account label"),
                    value: email
                )
            }
            if let plan = identity?.plan?.trimmingCharacters(in: .whitespacesAndNewlines), !plan.isEmpty {
                keyValueRow(
                    title: NSLocalizedString("usage.metric.plan", value: "Plan", comment: "Plan label"),
                    value: plan
                )
            }
        }
        .dsTertiaryText(font: .caption)
        .textSelection(.enabled)
    }

    private func keyValueRow(title: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
            Text("•")
            Text(value)
        }
    }

    private func usageContent(result: ProviderFetchResult) -> some View {
        return VStack(alignment: .leading, spacing: 12) {
            ProviderQuotaSection(
                provider: outcome.provider,
                usage: result.usage,
                credits: result.credits,
                creditsRefreshedAt: creditsRefreshedAt,
                isLoading: isLoading,
                showsEmptyState: true
            )

            footer(result: result)
        }
    }

    private func footer(result: ProviderFetchResult) -> some View {
        HStack(spacing: 8) {
            Text(result.fetchKind.label)
            Text("•")
            Text(result.strategyKind.label)
            Text("•")
            Text(result.usage.updatedAt.formatted(date: .abbreviated, time: .shortened))
        }
        .font(.caption)
        .dsTertiaryText(font: .caption)
    }

    private func errorContent(_ error: Error) -> some View {
        let code = UsageIssueClassifier.classify(provider: outcome.provider, error: error)
        let hints = UsageIssueClassifier.hints(provider: outcome.provider, code: code)

        return VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("usage.monitor.error.title", value: "Failed to load usage", comment: "Error title"))
                .dsErrorText(font: .subheadline)
            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .textSelection(.enabled)
            if code != .unknown {
                Text("diagnostic: \(code.rawValue)")
                    .font(.caption)
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    .textSelection(.enabled)
            }
            if !hints.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(hints, id: \.self) { hint in
                        Text("• \(hint)")
                            .font(.caption)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                            .textSelection(.enabled)
                    }
                }
            }
        }
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
