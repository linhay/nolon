import Foundation
import ProviderCatalog
import STFilePath

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
    let nolonHome: STFolder
    if let raw = environment["NOLON_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
        let expanded = NSString(string: raw).expandingTildeInPath
        nolonHome = STFolder(expanded)
    } else {
        nolonHome = try STFolder(sanbox: .home).folder(".nolon")
    }
    return nolonHome.folder("skills")
}

public struct NolonLiveSkillsRepositoryService: NolonSkillsRepositoryServing {
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
        let source = skillPath
        guard source.isExists else {
            throw NolonCoreCLIError.invalidArguments("Skill path does not exist: \(skillPath.url.path)")
        }

        let resolvedSkillID: String
        if let skillID, !skillID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedSkillID = try validateSinglePathComponent(skillID, field: "skill-id")
        } else {
            resolvedSkillID = try validateSinglePathComponent(source.url.lastPathComponent, field: "skill-id")
        }

        _ = providerPath.createIfNotExists()
        let targetPath = providerPath.subpath(resolvedSkillID)
        let target = targetPath
        if target.isExists {
            try target.delete()
        }

        switch installMethod {
        case .symlink:
            try target.createSymbolicLink(to: source)
        case .copy:
            try source.copy(to: target, isOverlay: true)
        }

        return NolonSkillInstallResult(
            skillID: resolvedSkillID,
            sourcePath: source.url.path,
            targetPath: target.url.path,
            installMethod: installMethod
        )
    }

    public func uninstallSkill(skillID: String, providerPath: STFolder) throws -> NolonSkillUninstallResult {
        let resolvedSkillID = try validateSinglePathComponent(skillID, field: "skill-id")
        let target = providerPath.subpath(resolvedSkillID)
        let existed = target.isExists
        if existed {
            try target.delete()
        }
        return NolonSkillUninstallResult(skillID: resolvedSkillID, targetPath: target.url.path, removed: existed)
    }

    public func scanProviderSkills(providerPath: STFolder, globalSkillsPath: STFolder) throws -> NolonSkillMigrateScanResult {
        guard providerPath.isExists else {
            throw NolonCoreCLIError.invalidArguments("Provider path does not exist: \(providerPath.url.path)")
        }
        let entries = try providerPath.subFilePaths([.skipsHiddenFiles])
        let globalRoot = globalSkillsPath.url.path.hasSuffix("/")
            ? globalSkillsPath.url.path
            : "\(globalSkillsPath.url.path)/"
        let states = entries.map { path -> NolonProviderSkillState in
            let skillID = path.url.lastPathComponent
            let globalCandidate = globalSkillsPath.subpath(skillID).url.path
            let globalExists = STPath(globalCandidate).isExists
            if path.isSymbolicLink {
                let dest = ((try? path.destinationOfSymbolicLink()) ?? path).url.path
                if STPath(dest).isExists {
                    if dest.hasPrefix(globalRoot) {
                        return NolonProviderSkillState(skillID: skillID, path: path.url.path, state: .installed)
                    }
                    return NolonProviderSkillState(skillID: skillID, path: path.url.path, state: .orphaned)
                }
                return NolonProviderSkillState(skillID: skillID, path: path.url.path, state: .broken)
            }
            if globalExists {
                return NolonProviderSkillState(skillID: skillID, path: path.url.path, state: .orphaned)
            }
            return NolonProviderSkillState(skillID: skillID, path: path.url.path, state: .orphaned)
        }.sorted { $0.skillID.localizedCaseInsensitiveCompare($1.skillID) == .orderedAscending }
        return NolonSkillMigrateScanResult(
            providerPath: providerPath.url.path,
            globalSkillsPath: globalSkillsPath.url.path,
            states: states
        )
    }

    public func migrateSkill(
        skillID: String,
        providerPath: STFolder,
        globalSkillsPath: STFolder,
        installMethod: NolonSkillInstallMethod
    ) throws -> NolonSkillInstallResult {
        let resolvedSkillID = try validateSinglePathComponent(skillID, field: "skill-id")
        let source = globalSkillsPath.subpath(resolvedSkillID)
        guard source.isExists else {
            throw NolonCoreCLIError.invalidArguments("Global skill not found: \(source.url.path)")
        }
        return try installSkill(
            skillPath: source,
            skillID: resolvedSkillID,
            providerPath: providerPath,
            installMethod: installMethod
        )
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
