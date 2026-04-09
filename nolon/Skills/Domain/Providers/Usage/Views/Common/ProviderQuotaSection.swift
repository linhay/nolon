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
        ProviderQuotaSectionDataBuilder.build(
            provider: provider,
            accountTitle: accountTitle,
            usage: usage,
            credits: credits,
            syncText: ProviderQuotaSectionBuilders.syncText(loginAt: loginAt, syncedAt: syncedAt),
            isLoading: isLoading,
            errorMessage: errorMessage,
            showsEmptyState: showsEmptyState,
            usesCardChrome: usesCardChrome,
            showsHeader: showsHeader
        )
    }

    static func displayWindows(for usage: UsageSnapshot, provider: UsageProvider) -> [UsageWindow] {
        ProviderQuotaSectionDataBuilder.displayWindows(for: usage, provider: provider)
    }

    private func makeRows() -> [ProviderQuotaSectionData.WindowRow] {
        ProviderQuotaSectionDataBuilder.rows(provider: provider, usage: usage)
    }

    private func makeCreditsText() -> String? {
        ProviderQuotaSectionDataBuilder.creditsText(credits)
    }

    private var resolvedAccountTitle: String {
        ProviderQuotaSectionDataBuilder.resolvedAccountTitle(accountTitle: accountTitle, usage: usage)
    }

    private func percentText(_ percent: Double) -> String {
        ProviderQuotaSectionDataBuilder.percentText(percent)
    }

    private func localizedTitle(_ item: UsageWindow) -> String {
        ProviderQuotaSectionDataBuilder.localizedTitle(item, provider: provider)
    }
}
