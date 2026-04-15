import ArgumentParser
import Foundation

public enum NolonCLIEntrypoint {
    public static func execute(
        arguments: [String],
        codexService: any NolonCodexCLIServing = NolonLiveCodexCLIService()
    ) async -> NolonCLIExecutionResult {
        let normalizedArguments = normalizeHelpArguments(arguments)
        if let helpText = resolveHelp(arguments: normalizedArguments) {
            return NolonCLIExecutionResult(exitCode: 0, stdout: helpText, stderr: "")
        }

        if shouldRouteToCoreCLI(arguments: normalizedArguments) {
            let (outputMode, forwardedArguments) = extractCoreOutputMode(arguments: normalizedArguments)
            return await NolonCoreCLIRunner().execute(arguments: forwardedArguments, outputMode: outputMode)
        }

        let context = NolonCLIExecutionContext(service: codexService)
        do {
            let output = try await NolonCodexCLIExecutor.execute(arguments: normalizedArguments, context: context)
            return NolonCLIExecutionResult(exitCode: 0, stdout: output, stderr: "")
        } catch is CancellationError {
            let wrapped = NolonCoreCLIError.domainFailed(code: "interrupted", message: "Operation cancelled")
            return NolonCLIExecutionResult(exitCode: 130, stdout: "", stderr: context.errorJSON(for: wrapped))
        } catch let error as NolonCoreCLIError {
            return NolonCLIExecutionResult(exitCode: 2, stdout: "", stderr: context.errorJSON(for: error))
        } catch {
            let message = NolonRootCommand.message(for: error)
            let wrapped = NolonCoreCLIError.invalidArguments(message)
            return NolonCLIExecutionResult(exitCode: 2, stdout: "", stderr: context.errorJSON(for: wrapped))
        }
    }

    private static func shouldRouteToCoreCLI(arguments: [String]) -> Bool {
        let forwarded = arguments.filter { $0 != "--json" }
        guard let root = forwarded.first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        else {
            return false
        }
        return root == "skills"
            || root == "workflow"
            || root == "mcp"
            || root == "plugin"
            || root == "remote"
            || root == "gemini"
            || root == "copilot"
    }

    private static func extractCoreOutputMode(arguments: [String]) -> (NolonCoreCLIOutputMode, [String]) {
        let forwarded = arguments.filter { $0 != "--json" }
        let mode: NolonCoreCLIOutputMode = forwarded.count == arguments.count ? .text : .json
        return (mode, forwarded)
    }

    private static func normalizeHelpArguments(_ arguments: [String]) -> [String] {
        guard !arguments.isEmpty else { return [] }
        if arguments[0].lowercased() == "help" {
            if arguments.count == 1 { return [] }
            var forwarded = Array(arguments.dropFirst())
            if forwarded.last == "help" {
                forwarded[forwarded.count - 1] = "--help"
            }
            if !forwarded.contains("--help"), !forwarded.contains("-h") {
                forwarded.append("--help")
            }
            return forwarded
        }
        var normalized = arguments
        if normalized.last == "help" {
            normalized[normalized.count - 1] = "--help"
        }
        if normalized.contains("--help") || normalized.contains("-h") {
            return normalized
        }
        let root = normalized[0].lowercased()
        let groupsNeedingHelp: [String: Set<String>] = [
            "codex": ["auth", "binary", "status", "session", "runtime", "provider"],
            "skills": [],
            "copilot": ["auth"],
        ]
        let rootCommands = Set(["codex", "provider", "skills", "workflow", "mcp", "plugin", "remote", "copilot"])
        if normalized.count == 1, rootCommands.contains(root) {
            return normalized + ["--help"]
        }
        if normalized.count == 2, let groups = groupsNeedingHelp[root] {
            let group = normalized[1].lowercased()
            if groups.contains(group) {
                return normalized + ["--help"]
            }
        }
        return normalized
    }

    private static func resolveHelp(arguments: [String]) -> String? {
        if arguments.isEmpty {
            return NolonRootCommand.helpMessage()
        }
        let hasHelpFlag = arguments.contains("--help") || arguments.contains("-h")
        guard hasHelpFlag else {
            return nil
        }
        let cleaned = arguments.filter { $0 != "--help" && $0 != "-h" }
        if let coreHelp = NolonCoreCLIHelpResolver.resolvedHelpText(arguments: cleaned) {
            return coreHelp
        }
        if let codexHelp = NolonCodexCLIHelpResolver.resolvedHelpText(arguments: cleaned + ["--help"]) {
            return codexHelp
        }
        guard let target = helpTargetType(for: cleaned) else {
            return nil
        }
        return NolonRootCommand.message(for: CleanExit.helpRequest(target))
    }

    private static func helpTargetType(for arguments: [String]) -> ParsableCommand.Type? {
        guard let root = arguments.first?.lowercased() else {
            return NolonRootCommand.self
        }
        switch root {
        case "codex":
            guard arguments.count >= 2 else { return NolonCodexRootCommand.self }
            let group = arguments[1].lowercased()
            switch group {
            case "auth":
                guard arguments.count >= 3 else { return NolonCodexAuthGroupCommand.self }
                return codexAuthCommandType(action: arguments[2])
            case "binary":
                guard arguments.count >= 3 else { return NolonCodexBinaryGroupCommand.self }
                return codexBinaryCommandType(action: arguments[2])
            case "status":
                guard arguments.count >= 3 else { return NolonCodexStatusGroupCommand.self }
                return codexStatusCommandType(action: arguments[2])
            case "session":
                guard arguments.count >= 3 else { return NolonCodexSessionGroupCommand.self }
                return codexSessionCommandType(action: arguments[2])
            case "runtime":
                guard arguments.count >= 3 else { return NolonCodexRuntimeGroupCommand.self }
                return codexRuntimeCommandType(action: arguments[2])
            case "provider":
                guard arguments.count >= 3 else { return NolonCodexProviderGroupCommand.self }
                return codexProviderCommandType(action: arguments[2])
            default:
                return NolonCodexRootCommand.self
            }
        case "provider":
            guard arguments.count >= 2 else { return NolonProviderRootCommand.self }
            let action = arguments[1].lowercased()
            switch action {
            case "list":
                return NolonProviderListCommand.self
            case "discover":
                return NolonProviderDiscoverCommand.self
            default:
                return NolonProviderRootCommand.self
            }
        case "skills":
            guard arguments.count >= 2 else { return NolonSkillsRootCommand.self }
            let action = arguments[1].lowercased()
            switch action {
            case "list":
                return NolonSkillsListCommand.self
            case "sync":
                return NolonSkillsSyncCommand.self
            case "repo":
                guard arguments.count >= 3 else { return NolonSkillsRepoGroupCommand.self }
                return skillsRepoCommandType(action: arguments[2])
            case "migrate":
                guard arguments.count >= 3 else { return NolonSkillsMigrateGroupCommand.self }
                return skillsMigrateCommandType(action: arguments[2])
            case "discover":
                return NolonSkillsDiscoverCommand.self
            case "search":
                return NolonSkillsSearchCommand.self
            case "add":
                return NolonSkillsAddCommand.self
            case "remove":
                return NolonSkillsRemoveCommand.self
            case "parse":
                return NolonSkillsParseCommand.self
            case "install":
                return NolonSkillsInstallCommand.self
            case "uninstall":
                return NolonSkillsUninstallCommand.self
            default:
                return NolonSkillsRootCommand.self
            }
        case "copilot":
            guard arguments.count >= 2 else { return NolonCopilotRootCommand.self }
            let group = arguments[1].lowercased()
            switch group {
            case "auth":
                guard arguments.count >= 3 else { return NolonCopilotAuthGroupCommand.self }
                return copilotAuthCommandType(action: arguments[2])
            default:
                return NolonCopilotRootCommand.self
            }
        case "workflow":
            guard arguments.count >= 2 else { return NolonWorkflowRootCommand.self }
            return workflowCommandType(action: arguments[1])
        case "mcp":
            guard arguments.count >= 2 else { return NolonMcpRootCommand.self }
            return mcpCommandType(action: arguments[1])
        case "plugin":
            guard arguments.count >= 2 else { return NolonPluginRootCommand.self }
            return pluginCommandType(action: arguments[1])
        case "remote":
            guard arguments.count >= 2 else { return NolonRemoteRootCommand.self }
            return remoteCommandType(action: arguments[1])
        default:
            return NolonRootCommand.self
        }
    }

    private static func codexAuthCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "list":
            return NolonCodexAuthListCommand.self
        case "usage":
            return NolonCodexAuthUsageCommand.self
        case "usage-trend":
            return NolonCodexAuthUsageTrendCommand.self
        case "status":
            return NolonCodexAuthStatusCommand.self
        case "refresh":
            return NolonCodexAuthRefreshCommand.self
        case "activate":
            return NolonCodexAuthActivateCommand.self
        case "login":
            return NolonCodexAuthLoginCommand.self
        case "delete":
            return NolonCodexAuthDeleteCommand.self
        default:
            return NolonCodexAuthGroupCommand.self
        }
    }

    private static func codexBinaryCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "list":
            return NolonCodexBinaryListCommand.self
        case "current":
            return NolonCodexBinaryCurrentCommand.self
        case "install":
            return NolonCodexBinaryInstallCommand.self
        case "use":
            return NolonCodexBinaryUseCommand.self
        case "available":
            return NolonCodexBinaryAvailableCommand.self
        case "switch":
            return NolonCodexBinarySwitchCommand.self
        case "doctor":
            return NolonCodexBinaryDoctorCommand.self
        default:
            return NolonCodexBinaryGroupCommand.self
        }
    }

    private static func copilotAuthCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "login":
            return NolonCopilotAuthLoginCommand.self
        case "status":
            return NolonCopilotAuthStatusCommand.self
        case "usage":
            return NolonCopilotAuthUsageCommand.self
        case "delete":
            return NolonCopilotAuthDeleteCommand.self
        default:
            return NolonCopilotAuthGroupCommand.self
        }
    }

    private static func codexStatusCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "probe":
            return NolonCodexStatusProbeCommand.self
        case "doctor":
            return NolonCodexStatusDoctorCommand.self
        default:
            return NolonCodexStatusGroupCommand.self
        }
    }

    private static func codexRuntimeCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "list":
            return NolonCodexRuntimeListCommand.self
        case "stop":
            return NolonCodexRuntimeStopCommand.self
        default:
            return NolonCodexRuntimeGroupCommand.self
        }
    }

    private static func codexSessionCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "list":
            return NolonCodexSessionListCommand.self
        case "preview-rewrite":
            return NolonCodexSessionPreviewRewriteCommand.self
        case "rewrite":
            return NolonCodexSessionRewriteCommand.self
        default:
            return NolonCodexSessionGroupCommand.self
        }
    }

    private static func codexProviderCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "discover":
            return NolonCodexProviderDiscoverCommand.self
        default:
            return NolonCodexProviderGroupCommand.self
        }
    }

    private static func skillsRepoCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "plan":
            return NolonSkillsRepoPlanCommand.self
        case "preflight":
            return NolonSkillsRepoPreflightCommand.self
        case "list":
            return NolonSkillsRepoListCommand.self
        case "sync":
            return NolonSkillsRepoSyncCommand.self
        default:
            return NolonSkillsRepoGroupCommand.self
        }
    }

    private static func skillsMigrateCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "scan":
            return NolonSkillsMigrateScanCommand.self
        case "apply":
            return NolonSkillsMigrateApplyCommand.self
        default:
            return NolonSkillsMigrateGroupCommand.self
        }
    }

    private static func workflowCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "list":
            return NolonWorkflowListCommand.self
        case "sync":
            return NolonWorkflowSyncCommand.self
        case "search":
            return NolonWorkflowSearchCommand.self
        case "add":
            return NolonWorkflowAddCommand.self
        case "remove":
            return NolonWorkflowRemoveCommand.self
        default:
            return NolonWorkflowRootCommand.self
        }
    }

    private static func mcpCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "list":
            return NolonMcpListCommand.self
        case "sync":
            return NolonMcpSyncCommand.self
        case "search":
            return NolonMcpSearchCommand.self
        case "add":
            return NolonMcpAddCommand.self
        case "remove":
            return NolonMcpRemoveCommand.self
        case "server":
            return NolonMcpServerRootCommand.self
        case "cache":
            return NolonMcpCacheRootCommand.self
        default:
            return NolonMcpRootCommand.self
        }
    }

    private static func pluginCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "list":
            return NolonPluginListCommand.self
        case "status":
            return NolonPluginStatusCommand.self
        case "install":
            return NolonPluginInstallCommand.self
        case "uninstall":
            return NolonPluginUninstallCommand.self
        case "upgrade":
            return NolonPluginUpgradeCommand.self
        case "start":
            return NolonPluginStartCommand.self
        case "stop":
            return NolonPluginStopCommand.self
        default:
            return NolonPluginRootCommand.self
        }
    }

    private static func remoteCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "list":
            return NolonRemoteListCommand.self
        case "download":
            return NolonRemoteDownloadCommand.self
        case "sync":
            return NolonRemoteSyncCommand.self
        case "install":
            return NolonRemoteInstallCommand.self
        case "sync-install":
            return NolonRemoteSyncInstallCommand.self
        default:
            return NolonRemoteRootCommand.self
        }
    }
}
