import Foundation
import ProviderUsage
import CodexBarProviderCatalog
import NolonUIFoundation

enum ProviderQuotaSectionDataBuilder {
    static func build(
        provider: UsageProvider,
        accountTitle: String?,
        usage: UsageSnapshot?,
        credits: ProviderUsage.CreditsSnapshot?,
        syncText: String?,
        isLoading: Bool,
        errorMessage: String?,
        showsEmptyState: Bool,
        usesCardChrome: Bool,
        showsHeader: Bool
    ) -> ProviderQuotaSectionData {
        ProviderQuotaSectionData(
            accountTitle: resolvedAccountTitle(accountTitle: accountTitle, usage: usage),
            statusPercent: usage?.primary?.remainingPercent ?? 100,
            rows: rows(provider: provider, usage: usage),
            creditsText: creditsText(credits),
            planText: usage?.identity?.plan,
            syncText: syncText,
            isLoading: isLoading,
            errorMessage: errorMessage,
            showsEmptyState: showsEmptyState,
            usesCardChrome: usesCardChrome,
            showsHeader: showsHeader
        )
    }

    static func rows(provider: UsageProvider, usage: UsageSnapshot?) -> [ProviderQuotaSectionData.WindowRow] {
        guard let usage else { return [] }
        return displayWindows(for: usage, provider: provider).map { item in
            let percent = item.window.remainingPercent
            return .init(
                id: item.id,
                title: localizedTitle(item, provider: provider),
                remainingPercent: percent,
                percentText: percentText(percent),
                resetText: item.window.resetsAt.map { ProviderQuotaSectionBuilders.resetText(resetsAt: $0) }
            )
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

    static func resolvedAccountTitle(accountTitle: String?, usage: UsageSnapshot?) -> String {
        if let resolvedTitle = TextNormalizationSupport.firstNonEmpty(
            accountTitle,
            usage?.identity?.accountEmail
        ) {
            return resolvedTitle
        }
        return NSLocalizedString("usage.account.unknown", value: "Unknown Account", comment: "Unknown account")
    }

    static func creditsText(_ credits: ProviderUsage.CreditsSnapshot?) -> String? {
        guard let credits, !credits.remaining.isNaN else { return nil }
        if credits.remaining.isInfinite { return "∞" }
        return String(format: "%.0f", credits.remaining)
    }

    static func percentText(_ percent: Double) -> String {
        if percent.isInfinite { return "∞" }
        return String(format: "%.0f%%", percent)
    }

    static func localizedTitle(_ item: UsageWindow, provider: UsageProvider) -> String {
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
}
