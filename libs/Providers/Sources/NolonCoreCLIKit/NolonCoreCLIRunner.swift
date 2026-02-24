import Foundation
import ProviderCatalog
import STFilePath

public enum NolonCoreCLIOutputMode: Sendable {
    case text
    case json
}

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
                if child.isSymbolicLink {
                    let destination = (try? FileManager.default.destinationOfSymbolicLink(atPath: child.url.path)) ?? ""
                    let resolved = STPath(destination).url.standardizedFileURL.path
                    let exists = STPath(resolved).isExists
                    if !exists {
                        stateKind = .broken
                    } else if cacheRoot.subpath(name).isExists {
                        stateKind = .installed
                    } else {
                        stateKind = .orphaned
                    }
                } else {
                    stateKind = cacheRoot.subpath(name).isExists ? .installed : .orphaned
                }

                items.append(
                    NolonSkillsListItem(
                        providerID: target.providerID,
                        providerPath: target.providerPath,
                        skillID: name,
                        state: stateKind,
                        path: child.url.path,
                        origin: readResourceOrigin(kind: kind == .workflow ? .workflow : .mcp, identifier: name)
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
            items.append(contentsOf: Self.buildMCPListItemsForConfig(providerID: target.providerID, configPath: target.providerPath))
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
        var candidates: [String] = []
        var seen: Set<String> = []

        for repository in repositories {
            let resources = service.discoverRepositoryResources(at: STFolder(repository.path), maxDepth: 6)
            for directory in resources.skillsDirectories where directory.skillNames.contains(slug) {
                let path = URL(fileURLWithPath: repository.path, isDirectory: true)
                    .appendingPathComponent(directory.path, isDirectory: true)
                    .appendingPathComponent(slug, isDirectory: true)
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
            try sourcePath.copy(to: target, isOverlay: true)
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
            guard let template = resolveProviderTemplate(providerID: provider) else {
                throw NolonCoreCLIError.invalidArguments("Unsupported --provider: \(provider)")
            }
            return [SkillsAddTarget(providerID: template.providerID, providerPath: template.defaultSkillsPath.path)]
        }

        var targets: [SkillsAddTarget] = []
        var seen: Set<String> = []
        for template in ProviderTemplate.allCases {
            let executable = template.cliName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !executable.isEmpty else { continue }
            guard Self.resolveCLIInOfficialPaths(named: executable) != nil else { continue }
            let key = template.providerID.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            targets.append(SkillsAddTarget(providerID: template.providerID, providerPath: template.defaultSkillsPath.path))
        }
        return targets.sorted { $0.providerID.localizedCaseInsensitiveCompare($1.providerID) == .orderedAscending }
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
            guard let template = resolveProviderTemplate(providerID: provider) else {
                throw NolonCoreCLIError.invalidArguments("Unsupported --provider: \(provider)")
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

        var targets: [SkillsAddTarget] = []
        var seen: Set<String> = []
        for template in ProviderTemplate.allCases {
            let executable = template.cliName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !executable.isEmpty else { continue }
            guard Self.resolveCLIInOfficialPaths(named: executable) != nil else { continue }
            let key = template.providerID.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            let providerPath: String
            switch kind {
            case .workflow:
                providerPath = template.defaultCommandPath?.path ?? template.defaultWorkflowPath.path
            case .mcp:
                providerPath = template.defaultMcpConfigPath.deletingLastPathComponent().path
            }
            targets.append(SkillsAddTarget(providerID: template.providerID, providerPath: providerPath))
        }
        return targets.sorted { $0.providerID.localizedCaseInsensitiveCompare($1.providerID) == .orderedAscending }
    }

    private static func resolveMCPConfigTargets(provider: String?) throws -> [SkillsAddTarget] {
        if let provider, !provider.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            guard let template = resolveProviderTemplate(providerID: provider) else {
                throw NolonCoreCLIError.invalidArguments("Unsupported --provider: \(provider)")
            }
            return [SkillsAddTarget(providerID: template.providerID, providerPath: template.defaultMcpConfigPath.path)]
        }

        var targets: [SkillsAddTarget] = []
        var seen: Set<String> = []
        for template in ProviderTemplate.allCases {
            let executable = template.cliName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !executable.isEmpty else { continue }
            guard Self.resolveCLIInOfficialPaths(named: executable) != nil else { continue }
            let key = template.providerID.lowercased()
            if seen.contains(key) { continue }
            seen.insert(key)
            targets.append(SkillsAddTarget(providerID: template.providerID, providerPath: template.defaultMcpConfigPath.path))
        }
        return targets.sorted { $0.providerID.localizedCaseInsensitiveCompare($1.providerID) == .orderedAscending }
    }

    static func buildMCPListItemsForConfig(providerID: String, configPath: String) -> [NolonSkillsListItem] {
        let config = STPath(configPath)
        guard config.isExists else { return [] }

        let ext = config.url.pathExtension.lowercased()
        do {
            let content = try STFile(configPath).read()
            let names = try parseMCPServerNames(content: content, fileExtension: ext)
            return names.map { name in
                NolonSkillsListItem(
                    providerID: providerID,
                    providerPath: configPath,
                    skillID: name,
                    state: .installed,
                    path: configPath,
                    origin: nil
                )
            }
        } catch {
            return [
                NolonSkillsListItem(
                    providerID: providerID,
                    providerPath: configPath,
                    skillID: config.url.lastPathComponent,
                    state: .broken,
                    path: configPath,
                    origin: nil
                ),
            ]
        }
    }

    static func parseMCPServerNames(content: String, fileExtension: String) throws -> [String] {
        switch fileExtension {
        case "json":
            return try parseMCPServerNamesFromJSON(content: content)
        case "toml":
            return parseMCPServerNamesFromTOML(content: content)
        default:
            return []
        }
    }

    private static func parseMCPServerNamesFromJSON(content: String) throws -> [String] {
        guard let data = content.data(using: .utf8) else { return [] }
        let object = try JSONSerialization.jsonObject(with: data, options: [])
        var names: Set<String> = []
        collectMCPServerNames(in: object, names: &names)
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static func collectMCPServerNames(in object: Any, names: inout Set<String>) {
        if let dictionary = object as? [String: Any] {
            for (key, value) in dictionary {
                let lower = key.lowercased()
                if lower == "mcpservers" || lower == "mcp_servers" {
                    if let serverMap = value as? [String: Any] {
                        names.formUnion(serverMap.keys.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
                    }
                }
                if lower == "mcp", let mcp = value as? [String: Any], let servers = mcp["servers"] as? [String: Any] {
                    names.formUnion(servers.keys.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
                }
                collectMCPServerNames(in: value, names: &names)
            }
        } else if let array = object as? [Any] {
            array.forEach { collectMCPServerNames(in: $0, names: &names) }
        }
    }

    private static func parseMCPServerNamesFromTOML(content: String) -> [String] {
        let patterns = [
            #"^\s*\[(?:mcp_servers|mcp\.servers|mcpServers)\.([^\]]+)\]\s*$"#,
        ]
        var names: Set<String> = []
        content.split(separator: "\n").forEach { rawLine in
            let line = String(rawLine)
            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
                let range = NSRange(line.startIndex..<line.endIndex, in: line)
                guard let match = regex.firstMatch(in: line, options: [], range: range), match.numberOfRanges > 1 else { continue }
                guard let captureRange = Range(match.range(at: 1), in: line) else { continue }
                let rawName = String(line[captureRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                guard let name = normalizedMCPServerNameFromToml(rawName) else { continue }
                if !name.isEmpty {
                    names.insert(name)
                }
            }
        }
        return names.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private static func normalizedMCPServerNameFromToml(_ rawName: String) -> String? {
        var token = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else { return nil }

        if token.hasPrefix("\""), token.hasSuffix("\""), token.count >= 2 {
            token = String(token.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            return token.isEmpty ? nil : token
        }

        if let dot = token.firstIndex(of: ".") {
            token = String(token[..<dot])
        }
        token = token.trimmingCharacters(in: .whitespacesAndNewlines)

        if token.hasPrefix("\""), token.hasSuffix("\""), token.count >= 2 {
            token = String(token.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return token.isEmpty ? nil : token
    }

    private static func resolveCLIInOfficialPaths(named executable: String) -> String? {
        let candidates = [
            "/opt/homebrew/bin/\(executable)",
            "/usr/local/bin/\(executable)",
            "/usr/bin/\(executable)",
        ]
        for path in candidates {
            let candidate = STPath(path)
            guard candidate.isExists, candidate.permission.contains(.executable) else { continue }
            return candidate.url.standardizedFileURL.path
        }
        return nil
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
        func percent(_ value: Int, total: Int) -> String {
            guard total > 0 else { return "0.0%" }
            let ratio = (Double(value) / Double(total)) * 100
            return String(format: "%.1f%%", ratio)
        }

        var lines: [String] = []
        let orphanedLabel = "失效链接"
        let issueCount = result.summary.orphanedCount + result.summary.brokenCount
        let compactHealthySummary = showFixes && issueCount == 0 && !verbose && result.providerFilter == nil && result.stateFilter == nil
        var filtersAppended = false
        func appendFiltersIfNeeded() {
            if filtersAppended { return }
            if let filter = result.providerFilter, !filter.isEmpty {
                lines.append("provider_filter: \(filter)")
            }
            if let stateFilter = result.stateFilter {
                lines.append("state_filter: \(stateFilter.rawValue)")
            }
            filtersAppended = true
        }
        lines.append("[结论]")
        if showFixes {
            let actionLabel = issueCount > 0 ? "fix" : "none"
            lines.append("summary: issues=\(issueCount) | installed=\(result.summary.installedCount)/\(result.summary.itemCount) | action=\(actionLabel)")
            lines.append("[详情]")
            appendFiltersIfNeeded()
        }
        if !compactHealthySummary {
            lines.append("providers_scanned: \(result.summary.providerCount)")
            let matchedProviders = matchedProvidersCount(for: result)
            lines.append("providers_matched: \(matchedProviders)")
            lines.append("skills_total: \(result.summary.itemCount)")
            if !showFixes {
                lines.append(
                    "健康度(已安装/总数): \(result.summary.installedCount)/\(result.summary.itemCount) (\(percent(result.summary.installedCount, total: result.summary.itemCount)))"
                )
            }
        }
        if !showFixes || issueCount > 0 {
            lines.append(
                "状态：已安装 \(result.summary.installedCount) 项（\(percent(result.summary.installedCount, total: result.summary.itemCount))），\(orphanedLabel) \(result.summary.orphanedCount) 项（\(percent(result.summary.orphanedCount, total: result.summary.itemCount))），损坏 \(result.summary.brokenCount) 项（\(percent(result.summary.brokenCount, total: result.summary.itemCount))）。"
            )
        }
        if showFixes {
            if issueCount > 0 {
                lines.append("结论：发现 \(issueCount) 项异常（\(orphanedLabel) \(result.summary.orphanedCount)、损坏 \(result.summary.brokenCount)），请按下方修复计划依序处理。")
            } else {
                lines.append("健康：\(result.summary.installedCount)/\(result.summary.itemCount)（\(percent(result.summary.installedCount, total: result.summary.itemCount))），异常 0，修复动作：无。")
            }
        } else {
            lines.append("需处理异常: \(issueCount)（\(orphanedLabel) \(result.summary.orphanedCount)，损坏 \(result.summary.brokenCount)）")
            if issueCount > 0 {
                lines.append("行动建议: 需处理 \(issueCount) 项异常（高优先级）")
                lines.append("摘要: 当前有 \(issueCount) 个异常项（\(result.summary.orphanedCount) 个\(orphanedLabel)，\(result.summary.brokenCount) 个损坏），建议按下方修复计划执行。")
            } else {
                lines.append("行动建议: 无需处理（系统健康）")
                lines.append("摘要: 当前无异常项，状态健康。")
            }
        }
        appendFiltersIfNeeded()
        if showFixes, issueCount == 0, !verbose, result.providerFilter == nil, result.stateFilter == nil {
            return lines.joined(separator: "\n")
        }
        lines.append("")

        let effectiveItems: [NolonSkillsListItem]
        if verbose || result.stateFilter != nil {
            effectiveItems = result.items
        } else {
            effectiveItems = result.items.filter { $0.state != .installed }
        }
        let issueProviders = Array(
            Set(
                effectiveItems
                    .filter { $0.state == .orphaned || $0.state == .broken }
                    .map(\.providerID)
            )
        ).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        if !issueProviders.isEmpty {
            lines.append("异常提供方(\(issueProviders.count)): \(issueProviders.joined(separator: ", "))")
        }
        let brokenIssueProviders = Array(
            Set(
                effectiveItems
                    .filter { $0.state == .broken }
                    .map(\.providerID)
            )
        ).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        let orphanedIssueProviders = Array(
            Set(
                effectiveItems
                    .filter { $0.state == .orphaned }
                    .map(\.providerID)
            )
        ).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }

        if effectiveItems.isEmpty {
            if let filter = result.providerFilter, !filter.isEmpty, let stateFilter = result.stateFilter {
                lines.append("在 provider=\(filter) 且 state=\(stateFilter.rawValue) 下，未发现匹配技能。")
            } else if let filter = result.providerFilter, !filter.isEmpty {
                lines.append("在 provider=\(filter) 下，未发现异常技能（\(orphanedLabel)/损坏）。")
            } else if let stateFilter = result.stateFilter {
                lines.append("在 state=\(stateFilter.rawValue) 下，未发现匹配技能。")
            } else {
                lines.append("未发现异常技能（\(orphanedLabel)/损坏）。")
            }
            if showFixes {
                lines.append("")
                Self.appendOptionalRecheck(lines: &lines, command: "nolon skills list --show-fixes")
            }
            return lines.joined(separator: "\n")
        }

        let installedCount = effectiveItems.filter { $0.state == .installed }.count
        let problematicCount = effectiveItems.count - installedCount
        if problematicCount > 0, installedCount == 0 {
            lines.append("[异常]")
        } else if installedCount > 0, problematicCount == 0 {
            lines.append("[已安装]")
        }

        lines.append(contentsOf: effectiveItems.map { item in
            let stateLabel = Self.localizedStateLabel(item.state)
            if verbose {
                var line = "- \(item.providerID)/\(item.skillID)"
                if item.state != .installed {
                    line += " [\(stateLabel)]"
                }
                line += "\n  path: \(item.path)"
                if let origin = item.origin, origin.sourceType != .unknown {
                    line += "\n  origin: \(origin.sourceType.rawValue):\(origin.sourceRef)"
                }
                return line
            }
            if item.state == .installed {
                return "- \(item.providerID)/\(item.skillID)"
            }
            return "- \(item.providerID)/\(item.skillID) [\(stateLabel)]"
        })
        if !verbose && !showFixes {
            lines.append("")
            lines.append("提示: 使用 `nolon skills list --verbose` 查看安装路径与来源。")
        }
        if !issueProviders.isEmpty && !showFixes {
            lines.append("")
            lines.append("[下一步（可复制执行）]")
            lines.append("先设置前缀变量（与本次入口一致）: `\(Self.runtimeCommandEnvAssignment())`")
            lines.append("本次入口: `\(Self.runtimeCommandPrefix())`")
            lines.append("修复建议（可复制）:")
            var quickActions: [String] = []
            if !brokenIssueProviders.isEmpty {
                quickActions.append("查看坏链详情: `\(Self.copyableCommand("nolon skills list --state broken --verbose"))`")
            }
            if !orphanedIssueProviders.isEmpty {
                quickActions.append("查看失效链接详情: `\(Self.copyableCommand("nolon skills list --state orphaned --verbose"))`")
            }
            quickActions.append("生成修复命令: `\(Self.copyableCommand("nolon skills list --show-fixes"))`")
            lines.append(contentsOf: quickActions.enumerated().map { index, action in
                "\(index + 1)) \(action)"
            })
        }

        let orphanedItems = effectiveItems.filter { $0.state == .orphaned }
        let brokenItems = effectiveItems.filter { $0.state == .broken }
        if showFixes && (!orphanedItems.isEmpty || !brokenItems.isEmpty) {
            lines.append("")
            lines.append("[下一步（按顺序执行）]")
            lines.append("`\(Self.runtimeCommandEnvAssignment())`")
            var orphanedCommands: [String] = []
            var brokenCommands: [String] = []
            if !orphanedItems.isEmpty {
                orphanedItems.forEach { item in
                    let remove = "nolon skills remove --skill-id \(item.skillID) --provider \(item.providerID)"
                    orphanedCommands.append(remove)
                }
            }
            if !brokenItems.isEmpty {
                brokenItems.forEach { item in
                    let remove = "nolon skills remove --skill-id \(item.skillID) --provider \(item.providerID)"
                    let add = "nolon skills add \(item.skillID) --provider \(item.providerID)"
                    let repair = "\(remove) && \(add)"
                    brokenCommands.append(repair)
                }
            }
            if !orphanedCommands.isEmpty {
                lines.append("")
                lines.append("1. 清理\(orphanedLabel)（\(orphanedItems.count)项）")
                let groupedOrphaned = Dictionary(grouping: orphanedItems, by: \.providerID)
                for providerID in groupedOrphaned.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
                    guard let items = groupedOrphaned[providerID] else { continue }
                    lines.append("provider: \(providerID) (\(items.count))")
                    for item in items.sorted(by: { $0.skillID.localizedCaseInsensitiveCompare($1.skillID) == .orderedAscending }) {
                        let command = "nolon skills remove --skill-id \(item.skillID) --provider \(item.providerID)"
                        lines.append("- `\(Self.copyableCommand(command))`")
                    }
                }
            }
            if !brokenCommands.isEmpty {
                lines.append("")
                lines.append("2. 修复损坏（\(brokenItems.count)项：先 remove 再 add）")
                let groupedBroken = Dictionary(grouping: brokenItems, by: \.providerID)
                for providerID in groupedBroken.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
                    guard let items = groupedBroken[providerID] else { continue }
                    lines.append("provider: \(providerID) (\(items.count))")
                    for item in items.sorted(by: { $0.skillID.localizedCaseInsensitiveCompare($1.skillID) == .orderedAscending }) {
                        let remove = "nolon skills remove --skill-id \(item.skillID) --provider \(item.providerID)"
                        let add = "nolon skills add \(item.skillID) --provider \(item.providerID)"
                        lines.append("- `\(Self.copyableCommand("\(remove) && \(add)"))`")
                    }
                }
            }
            lines.append("")
            lines.append("3. 复检")
            lines.append("`\(Self.copyableCommand("nolon skills list --show-fixes"))`")
        } else if showFixes, issueCount > 0 {
            lines.append("")
            lines.append("[下一步（可复制执行）]")
            lines.append("状态健康，无需修复；修复建议已启用但当前无可修复项。")
        }
        return lines.joined(separator: "\n")
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
        let normalizedQueryValue = Self.normalizedSlug(queryValue)
        let exactMatch = queryValue.isEmpty
            ? nil
            : result.items.first(where: { Self.normalizedSlug($0.slug) == normalizedQueryValue })
        let displayPool = exactMatch.map { [$0] } ?? result.items
        let alternativeCandidates = exactMatch.map { match in
            result.items.filter { Self.normalizedSlug($0.slug) != Self.normalizedSlug(match.slug) }
        } ?? []
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
        if exactMatch == nil, displayPool.count > displayedItems.count {
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
        if result.items.isEmpty {
            return """
            未找到匹配 \(kind.rawValue)
            提示: 使用 `nolon \(kind.rawValue) sync --source <owner/repo>` 同步本地仓库后重试，或更换关键词。
            """
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let showSummary = result.items.count <= 8
        let query = result.query?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let queryPart = query.isEmpty ? "" : " (query: \(query))"
        let maxDisplay = 10
        let displayedItems = Array(result.items.prefix(maxDisplay))
        let lines = displayedItems.enumerated().map { index, item in
            var itemLines = [
                "[\(index + 1)] \(item.slug)",
                "  version: \(item.latestVersion ?? "-")",
                "  updated: \(item.updatedAt.map { formatUpdatedDate($0, formatter: formatter) } ?? "-")",
            ]
            if showSummary, let summary = compactSummary(item.summary, maxLength: 140) {
                itemLines.append("  summary: \(summary)")
            }
            return itemLines.joined(separator: "\n")
        }.joined(separator: "\n\n")
        let queryExample = query.isEmpty ? "<keyword>" : query
        let truncatedHint = result.items.count > displayedItems.count
            ? "提示: 仅展示前 \(displayedItems.count) 条；可增大 `--limit` 查看更多。"
            : ""
        return """
        匹配结果: \(result.items.count)\(queryPart)
        source: remote-api (\(result.baseURL))
        安装:
        - 指定 provider: nolon \(kind.rawValue) add <slug> --provider codex --dry-run
        - 全部 providers: nolon \(kind.rawValue) add <slug> --dry-run [可能批量写入]
        - 搜索并挑选: nolon \(kind.rawValue) search \(queryExample) --install --pick 1 --provider codex --dry-run
        \(truncatedHint)
        \(lines)
        提示: 用 `--install --pick <序号>` 或直接 slug 安装。
        """
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
        func percent(_ value: Int, total: Int) -> String {
            guard total > 0 else { return "0.0%" }
            return String(format: "%.1f%%", (Double(value) / Double(total)) * 100)
        }
        var lines: [String] = []
        let orphanedLabel = "失效链接"
        let issueCount = result.summary.orphanedCount + result.summary.brokenCount
        let compactHealthySummary = showFixes && issueCount == 0 && !verbose && result.providerFilter == nil && result.stateFilter == nil
        var filtersAppended = false
        func appendFiltersIfNeeded() {
            if filtersAppended { return }
            if let filter = result.providerFilter, !filter.isEmpty {
                lines.append("provider_filter: \(filter)")
            }
            if let stateFilter = result.stateFilter {
                lines.append("state_filter: \(stateFilter.rawValue)")
            }
            filtersAppended = true
        }
        lines.append("[结论]")
        if showFixes {
            let actionLabel = issueCount > 0 ? "fix" : "none"
            lines.append("summary: issues=\(issueCount) | installed=\(result.summary.installedCount)/\(result.summary.itemCount) | action=\(actionLabel)")
            lines.append("[详情]")
            appendFiltersIfNeeded()
        }
        let installedPct = percent(result.summary.installedCount, total: result.summary.itemCount)
        let orphanedPct = percent(result.summary.orphanedCount, total: result.summary.itemCount)
        let brokenPct = percent(result.summary.brokenCount, total: result.summary.itemCount)
        if !compactHealthySummary {
            lines.append("providers_scanned: \(result.summary.providerCount)")
            lines.append("providers_matched: \(matchedProvidersCount(for: result))")
            lines.append("\(kind.rawValue)s_total: \(result.summary.itemCount)")
        }
        if showFixes {
            if issueCount > 0 {
                lines.append("状态：已安装 \(result.summary.installedCount) 项（\(installedPct)），\(orphanedLabel) \(result.summary.orphanedCount) 项（\(orphanedPct)），损坏 \(result.summary.brokenCount) 项（\(brokenPct)）。")
                lines.append("结论：发现 \(issueCount) 项异常（\(orphanedLabel) \(result.summary.orphanedCount)、损坏 \(result.summary.brokenCount)），请按下方修复计划依序处理。")
            } else {
                lines.append("健康：\(result.summary.installedCount)/\(result.summary.itemCount)（\(installedPct)），异常 0，修复动作：无。")
            }
        } else {
            lines.append("状态(已安装/\(orphanedLabel)/损坏): \(result.summary.installedCount)/\(result.summary.orphanedCount)/\(result.summary.brokenCount) (\(percent(result.summary.installedCount, total: result.summary.itemCount))/\(percent(result.summary.orphanedCount, total: result.summary.itemCount))/\(percent(result.summary.brokenCount, total: result.summary.itemCount)))")
            lines.append("需处理异常: \(issueCount)（\(orphanedLabel) \(result.summary.orphanedCount)，损坏 \(result.summary.brokenCount)）")
            if issueCount > 0 {
                lines.append("行动建议: 需处理 \(issueCount) 项异常（高优先级）")
                lines.append("摘要: 当前有 \(issueCount) 个异常项（\(result.summary.orphanedCount) 个\(orphanedLabel)，\(result.summary.brokenCount) 个损坏），建议按下方修复计划执行。")
            } else {
                lines.append("行动建议: 无需处理（系统健康）")
                lines.append("摘要: 当前无异常项，状态健康。")
            }
        }
        appendFiltersIfNeeded()
        if showFixes, issueCount == 0, !verbose, result.providerFilter == nil, result.stateFilter == nil {
            return lines.joined(separator: "\n")
        }

        let items: [NolonSkillsListItem]
        if verbose || result.stateFilter != nil {
            items = result.items
        } else {
            items = result.items.filter { $0.state != .installed }
        }
        if items.isEmpty {
            let resourceLabel = Self.localizedResourceKindLabel(kind)
            let resourceDisplayLabel = Self.displayResourceLabel(resourceLabel)
            if let filter = result.providerFilter, !filter.isEmpty, let stateFilter = result.stateFilter {
                lines.append("在 provider=\(filter) 且 state=\(stateFilter.rawValue) 下，未发现匹配\(resourceDisplayLabel)。")
            } else if let filter = result.providerFilter, !filter.isEmpty {
                lines.append("在 provider=\(filter) 下，未发现异常\(resourceDisplayLabel)（\(orphanedLabel)/损坏）。")
            } else if let stateFilter = result.stateFilter {
                lines.append("在 state=\(stateFilter.rawValue) 下，未发现匹配\(resourceDisplayLabel)。")
            } else {
                lines.append("未发现异常\(resourceDisplayLabel)（\(orphanedLabel)/损坏）。")
            }
            if showFixes {
                lines.append("")
                Self.appendOptionalRecheck(lines: &lines, command: "nolon \(kind.rawValue) list --show-fixes")
            }
            return lines.joined(separator: "\n")
        }
        let problematicItems = items.filter { $0.state != .installed }
        let installedItems = items.filter { $0.state == .installed }
        let providers = Array(Set(problematicItems.map(\.providerID))).sorted()
        if !providers.isEmpty {
            lines.append("异常提供方(\(providers.count)): \(providers.joined(separator: ", "))")
        }

        if !problematicItems.isEmpty {
            lines.append("")
            lines.append("[异常]")
            lines.append(contentsOf: problematicItems.map { item in
                let stateLabel: String = {
                    if item.state == .orphaned { return orphanedLabel }
                    return Self.localizedStateLabel(item.state)
                }()
                if verbose {
                    var line = "- \(item.providerID)/\(item.skillID) [\(stateLabel)]\n  path: \(item.path)"
                    if let origin = item.origin, origin.sourceType != .unknown {
                        line += "\n  origin: \(origin.sourceType.rawValue):\(origin.sourceRef)"
                    }
                    return line
                }
                return "- \(item.providerID)/\(item.skillID) [\(stateLabel)]"
            })
        }
        if !installedItems.isEmpty {
            lines.append("")
            lines.append("[已安装]")
            let installedLines = installedItems.map { item in
                if verbose {
                    var line = "- \(item.providerID)/\(item.skillID)"
                    line += "\n  path: \(item.path)"
                    if let origin = item.origin, origin.sourceType != .unknown {
                        line += "\n  origin: \(origin.sourceType.rawValue):\(origin.sourceRef)"
                    }
                    return line
                }
                return "- \(item.providerID)/\(item.skillID)"
            }
            lines.append(contentsOf: installedLines)
        }
        if !verbose, !showFixes {
            lines.append("")
            lines.append("提示: 使用 `nolon \(kind.rawValue) list --verbose` 查看安装路径与来源。")
        }
        let fixCommands = Self.buildResourceFixCommands(kind: kind, items: problematicItems)
        if !fixCommands.simple.isEmpty && !showFixes {
            let filterSuffix = Self.listFilterSuffix(provider: result.providerFilter, state: result.stateFilter)
            lines.append("")
            lines.append("[下一步（可复制执行）]")
            lines.append("先设置前缀变量（与本次入口一致）: `\(Self.runtimeCommandEnvAssignment())`")
            lines.append("本次入口: `\(Self.runtimeCommandPrefix())`")
            lines.append("修复建议（可复制）:")
            if fixCommands.detailed.count == 1 {
                lines.append("1) `\(Self.copyableCommand(fixCommands.simple))`")
            } else {
                lines.append("1) 生成分条修复命令: `\(Self.copyableCommand("nolon \(kind.rawValue) list\(filterSuffix) --show-fixes"))`")
            }
            lines.append("2) 查看路径与来源: `\(Self.copyableCommand("nolon \(kind.rawValue) list\(filterSuffix) --verbose --show-fixes"))`")
        }
        if showFixes, !fixCommands.detailed.isEmpty {
            lines.append("")
            lines.append("[下一步（按顺序执行）]")
            lines.append("`\(Self.runtimeCommandEnvAssignment())`")
            lines.append("修复计划:")
            lines.append("1. 清理异常项（\(fixCommands.detailed.count)项）")
            let groupedByProvider = Dictionary(grouping: problematicItems, by: \.providerID)
            for providerID in groupedByProvider.keys.sorted(by: { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }) {
                guard let items = groupedByProvider[providerID] else { continue }
                lines.append("provider: \(providerID) (\(items.count))")
                for item in items.sorted(by: { $0.skillID.localizedCaseInsensitiveCompare($1.skillID) == .orderedAscending }) {
                    let command = "nolon \(kind.rawValue) remove --resource-name \(item.skillID) --provider \(item.providerID)"
                    lines.append("- `\(Self.copyableCommand(command))`")
                }
            }
            lines.append("")
            lines.append("2. 复检")
            lines.append("`\(Self.copyableCommand("nolon \(kind.rawValue) list --show-fixes"))`")
        } else if showFixes, issueCount > 0 {
            lines.append("")
            lines.append("[下一步（可复制执行）]")
            lines.append("状态健康，无需修复；修复建议已启用但当前无可修复项。")
        }
        return lines.joined(separator: "\n")
    }

    static func buildResourceFixCommands(
        kind: NolonResourceKind,
        items: [NolonSkillsListItem]
    ) -> (simple: String, detailed: [String]) {
        let problematic = items.filter { $0.state != .installed }
        let detailed = problematic.map { item in
            "nolon \(kind.rawValue) remove --resource-name \(item.skillID) --provider \(item.providerID)"
        }
        return (simple: detailed.first ?? "", detailed: detailed)
    }

    private func matchedProvidersCount(for result: NolonSkillsListResult) -> Int {
        if let filter = result.providerFilter, !filter.isEmpty {
            return 1
        }
        return Set(result.items.map(\.providerID)).count
    }

    private static func listFilterSuffix(provider: String?, state: NolonProviderSkillStateKind?) -> String {
        var parts: [String] = []
        if let provider, !provider.isEmpty {
            parts.append("--provider \(provider)")
        }
        if let state {
            parts.append("--state \(state.rawValue)")
        }
        guard !parts.isEmpty else { return "" }
        return " " + parts.joined(separator: " ")
    }

    private static func combinedFixCommand(_ commands: [String]) -> String? {
        guard !commands.isEmpty else { return nil }
        guard commands.count <= 3 else { return nil }
        let combined = commands.joined(separator: " && ")
        return combined.count <= 280 ? combined : nil
    }

    private static func runtimeCommandPrefix() -> String {
        let executable = CommandLine.arguments.first ?? ""
        if executable.contains("/.build/") {
            return "swift run --package-path libs/Providers nolon"
        }
        return "nolon"
    }

    private static func runtimeCommandEnvAssignment() -> String {
        "NOLON_CMD='\(runtimeCommandPrefix())'"
    }

    private static func copyableCommand(_ command: String) -> String {
        command.replacingOccurrences(of: "nolon ", with: "$NOLON_CMD ")
    }

    private static func sourceModeCommand(_ command: String) -> String {
        command.replacingOccurrences(of: "nolon ", with: "swift run --package-path libs/Providers nolon ")
    }

    private static func appendOptionalRecheck(lines: inout [String], command: String) {
        lines.append("可选复检:")
        lines.append("- 直接运行: `\(command)`")
        lines.append("- 源码模式: `\(sourceModeCommand(command))`")
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

    private static func localizedStateLabel(_ state: NolonProviderSkillStateKind) -> String {
        switch state {
        case .installed:
            return "已安装"
        case .orphaned:
            return "失效链接"
        case .broken:
            return "损坏"
        }
    }

    private static func localizedResourceKindLabel(_ kind: NolonResourceKind) -> String {
        switch kind {
        case .workflow:
            return "工作流资源"
        case .mcp:
            return "MCP 资源"
        }
    }

    private static func displayResourceLabel(_ label: String) -> String {
        guard let first = label.unicodeScalars.first else { return label }
        return first.isASCII ? " \(label)" : label
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
