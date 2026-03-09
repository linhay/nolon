import SwiftUI
import ProviderUsage
import CodexBarProviderCatalog

struct CreditsMetadataLine: Equatable {
    let prefixKey: String
    let date: Date
}

struct ProviderQuotaSection: View {
    let provider: UsageProvider
    let usage: UsageSnapshot?
    let credits: CreditsSnapshot?
    let creditsRefreshedAt: Date?
    let isLoading: Bool
    let showsEmptyState: Bool

    @State private var shimmerPhase: Double = 0

    init(
        provider: UsageProvider,
        usage: UsageSnapshot?,
        credits: CreditsSnapshot? = nil,
        creditsRefreshedAt: Date? = nil,
        isLoading: Bool = false,
        showsEmptyState: Bool = false
    ) {
        self.provider = provider
        self.usage = usage
        self.credits = credits
        self.creditsRefreshedAt = creditsRefreshedAt
        self.isLoading = isLoading
        self.showsEmptyState = showsEmptyState
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                loadingSkeleton
            } else if let usage = usage {
                content(usage: usage)
            } else if showsEmptyState {
                emptyState
            }
        }
    }

    private func content(usage: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            let windows = usage.allWindows
            if windows.isEmpty && credits == nil {
                emptyMetricsState
            } else {
                ForEach(windows) { item in
                    quotaItem(title: localizedTitle(item), window: item.window)
                }

                if let credits, !credits.remaining.isNaN {
                    creditsFooter(credits)
                }
            }
        }
    }

    // MARK: - Quota Item
    private func quotaItem(title: String, window: RateWindow) -> some View {
        let percent = window.remainingPercent
        let statusColor = statusColor(for: percent)

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                HStack(spacing: 6) {
                    Image(systemName: iconName(for: title))
                        .font(.system(size: 10))
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(DesignSystem.Colors.Text.secondary)

                Spacer()

                Text(percentValue(percent))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(statusColor)
            }
            .padding(.bottom, 6)

            thinProgressBar(percent: percent, color: statusColor)

            HStack {
                if let period = window.windowMinutes {
                    Text(compactWindowPeriodText(period))
                }
                Spacer()
                if let resetsAt = window.resetsAt {
                    Text(preciseResetCountdownText(resetsAt: resetsAt))
                } else if let desc = window.resetDescription {
                    Text(desc)
                }
            }
            .font(.system(size: 9))
            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            .padding(.top, 6)
        }
        .padding(.vertical, 12)
        .divider(at: .top, color: DesignSystem.Colors.Background.elevated.opacity(0.3))
    }

    private func thinProgressBar(percent: Double, color: Color) -> some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignSystem.Colors.Background.elevated.opacity(0.5))
                .frame(height: 4)
            
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: max(2, proxy.size.width * min(1, max(0, percent / 100.0))))
            }
            .frame(height: 4)
        }
        .frame(height: 4)
    }

    private func creditsFooter(_ credits: CreditsSnapshot) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(NSLocalizedString("usage.metric.credits", value: "Credits", comment: "Credits"))
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(DesignSystem.Colors.Text.secondary)

                ForEach(Array(creditsMetadataLines(for: credits).enumerated()), id: \.offset) { _, line in
                    Text(
                        String(
                            format: NSLocalizedString(
                                line.prefixKey,
                                value: line.prefixKey == "usage.metric.updated_at" ? "Snapshot %@": "Refreshed %@",
                                comment: "Credits metadata timestamp"
                            ),
                            line.date.formatted(date: .abbreviated, time: .shortened)
                        )
                    )
                    .font(.system(size: 9))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
            }
            
            Spacer()
            
            Text(creditsValue(credits.remaining))
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.primary)
        }
        .padding(.top, 14)
        .divider(at: .top, color: DesignSystem.Colors.Background.elevated.opacity(0.5))
    }

    private func preciseResetCountdownText(resetsAt: Date) -> String {
        let remaining = resetsAt.timeIntervalSinceNow
        if remaining <= 0 {
            return NSLocalizedString("usage.metric.resets_now", value: "即将重置", comment: "Resets now")
        }
        
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        
        if let countdown = formatter.string(from: remaining) {
            let isChinese = Locale.current.language.languageCode?.identifier.hasPrefix("zh") ?? false
            return isChinese ? "\(countdown)后重置" : "Resets in \(countdown)"
        }
        return ""
    }

    // MARK: - Loading Skeleton
    private var loadingSkeleton: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<2) { _ in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        skeletonRect(width: 80, height: 12)
                        Spacer()
                        skeletonRect(width: 40, height: 14)
                    }
                    skeletonRect(width: .infinity, height: 4)
                    HStack {
                        skeletonRect(width: 60, height: 10)
                        Spacer()
                        skeletonRect(width: 60, height: 10)
                    }
                }
                .padding(.vertical, 12)
                .divider(at: .top, color: DesignSystem.Colors.Background.elevated.opacity(0.2))
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
    }

    private func skeletonRect(width: CGFloat?, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(DesignSystem.Colors.Background.elevated.opacity(0.3))
            .frame(width: width == .infinity ? nil : width, height: height)
            .overlay(
                GeometryReader { proxy in
                    Color.white.opacity(0.05)
                        .mask(
                            Rectangle()
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [.clear, .white.opacity(0.1), .clear]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .offset(x: -proxy.size.width + (proxy.size.width * 2 * shimmerPhase))
                        )
                }
            )
            .clipped()
    }

    // MARK: - Helper Methods
    func localizedTitle(_ item: UsageWindow) -> String {
        let metadata = ProviderUsageRegistry.metadata(for: provider)
        return switch item.id {
        case "primary": metadata?.sessionLabel ?? NSLocalizedString("usage.metric.session", value: "Session", comment: "Session")
        case "secondary": metadata?.weeklyLabel ?? NSLocalizedString("usage.metric.weekly", value: "Weekly", comment: "Weekly")
        case "tertiary": metadata?.opusLabel ?? NSLocalizedString("usage.metric.third", value: "Other", comment: "Other")
        default: item.title
        }
    }

    func statusColor(for percent: Double) -> Color {
        if percent.isInfinite { return DesignSystem.Colors.Status.success }
        if percent < 10 { return DesignSystem.Colors.Status.error }
        if percent < 25 { return DesignSystem.Colors.Status.warning }
        return DesignSystem.Colors.primary
    }

    func planColor(_ plan: String) -> Color {
        let p = plan.lowercased()
        if p.contains("pro") || p.contains("enterprise") { return DesignSystem.Colors.primary }
        if p.contains("free") || p.contains("limited") { return DesignSystem.Colors.Status.error }
        return DesignSystem.Colors.Text.secondary
    }

    func iconName(for title: String) -> String {
        let t = title.lowercased()
        if t.contains("session") || t.contains("min") { return "timer" }
        if t.contains("week") || t.contains("day") { return "calendar" }
        return "chart.bar"
    }

    func displayedCreditsTimestamp(for credits: CreditsSnapshot) -> Date {
        creditsRefreshedAt ?? credits.updatedAt
    }

    func creditsMetadataLines(for credits: CreditsSnapshot) -> [CreditsMetadataLine] {
        var lines: [CreditsMetadataLine] = [
            CreditsMetadataLine(
                prefixKey: "usage.metric.refreshed_at",
                date: displayedCreditsTimestamp(for: credits)
            )
        ]
        if let creditsRefreshedAt, creditsRefreshedAt != credits.updatedAt {
            lines.append(
                CreditsMetadataLine(
                    prefixKey: "usage.metric.updated_at",
                    date: credits.updatedAt
                )
            )
        }
        return lines
    }

    private func percentValue(_ percent: Double) -> String {
        if percent.isInfinite { return "∞" }
        return String(format: "%.0f%%", percent)
    }

    private func creditsValue(_ value: Double) -> String {
        if value.isInfinite { return "∞" }
        return String(format: "%.0f", value)
    }

    private func compactWindowPeriodText(_ minutes: Int) -> String {
        let isChinese = Locale.current.language.languageCode?.identifier.hasPrefix("zh") ?? false
        if minutes >= 60 * 24 * 7 { return isChinese ? "\(minutes / (60 * 24 * 7))周" : "\(minutes / (60 * 24 * 7))w" }
        if minutes >= 60 * 24 { return isChinese ? "\(minutes / (60 * 24))天" : "\(minutes / (60 * 24))d" }
        if minutes >= 60 { return isChinese ? "\(minutes / 60)小时" : "\(minutes / (60 * 24))h" }
        return isChinese ? "\(minutes)分钟" : "\(minutes)m"
    }

    private var emptyState: some View {
        Text(NSLocalizedString("usage.monitor.metrics.unavailable", value: "No usage metrics available yet.", comment: "Empty usage metrics hint"))
            .font(.caption)
            .foregroundStyle(DesignSystem.Colors.Text.secondary)
            .padding(.vertical, 12)
    }

    private var emptyMetricsState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.bar")
                .font(.title3)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            Text(NSLocalizedString("usage.monitor.empty.desc", value: "No data available.", comment: "Empty data"))
                .font(.caption)
                .foregroundStyle(DesignSystem.Colors.Text.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    static func displayWindows(for usage: UsageSnapshot, provider: UsageProvider) -> [UsageWindow] {
        if !usage.windows.isEmpty {
            return usage.windows
        }

        let metadata = ProviderUsageRegistry.metadata(for: provider)
        var items: [UsageWindow] = []
        if let primary = usage.primary {
            items.append(UsageWindow(
                id: "primary",
                title: metadata?.sessionLabel ?? NSLocalizedString("usage.metric.session", value: "Session", comment: "Session"),
                window: primary
            ))
        }
        if let secondary = usage.secondary {
            items.append(UsageWindow(
                id: "secondary",
                title: metadata?.weeklyLabel ?? NSLocalizedString("usage.metric.weekly", value: "Weekly", comment: "Weekly"),
                window: secondary
            ))
        }
        if let tertiary = usage.tertiary {
            items.append(UsageWindow(
                id: "tertiary",
                title: metadata?.opusLabel ?? NSLocalizedString("usage.metric.third", value: "Other", comment: "Other"),
                window: tertiary
            ))
        }
        return items
    }
}
