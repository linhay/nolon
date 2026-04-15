import Foundation
import CodexBarProviderCatalog
import CopilotProvider

public struct CopilotUsageDescriptor: ProviderUsageDescribing {
    public typealias FetchUsageAction = @Sendable (String) async throws -> CopilotUsageSnapshot

    public let provider: UsageProvider = .copilot
    public let fetchPlan = ProviderFetchPlan(sourceModes: [.auto, .apiToken])
    private let fetchUsage: FetchUsageAction

    public init(fetchUsage: @escaping FetchUsageAction = CopilotUsageDescriptor.defaultFetchUsage) {
        self.fetchUsage = fetchUsage
    }

    public func fetchOutcome(context: ProviderFetchContext) async -> ProviderFetchOutcome {
        let fetchKind: ProviderFetchKind = .apiToken

        do {
            let token = context.token ?? context.environment["COPILOT_API_TOKEN"]
            guard let token, !token.isEmpty else {
                throw ProviderUsageError.missingToken(.copilot)
            }

            let usageSnapshot = try await fetchUsage(token)
            let primary = usageSnapshot.chatQuota.map { quota in
                makeRateWindow(quota: quota, quotaResetDate: usageSnapshot.quotaResetDate)
            }
            let secondary = usageSnapshot.premiumQuota.map { quota in
                makeRateWindow(quota: quota, quotaResetDate: usageSnapshot.quotaResetDate)
            }
            let windows = makeWindows(
                chatQuota: usageSnapshot.chatQuota,
                premiumQuota: usageSnapshot.premiumQuota,
                quotaResetDate: usageSnapshot.quotaResetDate
            )
            let accountLabel = Self.viewerPrimaryLabel(usageSnapshot.viewer)
            let organizationLabel = Self.viewerSecondaryLabel(
                usageSnapshot.viewer,
                primaryLabel: accountLabel
            )

            let identity = UsageIdentity(
                accountEmail: accountLabel,
                accountOrganization: organizationLabel,
                loginMethod: "GitHub",
                plan: Self.displayPlanLabel(usageSnapshot.plan)
            )

            let usage = UsageSnapshot(
                identity: identity,
                windows: windows,
                primary: primary,
                secondary: secondary,
                tertiary: nil,
                updatedAt: usageSnapshot.updatedAt
            )

            let result = ProviderFetchResult(
                usage: usage,
                credits: nil,
                cost: nil,
                sourceLabel: NSLocalizedString("usage.source.api_token", value: "API token", comment: "API token"),
                fetchKind: fetchKind,
                strategyKind: .direct
            )

            return ProviderFetchOutcome(fetchKind: fetchKind, result: .success(result))
        } catch {
            return ProviderFetchOutcome(fetchKind: fetchKind, result: .failure(error))
        }
    }

    private func makeWindows(
        chatQuota: CopilotQuota?,
        premiumQuota: CopilotQuota?,
        quotaResetDate: String
    ) -> [UsageWindow] {
        var windows: [UsageWindow] = []
        if let chatQuota {
            windows.append(
                UsageWindow(
                    id: "chat",
                    title: "Chat",
                    window: makeRateWindow(quota: chatQuota, quotaResetDate: quotaResetDate)
                )
            )
        }
        if let premiumQuota {
            windows.append(
                UsageWindow(
                    id: "premium",
                    title: "Premium",
                    window: makeRateWindow(quota: premiumQuota, quotaResetDate: quotaResetDate)
                )
            )
        }
        return windows
    }

    private func makeRateWindow(quota: CopilotQuota, quotaResetDate: String) -> RateWindow {
        RateWindow(
            usedPercent: quota.percentUsed,
            resetDescription: String(
                format: NSLocalizedString(
                    "usage.metric.resets_at_string",
                    value: "Resets %@",
                    comment: "Resets at label (string date)"
                ),
                quotaResetDate
            )
        )
    }

    public static func defaultFetchUsage(token: String) async throws -> CopilotUsageSnapshot {
        try await CopilotUsageFetcher(token: token).fetch()
    }

    private static func viewerPrimaryLabel(_ viewer: CopilotViewerProfile?) -> String? {
        let login = normalized(viewer?.login)
        if let login {
            return login
        }
        return normalized(viewer?.email) ?? normalized(viewer?.name)
    }

    private static func viewerSecondaryLabel(
        _ viewer: CopilotViewerProfile?,
        primaryLabel: String?
    ) -> String? {
        let name = normalized(viewer?.name)
        guard let name else { return nil }
        guard name != primaryLabel else { return nil }
        return name
    }

    private static func displayPlanLabel(_ raw: String?) -> String? {
        guard let raw = normalized(raw) else { return nil }
        let tokens = raw
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { token -> String in
                let lowercased = token.lowercased()
                switch lowercased {
                case "individual":
                    return "Individual"
                case "business":
                    return "Business"
                case "enterprise":
                    return "Enterprise"
                case "pro":
                    return "Pro"
                case "free":
                    return "Free"
                case "copilot":
                    return "Copilot"
                default:
                    return lowercased.capitalized
                }
            }
        let label = tokens.joined(separator: " ")
        return label.isEmpty ? raw : label
    }

    private static func normalized(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}
