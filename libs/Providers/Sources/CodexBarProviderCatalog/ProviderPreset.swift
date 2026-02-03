import Foundation
import SweetCookieKit

public struct ProviderMetadataPreset: Sendable {
    public let id: UsageProvider
    public let displayName: String
    public let sessionLabel: String
    public let weeklyLabel: String
    public let opusLabel: String?
    public let supportsOpus: Bool
    public let supportsCredits: Bool
    public let creditsHint: String
    public let toggleTitle: String
    public let cliName: String
    public let defaultEnabled: Bool
    public let isPrimaryProvider: Bool
    public let usesAccountFallback: Bool
    public let browserCookieOrder: BrowserCookieImportOrder?
    public let dashboardURL: String?
    public let subscriptionDashboardURL: String?
    /// Statuspage.io base URL for incident polling (append /api/v2/status.json).
    public let statusPageURL: String?
    /// Browser-only status link (no API polling); used when statusPageURL is nil.
    public let statusLinkURL: String?
    /// Google Workspace product ID for status polling (appsstatus dashboard).
    public let statusWorkspaceProductID: String?

    public init(
        id: UsageProvider,
        displayName: String,
        sessionLabel: String,
        weeklyLabel: String,
        opusLabel: String?,
        supportsOpus: Bool,
        supportsCredits: Bool,
        creditsHint: String,
        toggleTitle: String,
        cliName: String,
        defaultEnabled: Bool,
        isPrimaryProvider: Bool = false,
        usesAccountFallback: Bool = false,
        browserCookieOrder: BrowserCookieImportOrder? = nil,
        dashboardURL: String?,
        subscriptionDashboardURL: String? = nil,
        statusPageURL: String?,
        statusLinkURL: String? = nil,
        statusWorkspaceProductID: String? = nil)
    {
        self.id = id
        self.displayName = displayName
        self.sessionLabel = sessionLabel
        self.weeklyLabel = weeklyLabel
        self.opusLabel = opusLabel
        self.supportsOpus = supportsOpus
        self.supportsCredits = supportsCredits
        self.creditsHint = creditsHint
        self.toggleTitle = toggleTitle
        self.cliName = cliName
        self.defaultEnabled = defaultEnabled
        self.isPrimaryProvider = isPrimaryProvider
        self.usesAccountFallback = usesAccountFallback
        self.browserCookieOrder = browserCookieOrder
        self.dashboardURL = dashboardURL
        self.subscriptionDashboardURL = subscriptionDashboardURL
        self.statusPageURL = statusPageURL
        self.statusLinkURL = statusLinkURL
        self.statusWorkspaceProductID = statusWorkspaceProductID
    }
}

public struct ProviderPreset: Sendable {
    public let id: UsageProvider
    public let metadata: ProviderMetadataPreset
    public let branding: ProviderBranding

    public init(id: UsageProvider, metadata: ProviderMetadataPreset, branding: ProviderBranding) {
        self.id = id
        self.metadata = metadata
        self.branding = branding
    }
}

public enum CodexBarProviderPresets {
    public static func preset(for id: UsageProvider) -> ProviderPreset {
        guard let preset = self.presets[id] else {
            preconditionFailure("Missing preset for \(id.rawValue)")
        }
        return preset
    }

    private static let presetsByID: [UsageProvider: ProviderPreset] = [
        .codex: ProviderPreset(
            id: .codex,
            metadata: ProviderMetadataPreset(
                id: .codex,
                displayName: "Codex",
                sessionLabel: "Session",
                weeklyLabel: "Weekly",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: true,
                creditsHint: "Credits unavailable; keep Codex running to refresh.",
                toggleTitle: "Show Codex usage",
                cliName: "codex",
                defaultEnabled: true,
                isPrimaryProvider: true,
                usesAccountFallback: true,
                browserCookieOrder: ProviderBrowserCookieDefaults.defaultImportOrder,
                dashboardURL: "https://chatgpt.com/codex/settings/usage",
                statusPageURL: "https://status.openai.com/"),
            branding: ProviderBranding(
                iconStyle: .codex,
                iconResourceName: "ProviderIcon-codex",
                color: ProviderColor(red: 73 / 255, green: 163 / 255, blue: 176 / 255))),
        .claude: ProviderPreset(
            id: .claude,
            metadata: ProviderMetadataPreset(
                id: .claude,
                displayName: "Claude",
                sessionLabel: "Session",
                weeklyLabel: "Weekly",
                opusLabel: "Sonnet",
                supportsOpus: true,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Claude Code usage",
                cliName: "claude",
                defaultEnabled: false,
                isPrimaryProvider: true,
                browserCookieOrder: ProviderBrowserCookieDefaults.defaultImportOrder,
                dashboardURL: "https://console.anthropic.com/settings/billing",
                subscriptionDashboardURL: "https://claude.ai/settings/usage",
                statusPageURL: "https://status.claude.com/"),
            branding: ProviderBranding(
                iconStyle: .claude,
                iconResourceName: "ProviderIcon-claude",
                color: ProviderColor(red: 204 / 255, green: 124 / 255, blue: 94 / 255))),
        .cursor: ProviderPreset(
            id: .cursor,
            metadata: ProviderMetadataPreset(
                id: .cursor,
                displayName: "Cursor",
                sessionLabel: "Plan",
                weeklyLabel: "On-Demand",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: true,
                creditsHint: "On-demand usage beyond included plan limits.",
                toggleTitle: "Show Cursor usage",
                cliName: "cursor",
                defaultEnabled: false,
                browserCookieOrder: ProviderBrowserCookieDefaults.defaultImportOrder,
                dashboardURL: "https://cursor.com/dashboard?tab=usage",
                statusPageURL: "https://status.cursor.com"),
            branding: ProviderBranding(
                iconStyle: .cursor,
                iconResourceName: "ProviderIcon-cursor",
                color: ProviderColor(red: 0 / 255, green: 191 / 255, blue: 165 / 255))),
        .opencode: ProviderPreset(
            id: .opencode,
            metadata: ProviderMetadataPreset(
                id: .opencode,
                displayName: "OpenCode",
                sessionLabel: "5-hour",
                weeklyLabel: "Weekly",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show OpenCode usage",
                cliName: "opencode",
                defaultEnabled: false,
                browserCookieOrder: ProviderBrowserCookieDefaults.defaultImportOrder,
                dashboardURL: "https://opencode.ai",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .opencode,
                iconResourceName: "ProviderIcon-opencode",
                color: ProviderColor(red: 59 / 255, green: 130 / 255, blue: 246 / 255))),
        .factory: ProviderPreset(
            id: .factory,
            metadata: ProviderMetadataPreset(
                id: .factory,
                displayName: "Droid",
                sessionLabel: "Standard",
                weeklyLabel: "Premium",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Droid usage",
                cliName: "factory",
                defaultEnabled: false,
                browserCookieOrder: ProviderBrowserCookieDefaults.defaultImportOrder,
                dashboardURL: "https://app.factory.ai/settings/billing",
                statusPageURL: "https://status.factory.ai"),
            branding: ProviderBranding(
                iconStyle: .factory,
                iconResourceName: "ProviderIcon-factory",
                color: ProviderColor(red: 255 / 255, green: 107 / 255, blue: 53 / 255))),
        .gemini: ProviderPreset(
            id: .gemini,
            metadata: ProviderMetadataPreset(
                id: .gemini,
                displayName: "Gemini",
                sessionLabel: "Pro",
                weeklyLabel: "Flash",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Gemini usage",
                cliName: "gemini",
                defaultEnabled: false,
                dashboardURL: "https://gemini.google.com",
                statusPageURL: nil,
                statusLinkURL: "https://www.google.com/appsstatus/dashboard/products/npdyhgECDJ6tB66MxXyo/history",
                statusWorkspaceProductID: "npdyhgECDJ6tB66MxXyo"),
            branding: ProviderBranding(
                iconStyle: .gemini,
                iconResourceName: "ProviderIcon-gemini",
                color: ProviderColor(red: 171 / 255, green: 135 / 255, blue: 234 / 255))),
        .antigravity: ProviderPreset(
            id: .antigravity,
            metadata: ProviderMetadataPreset(
                id: .antigravity,
                displayName: "Antigravity",
                sessionLabel: "Claude",
                weeklyLabel: "Gemini Pro",
                opusLabel: "Gemini Flash",
                supportsOpus: true,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Antigravity usage (experimental)",
                cliName: "antigravity",
                defaultEnabled: false,
                dashboardURL: nil,
                statusPageURL: nil,
                statusLinkURL: "https://www.google.com/appsstatus/dashboard/products/npdyhgECDJ6tB66MxXyo/history",
                statusWorkspaceProductID: "npdyhgECDJ6tB66MxXyo"),
            branding: ProviderBranding(
                iconStyle: .antigravity,
                iconResourceName: "ProviderIcon-antigravity",
                color: ProviderColor(red: 96 / 255, green: 186 / 255, blue: 126 / 255))),
        .copilot: ProviderPreset(
            id: .copilot,
            metadata: ProviderMetadataPreset(
                id: .copilot,
                displayName: "Copilot",
                sessionLabel: "Premium",
                weeklyLabel: "Chat",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Copilot usage",
                cliName: "copilot",
                defaultEnabled: false,
                dashboardURL: "https://github.com/settings/copilot",
                statusPageURL: "https://www.githubstatus.com/"),
            branding: ProviderBranding(
                iconStyle: .copilot,
                iconResourceName: "ProviderIcon-copilot",
                color: ProviderColor(red: 168 / 255, green: 85 / 255, blue: 247 / 255))),
        .zai: ProviderPreset(
            id: .zai,
            metadata: ProviderMetadataPreset(
                id: .zai,
                displayName: "z.ai",
                sessionLabel: "Tokens",
                weeklyLabel: "MCP",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show z.ai usage",
                cliName: "zai",
                defaultEnabled: false,
                dashboardURL: "https://z.ai/manage-apikey/subscription",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .zai,
                iconResourceName: "ProviderIcon-zai",
                color: ProviderColor(red: 232 / 255, green: 90 / 255, blue: 106 / 255))),
        .minimax: ProviderPreset(
            id: .minimax,
            metadata: ProviderMetadataPreset(
                id: .minimax,
                displayName: "MiniMax",
                sessionLabel: "Prompts",
                weeklyLabel: "Window",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show MiniMax usage",
                cliName: "minimax",
                defaultEnabled: false,
                browserCookieOrder: ProviderBrowserCookieDefaults.defaultImportOrder,
                dashboardURL: "https://platform.minimax.io/user-center/payment/coding-plan?cycle_type=3",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .minimax,
                iconResourceName: "ProviderIcon-minimax",
                color: ProviderColor(red: 254 / 255, green: 96 / 255, blue: 60 / 255))),
        .kimi: ProviderPreset(
            id: .kimi,
            metadata: ProviderMetadataPreset(
                id: .kimi,
                displayName: "Kimi",
                sessionLabel: "Weekly",
                weeklyLabel: "Rate Limit",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Kimi usage",
                cliName: "kimi",
                defaultEnabled: false,
                dashboardURL: "https://www.kimi.com/code/console",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .kimi,
                iconResourceName: "ProviderIcon-kimi",
                color: ProviderColor(red: 254 / 255, green: 96 / 255, blue: 60 / 255))),
        .kiro: ProviderPreset(
            id: .kiro,
            metadata: ProviderMetadataPreset(
                id: .kiro,
                displayName: "Kiro",
                sessionLabel: "Credits",
                weeklyLabel: "Bonus",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Kiro usage",
                cliName: "kiro",
                defaultEnabled: false,
                dashboardURL: "https://app.kiro.dev/account/usage",
                statusPageURL: nil,
                statusLinkURL: "https://health.aws.amazon.com/health/status"),
            branding: ProviderBranding(
                iconStyle: .kiro,
                iconResourceName: "ProviderIcon-kiro",
                color: ProviderColor(red: 255 / 255, green: 153 / 255, blue: 0 / 255))),
        .vertexai: ProviderPreset(
            id: .vertexai,
            metadata: ProviderMetadataPreset(
                id: .vertexai,
                displayName: "Vertex AI",
                sessionLabel: "Requests",
                weeklyLabel: "Tokens",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Vertex AI usage",
                cliName: "vertexai",
                defaultEnabled: false,
                dashboardURL: "https://console.cloud.google.com/vertex-ai",
                statusPageURL: nil,
                statusLinkURL: "https://status.cloud.google.com"),
            branding: ProviderBranding(
                iconStyle: .vertexai,
                iconResourceName: "ProviderIcon-vertexai",
                color: ProviderColor(red: 66 / 255, green: 133 / 255, blue: 244 / 255))),
        .augment: ProviderPreset(
            id: .augment,
            metadata: ProviderMetadataPreset(
                id: .augment,
                displayName: "Augment",
                sessionLabel: "Credits",
                weeklyLabel: "Usage",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: true,
                creditsHint: "Augment Code credits for AI-powered coding assistance.",
                toggleTitle: "Show Augment usage",
                cliName: "augment",
                defaultEnabled: false,
                browserCookieOrder: ProviderBrowserCookieDefaults.augmentImportOrder,
                dashboardURL: "https://app.augmentcode.com/account/subscription",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .augment,
                iconResourceName: "ProviderIcon-augment",
                color: ProviderColor(red: 99 / 255, green: 102 / 255, blue: 241 / 255))),
        .jetbrains: ProviderPreset(
            id: .jetbrains,
            metadata: ProviderMetadataPreset(
                id: .jetbrains,
                displayName: "JetBrains AI",
                sessionLabel: "Current",
                weeklyLabel: "Refill",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show JetBrains AI usage",
                cliName: "jetbrains",
                defaultEnabled: false,
                dashboardURL: nil,
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .jetbrains,
                iconResourceName: "ProviderIcon-jetbrains",
                color: ProviderColor(red: 255 / 255, green: 51 / 255, blue: 153 / 255))),
        .kimik2: ProviderPreset(
            id: .kimik2,
            metadata: ProviderMetadataPreset(
                id: .kimik2,
                displayName: "Kimi K2",
                sessionLabel: "Credits",
                weeklyLabel: "Credits",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Kimi K2 usage",
                cliName: "kimik2",
                defaultEnabled: false,
                dashboardURL: "https://kimi-k2.ai/my-credits",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .kimi,
                iconResourceName: "ProviderIcon-kimi",
                color: ProviderColor(red: 76 / 255, green: 0 / 255, blue: 255 / 255))),
        .amp: ProviderPreset(
            id: .amp,
            metadata: ProviderMetadataPreset(
                id: .amp,
                displayName: "Amp",
                sessionLabel: "Amp Free",
                weeklyLabel: "Balance",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Amp usage",
                cliName: "amp",
                defaultEnabled: false,
                browserCookieOrder: ProviderBrowserCookieDefaults.defaultImportOrder,
                dashboardURL: "https://ampcode.com/settings",
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .amp,
                iconResourceName: "ProviderIcon-amp",
                color: ProviderColor(red: 220 / 255, green: 38 / 255, blue: 38 / 255))),
        .synthetic: ProviderPreset(
            id: .synthetic,
            metadata: ProviderMetadataPreset(
                id: .synthetic,
                displayName: "Synthetic",
                sessionLabel: "Quota",
                weeklyLabel: "Usage",
                opusLabel: nil,
                supportsOpus: false,
                supportsCredits: false,
                creditsHint: "",
                toggleTitle: "Show Synthetic usage",
                cliName: "synthetic",
                defaultEnabled: false,
                dashboardURL: nil,
                statusPageURL: nil),
            branding: ProviderBranding(
                iconStyle: .synthetic,
                iconResourceName: "ProviderIcon-synthetic",
                color: ProviderColor(red: 20 / 255, green: 20 / 255, blue: 20 / 255))),
    ]

    public static var presets: [UsageProvider: ProviderPreset] {
        self.presetsByID
    }
}
