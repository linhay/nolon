import SwiftUI
import ProviderUsage
import CodexBarProviderCatalog
import NolonUI
import NolonUIFoundation

struct ProviderQuotaSection: View {
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
    let usesCardChrome: Bool
    let showsHeader: Bool

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
        onRefresh: (() -> Void)? = nil,
        usesCardChrome: Bool = true,
        showsHeader: Bool = true
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
        self.usesCardChrome = usesCardChrome
        self.showsHeader = showsHeader
    }

    var body: some View {
        NolonUI.ProviderQuotaSectionView(
            data: makeQuotaData(),
            onRefresh: onRefresh
        )
    }

    private func makeQuotaData() -> ProviderQuotaSectionData {
        ProviderQuotaSectionData(
            accountTitle: resolvedAccountTitle,
            statusPercent: usage?.primary?.remainingPercent ?? 100,
            rows: makeRows(),
            creditsText: makeCreditsText(),
            planText: usage?.identity?.plan,
            syncText: formattedSyncText,
            isLoading: isLoading,
            errorMessage: errorMessage,
            showsEmptyState: showsEmptyState,
            usesCardChrome: usesCardChrome,
            showsHeader: showsHeader
        )
    }

    private func makeRows() -> [ProviderQuotaSectionData.WindowRow] {
        guard let usage else { return [] }
        return Self.displayWindows(for: usage, provider: provider).map { item in
            let percent = item.window.remainingPercent
            return .init(
                id: item.id,
                title: localizedTitle(item),
                remainingPercent: percent,
                percentText: percentText(percent),
                resetText: item.window.resetsAt.map(shortResetText(resetsAt:))
            )
        }
    }

    private func makeCreditsText() -> String? {
        guard let credits, !credits.remaining.isNaN else { return nil }
        return creditsValue(credits.remaining)
    }

    private var resolvedAccountTitle: String {
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

    private var formattedSyncText: String? {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated

        var parts: [String] = []
        if let loginAt {
            let timeString = DateFormatter.localizedString(from: loginAt, dateStyle: .none, timeStyle: .short)
            parts.append(String(format: NSLocalizedString("usage.sync.login", value: "LoggedIn %@", comment: "Login time"), timeString))
        }
        if let syncedAt {
            let relative = formatter.localizedString(for: syncedAt, relativeTo: Date())
            parts.append(String(format: NSLocalizedString("usage.sync.synced", value: "Synced %@", comment: "Sync time"), relative))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func shortResetText(resetsAt: Date) -> String {
        let remaining = resetsAt.timeIntervalSinceNow
        if remaining <= 0 {
            return NSLocalizedString("usage.reset.now", value: "now", comment: "reset now")
        }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute, .second]
        formatter.unitsStyle = .abbreviated
        formatter.maximumUnitCount = 1
        let duration = formatter.string(from: remaining) ?? ""
        return String(format: NSLocalizedString("usage.reset.suffix", value: "%@ left", comment: "reset suffix"), duration)
    }

    private func percentText(_ percent: Double) -> String {
        if percent.isInfinite { return "∞" }
        return String(format: "%.0f%%", percent)
    }

    private func creditsValue(_ value: Double) -> String {
        if value.isInfinite { return "∞" }
        return String(format: "%.0f", value)
    }

    private func localizedTitle(_ item: UsageWindow) -> String {
        let metadata = ProviderUsageRegistry.metadata(for: provider)
        return switch item.id {
        case "primary":
            metadata?.sessionLabel ?? "Session"
        case "secondary":
            metadata?.weeklyLabel ?? "Weekly"
        default:
            item.title
        }
    }

    static func displayWindows(for usage: UsageSnapshot, provider: UsageProvider) -> [UsageWindow] {
        if !usage.windows.isEmpty { return usage.windows }
        var items: [UsageWindow] = []
        if let primary = usage.primary {
            items.append(UsageWindow(id: "primary", title: "Session", window: primary))
        }
        if let secondary = usage.secondary {
            items.append(UsageWindow(id: "secondary", title: "Weekly", window: secondary))
        }
        return items
    }
}
