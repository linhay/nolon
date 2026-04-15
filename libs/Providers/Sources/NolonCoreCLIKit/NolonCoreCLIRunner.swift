import Foundation
import ProviderCatalog
import NolonResourceKit
import ProviderUsage
import CodexBarProviderCatalog
import CopilotProvider
import SKProcessRunner
import STFilePath

public enum NolonCoreCLIOutputMode: Sendable {
    case text
    case json
}

extension NolonCoreCLIRunner {
    struct ResolvedCopilotCredential {
        let token: String
        let accountID: UUID?
        let label: String
        let source: String
        let accountCount: Int
    }

    func resolveCopilotProvider(_ providerID: String) throws -> UsageProvider {
        let normalized = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else {
            throw NolonCoreCLIError.invalidArguments("Missing required option: --provider (copilot).")
        }
        guard normalized == UsageProvider.copilot.rawValue else {
            throw NolonCoreCLIError.invalidArguments("Unsupported --provider: \(providerID). Expected copilot.")
        }
        return .copilot
    }

    func copilotAuthStatus(provider: UsageProvider) throws -> CopilotAuthStatusPayload {
        let accountData = try tokenAccountStore.loadAccounts()[provider]
        let resolvedCredential = resolveCopilotCredential(from: accountData)
        return CopilotAuthStatusPayload(
            provider: provider.rawValue,
            accountCount: resolvedCredential?.accountCount ?? 0,
            activeAccountID: resolvedCredential?.accountID?.uuidString.lowercased(),
            label: resolvedCredential?.label,
            source: resolvedCredential?.source
        )
    }

    func copilotAuthLogin(
        provider: UsageProvider,
        token: String,
        label: String?
    ) async throws -> CopilotAuthMutationPayload {
        guard let normalizedToken = normalizedNonEmpty(token) else {
            throw NolonCoreCLIError.invalidArguments("Missing required option: --token")
        }

        let accountLabel = normalizedNonEmpty(label) ?? "GitHub Copilot"
        let payload = try await fetchCopilotUsagePayload(provider: provider, token: normalizedToken, label: accountLabel)

        let account = ProviderTokenAccount(
            id: UUID(),
            label: accountLabel,
            token: normalizedToken,
            addedAt: payload.updatedAt.timeIntervalSince1970,
            lastUsed: payload.updatedAt.timeIntervalSince1970
        )

        var allAccounts = try tokenAccountStore.loadAccounts()
        allAccounts[provider] = ProviderTokenAccountData(version: 1, accounts: [account], activeIndex: 0)
        try tokenAccountStore.storeAccounts(allAccounts)

        return CopilotAuthMutationPayload(
            provider: provider.rawValue,
            action: "login",
            accountID: account.id.uuidString.lowercased(),
            activeAccountID: account.id.uuidString.lowercased(),
            accountCount: 1,
            label: account.displayName,
            plan: payload.plan
        )
    }

    func copilotAuthUsage(provider: UsageProvider) async throws -> CopilotUsagePayload {
        guard let credential = try resolveCopilotCredential(provider: provider) else {
            throw NolonCoreCLIError.domainFailed(
                code: "copilot_missing_token",
                message: ProviderUsageError.missingToken(.copilot).localizedDescription
            )
        }
        return try await fetchCopilotUsagePayload(
            provider: provider,
            token: credential.token,
            label: credential.label,
            accountID: credential.accountID,
            source: credential.source
        )
    }

    func copilotAuthDelete(provider: UsageProvider) throws -> CopilotAuthMutationPayload {
        var allAccounts = try tokenAccountStore.loadAccounts()
        allAccounts.removeValue(forKey: provider)
        try tokenAccountStore.storeAccounts(allAccounts)
        return CopilotAuthMutationPayload(
            provider: provider.rawValue,
            action: "delete",
            accountID: nil,
            activeAccountID: nil,
            accountCount: 0,
            label: nil,
            plan: nil
        )
    }

    func fetchCopilotUsagePayload(
        provider: UsageProvider,
        token: String,
        label: String,
        accountID: UUID? = nil,
        source: String = NSLocalizedString("usage.source.api_token", value: "API token", comment: "API token")
    ) async throws -> CopilotUsagePayload {
        let descriptor = CopilotUsageDescriptor(fetchUsage: copilotUsageFetchAction)
        let context = ProviderFetchContext(
            provider: provider,
            sourceMode: .apiToken,
            includeCredits: false,
            timeout: 20,
            costWindowDays: nil,
            environment: [:],
            token: token
        )

        let outcome = await descriptor.fetchOutcome(context: context)
        switch outcome.result {
        case let .success(result):
            let resolvedLabel = normalizedNonEmpty(result.usage.identity?.accountEmail) ?? label
            return CopilotUsagePayload(
                provider: provider.rawValue,
                activeAccountID: accountID?.uuidString.lowercased(),
                label: resolvedLabel,
                plan: result.usage.identity?.plan,
                source: source,
                updatedAt: result.usage.updatedAt,
                windows: result.usage.allWindows.map {
                    CopilotUsageWindowEntry(
                        id: $0.id,
                        title: $0.title,
                        usedPercent: $0.window.usedPercent,
                        resetDescription: $0.window.resetDescription
                    )
                }
            )
        case let .failure(error):
            throw mapCopilotError(error)
        }
    }

    func activeCopilotAccount(provider: UsageProvider) throws -> ProviderTokenAccount? {
        try activeCopilotAccount(from: tokenAccountStore.loadAccounts()[provider])
    }

    func activeCopilotAccount(from data: ProviderTokenAccountData?) -> ProviderTokenAccount? {
        guard let data, !data.accounts.isEmpty else { return nil }
        let index = data.clampedActiveIndex()
        guard data.accounts.indices.contains(index) else { return nil }
        return data.accounts[index]
    }

    func resolveCopilotCredential(provider: UsageProvider) throws -> ResolvedCopilotCredential? {
        try resolveCopilotCredential(from: tokenAccountStore.loadAccounts()[provider])
    }

    func resolveCopilotCredential(from data: ProviderTokenAccountData?) -> ResolvedCopilotCredential? {
        if let account = activeCopilotAccount(from: data) {
            return .init(
                token: account.token,
                accountID: account.id,
                label: account.displayName,
                source: "token_account",
                accountCount: data?.accounts.count ?? 1
            )
        }

        guard let token = normalizedNonEmpty(copilotTokenResolver()) else {
            return nil
        }
        return .init(
            token: token,
            accountID: nil,
            label: "GitHub CLI",
            source: "gh",
            accountCount: 1
        )
    }

    func mapCopilotError(_ error: Error) -> NolonCoreCLIError {
        if let usageError = error as? ProviderUsageError {
            switch usageError {
            case .missingToken:
                return .domainFailed(code: "copilot_missing_token", message: usageError.localizedDescription)
            default:
                return .domainFailed(code: "copilot_usage_failed", message: usageError.localizedDescription)
            }
        }

        if let usageError = error as? CopilotUsageError {
            switch usageError {
            case .unauthorized:
                return .domainFailed(code: "copilot_unauthorized", message: usageError.localizedDescription)
            default:
                return .domainFailed(code: "copilot_usage_failed", message: usageError.localizedDescription)
            }
        }

        return .executionFailed(error.localizedDescription)
    }

    func formatCopilotAuthStatusText(result: CopilotAuthStatusPayload) -> String {
        var lines = [
            "provider: \(result.provider)",
            "account_count: \(result.accountCount)",
        ]
        if let activeAccountID = result.activeAccountID {
            lines.append("active_account_id: \(activeAccountID)")
        }
        if let label = result.label {
            lines.append("label: \(label)")
        }
        if let source = result.source {
            lines.append("source: \(source)")
        }
        return lines.joined(separator: "\n")
    }

    func formatCopilotAuthMutationText(result: CopilotAuthMutationPayload) -> String {
        var lines = [
            "provider: \(result.provider)",
            "action: \(result.action)",
            "account_count: \(result.accountCount)",
        ]
        if let accountID = result.accountID {
            lines.append("account_id: \(accountID)")
        }
        if let activeAccountID = result.activeAccountID {
            lines.append("active_account_id: \(activeAccountID)")
        }
        if let label = result.label {
            lines.append("label: \(label)")
        }
        if let plan = result.plan {
            lines.append("plan: \(plan)")
        }
        return lines.joined(separator: "\n")
    }

    func formatCopilotUsageText(result: CopilotUsagePayload) -> String {
        var lines = [
            "provider: \(result.provider)",
            "label: \(result.label)",
        ]
        if let activeAccountID = result.activeAccountID {
            lines.append("active_account_id: \(activeAccountID)")
        }
        if let plan = result.plan {
            lines.append("plan: \(plan)")
        }
        lines.append("source: \(result.source)")
        lines.append("updated_at: \(ISO8601DateFormatter().string(from: result.updatedAt))")
        lines.append(contentsOf: result.windows.map { window in
            var line = "\(window.title): used=\(Self.formatPercent(window.usedPercent))%"
            if let resetDescription = window.resetDescription {
                line += " \(resetDescription)"
            }
            return line
        })
        return lines.joined(separator: "\n")
    }

    static func formatPercent(_ value: Double) -> String {
        let rounded = (value * 100).rounded() / 100
        if rounded == rounded.rounded() {
            return String(Int(rounded))
        }
        return String(rounded)
    }
}

struct CopilotAuthStatusPayload: Encodable, Sendable {
    let provider: String
    let accountCount: Int
    let activeAccountID: String?
    let label: String?
    let source: String?

    enum CodingKeys: String, CodingKey {
        case provider
        case accountCount = "account_count"
        case activeAccountID = "active_account_id"
        case label
        case source
    }
}

struct CopilotAuthMutationPayload: Encodable, Sendable {
    let provider: String
    let action: String
    let accountID: String?
    let activeAccountID: String?
    let accountCount: Int
    let label: String?
    let plan: String?

    enum CodingKeys: String, CodingKey {
        case provider
        case action
        case accountID = "account_id"
        case activeAccountID = "active_account_id"
        case accountCount = "account_count"
        case label
        case plan
    }
}

struct CopilotUsageWindowEntry: Encodable, Sendable {
    let id: String
    let title: String
    let usedPercent: Double
    let resetDescription: String?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case usedPercent = "used_percent"
        case resetDescription = "reset_description"
    }
}

struct CopilotUsagePayload: Encodable, Sendable {
    let provider: String
    let activeAccountID: String?
    let label: String
    let plan: String?
    let source: String
    let updatedAt: Date
    let windows: [CopilotUsageWindowEntry]

    enum CodingKeys: String, CodingKey {
        case provider
        case activeAccountID = "active_account_id"
        case label
        case plan
        case source
        case updatedAt = "updated_at"
        case windows
    }
}

public struct NolonCoreCLIRunner: Sendable {
    public typealias FileReader = @Sendable (String) throws -> String
    public typealias GeminiUsageFetchAction = @Sendable (UsageProvider) async -> [ProviderAccountUsageOutcome]
    public typealias GeminiTokenTrendFetchAction = @Sendable (UsageProvider) async throws -> ProviderTokenTrendSnapshot?
    public typealias CopilotUsageFetchAction = @Sendable (String) async throws -> CopilotUsageSnapshot
    public typealias CopilotTokenResolver = @Sendable () -> String?

    static let pluginDescriptors: [PluginDescriptor] = [
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

    let service: any NolonSkillsRepositoryServing
    let fileReader: FileReader
    let tokenAccountStore: ProviderTokenAccountStoring
    let geminiUsageFetchAction: GeminiUsageFetchAction
    let geminiTokenTrendFetchAction: GeminiTokenTrendFetchAction
    let copilotUsageFetchAction: CopilotUsageFetchAction
    let copilotTokenResolver: CopilotTokenResolver
    let installedStatusService = InstalledResourceStatusService()

    public init(
        service: any NolonSkillsRepositoryServing = NolonLiveSkillsRepositoryService(),
        fileReader: @escaping FileReader = { path in
            try STFile(path).read()
        },
        tokenAccountStore: ProviderTokenAccountStoring = FileTokenAccountStore(
            fileURL: ProviderUsagePaths.defaultTokenAccountsFileURL()
        ),
        geminiUsageFetchAction: GeminiUsageFetchAction? = nil,
        geminiTokenTrendFetchAction: GeminiTokenTrendFetchAction? = nil,
        copilotUsageFetchAction: CopilotUsageFetchAction? = nil,
        copilotTokenResolver: CopilotTokenResolver? = nil
    ) {
        self.service = service
        self.fileReader = fileReader
        self.tokenAccountStore = tokenAccountStore
        self.geminiUsageFetchAction = geminiUsageFetchAction ?? { provider in
            await Self.defaultFetchGeminiUsage(provider: provider)
        }
        self.geminiTokenTrendFetchAction = geminiTokenTrendFetchAction ?? { provider in
            try await GeminiTokenTrendService().fetchActiveSnapshot(provider: provider, trailingDays: nil)
        }
        self.copilotUsageFetchAction = copilotUsageFetchAction ?? { token in
            try await CopilotUsageFetcher(token: token).fetch()
        }
        self.copilotTokenResolver = copilotTokenResolver ?? {
            GitHubCLITokenResolver.resolveSync()
        }
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

    func renderError(_ error: NolonCoreCLIError, outputMode: NolonCoreCLIOutputMode) -> String {
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

    func normalizeError(_ error: NolonCoreCLIError) -> NolonCoreCLIError {
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

    func fetchRemoteResources(
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

    func mapRemoteCatalogErrorIfNeeded(_ error: NolonCoreCLIError, kind: NolonRemoteCatalogKind) -> NolonCoreCLIError? {
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

    func executeCommand(_ command: NolonCoreCLICommand) async throws -> String {
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

        case let .geminiAuthList(providerID):
            let provider = try resolveGeminiAuthProvider(providerID)
            let listing = try await loadGeminiAccountListing(provider: provider)
            return try encodeSuccess(
                command: command.commandID,
                data: GeminiAuthListPayload(
                    provider: provider.rawValue,
                    activeAccountID: listing.activeAccountID?.uuidString.lowercased(),
                    accounts: listing.accounts
                )
            )

        case let .geminiAuthStatus(providerID):
            let provider = try resolveGeminiAuthProvider(providerID)
            let listing = try await loadGeminiAccountListing(provider: provider)
            return try encodeSuccess(
                command: command.commandID,
                data: GeminiAuthStatusPayload(
                    provider: provider.rawValue,
                    accountCount: listing.accounts.count,
                    activeAccountID: listing.activeAccountID?.uuidString.lowercased()
                )
            )

        case let .geminiAuthLogin(providerID, method, timeoutSeconds, name, email, apiKey, googleAPIKey, project, location, useADC):
            let provider = try resolveGeminiAuthProvider(providerID)
            let mutation = try await geminiAuthLogin(
                provider: provider,
                methodRaw: method,
                timeoutSeconds: timeoutSeconds,
                name: name,
                email: email,
                apiKey: apiKey,
                googleAPIKey: googleAPIKey,
                project: project,
                location: location,
                useADC: useADC
            )
            return try encodeSuccess(command: command.commandID, data: mutation)

        case let .geminiAuthRefresh(providerID):
            let provider = try resolveGeminiAuthProvider(providerID)
            let _ = try await touchActiveGeminiAccount(provider: provider)
            let result = await fetchGeminiUsage(provider: provider)
            let tokenTrend = await fetchGeminiTokenTrend(provider: provider)
            return try encodeSuccess(
                command: command.commandID,
                data: GeminiUsagePayload(
                    provider: provider.rawValue,
                    refreshed: true,
                    activeAccountID: try await activeGeminiAccountID(provider: provider)?.uuidString.lowercased(),
                    entries: makeGeminiUsageEntries(result),
                    tokenTrend: tokenTrend.map(makeGeminiTokenTrendEntry)
                )
            )

        case let .geminiAuthActivate(providerID, accountID):
            let provider = try resolveGeminiAuthProvider(providerID)
            let mutation = try await geminiAuthActivate(provider: provider, accountID: accountID)
            return try encodeSuccess(command: command.commandID, data: mutation)

        case let .geminiAuthDelete(providerID, accountID):
            let provider = try resolveGeminiAuthProvider(providerID)
            let mutation = try await geminiAuthDelete(provider: provider, accountID: accountID)
            return try encodeSuccess(command: command.commandID, data: mutation)

        case let .geminiAuthUsage(providerID):
            let provider = try resolveGeminiAuthProvider(providerID)
            let result = await fetchGeminiUsage(provider: provider)
            let tokenTrend = await fetchGeminiTokenTrend(provider: provider)
            return try encodeSuccess(
                command: command.commandID,
                data: GeminiUsagePayload(
                    provider: provider.rawValue,
                    refreshed: false,
                    activeAccountID: try await activeGeminiAccountID(provider: provider)?.uuidString.lowercased(),
                    entries: makeGeminiUsageEntries(result),
                    tokenTrend: tokenTrend.map(makeGeminiTokenTrendEntry)
                )
            )

        case let .geminiAuthDoctor(providerID):
            let provider = try resolveGeminiAuthProvider(providerID)
            let result = await fetchGeminiUsage(provider: provider)
            let diagnosis = diagnoseGeminiUsage(result)
            return try encodeSuccess(
                command: command.commandID,
                data: GeminiUsageDoctorPayload(
                    provider: provider.rawValue,
                    healthy: diagnosis.healthy,
                    issues: diagnosis.issues,
                    hints: diagnosis.hints,
                    diagnostics: diagnosis.diagnostics
                )
            )

        case let .copilotAuthLogin(providerID, token, label):
            let provider = try resolveCopilotProvider(providerID)
            let mutation = try await copilotAuthLogin(provider: provider, token: token, label: label)
            return try encodeSuccess(command: command.commandID, data: mutation)

        case let .copilotAuthStatus(providerID):
            let provider = try resolveCopilotProvider(providerID)
            return try encodeSuccess(command: command.commandID, data: try copilotAuthStatus(provider: provider))

        case let .copilotAuthUsage(providerID):
            let provider = try resolveCopilotProvider(providerID)
            return try encodeSuccess(command: command.commandID, data: try await copilotAuthUsage(provider: provider))

        case let .copilotAuthDelete(providerID):
            let provider = try resolveCopilotProvider(providerID)
            return try encodeSuccess(command: command.commandID, data: try copilotAuthDelete(provider: provider))

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

    func executeCommandText(_ command: NolonCoreCLICommand) async throws -> String {
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
        case let .geminiAuthList(providerID):
            let provider = try resolveGeminiAuthProvider(providerID)
            let listing = try await loadGeminiAccountListing(provider: provider)
            return formatGeminiAuthListText(
                provider: provider,
                activeAccountID: listing.activeAccountID,
                accounts: listing.accounts
            )
        case let .geminiAuthStatus(providerID):
            let provider = try resolveGeminiAuthProvider(providerID)
            let listing = try await loadGeminiAccountListing(provider: provider)
            return formatGeminiAuthStatusText(
                provider: provider,
                accountCount: listing.accounts.count,
                activeAccountID: listing.activeAccountID
            )
        case let .geminiAuthLogin(providerID, method, timeoutSeconds, name, email, apiKey, googleAPIKey, project, location, useADC):
            let provider = try resolveGeminiAuthProvider(providerID)
            let mutation = try await geminiAuthLogin(
                provider: provider,
                methodRaw: method,
                timeoutSeconds: timeoutSeconds,
                name: name,
                email: email,
                apiKey: apiKey,
                googleAPIKey: googleAPIKey,
                project: project,
                location: location,
                useADC: useADC
            )
            return formatGeminiAuthMutationText(result: mutation)
        case let .geminiAuthRefresh(providerID):
            let provider = try resolveGeminiAuthProvider(providerID)
            let _ = try await touchActiveGeminiAccount(provider: provider)
            let result = await fetchGeminiUsage(provider: provider)
            let tokenTrend = await fetchGeminiTokenTrend(provider: provider)
            return formatGeminiUsageText(
                provider: provider,
                entries: makeGeminiUsageEntries(result),
                tokenTrend: tokenTrend.map(makeGeminiTokenTrendEntry)
            )
        case let .geminiAuthActivate(providerID, accountID):
            let provider = try resolveGeminiAuthProvider(providerID)
            let mutation = try await geminiAuthActivate(provider: provider, accountID: accountID)
            return formatGeminiAuthMutationText(result: mutation)
        case let .geminiAuthDelete(providerID, accountID):
            let provider = try resolveGeminiAuthProvider(providerID)
            let mutation = try await geminiAuthDelete(provider: provider, accountID: accountID)
            return formatGeminiAuthMutationText(result: mutation)
        case let .geminiAuthUsage(providerID):
            let provider = try resolveGeminiAuthProvider(providerID)
            let result = await fetchGeminiUsage(provider: provider)
            let tokenTrend = await fetchGeminiTokenTrend(provider: provider)
            return formatGeminiUsageText(
                provider: provider,
                entries: makeGeminiUsageEntries(result),
                tokenTrend: tokenTrend.map(makeGeminiTokenTrendEntry)
            )
        case let .geminiAuthDoctor(providerID):
            let provider = try resolveGeminiAuthProvider(providerID)
            let result = await fetchGeminiUsage(provider: provider)
            let diagnosis = diagnoseGeminiUsage(result)
            return formatGeminiUsageDoctorText(provider: provider, diagnosis: diagnosis)
        case let .copilotAuthLogin(providerID, token, label):
            let provider = try resolveCopilotProvider(providerID)
            return formatCopilotAuthMutationText(
                result: try await copilotAuthLogin(provider: provider, token: token, label: label)
            )
        case let .copilotAuthStatus(providerID):
            let provider = try resolveCopilotProvider(providerID)
            return formatCopilotAuthStatusText(result: try copilotAuthStatus(provider: provider))
        case let .copilotAuthUsage(providerID):
            let provider = try resolveCopilotProvider(providerID)
            return formatCopilotUsageText(result: try await copilotAuthUsage(provider: provider))
        case let .copilotAuthDelete(providerID):
            let provider = try resolveCopilotProvider(providerID)
            return formatCopilotAuthMutationText(result: try copilotAuthDelete(provider: provider))
        default:
            return try await executeCommand(command)
        }
    }
}
