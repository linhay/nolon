import ArgumentParser
import Foundation
import ProviderCatalog

extension NolonGitPullStrategy: ExpressibleByArgument {}
extension NolonGitCredentialStrategy: ExpressibleByArgument {}
extension NolonSkillInstallMethod: ExpressibleByArgument {}
extension NolonRemoteCatalogKind: ExpressibleByArgument {}
extension NolonProviderSkillStateKind: ExpressibleByArgument {}

private enum NolonCoreCLIPathDefaults {
    static func repositoriesRootPath(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
        let basePath: String
        if let raw = environment["NOLON_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            basePath = NSString(string: raw).expandingTildeInPath
        } else {
            basePath = NSString(string: "~/.nolon").expandingTildeInPath
        }
        return URL(fileURLWithPath: basePath, isDirectory: true)
            .appendingPathComponent("repositories", isDirectory: true)
            .path
    }
}

struct NolonSkillsRootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skills",
        abstract: "Search, add, remove and sync skills.",
        discussion: """
        Examples:
          nolon skills search xcode
          nolon skills add xcode --provider codex
          nolon skills list --provider codex --state broken
        """,
        subcommands: [
            NolonSkillsListCommand.self,
            NolonSkillsSyncCommand.self,
            NolonSkillsSearchCommand.self,
            NolonSkillsAddCommand.self,
            NolonSkillsRemoveCommand.self,
            NolonSkillsRepoGroupCommand.self,
            NolonSkillsDiscoverCommand.self,
            NolonSkillsParseCommand.self,
            NolonSkillsInstallCommand.self,
            NolonSkillsUninstallCommand.self,
            NolonSkillsMigrateGroupCommand.self,
        ]
    )
}

struct NolonSkillsRepoGroupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "repo",
        abstract: "List, plan, preflight and sync Git-based skill repositories.",
        shouldDisplay: false,
        subcommands: [
            NolonSkillsRepoListCommand.self,
            NolonSkillsRepoPlanCommand.self,
            NolonSkillsRepoPreflightCommand.self,
            NolonSkillsRepoSyncCommand.self,
        ]
    )
}

struct NolonSkillsMigrateGroupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "migrate",
        abstract: "Scan and apply provider skill migration.",
        shouldDisplay: false,
        subcommands: [
            NolonSkillsMigrateScanCommand.self,
            NolonSkillsMigrateApplyCommand.self,
        ]
    )
}

struct NolonSkillsListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "Inspect skill install states by provider (defaults to orphaned/broken view)."
    )

    @Option(name: .long, help: "Target provider ID. Omit only if you intend multi-provider distribution to all detected CLI providers.")
    var provider: String?

    @Option(name: .long, help: "Alias of --provider. Omit only if you intend multi-provider distribution to all detected CLI providers.")
    var providerID: String?

    @Flag(name: .long)
    var includeEmpty: Bool = false

    @Option(name: .long)
    var state: NolonProviderSkillStateKind?

    @Flag(name: .long, help: "Show full install path for each skill item.")
    var verbose: Bool = false

    @Flag(name: .long, help: "Show repair commands for orphaned/broken items.")
    var showFixes: Bool = false

    func validate() throws {
        if let provider, let providerID {
            if provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                throw ValidationError("Use either --provider or --provider-id, not both with different values.")
            }
        }
    }
}

struct NolonSkillsSyncCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Clone or update repository and discover resources."
    )

    @Option(name: .long)
    var source: String

    @Option(name: .long)
    var repositoriesRoot: String = NolonCoreCLIPathDefaults.repositoriesRootPath()

    @Option(name: .long)
    var pullStrategy: NolonGitPullStrategy = .ffOnly

    @Option(name: .long)
    var credentialStrategy: NolonGitCredentialStrategy = .automatic

    @Option(name: .long)
    var accessToken: String?
}

struct NolonSkillsRepoPlanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "plan",
        abstract: "Build repository clone/sync plan from source."
    )

    @Option(name: .long)
    var source: String

    @Option(name: .long)
    var repositoriesRoot: String

    @Option(name: .long)
    var pullStrategy: NolonGitPullStrategy = .ffOnly

    @Option(name: .long)
    var credentialStrategy: NolonGitCredentialStrategy = .automatic

    @Option(name: .long)
    var accessToken: String?
}

struct NolonSkillsRepoListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List local git repositories under repositories root."
    )

    @Option(name: .long)
    var repositoriesRoot: String = NolonCoreCLIPathDefaults.repositoriesRootPath()

    @Option(name: .long)
    var maxDepth: Int = 5

    @Flag(name: .long)
    var verbose: Bool = false

    func validate() throws {
        guard maxDepth > 0 else {
            throw ValidationError("--max-depth must be greater than 0.")
        }
    }
}

struct NolonSkillsRepoPreflightCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "preflight",
        abstract: "Validate sync strategy and credentials before clone/pull."
    )

    @Option(name: .long)
    var source: String

    @Option(name: .long)
    var pullStrategy: NolonGitPullStrategy = .ffOnly

    @Option(name: .long)
    var credentialStrategy: NolonGitCredentialStrategy = .automatic

    @Option(name: .long)
    var accessToken: String?
}

struct NolonSkillsSearchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search remote skills in Clawhub catalog.",
        discussion: """
        Examples:
          nolon skills search "swiftui" --install --pick 1 --provider codex --dry-run
        """
    )

    @Argument(help: "Search keyword.")
    var keyword: String?

    @Option(name: .long)
    var query: String?

    @Option(name: .long)
    var limit: Int = 20

    @Option(name: .long)
    var baseURL: String = "https://clawdhub.com"

    @Flag(name: .long, help: "Install matched skill(s); if multiple results, use --pick <index> to choose one.")
    var install: Bool = false

    @Option(name: .long, help: "Target provider ID. Omit to distribute to all detected CLI providers.")
    var provider: String?

    @Option(name: .long, help: "Alias of --provider. Omit to distribute to all detected CLI providers.")
    var providerID: String?

    @Option(name: .long)
    var installMethod: NolonSkillInstallMethod = .symlink

    @Option(name: .long, help: "Pick one search result by 1-based index when used with --install.")
    var pick: Int?

    @Flag(name: .long, help: "With --install, resolve and plan install without writing files.")
    var dryRun: Bool = false

    @Flag(name: .long, help: "Confirm non-dry-run install.")
    var yes: Bool = false

    func validate() throws {
        if keyword != nil, query != nil {
            let positional = keyword?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let optionQuery = query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw ValidationError(
                """
                Conflicting query input: received positional <query> (\(positional)) and --query (\(optionQuery)).
                Use one form only.
                Examples:
                - nolon skills search \(positional)
                - nolon skills search --query \(optionQuery)
                """
            )
        }
        guard limit > 0 else {
            throw ValidationError("--limit must be greater than 0; received \(limit). Try --limit 10.")
        }
        guard limit <= 200 else {
            throw ValidationError("--limit must be less than or equal to 200.")
        }
        if let provider, let providerID {
            if provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                throw ValidationError("Use either --provider or --provider-id, not both with different values.")
            }
        }
        if !install {
            if provider != nil || providerID != nil {
                throw ValidationError("--provider requires --install.")
            }
            if installMethod != .symlink {
                throw ValidationError("--install-method requires --install.")
            }
            if dryRun {
                throw ValidationError("--dry-run requires --install.")
            }
            if yes {
                throw ValidationError("--yes requires --install.")
            }
            if pick != nil {
                throw ValidationError("--pick requires --install.")
            }
        } else if !dryRun && !yes {
            throw ValidationError(
                """
                检测到写入操作。请先用 --dry-run 预览，确认后再加 --yes 执行。
                示例：
                - nolon skills search <keyword> --install --dry-run
                - nolon skills search <keyword> --install --yes --provider codex
                - nolon skills search --query <text> --install --dry-run
                - nolon skills search --query <text> --install --yes --provider codex
                """
            )
        }
        if let pick, pick <= 0 {
            throw ValidationError("--pick must be greater than 0; received \(pick).")
        }
    }
}

struct NolonSkillsRepoSyncCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "sync",
        abstract: "Clone or update repository and discover resources."
    )

    @Option(name: .long)
    var source: String

    @Option(name: .long)
    var repositoriesRoot: String

    @Option(name: .long)
    var pullStrategy: NolonGitPullStrategy = .ffOnly

    @Option(name: .long)
    var credentialStrategy: NolonGitCredentialStrategy = .automatic

    @Option(name: .long)
    var accessToken: String?
}

struct NolonSkillsAddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Install skill by slug: local repo first, fallback remote, cache to NOLON_HOME/skills, then distribute.",
        discussion: """
        Examples:
          nolon skills add swift-concurrency-expert --provider codex --dry-run
        """
    )

    @Argument(help: "Skill slug.")
    var slug: String

    @Option(name: .long, help: "Target provider ID. Omit to distribute to all detected CLI providers.")
    var provider: String?

    @Option(name: .long, help: "Alias of --provider. Omit to distribute to all detected CLI providers.")
    var providerID: String?

    @Option(name: .long)
    var version: String?

    @Option(name: .long)
    var baseURL: String = "https://clawdhub.com"

    @Option(name: .long)
    var installMethod: NolonSkillInstallMethod = .symlink

    @Option(name: .long)
    var repositoriesRoot: String = NolonCoreCLIPathDefaults.repositoriesRootPath()

    @Flag(name: .long, help: "Resolve source and targets only; do not write cache or install.")
    var dryRun: Bool = false

    func validate() throws {
        let slug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !slug.isEmpty else {
            throw ValidationError("<slug> cannot be empty.")
        }
        if let provider, let providerID {
            if provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() != providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                throw ValidationError("Use either --provider or --provider-id, not both with different values.")
            }
        }
    }
}

struct NolonSkillsDiscoverCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "discover",
        abstract: "Discover local skills directories under a path.",
        shouldDisplay: false
    )

    @Option(name: .long)
    var path: String

    @Option(name: .long)
    var maxDepth: Int = 5
}

struct NolonSkillsParseCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "parse",
        abstract: "Parse SKILL.md metadata.",
        shouldDisplay: false
    )

    @Option(name: .long)
    var file: String

    @Option(name: .long)
    var directoryName: String?
}

struct NolonSkillsInstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install one skill into provider path.",
        shouldDisplay: false
    )

    @Option(name: .long)
    var skillPath: String

    @Option(name: .long)
    var providerPath: String

    @Option(name: .long)
    var skillID: String?

    @Option(name: .long)
    var installMethod: NolonSkillInstallMethod = .symlink
}

struct NolonSkillsUninstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "uninstall",
        abstract: "Uninstall one skill from provider path.",
        shouldDisplay: false
    )

    @Option(name: .long)
    var skillID: String

    @Option(name: .long)
    var providerPath: String
}

struct NolonSkillsMigrateScanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "scan",
        abstract: "Scan provider path and report migration states.",
        shouldDisplay: false
    )

    @Option(name: .long)
    var providerPath: String

    @Option(name: .long)
    var globalSkillsPath: String
}

struct NolonSkillsMigrateApplyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "apply",
        abstract: "Apply migration for one skill id.",
        shouldDisplay: false
    )

    @Option(name: .long)
    var skillID: String

    @Option(name: .long)
    var providerPath: String

    @Option(name: .long)
    var globalSkillsPath: String

    @Option(name: .long)
    var installMethod: NolonSkillInstallMethod = .symlink
}

struct NolonWorkflowRootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "workflow",
        subcommands: [
            NolonWorkflowListCommand.self,
            NolonWorkflowSyncCommand.self,
            NolonWorkflowSearchCommand.self,
            NolonWorkflowAddCommand.self,
            NolonWorkflowRemoveCommand.self,
            NolonWorkflowBindSkillCommand.self,
            NolonWorkflowBindMcpCommand.self,
            NolonWorkflowUnbindSkillCommand.self,
            NolonWorkflowUnbindMcpCommand.self,
        ]
    )
}

struct NolonWorkflowListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list")

    @Option(name: .long, help: "Target provider ID. Omit only if you intend multi-provider distribution to all detected CLI providers.")
    var provider: String?

    @Option(name: .long, help: "Alias of --provider. Omit only if you intend multi-provider distribution to all detected CLI providers.")
    var providerID: String?

    @Flag(name: .long)
    var includeEmpty: Bool = false

    @Option(name: .long)
    var state: NolonProviderSkillStateKind?

    @Flag(name: .long, help: "Show full install path for each workflow item.")
    var verbose: Bool = false

    @Flag(name: .long, help: "Show repair commands for orphaned/broken items.")
    var showFixes: Bool = false

    func validate() throws {
        if let provider, let providerID, provider.lowercased() != providerID.lowercased() {
            throw ValidationError("Use either --provider or --provider-id, not both with different values.")
        }
    }
}

struct NolonWorkflowSyncCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "sync")

    @Option(name: .long)
    var source: String

    @Option(name: .long)
    var repositoriesRoot: String = NolonCoreCLIPathDefaults.repositoriesRootPath()

    @Option(name: .long)
    var pullStrategy: NolonGitPullStrategy = .ffOnly

    @Option(name: .long)
    var credentialStrategy: NolonGitCredentialStrategy = .automatic

    @Option(name: .long)
    var accessToken: String?
}

struct NolonWorkflowSearchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "search")

    @Argument(help: "Search keyword.")
    var keyword: String?

    @Option(name: .long)
    var query: String?

    @Option(name: .long)
    var limit: Int = 20

    @Option(name: .long)
    var baseURL: String = "https://clawdhub.com"

    @Flag(name: .long)
    var install: Bool = false

    @Option(name: .long)
    var provider: String?

    @Option(name: .long)
    var providerID: String?

    @Option(name: .long)
    var installMethod: NolonSkillInstallMethod = .symlink

    @Option(name: .long)
    var pick: Int?

    @Flag(name: .long)
    var dryRun: Bool = false

    @Flag(name: .long)
    var yes: Bool = false

    func validate() throws {
        if keyword != nil, query != nil {
            let positional = keyword ?? "<keyword>"
            let optionQuery = query ?? "<text>"
            throw ValidationError(
                """
                Conflicting query input: received positional <query> (\(positional)) and --query (\(optionQuery)).
                Use one form only.
                Examples:
                - nolon workflow search \(positional)
                - nolon workflow search --query \(optionQuery)
                """
            )
        }
        if let provider, let providerID, provider.lowercased() != providerID.lowercased() {
            throw ValidationError("Use either --provider or --provider-id, not both with different values.")
        }
        if !install, (pick != nil || dryRun || yes || provider != nil || providerID != nil) {
            throw ValidationError("--pick/--dry-run/--yes/--provider require --install.")
        }
        if install, !dryRun && !yes {
            throw ValidationError(
                """
                检测到写入操作。请先用 --dry-run 预览，确认后再加 --yes 执行。
                示例：
                - nolon workflow search <keyword> --install --dry-run
                - nolon workflow search <keyword> --install --yes --provider codex
                - nolon workflow search --query <text> --install --dry-run
                - nolon workflow search --query <text> --install --yes --provider codex
                """
            )
        }
    }
}

struct NolonWorkflowAddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add")

    @Argument(help: "Workflow slug.")
    var slug: String

    @Option(name: .long)
    var provider: String?

    @Option(name: .long)
    var providerID: String?

    @Option(name: .long)
    var version: String?

    @Option(name: .long)
    var baseURL: String = "https://clawdhub.com"

    @Option(name: .long)
    var installMethod: NolonSkillInstallMethod = .symlink

    @Option(name: .long)
    var repositoriesRoot: String = NolonCoreCLIPathDefaults.repositoriesRootPath()

    @Flag(name: .long)
    var dryRun: Bool = false
}

struct NolonWorkflowRemoveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove")

    @Option(name: .long)
    var resourceName: String

    @Option(name: .long)
    var targetPath: String?

    @Option(name: .long)
    var provider: String?

    @Option(name: .long)
    var providerID: String?

    func validate() throws {
        if let provider, let providerID, provider.lowercased() != providerID.lowercased() {
            throw ValidationError("Use either --provider or --provider-id, not both with different values.")
        }
        let selectorCount = [targetPath, provider ?? providerID]
            .compactMap { raw -> String? in
                guard let raw else { return nil }
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            .count
        if selectorCount == 0 {
            throw ValidationError("Missing required option: --target-path or --provider/--provider-id")
        }
        if selectorCount > 1 {
            throw ValidationError("Use only one target selector: --target-path or --provider/--provider-id")
        }
    }
}

private protocol NolonWorkflowProviderSelectorValidating {
    var targetPath: String? { get }
    var provider: String? { get }
    var providerID: String? { get }
}

private extension NolonWorkflowProviderSelectorValidating {
    func validateProviderSelector() throws {
        if let provider, let providerID, provider.lowercased() != providerID.lowercased() {
            throw ValidationError("Use either --provider or --provider-id, not both with different values.")
        }
        let selectorCount = [targetPath, provider ?? providerID]
            .compactMap { raw -> String? in
                guard let raw else { return nil }
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            .count
        if selectorCount == 0 {
            throw ValidationError("Missing required option: --target-path or --provider/--provider-id")
        }
        if selectorCount > 1 {
            throw ValidationError("Use only one target selector: --target-path or --provider/--provider-id")
        }
    }
}

struct NolonWorkflowBindSkillCommand: ParsableCommand, NolonWorkflowProviderSelectorValidating {
    static let configuration = CommandConfiguration(commandName: "bind-skill")

    @Option(name: .long)
    var skillID: String

    @Option(name: .long)
    var targetPath: String?

    @Option(name: .long)
    var provider: String?

    @Option(name: .long)
    var providerID: String?

    func validate() throws {
        try validateProviderSelector()
    }
}

struct NolonWorkflowBindMcpCommand: ParsableCommand, NolonWorkflowProviderSelectorValidating {
    static let configuration = CommandConfiguration(commandName: "bind-mcp")

    @Option(name: .long)
    var mcpName: String

    @Option(name: .long)
    var targetPath: String?

    @Option(name: .long)
    var provider: String?

    @Option(name: .long)
    var providerID: String?

    func validate() throws {
        try validateProviderSelector()
    }
}

struct NolonWorkflowUnbindSkillCommand: ParsableCommand, NolonWorkflowProviderSelectorValidating {
    static let configuration = CommandConfiguration(commandName: "unbind-skill")

    @Option(name: .long)
    var skillID: String

    @Option(name: .long)
    var targetPath: String?

    @Option(name: .long)
    var provider: String?

    @Option(name: .long)
    var providerID: String?

    func validate() throws {
        try validateProviderSelector()
    }
}

struct NolonWorkflowUnbindMcpCommand: ParsableCommand, NolonWorkflowProviderSelectorValidating {
    static let configuration = CommandConfiguration(commandName: "unbind-mcp")

    @Option(name: .long)
    var mcpName: String

    @Option(name: .long)
    var targetPath: String?

    @Option(name: .long)
    var provider: String?

    @Option(name: .long)
    var providerID: String?

    func validate() throws {
        try validateProviderSelector()
    }
}

struct NolonMcpRootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        subcommands: [
            NolonMcpListCommand.self,
            NolonMcpSyncCommand.self,
            NolonMcpSearchCommand.self,
            NolonMcpAddCommand.self,
            NolonMcpRemoveCommand.self,
            NolonMcpServerRootCommand.self,
            NolonMcpCacheRootCommand.self,
        ]
    )
}

struct NolonMcpListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list")

    @Option(name: .long, help: "Target provider ID. Omit only if you intend multi-provider distribution to all detected CLI providers.")
    var provider: String?

    @Option(name: .long, help: "Alias of --provider. Omit only if you intend multi-provider distribution to all detected CLI providers.")
    var providerID: String?

    @Flag(name: .long)
    var includeEmpty: Bool = false

    @Option(name: .long)
    var state: NolonProviderSkillStateKind?

    @Flag(name: .long, help: "Show full install path for each MCP item.")
    var verbose: Bool = false

    @Flag(name: .long, help: "Show repair commands for orphaned/broken items.")
    var showFixes: Bool = false

    func validate() throws {
        if let provider, let providerID, provider.lowercased() != providerID.lowercased() {
            throw ValidationError("Use either --provider or --provider-id, not both with different values.")
        }
    }
}

struct NolonMcpSyncCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "sync")

    @Option(name: .long)
    var source: String

    @Option(name: .long)
    var repositoriesRoot: String = NolonCoreCLIPathDefaults.repositoriesRootPath()

    @Option(name: .long)
    var pullStrategy: NolonGitPullStrategy = .ffOnly

    @Option(name: .long)
    var credentialStrategy: NolonGitCredentialStrategy = .automatic

    @Option(name: .long)
    var accessToken: String?
}

struct NolonMcpSearchCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "search")

    @Argument(help: "Search keyword.")
    var keyword: String?

    @Option(name: .long)
    var query: String?

    @Option(name: .long)
    var limit: Int = 20

    @Option(name: .long)
    var baseURL: String = "https://clawdhub.com"

    @Flag(name: .long)
    var install: Bool = false

    @Option(name: .long)
    var provider: String?

    @Option(name: .long)
    var providerID: String?

    @Option(name: .long)
    var installMethod: NolonSkillInstallMethod = .symlink

    @Option(name: .long)
    var pick: Int?

    @Flag(name: .long)
    var dryRun: Bool = false

    @Flag(name: .long)
    var yes: Bool = false

    func validate() throws {
        if keyword != nil, query != nil {
            let positional = keyword ?? "<keyword>"
            let optionQuery = query ?? "<text>"
            throw ValidationError(
                """
                Conflicting query input: received positional <query> (\(positional)) and --query (\(optionQuery)).
                Use one form only.
                Examples:
                - nolon mcp search \(positional)
                - nolon mcp search --query \(optionQuery)
                """
            )
        }
        if let provider, let providerID, provider.lowercased() != providerID.lowercased() {
            throw ValidationError("Use either --provider or --provider-id, not both with different values.")
        }
        if !install, (pick != nil || dryRun || yes || provider != nil || providerID != nil) {
            throw ValidationError("--pick/--dry-run/--yes/--provider require --install.")
        }
        if install, !dryRun && !yes {
            throw ValidationError(
                """
                检测到写入操作。请先用 --dry-run 预览，确认后再加 --yes 执行。
                示例：
                - nolon mcp search <keyword> --install --dry-run
                - nolon mcp search <keyword> --install --yes --provider codex
                - nolon mcp search --query <text> --install --dry-run
                - nolon mcp search --query <text> --install --yes --provider codex
                """
            )
        }
    }
}

struct NolonMcpAddCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "add")

    @Argument(help: "MCP slug.")
    var slug: String

    @Option(name: .long)
    var provider: String?

    @Option(name: .long)
    var providerID: String?

    @Option(name: .long)
    var version: String?

    @Option(name: .long)
    var baseURL: String = "https://clawdhub.com"

    @Option(name: .long)
    var installMethod: NolonSkillInstallMethod = .symlink

    @Option(name: .long)
    var repositoriesRoot: String = NolonCoreCLIPathDefaults.repositoriesRootPath()

    @Flag(name: .long)
    var dryRun: Bool = false
}

struct NolonMcpRemoveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "remove")

    @Option(name: .long)
    var resourceName: String

    @Option(name: .long)
    var targetPath: String?

    @Option(name: .long)
    var provider: String?

    @Option(name: .long)
    var providerID: String?

    func validate() throws {
        if let provider, let providerID, provider.lowercased() != providerID.lowercased() {
            throw ValidationError("Use either --provider or --provider-id, not both with different values.")
        }
        let selectorCount = [targetPath, provider ?? providerID]
            .compactMap { raw -> String? in
                guard let raw else { return nil }
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            .count
        if selectorCount == 0 {
            throw ValidationError("Missing required option: --target-path or --provider/--provider-id")
        }
        if selectorCount > 1 {
            throw ValidationError("Use only one target selector: --target-path or --provider/--provider-id")
        }
    }
}

private protocol NolonMcpProviderRequiredValidating {
    var provider: String? { get }
    var providerID: String? { get }
}

private extension NolonMcpProviderRequiredValidating {
    func validateProviderRequired() throws -> String {
        if let provider, let providerID, provider.lowercased() != providerID.lowercased() {
            throw ValidationError("Use either --provider or --provider-id, not both with different values.")
        }
        let resolved = (provider ?? providerID)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !resolved.isEmpty else {
            throw ValidationError("Missing required option: --provider or --provider-id")
        }
        return resolved
    }
}

struct NolonMcpServerRootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "server",
        subcommands: [
            NolonMcpServerListCommand.self,
            NolonMcpServerSetEnabledCommand.self,
            NolonMcpServerUpsertCommand.self,
            NolonMcpServerRemoveCommand.self,
        ]
    )
}

struct NolonMcpServerListCommand: ParsableCommand, NolonMcpProviderRequiredValidating {
    static let configuration = CommandConfiguration(commandName: "list")

    @Option(name: .long)
    var provider: String?

    @Option(name: .long)
    var providerID: String?

    func validate() throws {
        _ = try validateProviderRequired()
    }
}

struct NolonMcpServerSetEnabledCommand: ParsableCommand, NolonMcpProviderRequiredValidating {
    static let configuration = CommandConfiguration(commandName: "set-enabled")

    @Option(name: .long)
    var provider: String?

    @Option(name: .long)
    var providerID: String?

    @Option(name: .long)
    var name: String

    @Flag(name: .long)
    var enabled: Bool = false

    @Flag(name: .long)
    var disabled: Bool = false

    func validate() throws {
        _ = try validateProviderRequired()
        if enabled == disabled {
            throw ValidationError("Use exactly one flag: --enabled or --disabled")
        }
    }
}

struct NolonMcpServerUpsertCommand: ParsableCommand, NolonMcpProviderRequiredValidating {
    static let configuration = CommandConfiguration(commandName: "upsert")

    @Option(name: .long)
    var provider: String?

    @Option(name: .long)
    var providerID: String?

    @Option(name: .long)
    var name: String

    @Option(name: .long)
    var url: String?

    @Option(name: .long)
    var command: String?

    @Option(name: .customLong("arg"), parsing: .upToNextOption)
    var args: [String] = []

    @Option(name: .customLong("env"), parsing: .upToNextOption)
    var env: [String] = []

    @Flag(name: .long)
    var enabled: Bool = false

    @Flag(name: .long)
    var disabled: Bool = false

    func validate() throws {
        _ = try validateProviderRequired()
        if enabled && disabled {
            throw ValidationError("Use only one flag: --enabled or --disabled")
        }
        for pair in env {
            let parts = pair.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2, !parts[0].isEmpty else {
                throw ValidationError("Invalid --env assignment: \(pair). Expected KEY=VALUE")
            }
        }
    }
}

struct NolonMcpServerRemoveCommand: ParsableCommand, NolonMcpProviderRequiredValidating {
    static let configuration = CommandConfiguration(commandName: "remove")

    @Option(name: .long)
    var provider: String?

    @Option(name: .long)
    var providerID: String?

    @Option(name: .long)
    var name: String

    func validate() throws {
        _ = try validateProviderRequired()
    }
}

struct NolonMcpCacheRootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cache",
        subcommands: [
            NolonMcpCacheMigrateCommand.self,
            NolonMcpCacheStatusCommand.self,
        ]
    )
}

struct NolonMcpCacheMigrateCommand: ParsableCommand, NolonMcpProviderRequiredValidating {
    static let configuration = CommandConfiguration(commandName: "migrate")

    @Option(name: .long)
    var provider: String?

    @Option(name: .long)
    var providerID: String?

    @Flag(name: .long)
    var overwrite: Bool = false

    func validate() throws {
        _ = try validateProviderRequired()
    }
}

struct NolonMcpCacheStatusCommand: ParsableCommand, NolonMcpProviderRequiredValidating {
    static let configuration = CommandConfiguration(commandName: "status")

    @Option(name: .long)
    var provider: String?

    @Option(name: .long)
    var providerID: String?

    @Option(name: .long)
    var name: String?

    func validate() throws {
        _ = try validateProviderRequired()
    }
}

struct NolonPluginRootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "plugin",
        subcommands: [
            NolonPluginListCommand.self,
            NolonPluginStatusCommand.self,
            NolonPluginInstallCommand.self,
            NolonPluginUninstallCommand.self,
            NolonPluginUpgradeCommand.self,
            NolonPluginStartCommand.self,
            NolonPluginStopCommand.self,
        ]
    )
}

private protocol NolonPluginNameValidating {
    var name: String { get }
}

private extension NolonPluginNameValidating {
    func validatePluginName() throws {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized != "xcodemcpkit" {
            throw ValidationError("Unsupported plugin name: \(name). Supported: xcodemcpkit")
        }
    }
}

struct NolonPluginListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list")
}

struct NolonPluginStatusCommand: ParsableCommand, NolonPluginNameValidating {
    static let configuration = CommandConfiguration(commandName: "status")

    @Option(name: .long)
    var name: String = "xcodemcpkit"

    func validate() throws {
        try validatePluginName()
    }
}

struct NolonPluginInstallCommand: ParsableCommand, NolonPluginNameValidating {
    static let configuration = CommandConfiguration(commandName: "install")

    @Option(name: .long)
    var name: String = "xcodemcpkit"

    @Option(name: .long)
    var provider: String = "codex"

    @Option(name: .long)
    var version: String?

    @Flag(name: .long)
    var force: Bool = false

    func validate() throws {
        try validatePluginName()
    }
}

struct NolonPluginUninstallCommand: ParsableCommand, NolonPluginNameValidating {
    static let configuration = CommandConfiguration(commandName: "uninstall")

    @Option(name: .long)
    var name: String = "xcodemcpkit"

    @Option(name: .long)
    var provider: String = "codex"

    @Flag(name: .long)
    var force: Bool = false

    func validate() throws {
        try validatePluginName()
    }
}

struct NolonPluginUpgradeCommand: ParsableCommand, NolonPluginNameValidating {
    static let configuration = CommandConfiguration(commandName: "upgrade")

    @Option(name: .long)
    var name: String = "xcodemcpkit"

    @Option(name: .long)
    var provider: String = "codex"

    @Option(name: .customLong("to-version"))
    var toVersion: String?

    @Flag(name: .long)
    var force: Bool = false

    func validate() throws {
        try validatePluginName()
    }
}

struct NolonPluginStartCommand: ParsableCommand, NolonPluginNameValidating {
    static let configuration = CommandConfiguration(commandName: "start")

    @Option(name: .long)
    var name: String = "xcodemcpkit"

    @Flag(name: .customLong("force-restart"))
    var forceRestart: Bool = false

    func validate() throws {
        try validatePluginName()
    }
}

struct NolonPluginStopCommand: ParsableCommand, NolonPluginNameValidating {
    static let configuration = CommandConfiguration(commandName: "stop")

    @Option(name: .long)
    var name: String = "xcodemcpkit"

    @Flag(name: .long)
    var force: Bool = false

    func validate() throws {
        try validatePluginName()
    }
}

struct NolonRemoteRootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remote",
        subcommands: [
            NolonRemoteListCommand.self,
            NolonRemoteDownloadCommand.self,
            NolonRemoteSyncCommand.self,
            NolonRemoteInstallCommand.self,
            NolonRemoteSyncInstallCommand.self,
        ]
    )
}

struct NolonRemoteListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list")

    @Option(name: .long)
    var kind: NolonRemoteCatalogKind

    @Option(name: .long)
    var query: String?

    @Option(name: .long)
    var limit: Int = 20

    @Option(name: .long)
    var baseURL: String = "https://clawdhub.com"
}

struct NolonRemoteDownloadCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "download")

    @Option(name: .long)
    var kind: NolonRemoteCatalogKind

    @Option(name: .long)
    var slug: String

    @Option(name: .long)
    var version: String?

    @Option(name: .long)
    var baseURL: String = "https://clawdhub.com"
}

struct NolonRemoteSyncCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "sync")

    @Option(name: .long)
    var source: String

    @Option(name: .long)
    var repositoriesRoot: String

    @Option(name: .long)
    var accessToken: String?

    @Option(name: .long)
    var pullStrategy: NolonGitPullStrategy = .ffOnly

    @Option(name: .long)
    var credentialStrategy: NolonGitCredentialStrategy = .automatic

    @Option(name: .long)
    var maxDepth: Int = 5
}

struct NolonRemoteInstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install")

    @Option(name: .long)
    var kind: NolonRemoteCatalogKind

    @Option(name: .long)
    var slug: String

    @Option(name: .long)
    var version: String?

    @Option(name: .long)
    var baseURL: String = "https://clawdhub.com"

    @Option(name: .long)
    var providerPath: String?

    @Option(name: .long)
    var providerID: String?

    @Option(name: .long)
    var targetPath: String?

    @Option(name: .long)
    var resourceName: String?

    @Option(name: .long)
    var installMethod: NolonSkillInstallMethod = .symlink

    @Option(name: .long)
    var skillID: String?

    func validate() throws {
        switch kind {
        case .skill:
            if providerPath == nil && providerID == nil {
                throw ValidationError("Missing required option: --provider-path or --provider-id")
            }
            if providerPath != nil && providerID != nil {
                throw ValidationError("Use only one target selector: --provider-path or --provider-id")
            }
        case .workflow, .mcp:
            if targetPath == nil && providerID == nil {
                throw ValidationError("Missing required option: --target-path or --provider-id")
            }
            if targetPath != nil && providerID != nil {
                throw ValidationError("Use only one target selector: --target-path or --provider-id")
            }
        }
    }
}

struct NolonRemoteSyncInstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "sync-install")

    @Option(name: .long)
    var kind: NolonRemoteCatalogKind

    @Option(name: .long)
    var source: String

    @Option(name: .long)
    var repositoriesRoot: String

    @Option(name: .long)
    var accessToken: String?

    @Option(name: .long)
    var pullStrategy: NolonGitPullStrategy = .ffOnly

    @Option(name: .long)
    var credentialStrategy: NolonGitCredentialStrategy = .automatic

    @Option(name: .long)
    var maxDepth: Int = 5

    @Option(name: .long)
    var path: String?

    @Option(name: .long)
    var slug: String?

    @Option(name: .long)
    var strictSelector: Bool = false

    @Option(name: .long)
    var providerPath: String?

    @Option(name: .long)
    var providerID: String?

    @Option(name: .long)
    var targetPath: String?

    @Option(name: .long)
    var resourceName: String?

    @Option(name: .long)
    var installMethod: NolonSkillInstallMethod = .symlink

    @Option(name: .long)
    var skillID: String?

    func validate() throws {
        if path == nil && slug == nil {
            throw ValidationError("Missing required option: --path or --slug")
        }
        if path != nil && slug != nil {
            throw ValidationError("Use only one selector: --path or --slug")
        }
        switch kind {
        case .skill:
            if providerPath == nil && providerID == nil {
                throw ValidationError("Missing required option: --provider-path or --provider-id")
            }
            if providerPath != nil && providerID != nil {
                throw ValidationError("Use only one target selector: --provider-path or --provider-id")
            }
        case .workflow, .mcp:
            if targetPath == nil && providerID == nil {
                throw ValidationError("Missing required option: --target-path or --provider-id")
            }
            if targetPath != nil && providerID != nil {
                throw ValidationError("Use only one target selector: --target-path or --provider-id")
            }
        }
    }
}

enum NolonCoreCLIArgumentParser {
    static func parse(_ arguments: [String]) throws -> NolonCoreCLICommand {
        let parsed: any ParsableCommand
        do {
            parsed = try NolonRootCommand.parseAsRoot(arguments)
        } catch {
            let message = NolonRootCommand.message(for: error)
            throw NolonCoreCLIError.invalidArguments(message)
        }

        switch parsed {
        case let command as NolonSkillsListCommand:
            return .skillsList(
                provider: command.provider ?? command.providerID,
                includeEmpty: command.includeEmpty,
                state: command.state,
                verbose: command.verbose,
                showFixes: command.showFixes
            )
        case let command as NolonSkillsSyncCommand:
            return .skillsRepoSync(
                source: command.source,
                repositoriesRoot: command.repositoriesRoot,
                accessToken: command.accessToken,
                pullStrategy: command.pullStrategy,
                credentialStrategy: command.credentialStrategy
            )
        case let command as NolonSkillsRepoListCommand:
            return .skillsRepoList(
                repositoriesRoot: command.repositoriesRoot,
                maxDepth: command.maxDepth,
                verbose: command.verbose
            )
        case let command as NolonSkillsRepoPlanCommand:
            return .skillsRepoPlan(
                source: command.source,
                repositoriesRoot: command.repositoriesRoot,
                pullStrategy: command.pullStrategy,
                credentialStrategy: command.credentialStrategy,
                accessToken: command.accessToken
            )
        case let command as NolonSkillsRepoPreflightCommand:
            return .skillsRepoPreflight(
                source: command.source,
                pullStrategy: command.pullStrategy,
                credentialStrategy: command.credentialStrategy,
                accessToken: command.accessToken
            )
        case let command as NolonSkillsRepoSyncCommand:
            return .skillsRepoSync(
                source: command.source,
                repositoriesRoot: command.repositoriesRoot,
                accessToken: command.accessToken,
                pullStrategy: command.pullStrategy,
                credentialStrategy: command.credentialStrategy
            )
        case let command as NolonSkillsSearchCommand:
            return .skillsSearch(
                query: command.query ?? command.keyword,
                limit: command.limit,
                baseURL: command.baseURL,
                install: command.install,
                provider: command.provider ?? command.providerID,
                installMethod: command.installMethod,
                pick: command.pick,
                dryRun: command.dryRun,
                assumeYes: command.yes
            )
        case let command as NolonSkillsAddCommand:
            return .skillsAdd(
                slug: command.slug,
                provider: command.provider ?? command.providerID,
                version: command.version,
                baseURL: command.baseURL,
                installMethod: command.installMethod,
                repositoriesRoot: command.repositoriesRoot,
                dryRun: command.dryRun
            )
        case let command as NolonSkillsDiscoverCommand:
            return .skillsDiscover(path: command.path, maxDepth: command.maxDepth)
        case let command as NolonSkillsParseCommand:
            return .skillsParse(file: command.file, directoryName: command.directoryName)
        case let command as NolonSkillsInstallCommand:
            return .skillsInstall(
                skillPath: command.skillPath,
                skillID: command.skillID,
                providerPath: command.providerPath,
                installMethod: command.installMethod
            )
        case let command as NolonSkillsUninstallCommand:
            return .skillsUninstall(skillID: command.skillID, providerPath: command.providerPath)
        case let command as NolonSkillsRemoveCommand:
            let providerPath = try resolveSkillProviderPath(
                explicitProviderPath: command.providerPath,
                providerID: command.provider ?? command.providerID
            )
            return .skillsUninstall(skillID: command.skillID, providerPath: providerPath)
        case let command as NolonSkillsMigrateScanCommand:
            return .skillsMigrateScan(
                providerPath: command.providerPath,
                globalSkillsPath: command.globalSkillsPath
            )
        case let command as NolonSkillsMigrateApplyCommand:
            return .skillsMigrateApply(
                skillID: command.skillID,
                providerPath: command.providerPath,
                globalSkillsPath: command.globalSkillsPath,
                installMethod: command.installMethod
            )
        case let command as NolonWorkflowListCommand:
            return .workflowList(
                provider: command.provider ?? command.providerID,
                includeEmpty: command.includeEmpty,
                state: command.state,
                verbose: command.verbose,
                showFixes: command.showFixes
            )
        case let command as NolonWorkflowSyncCommand:
            return .workflowSync(
                source: command.source,
                repositoriesRoot: command.repositoriesRoot,
                accessToken: command.accessToken,
                pullStrategy: command.pullStrategy,
                credentialStrategy: command.credentialStrategy
            )
        case let command as NolonWorkflowSearchCommand:
            return .workflowSearch(
                query: command.query ?? command.keyword,
                limit: command.limit,
                baseURL: command.baseURL,
                install: command.install,
                provider: command.provider ?? command.providerID,
                installMethod: command.installMethod,
                pick: command.pick,
                dryRun: command.dryRun,
                assumeYes: command.yes
            )
        case let command as NolonWorkflowAddCommand:
            return .workflowAdd(
                slug: command.slug,
                provider: command.provider ?? command.providerID,
                version: command.version,
                baseURL: command.baseURL,
                installMethod: command.installMethod,
                repositoriesRoot: command.repositoriesRoot,
                dryRun: command.dryRun
            )
        case let command as NolonWorkflowRemoveCommand:
            let targetPath = try resolveResourceTargetPath(
                kind: .workflow,
                explicitTargetPath: command.targetPath,
                providerID: command.provider ?? command.providerID
            )
            return .workflowRemove(resourceName: command.resourceName, targetPath: targetPath)
        case let command as NolonWorkflowBindSkillCommand:
            let targetPath = try resolveResourceTargetPath(
                kind: .workflow,
                explicitTargetPath: command.targetPath,
                providerID: command.provider ?? command.providerID
            )
            return .workflowBindSkill(skillID: command.skillID, targetPath: targetPath)
        case let command as NolonWorkflowBindMcpCommand:
            let targetPath = try resolveResourceTargetPath(
                kind: .workflow,
                explicitTargetPath: command.targetPath,
                providerID: command.provider ?? command.providerID
            )
            return .workflowBindMcp(mcpName: command.mcpName, targetPath: targetPath)
        case let command as NolonWorkflowUnbindSkillCommand:
            let targetPath = try resolveResourceTargetPath(
                kind: .workflow,
                explicitTargetPath: command.targetPath,
                providerID: command.provider ?? command.providerID
            )
            return .workflowUnbindSkill(skillID: command.skillID, targetPath: targetPath)
        case let command as NolonWorkflowUnbindMcpCommand:
            let targetPath = try resolveResourceTargetPath(
                kind: .workflow,
                explicitTargetPath: command.targetPath,
                providerID: command.provider ?? command.providerID
            )
            return .workflowUnbindMcp(mcpName: command.mcpName, targetPath: targetPath)
        case let command as NolonMcpListCommand:
            return .mcpList(
                provider: command.provider ?? command.providerID,
                includeEmpty: command.includeEmpty,
                state: command.state,
                verbose: command.verbose,
                showFixes: command.showFixes
            )
        case let command as NolonMcpSyncCommand:
            return .mcpSync(
                source: command.source,
                repositoriesRoot: command.repositoriesRoot,
                accessToken: command.accessToken,
                pullStrategy: command.pullStrategy,
                credentialStrategy: command.credentialStrategy
            )
        case let command as NolonMcpSearchCommand:
            return .mcpSearch(
                query: command.query ?? command.keyword,
                limit: command.limit,
                baseURL: command.baseURL,
                install: command.install,
                provider: command.provider ?? command.providerID,
                installMethod: command.installMethod,
                pick: command.pick,
                dryRun: command.dryRun,
                assumeYes: command.yes
            )
        case let command as NolonMcpAddCommand:
            return .mcpAdd(
                slug: command.slug,
                provider: command.provider ?? command.providerID,
                version: command.version,
                baseURL: command.baseURL,
                installMethod: command.installMethod,
                repositoriesRoot: command.repositoriesRoot,
                dryRun: command.dryRun
            )
        case let command as NolonMcpRemoveCommand:
            let targetPath = try resolveResourceTargetPath(
                kind: .mcp,
                explicitTargetPath: command.targetPath,
                providerID: command.provider ?? command.providerID
            )
            return .mcpRemove(resourceName: command.resourceName, targetPath: targetPath)
        case let command as NolonMcpServerListCommand:
            return .mcpServerList(provider: command.provider ?? command.providerID ?? "")
        case let command as NolonMcpServerSetEnabledCommand:
            return .mcpServerSetEnabled(
                provider: command.provider ?? command.providerID ?? "",
                name: command.name,
                enabled: command.enabled
            )
        case let command as NolonMcpServerUpsertCommand:
            let env = try parseEnvAssignments(command.env)
            let enabled: Bool?
            if command.enabled {
                enabled = true
            } else if command.disabled {
                enabled = false
            } else {
                enabled = nil
            }
            return .mcpServerUpsert(
                provider: command.provider ?? command.providerID ?? "",
                name: command.name,
                url: command.url,
                command: command.command,
                args: command.args,
                env: env,
                enabled: enabled
            )
        case let command as NolonMcpServerRemoveCommand:
            return .mcpServerRemove(
                provider: command.provider ?? command.providerID ?? "",
                name: command.name
            )
        case let command as NolonMcpCacheMigrateCommand:
            return .mcpCacheMigrate(
                provider: command.provider ?? command.providerID ?? "",
                overwrite: command.overwrite
            )
        case let command as NolonMcpCacheStatusCommand:
            return .mcpCacheStatus(
                provider: command.provider ?? command.providerID ?? "",
                name: command.name
            )
        case is NolonPluginListCommand:
            return .pluginList
        case let command as NolonPluginStatusCommand:
            return .pluginStatus(name: command.name)
        case let command as NolonPluginInstallCommand:
            return .pluginInstall(
                name: command.name,
                provider: command.provider,
                version: command.version,
                force: command.force
            )
        case let command as NolonPluginUninstallCommand:
            return .pluginUninstall(
                name: command.name,
                provider: command.provider,
                force: command.force
            )
        case let command as NolonPluginUpgradeCommand:
            return .pluginUpgrade(
                name: command.name,
                provider: command.provider,
                toVersion: command.toVersion,
                force: command.force
            )
        case let command as NolonPluginStartCommand:
            return .pluginStart(
                name: command.name,
                forceRestart: command.forceRestart
            )
        case let command as NolonPluginStopCommand:
            return .pluginStop(
                name: command.name,
                force: command.force
            )
        case let command as NolonRemoteListCommand:
            return .remoteList(
                kind: command.kind,
                query: command.query,
                limit: command.limit,
                baseURL: command.baseURL
            )
        case let command as NolonRemoteDownloadCommand:
            return .remoteDownload(
                kind: command.kind,
                slug: command.slug,
                version: command.version,
                baseURL: command.baseURL
            )
        case let command as NolonRemoteSyncCommand:
            return .remoteSync(
                source: command.source,
                repositoriesRoot: command.repositoriesRoot,
                accessToken: command.accessToken,
                pullStrategy: command.pullStrategy,
                credentialStrategy: command.credentialStrategy,
                maxDepth: command.maxDepth
            )
        case let command as NolonRemoteInstallCommand:
            switch command.kind {
            case .skill:
                return .remoteInstallSkill(
                    slug: command.slug,
                    version: command.version,
                    baseURL: command.baseURL,
                    providerPath: command.providerPath,
                    providerID: command.providerID,
                    installMethod: command.installMethod,
                    skillID: command.skillID
                )
            case .workflow, .mcp:
                let resourceKind: NolonResourceKind = command.kind == .workflow ? .workflow : .mcp
                return .remoteInstallResource(
                    kind: resourceKind,
                    slug: command.slug,
                    version: command.version,
                    baseURL: command.baseURL,
                    targetPath: command.targetPath,
                    providerID: command.providerID,
                    installMethod: command.installMethod,
                    resourceName: command.resourceName
                )
            }
        case let command as NolonRemoteSyncInstallCommand:
            switch command.kind {
            case .skill:
                return .remoteSyncInstallSkill(
                    source: command.source,
                    repositoriesRoot: command.repositoriesRoot,
                    accessToken: command.accessToken,
                    pullStrategy: command.pullStrategy,
                    credentialStrategy: command.credentialStrategy,
                    maxDepth: command.maxDepth,
                    path: command.path,
                    slug: command.slug,
                    strictSelector: command.strictSelector,
                    providerPath: command.providerPath,
                    providerID: command.providerID,
                    installMethod: command.installMethod,
                    skillID: command.skillID
                )
            case .workflow, .mcp:
                let resourceKind: NolonResourceKind = command.kind == .workflow ? .workflow : .mcp
                return .remoteSyncInstallResource(
                    kind: resourceKind,
                    source: command.source,
                    repositoriesRoot: command.repositoriesRoot,
                    accessToken: command.accessToken,
                    pullStrategy: command.pullStrategy,
                    credentialStrategy: command.credentialStrategy,
                    maxDepth: command.maxDepth,
                    path: command.path,
                    slug: command.slug,
                    strictSelector: command.strictSelector,
                    targetPath: command.targetPath,
                    providerID: command.providerID,
                    installMethod: command.installMethod,
                    resourceName: command.resourceName
                )
            }
        case is NolonSkillsRepoGroupCommand:
            throw NolonCoreCLIError.invalidArguments("Missing command. Expected: skills repo <action> ...")
        case is NolonSkillsMigrateGroupCommand:
            throw NolonCoreCLIError.invalidArguments("Missing command. Expected: skills migrate <action> ...")
        case is NolonPluginRootCommand:
            throw NolonCoreCLIError.invalidArguments("Missing command. Expected: plugin <action> ...")
        default:
            throw NolonCoreCLIError.invalidArguments("Unsupported parsed command type: \(type(of: parsed))")
        }
    }
}

private func resolveSkillProviderPath(
    explicitProviderPath: String?,
    providerID: String?
) throws -> String {
    if let explicitProviderPath, !explicitProviderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return explicitProviderPath
    }
    guard let providerID, !providerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw NolonCoreCLIError.invalidArguments("Missing required option: --provider-path or --provider/--provider-id")
    }
    guard let template = ProviderTemplate.resolve(providerID: providerID) else {
        throw NolonCoreCLIError.invalidArguments("Unsupported --provider: \(providerID)")
    }
    return template.defaultSkillsPath.path
}

private func resolveResourceTargetPath(
    kind: NolonResourceKind,
    explicitTargetPath: String?,
    providerID: String?
) throws -> String {
    if let explicitTargetPath, !explicitTargetPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        return explicitTargetPath
    }
    guard let providerID, !providerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw NolonCoreCLIError.invalidArguments("Missing required option: --target-path or --provider/--provider-id")
    }
    guard let template = ProviderTemplate.resolve(providerID: providerID) else {
        throw NolonCoreCLIError.invalidArguments("Unsupported --provider: \(providerID)")
    }
    switch kind {
    case .workflow:
        return template.defaultCommandPath?.path ?? template.defaultWorkflowPath.path
    case .mcp:
        return template.defaultMcpConfigPath.deletingLastPathComponent().path
    }
}

private func parseEnvAssignments(_ values: [String]) throws -> [String: String] {
    var env: [String: String] = [:]
    for value in values {
        let parts = value.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else {
            throw NolonCoreCLIError.invalidArguments("Invalid --env assignment: \(value). Expected KEY=VALUE")
        }
        let key = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else {
            throw NolonCoreCLIError.invalidArguments("Invalid --env assignment: \(value). Key cannot be empty")
        }
        env[key] = String(parts[1])
    }
    return env
}

struct NolonSkillsRemoveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove one installed skill from provider.",
        discussion: """
        注意: 该操作会直接移除 provider 下的技能链接/目录，请先用 `nolon skills list --provider <id>` 确认 skill-id。
        Examples:
          nolon skills remove --skill-id xcode --provider codex
        """
    )

    @Option(name: .long, help: "Exact skill id (slug).")
    var skillID: String

    @Option(name: .long, help: "Explicit provider skills path.")
    var providerPath: String?

    @Option(name: .long, help: "Provider ID (recommended).")
    var provider: String?

    @Option(name: .long, help: "Alias of --provider.")
    var providerID: String?

    func validate() throws {
        if let provider, let providerID,
           provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
           != providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            throw ValidationError("Use either --provider or --provider-id, not both with different values.")
        }

        let selectorCount = [providerPath, provider ?? providerID]
            .compactMap { raw -> String? in
                guard let raw else { return nil }
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                return trimmed.isEmpty ? nil : trimmed
            }
            .count
        if selectorCount == 0 {
            throw ValidationError("Missing required option: --provider-path or --provider/--provider-id")
        }
        if selectorCount > 1 {
            throw ValidationError("Use only one target selector: --provider-path or --provider/--provider-id")
        }
    }
}
