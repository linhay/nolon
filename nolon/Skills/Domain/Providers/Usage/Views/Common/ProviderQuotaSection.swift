import SwiftUI
import ProviderUsage
import CodexBarProviderCatalog
import NolonUI
import NolonUIFoundation

struct ProviderQuotaSection: View {
    let provider: UsageProvider
    let accountTitle: String?
    let usage: UsageSnapshot?
    let credits: ProviderUsage.CreditsSnapshot?
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
        credits: ProviderUsage.CreditsSnapshot? = nil,
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
            syncText: ProviderQuotaSectionBuilders.syncText(loginAt: loginAt, syncedAt: syncedAt),
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
                resetText: item.window.resetsAt.map { ProviderQuotaSectionBuilders.resetText(resetsAt: $0) }
            )
        }
    }

    private func makeCreditsText() -> String? {
        guard let credits, !credits.remaining.isNaN else { return nil }
        if credits.remaining.isInfinite { return "∞" }
        return String(format: "%.0f", credits.remaining)
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

    private func percentText(_ percent: Double) -> String {
        if percent.isInfinite { return "∞" }
        return String(format: "%.0f%%", percent)
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

    static func displayWindows(for usage: UsageSnapshot, provider _: UsageProvider) -> [UsageWindow] {
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
