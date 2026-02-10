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
        VStack(alignment: .leading, spacing: 12) {
            let metadata = ProviderUsageRegistry.metadata(for: outcome.provider)
            if let primary = result.usage.primary {
                usageRow(
                    title: metadata?.sessionLabel ?? NSLocalizedString("usage.metric.session", value: "Session", comment: "Session"),
                    window: primary)
            }
            if let secondary = result.usage.secondary {
                usageRow(
                    title: metadata?.weeklyLabel ?? NSLocalizedString("usage.metric.weekly", value: "Weekly", comment: "Weekly"),
                    window: secondary)
            }
            if let tertiary = result.usage.tertiary {
                usageRow(
                    title: metadata?.opusLabel ?? NSLocalizedString("usage.metric.third", value: "Other", comment: "Other"),
                    window: tertiary)
            }

            if let credits = result.credits, !credits.remaining.isNaN {
                Divider()
                creditsRow(credits, refreshedAt: creditsRefreshedAt)
            }

            if let cost = result.cost, cost.todayCostUSD != nil || cost.last30DaysCostUSD != nil {
                Divider()
                costRow(cost)
            }

            footer(result: result)
        }
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
        VStack(alignment: .leading, spacing: 8) {
            Text(NSLocalizedString("usage.monitor.error.title", value: "Failed to load usage", comment: "Error title"))
                .dsErrorText(font: .subheadline)
            Text(error.localizedDescription)
                .font(.body)
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .textSelection(.enabled)
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

    private func costRow(_ cost: CostSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(NSLocalizedString("usage.metric.cost", value: "Cost", comment: "Cost label"))
                .font(.subheadline)
                .dsSecondaryText(font: .subheadline)

            if let line = costLineToday(cost), !line.isEmpty {
                Text(line)
                    .font(.caption)
                    .dsTertiaryText(font: .caption)
            }
            if let line = costLineLast30(cost), !line.isEmpty {
                Text(line)
                    .font(.caption)
                    .dsTertiaryText(font: .caption)
            }

            usageTokensTable(cost)
        }
    }

    private func costLineToday(_ cost: CostSnapshot) -> String? {
        guard let dollars = cost.todayCostUSD else { return nil }
        let tokens = cost.todayTokens
        let tokenText = tokens.map { " • \(tokenCountText($0))" } ?? ""
        return String(
            format: NSLocalizedString(
                "usage.metric.cost.today_format",
                value: "Today: $%.2f%@",
                comment: "Today cost format"
            ),
            dollars,
            tokenText
        )
    }

    private func costLineLast30(_ cost: CostSnapshot) -> String? {
        guard let dollars = cost.last30DaysCostUSD else { return nil }
        let tokens = cost.last30DaysTokens
        let tokenText = tokens.map { " • \(tokenCountText($0))" } ?? ""
        let label = rangeLabel(cost.windowDays)
        return String(
            format: "%@: $%.2f%@",
            label,
            dollars,
            tokenText
        )
    }

    @ViewBuilder
    private func usageTokensTable(_ cost: CostSnapshot) -> some View {
        let today = UsageBreakdown(
            title: NSLocalizedString("codex.usage.range.today", value: "Today", comment: "Usage range"),
            total: cost.todayTokens,
            input: nil,
            output: nil,
            cached: nil
        )
        let range = UsageBreakdown(
            title: rangeLabel(cost.windowDays),
            total: cost.last30DaysTokens,
            input: nil,
            output: nil,
            cached: nil
        )
        if today.hasData || range.hasData {
            VStack(alignment: .leading, spacing: 4) {
                Text("Tokens")
                    .font(.caption)
                    .dsSecondaryText(font: .caption)

                Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 8, verticalSpacing: 3) {
                    GridRow {
                        Text("")
                        Text("Total")
                    }
                    .font(.caption2)
                    .dsTertiaryText(font: .caption2)

                    GridRow {
                        Text(today.title)
                        Text(today.totalText)
                    }
                    GridRow {
                        Text(range.title)
                        Text(range.totalText)
                    }
                }
                .font(.caption)
                .dsTertiaryText(font: .caption)
            }
        }
    }

    private func rangeLabel(_ rangeDays: Int?) -> String {
        if let rangeDays {
            if rangeDays == 1 {
                return NSLocalizedString("codex.usage.range.today", value: "Today", comment: "Usage range")
            }
            return String(format: NSLocalizedString("Last %d days", value: "Last %d days", comment: "Rolling usage days"), rangeDays)
        }
        return NSLocalizedString("codex.usage.range.all", value: "All time", comment: "Usage range")
    }

    private func tokenCountText(_ value: Int) -> String {
        if value >= 1_000_000 {
            let millions = Double(value) / 1_000_000.0
            return String(format: NSLocalizedString("usage.metric.tokens_m", value: "%.0fM tokens", comment: "Token count in millions"), millions)
        }
        if value >= 1_000 {
            let thousands = Double(value) / 1_000.0
            return String(format: NSLocalizedString("usage.metric.tokens_k", value: "%.0fK tokens", comment: "Token count in thousands"), thousands)
        }
        return String(format: NSLocalizedString("usage.metric.tokens", value: "%d tokens", comment: "Token count"), value)
    }
}

private struct UsageBreakdown {
    let title: String
    let total: Int?
    let input: Int?
    let output: Int?
    let cached: Int?

    var hasData: Bool {
        total != nil || input != nil || output != nil || cached != nil
    }

    var totalText: String { text(total) }
    var inputText: String { text(input) }
    var outputText: String { text(output) }
    var cachedText: String { text(cached) }

    private func text(_ value: Int?) -> String {
        guard let value else { return "-" }
        return "\(value)"
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
