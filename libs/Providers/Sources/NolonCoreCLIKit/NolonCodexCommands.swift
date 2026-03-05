import ArgumentParser

struct NolonRootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "nolon",
        subcommands: [
            NolonCodexRootCommand.self,
            NolonGeminiRootCommand.self,
            NolonProviderRootCommand.self,
            NolonSkillsRootCommand.self,
            NolonWorkflowRootCommand.self,
            NolonMcpRootCommand.self,
            NolonPluginRootCommand.self,
            NolonRemoteRootCommand.self,
        ]
    )
}

struct NolonCodexRootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "codex",
        subcommands: [
            NolonCodexAuthGroupCommand.self,
            NolonCodexBinaryGroupCommand.self,
            NolonCodexStatusGroupCommand.self,
            NolonCodexRuntimeGroupCommand.self,
            NolonCodexProviderGroupCommand.self,
        ]
    )
}

struct NolonCodexAuthGroupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "auth",
        subcommands: [
            NolonCodexAuthListCommand.self,
            NolonCodexAuthUsageCommand.self,
            NolonCodexAuthUsageTrendCommand.self,
            NolonCodexAuthStatusCommand.self,
            NolonCodexAuthRefreshCommand.self,
            NolonCodexAuthActivateCommand.self,
            NolonCodexAuthLoginCommand.self,
            NolonCodexAuthDeleteCommand.self,
        ]
    )
}

struct NolonCodexBinaryGroupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "binary",
        subcommands: [
            NolonCodexBinaryListCommand.self,
            NolonCodexBinaryCurrentCommand.self,
            NolonCodexBinaryInstallCommand.self,
            NolonCodexBinaryUseCommand.self,
            NolonCodexBinaryDoctorCommand.self,
            NolonCodexBinaryAvailableCommand.self,
            NolonCodexBinarySwitchCommand.self,
        ]
    )
}

struct NolonCodexStatusGroupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "status",
        subcommands: [
            NolonCodexStatusProbeCommand.self,
            NolonCodexStatusDoctorCommand.self,
        ]
    )
}

struct NolonCodexRuntimeGroupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "runtime",
        subcommands: [NolonCodexRuntimeListCommand.self, NolonCodexRuntimeStopCommand.self]
    )
}

struct NolonCodexProviderGroupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "provider",
        subcommands: [NolonCodexProviderDiscoverCommand.self]
    )
}

struct NolonCodexAuthListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"
}

struct NolonCodexAuthUsageCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "usage")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"

    @Flag(name: .long, help: "Show aggregated summary only.")
    var summary: Bool = false

    @Flag(name: .long, help: "Refresh usage cache before rendering output.")
    var refresh: Bool = false

    @Option(name: .long, help: "Account id UUID for usage refresh target (requires --refresh).")
    var accountID: String?

    @Option(name: .long, help: "Account email for usage refresh target (requires --refresh).")
    var email: String?
}

struct NolonCodexAuthUsageTrendCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "usage-trend")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"

    @Option(name: .long, help: "Trend range: 7d, 30d, all.")
    var range: String = "30d"
}

struct NolonCodexAuthStatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"
}

struct NolonCodexAuthRefreshCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "refresh",
        abstract: "Refresh Codex account tokens. Without a target, refreshes all accounts and keeps current active account."
    )

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"

    @Option(name: .long, help: "Account id UUID. Targeted refresh switches active account to this target.")
    var accountID: String?

    @Option(name: .long, help: "Account email for selecting refresh target. Targeted refresh switches active account to this target.")
    var email: String?
}

struct NolonCodexAuthActivateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "activate")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"

    @Option(name: .long, help: "Account id UUID.")
    var accountID: String?

    @Option(name: .long, help: "Account email for non-interactive activation.")
    var email: String?

    @Flag(name: .long, help: "Use TUI picker when account id is omitted.")
    var tui: Bool = false
}

struct NolonCodexAuthLoginCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "login")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"

    @Option(name: .long, help: "Preferred account id UUID for snapshot update.")
    var preferredAccountID: String?
}

struct NolonCodexAuthDeleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"

    @Option(name: .long, help: "Account id UUID.")
    var accountID: String
}

struct NolonCodexBinaryInstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install")

    @Argument(help: "Version tag to install, e.g. 0.26.0 or rust-v0.26.0.")
    var version: String

    @Flag(name: .long, help: "Activate this version after install.")
    var setDefault: Bool = false
}

struct NolonCodexBinaryListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list")
}

struct NolonCodexBinaryAvailableCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "available")
}

struct NolonCodexBinarySwitchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "switch")
}

struct NolonCodexBinaryCurrentCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "current")
}

struct NolonCodexBinaryUseCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "use")

    @Option(name: .long, help: "Version id or semantic version.")
    var version: String
}

struct NolonCodexBinaryDoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "doctor")
}

struct NolonCodexStatusProbeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "probe")

    @Option(name: .long, help: "Provider id for reporting context.")
    var provider: String?
}

struct NolonCodexStatusDoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "doctor")
}

struct NolonCodexRuntimeListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list")
}

struct NolonCodexRuntimeStopCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "stop")

    @Option(name: .long, help: "Target runtime pid.")
    var pid: Int32

    @Flag(name: .long, help: "Send SIGKILL immediately.")
    var force: Bool = false

    @Option(name: .long, help: "Timeout seconds before escalating TERM to KILL.")
    var timeoutSeconds: Int = 8
}

struct NolonCodexProviderDiscoverCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "discover")
}

struct NolonGeminiRootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "gemini",
        subcommands: [NolonGeminiAuthGroupCommand.self]
    )
}

struct NolonGeminiAuthGroupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "auth",
        subcommands: [
            NolonGeminiAuthListCommand.self,
            NolonGeminiAuthStatusCommand.self,
            NolonGeminiAuthLoginCommand.self,
            NolonGeminiAuthRefreshCommand.self,
            NolonGeminiAuthActivateCommand.self,
            NolonGeminiAuthDeleteCommand.self,
            NolonGeminiAuthUsageCommand.self,
            NolonGeminiAuthDoctorCommand.self,
        ]
    )
}

struct NolonGeminiAuthListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list")

    @Option(name: .long, help: "Provider id: gemini or antigravity (required).")
    var provider: String
}

struct NolonGeminiAuthStatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status")

    @Option(name: .long, help: "Provider id: gemini or antigravity (required).")
    var provider: String
}

struct NolonGeminiAuthLoginCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "login")

    @Option(name: .long, help: "Provider id: gemini or antigravity (required).")
    var provider: String

    @Option(name: .long, help: "Auth method: oauth-personal | gemini-api-key | vertex-ai (required).")
    var method: String

    @Option(name: .long, help: "Account display name.")
    var name: String?

    @Option(name: .long, help: "Account email.")
    var email: String?

    @Option(name: .long, help: "OAuth login timeout in seconds.")
    var timeoutSeconds: Int = 300

    @Option(name: .long, help: "Gemini API key (for gemini-api-key method).")
    var apiKey: String?

    @Option(name: .long, help: "Google API key (for vertex-ai method).")
    var googleAPIKey: String?

    @Option(name: .long, help: "Vertex project id (for vertex-ai method).")
    var project: String?

    @Option(name: .long, help: "Vertex location (for vertex-ai method).")
    var location: String?

    @Flag(name: .long, help: "Use ADC for vertex-ai method.")
    var useADC: Bool = false
}

struct NolonGeminiAuthRefreshCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "refresh")

    @Option(name: .long, help: "Provider id: gemini or antigravity (required).")
    var provider: String
}

struct NolonGeminiAuthActivateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "activate")

    @Option(name: .long, help: "Provider id: gemini or antigravity (required).")
    var provider: String

    @Option(name: .long, help: "Account id UUID.")
    var accountID: String
}

struct NolonGeminiAuthDeleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete")

    @Option(name: .long, help: "Provider id: gemini or antigravity (required).")
    var provider: String

    @Option(name: .long, help: "Account id UUID.")
    var accountID: String
}

struct NolonGeminiAuthUsageCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "usage")

    @Option(name: .long, help: "Provider id: gemini or antigravity (required).")
    var provider: String
}

struct NolonGeminiAuthDoctorCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "doctor")

    @Option(name: .long, help: "Provider id: gemini or antigravity (required).")
    var provider: String
}

struct NolonProviderRootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "provider",
        subcommands: [NolonProviderListCommand.self, NolonProviderDiscoverCommand.self]
    )
}

struct NolonProviderListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list")
}

struct NolonProviderDiscoverCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "discover")
}
