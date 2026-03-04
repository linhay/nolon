import Foundation
import ProviderCatalog
import NolonResourceKit
import SKProcessRunner
import STFilePath

public enum NolonCoreCLIOutputMode: Sendable {
    case text
    case json
}

public struct NolonCoreCLIRunner: Sendable {
    public typealias FileReader = @Sendable (String) throws -> String

    private static let pluginDescriptors: [PluginDescriptor] = [
        PluginDescriptor(
            id: "xcodemcpkit",
            displayName: "XcodeMCPKit",
            summary: "Xcode simulator and runtime MCP server integration.",
            serverName: "xcodemcpkit",
            serverCommand: "xcode-mcp-server",
            requiredBinaries: ["xcodemcpkit", "xcode-mcp-server"],
            capabilities: [.mcpGlobalInstall, .runtimeControl],
            runtimeStartCommand: "xcodemcpkit"
        ),
    ]

    private let service: any NolonSkillsRepositoryServing
    private let fileReader: FileReader
    private let installedStatusService = InstalledResourceStatusService()

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
        await execute(arguments: arguments, outputMode: .json)
    }

    public func execute(arguments: [String], outputMode: NolonCoreCLIOutputMode) async -> NolonCLIExecutionResult {
        do {
            let command = try NolonCoreCLIArgumentParser.parse(arguments)
            if case let .skillsAdd(slug, provider, version, baseURL, installMethod, repositoriesRoot, dryRun) = command {
                let add = try await executeSkillsAdd(
                    slug: slug,
                    provider: provider,
                    version: version,
                    baseURL: baseURL,
                    installMethod: installMethod,
                    repositoriesRoot: repositoriesRoot,
                    dryRun: dryRun,
                    outputMode: outputMode
                )
                return NolonCLIExecutionResult(exitCode: add.exitCode, stdout: add.output, stderr: "")
            }
            let success: String
            switch outputMode {
            case .text:
                success = try await executeCommandText(command)
            case .json:
                success = try await executeCommand(command)
            }
            return NolonCLIExecutionResult(exitCode: 0, stdout: success, stderr: "")
        } catch let error as NolonCoreCLIError {
            let normalized = normalizeError(error)
            let renderedError = renderError(normalized, outputMode: outputMode)
            return NolonCLIExecutionResult(exitCode: 2, stdout: "", stderr: renderedError)
        } catch {
            let wrapped = normalizeError(NolonCoreCLIError.executionFailed(error.localizedDescription))
            let renderedError = renderError(wrapped, outputMode: outputMode)
            return NolonCLIExecutionResult(exitCode: 2, stdout: "", stderr: renderedError)
        }
    }

    private func renderError(_ error: NolonCoreCLIError, outputMode: NolonCoreCLIOutputMode) -> String {
        switch outputMode {
        case .json:
            return errorJSON(for: error)
        case .text:
            if case let .syncFailed(code, message, detail) = error {
                let inferredRepoPath = Self.inferredRepositoryPath(fromGitURL: detail.gitURL) ?? "<repo-path>"
                let inferredSource = Self.inferredSource(fromGitURL: detail.gitURL) ?? "<owner/repo>"
                var lines = [
                    "Error [\(code)]",
                    message,
                ]
                if code == "git_pull_failed" {
                    let normalized = message.lowercased()
                    if normalized.contains("cannot fast-forward to multiple branches") {
                        lines.append("建议:")
                        lines.append("- 改用 rebase/merge（任选其一）:")
                        lines.append("  - `nolon skills sync --source \(inferredSource) --pull-strategy rebase`")
                        lines.append("  - `nolon workflow sync --source \(inferredSource) --pull-strategy rebase`")
                        lines.append("  - `nolon mcp sync --source \(inferredSource) --pull-strategy rebase`")
                        lines.append("- 先清理远端跟踪分支：`git -C \(inferredRepoPath) fetch --all --prune`")
                        lines.append("- 查看本地仓库索引：`nolon skills repo list --verbose`")
                    }
                }
                lines.append("git_url: \(detail.gitURL)")
                lines.append("source_hint: \(inferredSource)")
                lines.append("repo_path_hint: \(inferredRepoPath)")
                lines.append("pull_strategy: \(detail.pullStrategy.rawValue)")
                lines.append("credential_strategy: \(detail.credentialStrategy.rawValue)")
                return lines.joined(separator: "\n")
            }
            if error.code == "permission_denied" || error.code == "rate_limited" || error.code == "remote_catalog_unavailable" || error.code == "git_ref_conflict" {
                return """
                Error [\(error.code)]
                \(error.errorDescription ?? error.localizedDescription)
                """
            }
            return errorJSON(for: error)
        }
    }

    private func normalizeError(_ error: NolonCoreCLIError) -> NolonCoreCLIError {
        if case let .syncFailed(code, message, detail) = error,
           code == "git_pull_failed" {
            let normalizedSync = message.lowercased()
            if normalizedSync.contains("cannot lock ref"), normalizedSync.contains("unable to update local ref") {
                let inferredRepoPath = Self.inferredRepositoryPath(fromGitURL: detail.gitURL) ?? "<repo-path>"
                let inferredSource = Self.inferredSource(fromGitURL: detail.gitURL) ?? "<owner/repo>"
                return .domainFailed(
                    code: "git_ref_conflict",
                    message: """
                    检测到本地 Git 引用冲突（cannot lock ref / unable to update local ref）。
                    建议:
                    - 查看仓库目录：`nolon skills repo list --verbose`
                    - 在对应仓库执行：`git -C \(inferredRepoPath) fetch --all --prune`
                    - 若仍失败，删除冲突仓库后重试 sync（任选其一）:
                      - `rm -rf \(inferredRepoPath)` 后 `nolon skills sync --source \(inferredSource)`
                      - `rm -rf \(inferredRepoPath)` 后 `nolon workflow sync --source \(inferredSource)`
                      - `rm -rf \(inferredRepoPath)` 后 `nolon mcp sync --source \(inferredSource)`
                    参考仓库: \(detail.gitURL)
                    """
                )
            }
        }
        guard case let .executionFailed(message) = error else {
            return error
        }
        let normalized = message.lowercased()
        if normalized.contains("status 429") || normalized.contains("429 too many requests") {
            return .domainFailed(
                code: "rate_limited",
                message: "远端请求被限流（429）。请等待 30 秒后重试；若持续失败，检查 API 配额/令牌配置。可先执行 `nolon skills sync --source <owner/repo>` 更新本地仓库，再使用 `nolon skills add <slug> --dry-run` 走本地安装预览。"
            )
        }
        if normalized.contains("status 404") || normalized.contains("404 not found") {
            return .domainFailed(
                code: "remote_catalog_unavailable",
                message: """
                远端目录当前不可用或不支持该资源类型（404）。
                建议:
                - 先走本地源：`nolon skills sync --source <owner/repo>` / `nolon workflow sync --source <owner/repo>` / `nolon mcp sync --source <owner/repo>`
                - 再执行：`nolon skills add <slug> --provider codex --dry-run` / `nolon workflow add <slug> --provider codex --dry-run` / `nolon mcp add <slug> --provider codex --dry-run`
                """
            )
        }
        if normalized.contains("operation not permitted") || normalized.contains("permission denied") {
            return .domainFailed(
                code: "permission_denied",
                message: """
                权限不足（Operation not permitted）。请检查网络/目录访问权限后重试。
                建议: NOLON_HOME=/tmp/nolon-home nolon skills search <keyword>
                建议: 使用 `nolon skills list` 查看本地已安装技能。
                """
            )
        }
        return error
    }

    private func fetchRemoteResources(
        kind: NolonRemoteCatalogKind,
        query: String?,
        limit: Int,
        baseURL: String
    ) async throws -> NolonRemoteListResult {
        do {
            return try await service.listRemoteResources(
                kind: kind,
                query: query,
                limit: limit,
                baseURL: baseURL
            )
        } catch let error as NolonCoreCLIError {
            throw mapRemoteCatalogErrorIfNeeded(error, kind: kind) ?? error
        } catch {
            let wrapped = NolonCoreCLIError.executionFailed(error.localizedDescription)
            throw mapRemoteCatalogErrorIfNeeded(wrapped, kind: kind) ?? wrapped
        }
    }

    private func mapRemoteCatalogErrorIfNeeded(_ error: NolonCoreCLIError, kind: NolonRemoteCatalogKind) -> NolonCoreCLIError? {
        guard case let .executionFailed(message) = error else { return nil }
        let normalized = message.lowercased()
        guard normalized.contains("status 404") || normalized.contains("404 not found") else {
            return nil
        }
        let commandNamespace: String = {
            switch kind {
            case .skill: return "skills"
            case .workflow: return "workflow"
            case .mcp: return "mcp"
            }
        }()
        return .domainFailed(
            code: "remote_catalog_unavailable",
            message: """
            远端目录当前不可用或不支持该资源类型（404）。
            建议:
            - 先走本地源：`nolon \(commandNamespace) sync --source <owner/repo>`
            - 再执行：`nolon \(commandNamespace) add <slug> --provider codex --dry-run`
            - 检查本地状态：`nolon \(commandNamespace) list --verbose`
            - 查看本地仓库索引：`nolon skills repo list --verbose`
            """
        )
    }

    private func executeCommand(_ command: NolonCoreCLICommand) async throws -> String {
        switch command {
        case let .skillsList(provider, includeEmpty, state, _, _):
            let result = try executeSkillsList(provider: provider, includeEmpty: includeEmpty, state: state)
            return try encodeSuccess(command: command.commandID, data: SkillsListPayload(result: result))

        case let .skillsRepoList(repositoriesRoot, maxDepth, _):
            let repositories = service.listLocalRepositories(
                repositoriesRoot: STFolder(repositoriesRoot),
                maxDepth: maxDepth
            )
            return try encodeSuccess(
                command: command.commandID,
                data: RepoListPayload(
                    repositoriesRoot: repositoriesRoot,
                    maxDepth: maxDepth,
                    repositories: repositories
                )
            )

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

        case let .skillsSearch(query, limit, baseURL, install, provider, installMethod, pick, dryRun, _):
            if install {
                try validateInstallQuery(query, kind: .skill)
            }
            let result = try await fetchRemoteResources(
                kind: .skill,
                query: query,
                limit: limit,
                baseURL: baseURL
            )
            if !install {
                return try encodeSuccess(command: command.commandID, data: RemoteListPayload(result: result))
            }
            guard let selected = try resolveSingleSearchInstallMatch(result: result, query: query, provider: provider, pick: pick, kind: .skill) else {
                return try encodeSuccess(command: command.commandID, data: RemoteListPayload(result: result))
            }
            let add = try await executeSkillsAdd(
                slug: selected.slug,
                provider: provider,
                version: nil,
                baseURL: baseURL,
                installMethod: installMethod,
                repositoriesRoot: Self.defaultRepositoriesRootPath(),
                dryRun: dryRun,
                outputMode: .json
            )
            return add.output

        case let .skillsAdd(slug, provider, version, baseURL, installMethod, repositoriesRoot, dryRun):
            let add = try await executeSkillsAdd(
                slug: slug,
                provider: provider,
                version: version,
                baseURL: baseURL,
                installMethod: installMethod,
                repositoriesRoot: repositoriesRoot,
                dryRun: dryRun,
                outputMode: .json
            )
            return add.output

        case let .skillsParse(file, directoryName):
            let content = try fileReader(file)
            let metadata = service.parseSkillMetadata(content: content, directoryName: directoryName)
            return try encodeSuccess(
                command: command.commandID,
                data: ParsePayload(file: file, metadata: metadata)
            )

        case let .workflowList(provider, includeEmpty, state, _, _):
            let result = try executeResourceList(kind: .workflow, provider: provider, includeEmpty: includeEmpty, state: state)
            return try encodeSuccess(command: command.commandID, data: SkillsListPayload(result: result))

        case let .workflowSync(source, repositoriesRoot, accessToken, pullStrategy, credentialStrategy):
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
                data: SyncPayload(plan: plan, result: result, resources: filterResources(resources, kind: .workflow))
            )

        case let .workflowSearch(query, limit, baseURL, install, provider, installMethod, pick, dryRun, _):
            if install {
                try validateInstallQuery(query, kind: .workflow)
            }
            let result = try await fetchRemoteResources(
                kind: .workflow,
                query: query,
                limit: limit,
                baseURL: baseURL
            )
            if !install {
                return try encodeSuccess(command: command.commandID, data: RemoteListPayload(result: result))
            }
            guard let selected = try resolveSingleSearchInstallMatch(result: result, query: query, provider: provider, pick: pick, kind: .workflow) else {
                return try encodeSuccess(command: command.commandID, data: RemoteListPayload(result: result))
            }
            let add = try await executeResourceAdd(
                kind: .workflow,
                slug: selected.slug,
                provider: provider,
                version: nil,
                baseURL: baseURL,
                installMethod: installMethod,
                repositoriesRoot: Self.defaultRepositoriesRootPath(),
                dryRun: dryRun,
                outputMode: .json
            )
            return add.output

        case let .workflowAdd(slug, provider, version, baseURL, installMethod, repositoriesRoot, dryRun):
            let add = try await executeResourceAdd(
                kind: .workflow,
                slug: slug,
                provider: provider,
                version: version,
                baseURL: baseURL,
                installMethod: installMethod,
                repositoriesRoot: repositoriesRoot,
                dryRun: dryRun,
                outputMode: .json
            )
            return add.output

        case let .workflowRemove(resourceName, targetPath):
            let result = try service.uninstallResource(
                kind: .workflow,
                resourceName: resourceName,
                targetPath: STFolder(targetPath)
            )
            return try encodeSuccess(command: command.commandID, data: ResourceUninstallPayload(result: result))

        case let .workflowBindSkill(skillID, targetPath):
            let result = try service.bindWorkflowFromSkill(
                skillID: skillID,
                targetPath: STFolder(targetPath)
            )
            try Self.writeResourceOrigin(
                kind: .workflow,
                identifier: result.resourceName,
                origin: buildWorkflowBindOrigin(sourceType: .fromSkill, sourceKind: .skill, sourceRef: skillID)
            )
            return try encodeSuccess(command: command.commandID, data: ResourceInstallPayload(result: result))

        case let .workflowBindMcp(mcpName, targetPath):
            let result = try service.bindWorkflowFromMcp(
                mcpName: mcpName,
                targetPath: STFolder(targetPath)
            )
            try Self.writeResourceOrigin(
                kind: .workflow,
                identifier: result.resourceName,
                origin: buildWorkflowBindOrigin(sourceType: .fromMcp, sourceKind: .mcp, sourceRef: mcpName)
            )
            return try encodeSuccess(command: command.commandID, data: ResourceInstallPayload(result: result))

        case let .workflowUnbindSkill(skillID, targetPath):
            let result = try service.unbindWorkflowFromSkill(
                skillID: skillID,
                targetPath: STFolder(targetPath)
            )
            try Self.removeResourceOrigin(kind: .workflow, identifier: result.resourceName)
            return try encodeSuccess(command: command.commandID, data: ResourceUninstallPayload(result: result))

        case let .workflowUnbindMcp(mcpName, targetPath):
            let result = try service.unbindWorkflowFromMcp(
                mcpName: mcpName,
                targetPath: STFolder(targetPath)
            )
            try Self.removeResourceOrigin(kind: .workflow, identifier: result.resourceName)
            return try encodeSuccess(command: command.commandID, data: ResourceUninstallPayload(result: result))

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

        case let .mcpList(provider, includeEmpty, state, _, _):
            let result = try executeResourceList(kind: .mcp, provider: provider, includeEmpty: includeEmpty, state: state)
            return try encodeSuccess(command: command.commandID, data: SkillsListPayload(result: result))

        case let .mcpSync(source, repositoriesRoot, accessToken, pullStrategy, credentialStrategy):
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
                data: SyncPayload(plan: plan, result: result, resources: filterResources(resources, kind: .mcp))
            )

        case let .mcpSearch(query, limit, baseURL, install, provider, installMethod, pick, dryRun, _):
            if install {
                try validateInstallQuery(query, kind: .mcp)
            }
            let result = try await fetchRemoteResources(
                kind: .mcp,
                query: query,
                limit: limit,
                baseURL: baseURL
            )
            if !install {
                return try encodeSuccess(command: command.commandID, data: RemoteListPayload(result: result))
            }
            guard let selected = try resolveSingleSearchInstallMatch(result: result, query: query, provider: provider, pick: pick, kind: .mcp) else {
                return try encodeSuccess(command: command.commandID, data: RemoteListPayload(result: result))
            }
            let add = try await executeResourceAdd(
                kind: .mcp,
                slug: selected.slug,
                provider: provider,
                version: nil,
                baseURL: baseURL,
                installMethod: installMethod,
                repositoriesRoot: Self.defaultRepositoriesRootPath(),
                dryRun: dryRun,
                outputMode: .json
            )
            return add.output

        case let .mcpAdd(slug, provider, version, baseURL, installMethod, repositoriesRoot, dryRun):
            let add = try await executeResourceAdd(
                kind: .mcp,
                slug: slug,
                provider: provider,
                version: version,
                baseURL: baseURL,
                installMethod: installMethod,
                repositoriesRoot: repositoriesRoot,
                dryRun: dryRun,
                outputMode: .json
            )
            return add.output

        case let .mcpRemove(resourceName, targetPath):
            let result = try service.uninstallResource(
                kind: .mcp,
                resourceName: resourceName,
                targetPath: STFolder(targetPath)
            )
            return try encodeSuccess(command: command.commandID, data: ResourceUninstallPayload(result: result))

        case let .mcpServerList(provider):
            let result = try service.listMcpServers(provider: provider)
            return try encodeSuccess(command: command.commandID, data: MCPServersPayload(result: result))

        case let .mcpServerSetEnabled(provider, name, enabled):
            let result = try service.setMcpServerEnabled(provider: provider, name: name, enabled: enabled)
            return try encodeSuccess(command: command.commandID, data: MCPServerMutationPayload(result: result))

        case let .mcpServerUpsert(provider, name, url, commandValue, args, env, enabled):
            let result = try service.upsertMcpServer(
                provider: provider,
                name: name,
                url: url,
                command: commandValue,
                args: args,
                env: env,
                enabled: enabled
            )
            return try encodeSuccess(command: command.commandID, data: MCPServerMutationPayload(result: result))

        case let .mcpServerRemove(provider, name):
            let result = try service.removeMcpServer(provider: provider, name: name)
            return try encodeSuccess(command: command.commandID, data: MCPServerMutationPayload(result: result))

        case let .mcpCacheMigrate(provider, overwrite):
            let result = try service.migrateMcpServersToCache(provider: provider, overwrite: overwrite)
            return try encodeSuccess(command: command.commandID, data: MCPCacheMigratePayload(result: result))

        case let .mcpCacheStatus(provider, name):
            let result = try service.mcpCacheStatus(provider: provider, name: name)
            return try encodeSuccess(command: command.commandID, data: MCPCacheStatusPayload(result: result))

        case let .mcpUninstall(resourceName, targetPath):
            let result = try service.uninstallResource(
                kind: .mcp,
                resourceName: resourceName,
                targetPath: STFolder(targetPath)
            )
            return try encodeSuccess(command: command.commandID, data: ResourceUninstallPayload(result: result))

        case .pluginList:
            let result = try await listPlugins()
            return try encodeSuccess(command: command.commandID, data: PluginListPayload(result: result))

        case let .pluginStatus(name):
            let result = try await pluginStatus(name: name)
            return try encodeSuccess(command: command.commandID, data: PluginStatusPayload(result: result))

        case let .pluginInstall(name, provider, version, force):
            let result = try await installPlugin(
                name: name,
                provider: provider,
                version: version,
                force: force
            )
            return try encodeSuccess(command: command.commandID, data: PluginMutationPayload(result: result))

        case let .pluginUninstall(name, provider, force):
            let result = try await uninstallPlugin(
                name: name,
                provider: provider,
                force: force
            )
            return try encodeSuccess(command: command.commandID, data: PluginMutationPayload(result: result))

        case let .pluginUpgrade(name, provider, toVersion, force):
            let result = try await upgradePlugin(
                name: name,
                provider: provider,
                toVersion: toVersion,
                force: force
            )
            return try encodeSuccess(command: command.commandID, data: PluginMutationPayload(result: result))

        case let .pluginStart(name, forceRestart):
            let result = try startPlugin(name: name, forceRestart: forceRestart)
            return try encodeSuccess(command: command.commandID, data: PluginRuntimePayload(result: result))

        case let .pluginStop(name, force):
            let result = try stopPlugin(name: name, force: force)
            return try encodeSuccess(command: command.commandID, data: PluginRuntimePayload(result: result))

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

    private func executeCommandText(_ command: NolonCoreCLICommand) async throws -> String {
        switch command {
        case let .skillsList(provider, includeEmpty, state, verbose, showFixes):
            let result = try executeSkillsList(provider: provider, includeEmpty: includeEmpty, state: state)
            return formatSkillsListText(result, verbose: verbose, showFixes: showFixes)
        case let .skillsRepoList(repositoriesRoot, maxDepth, verbose):
            let repositories = service.listLocalRepositories(
                repositoriesRoot: STFolder(repositoriesRoot),
                maxDepth: maxDepth
            )
            return formatSkillsRepoListText(
                repositoriesRoot: repositoriesRoot,
                repositories: repositories,
                verbose: verbose
            )
        case let .skillsSearch(query, limit, baseURL, install, provider, installMethod, pick, dryRun, _):
            if install {
                try validateInstallQuery(query, kind: .skill)
            }
            let result = try await fetchRemoteResources(
                kind: .skill,
                query: query,
                limit: limit,
                baseURL: baseURL
            )
            if install {
                guard let selected = try resolveSingleSearchInstallMatch(result: result, query: query, provider: provider, pick: pick, kind: .skill) else {
                    return formatSkillsSearchText(result)
                }
                let add = try await executeSkillsAdd(
                    slug: selected.slug,
                    provider: provider,
                    version: nil,
                    baseURL: baseURL,
                    installMethod: installMethod,
                    repositoriesRoot: Self.defaultRepositoriesRootPath(),
                    dryRun: dryRun,
                    outputMode: .text
                )
                return add.output
            }
            return formatSkillsSearchText(result)
        case let .skillsAdd(slug, provider, version, baseURL, installMethod, repositoriesRoot, dryRun):
            let add = try await executeSkillsAdd(
                slug: slug,
                provider: provider,
                version: version,
                baseURL: baseURL,
                installMethod: installMethod,
                repositoriesRoot: repositoriesRoot,
                dryRun: dryRun,
                outputMode: .text
            )
            return add.output
        case let .workflowList(provider, includeEmpty, state, verbose, showFixes):
            let result = try executeResourceList(kind: .workflow, provider: provider, includeEmpty: includeEmpty, state: state)
            return formatResourceListText(kind: .workflow, result, verbose: verbose, showFixes: showFixes)
        case let .workflowSearch(query, limit, baseURL, install, provider, installMethod, pick, dryRun, _):
            if install {
                try validateInstallQuery(query, kind: .workflow)
            }
            let result = try await fetchRemoteResources(
                kind: .workflow,
                query: query,
                limit: limit,
                baseURL: baseURL
            )
            if install {
                guard let selected = try resolveSingleSearchInstallMatch(result: result, query: query, provider: provider, pick: pick, kind: .workflow) else {
                    return formatResourceSearchText(kind: .workflow, result: result)
                }
                let add = try await executeResourceAdd(
                    kind: .workflow,
                    slug: selected.slug,
                    provider: provider,
                    version: nil,
                    baseURL: baseURL,
                    installMethod: installMethod,
                    repositoriesRoot: Self.defaultRepositoriesRootPath(),
                    dryRun: dryRun,
                    outputMode: .text
                )
                return add.output
            }
            return formatResourceSearchText(kind: .workflow, result: result)
        case let .workflowAdd(slug, provider, version, baseURL, installMethod, repositoriesRoot, dryRun):
            let add = try await executeResourceAdd(
                kind: .workflow,
                slug: slug,
                provider: provider,
                version: version,
                baseURL: baseURL,
                installMethod: installMethod,
                repositoriesRoot: repositoriesRoot,
                dryRun: dryRun,
                outputMode: .text
            )
            return add.output
        case let .workflowBindSkill(skillID, targetPath):
            let result = try service.bindWorkflowFromSkill(
                skillID: skillID,
                targetPath: STFolder(targetPath)
            )
            try Self.writeResourceOrigin(
                kind: .workflow,
                identifier: result.resourceName,
                origin: buildWorkflowBindOrigin(sourceType: .fromSkill, sourceKind: .skill, sourceRef: skillID)
            )
            return formatWorkflowBindText(result: result, sourceLabel: "skill", sourceID: skillID)
        case let .workflowBindMcp(mcpName, targetPath):
            let result = try service.bindWorkflowFromMcp(
                mcpName: mcpName,
                targetPath: STFolder(targetPath)
            )
            try Self.writeResourceOrigin(
                kind: .workflow,
                identifier: result.resourceName,
                origin: buildWorkflowBindOrigin(sourceType: .fromMcp, sourceKind: .mcp, sourceRef: mcpName)
            )
            return formatWorkflowBindText(result: result, sourceLabel: "mcp", sourceID: mcpName)
        case let .workflowUnbindSkill(skillID, targetPath):
            let result = try service.unbindWorkflowFromSkill(
                skillID: skillID,
                targetPath: STFolder(targetPath)
            )
            try Self.removeResourceOrigin(kind: .workflow, identifier: result.resourceName)
            return formatWorkflowUnbindText(result: result, sourceLabel: "skill", sourceID: skillID)
        case let .workflowUnbindMcp(mcpName, targetPath):
            let result = try service.unbindWorkflowFromMcp(
                mcpName: mcpName,
                targetPath: STFolder(targetPath)
            )
            try Self.removeResourceOrigin(kind: .workflow, identifier: result.resourceName)
            return formatWorkflowUnbindText(result: result, sourceLabel: "mcp", sourceID: mcpName)
        case let .workflowSync(source, repositoriesRoot, accessToken, pullStrategy, credentialStrategy):
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
            return formatResourceSyncText(kind: .workflow, plan: plan, result: result, resources: resources)
        case let .mcpList(provider, includeEmpty, state, verbose, showFixes):
            let result = try executeResourceList(kind: .mcp, provider: provider, includeEmpty: includeEmpty, state: state)
            return formatResourceListText(kind: .mcp, result, verbose: verbose, showFixes: showFixes)
        case let .mcpSearch(query, limit, baseURL, install, provider, installMethod, pick, dryRun, _):
            if install {
                try validateInstallQuery(query, kind: .mcp)
            }
            let result = try await fetchRemoteResources(
                kind: .mcp,
                query: query,
                limit: limit,
                baseURL: baseURL
            )
            if install {
                guard let selected = try resolveSingleSearchInstallMatch(result: result, query: query, provider: provider, pick: pick, kind: .mcp) else {
                    return formatResourceSearchText(kind: .mcp, result: result)
                }
                let add = try await executeResourceAdd(
                    kind: .mcp,
                    slug: selected.slug,
                    provider: provider,
                    version: nil,
                    baseURL: baseURL,
                    installMethod: installMethod,
                    repositoriesRoot: Self.defaultRepositoriesRootPath(),
                    dryRun: dryRun,
                    outputMode: .text
                )
                return add.output
            }
            return formatResourceSearchText(kind: .mcp, result: result)
        case let .mcpAdd(slug, provider, version, baseURL, installMethod, repositoriesRoot, dryRun):
            let add = try await executeResourceAdd(
                kind: .mcp,
                slug: slug,
                provider: provider,
                version: version,
                baseURL: baseURL,
                installMethod: installMethod,
                repositoriesRoot: repositoriesRoot,
                dryRun: dryRun,
                outputMode: .text
            )
            return add.output
        case let .mcpServerList(provider):
            let result = try service.listMcpServers(provider: provider)
            return formatMcpServerListText(result: result)
        case let .mcpServerSetEnabled(provider, name, enabled):
            let result = try service.setMcpServerEnabled(provider: provider, name: name, enabled: enabled)
            return formatMcpServerMutationText(result: result)
        case let .mcpServerUpsert(provider, name, url, commandValue, args, env, enabled):
            let result = try service.upsertMcpServer(
                provider: provider,
                name: name,
                url: url,
                command: commandValue,
                args: args,
                env: env,
                enabled: enabled
            )
            return formatMcpServerMutationText(result: result)
        case let .mcpServerRemove(provider, name):
            let result = try service.removeMcpServer(provider: provider, name: name)
            return formatMcpServerMutationText(result: result)
        case let .mcpCacheMigrate(provider, overwrite):
            let result = try service.migrateMcpServersToCache(provider: provider, overwrite: overwrite)
            return formatMcpCacheMigrateText(result: result, overwrite: overwrite)
        case let .mcpCacheStatus(provider, name):
            let result = try service.mcpCacheStatus(provider: provider, name: name)
            return formatMcpCacheStatusText(result: result, filterName: name)
        case let .mcpSync(source, repositoriesRoot, accessToken, pullStrategy, credentialStrategy):
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
            return formatResourceSyncText(kind: .mcp, plan: plan, result: result, resources: resources)
        case .pluginList:
            return formatPluginListText(result: try await listPlugins())
        case let .pluginStatus(name):
            return formatPluginStatusText(result: try await pluginStatus(name: name))
        case let .pluginInstall(name, provider, version, force):
            return formatPluginMutationText(result: try await installPlugin(name: name, provider: provider, version: version, force: force))
        case let .pluginUninstall(name, provider, force):
            return formatPluginMutationText(result: try await uninstallPlugin(name: name, provider: provider, force: force))
        case let .pluginUpgrade(name, provider, toVersion, force):
            return formatPluginMutationText(result: try await upgradePlugin(name: name, provider: provider, toVersion: toVersion, force: force))
        case let .pluginStart(name, forceRestart):
            return formatPluginRuntimeText(result: try startPlugin(name: name, forceRestart: forceRestart))
        case let .pluginStop(name, force):
            return formatPluginRuntimeText(result: try stopPlugin(name: name, force: force))
        default:
            return try await executeCommand(command)
        }
    }

    private func formatResourceSyncText(
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

    private func executeSkillsList(
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

    private func executeResourceList(
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

    private func executeMCPList(
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
        guard let template = ProviderTemplate.resolve(providerID: providerID) else {
            throw NolonCoreCLIError.invalidArguments(unsupportedProviderHint(flag: "--provider-id", value: providerID))
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

    private static func unsupportedProviderHint(flag: String, value: String) -> String {
        "Unsupported \(flag): \(value). Run `nolon provider list` to view available providers."
    }

    private func executeSkillsAdd(
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

    private func executeResourceAdd(
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

    private func findLocalResourceCandidates(kind: NolonResourceKind, slug: String, repositoriesRoot: String) -> [String] {
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

    private func resolveRemoteResourceExact(kind: NolonResourceKind, slug: String, baseURL: String) async throws -> NolonRemoteCatalogItem? {
        let remoteKind: NolonRemoteCatalogKind = kind == .workflow ? .workflow : .mcp
        let result = try await service.listRemoteResources(
            kind: remoteKind,
            query: slug,
            limit: 50,
            baseURL: baseURL
        )
        return result.items.first { $0.slug == slug }
    }

    private func stageRemoteResourceToCache(kind: NolonResourceKind, slug: String, version: String?, baseURL: String) async throws -> STPath {
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

    private static func stageLocalResourceToCache(kind: NolonResourceKind, slug: String, sourcePath: STPath) throws -> STPath {
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

    private func findLocalSkillCandidates(slug: String, repositoriesRoot: String) -> [String] {
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

    private func localSkillMatchPath(
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

    private static func normalizedSkillLookupKey(_ raw: String) -> String {
        let lowered = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        let scalarView = lowered.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        return String(String.UnicodeScalarView(scalarView))
    }

    private static func repositoryAlias(for repository: NolonLocalRepositorySummary) -> String? {
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

    private func resolveRemoteSkillExact(slug: String, baseURL: String) async throws -> NolonRemoteCatalogItem? {
        let result = try await service.listRemoteResources(
            kind: .skill,
            query: slug,
            limit: 50,
            baseURL: baseURL
        )
        return result.items.first { $0.slug == slug }
    }

    private func stageRemoteSkillToCache(slug: String, version: String?, baseURL: String) async throws -> STPath {
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

    private static func stageLocalSkillToCache(slug: String, sourcePath: STPath) throws -> STPath {
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

    private static func resolveNolonSkillsRootFolder(environment: [String: String] = ProcessInfo.processInfo.environment) throws -> STFolder {
        let nolonHome: STFolder
        if let raw = environment["NOLON_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            let expanded = NSString(string: raw).expandingTildeInPath
            nolonHome = STFolder(expanded)
        } else {
            nolonHome = try STFolder(sanbox: .home).folder(".nolon")
        }
        return nolonHome.folder("skills")
    }

    private static func resolveNolonResourceCacheRootFolder(
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

    private static func defaultRepositoriesRootPath(environment: [String: String] = ProcessInfo.processInfo.environment) -> String {
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

    private static func inferredRepositoryPath(
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

    private static func inferredSource(fromGitURL gitURL: String) -> String? {
        guard let url = URL(string: gitURL) else { return nil }
        let comps = url.pathComponents.filter { $0 != "/" && !$0.isEmpty }
        guard comps.count >= 2 else { return nil }
        var repo = comps[1]
        if repo.hasSuffix(".git") {
            repo.removeLast(4)
        }
        return "\(comps[0])/\(repo)"
    }

    private func resolveSingleSearchInstallMatch(
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
    private func validateInstallQuery(
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

    private static func resolveSkillsAddTargets(provider: String?) throws -> [SkillsAddTarget] {
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

    private static func normalizedSlug(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func shellQuotedArgument(_ value: String) -> String {
        if value.rangeOfCharacter(from: .whitespacesAndNewlines) == nil, !value.isEmpty {
            return value
        }
        let escaped = value.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    private static func resolveResourceTargets(kind: NolonResourceKind, provider: String?) throws -> [SkillsAddTarget] {
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

    private static func resolveMCPConfigTargets(provider: String?) throws -> [SkillsAddTarget] {
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

    private static func writeSkillOrigin(skillRoot: STPath, payload: [String: String]) throws {
        let skillFolder = STFolder(skillRoot.url.standardizedFileURL.path)
        let originFolder = STFolder(skillFolder.subpath(".nolon").url.path)
        _ = originFolder.createIfNotExists()
        let originFile = originFolder.subpath("origin.json")
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
        try STFile(originFile.url.path).overlay(with: data)
    }

    private static func writeResourceOrigin(
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

    private static func removeResourceOrigin(
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

    private func buildWorkflowBindOrigin(
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

    private func readResourceOrigin(kind: NolonRemoteCatalogKind, identifier: String) -> NolonResourceOrigin? {
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

    private func inferWorkflowOriginIfNeeded(
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

    private func inferMcpOrigin(serverName: String, configPath: String) -> NolonResourceOrigin {
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

    private static func encodePrettyJSON<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(value)
    }

    private func formatSkillsAddText(_ result: NolonSkillsAddResult) -> String {
        var lines: [String] = []
        if result.dryRun {
            lines.append("[DRY-RUN] No changes applied")
        }
        lines.append("skill: \(result.slug) (\(result.source.rawValue))")
        lines.append("cache: \(result.cachedPath)")
        lines.append("install_method: \(result.installMethod.rawValue)")
        if result.dryRun {
            lines.append("status: dry-run (no cache writes, no installation)")
        } else {
            lines.append("status: apply")
        }
        if let scope = Self.makeInstallScopeLabel(targets: result.targets) {
            lines.append("scope: \(scope)")
        }
        if result.dryRun {
            lines.append("result: planned=\(result.successCount), invalid=\(result.failureCount)")
        } else {
            lines.append("result: installed=\(result.successCount), failed=\(result.failureCount)")
        }
        if !result.warnings.isEmpty {
            lines.append("warnings:")
            lines.append(contentsOf: result.warnings.map { "- \($0)" })
        }
        if let safetyWarning = Self.makeMultiProviderSafetyWarning(targets: result.targets, dryRun: result.dryRun) {
            lines.append("safety:")
            lines.append("- \(safetyWarning)")
        }
        lines.append("targets:")
        lines.append(contentsOf: result.targets.map { target in
            let prefix: String
            switch target.status {
            case .installed:
                prefix = "[OK]"
            case .planned:
                prefix = "[PLAN]"
            case .failed:
                prefix = "[FAIL]"
            }
            if target.status == .installed || target.status == .planned {
                return "\(prefix) \(target.providerID) -> \(target.installedPath ?? "-")"
            }
            return "\(prefix) \(target.providerID) -> - (\(target.errorMessage ?? "install failed"))"
        })
        return lines.joined(separator: "\n")
    }

    private func formatWorkflowBindText(
        result: NolonResourceInstallResult,
        sourceLabel: String,
        sourceID: String
    ) -> String {
        [
            "workflow bind: success",
            "source: \(sourceLabel):\(sourceID)",
            "name: \(result.resourceName)",
            "global: \(result.sourcePath)",
            "target: \(result.targetPath)",
            "install_method: \(result.installMethod.rawValue)",
        ].joined(separator: "\n")
    }

    private func formatWorkflowUnbindText(
        result: NolonResourceUninstallResult,
        sourceLabel: String,
        sourceID: String
    ) -> String {
        [
            "workflow unbind: \(result.removed ? "success" : "noop")",
            "source: \(sourceLabel):\(sourceID)",
            "name: \(result.resourceName)",
            "target: \(result.targetPath)",
            "removed: \(result.removed)",
        ].joined(separator: "\n")
    }

    private func formatMcpServerListText(result: NolonMcpServerListResult) -> String {
        var lines: [String] = []
        lines.append("mcp server list")
        lines.append("provider: \(result.providerID)")
        lines.append("config: \(result.configPath)")
        lines.append("servers_total: \(result.items.count)")
        if result.items.isEmpty {
            lines.append("servers: (empty)")
            return lines.joined(separator: "\n")
        }
        lines.append("")
        lines.append("[servers]")
        for item in result.items {
            lines.append("- name: \(item.name)")
            lines.append("  enabled: \(item.enabled)")
            if let url = item.url, !url.isEmpty { lines.append("  url: \(url)") }
            if let command = item.command, !command.isEmpty { lines.append("  command: \(command)") }
            if let args = item.args, !args.isEmpty { lines.append("  args: \(args.joined(separator: " "))") }
            if let env = item.env, !env.isEmpty {
                let values = env.keys.sorted().map { "\($0)=\(env[$0] ?? "")" }.joined(separator: ", ")
                lines.append("  env: \(values)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private func formatMcpServerMutationText(result: NolonMcpServerMutationResult) -> String {
        [
            "mcp server mutation: success",
            "provider: \(result.providerID)",
            "config: \(result.configPath)",
            "name: \(result.name)",
            "action: \(result.action)",
        ].joined(separator: "\n")
    }

    private func formatMcpCacheMigrateText(result: NolonMcpCacheMigrateResult, overwrite: Bool) -> String {
        [
            "mcp cache migrate: success",
            "provider: \(result.providerID)",
            "config: \(result.configPath)",
            "overwrite: \(overwrite)",
            "migrated: \(result.migrated)",
            "updated: \(result.updated)",
            "skipped: \(result.skipped)",
        ].joined(separator: "\n")
    }

    private func formatMcpCacheStatusText(result: NolonMcpCacheStatusResult, filterName: String?) -> String {
        var lines: [String] = []
        lines.append("mcp cache status")
        lines.append("provider: \(result.providerID)")
        lines.append("config: \(result.configPath)")
        if let filterName, !filterName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append("filter: \(filterName)")
        }
        lines.append("servers_total: \(result.items.count)")
        if result.items.isEmpty {
            lines.append("servers: (empty)")
            return lines.joined(separator: "\n")
        }
        lines.append("")
        lines.append("[servers]")
        for item in result.items {
            lines.append("- name: \(item.name)")
            lines.append("  state: \(item.state.rawValue)")
            lines.append("  cache: \(item.cachePath)")
        }
        return lines.joined(separator: "\n")
    }

    static func makeInstallScopeLabel(targets: [NolonSkillsAddTargetResult]) -> String? {
        let providerIDs = Array(Set(targets.map(\.providerID))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        guard providerIDs.count > 1 else {
            return nil
        }
        return "multi-provider (\(providerIDs.count): \(providerIDs.joined(separator: ",")))"
    }

    static func makeMultiProviderSafetyWarning(
        targets: [NolonSkillsAddTargetResult],
        dryRun: Bool
    ) -> String? {
        let providerIDs = Array(Set(targets.map(\.providerID))).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        guard providerIDs.count > 1 else {
            return nil
        }
        let providerList = providerIDs.joined(separator: ",")
        if dryRun {
            return "未指定 --provider：当前预览将分发到 \(providerIDs.count) 个 providers（\(providerList)）。如仅安装单个目标，请使用 --provider <provider-id>。"
        }
        return "[WARN] 未指定 --provider：本次将安装到 \(providerIDs.count) 个 providers（\(providerList)）。如仅安装单个目标，请使用 --provider <provider-id>；建议先执行 --dry-run。"
    }

    private func formatSkillsRepoListText(
        repositoriesRoot: String,
        repositories: [NolonLocalRepositorySummary],
        verbose: Bool
    ) -> String {
        var lines: [String] = []
        lines.append("repositories_root: \(repositoriesRoot)")
        if repositories.isEmpty {
            lines.append("未发现本地仓库")
            return lines.joined(separator: "\n")
        }

        if verbose {
            let rows = repositories.map {
                [$0.name, $0.path, "\($0.skillsDirectoryCount)", "\($0.workflowCount)", "\($0.mcpCount)"]
            }
            lines.append(contentsOf: renderTable(headers: ["repo", "path", "skills", "workflows", "mcps"], rows: rows))
        } else {
            let rows = repositories.map {
                [$0.name, "\($0.skillsDirectoryCount)", "\($0.workflowCount)", "\($0.mcpCount)"]
            }
            lines.append(contentsOf: renderTable(headers: ["repo", "skills", "workflows", "mcps"], rows: rows))
        }
        return lines.joined(separator: "\n")
    }

    private func formatSkillsListText(_ result: NolonSkillsListResult, verbose: Bool, showFixes: Bool) -> String {
        let presenter = ResourceListTextPresenter()
        return presenter.render(
            makePresentationInput(
                kind: .skill,
                result: result,
                verbose: verbose,
                showFixes: showFixes
            )
        )
    }

    private func formatSkillsSearchText(_ result: NolonRemoteListResult) -> String {
        if result.items.isEmpty {
            return """
            未找到匹配 skill
            提示: 使用 `nolon skills sync --source <owner/repo>` 同步本地仓库后重试，或更换关键词。
            """
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let queryValue = result.query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let selection = SearchPresentationPolicy.select(
            query: queryValue,
            items: result.items,
            maxDisplayCount: 10,
            slug: \.slug
        )
        let exactMatch = selection.exactMatch
        let displayPool = selection.displayed
        let alternativeCandidates = selection.alternatives
        let showSummary = displayPool.count <= 8
        let queryPart = queryValue.isEmpty ? "" : " (query: \(queryValue))"
        let headline: String
        if let exactMatch {
            headline = "精确命中: \(exactMatch.slug)\(queryPart), candidates: \(result.items.count)"
        } else {
            headline = "匹配结果: \(result.items.count)\(queryPart)"
        }
        let maxDisplay = 10
        let displayedItems = Array(displayPool.prefix(maxDisplay))
        let lines = displayedItems.enumerated().map { index, item in
            let version = item.latestVersion ?? "-"
            let updated = item.updatedAt.map { formatUpdatedDate($0, formatter: formatter) } ?? "-"
            var itemLines: [String] = [
                "[\(index + 1)] \(item.slug)",
                "  version: \(version)",
                "  updated: \(updated)",
            ]
            if showSummary, let summary = compactSummary(item.summary, maxLength: 140) {
                itemLines.append("  summary: \(summary)")
            }
            return itemLines.joined(separator: "\n")
        }.joined(separator: "\n\n")
        let currentQueryExample = queryValue.isEmpty ? "<keyword>" : queryValue
        var hintParts: [String] = []
        if !showSummary {
            hintParts.append("已省略 summary（将 `--limit` 设为 8 或更小可查看摘要）")
        }
        if exactMatch == nil, result.items.count > displayedItems.count {
            hintParts.append("仅展示前 \(displayedItems.count) 条（可增大 `--limit` 查看更多）")
        }
        let hintBlock = hintParts.isEmpty ? "" : "提示: " + hintParts.joined(separator: "；") + "。\n"
        let alternativesBlock: String = {
            guard !alternativeCandidates.isEmpty else { return "" }
            let names = alternativeCandidates.prefix(5).map(\.slug).joined(separator: ", ")
            let suffix = alternativeCandidates.count > 5 ? " 等" : ""
            return "其他候选(\(alternativeCandidates.count)): \(names)\(suffix)\n"
        }()
        let installLines: [String]
        if let exactMatch {
            installLines = [
                "- nolon skills add \(exactMatch.slug) --provider codex --dry-run",
            ]
        } else if result.items.count == 1, let first = result.items.first {
            installLines = [
                "- nolon skills add \(first.slug) --provider codex --dry-run",
            ]
        } else {
            installLines = [
                "- nolon skills add <slug> --provider codex --dry-run",
                "- nolon skills search \(currentQueryExample) --install --pick <序号> --provider codex --dry-run",
            ]
        }
        let installBlock = installLines.joined(separator: "\n")
        return """
        \(headline)
        \(hintBlock)\(alternativesBlock)安装:
        \(installBlock)
        \(lines)
        """
    }

    private func formatResourceSearchText(kind: NolonResourceKind, result: NolonRemoteListResult) -> String {
        let presenter = RemoteSearchTextPresenter()
        let mappedKind: RemoteSearchPresentationKind = (kind == .workflow) ? .workflow : .mcp
        let input = RemoteSearchPresentationInput(
            kind: mappedKind,
            baseURL: result.baseURL,
            query: result.query,
            items: result.items.map {
                RemoteSearchPresentationItem(
                    slug: $0.slug,
                    summary: $0.summary,
                    latestVersion: $0.latestVersion,
                    updatedAt: $0.updatedAt
                )
            }
        )
        return presenter.render(input)
    }

    private func formatResourceAddText(kind: NolonResourceKind, result: NolonSkillsAddResult) -> String {
        var lines: [String] = []
        if result.dryRun {
            lines.append("[DRY-RUN] No changes applied")
        }
        lines.append("\(kind.rawValue): \(result.slug) (\(result.source.rawValue))")
        lines.append("cache: \(result.cachedPath)")
        lines.append("install_method: \(result.installMethod.rawValue)")
        lines.append("status: \(result.dryRun ? "dry-run (no cache writes, no installation)" : "apply")")
        if let scope = Self.makeInstallScopeLabel(targets: result.targets) {
            lines.append("scope: \(scope)")
        }
        if result.dryRun {
            lines.append("result: planned=\(result.successCount), invalid=\(result.failureCount)")
        } else {
            lines.append("result: installed=\(result.successCount), failed=\(result.failureCount)")
        }
        if !result.warnings.isEmpty {
            lines.append("warnings:")
            lines.append(contentsOf: result.warnings.map { "- \($0)" })
        }
        if let safety = Self.makeMultiProviderSafetyWarning(targets: result.targets, dryRun: result.dryRun) {
            lines.append("safety:")
            lines.append("- \(safety)")
        }
        lines.append(contentsOf: result.targets.map { target in
            let label: String
            switch target.status {
            case .planned:
                label = "[PLAN]"
            case .installed:
                label = "[OK]"
            case .failed:
                label = "[FAIL]"
            }
            var line = "\(label) \(target.providerID) -> \(target.installedPath ?? "-")"
            if let error = target.errorMessage, !error.isEmpty {
                line += " (\(error))"
            }
            return line
        })
        return lines.joined(separator: "\n")
    }

    private func formatResourceListText(
        kind: NolonResourceKind,
        _ result: NolonSkillsListResult,
        verbose: Bool,
        showFixes: Bool
    ) -> String {
        let presenter = ResourceListTextPresenter()
        let mappedKind: ResourceListPresentationKind = {
            switch kind {
            case .workflow: return .workflow
            case .mcp: return .mcp
            }
        }()
        return presenter.render(
            makePresentationInput(
                kind: mappedKind,
                result: result,
                verbose: verbose,
                showFixes: showFixes
            )
        )
    }

    private func makePresentationInput(
        kind: ResourceListPresentationKind,
        result: NolonSkillsListResult,
        verbose: Bool,
        showFixes: Bool
    ) -> ResourceListPresentationInput {
        ResourceListPresentationInput(
            kind: kind,
            providerFilter: result.providerFilter,
            stateFilter: result.stateFilter.map(toPresentationState),
            items: result.items.map { item in
                ResourceListPresentationItem(
                    providerID: item.providerID,
                    resourceID: item.skillID,
                    state: toPresentationState(item.state),
                    path: item.path,
                    originDescription: item.origin.flatMap { origin in
                        guard origin.sourceType != .unknown else { return nil }
                        return Self.originDescriptionForDisplay(origin)
                    }
                )
            },
            summary: ResourceListPresentationSummary(
                providersScanned: result.summary.providerCount,
                providersMatched: matchedProvidersCount(for: result),
                totalCount: result.summary.itemCount,
                installedCount: result.summary.installedCount,
                orphanedCount: result.summary.orphanedCount,
                brokenCount: result.summary.brokenCount
            ),
            verbose: verbose,
            showFixes: showFixes
        )
    }

    private func toPresentationState(_ state: NolonProviderSkillStateKind) -> ResourceListPresentationState {
        switch state {
        case .installed: return .installed
        case .orphaned: return .orphaned
        case .broken: return .broken
        }
    }

    static func buildResourceFixCommands(
        kind: NolonResourceKind,
        items: [NolonSkillsListItem]
    ) -> (simple: String, detailed: [String]) {
        let planItems = items.compactMap { toRepairItemIfNeeded($0) }
        let plan = ResourceRepairPlanner.plan(
            kind: toRepairResourceKind(kind),
            items: planItems
        )
        let detailed = plan.steps.flatMap(\.commands)
        return (simple: detailed.first ?? "", detailed: detailed)
    }

    static func buildSkillFixCommands(
        items: [NolonSkillsListItem]
    ) -> (simple: String, detailed: [String]) {
        let planItems = items.compactMap { toRepairItemIfNeeded($0) }
        let plan = ResourceRepairPlanner.plan(kind: .skill, items: planItems)
        let detailed = plan.steps.flatMap(\.commands)
        return (simple: detailed.first ?? "", detailed: detailed)
    }

    private static func toRepairResourceKind(_ kind: NolonResourceKind) -> RepairResourceKind {
        switch kind {
        case .workflow:
            return .workflow
        case .mcp:
            return .mcp
        }
    }

    private static func toRepairItemIfNeeded(_ item: NolonSkillsListItem) -> RepairItem? {
        switch item.state {
        case .orphaned, .broken:
            return toRepairItem(item)
        case .installed:
            return nil
        }
    }

    private static func toRepairItem(_ item: NolonSkillsListItem) -> RepairItem {
        let state: RepairStateKind = item.state == .broken ? .broken : .orphaned
        return RepairItem(providerID: item.providerID, resourceID: item.skillID, state: state)
    }

    private func matchedProvidersCount(for result: NolonSkillsListResult) -> Int {
        if let filter = result.providerFilter, !filter.isEmpty {
            return 1
        }
        return Set(result.items.map(\.providerID)).count
    }

    private func formatUpdatedDate(_ date: Date, formatter: DateFormatter) -> String {
        let rendered = formatter.string(from: date)
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let target = calendar.startOfDay(for: date)
        guard target > today else { return rendered }
        let dayDiff = calendar.dateComponents([.day], from: today, to: target).day ?? 0
        guard dayDiff > 0 else { return rendered }
        return "\(rendered) (future +\(dayDiff)d)"
    }

    private func compactSummary(_ raw: String?, maxLength: Int) -> String? {
        guard let raw else { return nil }
        let compact = raw
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !compact.isEmpty else { return nil }
        guard compact.count > maxLength else { return compact }
        let prefix = compact.prefix(max(0, maxLength - 3))
        return "\(prefix)..."
    }

    static func originDescriptionForDisplay(_ origin: NolonResourceOrigin) -> String {
        let sourceLabel = localizedSourceTypeLabel(origin.sourceType)
        let compactRef = compactSourceReference(origin.sourceRef)
        let inferredSuffix = origin.metadata["inferred"] == "true" ? " [推断]" : ""
        return "\(sourceLabel)(\(compactRef))\(inferredSuffix)"
    }

    private static func localizedSourceTypeLabel(_ type: NolonResourceSourceType) -> String {
        switch type {
        case .local:
            return "本地"
        case .remote:
            return "远端"
        case .fromSkill:
            return "技能"
        case .fromWorkflow:
            return "工作流"
        case .fromMcp:
            return "MCP"
        case .unknown:
            return "未知"
        }
    }

    private static func compactSourceReference(_ raw: String, maxLength: Int = 72) -> String {
        guard raw.count > maxLength else { return raw }
        let home = NSString(string: NSHomeDirectory()).expandingTildeInPath
        var normalized = raw
        if normalized.hasPrefix(home) {
            normalized = "~" + normalized.dropFirst(home.count)
        }
        guard normalized.count > maxLength else { return normalized }

        if let anchorIndex = normalized.lastIndex(of: "#") {
            let pathPart = String(normalized[..<anchorIndex])
            let anchor = String(normalized[anchorIndex...])
            return compactPath(pathPart, maxLength: max(24, maxLength - anchor.count)) + anchor
        }
        return compactPath(normalized, maxLength: maxLength)
    }

    private static func compactPath(_ path: String, maxLength: Int) -> String {
        guard path.count > maxLength else { return path }
        let headCount = max(12, (maxLength - 3) / 2)
        let tailCount = max(12, maxLength - 3 - headCount)
        let head = path.prefix(headCount)
        let tail = path.suffix(tailCount)
        return "\(head)...\(tail)"
    }

    private func renderTable(headers: [String], rows: [[String]]) -> [String] {
        guard !headers.isEmpty else { return [] }
        var widths = headers.map(\.count)
        for row in rows {
            for index in 0..<min(row.count, widths.count) {
                widths[index] = max(widths[index], row[index].count)
            }
        }
        func pad(_ value: String, _ width: Int) -> String {
            if value.count >= width { return value }
            return value + String(repeating: " ", count: width - value.count)
        }
        let header = zip(headers, widths).map { pad($0.0, $0.1) }.joined(separator: " | ")
        let separator = widths.map { String(repeating: "-", count: $0) }.joined(separator: "-|-")
        let body = rows.map { row in
            zip(row, widths).map { pad($0.0, $0.1) }.joined(separator: " | ")
        }
        return [header, separator] + body
    }

    private static func resolveRepositoryFilePath(repositoryRoot: URL, path: String) -> String {
        if path.hasPrefix("/") {
            return STPath(path).url.path
        }
        return repositoryRoot.appendingPathComponent(path).standardizedFileURL.path
    }

    private static func ensurePathWithinRepositoryRoot(_ resolvedPath: String, repositoryRoot: URL) throws {
        let rootPath = repositoryRoot.standardizedFileURL.path
        let candidatePath = STPath(resolvedPath).url.standardizedFileURL.path
        if candidatePath == rootPath { return }
        let rootWithSlash = rootPath.hasSuffix("/") ? rootPath : "\(rootPath)/"
        guard candidatePath.hasPrefix(rootWithSlash) else {
            throw NolonCoreCLIError.invalidArguments(
                "Resolved --path is outside synced repository root: \(resolvedPath)"
            )
        }
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
            let resolved = resolveRepositoryFilePath(repositoryRoot: repositoryRoot, path: path)
            try ensurePathWithinRepositoryRoot(resolved, repositoryRoot: repositoryRoot)
            return RepositoryPathSelection(path: resolved, warnings: [])
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

    private func listPlugins() async throws -> [NolonPluginStatusSnapshot] {
        var snapshots: [NolonPluginStatusSnapshot] = []
        snapshots.reserveCapacity(Self.pluginDescriptors.count)
        for descriptor in Self.pluginDescriptors {
            snapshots.append(try await pluginStatus(name: descriptor.id))
        }
        return snapshots
    }

    private func pluginStatus(name: String) async throws -> NolonPluginStatusSnapshot {
        let descriptor = try resolvePluginDescriptor(name: name)
        let metadataPath = Self.pluginVersionFilePath(pluginName: descriptor.id)
        let installedVersion = try Self.readPluginVersion(at: metadataPath)
        let releaseStatus: XcodeMCPKitUpgradeStatus
        if descriptor.id == "xcodemcpkit" {
            releaseStatus = await Self.checkPluginUpgradeStatus(installedVersion: installedVersion)
        } else {
            releaseStatus = XcodeMCPKitUpgradeStatus(
                installedVersion: installedVersion,
                latestVersion: nil,
                hasUpgrade: false,
                releaseURL: nil
            )
        }
        let globalPath = Self.pluginGlobalMcpFilePath(pluginID: descriptor.id)
        let marker = try Self.readPluginMarker(fromGlobalMcpPath: globalPath)
        let runtime = try Self.currentRuntimeSnapshot(for: descriptor)
        return NolonPluginStatusSnapshot(
            name: descriptor.id,
            provider: "global",
            installedVersion: installedVersion,
            latestVersion: releaseStatus.latestVersion,
            hasUpgrade: releaseStatus.hasUpgrade,
            isInstalled: marker.exists,
            binariesReady: Self.arePluginBinariesReady(for: descriptor),
            runtime: runtime,
            globalPath: globalPath,
            managedByPlugin: marker.managedByPlugin,
            markerPluginID: marker.pluginID
        )
    }

    private func installPlugin(
        name: String,
        provider: String,
        version: String?,
        force: Bool
    ) async throws -> NolonPluginMutationResult {
        let descriptor = try resolvePluginDescriptor(name: name)
        guard descriptor.capabilities.contains(.mcpGlobalInstall) else {
            throw NolonCoreCLIError.domainFailed(
                code: "plugin_capability_unsupported",
                message: "Plugin `\(descriptor.id)` does not support global MCP installation."
            )
        }
        guard Self.arePluginBinariesReady(for: descriptor) else {
            throw NolonCoreCLIError.domainFailed(
                code: "plugin_binary_missing",
                message: "Missing required binaries for plugin `\(descriptor.id)`."
            )
        }
        let globalPath = Self.pluginGlobalMcpFilePath(pluginID: descriptor.id)
        try Self.writePluginGlobalMcpFile(descriptor: descriptor, path: globalPath)

        let resolvedVersion: String?
        if let version, !version.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            resolvedVersion = version
        } else if descriptor.id == "xcodemcpkit" {
            let status = await Self.checkPluginUpgradeStatus(installedVersion: nil)
            resolvedVersion = status.latestVersion
        } else {
            resolvedVersion = nil
        }
        if let resolvedVersion {
            try Self.writePluginVersion(resolvedVersion, pluginName: descriptor.id)
        }
        let snapshot = try await pluginStatus(name: descriptor.id)
        let message = force ? "plugin installed (force overwrite global)" : "plugin installed"
        return NolonPluginMutationResult(
            action: "install",
            name: descriptor.id,
            provider: provider,
            success: true,
            message: message,
            version: snapshot.installedVersion,
            globalPath: snapshot.globalPath,
            managedByPlugin: snapshot.managedByPlugin,
            markerPluginID: snapshot.markerPluginID
        )
    }

    private func uninstallPlugin(
        name: String,
        provider: String,
        force: Bool
    ) async throws -> NolonPluginMutationResult {
        let descriptor = try resolvePluginDescriptor(name: name)
        guard descriptor.capabilities.contains(.mcpGlobalInstall) else {
            throw NolonCoreCLIError.domainFailed(
                code: "plugin_capability_unsupported",
                message: "Plugin `\(descriptor.id)` does not support global MCP uninstall."
            )
        }
        let globalPath = Self.pluginGlobalMcpFilePath(pluginID: descriptor.id)
        let marker = try Self.readPluginMarker(fromGlobalMcpPath: globalPath)
        if marker.exists {
            guard marker.managedByPlugin, marker.pluginID == descriptor.id else {
                throw NolonCoreCLIError.domainFailed(
                    code: "plugin_not_managed_by_nolon",
                    message: "Global MCP entry exists but is not managed by plugin `\(descriptor.id)`."
                )
            }
            if descriptor.capabilities.contains(.runtimeControl) {
                _ = try stopPlugin(name: descriptor.id, force: force)
            }
            try STFile(globalPath).delete()
        }
        try? STFile(Self.pluginVersionFilePath(pluginName: descriptor.id)).delete()

        let message = marker.exists ? "plugin uninstalled from global cache" : "plugin not installed in global cache"
        return NolonPluginMutationResult(
            action: "uninstall",
            name: descriptor.id,
            provider: provider,
            success: true,
            message: message,
            version: nil,
            globalPath: globalPath,
            managedByPlugin: false,
            markerPluginID: nil
        )
    }

    private func upgradePlugin(
        name: String,
        provider: String,
        toVersion: String?,
        force: Bool
    ) async throws -> NolonPluginMutationResult {
        let descriptor = try resolvePluginDescriptor(name: name)
        let targetVersion: String?
        if let toVersion, !toVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            targetVersion = toVersion
        } else if descriptor.id == "xcodemcpkit" {
            let current = try Self.readPluginVersion(at: Self.pluginVersionFilePath(pluginName: descriptor.id))
            let status = await Self.checkPluginUpgradeStatus(installedVersion: current)
            targetVersion = status.latestVersion
        } else {
            targetVersion = nil
        }
        let installResult = try await installPlugin(
            name: descriptor.id,
            provider: provider,
            version: targetVersion,
            force: force
        )
        return NolonPluginMutationResult(
            action: "upgrade",
            name: descriptor.id,
            provider: provider,
            success: true,
            message: "plugin upgraded",
            version: installResult.version,
            globalPath: installResult.globalPath,
            managedByPlugin: installResult.managedByPlugin,
            markerPluginID: installResult.markerPluginID
        )
    }

    private func startPlugin(name: String, forceRestart: Bool) throws -> NolonPluginRuntimeResult {
        let descriptor = try resolvePluginDescriptor(name: name)
        guard descriptor.capabilities.contains(.runtimeControl),
              let runtimeCommand = descriptor.runtimeStartCommand else {
            throw NolonCoreCLIError.domainFailed(
                code: "plugin_runtime_unsupported",
                message: "Plugin `\(descriptor.id)` does not support runtime control."
            )
        }
        guard Self.executablePath(named: runtimeCommand) != nil else {
            throw NolonCoreCLIError.domainFailed(
                code: "plugin_binary_missing",
                message: "Cannot find `\(runtimeCommand)` in PATH."
            )
        }
        if let current = try Self.waitForRunningServerPID(commandContains: runtimeCommand, timeoutMilliseconds: 400) {
            return NolonPluginRuntimeResult(
                action: "start",
                name: descriptor.id,
                state: "running",
                pid: current,
                message: "\(runtimeCommand) already running"
            )
        }
        let args = forceRestart ? ["--force-restart"] : []
        let pid = try Self.startDetachedProcess(command: runtimeCommand, arguments: args)
        let runningPID = try Self.waitForRunningServerPID(commandContains: runtimeCommand, timeoutMilliseconds: 800) ?? pid
        return NolonPluginRuntimeResult(
            action: "start",
            name: descriptor.id,
            state: "running",
            pid: runningPID,
            message: "\(runtimeCommand) started"
        )
    }

    private func stopPlugin(name: String, force: Bool) throws -> NolonPluginRuntimeResult {
        let descriptor = try resolvePluginDescriptor(name: name)
        guard descriptor.capabilities.contains(.runtimeControl),
              let runtimeCommand = descriptor.runtimeStartCommand else {
            throw NolonCoreCLIError.domainFailed(
                code: "plugin_runtime_unsupported",
                message: "Plugin `\(descriptor.id)` does not support runtime control."
            )
        }
        guard let pid = try Self.runningServerPID(commandContains: runtimeCommand) else {
            return NolonPluginRuntimeResult(
                action: "stop",
                name: descriptor.id,
                state: "stopped",
                pid: nil,
                message: "\(runtimeCommand) not running"
            )
        }
        let signal = force ? SIGKILL : SIGTERM
        _ = kill(pid_t(pid), signal)
        let stopped = try Self.waitForProcessExit(commandContains: runtimeCommand, expectedPID: pid, timeoutMilliseconds: 800)
        let message: String
        if force {
            message = stopped ? "sent SIGKILL" : "sent SIGKILL (still shutting down)"
        } else {
            message = stopped ? "sent SIGTERM" : "sent SIGTERM (still shutting down)"
        }
        return NolonPluginRuntimeResult(
            action: "stop",
            name: descriptor.id,
            state: "stopped",
            pid: pid,
            message: message
        )
    }

    private func resolvePluginDescriptor(name raw: String) throws -> PluginDescriptor {
        let normalized = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let descriptor = Self.pluginDescriptors.first(where: { $0.id == normalized }) {
            return descriptor
        }
        let supported = Self.pluginDescriptors.map(\.id).sorted().joined(separator: ", ")
        throw NolonCoreCLIError.invalidArguments("Unsupported plugin name: \(raw). Supported: \(supported)")
    }

    private static func arePluginBinariesReady(for descriptor: PluginDescriptor) -> Bool {
        descriptor.requiredBinaries.allSatisfy { executablePath(named: $0) != nil }
    }

    private static func executablePath(named name: String) -> String? {
        let fm = FileManager.default
        let pathEnv = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for raw in pathEnv.split(separator: ":") {
            let dir = String(raw)
            if dir.isEmpty { continue }
            let candidate = URL(fileURLWithPath: dir, isDirectory: true).appendingPathComponent(name).path
            if fm.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    private static func startDetachedProcess(command: String, arguments: [String]) throws -> Int {
        let commandLine = ([command] + arguments)
            .map(shellEscaped)
            .joined(separator: " ")
        let script = "nohup \(commandLine) >/dev/null 2>&1 & echo $!"

        var payload = SKProcessPayload.executableURL(STPath("/bin/sh").url)
        payload.arguments = ["-lc", script]
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 5_000

        let result = try SKProcessRunner.runSync(payload)
        guard result.exitCode == 0 else {
            let stderr = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw NolonCoreCLIError.executionFailed(stderr.isEmpty ? "failed to start detached process" : stderr)
        }

        let output = result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let line = output.split(separator: "\n").last,
              let pid = Int(line) else {
            throw NolonCoreCLIError.executionFailed("failed to parse detached process pid")
        }
        return pid
    }

    private static func shellEscaped(_ value: String) -> String {
        if value.isEmpty { return "''" }
        if value.range(of: #"^[A-Za-z0-9_@%+=:,./-]+$"#, options: .regularExpression) != nil {
            return value
        }
        return "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func runningServerPID(commandContains: String) throws -> Int? {
        let currentPID = Int(ProcessInfo.processInfo.processIdentifier)

        var pgrepPayload = SKProcessPayload.executableURL(STPath("/usr/bin/pgrep").url)
        pgrepPayload.arguments = ["-f", commandContains]
        pgrepPayload.throwOnNonZeroExit = false
        pgrepPayload.timeoutMs = 5_000
        if let pgrepResult = try? SKProcessRunner.runSync(pgrepPayload),
           pgrepResult.exitCode == 0 {
            for line in pgrepResult.stdout.split(separator: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let pid = Int(trimmed), pid != currentPID else { continue }
                return pid
            }
        }

        var payload = SKProcessPayload.executableURL(STPath("/bin/ps").url)
        payload.arguments = ["-axo", "pid=,command="]
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 10_000
        payload.maxOutputBytes = 8 * 1024 * 1024
        let result = try SKProcessRunner.runSync(payload)
        guard result.exitCode == 0 else { return nil }

        let text = result.stdout
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2, let pid = Int(parts[0]) else { continue }
            if pid == currentPID { continue }
            if matchesRuntimeCommand(String(parts[1]), runtimeCommand: commandContains) {
                return pid
            }
        }
        return nil
    }

    private static func waitForRunningServerPID(commandContains: String, timeoutMilliseconds: Int) throws -> Int? {
        let timeout = max(0, timeoutMilliseconds)
        let start = Date()
        repeat {
            if let pid = try runningServerPID(commandContains: commandContains) {
                return pid
            }
            if timeout == 0 {
                break
            }
            Thread.sleep(forTimeInterval: 0.05)
        } while Date().timeIntervalSince(start) * 1000.0 < Double(timeout)
        return nil
    }

    private static func matchesRuntimeCommand(_ commandLine: String, runtimeCommand: String) -> Bool {
        let tokens = commandLine
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .map(String.init)
        guard !tokens.isEmpty else { return false }
        let firstBase = URL(fileURLWithPath: tokens[0]).lastPathComponent
        if firstBase == runtimeCommand { return true }
        if firstBase == "env", tokens.count >= 2 {
            let secondBase = URL(fileURLWithPath: tokens[1]).lastPathComponent
            if secondBase == runtimeCommand { return true }
        }
        if firstBase == "nohup", tokens.count >= 2 {
            let secondBase = URL(fileURLWithPath: tokens[1]).lastPathComponent
            if secondBase == runtimeCommand { return true }
        }
        if Set(["sh", "bash", "zsh", "dash"]).contains(firstBase), tokens.count >= 2 {
            let scriptBase = URL(fileURLWithPath: tokens[1]).lastPathComponent
            if scriptBase == runtimeCommand { return true }
        }
        return false
    }

    private static func currentRuntimeSnapshot(for descriptor: PluginDescriptor) throws -> NolonPluginRuntimeSnapshot {
        guard descriptor.capabilities.contains(.runtimeControl),
              let runtimeCommand = descriptor.runtimeStartCommand else {
            return NolonPluginRuntimeSnapshot(state: "unsupported", pid: nil)
        }
        if let pid = try runningServerPID(commandContains: runtimeCommand) {
            return NolonPluginRuntimeSnapshot(state: "running", pid: pid)
        }
        return NolonPluginRuntimeSnapshot(state: "stopped", pid: nil)
    }

    private static func waitForProcessExit(
        commandContains: String,
        expectedPID: Int,
        timeoutMilliseconds: Int
    ) throws -> Bool {
        let deadline = Date().addingTimeInterval(Double(timeoutMilliseconds) / 1000.0)
        while Date() < deadline {
            let current = try runningServerPID(commandContains: commandContains)
            if current != expectedPID {
                return true
            }
            usleep(50_000)
        }
        return try runningServerPID(commandContains: commandContains) != expectedPID
    }

    private static func pluginGlobalMcpFilePath(pluginID: String) -> String {
        let base: String
        if let custom = ProcessInfo.processInfo.environment["NOLON_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            base = NSString(string: custom).expandingTildeInPath
        } else {
            base = NSString(string: "~/.nolon").expandingTildeInPath
        }
        return URL(fileURLWithPath: base, isDirectory: true)
            .appendingPathComponent("mcps", isDirectory: true)
            .appendingPathComponent("\(pluginID).json", isDirectory: false)
            .path
    }

    private static func writePluginGlobalMcpFile(descriptor: PluginDescriptor, path: String) throws {
        let marker: [String: Any] = [
            "plugin_id": descriptor.id,
            "managed": true,
            "schema_version": 1,
            "installed_by": "nolon-plugin-cli",
            "installed_at": ISO8601DateFormatter().string(from: Date()),
        ]
        let server: [String: Any] = [
            "command": descriptor.serverCommand,
            "enabled": true,
        ]
        let payload: [String: Any] = [
            "name": descriptor.displayName,
            "description": descriptor.summary,
            "mcpServers": [descriptor.serverName: server],
            "nolon_plugin": marker,
        ]
        let file = STFile(path)
        _ = file.parentFolder()?.createIfNotExists()
        let data = try JSONSerialization.data(
            withJSONObject: payload,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )
        try file.overlay(with: data)
    }

    private static func readPluginMarker(fromGlobalMcpPath path: String) throws -> PluginMarkerState {
        let file = STFile(path)
        guard file.isExists else { return PluginMarkerState(exists: false, managedByPlugin: false, pluginID: nil) }
        let raw = try? Data(contentsOf: file.url)
        guard let raw else {
            return PluginMarkerState(exists: true, managedByPlugin: false, pluginID: nil)
        }
        guard let object = try? JSONSerialization.jsonObject(with: raw) as? [String: Any] else {
            return PluginMarkerState(exists: true, managedByPlugin: false, pluginID: nil)
        }
        guard let marker = object["nolon_plugin"] as? [String: Any] else {
            return PluginMarkerState(exists: true, managedByPlugin: false, pluginID: nil)
        }
        let pluginID = marker["plugin_id"] as? String
        let managed = marker["managed"] as? Bool ?? false
        return PluginMarkerState(exists: true, managedByPlugin: managed, pluginID: pluginID)
    }

    private static func pluginVersionFilePath(pluginName: String) -> String {
        let base: String
        if let custom = ProcessInfo.processInfo.environment["NOLON_HOME"]?.trimmingCharacters(in: .whitespacesAndNewlines), !custom.isEmpty {
            base = NSString(string: custom).expandingTildeInPath
        } else {
            base = NSString(string: "~/.nolon").expandingTildeInPath
        }
        return URL(fileURLWithPath: base, isDirectory: true)
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent(pluginName, isDirectory: true)
            .appendingPathComponent("installed_version.txt", isDirectory: false)
            .path
    }

    private static func readPluginVersion(at path: String) throws -> String? {
        let file = STFile(path)
        guard file.isExists else { return nil }
        let raw = try file.read().trimmingCharacters(in: .whitespacesAndNewlines)
        return raw.isEmpty ? nil : raw
    }

    private static func writePluginVersion(_ version: String, pluginName: String) throws {
        let path = pluginVersionFilePath(pluginName: pluginName)
        let file = STFile(path)
        _ = file.parentFolder()?.createIfNotExists()
        try file.write(Data((version + "\n").utf8))
    }

    private static func checkPluginUpgradeStatus(installedVersion: String?) async -> XcodeMCPKitUpgradeStatus {
        guard ProcessInfo.processInfo.environment["NOLON_PLUGIN_CHECK_LATEST"] == "1" else {
            return XcodeMCPKitUpgradeStatus(
                installedVersion: installedVersion,
                latestVersion: nil,
                hasUpgrade: false,
                releaseURL: URL(string: "https://github.com/linhay/XcodeMCPKit/releases")
            )
        }
        return await XcodeMCPKitReleaseChecker().checkUpgrade(installedVersion: installedVersion)
    }

    private func formatPluginListText(result: [NolonPluginStatusSnapshot]) -> String {
        if result.isEmpty {
            return "no plugins"
        }
        return result.map { item in
            let installed = item.installedVersion ?? "-"
            let latest = item.latestVersion ?? "-"
            let runtime = item.runtime.pid.map { "running(pid=\($0))" } ?? item.runtime.state
            return "\(item.name) installed=\(installed) latest=\(latest) managed_by_plugin=\(item.managedByPlugin) binaries_ready=\(item.binariesReady) runtime=\(runtime)"
        }.joined(separator: "\n")
    }

    private func formatPluginStatusText(result: NolonPluginStatusSnapshot) -> String {
        let installed = result.installedVersion ?? "-"
        let latest = result.latestVersion ?? "-"
        let runtime = result.runtime.pid.map { "running(pid=\($0))" } ?? result.runtime.state
        return """
        plugin: \(result.name)
        provider: \(result.provider)
        installed: \(installed)
        latest: \(latest)
        has_upgrade: \(result.hasUpgrade)
        global_path: \(result.globalPath)
        managed_by_plugin: \(result.managedByPlugin)
        marker_plugin_id: \(result.markerPluginID ?? "-")
        binaries_ready: \(result.binariesReady)
        runtime: \(runtime)
        """
    }

    private func formatPluginMutationText(result: NolonPluginMutationResult) -> String {
        let version = result.version ?? "-"
        return "plugin \(result.action): \(result.name) provider=\(result.provider) version=\(version) global_path=\(result.globalPath ?? "-") managed_by_plugin=\(result.managedByPlugin ?? false) message=\(result.message)"
    }

    private func formatPluginRuntimeText(result: NolonPluginRuntimeResult) -> String {
        let pid = result.pid.map(String.init) ?? "-"
        return "plugin runtime \(result.action): \(result.name) state=\(result.state) pid=\(pid) message=\(result.message)"
    }
}

private struct RepositoryPathSelection: Sendable {
    let path: String
    let warnings: [String]
}

private struct SkillsAddTarget: Sendable {
    let providerID: String
    let providerPath: String
}

private struct SkillsAddExecutionOutput: Sendable {
    let output: String
    let exitCode: Int32
}

private struct NolonPluginRuntimeSnapshot: Encodable, Sendable {
    let state: String
    let pid: Int?
}

private struct NolonPluginStatusSnapshot: Encodable, Sendable {
    let name: String
    let provider: String
    let installedVersion: String?
    let latestVersion: String?
    let hasUpgrade: Bool
    let isInstalled: Bool
    let binariesReady: Bool
    let runtime: NolonPluginRuntimeSnapshot
    let globalPath: String
    let managedByPlugin: Bool
    let markerPluginID: String?

    enum CodingKeys: String, CodingKey {
        case name
        case provider
        case installedVersion = "installed_version"
        case latestVersion = "latest_version"
        case hasUpgrade = "has_upgrade"
        case isInstalled = "is_installed"
        case binariesReady = "binaries_ready"
        case runtime
        case globalPath = "global_path"
        case managedByPlugin = "managed_by_plugin"
        case markerPluginID = "marker_plugin_id"
    }
}

private struct NolonPluginRuntimeResult: Encodable, Sendable {
    let action: String
    let name: String
    let state: String
    let pid: Int?
    let message: String
}

private struct NolonPluginMutationResult: Encodable, Sendable {
    let action: String
    let name: String
    let provider: String
    let success: Bool
    let message: String
    let version: String?
    let globalPath: String?
    let managedByPlugin: Bool?
    let markerPluginID: String?

    enum CodingKeys: String, CodingKey {
        case action
        case name
        case provider
        case success
        case message
        case version
        case globalPath = "global_path"
        case managedByPlugin = "managed_by_plugin"
        case markerPluginID = "marker_plugin_id"
    }
}

private struct PluginListPayload: Encodable, Sendable {
    let result: [NolonPluginStatusSnapshot]
}

private struct PluginStatusPayload: Encodable, Sendable {
    let result: NolonPluginStatusSnapshot
}

private struct PluginMutationPayload: Encodable, Sendable {
    let result: NolonPluginMutationResult
}

private struct PluginRuntimePayload: Encodable, Sendable {
    let result: NolonPluginRuntimeResult
}

private enum PluginCapability: String, Sendable {
    case mcpGlobalInstall = "mcp_global_install"
    case runtimeControl = "runtime_control"
}

private struct PluginDescriptor: Sendable {
    let id: String
    let displayName: String
    let summary: String
    let serverName: String
    let serverCommand: String
    let requiredBinaries: [String]
    let capabilities: Set<PluginCapability>
    let runtimeStartCommand: String?
}

private struct PluginMarkerState: Sendable {
    let exists: Bool
    let managedByPlugin: Bool
    let pluginID: String?
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

private struct RepoListPayload: Encodable, Sendable {
    let repositoriesRoot: String
    let maxDepth: Int
    let repositories: [NolonLocalRepositorySummary]

    enum CodingKeys: String, CodingKey {
        case repositoriesRoot = "repositories_root"
        case maxDepth = "max_depth"
        case repositories
    }
}

private struct SkillsListPayload: Encodable, Sendable {
    let result: NolonSkillsListResult
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

private struct MCPServersPayload: Encodable, Sendable {
    let result: NolonMcpServerListResult
}

private struct MCPServerMutationPayload: Encodable, Sendable {
    let result: NolonMcpServerMutationResult
}

private struct MCPCacheStatusPayload: Encodable, Sendable {
    let result: NolonMcpCacheStatusResult
}

private struct MCPCacheMigratePayload: Encodable, Sendable {
    let result: NolonMcpCacheMigrateResult
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

private struct SkillsAddPayload: Encodable, Sendable {
    let result: NolonSkillsAddResult
}

private struct RemoteSyncInstallPayload: Encodable, Sendable {
    let plan: NolonGitImportPlan
    let result: NolonGitSyncResult
    let resources: NolonRepositoryResources
    let install: NolonRemoteSyncInstallResult
}
