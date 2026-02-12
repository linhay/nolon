import Foundation

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
    case skillsRepoSync(
        source: String,
        repositoriesRoot: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
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
    case resourcesDiscover(path: String, maxDepth: Int)
    case resourcesInstall(
        kind: NolonResourceKind,
        filePath: String,
        resourceName: String?,
        targetPath: String,
        installMethod: NolonSkillInstallMethod
    )
    case resourcesUninstall(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: String
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

    var commandID: String {
        switch self {
        case .skillsRepoPlan: "skills.repo.plan"
        case .skillsRepoPreflight: "skills.repo.preflight"
        case .skillsRepoSync: "skills.repo.sync"
        case .skillsInstall: "skills.install"
        case .skillsUninstall: "skills.uninstall"
        case .skillsMigrateScan: "skills.migrate.scan"
        case .skillsMigrateApply: "skills.migrate.apply"
        case .skillsDiscover: "skills.discover"
        case .skillsParse: "skills.parse"
        case .resourcesDiscover: "resources.discover"
        case .resourcesInstall: "resources.install"
        case .resourcesUninstall: "resources.uninstall"
        case .remoteList: "remote.list"
        case .remoteDownload: "remote.download"
        }
    }
}

public enum NolonCoreCLIError: LocalizedError, Equatable, Sendable {
    case invalidArguments(String)
    case executionFailed(String)
    case syncFailed(code: String, message: String, detail: NolonGitSyncErrorDetail)

    public var errorDescription: String? {
        switch self {
        case let .invalidArguments(message):
            message
        case let .executionFailed(message):
            message
        case let .syncFailed(_, message, _):
            message
        }
    }

    var code: String {
        switch self {
        case .invalidArguments: "invalid_arguments"
        case .executionFailed: "execution_failed"
        case let .syncFailed(code, _, _): code
        }
    }

    var detail: NolonGitSyncErrorDetail? {
        switch self {
        case .invalidArguments, .executionFailed:
            return nil
        case let .syncFailed(_, _, detail):
            return detail
        }
    }
}

public enum NolonCoreCLICommandParser {
    public static func parse(_ arguments: [String]) throws -> NolonCoreCLICommand {
        guard arguments.count >= 2 else {
            throw NolonCoreCLIError.invalidArguments("Missing command. Expected: skills|resources ...")
        }

        let command = arguments[0]
        if command == "skills" {
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

            throw NolonCoreCLIError.invalidArguments("Unsupported skills subcommand: \(arguments[1])")
        }

        if command == "resources" {
            return try parseResources(Array(arguments.dropFirst(1)))
        }

        if command == "remote" {
            return try parseRemote(Array(arguments.dropFirst(1)))
        }

        throw NolonCoreCLIError.invalidArguments("Unsupported command root: \(command)")
    }

    private static func parseSkillsRepo(_ arguments: [String]) throws -> NolonCoreCLICommand {
        guard let action = arguments.first else {
            throw NolonCoreCLIError.invalidArguments("Missing skills repo action: plan|sync")
        }
        let options = Array(arguments.dropFirst())
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

    private static func parseResources(_ arguments: [String]) throws -> NolonCoreCLICommand {
        guard let action = arguments.first else {
            throw NolonCoreCLIError.invalidArguments("Missing resources action: discover|install|uninstall")
        }
        if action == "discover" {
            let options = Array(arguments.dropFirst())
            let path = try readRequiredOption("--path", in: options)
            let maxDepth = Int(readOption("--max-depth", in: options) ?? "5") ?? 5
            return .resourcesDiscover(path: path, maxDepth: maxDepth)
        }
        if action == "install" {
            let options = Array(arguments.dropFirst())
            let kind = try parseResourceKind(try readRequiredOption("--kind", in: options))
            let filePath = try readRequiredOption("--file-path", in: options)
            let targetPath = try readRequiredOption("--target-path", in: options)
            let resourceName = readOption("--resource-name", in: options)
            let installMethod = try parseInstallMethod(readOption("--install-method", in: options) ?? "symlink")
            return .resourcesInstall(
                kind: kind,
                filePath: filePath,
                resourceName: resourceName,
                targetPath: targetPath,
                installMethod: installMethod
            )
        }
        if action == "uninstall" {
            let options = Array(arguments.dropFirst())
            let kind = try parseResourceKind(try readRequiredOption("--kind", in: options))
            let resourceName = try readRequiredOption("--resource-name", in: options)
            let targetPath = try readRequiredOption("--target-path", in: options)
            return .resourcesUninstall(kind: kind, resourceName: resourceName, targetPath: targetPath)
        }
        throw NolonCoreCLIError.invalidArguments("Unsupported resources action: \(action)")
    }

    private static func parseRemote(_ arguments: [String]) throws -> NolonCoreCLICommand {
        guard let action = arguments.first else {
            throw NolonCoreCLIError.invalidArguments("Missing remote action: list|download")
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

    private static func parseRemoteKind(_ raw: String) throws -> NolonRemoteCatalogKind {
        guard let value = NolonRemoteCatalogKind(rawValue: raw) else {
            throw NolonCoreCLIError.invalidArguments("Unsupported --kind: \(raw)")
        }
        return value
    }
}
