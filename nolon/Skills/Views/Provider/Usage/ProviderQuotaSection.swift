import SwiftUI
import ProviderUsage
import CodexBarProviderCatalog

struct ProviderQuotaSection: View {
    struct MetadataLine: Equatable {
        let prefixKey: String
        let date: Date
    }

    let provider: UsageProvider
    let accountTitle: String?
    let usage: UsageSnapshot?
    let credits: CreditsSnapshot?
    let creditsRefreshedAt: Date?
    let loginAt: Date?
    let syncedAt: Date?
    let isLoading: Bool
    let showsEmptyState: Bool
    let errorMessage: String?
    let onRefresh: (() -> Void)?

    @State private var shimmerPhase: Double = 0

    init(
        provider: UsageProvider,
        accountTitle: String? = nil,
        usage: UsageSnapshot?,
        credits: CreditsSnapshot? = nil,
        creditsRefreshedAt: Date? = nil,
        loginAt: Date? = nil,
        syncedAt: Date? = nil,
        isLoading: Bool = false,
        showsEmptyState: Bool = false,
        errorMessage: String? = nil,
        onRefresh: (() -> Void)? = nil
    ) {
        self.provider = provider
        self.accountTitle = accountTitle
        self.usage = usage
        self.credits = credits
        self.creditsRefreshedAt = creditsRefreshedAt
        self.loginAt = loginAt
        self.syncedAt = syncedAt
        self.isLoading = isLoading
        self.showsEmptyState = showsEmptyState
        self.errorMessage = errorMessage
        self.onRefresh = onRefresh
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            
            if isLoading {
                loadingSkeleton
            } else if let errorMessage = errorMessage {
                errorState(message: errorMessage)
            } else if let usage = usage {
                quotaList(usage: usage)
            } else if showsEmptyState {
                emptyState
            }

            footer
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(DesignSystem.Colors.Background.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(DesignSystem.Colors.Background.elevated.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - 1. Header (LED + Account + Refresh)
    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            // LED Indicator
            Circle()
                .fill(statusColor(for: usage?.primary?.remainingPercent ?? 100))
                .frame(width: 6, height: 6)
                .shadow(color: statusColor(for: usage?.primary?.remainingPercent ?? 100).opacity(0.5), radius: 3)
            
            Text(resolvedAccountTitle)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
                .lineLimit(1)

            Spacer()

            if let onRefresh {
                Button(action: onRefresh) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                }
                .buttonStyle(.plain)
                .opacity(isLoading ? 0.3 : 0.6)
                .disabled(isLoading)
            }
        }
        .padding(.horizontal, 4)
        .padding(.bottom, 8)
    }

    var resolvedAccountTitle: String {
        let explicitTitle = accountTitle?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let explicitTitle, !explicitTitle.isEmpty {
            return explicitTitle
        }
        let email = usage?.identity?.accountEmail?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let email, !email.isEmpty {
            return email
        }
        return NSLocalizedString("usage.account.unknown", value: "Unknown Account", comment: "Unknown account")
    }

    // MARK: - 2. Body (Ghost List)
    private func quotaList(usage: UsageSnapshot) -> some View {
        VStack(spacing: 2) {
            let windows = usage.allWindows
            ForEach(windows) { item in
                ghostRow(title: localizedTitle(item), window: item.window)
            }
            
            if let credits, !credits.remaining.isNaN {
                creditsRow(credits)
            }
        }
    }

    private func ghostRow(title: String, window: RateWindow) -> some View {
        let percent = window.remainingPercent
        let color = statusColor(for: percent)

        return ZStack(alignment: .leading) {
            // Ghost Fill Background
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 6)
                    .fill(color.opacity(0.15))
                    .frame(width: percent.isInfinite ? proxy.size.width : max(0, proxy.size.width * min(1, max(0, percent / 100.0))))
            }
            .frame(height: 28)

            // Content Overlay
            HStack(alignment: .center) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(title)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(DesignSystem.Colors.Text.primary)
                    
                    if let resetsAt = window.resetsAt {
                        Text("· \(shortResetText(resetsAt: resetsAt))")
                            .font(.system(size: 9))
                            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
                    }
                }
                
                Spacer()
                
                Text(percentValue(percent))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
            }
            .padding(.horizontal, 10)
        }
        .frame(height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func creditsRow(_ credits: CreditsSnapshot) -> some View {
        HStack {
            Text(NSLocalizedString("usage.metric.credits", value: "Credits", comment: "Credits label"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Text.primary)
            
            Spacer()
            
            Text(creditsValue(credits.remaining))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(DesignSystem.Colors.primary)
        }
        .padding(.horizontal, 10)
        .frame(height: 28)
    }

    // MARK: - 3. Footer (Plan + Sync)
    private var footer: some View {
        HStack(alignment: .center) {
            if let plan = usage?.identity?.plan, !plan.isEmpty {
                Text(plan)
                    .font(.system(size: 8, weight: .black))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(RoundedRectangle(cornerRadius: 4).fill(planColor(plan).opacity(0.15)))
                    .foregroundStyle(planColor(plan))
                    .textCase(.uppercase)
            }

            Spacer()

            if let syncText = formattedSyncText {
                Text(syncText)
                    .font(.system(size: 10))
                    .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            }
        }
        .padding(.top, 10)
        .padding(.horizontal, 4)
        .divider(at: .top, color: DesignSystem.Colors.Background.elevated.opacity(0.3))
        .padding(.top, 4)
    }

    // MARK: - Error & Loading States
    private func errorState(message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(NSLocalizedString("usage.error.title", value: "Sync Failed", comment: "Error title"))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(DesignSystem.Colors.Status.error)
            Text(message)
                .font(.system(size: 9))
                .foregroundStyle(DesignSystem.Colors.Text.secondary)
                .lineLimit(2)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DesignSystem.Colors.Status.error.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var loadingSkeleton: some View {
        VStack(spacing: 2) {
            ForEach(0..<2) { _ in
                RoundedRectangle(cornerRadius: 6)
                    .fill(DesignSystem.Colors.Background.elevated.opacity(0.2))
                    .frame(height: 28)
                    .overlay(shimmerOverlay)
            }
        }
        .onAppear {
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
    }

    private var shimmerOverlay: some View {
        GeometryReader { proxy in
            Color.white.opacity(0.05)
                .mask(
                    Rectangle()
                        .fill(LinearGradient(gradient: Gradient(colors: [.clear, .white.opacity(0.1), .clear]), startPoint: .leading, endPoint: .trailing))
                        .offset(x: -proxy.size.width + (proxy.size.width * 2 * shimmerPhase))
                )
        }
    }

    // MARK: - Helpers
    private var formattedSyncText: String? {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        
        var parts: [String] = []
        if let loginAt {
            let timeStr = DateFormatter.localizedString(from: loginAt, dateStyle: .none, timeStyle: .short)
            parts.append(String(format: NSLocalizedString("usage.sync.login", value: "LoggedIn %@", comment: "Login time"), timeStr))
        }
        if let syncedAt {
            let relativeStr = formatter.localizedString(for: syncedAt, relativeTo: Date())
            parts.append(String(format: NSLocalizedString("usage.sync.synced", value: "Synced %@", comment: "Sync time"), relativeStr))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func shortResetText(resetsAt: Date) -> String {
        let remaining = resetsAt.timeIntervalSinceNow
        if remaining <= 0 { return NSLocalizedString("usage.reset.now", value: "now", comment: "reset now") }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        return String(format: NSLocalizedString("usage.reset.suffix", value: "%@ left", comment: "reset suffix"), formatter.string(from: remaining) ?? "")
    }

    private func percentValue(_ percent: Double) -> String {
        if percent.isInfinite { return "∞" }
        return String(format: "%.0f%%", percent)
    }

    private func creditsValue(_ value: Double) -> String {
        if value.isInfinite { return "∞" }
        return String(format: "%.0f", value)
    }

    func displayedCreditsTimestamp(for credits: CreditsSnapshot) -> Date {
        creditsRefreshedAt ?? credits.updatedAt
    }

    func creditsMetadataLines(for credits: CreditsSnapshot) -> [MetadataLine] {
        var lines: [MetadataLine] = []
        if let creditsRefreshedAt {
            lines.append(.init(prefixKey: "usage.metric.refreshed_at", date: creditsRefreshedAt))
        }
        if credits.updatedAt != creditsRefreshedAt {
            lines.append(.init(prefixKey: "usage.metric.updated_at", date: credits.updatedAt))
        }
        return lines
    }

    func statusColor(for percent: Double) -> Color {
        if percent.isInfinite { return DesignSystem.Colors.Status.success }
        if percent < 10 { return DesignSystem.Colors.Status.error }
        if percent < 25 { return DesignSystem.Colors.Status.warning }
        return DesignSystem.Colors.primary
    }

    func planColor(_ plan: String) -> Color {
        let p = plan.lowercased()
        if p.contains("pro") || p.contains("enterprise") || p.contains("team") { return DesignSystem.Colors.primary }
        if p.contains("free") || p.contains("limited") { return DesignSystem.Colors.Status.error }
        return DesignSystem.Colors.Text.secondary
    }

    func iconName(for title: String) -> String {
        let value = title.lowercased()
        if value.contains("session") {
            return "timer"
        }
        if value.contains("weekly") || value.contains("daily") {
            return "calendar"
        }
        return "chart.bar"
    }

    private func localizedTitle(_ item: UsageWindow) -> String {
        let metadata = ProviderUsageRegistry.metadata(for: provider)
        return switch item.id {
        case "primary": metadata?.sessionLabel ?? "Session"
        case "secondary": metadata?.weeklyLabel ?? "Weekly"
        default: item.title
        }
    }

    private var emptyState: some View {
        Text(NSLocalizedString("usage.monitor.empty.desc", value: "No data available.", comment: "Empty data"))
            .font(.system(size: 10))
            .foregroundStyle(DesignSystem.Colors.Text.tertiary)
            .frame(maxWidth: .infinity, minHeight: 40)
    }

    static func displayWindows(for usage: UsageSnapshot, provider: UsageProvider) -> [UsageWindow] {
        if !usage.windows.isEmpty { return usage.windows }
        var items: [UsageWindow] = []
        if let primary = usage.primary { items.append(UsageWindow(id: "primary", title: "Session", window: primary)) }
        if let secondary = usage.secondary { items.append(UsageWindow(id: "secondary", title: "Weekly", window: secondary)) }
        return items
    }
}
