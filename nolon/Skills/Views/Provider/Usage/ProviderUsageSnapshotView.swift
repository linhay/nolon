import SwiftUI
import ProviderUsage
import CodexBarProviderCatalog

struct ProviderUsageSnapshotView: View {
    let outcome: ProviderAccountUsageOutcome
    let creditsRefreshedAt: Date?

    init(outcome: ProviderAccountUsageOutcome, creditsRefreshedAt: Date? = nil) {
        self.outcome = outcome
        self.creditsRefreshedAt = creditsRefreshedAt
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
        let displayWindows = usageWindows(for: result)
        let hasMetrics = !displayWindows.isEmpty || result.credits != nil

        return VStack(alignment: .leading, spacing: 12) {
            ForEach(displayWindows) { item in
                usageRow(
                    title: item.title,
                    window: item.window
                )
            }

            if let credits = result.credits, !credits.remaining.isNaN {
                Divider()
                creditsRow(credits, refreshedAt: creditsRefreshedAt)
            }

            if !hasMetrics {
                Text(
                    NSLocalizedString(
                        "usage.monitor.metrics.unavailable",
                        value: "No usage metrics available for this account yet.",
                        comment: "Empty usage metrics hint"
                    )
                )
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
            }

            footer(result: result)
        }
    }

    private func usageWindows(for result: ProviderFetchResult) -> [UsageWindow] {
        if !result.usage.windows.isEmpty {
            return result.usage.windows
        }

        let metadata = ProviderUsageRegistry.metadata(for: outcome.provider)
        var items: [UsageWindow] = []
        if let primary = result.usage.primary {
            items.append(UsageWindow(
                id: "primary",
                title: metadata?.sessionLabel ?? NSLocalizedString("usage.metric.session", value: "Session", comment: "Session"),
                window: primary
            ))
        }
        if let secondary = result.usage.secondary {
            items.append(UsageWindow(
                id: "secondary",
                title: metadata?.weeklyLabel ?? NSLocalizedString("usage.metric.weekly", value: "Weekly", comment: "Weekly"),
                window: secondary
            ))
        }
        if let tertiary = result.usage.tertiary {
            items.append(UsageWindow(
                id: "tertiary",
                title: metadata?.opusLabel ?? NSLocalizedString("usage.metric.third", value: "Other", comment: "Other"),
                window: tertiary
            ))
        }
        return items
    }

    private func usageRow(title: String, window: RateWindow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .dsSecondaryText(font: .subheadline)
                Spacer()
                Text(String(format: "%.0f%%", window.remainingPercent))
                    .font(.subheadline)
                    .monospacedDigit()
            }

            ProgressView(value: min(100, max(0, window.remainingPercent)), total: 100)
                .tint(DesignSystem.Colors.primary)

            if let detail = resetText(window: window), !detail.isEmpty {
                Text(detail)
                    .font(.caption)
                    .dsTertiaryText(font: .caption)
            }
        }
    }

    private func creditsRow(_ credits: CreditsSnapshot, refreshedAt: Date?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(NSLocalizedString("usage.metric.credits", value: "Credits", comment: "Credits"))
                    .font(.subheadline)
                    .dsSecondaryText(font: .subheadline)
                Spacer()
                Text(creditsText(credits.remaining))
                    .font(.subheadline)
                    .monospacedDigit()
            }
            Text(credits.updatedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .dsTertiaryText(font: .caption)

            if let refreshedAt {
                Text(String(
                    format: NSLocalizedString(
                        "usage.metric.refreshed_at",
                        value: "Refreshed %@",
                        comment: "Credits refreshed time"
                    ),
                    refreshedAt.formatted(date: .abbreviated, time: .shortened)
                ))
                .font(.caption)
                .dsTertiaryText(font: .caption)
            }
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

    private func resetText(window: RateWindow) -> String? {
        if let resetDescription = window.resetDescription, !resetDescription.isEmpty {
            return resetDescription
        }
        if let resetsAt = window.resetsAt {
            if let countdown = resetCountdownText(resetsAt: resetsAt) {
                return String(
                    format: NSLocalizedString(
                        "usage.metric.resets_in",
                        value: "Resets in %@",
                        comment: "Resets countdown label"
                    ),
                    countdown
                )
            }
            if resetsAt <= Date() {
                return NSLocalizedString("usage.metric.resets_now", value: "Resets now", comment: "Resets now label")
            }
            return String(
                format: NSLocalizedString("usage.metric.resets_at", value: "Resets %@", comment: "Resets label"),
                resetsAt.formatted(date: .abbreviated, time: .shortened))
        }
        if let minutes = window.windowMinutes {
            return String(
                format: NSLocalizedString("usage.metric.window_minutes", value: "Window %d min", comment: "Window minutes"),
                minutes)
        }
        return nil
    }

    private func resetCountdownText(resetsAt: Date) -> String? {
        let remaining = max(0, resetsAt.timeIntervalSinceNow)
        if remaining <= 0 { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 2
        formatter.zeroFormattingBehavior = [.dropLeading, .dropTrailing]
        return formatter.string(from: remaining)
    }

    private func creditsText(_ value: Double) -> String {
        if value.isInfinite { return NSLocalizedString("usage.metric.unlimited", value: "Unlimited", comment: "Unlimited") }
        if value.isNaN { return NSLocalizedString("usage.metric.unknown", value: "Unknown", comment: "Unknown") }
        return String(format: "%.0f", value)
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
