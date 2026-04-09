import Foundation
import ProviderCatalog
import NolonResourceKit
import ProviderUsage
import CodexBarProviderCatalog
import SKProcessRunner
import STFilePath

extension NolonCoreCLIRunner {
    func formatResourceSyncText(
        kind: NolonResourceKind,
        plan: NolonGitImportPlan,
        result: NolonGitSyncResult,
        resources: NolonRepositoryResources
    ) -> String {
        let filtered = filterResources(resources, kind: kind)
        let count: Int = {
            switch kind {
            case .workflow: filtered.workflows.count
            case .mcp: filtered.mcps.count
            }
        }()
        var lines: [String] = []
        lines.append("\(kind.rawValue) sync: \(result.mode)")
        lines.append("source: \(plan.source)")
        lines.append("repo: \(plan.owner)/\(plan.repo)")
        lines.append("default_branch: \(result.defaultBranch ?? "-")")
        lines.append("credential_mode: \(result.credentialMode)")
        lines.append("updated_at: \(ISO8601DateFormatter().string(from: result.updatedAt))")
        lines.append("\(kind.rawValue)s_discovered: \(count)")
        lines.append("clone_path: \(plan.localClonePath)")
        return lines.joined(separator: "\n")
    }

    func executeSkillsList(
        provider: String?,
        includeEmpty: Bool,
        state: NolonProviderSkillStateKind?
    ) throws -> NolonSkillsListResult {
        let targets = try Self.resolveSkillsAddTargets(provider: provider)
        let globalSkillsPath = try Self.resolveNolonSkillsRootFolder()
        var items: [NolonSkillsListItem] = []
        items.reserveCapacity(targets.count * 4)
        var providersScanned = 0

        for target in targets {
            providersScanned += 1
            let providerFolder = STFolder(target.providerPath)
            guard providerFolder.isExists else {
                continue
            }
            let isDirectory = (try? providerFolder.url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDirectory else {
                if provider != nil {
                    throw NolonCoreCLIError.invalidArguments("Provider skills path is not a directory: \(target.providerPath)")
                }
                continue
            }

            let scan: NolonSkillMigrateScanResult
            do {
                scan = try service.scanProviderSkills(
                    providerPath: providerFolder,
                    globalSkillsPath: globalSkillsPath
                )
            } catch {
                if provider != nil {
                    throw error
                }
                continue
            }
            items.append(contentsOf: scan.states.map { state in
                NolonSkillsListItem(
                    providerID: target.providerID,
                    providerPath: target.providerPath,
                    skillID: state.skillID,
                    state: state.state,
                    path: state.path,
                    origin: readResourceOrigin(kind: .skill, identifier: state.skillID)
                )
            })
        }

        items.sort {
            if $0.providerID.caseInsensitiveCompare($1.providerID) == .orderedSame {
                return $0.skillID.caseInsensitiveCompare($1.skillID) == .orderedAscending
            }
            return $0.providerID.caseInsensitiveCompare($1.providerID) == .orderedAscending
        }

        let effectiveItems = state == nil ? items : items.filter { $0.state == state }
        let installedCount = effectiveItems.filter { $0.state == .installed }.count
        let orphanedCount = effectiveItems.filter { $0.state == .orphaned }.count
        let brokenCount = effectiveItems.filter { $0.state == .broken }.count

        return NolonSkillsListResult(
            providerFilter: provider,
            stateFilter: state,
            includeEmpty: includeEmpty,
            items: effectiveItems,
            summary: NolonSkillsListSummary(
                providerCount: providersScanned,
                itemCount: effectiveItems.count,
                installedCount: installedCount,
                orphanedCount: orphanedCount,
                brokenCount: brokenCount
            )
        )
    }

    func executeResourceList(
        kind: NolonResourceKind,
        provider: String?,
        includeEmpty: Bool,
        state: NolonProviderSkillStateKind?
    ) throws -> NolonSkillsListResult {
        if kind == .mcp {
            return try executeMCPList(provider: provider, includeEmpty: includeEmpty, state: state)
        }
        let targets = try Self.resolveResourceTargets(kind: kind, provider: provider)
        let cacheRoot = try Self.resolveNolonResourceCacheRootFolder(kind: kind)
        var items: [NolonSkillsListItem] = []
        var providersScanned = 0

        for target in targets {
            providersScanned += 1
            let providerFolder = STFolder(target.providerPath)
            guard providerFolder.isExists else { continue }
            let isDirectory = (try? providerFolder.url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
            guard isDirectory else { continue }

            let childNames = (try? FileManager.default.contentsOfDirectory(atPath: providerFolder.url.path)) ?? []
            for name in childNames {
                guard !name.hasPrefix(".") else { continue }
                let child = providerFolder.subpath(name)

                let stateKind: NolonProviderSkillStateKind
                let resolvedDestinationPath: String?
                if child.isSymbolicLink {
                    let destination = (try? FileManager.default.destinationOfSymbolicLink(atPath: child.url.path)) ?? ""
                    let resolved = WorkflowSourceResolver.resolveSymlinkDestination(
                        linkPath: child.url.path,
                        destination: destination
                    )
                    resolvedDestinationPath = resolved
                    let exists = STPath(resolved).isExists
                    if !exists {
                        stateKind = .broken
                    } else if cacheRoot.subpath(name).isExists {
                        stateKind = .installed
                    } else {
                        stateKind = .orphaned
                    }
                } else {
                    resolvedDestinationPath = nil
                    stateKind = cacheRoot.subpath(name).isExists ? .installed : .orphaned
                }

                let origin = readResourceOrigin(kind: kind == .workflow ? .workflow : .mcp, identifier: name)
                    ?? inferWorkflowOriginIfNeeded(
                        kind: kind,
                        itemPath: child.url.path,
                        resolvedDestinationPath: resolvedDestinationPath
                    )

                items.append(
                    NolonSkillsListItem(
                        providerID: target.providerID,
                        providerPath: target.providerPath,
                        skillID: name,
                        state: stateKind,
                        path: child.url.path,
                        origin: origin
                    )
                )
            }
        }

        items.sort {
            if $0.providerID.caseInsensitiveCompare($1.providerID) == .orderedSame {
                return $0.skillID.caseInsensitiveCompare($1.skillID) == .orderedAscending
            }
            return $0.providerID.caseInsensitiveCompare($1.providerID) == .orderedAscending
        }

        let effectiveItems = state == nil ? items : items.filter { $0.state == state }
        let installedCount = effectiveItems.filter { $0.state == .installed }.count
        let orphanedCount = effectiveItems.filter { $0.state == .orphaned }.count
        let brokenCount = effectiveItems.filter { $0.state == .broken }.count
        return NolonSkillsListResult(
            providerFilter: provider,
            stateFilter: state,
            includeEmpty: includeEmpty,
            items: effectiveItems,
            summary: NolonSkillsListSummary(
                providerCount: providersScanned,
                itemCount: effectiveItems.count,
                installedCount: installedCount,
                orphanedCount: orphanedCount,
                brokenCount: brokenCount
            )
        )
    }

    func executeMCPList(
        provider: String?,
        includeEmpty: Bool,
        state: NolonProviderSkillStateKind?
    ) throws -> NolonSkillsListResult {
        let targets = try Self.resolveMCPConfigTargets(provider: provider)
        var items: [NolonSkillsListItem] = []
        var providersScanned = 0

        for target in targets {
            providersScanned += 1
            if service is NolonLiveSkillsRepositoryService,
               let template = ProviderTemplate.resolve(providerID: target.providerID),
               let names = try? installedStatusService.installedMcpIDsStrict(provider: template.createProvider()),
               !names.isEmpty {
                items.append(contentsOf: names.sorted().map { serverName in
                    let persistedOrigin = readResourceOrigin(kind: .mcp, identifier: serverName)
                    let inferredOrigin = persistedOrigin ?? inferMcpOrigin(
                        serverName: serverName,
                        configPath: template.defaultMcpConfigPath.path
                    )
                    return NolonSkillsListItem(
                        providerID: target.providerID,
                        providerPath: template.defaultMcpConfigPath.path,
                        skillID: serverName,
                        state: .installed,
                        path: template.defaultMcpConfigPath.path,
                        origin: inferredOrigin
                    )
                })
                continue
            }
            do {
                let result = try service.listMcpServers(provider: target.providerID)
                items.append(contentsOf: result.items.map { server in
                    let persistedOrigin = readResourceOrigin(kind: .mcp, identifier: server.name)
                    let inferredOrigin = persistedOrigin ?? inferMcpOrigin(
                        serverName: server.name,
                        configPath: result.configPath
                    )
                    return NolonSkillsListItem(
                        providerID: target.providerID,
                        providerPath: result.configPath,
                        skillID: server.name,
                        state: .installed,
                        path: result.configPath,
                        origin: inferredOrigin
                    )
                })
            } catch {
                items.append(
                    NolonSkillsListItem(
                        providerID: target.providerID,
                        providerPath: target.providerPath,
                        skillID: URL(fileURLWithPath: target.providerPath).lastPathComponent,
                        state: .broken,
                        path: target.providerPath,
                        origin: nil
                    )
                )
            }
        }

        items.sort {
            if $0.providerID.caseInsensitiveCompare($1.providerID) == .orderedSame {
                return $0.skillID.caseInsensitiveCompare($1.skillID) == .orderedAscending
            }
            return $0.providerID.caseInsensitiveCompare($1.providerID) == .orderedAscending
        }

        let effectiveItems = state == nil ? items : items.filter { $0.state == state }
        let installedCount = effectiveItems.filter { $0.state == .installed }.count
        let orphanedCount = effectiveItems.filter { $0.state == .orphaned }.count
        let brokenCount = effectiveItems.filter { $0.state == .broken }.count

        return NolonSkillsListResult(
            providerFilter: provider,
            stateFilter: state,
            includeEmpty: includeEmpty,
            items: effectiveItems,
            summary: NolonSkillsListSummary(
                providerCount: providersScanned,
                itemCount: effectiveItems.count,
                installedCount: installedCount,
                orphanedCount: orphanedCount,
                brokenCount: brokenCount
            )
        )
    }

    func encodeSuccess<Payload: Encodable & Sendable>(command: String, data: Payload) throws -> String {
        let envelope = NolonCLISuccessEnvelope(command: command, data: data)
        return try encodeJSON(envelope)
    }

    func errorJSON(for error: NolonCoreCLIError) -> String {
        (try? encodeJSON(
            NolonCLIErrorEnvelope(
                code: error.code,
                message: error.errorDescription ?? "Unknown error",
                detail: error.detail
            )
        ))
            ?? "{\"ok\":false,\"error\":{\"code\":\"execution_failed\",\"message\":\"Unknown error\"}}"
    }

    func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    static func resolveSkillProviderPath(
        explicitProviderPath: String?,
        providerID: String?
    ) throws -> String {
        if let explicitProviderPath, !explicitProviderPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return explicitProviderPath
        }
        guard let providerID, !providerID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NolonCoreCLIError.invalidArguments("Missing required option: --provider-path or --provider-id")
        }
        guard let template = ProviderTemplate.resolve(providerID: providerID) else {
            throw NolonCoreCLIError.invalidArguments(unsupportedProviderHint(flag: "--provider-id", value: providerID))
        }
        return template.defaultSkillsPath.path
    }

    static func resolveResourceTargetPath(
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
        guard let template = ProviderTemplate.resolve(providerID: providerID) else {
            throw NolonCoreCLIError.invalidArguments(unsupportedProviderHint(flag: "--provider-id", value: providerID))
        }
        switch kind {
        case .workflow:
            return template.defaultCommandPath?.path ?? template.defaultWorkflowPath.path
        case .mcp:
            return template.defaultMcpConfigPath.deletingLastPathComponent().path
        }
    }

    static func unsupportedProviderHint(flag: String, value: String) -> String {
        "Unsupported \(flag): \(value). Run `nolon provider list` to view available providers."
    }

    func executeSkillsAdd(
        slug: String,
        provider: String?,
        version: String?,
        baseURL: String,
        installMethod: NolonSkillInstallMethod,
        repositoriesRoot: String,
        dryRun: Bool,
        outputMode: NolonCoreCLIOutputMode
    ) async throws -> SkillsAddExecutionOutput {
        let normalizedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSlug.isEmpty else {
            throw NolonCoreCLIError.invalidArguments("<slug> cannot be empty.")
        }

        let targets = try Self.resolveSkillsAddTargets(provider: provider)
        guard !targets.isEmpty else {
            throw NolonCoreCLIError.invalidArguments("No installed providers found. Use --provider to target one provider.")
        }

        let localMatches = findLocalSkillCandidates(slug: normalizedSlug, repositoriesRoot: repositoriesRoot)
        let source: NolonSkillsAddSourceKind
        let sourcePath: String
        let stagedSkillPath: STPath?
        var warnings: [String] = []

        if localMatches.count > 1 {
            throw NolonCoreCLIError.invalidArguments(
                "Ambiguous local slug '\(normalizedSlug)' matched multiple paths: \(localMatches.joined(separator: ", "))"
            )
        }

        if let localPath = localMatches.first {
            source = .local
            sourcePath = localPath
            if dryRun {
                stagedSkillPath = nil
            } else {
                stagedSkillPath = try Self.stageLocalSkillToCache(slug: normalizedSlug, sourcePath: STPath(localPath))
            }
            if version != nil {
                warnings.append("Ignored --version because local slug '\(normalizedSlug)' was found.")
            }
        } else {
            let item = try await resolveRemoteSkillExact(slug: normalizedSlug, baseURL: baseURL)
            guard let item else {
                throw NolonCoreCLIError.domainFailed(
                    code: "skill_not_found",
                    message: "Skill not found by slug: \(normalizedSlug)"
                )
            }
            source = .remote
            sourcePath = "\(baseURL)/skills/\(item.slug)"
            if dryRun {
                stagedSkillPath = nil
            } else {
                stagedSkillPath = try await stageRemoteSkillToCache(slug: item.slug, version: version, baseURL: baseURL)
            }
        }

        let cachePath: String = {
            if let stagedSkillPath {
                return stagedSkillPath.url.path
            }
            let skillsRoot = (try? Self.resolveNolonSkillsRootFolder()) ?? STFolder(NSHomeDirectory()).folder(".nolon/skills")
            return skillsRoot.subpath(normalizedSlug).url.path
        }()
        var targetResults: [NolonSkillsAddTargetResult] = []
        targetResults.reserveCapacity(targets.count)

        for target in targets {
            if dryRun {
                targetResults.append(
                    NolonSkillsAddTargetResult(
                        providerID: target.providerID,
                        providerPath: target.providerPath,
                        sourcePath: sourcePath,
                        installedPath: STFolder(target.providerPath).subpath(normalizedSlug).url.path,
                        status: .planned,
                        errorCode: nil,
                        errorMessage: nil
                    )
                )
                continue
            }
            do {
                let install = try service.installSkill(
                    skillPath: stagedSkillPath ?? STPath(sourcePath),
                    skillID: normalizedSlug,
                    providerPath: STFolder(target.providerPath),
                    installMethod: installMethod
                )
                targetResults.append(
                    NolonSkillsAddTargetResult(
                        providerID: target.providerID,
                        providerPath: target.providerPath,
                        sourcePath: stagedSkillPath?.url.path ?? sourcePath,
                        installedPath: install.targetPath,
                        status: .installed,
                        errorCode: nil,
                        errorMessage: nil
                    )
                )
            } catch {
                targetResults.append(
                    NolonSkillsAddTargetResult(
                        providerID: target.providerID,
                        providerPath: target.providerPath,
                        sourcePath: stagedSkillPath?.url.path ?? sourcePath,
                        installedPath: nil,
                        status: .failed,
                        errorCode: "install_failed",
                        errorMessage: error.localizedDescription
                    )
                )
            }
        }

        let failed = targetResults.filter { $0.status == .failed }.count
        let success = targetResults.count - failed
        let result = NolonSkillsAddResult(
            slug: normalizedSlug,
            source: source,
            cachedPath: cachePath,
            installMethod: installMethod,
            targets: targetResults,
            successCount: success,
            failureCount: failed,
            warnings: warnings,
            dryRun: dryRun
        )

        let output: String
        switch outputMode {
        case .json:
            output = try encodeSuccess(command: "skills.add", data: SkillsAddPayload(result: result))
        case .text:
            output = formatSkillsAddText(result)
        }
        return SkillsAddExecutionOutput(output: output, exitCode: failed > 0 ? 2 : 0)
    }

    func executeResourceAdd(
        kind: NolonResourceKind,
        slug: String,
        provider: String?,
        version: String?,
        baseURL: String,
        installMethod: NolonSkillInstallMethod,
        repositoriesRoot: String,
        dryRun: Bool,
        outputMode: NolonCoreCLIOutputMode
    ) async throws -> SkillsAddExecutionOutput {
        let normalizedSlug = slug.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedSlug.isEmpty else {
            throw NolonCoreCLIError.invalidArguments("<slug> cannot be empty.")
        }
        let targets = try Self.resolveResourceTargets(kind: kind, provider: provider)
        guard !targets.isEmpty else {
            throw NolonCoreCLIError.invalidArguments("No installed providers found. Use --provider to target one provider.")
        }

        let localMatches = findLocalResourceCandidates(kind: kind, slug: normalizedSlug, repositoriesRoot: repositoriesRoot)
        let source: NolonSkillsAddSourceKind
        let sourcePath: String
        let stagedPath: STPath?
        var warnings: [String] = []
        var cachedName = normalizedSlug

        if localMatches.count > 1 {
            throw NolonCoreCLIError.invalidArguments(
                "Ambiguous local slug '\(normalizedSlug)' matched multiple paths: \(localMatches.joined(separator: ", "))"
            )
        }

        if let localPath = localMatches.first {
            source = .local
            sourcePath = localPath
            cachedName = STPath(localPath).url.lastPathComponent
            if dryRun {
                stagedPath = nil
            } else {
                stagedPath = try Self.stageLocalResourceToCache(kind: kind, slug: normalizedSlug, sourcePath: STPath(localPath))
            }
            if version != nil {
                warnings.append("Ignored --version because local slug '\(normalizedSlug)' was found.")
            }
        } else {
            let item = try await resolveRemoteResourceExact(kind: kind, slug: normalizedSlug, baseURL: baseURL)
            guard let item else {
                throw NolonCoreCLIError.domainFailed(
                    code: "resource_not_found",
                    message: "\(kind.rawValue) not found by slug: \(normalizedSlug)"
                )
            }
            source = .remote
            sourcePath = "\(baseURL)/\(kind.rawValue)s/\(item.slug)"
            if dryRun {
                stagedPath = nil
            } else {
                stagedPath = try await stageRemoteResourceToCache(kind: kind, slug: item.slug, version: version, baseURL: baseURL)
                cachedName = stagedPath?.url.lastPathComponent ?? normalizedSlug
            }
        }

        let cachePath: String = {
            if let stagedPath { return stagedPath.url.path }
            let root = (try? Self.resolveNolonResourceCacheRootFolder(kind: kind)) ?? STFolder(NSHomeDirectory()).folder(".nolon").folder("\(kind.rawValue)s")
            return root.subpath(cachedName).url.path
        }()

        var targetResults: [NolonSkillsAddTargetResult] = []
        for target in targets {
            if dryRun {
                targetResults.append(
                    NolonSkillsAddTargetResult(
                        providerID: target.providerID,
                        providerPath: target.providerPath,
                        sourcePath: sourcePath,
                        installedPath: STFolder(target.providerPath).subpath(cachedName).url.path,
                        status: .planned,
                        errorCode: nil,
                        errorMessage: nil
                    )
                )
                continue
            }
            do {
                let install = try service.installResource(
                    kind: kind,
                    filePath: stagedPath ?? STPath(sourcePath),
                    resourceName: nil,
                    targetPath: STFolder(target.providerPath),
                    installMethod: installMethod
                )
                targetResults.append(
                    NolonSkillsAddTargetResult(
                        providerID: target.providerID,
                        providerPath: target.providerPath,
                        sourcePath: stagedPath?.url.path ?? sourcePath,
                        installedPath: install.targetPath,
                        status: .installed,
                        errorCode: nil,
                        errorMessage: nil
                    )
                )
            } catch {
                targetResults.append(
                    NolonSkillsAddTargetResult(
                        providerID: target.providerID,
                        providerPath: target.providerPath,
                        sourcePath: stagedPath?.url.path ?? sourcePath,
                        installedPath: nil,
                        status: .failed,
                        errorCode: "install_failed",
                        errorMessage: error.localizedDescription
                    )
                )
            }
        }

        let failed = targetResults.filter { $0.status == .failed }.count
        let success = targetResults.count - failed
        let result = NolonSkillsAddResult(
            slug: normalizedSlug,
            source: source,
            cachedPath: cachePath,
            installMethod: installMethod,
            targets: targetResults,
            successCount: success,
            failureCount: failed,
            warnings: warnings,
            dryRun: dryRun
        )

        let output: String
        switch outputMode {
        case .json:
            output = try encodeSuccess(command: "\(kind.rawValue).add", data: SkillsAddPayload(result: result))
        case .text:
            output = formatResourceAddText(kind: kind, result: result)
        }
        return SkillsAddExecutionOutput(output: output, exitCode: failed > 0 ? 2 : 0)
    }

    func findLocalResourceCandidates(kind: NolonResourceKind, slug: String, repositoriesRoot: String) -> [String] {
        let repositories = service.listLocalRepositories(
            repositoriesRoot: STFolder(repositoriesRoot),
            maxDepth: 6
        )
        var candidates: [String] = []
        var seen: Set<String> = []
        for repository in repositories {
            let resources = service.discoverRepositoryResources(at: STFolder(repository.path), maxDepth: 6)
            let paths: [String]
            switch kind {
            case .workflow:
                paths = resources.workflows.map(\.path)
            case .mcp:
                paths = resources.mcps.map(\.path)
            }
            if let match = try? Self.matchResourcePath(slug: slug, candidates: paths, strictSelector: false) {
                let path = URL(fileURLWithPath: repository.path, isDirectory: true)
                    .appendingPathComponent(match.path, isDirectory: false)
                    .standardizedFileURL
                    .path
                let candidate = STPath(path)
                guard candidate.isExists else { continue }
                if !seen.contains(path) {
                    seen.insert(path)
                    candidates.append(path)
                }
            }
        }
        return candidates.sorted()
    }

    func resolveRemoteResourceExact(kind: NolonResourceKind, slug: String, baseURL: String) async throws -> NolonRemoteCatalogItem? {
        let remoteKind: NolonRemoteCatalogKind = kind == .workflow ? .workflow : .mcp
        let result = try await service.listRemoteResources(
            kind: remoteKind,
            query: slug,
            limit: 50,
            baseURL: baseURL
        )
        return result.items.first { $0.slug == slug }
    }

    func stageRemoteResourceToCache(kind: NolonResourceKind, slug: String, version: String?, baseURL: String) async throws -> STPath {
        let remoteKind: NolonRemoteCatalogKind = kind == .workflow ? .workflow : .mcp
        let download = try await service.downloadRemoteResource(
            kind: remoteKind,
            slug: slug,
            version: version,
            baseURL: baseURL
        )
        let sourceFile = STFile(download.filePath)
        let cacheRoot = try Self.resolveNolonResourceCacheRootFolder(kind: kind)
        _ = cacheRoot.createIfNotExists()
        let fileName = sourceFile.url.lastPathComponent
        let target = cacheRoot.subpath(fileName)
        if target.isExists || target.isSymbolicLink {
            try target.delete()
        }
        try sourceFile.copy(to: target, isOverlay: true)
        let now = Date()
        try Self.writeResourceOrigin(
            kind: remoteKind,
            identifier: fileName,
            origin: NolonResourceOrigin(
                resourceKind: remoteKind,
                sourceType: .remote,
                sourceKind: .url,
                sourceRef: "\(baseURL)/\(kind.rawValue)s/\(slug)",
                sourceDisplay: "\(baseURL)/\(kind.rawValue)s/\(slug)",
                createdAt: now,
                updatedAt: now
            )
        )
        return STPath(target.url.path)
    }

    static func stageLocalResourceToCache(kind: NolonResourceKind, slug: String, sourcePath: STPath) throws -> STPath {
        let cacheRoot = try resolveNolonResourceCacheRootFolder(kind: kind)
        _ = cacheRoot.createIfNotExists()
        let fileName = sourcePath.url.lastPathComponent
        let target = cacheRoot.subpath(fileName)
        if target.isExists || target.isSymbolicLink {
            try target.delete()
        }
        try sourcePath.copy(to: target, isOverlay: true)
        let remoteKind: NolonRemoteCatalogKind = kind == .workflow ? .workflow : .mcp
        let now = Date()
        try writeResourceOrigin(
            kind: remoteKind,
            identifier: fileName,
            origin: NolonResourceOrigin(
                resourceKind: remoteKind,
                sourceType: .local,
                sourceKind: .path,
                sourceRef: sourcePath.url.path,
                sourceDisplay: sourcePath.url.path,
                createdAt: now,
                updatedAt: now,
                metadata: ["slug": slug]
            )
        )
        return STPath(target.url.path)
    }

    func findLocalSkillCandidates(slug: String, repositoriesRoot: String) -> [String] {
        let repositories = service.listLocalRepositories(
            repositoriesRoot: STFolder(repositoriesRoot),
            maxDepth: 6
        )
        var directCandidates: [String] = []
        var directSeen: Set<String> = []
        var aliasCandidates: [String] = []
        var aliasSeen: Set<String> = []
        let normalizedSlug = Self.normalizedSkillLookupKey(slug)

        for repository in repositories {
            let resources = service.discoverRepositoryResources(at: STFolder(repository.path), maxDepth: 6)
            var repositorySkillPaths: [String] = []
            var repositoryMatchedPaths: [String] = []
            for directory in resources.skillsDirectories {
                let directoryPath = URL(fileURLWithPath: repository.path, isDirectory: true)
                    .appendingPathComponent(directory.path, isDirectory: true)
                    .standardizedFileURL
                    .path
                let folderPath = STPath(directoryPath)
                guard folderPath.isFolderExists else { continue }
                let folder = STFolder(directoryPath)

                if let rootMatchPath = localSkillMatchPath(
                    in: folder,
                    fallbackDirectoryName: folder.url.lastPathComponent,
                    normalizedSlug: normalizedSlug
                ) {
                    let path = rootMatchPath.url.path
                    repositorySkillPaths.append(path)
                    repositoryMatchedPaths.append(path)
                } else if folder.file("SKILL.md").isExists {
                    repositorySkillPaths.append(folder.url.path)
                }

                guard let children = try? folder.folders() else { continue }
                for child in children {
                    if let matched = localSkillMatchPath(
                        in: child,
                        fallbackDirectoryName: child.url.lastPathComponent,
                        normalizedSlug: normalizedSlug
                    ) {
                        let path = matched.url.path
                        repositorySkillPaths.append(path)
                        repositoryMatchedPaths.append(path)
                    } else if child.file("SKILL.md").isExists {
                        repositorySkillPaths.append(child.url.path)
                    }
                }
            }

            for path in repositoryMatchedPaths {
                if !directSeen.contains(path) {
                    directSeen.insert(path)
                    directCandidates.append(path)
                }
            }

            if repositoryMatchedPaths.isEmpty,
               repositorySkillPaths.count == 1,
               let alias = Self.repositoryAlias(for: repository),
               Self.normalizedSkillLookupKey(alias) == normalizedSlug {
                let path = repositorySkillPaths[0]
                if !aliasSeen.contains(path) {
                    aliasSeen.insert(path)
                    aliasCandidates.append(path)
                }
            }
        }
        if !directCandidates.isEmpty {
            return directCandidates.sorted()
        }
        return aliasCandidates.sorted()
    }

    func localSkillMatchPath(
        in folder: STFolder,
        fallbackDirectoryName: String,
        normalizedSlug: String
    ) -> STPath? {
        let skillFile = folder.file("SKILL.md")
        guard skillFile.isExists else { return nil }

        if Self.normalizedSkillLookupKey(fallbackDirectoryName) == normalizedSlug {
            return STPath(folder.url.path)
        }

        guard let content = try? skillFile.read() else { return nil }
        guard let metadata = service.parseSkillMetadata(content: content, directoryName: fallbackDirectoryName) else {
            return nil
        }
        if Self.normalizedSkillLookupKey(metadata.name) == normalizedSlug {
            return STPath(folder.url.path)
        }
        return nil
    }

    static func normalizedSkillLookupKey(_ raw: String) -> String {
        let lowered = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let scalarView = lowered.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(scalarView))
    }

    static func repositoryAlias(for repository: NolonLocalRepositorySummary) -> String? {
        let rawName = repository.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if let atIndex = rawName.lastIndex(of: "@"), atIndex < rawName.endIndex {
            let afterAt = rawName[rawName.index(after: atIndex)...]
            if !afterAt.isEmpty {
                return String(afterAt)
            }
        }

        let lastPath = URL(fileURLWithPath: repository.path).lastPathComponent
        if let atIndex = lastPath.lastIndex(of: "@"), atIndex < lastPath.endIndex {
            let afterAt = lastPath[lastPath.index(after: atIndex)...]
            if !afterAt.isEmpty {
                return String(afterAt)
            }
        }
        return lastPath.isEmpty ? nil : lastPath
    }

    func resolveRemoteSkillExact(slug: String, baseURL: String) async throws -> NolonRemoteCatalogItem? {
        let result = try await service.listRemoteResources(
            kind: .skill,
            query: slug,
            limit: 50,
            baseURL: baseURL
        )
        return result.items.first { $0.slug == slug }
    }

    func stageRemoteSkillToCache(slug: String, version: String?, baseURL: String) async throws -> STPath {
        let download = try await service.downloadRemoteResource(
            kind: .skill,
            slug: slug,
            version: version,
            baseURL: baseURL
        )
        let skillsRoot = try Self.resolveNolonSkillsRootFolder()
        let stagedURL = try SkillsRepositoryFacade.stageRemoteSkillForInstall(
            downloadedFileURL: STPath(download.filePath).url,
            slug: slug,
            skillsRoot: skillsRoot.url
        )
        let stagedPath = STPath(stagedURL.path)
        let now = Date()
        try Self.writeResourceOrigin(
            kind: .skill,
            identifier: slug,
            origin: NolonResourceOrigin(
                resourceKind: .skill,
                sourceType: .remote,
                sourceKind: .url,
                sourceRef: "\(baseURL)/skills/\(slug)",
                sourceDisplay: "\(baseURL)/skills/\(slug)",
                createdAt: now,
                updatedAt: now
            )
        )
        return stagedPath
    }

    static func stageLocalSkillToCache(slug: String, sourcePath: STPath) throws -> STPath {
        let skillsRoot = try resolveNolonSkillsRootFolder()
        _ = skillsRoot.createIfNotExists()
        let target = skillsRoot.subpath(slug)
        if target.isExists || target.isSymbolicLink {
            try target.delete()
        }

        let sourceURL = sourcePath.url.standardizedFileURL
        let targetURL = target.url.standardizedFileURL
        if sourceURL.path != targetURL.path {
            try SkillContentMaterializer.copyMaterializingSymlinks(
                from: sourcePath,
                to: target
            )
        }
        let now = Date()
        try writeResourceOrigin(
            kind: .skill,
            identifier: slug,
            origin: NolonResourceOrigin(
                resourceKind: .skill,
                sourceType: .local,
                sourceKind: .path,
                sourceRef: sourcePath.url.path,
                sourceDisplay: sourcePath.url.path,
                createdAt: now,
                updatedAt: now
            )
        )
        return target
    }

    static func resolveNolonSkillsRootFolder(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> STFolder {
        let nolonHome: STFolder
        if let raw = environment["NOLON_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            let expanded = NSString(string: raw).expandingTildeInPath
            nolonHome = STFolder(expanded)
        } else {
            nolonHome = try STFolder(sanbox: .home).folder(".nolon")
        }
        return nolonHome.folder("skills")
    }

    static func resolveNolonResourceCacheRootFolder(
        kind: NolonResourceKind,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws -> STFolder {
        let nolonHome: STFolder
        if let raw = environment["NOLON_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            let expanded = NSString(string: raw).expandingTildeInPath
            nolonHome = STFolder(expanded)
        } else {
            nolonHome = try STFolder(sanbox: .home).folder(".nolon")
        }
        switch kind {
        case .workflow:
            return nolonHome.folder("workflows")
        case .mcp:
            return nolonHome.folder("mcps")
        }
    }

    static func defaultRepositoriesRootPath(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
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

    static func inferredRepositoryPath(
        fromGitURL gitURL: String,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> String? {
        guard let url = URL(string: gitURL),
              let host = url.host
        else { return nil }
        let comps = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard comps.count >= 2 else { return nil }
        let owner = comps[0]
        var repo = comps[1]
        if repo.hasSuffix(".git") {
            repo.removeLast(4)
        }
        let root = defaultRepositoriesRootPath(environment: environment)
        return STFolder(root).folder(host).subpath("\(owner)@\(repo)").url.path
    }

    static func inferredSource(fromGitURL gitURL: String) -> String? {
        guard let url = URL(string: gitURL) else { return nil }
        let comps = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard comps.count >= 2 else { return nil }
        var repo = comps[1]
        if repo.hasSuffix(".git") {
            repo.removeLast(4)
        }
        return "\(comps[0])/\(repo)"
    }

    func resolveSingleSearchInstallMatch(
        result: NolonRemoteListResult,
        query: String?,
        provider: String?,
        pick: Int?,
        kind: NolonRemoteCatalogKind
    ) throws -> NolonRemoteCatalogItem? {
        let commandNamespace: String = {
            switch kind {
            case .skill: return "skills"
            case .workflow: return "workflow"
            case .mcp: return "mcp"
            }
        }()
        let q = try validateInstallQuery(query, kind: kind, commandNamespace: commandNamespace)
        if result.items.isEmpty {
            let notFoundCode: String
            let notFoundLabel: String
            switch kind {
            case .skill:
                notFoundCode = "skill_not_found"
                notFoundLabel = "Skill"
            case .workflow:
                notFoundCode = "workflow_not_found"
                notFoundLabel = "Workflow"
            case .mcp:
                notFoundCode = "mcp_not_found"
                notFoundLabel = "MCP"
            }
            throw NolonCoreCLIError.domainFailed(
                code: notFoundCode,
                message: """
                \(notFoundLabel) not found by query: \(q). Try:
                - nolon \(commandNamespace) search \(q)
                - nolon \(commandNamespace) sync --source <owner/repo>
                """
            )
        }
        if let pick {
            let index = pick - 1
            guard index >= 0, index < result.items.count else {
                let providerPart: String
                if let provider, !provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    providerPart = " --provider \(provider)"
                } else {
                    providerPart = ""
                }
                let queryArg = Self.shellQuotedArgument(q)
                let reviewCommand = "nolon \(commandNamespace) search \(queryArg)\(providerPart)"
                let retryCommand = "nolon \(commandNamespace) search \(queryArg) --install --pick <1-\(result.items.count)>\(providerPart) --dry-run"
                throw NolonCoreCLIError.invalidArguments(
                    "--pick is out of range. received \(pick), available range: 1...\(result.items.count). Review candidates: \(reviewCommand). Then retry: \(retryCommand)"
                )
            }
            return result.items[index]
        }
        let normalizedQuery = Self.normalizedSlug(q)
        if let exact = result.items.first(where: { Self.normalizedSlug($0.slug) == normalizedQuery }) {
            return exact
        }
        guard result.items.count == 1 else {
            let maxCandidates = 8
            let candidates = Array(result.items.prefix(maxCandidates))
            let matches = candidates.enumerated().map { index, item in
                "[\(index + 1)] \(item.slug)"
            }.joined(separator: "; ")
            let first = result.items.first?.slug ?? "<slug>"
            let providerPart: String
            if let provider, !provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                providerPart = " --provider \(provider)"
            } else {
                providerPart = ""
            }
            let nextCommand = "nolon \(commandNamespace) search \(first) --install\(providerPart) --dry-run"
            let pickCommand = "nolon \(commandNamespace) search \(Self.shellQuotedArgument(q)) --install --pick 1\(providerPart) --dry-run"
            throw NolonCoreCLIError.invalidArguments(
                "--install requires exactly one match. refine query or use `nolon \(commandNamespace) add <slug>`. matches(\(candidates.count)): \(matches). Next: \(nextCommand). Or disambiguate with --pick: \(pickCommand)"
            )
        }
        return result.items[0]
    }

    @discardableResult
    func validateInstallQuery(
        _ query: String?,
        kind: NolonRemoteCatalogKind,
        commandNamespace: String? = nil
    ) throws -> String {
        let q = (query ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else {
            let namespace: String = commandNamespace ?? {
                switch kind {
                case .skill: return "skills"
                case .workflow: return "workflow"
                case .mcp: return "mcp"
                }
            }()
            throw NolonCoreCLIError.invalidArguments(
                """
                --install requires a non-empty query. Try:
                - nolon \(namespace) search <keyword> --install --dry-run
                - nolon \(namespace) search <keyword> --install --yes --provider codex
                - nolon \(namespace) search --query <text> --install --dry-run
                - nolon \(namespace) search --query <text> --install --yes --provider codex
                """
            )
        }
        return q
    }

    static func resolveSkillsAddTargets(provider: String?) throws -> [SkillsAddTarget] {
        if let provider, !provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let template = ProviderTemplate.resolve(providerID: provider) else {
                throw NolonCoreCLIError.invalidArguments(unsupportedProviderHint(flag: "--provider", value: provider))
            }
            return [SkillsAddTarget(providerID: template.providerID, providerPath: template.defaultSkillsPath.path)]
        }
        let templates = ProviderDiscoveryService().templatesWithInstalledCLI()
        return templates.map {
            SkillsAddTarget(providerID: $0.providerID, providerPath: $0.defaultSkillsPath.path)
        }
    }

    static func normalizedSlug(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    static func shellQuotedArgument(_ value: String) -> String {
        if value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil, !value.isEmpty {
            return value
        }
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    static func resolveResourceTargets(kind: NolonResourceKind, provider: String?) throws -> [SkillsAddTarget] {
        if let provider, !provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let template = ProviderTemplate.resolve(providerID: provider) else {
                throw NolonCoreCLIError.invalidArguments(unsupportedProviderHint(flag: "--provider", value: provider))
            }
            let providerPath: String
            switch kind {
            case .workflow:
                providerPath = template.defaultCommandPath?.path ?? template.defaultWorkflowPath.path
            case .mcp:
                providerPath = template.defaultMcpConfigPath.deletingLastPathComponent().path
            }
            return [SkillsAddTarget(providerID: template.providerID, providerPath: providerPath)]
        }
        let templates = ProviderDiscoveryService().templatesWithInstalledCLI()
        return templates.map { template in
            let providerPath: String
            switch kind {
            case .workflow:
                providerPath = template.defaultCommandPath?.path ?? template.defaultWorkflowPath.path
            case .mcp:
                providerPath = template.defaultMcpConfigPath.deletingLastPathComponent().path
            }
            return SkillsAddTarget(providerID: template.providerID, providerPath: providerPath)
        }
    }

    static func resolveMCPConfigTargets(provider: String?) throws -> [SkillsAddTarget] {
        if let provider, !provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let template = ProviderTemplate.resolve(providerID: provider) else {
                throw NolonCoreCLIError.invalidArguments(unsupportedProviderHint(flag: "--provider", value: provider))
            }
            return [SkillsAddTarget(providerID: template.providerID, providerPath: template.defaultMcpConfigPath.path)]
        }
        let templates = ProviderDiscoveryService().templatesWithInstalledCLI()
        return templates.map {
            SkillsAddTarget(providerID: $0.providerID, providerPath: $0.defaultMcpConfigPath.path)
        }
    }

    static func writeSkillOrigin(skillRoot: STPath, payload: [String: String]) throws {
        let skillFolder = STFolder(skillRoot.url.standardizedFileURL.path)
        let originFolder = STFolder(skillFolder.subpath(".nolon").url.path)
        _ = originFolder.createIfNotExists()
        let originFile = originFolder.subpath("origin.json")
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try STFile(originFile.url.path).overlay(with: data)
    }

    static func writeResourceOrigin(
        kind: NolonRemoteCatalogKind,
        identifier: String,
        origin: NolonResourceOrigin
    ) throws {
        if kind == .skill {
            let skillRoot = try resolveNolonSkillsRootFolder().subpath(identifier)
            let originFolder = STFolder(skillRoot.url.path).folder(".nolon")
            _ = originFolder.createIfNotExists()
            let originFile = originFolder.subpath("origin.json")
            let data = try encodePrettyJSON(origin)
            try STFile(originFile.url.path).overlay(with: data)
            return
        }
        let root = try resolveNolonResourceCacheRootFolder(kind: kind == .workflow ? .workflow : .mcp)
        let meta = root.folder(".nolon")
        _ = meta.createIfNotExists()
        let file = meta.subpath("\(identifier).origin.json")
        let data = try encodePrettyJSON(origin)
        try STFile(file.url.path).overlay(with: data)
    }

    static func removeResourceOrigin(
        kind: NolonRemoteCatalogKind,
        identifier: String
    ) throws {
        guard kind != .skill else { return }
        let root = try resolveNolonResourceCacheRootFolder(kind: kind == .workflow ? .workflow : .mcp)
        let file = root.folder(".nolon").subpath("\(identifier).origin.json")
        if file.isExists || file.isSymbolicLink {
            try file.delete()
        }
    }

    func buildWorkflowBindOrigin(
        sourceType: NolonResourceSourceType,
        sourceKind: NolonResourceSourceKind,
        sourceRef: String
    ) -> NolonResourceOrigin {
        let now = Date()
        return NolonResourceOrigin(
            resourceKind: .workflow,
            sourceType: sourceType,
            sourceKind: sourceKind,
            sourceRef: sourceRef,
            sourceDisplay: sourceRef,
            createdAt: now,
            updatedAt: now
        )
    }

    func readResourceOrigin(kind: NolonRemoteCatalogKind, identifier: String) -> NolonResourceOrigin? {
        if kind == .skill {
            guard let root = try? Self.resolveNolonSkillsRootFolder() else { return nil }
            let file = STFolder(root.subpath(identifier).url.path).folder(".nolon").subpath("origin.json")
            guard file.isExists else { return nil }
            if let data = try? Data(contentsOf: file.url),
               let origin = try? JSONDecoder().decode(NolonResourceOrigin.self, from: data) {
                return origin
            }
            if let data = try? Data(contentsOf: file.url),
               let payload = try? JSONSerialization.jsonObject(with: data) as? [String: String] {
                let sourceTypeRaw = payload["source_type"] ?? "unknown"
                let sourceRaw = payload["source"] ?? "-"
                let sourceType = NolonResourceSourceType(rawValue: sourceTypeRaw) ?? .unknown
                let sourceKind: NolonResourceSourceKind = sourceType == .remote ? .url : .path
                let now = Date()
                return NolonResourceOrigin(
                    resourceKind: .skill,
                    sourceType: sourceType,
                    sourceKind: sourceKind,
                    sourceRef: sourceRaw,
                    sourceDisplay: sourceRaw,
                    createdAt: now,
                    updatedAt: now
                )
            }
            return nil
        }
        guard let root = try? Self.resolveNolonResourceCacheRootFolder(kind: kind == .workflow ? .workflow : .mcp) else { return nil }
        let file = root.folder(".nolon").subpath("\(identifier).origin.json")
        guard file.isExists else { return nil }
        guard let data = try? Data(contentsOf: file.url) else { return nil }
        return try? JSONDecoder().decode(NolonResourceOrigin.self, from: data)
    }

    func inferWorkflowOriginIfNeeded(
        kind: NolonResourceKind,
        itemPath: String,
        resolvedDestinationPath: String?
    ) -> NolonResourceOrigin? {
        guard kind == .workflow else { return nil }
        let sourceKind = WorkflowSourceResolver.resolve(
            workflowPath: itemPath,
            resolvedPath: resolvedDestinationPath
        )
        let resolvedRef = resolvedDestinationPath ?? itemPath
        let now = Date()

        switch sourceKind {
        case .skill:
            return NolonResourceOrigin(
                resourceKind: .workflow,
                sourceType: .fromSkill,
                sourceKind: .skill,
                sourceRef: resolvedRef,
                sourceDisplay: resolvedRef,
                createdAt: now,
                updatedAt: now,
                metadata: ["inferred": "true"]
            )
        case .mcp:
            return NolonResourceOrigin(
                resourceKind: .workflow,
                sourceType: .fromMcp,
                sourceKind: .mcp,
                sourceRef: resolvedRef,
                sourceDisplay: resolvedRef,
                createdAt: now,
                updatedAt: now,
                metadata: ["inferred": "true"]
            )
        case .user:
            return NolonResourceOrigin(
                resourceKind: .workflow,
                sourceType: .fromWorkflow,
                sourceKind: .workflow,
                sourceRef: resolvedRef,
                sourceDisplay: resolvedRef,
                createdAt: now,
                updatedAt: now,
                metadata: ["inferred": "true"]
            )
        case .unknown:
            return nil
        }
    }

    func inferMcpOrigin(serverName: String, configPath: String) -> NolonResourceOrigin {
        let now = Date()
        let sourceRef = "\(configPath)#\(serverName)"
        return NolonResourceOrigin(
            resourceKind: .mcp,
            sourceType: .fromMcp,
            sourceKind: .mcp,
            sourceRef: sourceRef,
            sourceDisplay: sourceRef,
            createdAt: now,
            updatedAt: now,
            metadata: ["inferred": "true"]
        )
    }

    static func encodePrettyJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

}

struct RepositoryPathSelection: Sendable {
    let path: String
    let warnings: [String]
}

struct SkillsAddTarget: Sendable {
    let providerID: String
    let providerPath: String
}

struct SkillsAddExecutionOutput: Sendable {
    let output: String
    let exitCode: Int32
}

struct PlanPayload: Encodable, Sendable {
    let plan: NolonGitImportPlan
    let preflight: NolonGitSyncPreflight
}

struct SyncPayload: Encodable, Sendable {
    let plan: NolonGitImportPlan
    let result: NolonGitSyncResult
    let resources: NolonRepositoryResources
}

struct PreflightPayload: Encodable, Sendable {
    let result: NolonGitSyncPreflight
}

struct RepoListPayload: Encodable, Sendable {
    let repositoriesRoot: String
    let maxDepth: Int
    let repositories: [NolonLocalRepositorySummary]

    enum CodingKeys: String, CodingKey {
        case repositoriesRoot = "repositories_root"
        case maxDepth = "max_depth"
        case repositories
    }
}

struct SkillsListPayload: Encodable, Sendable {
    let result: NolonSkillsListResult
}

func filterResources(_ resources: NolonRepositoryResources, kind: NolonResourceKind) -> NolonRepositoryResources {
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

struct DiscoverPayload: Encodable, Sendable {
    let path: String
    let maxDepth: Int
    let directories: [NolonSkillsDirectoryCandidate]
}

struct SkillInstallPayload: Encodable, Sendable {
    let result: NolonSkillInstallResult
}

struct SkillUninstallPayload: Encodable, Sendable {
    let result: NolonSkillUninstallResult
}

struct SkillMigrateScanPayload: Encodable, Sendable {
    let result: NolonSkillMigrateScanResult
}

struct SkillMigrateApplyPayload: Encodable, Sendable {
    let result: NolonSkillInstallResult
}

struct ParsePayload: Encodable, Sendable {
    let file: String
    let metadata: NolonSkillStandardMetadata?
}

struct ResourceDiscoverPayload: Encodable, Sendable {
    let path: String
    let maxDepth: Int
    let resources: NolonRepositoryResources
}

struct ResourceInstallPayload: Encodable, Sendable {
    let result: NolonResourceInstallResult
}

struct ResourceUninstallPayload: Encodable, Sendable {
    let result: NolonResourceUninstallResult
}

struct MCPServersPayload: Encodable, Sendable {
    let result: NolonMcpServerListResult
}

struct MCPServerMutationPayload: Encodable, Sendable {
    let result: NolonMcpServerMutationResult
}

struct MCPCacheStatusPayload: Encodable, Sendable {
    let result: NolonMcpCacheStatusResult
}

struct MCPCacheMigratePayload: Encodable, Sendable {
    let result: NolonMcpCacheMigrateResult
}

struct RemoteListPayload: Encodable, Sendable {
    let result: NolonRemoteListResult
}

struct RemoteDownloadPayload: Encodable, Sendable {
    let result: NolonRemoteDownloadResult
}

struct RemoteInstallPayload: Encodable, Sendable {
    let result: NolonRemoteInstallResult
}

struct SkillsAddPayload: Encodable, Sendable {
    let result: NolonSkillsAddResult
}

struct RemoteSyncInstallPayload: Encodable, Sendable {
    let plan: NolonGitImportPlan
    let result: NolonGitSyncResult
    let resources: NolonRepositoryResources
    let install: NolonRemoteSyncInstallResult
}
