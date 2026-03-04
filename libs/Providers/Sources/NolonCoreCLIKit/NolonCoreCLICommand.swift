import Foundation
import ProviderCatalog

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

public enum NolonCoreCLICommand: Sendable, Equatable {
    case skillsRepoPlan(
        source: String,
        repositoriesRoot: String,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy,
        accessToken: String?
    )
    case skillsRepoPreflight(
        source: String,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy,
        accessToken: String?
    )
    case skillsRepoList(
        repositoriesRoot: String,
        maxDepth: Int,
        verbose: Bool
    )
    case skillsList(
        provider: String?,
        includeEmpty: Bool,
        state: NolonProviderSkillStateKind?,
        verbose: Bool,
        showFixes: Bool
    )
    case skillsRepoSync(
        source: String,
        repositoriesRoot: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    )
    case skillsSearch(
        query: String?,
        limit: Int,
        baseURL: String,
        install: Bool,
        provider: String?,
        installMethod: NolonSkillInstallMethod,
        pick: Int?,
        dryRun: Bool,
        assumeYes: Bool
    )
    case skillsAdd(
        slug: String,
        provider: String?,
        version: String?,
        baseURL: String,
        installMethod: NolonSkillInstallMethod,
        repositoriesRoot: String,
        dryRun: Bool
    )
    case skillsInstall(
        skillPath: String,
        skillID: String?,
        providerPath: String,
        installMethod: NolonSkillInstallMethod
    )
    case skillsUninstall(
        skillID: String,
        providerPath: String
    )
    case skillsMigrateScan(
        providerPath: String,
        globalSkillsPath: String
    )
    case skillsMigrateApply(
        skillID: String,
        providerPath: String,
        globalSkillsPath: String,
        installMethod: NolonSkillInstallMethod
    )
    case skillsDiscover(path: String, maxDepth: Int)
    case skillsParse(file: String, directoryName: String?)
    case workflowDiscover(path: String, maxDepth: Int)
    case workflowList(
        provider: String?,
        includeEmpty: Bool,
        state: NolonProviderSkillStateKind?,
        verbose: Bool,
        showFixes: Bool
    )
    case workflowSearch(
        query: String?,
        limit: Int,
        baseURL: String,
        install: Bool,
        provider: String?,
        installMethod: NolonSkillInstallMethod,
        pick: Int?,
        dryRun: Bool,
        assumeYes: Bool
    )
    case workflowAdd(
        slug: String,
        provider: String?,
        version: String?,
        baseURL: String,
        installMethod: NolonSkillInstallMethod,
        repositoriesRoot: String,
        dryRun: Bool
    )
    case workflowRemove(
        resourceName: String,
        targetPath: String
    )
    case workflowBindSkill(
        skillID: String,
        targetPath: String
    )
    case workflowBindMcp(
        mcpName: String,
        targetPath: String
    )
    case workflowUnbindSkill(
        skillID: String,
        targetPath: String
    )
    case workflowUnbindMcp(
        mcpName: String,
        targetPath: String
    )
    case workflowSync(
        source: String,
        repositoriesRoot: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    )
    case workflowInstall(
        filePath: String,
        resourceName: String?,
        targetPath: String,
        installMethod: NolonSkillInstallMethod
    )
    case workflowUninstall(
        resourceName: String,
        targetPath: String
    )
    case mcpDiscover(path: String, maxDepth: Int)
    case mcpList(
        provider: String?,
        includeEmpty: Bool,
        state: NolonProviderSkillStateKind?,
        verbose: Bool,
        showFixes: Bool
    )
    case mcpSearch(
        query: String?,
        limit: Int,
        baseURL: String,
        install: Bool,
        provider: String?,
        installMethod: NolonSkillInstallMethod,
        pick: Int?,
        dryRun: Bool,
        assumeYes: Bool
    )
    case mcpAdd(
        slug: String,
        provider: String?,
        version: String?,
        baseURL: String,
        installMethod: NolonSkillInstallMethod,
        repositoriesRoot: String,
        dryRun: Bool
    )
    case mcpRemove(
        resourceName: String,
        targetPath: String
    )
    case mcpServerList(
        provider: String
    )
    case mcpServerSetEnabled(
        provider: String,
        name: String,
        enabled: Bool
    )
    case mcpServerUpsert(
        provider: String,
        name: String,
        url: String?,
        command: String?,
        args: [String],
        env: [String: String],
        enabled: Bool?
    )
    case mcpServerRemove(
        provider: String,
        name: String
    )
    case mcpCacheMigrate(
        provider: String,
        overwrite: Bool
    )
    case mcpCacheStatus(
        provider: String,
        name: String?
    )
    case mcpSync(
        source: String,
        repositoriesRoot: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    )
    case mcpInstall(
        filePath: String,
        resourceName: String?,
        targetPath: String,
        installMethod: NolonSkillInstallMethod
    )
    case mcpUninstall(
        resourceName: String,
        targetPath: String
    )
    case pluginList
    case pluginStatus(name: String)
    case pluginInstall(
        name: String,
        provider: String,
        version: String?,
        force: Bool
    )
    case pluginUninstall(
        name: String,
        provider: String,
        force: Bool
    )
    case pluginUpgrade(
        name: String,
        provider: String,
        toVersion: String?,
        force: Bool
    )
    case pluginStart(
        name: String,
        forceRestart: Bool
    )
    case pluginStop(
        name: String,
        force: Bool
    )
    case remoteList(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    )
    case remoteDownload(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    )
    case remoteSync(
        source: String,
        repositoriesRoot: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy,
        maxDepth: Int
    )
    case remoteInstallSkill(
        slug: String,
        version: String?,
        baseURL: String,
        providerPath: String?,
        providerID: String?,
        installMethod: NolonSkillInstallMethod,
        skillID: String?
    )
    case remoteInstallResource(
        kind: NolonResourceKind,
        slug: String,
        version: String?,
        baseURL: String,
        targetPath: String?,
        providerID: String?,
        installMethod: NolonSkillInstallMethod,
        resourceName: String?
    )
    case remoteSyncInstallSkill(
        source: String,
        repositoriesRoot: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy,
        maxDepth: Int,
        path: String?,
        slug: String?,
        strictSelector: Bool,
        providerPath: String?,
        providerID: String?,
        installMethod: NolonSkillInstallMethod,
        skillID: String?
    )
    case remoteSyncInstallResource(
        kind: NolonResourceKind,
        source: String,
        repositoriesRoot: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy,
        maxDepth: Int,
        path: String?,
        slug: String?,
        strictSelector: Bool,
        targetPath: String?,
        providerID: String?,
        installMethod: NolonSkillInstallMethod,
        resourceName: String?
    )

    var commandID: String {
        switch self {
        case .skillsRepoPlan: "skills.repo.plan"
        case .skillsRepoPreflight: "skills.repo.preflight"
        case .skillsRepoList: "skills.repo.list"
        case .skillsList: "skills.list"
        case .skillsRepoSync: "skills.repo.sync"
        case .skillsSearch: "skills.search"
        case .skillsAdd: "skills.add"
        case .skillsInstall: "skills.install"
        case .skillsUninstall: "skills.uninstall"
        case .skillsMigrateScan: "skills.migrate.scan"
        case .skillsMigrateApply: "skills.migrate.apply"
        case .skillsDiscover: "skills.discover"
        case .skillsParse: "skills.parse"
        case .workflowDiscover: "workflow.discover"
        case .workflowList: "workflow.list"
        case .workflowSearch: "workflow.search"
        case .workflowAdd: "workflow.add"
        case .workflowRemove: "workflow.remove"
        case .workflowBindSkill: "workflow.bind-skill"
        case .workflowBindMcp: "workflow.bind-mcp"
        case .workflowUnbindSkill: "workflow.unbind-skill"
        case .workflowUnbindMcp: "workflow.unbind-mcp"
        case .workflowSync: "workflow.sync"
        case .workflowInstall: "workflow.install"
        case .workflowUninstall: "workflow.uninstall"
        case .mcpDiscover: "mcp.discover"
        case .mcpList: "mcp.list"
        case .mcpSearch: "mcp.search"
        case .mcpAdd: "mcp.add"
        case .mcpRemove: "mcp.remove"
        case .mcpServerList: "mcp.server.list"
        case .mcpServerSetEnabled: "mcp.server.set-enabled"
        case .mcpServerUpsert: "mcp.server.upsert"
        case .mcpServerRemove: "mcp.server.remove"
        case .mcpCacheMigrate: "mcp.cache.migrate"
        case .mcpCacheStatus: "mcp.cache.status"
        case .mcpSync: "mcp.sync"
        case .mcpInstall: "mcp.install"
        case .mcpUninstall: "mcp.uninstall"
        case .pluginList: "plugin.list"
        case .pluginStatus: "plugin.status"
        case .pluginInstall: "plugin.install"
        case .pluginUninstall: "plugin.uninstall"
        case .pluginUpgrade: "plugin.upgrade"
        case .pluginStart: "plugin.start"
        case .pluginStop: "plugin.stop"
        case .remoteList: "remote.list"
        case .remoteDownload: "remote.download"
        case .remoteSync: "remote.sync"
        case .remoteInstallSkill, .remoteInstallResource: "remote.install"
        case .remoteSyncInstallSkill, .remoteSyncInstallResource: "remote.sync-install"
        }
    }
}

public enum NolonCoreCLIError: LocalizedError, Equatable, Sendable {
    case invalidArguments(String)
    case executionFailed(String)
    case domainFailed(code: String, message: String)
    case syncFailed(code: String, message: String, detail: NolonGitSyncErrorDetail)

    public var errorDescription: String? {
        switch self {
        case let .invalidArguments(message):
            message
        case let .executionFailed(message):
            message
        case let .domainFailed(_, message):
            message
        case let .syncFailed(_, message, _):
            message
        }
    }

    var code: String {
        switch self {
        case .invalidArguments: "invalid_arguments"
        case .executionFailed: "execution_failed"
        case let .domainFailed(code, _): code
        case let .syncFailed(code, _, _): code
        }
    }

    var detail: NolonGitSyncErrorDetail? {
        switch self {
        case .invalidArguments, .executionFailed, .domainFailed:
            return nil
        case let .syncFailed(_, _, detail):
            return detail
        }
    }
}

public enum NolonCoreCLICommandParser {
    public static func parse(_ arguments: [String]) throws -> NolonCoreCLICommand {
        guard arguments.count >= 2 else {
            throw NolonCoreCLIError.invalidArguments("Missing command. Expected: skills|workflow|mcp|plugin|remote ...")
        }

        let command = arguments[0]
        if command == "skills" {
            if arguments[1] == "list" {
                let source = Array(arguments.dropFirst(2))
                let provider = readOption("--provider", in: source) ?? readOption("--provider-id", in: source)
                let includeEmpty = source.contains("--include-empty")
                let state = readOption("--state", in: source).flatMap { NolonProviderSkillStateKind(rawValue: $0) }
                let verbose = source.contains("--verbose")
                let showFixes = source.contains("--show-fixes")
                if readOption("--state", in: source) != nil, state == nil {
                    throw NolonCoreCLIError.invalidArguments("Invalid --state. Supported: installed|orphaned|broken")
                }
                return .skillsList(
                    provider: provider,
                    includeEmpty: includeEmpty,
                    state: state,
                    verbose: verbose,
                    showFixes: showFixes
                )
            }

            if arguments[1] == "sync" {
                let options = Array(arguments.dropFirst(2))
                let source = try readRequiredOption("--source", in: options)
                let repositoriesRoot = readOption("--repositories-root", in: options)
                    ?? NolonCoreCLIPathDefaults.repositoriesRootPath()
                let accessToken = readOption("--access-token", in: options)
                let pullStrategy = try parsePullStrategy(readOption("--pull-strategy", in: options) ?? "ff-only")
                let credentialStrategy = try parseCredentialStrategy(
                    readOption("--credential-strategy", in: options) ?? "automatic"
                )
                return .skillsRepoSync(
                    source: source,
                    repositoriesRoot: repositoriesRoot,
                    accessToken: accessToken,
                    pullStrategy: pullStrategy,
                    credentialStrategy: credentialStrategy
                )
            }

            if arguments[1] == "repo" {
                return try parseSkillsRepo(Array(arguments.dropFirst(2)))
            }
            if arguments[1] == "migrate" {
                return try parseSkillsMigrate(Array(arguments.dropFirst(2)))
            }

            if arguments[1] == "discover" {
                let source = Array(arguments.dropFirst(2))
                let path = try readRequiredOption("--path", in: source)
                let maxDepth = Int(readOption("--max-depth", in: source) ?? "5") ?? 5
                return .skillsDiscover(path: path, maxDepth: maxDepth)
            }

            if arguments[1] == "search" {
                let source = Array(arguments.dropFirst(2))
                let valueOptions: Set<String> = [
                    "--query", "--limit", "--base-url", "--provider", "--provider-id", "--install-method",
                ]
                let positionalQuery = source.enumerated().first { index, token in
                    guard !token.hasPrefix("-") else { return false }
                    guard index > 0 else { return true }
                    return !valueOptions.contains(source[index - 1])
                }?.element
                let optionQuery = readOption("--query", in: source)
                if let positionalQuery, let optionQuery {
                    throw NolonCoreCLIError.invalidArguments(
                        """
                        Conflicting query input: received positional <query> (\(positionalQuery)) and --query (\(optionQuery)).
                        Use one form only.
                        Examples:
                        - nolon skills search \(positionalQuery)
                        - nolon skills search --query \(optionQuery)
                        """
                    )
                }
                let query = optionQuery ?? positionalQuery
                let limit = Int(readOption("--limit", in: source) ?? "20") ?? 20
                guard limit > 0 else {
                    throw NolonCoreCLIError.invalidArguments("--limit must be greater than 0; received \(limit). Try --limit 10.")
                }
                guard limit <= 200 else {
                    throw NolonCoreCLIError.invalidArguments("--limit must be less than or equal to 200.")
                }
                let baseURL = readOption("--base-url", in: source) ?? "https://clawdhub.com"
                let install = source.contains("--install")
                let assumeYes = source.contains("--yes")
                let provider = readOption("--provider", in: source)
                let providerID = readOption("--provider-id", in: source)
                let pick = readOption("--pick", in: source).flatMap { Int($0) }
                if let provider, let providerID,
                   provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                   != providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                    throw NolonCoreCLIError.invalidArguments("Use either --provider or --provider-id, not both with different values.")
                }
                let installMethod = try parseInstallMethod(readOption("--install-method", in: source) ?? "symlink")
                let dryRun = source.contains("--dry-run")
                if !install {
                    if provider != nil || providerID != nil {
                        throw NolonCoreCLIError.invalidArguments("--provider requires --install.")
                    }
                    if installMethod != .symlink {
                        throw NolonCoreCLIError.invalidArguments("--install-method requires --install.")
                    }
                    if dryRun {
                        throw NolonCoreCLIError.invalidArguments("--dry-run requires --install.")
                    }
                    if assumeYes {
                        throw NolonCoreCLIError.invalidArguments("--yes requires --install.")
                    }
                    if pick != nil {
                        throw NolonCoreCLIError.invalidArguments("--pick requires --install.")
                    }
                } else if !dryRun && !assumeYes {
                    throw NolonCoreCLIError.invalidArguments(
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
                    throw NolonCoreCLIError.invalidArguments("--pick must be greater than 0; received \(pick).")
                }
                return .skillsSearch(
                    query: query,
                    limit: limit,
                    baseURL: baseURL,
                    install: install,
                    provider: provider ?? providerID,
                    installMethod: installMethod,
                    pick: pick,
                    dryRun: dryRun,
                    assumeYes: assumeYes
                )
            }

            if arguments[1] == "add" {
                let source = Array(arguments.dropFirst(2))
                guard let slug = source.first(where: { !$0.hasPrefix("-") }), !slug.isEmpty else {
                    throw NolonCoreCLIError.invalidArguments("Missing required argument: <slug>")
                }
                let provider = readOption("--provider", in: source)
                let providerID = readOption("--provider-id", in: source)
                if let provider, let providerID,
                   provider.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                   != providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
                    throw NolonCoreCLIError.invalidArguments("Use either --provider or --provider-id, not both with different values.")
                }
                let version = readOption("--version", in: source)
                let baseURL = readOption("--base-url", in: source) ?? "https://clawdhub.com"
                let installMethod = try parseInstallMethod(readOption("--install-method", in: source) ?? "symlink")
                let repositoriesRoot = readOption("--repositories-root", in: source)
                    ?? NolonCoreCLIPathDefaults.repositoriesRootPath()
                return .skillsAdd(
                    slug: slug,
                    provider: provider ?? providerID,
                    version: version,
                    baseURL: baseURL,
                    installMethod: installMethod,
                    repositoriesRoot: repositoriesRoot,
                    dryRun: source.contains("--dry-run")
                )
            }

            if arguments[1] == "parse" {
                let source = Array(arguments.dropFirst(2))
                let file = try readRequiredOption("--file", in: source)
                let directoryName = readOption("--directory-name", in: source)
                return .skillsParse(file: file, directoryName: directoryName)
            }

            if arguments[1] == "install" {
                let source = Array(arguments.dropFirst(2))
                let skillPath = try readRequiredOption("--skill-path", in: source)
                let providerPath = try readRequiredOption("--provider-path", in: source)
                let skillID = readOption("--skill-id", in: source)
                let installMethod = try parseInstallMethod(readOption("--install-method", in: source) ?? "symlink")
                return .skillsInstall(
                    skillPath: skillPath,
                    skillID: skillID,
                    providerPath: providerPath,
                    installMethod: installMethod
                )
            }

            if arguments[1] == "uninstall" {
                let source = Array(arguments.dropFirst(2))
                let skillID = try readRequiredOption("--skill-id", in: source)
                let providerPath = try readRequiredOption("--provider-path", in: source)
                return .skillsUninstall(skillID: skillID, providerPath: providerPath)
            }

            if arguments[1] == "remove" {
                let source = Array(arguments.dropFirst(2))
                let skillID = try readRequiredOption("--skill-id", in: source)
                let providerPath: String
                if let explicitPath = readOption("--provider-path", in: source),
                   !explicitPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    providerPath = explicitPath
                } else {
                    let provider = readOption("--provider", in: source) ?? readOption("--provider-id", in: source)
                    guard let provider, !provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                        throw NolonCoreCLIError.invalidArguments("Missing required option: --provider-path or --provider/--provider-id")
                    }
                    guard let template = ProviderTemplate.resolve(providerID: provider) else {
                        throw NolonCoreCLIError.invalidArguments("Unsupported --provider: \(provider)")
                    }
                    providerPath = template.defaultSkillsPath.path
                }
                return .skillsUninstall(skillID: skillID, providerPath: providerPath)
            }

            throw NolonCoreCLIError.invalidArguments("Unsupported skills subcommand: \(arguments[1])")
        }

        if command == "workflow" {
            return try parseWorkflow(Array(arguments.dropFirst(1)))
        }

        if command == "mcp" {
            return try parseMcp(Array(arguments.dropFirst(1)))
        }

        if command == "plugin" {
            return try parsePlugin(Array(arguments.dropFirst(1)))
        }

        if command == "remote" {
            return try parseRemote(Array(arguments.dropFirst(1)))
        }

        throw NolonCoreCLIError.invalidArguments("Unsupported command root: \(command). Expected: skills|workflow|mcp|plugin|remote")
    }

    private static func parseSkillsRepo(_ arguments: [String]) throws -> NolonCoreCLICommand {
        guard let action = arguments.first else {
            throw NolonCoreCLIError.invalidArguments("Missing skills repo action: plan|preflight|list|sync")
        }
        let options = Array(arguments.dropFirst())

        if action == "list" {
            let repositoriesRoot = try readRequiredOption("--repositories-root", in: options)
            let maxDepth = Int(readOption("--max-depth", in: options) ?? "5") ?? 5
            let verbose = options.contains("--verbose")
            return .skillsRepoList(repositoriesRoot: repositoriesRoot, maxDepth: maxDepth, verbose: verbose)
        }

        let source = try readRequiredOption("--source", in: options)

        if action == "plan" {
            let repositoriesRoot = try readRequiredOption("--repositories-root", in: options)
            let accessToken = readOption("--access-token", in: options)
            let pullStrategy = try parsePullStrategy(readOption("--pull-strategy", in: options) ?? "ff-only")
            let credentialStrategy = try parseCredentialStrategy(
                readOption("--credential-strategy", in: options) ?? "automatic"
            )
            return .skillsRepoPlan(
                source: source,
                repositoriesRoot: repositoriesRoot,
                pullStrategy: pullStrategy,
                credentialStrategy: credentialStrategy,
                accessToken: accessToken
            )
        }

        if action == "preflight" {
            let accessToken = readOption("--access-token", in: options)
            let pullStrategy = try parsePullStrategy(readOption("--pull-strategy", in: options) ?? "ff-only")
            let credentialStrategy = try parseCredentialStrategy(
                readOption("--credential-strategy", in: options) ?? "automatic"
            )
            return .skillsRepoPreflight(
                source: source,
                pullStrategy: pullStrategy,
                credentialStrategy: credentialStrategy,
                accessToken: accessToken
            )
        }

        if action == "sync" {
            let repositoriesRoot = try readRequiredOption("--repositories-root", in: options)
            let accessToken = readOption("--access-token", in: options)
            let pullStrategy = try parsePullStrategy(readOption("--pull-strategy", in: options) ?? "ff-only")
            let credentialStrategy = try parseCredentialStrategy(
                readOption("--credential-strategy", in: options) ?? "automatic"
            )
            return .skillsRepoSync(
                source: source,
                repositoriesRoot: repositoriesRoot,
                accessToken: accessToken,
                pullStrategy: pullStrategy,
                credentialStrategy: credentialStrategy
            )
        }

        throw NolonCoreCLIError.invalidArguments("Unsupported skills repo action: \(action)")
    }

    private static func parseSkillsMigrate(_ arguments: [String]) throws -> NolonCoreCLICommand {
        guard let action = arguments.first else {
            throw NolonCoreCLIError.invalidArguments("Missing skills migrate action: scan|apply")
        }
        let options = Array(arguments.dropFirst())
        if action == "scan" {
            let providerPath = try readRequiredOption("--provider-path", in: options)
            let globalSkillsPath = try readRequiredOption("--global-skills-path", in: options)
            return .skillsMigrateScan(providerPath: providerPath, globalSkillsPath: globalSkillsPath)
        }
        if action == "apply" {
            let skillID = try readRequiredOption("--skill-id", in: options)
            let providerPath = try readRequiredOption("--provider-path", in: options)
            let globalSkillsPath = try readRequiredOption("--global-skills-path", in: options)
            let installMethod = try parseInstallMethod(readOption("--install-method", in: options) ?? "symlink")
            return .skillsMigrateApply(
                skillID: skillID,
                providerPath: providerPath,
                globalSkillsPath: globalSkillsPath,
                installMethod: installMethod
            )
        }
        throw NolonCoreCLIError.invalidArguments("Unsupported skills migrate action: \(action)")
    }

    private static func parseWorkflow(_ arguments: [String]) throws -> NolonCoreCLICommand {
        guard let action = arguments.first else {
            throw NolonCoreCLIError.invalidArguments("Missing workflow action: list|search|add|remove|bind-skill|bind-mcp|unbind-skill|unbind-mcp|sync")
        }
        let options = Array(arguments.dropFirst())
        if action == "list" {
            let provider = readOption("--provider", in: options) ?? readOption("--provider-id", in: options)
            let includeEmpty = readFlag("--include-empty", in: options)
            let state = try parseStateKind(readOption("--state", in: options))
            let verbose = readFlag("--verbose", in: options)
            let showFixes = readFlag("--show-fixes", in: options)
            return .workflowList(
                provider: provider,
                includeEmpty: includeEmpty,
                state: state,
                verbose: verbose,
                showFixes: showFixes
            )
        }
        if action == "search" {
            let query = readOption("--query", in: options) ?? arguments.dropFirst(1).first
            let limit = Int(readOption("--limit", in: options) ?? "20") ?? 20
            let baseURL = readOption("--base-url", in: options) ?? "https://clawdhub.com"
            let install = readFlag("--install", in: options)
            let provider = readOption("--provider", in: options) ?? readOption("--provider-id", in: options)
            let installMethod = try parseInstallMethod(readOption("--install-method", in: options) ?? "symlink")
            let pick = readOption("--pick", in: options).flatMap(Int.init)
            let dryRun = readFlag("--dry-run", in: options)
            let yes = readFlag("--yes", in: options)
            return .workflowSearch(
                query: query,
                limit: limit,
                baseURL: baseURL,
                install: install,
                provider: provider,
                installMethod: installMethod,
                pick: pick,
                dryRun: dryRun,
                assumeYes: yes
            )
        }
        if action == "add" {
            guard let slug = options.first, !slug.hasPrefix("--") else {
                throw NolonCoreCLIError.invalidArguments("Missing required argument: <slug>")
            }
            let provider = readOption("--provider", in: options) ?? readOption("--provider-id", in: options)
            let version = readOption("--version", in: options)
            let baseURL = readOption("--base-url", in: options) ?? "https://clawdhub.com"
            let installMethod = try parseInstallMethod(readOption("--install-method", in: options) ?? "symlink")
            let repositoriesRoot = readOption("--repositories-root", in: options) ?? NolonCoreCLIPathDefaults.repositoriesRootPath()
            let dryRun = readFlag("--dry-run", in: options)
            return .workflowAdd(
                slug: slug,
                provider: provider,
                version: version,
                baseURL: baseURL,
                installMethod: installMethod,
                repositoriesRoot: repositoriesRoot,
                dryRun: dryRun
            )
        }
        if action == "remove" {
            let resourceName = try readRequiredOption("--resource-name", in: options)
            if let explicit = readOption("--target-path", in: options), !explicit.isEmpty {
                return .workflowRemove(resourceName: resourceName, targetPath: explicit)
            }
            throw NolonCoreCLIError.invalidArguments("Missing required option: --target-path")
        }
        if action == "bind-skill" {
            let skillID = try readRequiredOption("--skill-id", in: options)
            if let explicit = readOption("--target-path", in: options), !explicit.isEmpty {
                return .workflowBindSkill(skillID: skillID, targetPath: explicit)
            }
            throw NolonCoreCLIError.invalidArguments("Missing required option: --target-path")
        }
        if action == "bind-mcp" {
            let mcpName = try readRequiredOption("--mcp-name", in: options)
            if let explicit = readOption("--target-path", in: options), !explicit.isEmpty {
                return .workflowBindMcp(mcpName: mcpName, targetPath: explicit)
            }
            throw NolonCoreCLIError.invalidArguments("Missing required option: --target-path")
        }
        if action == "unbind-skill" {
            let skillID = try readRequiredOption("--skill-id", in: options)
            if let explicit = readOption("--target-path", in: options), !explicit.isEmpty {
                return .workflowUnbindSkill(skillID: skillID, targetPath: explicit)
            }
            throw NolonCoreCLIError.invalidArguments("Missing required option: --target-path")
        }
        if action == "unbind-mcp" {
            let mcpName = try readRequiredOption("--mcp-name", in: options)
            if let explicit = readOption("--target-path", in: options), !explicit.isEmpty {
                return .workflowUnbindMcp(mcpName: mcpName, targetPath: explicit)
            }
            throw NolonCoreCLIError.invalidArguments("Missing required option: --target-path")
        }
        if action == "sync" {
            let source = try readRequiredOption("--source", in: options)
            let repositoriesRoot = readOption("--repositories-root", in: options) ?? NolonCoreCLIPathDefaults.repositoriesRootPath()
            let accessToken = readOption("--access-token", in: options)
            let pullStrategy = try parsePullStrategy(readOption("--pull-strategy", in: options) ?? "ff-only")
            let credentialStrategy = try parseCredentialStrategy(readOption("--credential-strategy", in: options) ?? "automatic")
            return .workflowSync(
                source: source,
                repositoriesRoot: repositoriesRoot,
                accessToken: accessToken,
                pullStrategy: pullStrategy,
                credentialStrategy: credentialStrategy
            )
        }
        throw NolonCoreCLIError.invalidArguments("Unsupported workflow action: \(action). Expected: list|search|add|remove|bind-skill|bind-mcp|unbind-skill|unbind-mcp|sync")
    }

    private static func parseMcp(_ arguments: [String]) throws -> NolonCoreCLICommand {
        guard let action = arguments.first else {
            throw NolonCoreCLIError.invalidArguments("Missing mcp action: list|search|add|remove|server|cache|sync")
        }
        let options = Array(arguments.dropFirst())
        if action == "server" {
            guard let sub = options.first else {
                throw NolonCoreCLIError.invalidArguments("Missing mcp server action: list|set-enabled|upsert|remove")
            }
            let subOptions = Array(options.dropFirst())
            let provider = try readRequiredOption("--provider", in: subOptions)
            if sub == "list" {
                return .mcpServerList(provider: provider)
            }
            if sub == "set-enabled" {
                let name = try readRequiredOption("--name", in: subOptions)
                let enabledFlag = readFlag("--enabled", in: subOptions)
                let disabledFlag = readFlag("--disabled", in: subOptions)
                if enabledFlag == disabledFlag {
                    throw NolonCoreCLIError.invalidArguments("Use exactly one flag: --enabled or --disabled")
                }
                return .mcpServerSetEnabled(provider: provider, name: name, enabled: enabledFlag)
            }
            if sub == "upsert" {
                let name = try readRequiredOption("--name", in: subOptions)
                let url = readOption("--url", in: subOptions)
                let command = readOption("--command", in: subOptions)
                let args = readMultiOption("--arg", in: subOptions)
                let env = try parseEnvAssignments(readMultiOption("--env", in: subOptions))
                let enabledFlag = readFlag("--enabled", in: subOptions)
                let disabledFlag = readFlag("--disabled", in: subOptions)
                let enabled: Bool?
                if enabledFlag && disabledFlag {
                    throw NolonCoreCLIError.invalidArguments("Use only one flag: --enabled or --disabled")
                } else if enabledFlag {
                    enabled = true
                } else if disabledFlag {
                    enabled = false
                } else {
                    enabled = nil
                }
                return .mcpServerUpsert(
                    provider: provider,
                    name: name,
                    url: url,
                    command: command,
                    args: args,
                    env: env,
                    enabled: enabled
                )
            }
            if sub == "remove" {
                let name = try readRequiredOption("--name", in: subOptions)
                return .mcpServerRemove(provider: provider, name: name)
            }
            throw NolonCoreCLIError.invalidArguments("Unsupported mcp server action: \(sub). Expected: list|set-enabled|upsert|remove")
        }
        if action == "cache" {
            guard let sub = options.first else {
                throw NolonCoreCLIError.invalidArguments("Missing mcp cache action: migrate|status")
            }
            let subOptions = Array(options.dropFirst())
            let provider = try readRequiredOption("--provider", in: subOptions)
            if sub == "migrate" {
                let overwrite = readFlag("--overwrite", in: subOptions)
                return .mcpCacheMigrate(provider: provider, overwrite: overwrite)
            }
            if sub == "status" {
                let name = readOption("--name", in: subOptions)
                return .mcpCacheStatus(provider: provider, name: name)
            }
            throw NolonCoreCLIError.invalidArguments("Unsupported mcp cache action: \(sub). Expected: migrate|status")
        }
        if action == "list" {
            let provider = readOption("--provider", in: options) ?? readOption("--provider-id", in: options)
            let includeEmpty = readFlag("--include-empty", in: options)
            let state = try parseStateKind(readOption("--state", in: options))
            let verbose = readFlag("--verbose", in: options)
            let showFixes = readFlag("--show-fixes", in: options)
            return .mcpList(
                provider: provider,
                includeEmpty: includeEmpty,
                state: state,
                verbose: verbose,
                showFixes: showFixes
            )
        }
        if action == "search" {
            let query = readOption("--query", in: options) ?? arguments.dropFirst(1).first
            let limit = Int(readOption("--limit", in: options) ?? "20") ?? 20
            let baseURL = readOption("--base-url", in: options) ?? "https://clawdhub.com"
            let install = readFlag("--install", in: options)
            let provider = readOption("--provider", in: options) ?? readOption("--provider-id", in: options)
            let installMethod = try parseInstallMethod(readOption("--install-method", in: options) ?? "symlink")
            let pick = readOption("--pick", in: options).flatMap(Int.init)
            let dryRun = readFlag("--dry-run", in: options)
            let yes = readFlag("--yes", in: options)
            return .mcpSearch(
                query: query,
                limit: limit,
                baseURL: baseURL,
                install: install,
                provider: provider,
                installMethod: installMethod,
                pick: pick,
                dryRun: dryRun,
                assumeYes: yes
            )
        }
        if action == "add" {
            guard let slug = options.first, !slug.hasPrefix("--") else {
                throw NolonCoreCLIError.invalidArguments("Missing required argument: <slug>")
            }
            let provider = readOption("--provider", in: options) ?? readOption("--provider-id", in: options)
            let version = readOption("--version", in: options)
            let baseURL = readOption("--base-url", in: options) ?? "https://clawdhub.com"
            let installMethod = try parseInstallMethod(readOption("--install-method", in: options) ?? "symlink")
            let repositoriesRoot = readOption("--repositories-root", in: options) ?? NolonCoreCLIPathDefaults.repositoriesRootPath()
            let dryRun = readFlag("--dry-run", in: options)
            return .mcpAdd(
                slug: slug,
                provider: provider,
                version: version,
                baseURL: baseURL,
                installMethod: installMethod,
                repositoriesRoot: repositoriesRoot,
                dryRun: dryRun
            )
        }
        if action == "remove" {
            let resourceName = try readRequiredOption("--resource-name", in: options)
            if let explicit = readOption("--target-path", in: options), !explicit.isEmpty {
                return .mcpRemove(resourceName: resourceName, targetPath: explicit)
            }
            throw NolonCoreCLIError.invalidArguments("Missing required option: --target-path")
        }
        if action == "sync" {
            let source = try readRequiredOption("--source", in: options)
            let repositoriesRoot = readOption("--repositories-root", in: options) ?? NolonCoreCLIPathDefaults.repositoriesRootPath()
            let accessToken = readOption("--access-token", in: options)
            let pullStrategy = try parsePullStrategy(readOption("--pull-strategy", in: options) ?? "ff-only")
            let credentialStrategy = try parseCredentialStrategy(readOption("--credential-strategy", in: options) ?? "automatic")
            return .mcpSync(
                source: source,
                repositoriesRoot: repositoriesRoot,
                accessToken: accessToken,
                pullStrategy: pullStrategy,
                credentialStrategy: credentialStrategy
            )
        }
        throw NolonCoreCLIError.invalidArguments("Unsupported mcp action: \(action). Expected: list|search|add|remove|server|cache|sync")
    }

    private static func parsePlugin(_ arguments: [String]) throws -> NolonCoreCLICommand {
        guard let action = arguments.first else {
            throw NolonCoreCLIError.invalidArguments("Missing command. Expected: plugin <action> ...")
        }

        let options = Array(arguments.dropFirst())
        switch action {
        case "list":
            return .pluginList
        case "status":
            return .pluginStatus(name: readOption("--name", in: options) ?? "xcodemcpkit")
        case "install":
            return .pluginInstall(
                name: readOption("--name", in: options) ?? "xcodemcpkit",
                provider: readOption("--provider", in: options) ?? "codex",
                version: readOption("--version", in: options),
                force: readFlag("--force", in: options)
            )
        case "uninstall":
            return .pluginUninstall(
                name: readOption("--name", in: options) ?? "xcodemcpkit",
                provider: readOption("--provider", in: options) ?? "codex",
                force: readFlag("--force", in: options)
            )
        case "upgrade":
            return .pluginUpgrade(
                name: readOption("--name", in: options) ?? "xcodemcpkit",
                provider: readOption("--provider", in: options) ?? "codex",
                toVersion: readOption("--to-version", in: options),
                force: readFlag("--force", in: options)
            )
        case "start":
            return .pluginStart(
                name: readOption("--name", in: options) ?? "xcodemcpkit",
                forceRestart: readFlag("--force-restart", in: options)
            )
        case "stop":
            return .pluginStop(
                name: readOption("--name", in: options) ?? "xcodemcpkit",
                force: readFlag("--force", in: options)
            )
        default:
            throw NolonCoreCLIError.invalidArguments(
                "Unsupported plugin action: \(action). Expected: list|status|install|uninstall|upgrade|start|stop"
            )
        }
    }

    private static func parseRemote(_ arguments: [String]) throws -> NolonCoreCLICommand {
        guard let action = arguments.first else {
            throw NolonCoreCLIError.invalidArguments("Missing remote action: list|download|sync|install|sync-install")
        }
        let options = Array(arguments.dropFirst())
        if action == "list" {
            let kind = try parseRemoteKind(try readRequiredOption("--kind", in: options))
            let query = readOption("--query", in: options)
            let limit = Int(readOption("--limit", in: options) ?? "20") ?? 20
            let baseURL = readOption("--base-url", in: options) ?? "https://clawdhub.com"
            return .remoteList(kind: kind, query: query, limit: limit, baseURL: baseURL)
        }
        if action == "download" {
            let kind = try parseRemoteKind(try readRequiredOption("--kind", in: options))
            let slug = try readRequiredOption("--slug", in: options)
            let version = readOption("--version", in: options)
            let baseURL = readOption("--base-url", in: options) ?? "https://clawdhub.com"
            return .remoteDownload(kind: kind, slug: slug, version: version, baseURL: baseURL)
        }
        if action == "sync" {
            let source = try readRequiredOption("--source", in: options)
            let repositoriesRoot = try readRequiredOption("--repositories-root", in: options)
            let accessToken = readOption("--access-token", in: options)
            let pullStrategy = try parsePullStrategy(readOption("--pull-strategy", in: options) ?? "ff-only")
            let credentialStrategy = try parseCredentialStrategy(
                readOption("--credential-strategy", in: options) ?? "automatic"
            )
            let maxDepth = Int(readOption("--max-depth", in: options) ?? "5") ?? 5
            return .remoteSync(
                source: source,
                repositoriesRoot: repositoriesRoot,
                accessToken: accessToken,
                pullStrategy: pullStrategy,
                credentialStrategy: credentialStrategy,
                maxDepth: maxDepth
            )
        }
        if action == "install" {
            let kind = try parseRemoteKind(try readRequiredOption("--kind", in: options))
            let slug = try readRequiredOption("--slug", in: options)
            let version = readOption("--version", in: options)
            let baseURL = readOption("--base-url", in: options) ?? "https://clawdhub.com"
            let installMethod = try parseInstallMethod(readOption("--install-method", in: options) ?? "symlink")
            let providerID = readOption("--provider-id", in: options)
            switch kind {
            case .skill:
                let providerPath = readOption("--provider-path", in: options)
                if providerPath == nil && providerID == nil {
                    throw NolonCoreCLIError.invalidArguments("Missing required option: --provider-path or --provider-id")
                }
                let skillID = readOption("--skill-id", in: options)
                return .remoteInstallSkill(
                    slug: slug,
                    version: version,
                    baseURL: baseURL,
                    providerPath: providerPath,
                    providerID: providerID,
                    installMethod: installMethod,
                    skillID: skillID
                )
            case .workflow, .mcp:
                let targetPath = readOption("--target-path", in: options)
                if targetPath == nil && providerID == nil {
                    throw NolonCoreCLIError.invalidArguments("Missing required option: --target-path or --provider-id")
                }
                let resourceName = readOption("--resource-name", in: options)
                let resourceKind: NolonResourceKind = kind == .workflow ? .workflow : .mcp
                return .remoteInstallResource(
                    kind: resourceKind,
                    slug: slug,
                    version: version,
                    baseURL: baseURL,
                    targetPath: targetPath,
                    providerID: providerID,
                    installMethod: installMethod,
                    resourceName: resourceName
                )
            }
        }
        if action == "sync-install" {
            let kind = try parseRemoteKind(try readRequiredOption("--kind", in: options))
            let source = try readRequiredOption("--source", in: options)
            let repositoriesRoot = try readRequiredOption("--repositories-root", in: options)
            let accessToken = readOption("--access-token", in: options)
            let pullStrategy = try parsePullStrategy(readOption("--pull-strategy", in: options) ?? "ff-only")
            let credentialStrategy = try parseCredentialStrategy(
                readOption("--credential-strategy", in: options) ?? "automatic"
            )
            let maxDepth = Int(readOption("--max-depth", in: options) ?? "5") ?? 5
            let path = readOption("--path", in: options)
            let slug = readOption("--slug", in: options)
            if path == nil && slug == nil {
                throw NolonCoreCLIError.invalidArguments("Missing required option: --path or --slug")
            }
            if path != nil && slug != nil {
                throw NolonCoreCLIError.invalidArguments("Use only one selector: --path or --slug")
            }
            let strictSelector = try parseBoolOption(readOption("--strict-selector", in: options) ?? "false", key: "--strict-selector")
            let installMethod = try parseInstallMethod(readOption("--install-method", in: options) ?? "symlink")
            let providerID = readOption("--provider-id", in: options)

            switch kind {
            case .skill:
                let providerPath = readOption("--provider-path", in: options)
                if providerPath == nil && providerID == nil {
                    throw NolonCoreCLIError.invalidArguments("Missing required option: --provider-path or --provider-id")
                }
                let skillID = readOption("--skill-id", in: options)
                return .remoteSyncInstallSkill(
                    source: source,
                    repositoriesRoot: repositoriesRoot,
                    accessToken: accessToken,
                    pullStrategy: pullStrategy,
                    credentialStrategy: credentialStrategy,
                    maxDepth: maxDepth,
                    path: path,
                    slug: slug,
                    strictSelector: strictSelector,
                    providerPath: providerPath,
                    providerID: providerID,
                    installMethod: installMethod,
                    skillID: skillID
                )
            case .workflow, .mcp:
                let targetPath = readOption("--target-path", in: options)
                if targetPath == nil && providerID == nil {
                    throw NolonCoreCLIError.invalidArguments("Missing required option: --target-path or --provider-id")
                }
                let resourceName = readOption("--resource-name", in: options)
                let resourceKind: NolonResourceKind = kind == .workflow ? .workflow : .mcp
                return .remoteSyncInstallResource(
                    kind: resourceKind,
                    source: source,
                    repositoriesRoot: repositoriesRoot,
                    accessToken: accessToken,
                    pullStrategy: pullStrategy,
                    credentialStrategy: credentialStrategy,
                    maxDepth: maxDepth,
                    path: path,
                    slug: slug,
                    strictSelector: strictSelector,
                    targetPath: targetPath,
                    providerID: providerID,
                    installMethod: installMethod,
                    resourceName: resourceName
                )
            }
        }
        throw NolonCoreCLIError.invalidArguments("Unsupported remote action: \(action)")
    }

    private static func readRequiredOption(_ key: String, in arguments: [String]) throws -> String {
        guard let value = readOption(key, in: arguments), !value.isEmpty else {
            throw NolonCoreCLIError.invalidArguments("Missing required option: \(key)")
        }
        return value
    }

    private static func readOption(_ key: String, in arguments: [String]) -> String? {
        guard let index = arguments.firstIndex(of: key), arguments.indices.contains(index + 1) else { return nil }
        return arguments[index + 1]
    }

    private static func readFlag(_ key: String, in arguments: [String]) -> Bool {
        arguments.contains(key)
    }

    private static func readMultiOption(_ key: String, in arguments: [String]) -> [String] {
        var values: [String] = []
        var index = 0
        while index < arguments.count {
            defer { index += 1 }
            guard arguments[index] == key else { continue }
            let valueIndex = index + 1
            guard arguments.indices.contains(valueIndex) else { continue }
            let value = arguments[valueIndex]
            guard !value.hasPrefix("--") else { continue }
            values.append(value)
            index = valueIndex
        }
        return values
    }

    private static func parseEnvAssignments(_ values: [String]) throws -> [String: String] {
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

    private static func parseStateKind(_ raw: String?) throws -> NolonProviderSkillStateKind? {
        guard let raw else { return nil }
        guard let value = NolonProviderSkillStateKind(rawValue: raw) else {
            throw NolonCoreCLIError.invalidArguments("Unsupported --state: \(raw)")
        }
        return value
    }

    private static func parsePullStrategy(_ raw: String) throws -> NolonGitPullStrategy {
        guard let value = NolonGitPullStrategy(rawValue: raw) else {
            throw NolonCoreCLIError.invalidArguments("Unsupported --pull-strategy: \(raw)")
        }
        return value
    }

    private static func parseCredentialStrategy(_ raw: String) throws -> NolonGitCredentialStrategy {
        guard let value = NolonGitCredentialStrategy(rawValue: raw) else {
            throw NolonCoreCLIError.invalidArguments("Unsupported --credential-strategy: \(raw)")
        }
        return value
    }

    private static func parseInstallMethod(_ raw: String) throws -> NolonSkillInstallMethod {
        guard let value = NolonSkillInstallMethod(rawValue: raw) else {
            throw NolonCoreCLIError.invalidArguments("Unsupported --install-method: \(raw)")
        }
        return value
    }

    private static func parseResourceKind(_ raw: String) throws -> NolonResourceKind {
        guard let value = NolonResourceKind(rawValue: raw) else {
            throw NolonCoreCLIError.invalidArguments("Unsupported --kind: \(raw)")
        }
        return value
    }

    private static func parseBoolOption(_ raw: String, key: String) throws -> Bool {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if ["true", "1", "yes", "y", "on"].contains(normalized) { return true }
        if ["false", "0", "no", "n", "off"].contains(normalized) { return false }
        throw NolonCoreCLIError.invalidArguments("Unsupported \(key): \(raw)")
    }

    private static func parseRemoteKind(_ raw: String) throws -> NolonRemoteCatalogKind {
        guard let value = NolonRemoteCatalogKind(rawValue: raw) else {
            throw NolonCoreCLIError.invalidArguments("Unsupported --kind: \(raw)")
        }
        return value
    }
}
