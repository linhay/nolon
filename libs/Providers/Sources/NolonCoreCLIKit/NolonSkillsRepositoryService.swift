import Foundation
import ProviderCatalog
import STFilePath
import NolonResourceKit

public protocol NolonSkillsRepositoryServing: Sendable {
    func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan
    func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight
    func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult
    func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate]
    func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary]
    func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources
    func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata?
    func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult
    func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult
    func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult
    func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult
    func installResource(
        kind: NolonResourceKind,
        filePath: STPath,
        resourceName: String?,
        targetPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonResourceInstallResult
    func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult
    func bindWorkflowFromSkill(
        skillID: String,
        targetPath: STFolder
    ) throws -> NolonResourceInstallResult
    func bindWorkflowFromMcp(
        mcpName: String,
        targetPath: STFolder
    ) throws -> NolonResourceInstallResult
    func unbindWorkflowFromSkill(
        skillID: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult
    func unbindWorkflowFromMcp(
        mcpName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult
    func listMcpServers(provider: String) throws -> NolonMcpServerListResult
    func setMcpServerEnabled(provider: String, name: String, enabled: Bool) throws -> NolonMcpServerMutationResult
    func upsertMcpServer(
        provider: String,
        name: String,
        url: String?,
        command: String?,
        args: [String],
        env: [String: String],
        enabled: Bool?
    ) throws -> NolonMcpServerMutationResult
    func removeMcpServer(provider: String, name: String) throws -> NolonMcpServerMutationResult
    func migrateMcpServersToCache(provider: String, overwrite: Bool) throws -> NolonMcpCacheMigrateResult
    func mcpCacheStatus(provider: String, name: String?) throws -> NolonMcpCacheStatusResult
    func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult
    func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult
}

public extension NolonSkillsRepositoryServing {
    func listLocalRepositories(repositoriesRoot _: STFolder, maxDepth _: Int) -> [NolonLocalRepositorySummary] { [] }

    func remoteInstallSkill(
        slug: String,
        version: String?,
        baseURL: String,
        providerPath: STFolder,
        skillID: String?,
        installMethod: NolonSkillInstallMethod
    ) async throws -> NolonRemoteInstallResult {
        let download = try await downloadRemoteResource(
            kind: .skill,
            slug: slug,
            version: version,
            baseURL: baseURL
        )
        let skillsRoot = try resolveNolonSkillsRootFolder()
        let stagedSkillPath = STPath(try SkillsRepositoryFacade.stageRemoteSkillForInstall(
            downloadedFileURL: STPath(download.filePath).url,
            slug: slug,
            skillsRoot: skillsRoot.url
        ))
        let effectiveSkillID = (skillID?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false)
            ? skillID
            : slug
        let install = try installSkill(
            skillPath: stagedSkillPath,
            skillID: effectiveSkillID,
            providerPath: providerPath,
            installMethod: installMethod
        )
        return NolonRemoteInstallResult(
            kind: .skill,
            slug: slug,
            version: version,
            baseURL: baseURL,
            downloadedFilePath: download.filePath,
            installedPath: install.targetPath,
            installMethod: installMethod,
            skillID: install.skillID,
            resourceName: nil
        )
    }

    func remoteInstallResource(
        kind: NolonResourceKind,
        slug: String,
        version: String?,
        baseURL: String,
        targetPath: STFolder,
        resourceName: String?,
        installMethod: NolonSkillInstallMethod
    ) async throws -> NolonRemoteInstallResult {
        let remoteKind: NolonRemoteCatalogKind = kind == .workflow ? .workflow : .mcp
        let download = try await downloadRemoteResource(
            kind: remoteKind,
            slug: slug,
            version: version,
            baseURL: baseURL
        )
        let install = try installResource(
            kind: kind,
            filePath: STPath(download.filePath),
            resourceName: resourceName,
            targetPath: targetPath,
            installMethod: installMethod
        )
        return NolonRemoteInstallResult(
            kind: remoteKind,
            slug: slug,
            version: version,
            baseURL: baseURL,
            downloadedFilePath: download.filePath,
            installedPath: install.targetPath,
            installMethod: installMethod,
            skillID: nil,
            resourceName: install.resourceName
        )
    }

    func bindWorkflowFromSkill(
        skillID _: String,
        targetPath _: STFolder
    ) throws -> NolonResourceInstallResult {
        throw NolonCoreCLIError.executionFailed("bindWorkflowFromSkill is not implemented")
    }

    func bindWorkflowFromMcp(
        mcpName _: String,
        targetPath _: STFolder
    ) throws -> NolonResourceInstallResult {
        throw NolonCoreCLIError.executionFailed("bindWorkflowFromMcp is not implemented")
    }

    func unbindWorkflowFromSkill(
        skillID _: String,
        targetPath _: STFolder
    ) throws -> NolonResourceUninstallResult {
        throw NolonCoreCLIError.executionFailed("unbindWorkflowFromSkill is not implemented")
    }

    func unbindWorkflowFromMcp(
        mcpName _: String,
        targetPath _: STFolder
    ) throws -> NolonResourceUninstallResult {
        throw NolonCoreCLIError.executionFailed("unbindWorkflowFromMcp is not implemented")
    }

    func listMcpServers(provider _: String) throws -> NolonMcpServerListResult {
        throw NolonCoreCLIError.executionFailed("listMcpServers is not implemented")
    }

    func setMcpServerEnabled(provider _: String, name _: String, enabled _: Bool) throws -> NolonMcpServerMutationResult {
        throw NolonCoreCLIError.executionFailed("setMcpServerEnabled is not implemented")
    }

    func upsertMcpServer(
        provider _: String,
        name _: String,
        url _: String?,
        command _: String?,
        args _: [String],
        env _: [String: String],
        enabled _: Bool?
    ) throws -> NolonMcpServerMutationResult {
        throw NolonCoreCLIError.executionFailed("upsertMcpServer is not implemented")
    }

    func removeMcpServer(provider _: String, name _: String) throws -> NolonMcpServerMutationResult {
        throw NolonCoreCLIError.executionFailed("removeMcpServer is not implemented")
    }

    func migrateMcpServersToCache(provider _: String, overwrite _: Bool) throws -> NolonMcpCacheMigrateResult {
        throw NolonCoreCLIError.executionFailed("migrateMcpServersToCache is not implemented")
    }

    func mcpCacheStatus(provider _: String, name _: String?) throws -> NolonMcpCacheStatusResult {
        throw NolonCoreCLIError.executionFailed("mcpCacheStatus is not implemented")
    }
}

private func validateSinglePathComponent(_ value: String, field: String) throws -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmed.isEmpty else {
        throw NolonCoreCLIError.invalidArguments("\(field) cannot be empty")
    }
    let candidateURL = URL(fileURLWithPath: trimmed)
    let basename = candidateURL.lastPathComponent
    guard basename == trimmed, trimmed != ".", trimmed != ".." else {
        throw NolonCoreCLIError.invalidArguments("\(field) must be a single path component: \(value)")
    }
    return trimmed
}

private func resolveNolonSkillsRootFolder(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> STFolder {
    let nolonHome = try resolveNolonHomeFolder(environment: environment)
    return nolonHome.folder("skills")
}

private func resolveNolonRepositoriesRootFolder(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> STFolder {
    let nolonHome = try resolveNolonHomeFolder(environment: environment)
    return nolonHome.folder("repositories")
}

private func resolveNolonHomeFolder(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> STFolder {
    let nolonHome: STFolder
    if let raw = environment["NOLON_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
        let expanded = NSString(string: raw).expandingTildeInPath
        nolonHome = STFolder(expanded)
    } else {
        nolonHome = try STFolder(sanbox: .home).folder(".nolon")
    }
    return nolonHome
}

public struct NolonLiveSkillsRepositoryService: NolonSkillsRepositoryServing {
    private let maintenanceService = ProviderSkillMaintenanceService()

    public init() {}

    public func planGitImport(source: String, repositoriesRoot: STFolder) throws -> NolonGitImportPlan {
        let plan = try SkillsRepositoryFacade.planGitImport(source: source, repositoriesRoot: repositoriesRoot.url)
        return NolonGitImportPlan(
            source: plan.source,
            normalizedGitURL: plan.normalizedGitURL,
            subpath: plan.subpath,
            providerHost: plan.providerHost,
            owner: plan.owner,
            repo: plan.repo,
            localClonePath: plan.localClonePath
        )
    }

    public func preflightGitSync(
        source: String,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) throws -> NolonGitSyncPreflight {
        let result = SkillsRepositoryFacade.preflightSync(
            source: source,
            accessToken: accessToken,
            options: .init(
                pullStrategy: mapPullStrategy(pullStrategy),
                credentialStrategy: mapCredentialStrategy(credentialStrategy)
            )
        )
        return NolonGitSyncPreflight(
            isValidURL: result.isValidURL,
            normalizedGitURL: result.normalizedGitURL,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy,
            credentialMode: result.credentialMode.rawValue,
            requiresAccessToken: result.requiresAccessToken,
            warnings: result.warnings,
            issues: result.issues.map {
                NolonGitSyncPreflightIssue(
                    code: mapIssueCode($0.code),
                    severity: mapIssueSeverity($0.severity),
                    message: $0.message
                )
            }
        )
    }

    public func syncGitRepository(
        plan: NolonGitImportPlan,
        accessToken: String?,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy
    ) async throws -> NolonGitSyncResult {
        do {
            let result = try await SkillsRepositoryFacade.syncGitRepository(
                gitURL: plan.normalizedGitURL,
                localClonePath: plan.localClonePath,
                accessToken: accessToken,
                options: .init(
                    pullStrategy: mapPullStrategy(pullStrategy),
                    credentialStrategy: mapCredentialStrategy(credentialStrategy)
                )
            )
            let mode: String
            switch result.mode {
            case .cloned:
                mode = "cloned"
            case .updated:
                mode = "pulled"
            }
            return NolonGitSyncResult(
                mode: mode,
                updatedAt: result.updatedAt,
                directories: result.directories.map {
                    NolonSkillsDirectoryCandidate(path: $0.path, skillCount: $0.skillCount, skillNames: $0.skillNames)
                },
                defaultBranch: result.defaultBranch,
                credentialMode: result.credentialMode.rawValue
            )
        } catch let error as SkillsRepositoryFacade.SyncError {
            throw mapSyncError(
                error,
                gitURL: plan.normalizedGitURL,
                pullStrategy: pullStrategy,
                credentialStrategy: credentialStrategy,
                hasAccessToken: accessToken?.isEmpty == false
            )
        }
    }

    public func discoverSkillsDirectories(at repositoryPath: STFolder, maxDepth: Int) -> [NolonSkillsDirectoryCandidate] {
        SkillsRepositoryFacade.discoverSkillsDirectories(at: repositoryPath.url, maxDepth: maxDepth).map {
            NolonSkillsDirectoryCandidate(path: $0.path, skillCount: $0.skillCount, skillNames: $0.skillNames)
        }
    }

    public func listLocalRepositories(repositoriesRoot: STFolder, maxDepth: Int) -> [NolonLocalRepositorySummary] {
        let root = repositoriesRoot.isExists ? repositoriesRoot : (try? resolveNolonRepositoriesRootFolder()) ?? repositoriesRoot
        guard root.isExists else { return [] }

        let fileManager = FileManager.default
        var repositoryFolders: [STFolder] = []
        var seenPaths: Set<String> = []

        let levelOne = (try? root.subFilePaths([.skipsHiddenFiles])) ?? []
        for levelOnePath in levelOne {
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: levelOnePath.url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }

            let levelOneFolder = STFolder(levelOnePath.url.path)
            let levelOneKey = levelOneFolder.url.standardizedFileURL.path
            if levelOneFolder.subpath(".git").isExists, !seenPaths.contains(levelOneKey) {
                seenPaths.insert(levelOneKey)
                repositoryFolders.append(levelOneFolder)
            }

            let levelTwo = (try? levelOneFolder.subFilePaths([.skipsHiddenFiles])) ?? []
            for levelTwoPath in levelTwo {
                var isLevelTwoDirectory: ObjCBool = false
                guard fileManager.fileExists(atPath: levelTwoPath.url.path, isDirectory: &isLevelTwoDirectory),
                      isLevelTwoDirectory.boolValue else {
                    continue
                }
                let levelTwoFolder = STFolder(levelTwoPath.url.path)
                let levelTwoKey = levelTwoFolder.url.standardizedFileURL.path
                if levelTwoFolder.subpath(".git").isExists, !seenPaths.contains(levelTwoKey) {
                    seenPaths.insert(levelTwoKey)
                    repositoryFolders.append(levelTwoFolder)
                }
            }
        }

        return repositoryFolders
            .sorted { $0.url.path.localizedCaseInsensitiveCompare($1.url.path) == .orderedAscending }
            .map { repository in
                let resources = discoverRepositoryResources(at: repository, maxDepth: maxDepth)
                return NolonLocalRepositorySummary(
                    name: repository.url.lastPathComponent,
                    path: repository.url.path,
                    skillsDirectoryCount: resources.skillsDirectories.count,
                    workflowCount: resources.workflows.count,
                    mcpCount: resources.mcps.count
                )
            }
    }

    public func discoverRepositoryResources(at repositoryPath: STFolder, maxDepth: Int) -> NolonRepositoryResources {
        let resources = SkillsRepositoryFacade.discoverRepositoryResources(at: repositoryPath.url, maxDepth: maxDepth)
        return NolonRepositoryResources(
            skillsDirectories: resources.skillsDirectories.map {
                NolonSkillsDirectoryCandidate(path: $0.path, skillCount: $0.skillCount, skillNames: $0.skillNames)
            },
            workflows: resources.workflows.map { NolonResourceFile(path: $0.path, kind: $0.kind) },
            mcps: resources.mcps.map { NolonResourceFile(path: $0.path, kind: $0.kind) }
        )
    }

    public func parseSkillMetadata(content: String, directoryName: String?) -> NolonSkillStandardMetadata? {
        guard let metadata = SkillsRepositoryFacade.parseSkillMetadata(content: content, directoryName: directoryName) else {
            return nil
        }
        return NolonSkillStandardMetadata(
            name: metadata.name,
            description: metadata.description,
            license: metadata.license,
            compatibility: metadata.compatibility,
            metadata: metadata.metadata,
            argumentHint: metadata.argumentHint,
            allowedTools: metadata.allowedTools,
            isValid: metadata.isValid,
            warnings: metadata.warnings,
            issues: metadata.issues.map { issue in
                NolonSkillValidationIssue(
                    code: mapSkillIssueCode(issue.code),
                    severity: mapSkillIssueSeverity(issue.severity),
                    message: issue.message
                )
            }
        )
    }

    public func installSkill(
        skillPath: STPath,
        skillID: String?,
        providerPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        do {
            let result = try maintenanceService.installSkill(
                skillPath: skillPath,
                skillID: skillID,
                providerPath: providerPath,
                installMethod: installMethod == .copy ? .copy : .symlink
            )
            return NolonSkillInstallResult(
                skillID: result.skillID,
                sourcePath: result.sourcePath,
                targetPath: result.targetPath,
                installMethod: result.installMethod == .copy ? .copy : .symlink
            )
        } catch {
            throw NolonCoreCLIError.invalidArguments(error.localizedDescription)
        }
    }

    public func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        do {
            let result = try maintenanceService.uninstallSkill(skillID: skillID, providerPath: providerPath)
            return NolonSkillUninstallResult(
                skillID: result.skillID,
                targetPath: result.targetPath,
                removed: result.removed
            )
        } catch {
            throw NolonCoreCLIError.invalidArguments(error.localizedDescription)
        }
    }

    public func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        do {
            let scan = try maintenanceService.scanProviderSkills(
                providerPath: providerPath,
                globalSkillsPath: globalSkillsPath
            )
            return NolonSkillMigrateScanResult(
                providerPath: scan.providerPath,
                globalSkillsPath: scan.globalSkillsPath,
                states: scan.states.map { state in
                    NolonProviderSkillState(
                        skillID: state.skillID,
                        path: state.path,
                        state: {
                            switch state.state {
                            case .installed: return .installed
                            case .orphaned: return .orphaned
                            case .broken: return .broken
                            }
                        }()
                    )
                }
            )
        } catch {
            throw NolonCoreCLIError.invalidArguments(error.localizedDescription)
        }
    }

    public func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        do {
            let result = try maintenanceService.migrateSkill(
                skillID: skillID,
                providerPath: providerPath,
                globalSkillsPath: globalSkillsPath,
                installMethod: installMethod == .copy ? .copy : .symlink
            )
            return NolonSkillInstallResult(
                skillID: result.skillID,
                sourcePath: result.sourcePath,
                targetPath: result.targetPath,
                installMethod: result.installMethod == .copy ? .copy : .symlink
            )
        } catch {
            throw NolonCoreCLIError.invalidArguments(error.localizedDescription)
        }
    }

    public func installResource(
        kind: NolonResourceKind,
        filePath: STPath,
        resourceName: String?,
        targetPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonResourceInstallResult {
        let source = filePath
        guard source.isExists else {
            throw NolonCoreCLIError.invalidArguments("Resource file does not exist: \(filePath.url.path)")
        }

        let resolvedName: String
        if let resourceName, !resourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedName = try validateSinglePathComponent(resourceName, field: "resource-name")
        } else {
            resolvedName = try validateSinglePathComponent(source.url.lastPathComponent, field: "resource-name")
        }

        _ = targetPath.createIfNotExists()
        let target = targetPath.subpath(resolvedName)
        if target.isExists {
            try target.delete()
        }

        switch installMethod {
        case .symlink:
            try target.createSymbolicLink(to: source)
        case .copy:
            try source.copy(to: target, isOverlay: true)
        }

        return NolonResourceInstallResult(
            kind: kind,
            resourceName: resolvedName,
            sourcePath: source.url.path,
            targetPath: target.url.path,
            installMethod: installMethod
        )
    }

    public func uninstallResource(
        kind: NolonResourceKind,
        resourceName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        let resolvedName = try validateSinglePathComponent(resourceName, field: "resource-name")
        let target = targetPath.subpath(resolvedName)
        let existed = target.isExists
        if existed {
            try target.delete()
        }
        return NolonResourceUninstallResult(
            kind: kind,
            resourceName: resolvedName,
            targetPath: target.url.path,
            removed: existed
        )
    }

    public func bindWorkflowFromSkill(
        skillID: String,
        targetPath: STFolder
    ) throws -> NolonResourceInstallResult {
        do {
            let result = try SkillsRepositoryFacade.bindWorkflowFromSkill(
                skillID: skillID,
                providerWorkflowPath: targetPath.url
            )
            return NolonResourceInstallResult(
                kind: .workflow,
                resourceName: result.workflowFileName,
                sourcePath: result.globalWorkflowPath,
                targetPath: result.providerWorkflowPath,
                installMethod: .symlink
            )
        } catch {
            throw NolonCoreCLIError.executionFailed(error.localizedDescription)
        }
    }

    public func bindWorkflowFromMcp(
        mcpName: String,
        targetPath: STFolder
    ) throws -> NolonResourceInstallResult {
        do {
            let result = try SkillsRepositoryFacade.bindWorkflowFromMCP(
                mcpName: mcpName,
                providerWorkflowPath: targetPath.url
            )
            return NolonResourceInstallResult(
                kind: .workflow,
                resourceName: result.workflowFileName,
                sourcePath: result.globalWorkflowPath,
                targetPath: result.providerWorkflowPath,
                installMethod: .symlink
            )
        } catch {
            throw NolonCoreCLIError.executionFailed(error.localizedDescription)
        }
    }

    public func unbindWorkflowFromSkill(
        skillID: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        do {
            let result = try SkillsRepositoryFacade.unbindWorkflowFromSkill(
                skillID: skillID,
                providerWorkflowPath: targetPath.url
            )
            return NolonResourceUninstallResult(
                kind: .workflow,
                resourceName: result.workflowFileName,
                targetPath: result.providerWorkflowPath,
                removed: result.removed
            )
        } catch {
            throw NolonCoreCLIError.executionFailed(error.localizedDescription)
        }
    }

    public func unbindWorkflowFromMcp(
        mcpName: String,
        targetPath: STFolder
    ) throws -> NolonResourceUninstallResult {
        do {
            let result = try SkillsRepositoryFacade.unbindWorkflowFromMCP(
                mcpName: mcpName,
                providerWorkflowPath: targetPath.url
            )
            return NolonResourceUninstallResult(
                kind: .workflow,
                resourceName: result.workflowFileName,
                targetPath: result.providerWorkflowPath,
                removed: result.removed
            )
        } catch {
            throw NolonCoreCLIError.executionFailed(error.localizedDescription)
        }
    }

    public func listMcpServers(provider: String) throws -> NolonMcpServerListResult {
        do {
            let template = try resolveProviderTemplateOrThrow(provider)
            let servers = try MCPConfigManager.listServers(for: template)
            return NolonMcpServerListResult(
                providerID: template.providerID,
                configPath: template.defaultMcpConfigPath.path,
                items: servers.map {
                    NolonMcpServerItem(
                        name: $0.name,
                        url: $0.url,
                        command: $0.command,
                        args: $0.args,
                        env: $0.env,
                        enabled: $0.isEnabled
                    )
                }
            )
        } catch let error as NolonCoreCLIError {
            throw error
        } catch {
            throw NolonCoreCLIError.executionFailed(error.localizedDescription)
        }
    }

    public func setMcpServerEnabled(provider: String, name: String, enabled: Bool) throws -> NolonMcpServerMutationResult {
        do {
            let template = try resolveProviderTemplateOrThrow(provider)
            try MCPConfigManager.setEnabled(for: template, name: name, enabled: enabled)
            return NolonMcpServerMutationResult(
                providerID: template.providerID,
                configPath: template.defaultMcpConfigPath.path,
                name: name,
                action: enabled ? "enabled" : "disabled"
            )
        } catch let error as NolonCoreCLIError {
            throw error
        } catch {
            throw NolonCoreCLIError.executionFailed(error.localizedDescription)
        }
    }

    public func upsertMcpServer(
        provider: String,
        name: String,
        url: String?,
        command: String?,
        args: [String],
        env: [String: String],
        enabled: Bool?
    ) throws -> NolonMcpServerMutationResult {
        do {
            let template = try resolveProviderTemplateOrThrow(provider)
            var config: [String: Any] = [:]
            if let url, !url.isEmpty { config["url"] = url }
            if let command, !command.isEmpty { config["command"] = command }
            if !args.isEmpty { config["args"] = args }
            if !env.isEmpty { config["env"] = env }
            if let enabled { config["enabled"] = enabled }
            try MCPConfigManager.upsertServer(for: template, name: name, serverConfig: config)
            return NolonMcpServerMutationResult(
                providerID: template.providerID,
                configPath: template.defaultMcpConfigPath.path,
                name: name,
                action: "upserted"
            )
        } catch let error as NolonCoreCLIError {
            throw error
        } catch {
            throw NolonCoreCLIError.executionFailed(error.localizedDescription)
        }
    }

    public func removeMcpServer(provider: String, name: String) throws -> NolonMcpServerMutationResult {
        do {
            let template = try resolveProviderTemplateOrThrow(provider)
            try MCPConfigManager.removeServer(for: template, name: name)
            return NolonMcpServerMutationResult(
                providerID: template.providerID,
                configPath: template.defaultMcpConfigPath.path,
                name: name,
                action: "removed"
            )
        } catch let error as NolonCoreCLIError {
            throw error
        } catch {
            throw NolonCoreCLIError.executionFailed(error.localizedDescription)
        }
    }

    public func migrateMcpServersToCache(provider: String, overwrite: Bool) throws -> NolonMcpCacheMigrateResult {
        do {
            let template = try resolveProviderTemplateOrThrow(provider)
            let result = try MCPConfigManager.migrateServersToGlobalCache(for: template, overwrite: overwrite)
            return NolonMcpCacheMigrateResult(
                providerID: template.providerID,
                configPath: template.defaultMcpConfigPath.path,
                migrated: result.migrated,
                skipped: result.skipped,
                updated: result.updated
            )
        } catch let error as NolonCoreCLIError {
            throw error
        } catch {
            throw NolonCoreCLIError.executionFailed(error.localizedDescription)
        }
    }

    public func mcpCacheStatus(provider: String, name: String?) throws -> NolonMcpCacheStatusResult {
        do {
            let template = try resolveProviderTemplateOrThrow(provider)
            let result = try MCPConfigManager.cacheStatus(for: template, name: name)
            return NolonMcpCacheStatusResult(
                providerID: template.providerID,
                configPath: template.defaultMcpConfigPath.path,
                items: result.map {
                    NolonMcpCacheStatusItem(
                        name: $0.name,
                        state: NolonMcpCacheState(rawValue: $0.state.rawValue) ?? .notMigrated,
                        cachePath: $0.cachePath
                    )
                }
            )
        } catch let error as NolonCoreCLIError {
            throw error
        } catch {
            throw NolonCoreCLIError.executionFailed(error.localizedDescription)
        }
    }

    public func listRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        let facadeKind: SkillsRepositoryFacade.RemoteCatalogKind = {
            switch kind {
            case .skill: return .skill
            case .workflow: return .workflow
            case .mcp: return .mcp
            }
        }()
        let result = try await SkillsRepositoryFacade.listRemoteResources(
            kind: facadeKind,
            query: query,
            limit: limit,
            baseURL: baseURL
        )
        return NolonRemoteListResult(
            kind: kind,
            baseURL: result.baseURL,
            query: result.query,
            limit: result.limit,
            items: result.items.map { item in
                NolonRemoteCatalogItem(
                    kind: kind,
                    slug: item.slug,
                    displayName: item.displayName,
                    summary: item.summary,
                    latestVersion: item.latestVersion,
                    updatedAt: item.updatedAt,
                    downloads: item.downloads,
                    stars: item.stars,
                    installs: item.installs
                )
            }
        )
    }

    public func downloadRemoteResource(
        kind: NolonRemoteCatalogKind,
        slug: String,
        version: String?,
        baseURL: String
    ) async throws -> NolonRemoteDownloadResult {
        let facadeKind: SkillsRepositoryFacade.RemoteCatalogKind = {
            switch kind {
            case .skill: return .skill
            case .workflow: return .workflow
            case .mcp: return .mcp
            }
        }()
        let fileURL: URL
        do {
            fileURL = try await SkillsRepositoryFacade.downloadRemoteResource(
                kind: facadeKind,
                slug: slug,
                version: version,
                baseURL: baseURL
            )
        } catch {
            throw NolonCoreCLIError.executionFailed(error.localizedDescription)
        }
        return NolonRemoteDownloadResult(
            kind: kind,
            slug: slug,
            version: version,
            baseURL: baseURL,
            filePath: fileURL.path
        )
    }
}

private func resolveProviderTemplateOrThrow(_ provider: String) throws -> ProviderTemplate {
    if let template = ProviderTemplate.resolve(providerID: provider) {
        return template
    }
    throw NolonCoreCLIError.invalidArguments("Unsupported --provider: \(provider)")
}

private extension NolonLiveSkillsRepositoryService {
    func mapPullStrategy(_ strategy: NolonGitPullStrategy) -> SkillsRepositoryFacade.GitPullStrategy {
        switch strategy {
        case .ffOnly:
            return .ffOnly
        case .rebase:
            return .rebase
        }
    }

    func mapCredentialStrategy(_ strategy: NolonGitCredentialStrategy) -> SkillsRepositoryFacade.GitCredentialStrategy {
        switch strategy {
        case .automatic:
            return .automatic
        case .tokenOnly:
            return .tokenOnly
        case .sshOnly:
            return .sshOnly
        }
    }

    func mapSyncError(
        _ error: SkillsRepositoryFacade.SyncError,
        gitURL: String,
        pullStrategy: NolonGitPullStrategy,
        credentialStrategy: NolonGitCredentialStrategy,
        hasAccessToken: Bool
    ) -> NolonCoreCLIError {
        var detail = NolonGitSyncErrorDetail(
            gitURL: gitURL,
            pullStrategy: pullStrategy,
            credentialStrategy: credentialStrategy,
            hasAccessToken: hasAccessToken
        )

        switch error {
        case .invalidURL:
            return .syncFailed(code: "invalid_git_url", message: error.localizedDescription, detail: detail)
        case .accessTokenRequired:
            return .syncFailed(code: "access_token_required", message: error.localizedDescription, detail: detail)
        case let .sshNotAvailable(host):
            detail = NolonGitSyncErrorDetail(
                gitURL: detail.gitURL,
                pullStrategy: detail.pullStrategy,
                credentialStrategy: detail.credentialStrategy,
                hasAccessToken: detail.hasAccessToken,
                host: host
            )
            return .syncFailed(code: "ssh_not_available", message: error.localizedDescription, detail: detail)
        case .cloneFailed:
            detail = NolonGitSyncErrorDetail(
                gitURL: detail.gitURL,
                pullStrategy: detail.pullStrategy,
                credentialStrategy: detail.credentialStrategy,
                hasAccessToken: detail.hasAccessToken,
                phase: "clone"
            )
            return .syncFailed(code: "git_clone_failed", message: error.localizedDescription, detail: detail)
        case .pullFailed:
            detail = NolonGitSyncErrorDetail(
                gitURL: detail.gitURL,
                pullStrategy: detail.pullStrategy,
                credentialStrategy: detail.credentialStrategy,
                hasAccessToken: detail.hasAccessToken,
                phase: "pull"
            )
            return .syncFailed(code: "git_pull_failed", message: error.localizedDescription, detail: detail)
        case .commandFailed:
            detail = NolonGitSyncErrorDetail(
                gitURL: detail.gitURL,
                pullStrategy: detail.pullStrategy,
                credentialStrategy: detail.credentialStrategy,
                hasAccessToken: detail.hasAccessToken,
                phase: "command"
            )
            return .syncFailed(code: "git_command_failed", message: error.localizedDescription, detail: detail)
        }
    }

    func mapIssueCode(_ code: SkillsRepositoryFacade.GitSyncPreflightIssueCode) -> NolonGitSyncPreflightIssueCode {
        switch code {
        case .invalidGitURL:
            return .invalidGitURL
        case .accessTokenRequired:
            return .accessTokenRequired
        case .tokenStrategyRequiresHTTPS:
            return .tokenStrategyRequiresHTTPS
        case .sshStrategyRequiresSSH:
            return .sshStrategyRequiresSSH
        }
    }

    func mapIssueSeverity(
        _ severity: SkillsRepositoryFacade.GitSyncPreflightIssueSeverity
    ) -> NolonGitSyncPreflightIssueSeverity {
        switch severity {
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }

    func mapSkillIssueCode(_ code: SkillSpecificationParser.IssueCode) -> NolonSkillValidationIssueCode {
        switch code {
        case .unknownTopLevelField:
            return .unknownTopLevelField
        case .metadataNotObject:
            return .metadataNotObject
        case .metadataValueNotString:
            return .metadataValueNotString
        case .missingName:
            return .missingName
        case .missingDescription:
            return .missingDescription
        case .invalidNameFormat:
            return .invalidNameFormat
        case .nameDirectoryMismatch:
            return .nameDirectoryMismatch
        case .descriptionTooLong:
            return .descriptionTooLong
        case .compatibilityOutOfRange:
            return .compatibilityOutOfRange
        case .allowedToolsUnsupportedFormat:
            return .allowedToolsUnsupportedFormat
        case .allowedToolsNonStringItem:
            return .allowedToolsNonStringItem
        }
    }

    func mapSkillIssueSeverity(_ severity: SkillSpecificationParser.IssueSeverity) -> NolonSkillValidationIssueSeverity {
        switch severity {
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }
}
