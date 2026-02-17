import Foundation
import ProviderCatalog
import STFilePath

public struct NolonCoreCLIRunner: Sendable {
    public typealias FileReader = @Sendable (String) throws -> String

    private let service: any NolonSkillsRepositoryServing
    private let fileReader: FileReader

    public init(
        service: any NolonSkillsRepositoryServing = NolonLiveSkillsRepositoryService(),
        fileReader: @escaping FileReader = { path in
            try STFile(path).read()
        }
    ) {
        self.service = service
        self.fileReader = fileReader
    }

    public func execute(arguments: [String]) async -> NolonCLIExecutionResult {
        do {
            let command = try NolonCoreCLIArgumentParser.parse(arguments)
            let success = try await executeCommand(command)
            return NolonCLIExecutionResult(exitCode: 0, stdout: success, stderr: "")
        } catch let error as NolonCoreCLIError {
            return NolonCLIExecutionResult(exitCode: 2, stdout: "", stderr: errorJSON(for: error))
        } catch {
            let wrapped = NolonCoreCLIError.executionFailed(error.localizedDescription)
            return NolonCLIExecutionResult(exitCode: 2, stdout: "", stderr: errorJSON(for: wrapped))
        }
    }

    private func executeCommand(_ command: NolonCoreCLICommand) async throws -> String {
        switch command {
        case let .skillsRepoPlan(source, repositoriesRoot, pullStrategy, credentialStrategy, accessToken):
            let plan = try service.planGitImport(
                source: source,
                repositoriesRoot: STFolder(repositoriesRoot)
            )
            let preflight = try service.preflightGitSync(
                source: source,
                accessToken: accessToken,
                pullStrategy: pullStrategy,
                credentialStrategy: credentialStrategy
            )
            return try encodeSuccess(
                command: command.commandID,
                data: PlanPayload(plan: plan, preflight: preflight)
            )

        case let .skillsRepoPreflight(source, pullStrategy, credentialStrategy, accessToken):
            let result = try service.preflightGitSync(
                source: source,
                accessToken: accessToken,
                pullStrategy: pullStrategy,
                credentialStrategy: credentialStrategy
            )
            return try encodeSuccess(
                command: command.commandID,
                data: PreflightPayload(result: result)
            )

        case let .skillsRepoSync(source, repositoriesRoot, accessToken, pullStrategy, credentialStrategy):
            let plan = try service.planGitImport(
                source: source,
                repositoriesRoot: STFolder(repositoriesRoot)
            )
            let result = try await service.syncGitRepository(
                plan: plan,
                accessToken: accessToken,
                pullStrategy: pullStrategy,
                credentialStrategy: credentialStrategy
            )
            let resources = service.discoverRepositoryResources(
                at: STFolder(plan.localClonePath),
                maxDepth: 5
            )
            return try encodeSuccess(
                command: command.commandID,
                data: SyncPayload(plan: plan, result: result, resources: resources)
            )

        case let .skillsInstall(skillPath, skillID, providerPath, installMethod):
            let result = try service.installSkill(
                skillPath: STPath(skillPath),
                skillID: skillID,
                providerPath: STFolder(providerPath),
                installMethod: installMethod
            )
            return try encodeSuccess(command: command.commandID, data: SkillInstallPayload(result: result))

        case let .skillsUninstall(skillID, providerPath):
            let result = try service.uninstallSkill(
                skillID: skillID,
                providerPath: STFolder(providerPath)
            )
            return try encodeSuccess(command: command.commandID, data: SkillUninstallPayload(result: result))

        case let .skillsMigrateScan(providerPath, globalSkillsPath):
            let result = try service.scanProviderSkills(
                providerPath: STFolder(providerPath),
                globalSkillsPath: STFolder(globalSkillsPath)
            )
            return try encodeSuccess(command: command.commandID, data: SkillMigrateScanPayload(result: result))

        case let .skillsMigrateApply(skillID, providerPath, globalSkillsPath, installMethod):
            let result = try service.migrateSkill(
                skillID: skillID,
                providerPath: STFolder(providerPath),
                globalSkillsPath: STFolder(globalSkillsPath),
                installMethod: installMethod
            )
            return try encodeSuccess(command: command.commandID, data: SkillMigrateApplyPayload(result: result))

        case let .skillsDiscover(path, maxDepth):
            let directories = service.discoverSkillsDirectories(
                at: STFolder(path),
                maxDepth: maxDepth
            )
            return try encodeSuccess(
                command: command.commandID,
                data: DiscoverPayload(path: path, maxDepth: maxDepth, directories: directories)
            )

        case let .skillsParse(file, directoryName):
            let content = try fileReader(file)
            let metadata = service.parseSkillMetadata(content: content, directoryName: directoryName)
            return try encodeSuccess(
                command: command.commandID,
                data: ParsePayload(file: file, metadata: metadata)
            )

        case let .workflowDiscover(path, maxDepth):
            let resources = service.discoverRepositoryResources(
                at: STFolder(path),
                maxDepth: maxDepth
            )
            return try encodeSuccess(
                command: command.commandID,
                data: ResourceDiscoverPayload(
                    path: path,
                    maxDepth: maxDepth,
                    resources: filterResources(resources, kind: .workflow)
                )
            )

        case let .workflowInstall(filePath, resourceName, targetPath, installMethod):
            let result = try service.installResource(
                kind: .workflow,
                filePath: STPath(filePath),
                resourceName: resourceName,
                targetPath: STFolder(targetPath),
                installMethod: installMethod
            )
            return try encodeSuccess(command: command.commandID, data: ResourceInstallPayload(result: result))

        case let .workflowUninstall(resourceName, targetPath):
            let result = try service.uninstallResource(
                kind: .workflow,
                resourceName: resourceName,
                targetPath: STFolder(targetPath)
            )
            return try encodeSuccess(command: command.commandID, data: ResourceUninstallPayload(result: result))

        case let .mcpDiscover(path, maxDepth):
            let resources = service.discoverRepositoryResources(
                at: STFolder(path),
                maxDepth: maxDepth
            )
            return try encodeSuccess(
                command: command.commandID,
                data: ResourceDiscoverPayload(
                    path: path,
                    maxDepth: maxDepth,
                    resources: filterResources(resources, kind: .mcp)
                )
            )

        case let .mcpInstall(filePath, resourceName, targetPath, installMethod):
            let result = try service.installResource(
                kind: .mcp,
                filePath: STPath(filePath),
                resourceName: resourceName,
                targetPath: STFolder(targetPath),
                installMethod: installMethod
            )
            return try encodeSuccess(command: command.commandID, data: ResourceInstallPayload(result: result))

        case let .mcpUninstall(resourceName, targetPath):
            let result = try service.uninstallResource(
                kind: .mcp,
                resourceName: resourceName,
                targetPath: STFolder(targetPath)
            )
            return try encodeSuccess(command: command.commandID, data: ResourceUninstallPayload(result: result))

        case let .remoteList(kind, query, limit, baseURL):
            let result = try await service.listRemoteResources(
                kind: kind,
                query: query,
                limit: limit,
                baseURL: baseURL
            )
            return try encodeSuccess(command: command.commandID, data: RemoteListPayload(result: result))

        case let .remoteDownload(kind, slug, version, baseURL):
            let result = try await service.downloadRemoteResource(
                kind: kind,
                slug: slug,
                version: version,
                baseURL: baseURL
            )
            return try encodeSuccess(command: command.commandID, data: RemoteDownloadPayload(result: result))

        case let .remoteSync(source, repositoriesRoot, accessToken, pullStrategy, credentialStrategy, maxDepth):
            let plan = try service.planGitImport(
                source: source,
                repositoriesRoot: STFolder(repositoriesRoot)
            )
            let result = try await service.syncGitRepository(
                plan: plan,
                accessToken: accessToken,
                pullStrategy: pullStrategy,
                credentialStrategy: credentialStrategy
            )
            let resources = service.discoverRepositoryResources(
                at: STFolder(plan.localClonePath),
                maxDepth: maxDepth
            )
            return try encodeSuccess(
                command: command.commandID,
                data: SyncPayload(plan: plan, result: result, resources: resources)
            )

        case let .remoteSyncInstallSkill(
            source,
            repositoriesRoot,
            accessToken,
            pullStrategy,
            credentialStrategy,
            maxDepth,
            path,
            slug,
            strictSelector,
            providerPath,
            providerID,
            installMethod,
            skillID
        ):
            let plan = try service.planGitImport(
                source: source,
                repositoriesRoot: STFolder(repositoriesRoot)
            )
            let result = try await service.syncGitRepository(
                plan: plan,
                accessToken: accessToken,
                pullStrategy: pullStrategy,
                credentialStrategy: credentialStrategy
            )
            let resources = service.discoverRepositoryResources(
                at: STFolder(plan.localClonePath),
                maxDepth: maxDepth
            )
            let repositorySelection = try Self.resolveRepositoryInstallPath(
                kind: .skill,
                repositoryRoot: plan.localClonePath,
                path: path,
                slug: slug,
                strictSelector: strictSelector,
                resources: resources
            )
            let resolvedProviderPath = try Self.resolveSkillProviderPath(
                explicitProviderPath: providerPath,
                providerID: providerID
            )
            let install = try service.installSkill(
                skillPath: STPath(repositorySelection.path),
                skillID: skillID,
                providerPath: STFolder(resolvedProviderPath),
                installMethod: installMethod
            )
            return try encodeSuccess(
                command: command.commandID,
                data: RemoteSyncInstallPayload(
                    plan: plan,
                    result: result,
                    resources: resources,
                    install: NolonRemoteSyncInstallResult(
                        kind: .skill,
                        source: source,
                        repositoriesRoot: repositoriesRoot,
                        path: path ?? slug ?? "",
                        repositoryFilePath: repositorySelection.path,
                        installedPath: install.targetPath,
                        installMethod: installMethod,
                        skillID: install.skillID,
                        resourceName: nil,
                        warnings: repositorySelection.warnings
                    )
                )
            )

        case let .remoteSyncInstallResource(
            kind,
            source,
            repositoriesRoot,
            accessToken,
            pullStrategy,
            credentialStrategy,
            maxDepth,
            path,
            slug,
            strictSelector,
            targetPath,
            providerID,
            installMethod,
            resourceName
        ):
            let plan = try service.planGitImport(
                source: source,
                repositoriesRoot: STFolder(repositoriesRoot)
            )
            let result = try await service.syncGitRepository(
                plan: plan,
                accessToken: accessToken,
                pullStrategy: pullStrategy,
                credentialStrategy: credentialStrategy
            )
            let resources = service.discoverRepositoryResources(
                at: STFolder(plan.localClonePath),
                maxDepth: maxDepth
            )
            let repositorySelection = try Self.resolveRepositoryInstallPath(
                kind: kind == .workflow ? .workflow : .mcp,
                repositoryRoot: plan.localClonePath,
                path: path,
                slug: slug,
                strictSelector: strictSelector,
                resources: resources
            )
            let resolvedTargetPath = try Self.resolveResourceTargetPath(
                kind: kind,
                explicitTargetPath: targetPath,
                providerID: providerID
            )
            let install = try service.installResource(
                kind: kind,
                filePath: STPath(repositorySelection.path),
                resourceName: resourceName,
                targetPath: STFolder(resolvedTargetPath),
                installMethod: installMethod
            )
            let remoteKind: NolonRemoteCatalogKind = kind == .workflow ? .workflow : .mcp
            return try encodeSuccess(
                command: command.commandID,
                data: RemoteSyncInstallPayload(
                    plan: plan,
                    result: result,
                    resources: resources,
                    install: NolonRemoteSyncInstallResult(
                        kind: remoteKind,
                        source: source,
                        repositoriesRoot: repositoriesRoot,
                        path: path ?? slug ?? "",
                        repositoryFilePath: repositorySelection.path,
                        installedPath: install.targetPath,
                        installMethod: installMethod,
                        skillID: nil,
                        resourceName: install.resourceName,
                        warnings: repositorySelection.warnings
                    )
                )
            )

        case let .remoteInstallSkill(slug, version, baseURL, providerPath, providerID, installMethod, skillID):
            let resolvedProviderPath = try Self.resolveSkillProviderPath(
                explicitProviderPath: providerPath,
                providerID: providerID
            )
            let result = try await service.remoteInstallSkill(
                slug: slug,
                version: version,
                baseURL: baseURL,
                providerPath: STFolder(resolvedProviderPath),
                skillID: skillID,
                installMethod: installMethod
            )
            return try encodeSuccess(
                command: command.commandID,
                data: RemoteInstallPayload(
                    result: result
                )
            )

        case let .remoteInstallResource(kind, slug, version, baseURL, targetPath, providerID, installMethod, resourceName):
            let resolvedTargetPath = try Self.resolveResourceTargetPath(
                kind: kind,
                explicitTargetPath: targetPath,
                providerID: providerID
            )
            let result = try await service.remoteInstallResource(
                kind: kind,
                slug: slug,
                version: version,
                baseURL: baseURL,
                targetPath: STFolder(resolvedTargetPath),
                resourceName: resourceName,
                installMethod: installMethod
            )
            return try encodeSuccess(
                command: command.commandID,
                data: RemoteInstallPayload(
                    result: result
                )
            )
        }
    }

    private func encodeSuccess<Payload: Encodable & Sendable>(command: String, data: Payload) throws -> String {
        let envelope = NolonCLISuccessEnvelope(command: command, data: data)
        return try encodeJSON(envelope)
    }

    private func errorJSON(for error: NolonCoreCLIError) -> String {
        (try? encodeJSON(
            NolonCLIErrorEnvelope(
                code: error.code,
                message: error.errorDescription ?? "Unknown error",
                detail: error.detail
            )
        ))
            ?? "{\"ok\":false,\"error\":{\"code\":\"execution_failed\",\"message\":\"Unknown error\"}}"
    }

    private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    private static func resolveSkillProviderPath(
        explicitProviderPath: String?,
        providerID: String?
    ) throws -> String {
        if let explicitProviderPath, !explicitProviderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return explicitProviderPath
        }
        guard let providerID, !providerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NolonCoreCLIError.invalidArguments("Missing required option: --provider-path or --provider-id")
        }
        guard let template = resolveProviderTemplate(providerID: providerID) else {
            throw NolonCoreCLIError.invalidArguments("Unsupported --provider-id: \(providerID)")
        }
        return template.defaultSkillsPath.path
    }

    private static func resolveResourceTargetPath(
        kind: NolonResourceKind,
        explicitTargetPath: String?,
        providerID: String?
    ) throws -> String {
        if let explicitTargetPath, !explicitTargetPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return explicitTargetPath
        }
        guard let providerID, !providerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NolonCoreCLIError.invalidArguments("Missing required option: --target-path or --provider-id")
        }
        guard let template = resolveProviderTemplate(providerID: providerID) else {
            throw NolonCoreCLIError.invalidArguments("Unsupported --provider-id: \(providerID)")
        }
        switch kind {
        case .workflow:
            return template.defaultCommandPath?.path ?? template.defaultWorkflowPath.path
        case .mcp:
            return template.defaultMcpConfigPath.deletingLastPathComponent().path
        }
    }

    private static func resolveProviderTemplate(providerID: String) -> ProviderTemplate? {
        let normalized = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == "codex-xcode" || normalized == "codexxcode" {
            return .codexXcode
        }
        return ProviderTemplate.allCases.first { template in
            let raw = template.rawValue.lowercased()
            let stable = template.providerID.lowercased()
            return normalized == raw || normalized == stable
        }
    }

    private static func resolveRepositoryFilePath(repositoryRoot: URL, path: String) -> String {
        if path.hasPrefix("/") {
            return STPath(path).url.path
        }
        return repositoryRoot.appendingPathComponent(path).standardizedFileURL.path
    }

    private static func resolveRepositoryInstallPath(
        kind: NolonRemoteCatalogKind,
        repositoryRoot: URL,
        path: String?,
        slug: String?,
        strictSelector: Bool,
        resources: NolonRepositoryResources
    ) throws -> RepositoryPathSelection {
        if let path, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return RepositoryPathSelection(
                path: resolveRepositoryFilePath(repositoryRoot: repositoryRoot, path: path),
                warnings: []
            )
        }
        guard let slug, !slug.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NolonCoreCLIError.invalidArguments("Missing required option: --path or --slug")
        }

        switch kind {
        case .skill:
            let skillMatches = resources.skillsDirectories.filter { $0.skillNames.contains(slug) }
            if skillMatches.count > 1, strictSelector {
                let candidates = skillMatches.map { "\($0.path)/\(slug)" }
                throw NolonCoreCLIError.invalidArguments(
                    "Ambiguous --slug '\(slug)' matched multiple files: \(candidates.joined(separator: ", "))"
                )
            }
            if let dir = skillMatches.first {
                let warnings: [String]
                if skillMatches.count > 1 {
                    warnings = ["Ambiguous --slug '\(slug)' matched multiple files; selected first: \(dir.path)/\(slug)"]
                } else {
                    warnings = []
                }
                return RepositoryPathSelection(
                    path: resolveRepositoryFilePath(
                        repositoryRoot: repositoryRoot,
                        path: "\(dir.path)/\(slug)"
                    ),
                    warnings: warnings
                )
            }
            return RepositoryPathSelection(
                path: resolveRepositoryFilePath(repositoryRoot: repositoryRoot, path: "skills/\(slug)"),
                warnings: []
            )
        case .workflow:
            if let matched = try matchResourcePath(
                slug: slug,
                candidates: resources.workflows.map(\.path),
                strictSelector: strictSelector
            ) {
                return RepositoryPathSelection(
                    path: resolveRepositoryFilePath(repositoryRoot: repositoryRoot, path: matched.path),
                    warnings: matched.warnings
                )
            }
        case .mcp:
            if let matched = try matchResourcePath(
                slug: slug,
                candidates: resources.mcps.map(\.path),
                strictSelector: strictSelector
            ) {
                return RepositoryPathSelection(
                    path: resolveRepositoryFilePath(repositoryRoot: repositoryRoot, path: matched.path),
                    warnings: matched.warnings
                )
            }
        }

        throw NolonCoreCLIError.invalidArguments("Unable to resolve --slug '\(slug)' in synced repository")
    }

    private static func matchResourcePath(
        slug: String,
        candidates: [String],
        strictSelector: Bool
    ) throws -> RepositoryPathSelection? {
        let normalized = slug.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let exact = candidates.first(where: { $0.lowercased() == normalized }) {
            return RepositoryPathSelection(path: exact, warnings: [])
        }
        let nameMatches = candidates.filter { STPath($0).url.lastPathComponent.lowercased() == normalized }
        if nameMatches.count > 1, strictSelector {
            throw NolonCoreCLIError.invalidArguments(
                "Ambiguous --slug '\(slug)' matched multiple files: \(nameMatches.joined(separator: ", "))"
            )
        }
        if let byName = nameMatches.first {
            let warnings: [String]
            if nameMatches.count > 1 {
                warnings = ["Ambiguous --slug '\(slug)' matched multiple files; selected first: \(byName)"]
            } else {
                warnings = []
            }
            return RepositoryPathSelection(path: byName, warnings: warnings)
        }
        let stemMatches = candidates.filter {
            let basename = STPath($0).url.lastPathComponent.lowercased()
            let stem = basename.split(separator: ".").dropLast().joined(separator: ".")
            return stem == normalized
        }
        if stemMatches.count > 1, strictSelector {
            throw NolonCoreCLIError.invalidArguments(
                "Ambiguous --slug '\(slug)' matched multiple files: \(stemMatches.joined(separator: ", "))"
            )
        }
        if let byStem = stemMatches.first {
            let warnings: [String]
            if stemMatches.count > 1 {
                warnings = ["Ambiguous --slug '\(slug)' matched multiple files; selected first: \(byStem)"]
            } else {
                warnings = []
            }
            return RepositoryPathSelection(path: byStem, warnings: warnings)
        }
        return nil
    }
}

private struct RepositoryPathSelection: Sendable {
    let path: String
    let warnings: [String]
}

private struct PlanPayload: Encodable, Sendable {
    let plan: NolonGitImportPlan
    let preflight: NolonGitSyncPreflight
}

private struct SyncPayload: Encodable, Sendable {
    let plan: NolonGitImportPlan
    let result: NolonGitSyncResult
    let resources: NolonRepositoryResources
}

private struct PreflightPayload: Encodable, Sendable {
    let result: NolonGitSyncPreflight
}

private func filterResources(_ resources: NolonRepositoryResources, kind: NolonResourceKind) -> NolonRepositoryResources {
    switch kind {
    case .workflow:
        return NolonRepositoryResources(
            skillsDirectories: [],
            workflows: resources.workflows,
            mcps: []
        )
    case .mcp:
        return NolonRepositoryResources(
            skillsDirectories: [],
            workflows: [],
            mcps: resources.mcps
        )
    }
}

private struct DiscoverPayload: Encodable, Sendable {
    let path: String
    let maxDepth: Int
    let directories: [NolonSkillsDirectoryCandidate]
}

private struct SkillInstallPayload: Encodable, Sendable {
    let result: NolonSkillInstallResult
}

private struct SkillUninstallPayload: Encodable, Sendable {
    let result: NolonSkillUninstallResult
}

private struct SkillMigrateScanPayload: Encodable, Sendable {
    let result: NolonSkillMigrateScanResult
}

private struct SkillMigrateApplyPayload: Encodable, Sendable {
    let result: NolonSkillInstallResult
}

private struct ParsePayload: Encodable, Sendable {
    let file: String
    let metadata: NolonSkillStandardMetadata?
}

private struct ResourceDiscoverPayload: Encodable, Sendable {
    let path: String
    let maxDepth: Int
    let resources: NolonRepositoryResources
}

private struct ResourceInstallPayload: Encodable, Sendable {
    let result: NolonResourceInstallResult
}

private struct ResourceUninstallPayload: Encodable, Sendable {
    let result: NolonResourceUninstallResult
}

private struct RemoteListPayload: Encodable, Sendable {
    let result: NolonRemoteListResult
}

private struct RemoteDownloadPayload: Encodable, Sendable {
    let result: NolonRemoteDownloadResult
}

private struct RemoteInstallPayload: Encodable, Sendable {
    let result: NolonRemoteInstallResult
}

private struct RemoteSyncInstallPayload: Encodable, Sendable {
    let plan: NolonGitImportPlan
    let result: NolonGitSyncResult
    let resources: NolonRepositoryResources
    let install: NolonRemoteSyncInstallResult
}
