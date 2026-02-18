import ArgumentParser
import Foundation

extension NolonGitPullStrategy: ExpressibleByArgument {}
extension NolonGitCredentialStrategy: ExpressibleByArgument {}
extension NolonSkillInstallMethod: ExpressibleByArgument {}
extension NolonRemoteCatalogKind: ExpressibleByArgument {}

struct NolonSkillsRootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "skills",
        subcommands: [
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
        subcommands: [
            NolonSkillsRepoPlanCommand.self,
            NolonSkillsRepoPreflightCommand.self,
            NolonSkillsRepoSyncCommand.self,
        ]
    )
}

struct NolonSkillsMigrateGroupCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "migrate",
        subcommands: [
            NolonSkillsMigrateScanCommand.self,
            NolonSkillsMigrateApplyCommand.self,
        ]
    )
}

struct NolonSkillsRepoPlanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "plan")

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

struct NolonSkillsRepoPreflightCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "preflight")

    @Option(name: .long)
    var source: String

    @Option(name: .long)
    var pullStrategy: NolonGitPullStrategy = .ffOnly

    @Option(name: .long)
    var credentialStrategy: NolonGitCredentialStrategy = .automatic

    @Option(name: .long)
    var accessToken: String?
}

struct NolonSkillsRepoSyncCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "sync")

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

struct NolonSkillsDiscoverCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "discover")

    @Option(name: .long)
    var path: String

    @Option(name: .long)
    var maxDepth: Int = 5
}

struct NolonSkillsParseCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "parse")

    @Option(name: .long)
    var file: String

    @Option(name: .long)
    var directoryName: String?
}

struct NolonSkillsInstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install")

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
    static let configuration = CommandConfiguration(commandName: "uninstall")

    @Option(name: .long)
    var skillID: String

    @Option(name: .long)
    var providerPath: String
}

struct NolonSkillsMigrateScanCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "scan")

    @Option(name: .long)
    var providerPath: String

    @Option(name: .long)
    var globalSkillsPath: String
}

struct NolonSkillsMigrateApplyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "apply")

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
            NolonWorkflowDiscoverCommand.self,
            NolonWorkflowInstallCommand.self,
            NolonWorkflowUninstallCommand.self,
        ]
    )
}

struct NolonWorkflowDiscoverCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "discover")

    @Option(name: .long)
    var path: String

    @Option(name: .long)
    var maxDepth: Int = 5
}

struct NolonWorkflowInstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install")

    @Option(name: .long)
    var filePath: String

    @Option(name: .long)
    var targetPath: String

    @Option(name: .long)
    var resourceName: String?

    @Option(name: .long)
    var installMethod: NolonSkillInstallMethod = .symlink
}

struct NolonWorkflowUninstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "uninstall")

    @Option(name: .long)
    var resourceName: String

    @Option(name: .long)
    var targetPath: String
}

struct NolonMcpRootCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "mcp",
        subcommands: [
            NolonMcpDiscoverCommand.self,
            NolonMcpInstallCommand.self,
            NolonMcpUninstallCommand.self,
        ]
    )
}

struct NolonMcpDiscoverCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "discover")

    @Option(name: .long)
    var path: String

    @Option(name: .long)
    var maxDepth: Int = 5
}

struct NolonMcpInstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install")

    @Option(name: .long)
    var filePath: String

    @Option(name: .long)
    var targetPath: String

    @Option(name: .long)
    var resourceName: String?

    @Option(name: .long)
    var installMethod: NolonSkillInstallMethod = .symlink
}

struct NolonMcpUninstallCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "uninstall")

    @Option(name: .long)
    var resourceName: String

    @Option(name: .long)
    var targetPath: String
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
        case let command as NolonWorkflowDiscoverCommand:
            return .workflowDiscover(path: command.path, maxDepth: command.maxDepth)
        case let command as NolonWorkflowInstallCommand:
            return .workflowInstall(
                filePath: command.filePath,
                resourceName: command.resourceName,
                targetPath: command.targetPath,
                installMethod: command.installMethod
            )
        case let command as NolonWorkflowUninstallCommand:
            return .workflowUninstall(resourceName: command.resourceName, targetPath: command.targetPath)
        case let command as NolonMcpDiscoverCommand:
            return .mcpDiscover(path: command.path, maxDepth: command.maxDepth)
        case let command as NolonMcpInstallCommand:
            return .mcpInstall(
                filePath: command.filePath,
                resourceName: command.resourceName,
                targetPath: command.targetPath,
                installMethod: command.installMethod
            )
        case let command as NolonMcpUninstallCommand:
            return .mcpUninstall(resourceName: command.resourceName, targetPath: command.targetPath)
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
        default:
            throw NolonCoreCLIError.invalidArguments("Unsupported parsed command type: \(type(of: parsed))")
        }
    }
}
