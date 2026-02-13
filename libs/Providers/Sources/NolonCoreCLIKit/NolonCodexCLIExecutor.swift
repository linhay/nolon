import ArgumentParser
import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

enum NolonCodexCLIExecutor {
    static let stdinIsTTY: @Sendable () -> Bool = { isatty(STDIN_FILENO) == 1 }
    static let readInputLine: @Sendable () -> String? = { readLine(strippingNewline: true) }
    static let writePrompt: @Sendable (String) -> Void = { prompt in
        FileHandle.standardOutput.write(Data(prompt.utf8))
    }

    static func execute(
        arguments: [String],
        context: NolonCLIExecutionContext
    ) async throws -> String {
        try validateUnsupportedRoute(arguments: arguments)
        let parsed = try parseRootCommand(arguments)

        switch parsed {
        case let command as NolonCodexAuthListCommand:
            return try await executeAuthList(command: command, context: context)
        case let command as NolonCodexAuthStatusCommand:
            return try await executeAuthStatus(command: command, context: context)
        case let command as NolonCodexAuthActivateCommand:
            return try await executeAuthActivate(command: command, context: context)
        case let command as NolonCodexAuthLoginCommand:
            return try await executeAuthLogin(command: command, context: context)
        case let command as NolonCodexAuthDeleteCommand:
            return try await executeAuthDelete(command: command, context: context)
        case _ as NolonCodexBinaryListCommand:
            return try await executeBinaryList(context: context)
        case _ as NolonCodexBinaryCurrentCommand:
            return try await executeBinaryCurrent(context: context)
        case let command as NolonCodexBinaryInstallCommand:
            return try await executeBinaryInstall(command: command, context: context)
        case let command as NolonCodexBinaryUseCommand:
            return try await executeBinaryUse(command: command, context: context)
        case _ as NolonCodexBinaryDoctorCommand:
            return try await executeBinaryDoctor(context: context)
        case let command as NolonCodexStatusProbeCommand:
            return try await executeStatusProbe(command: command, context: context)
        case _ as NolonCodexRuntimeListCommand:
            return try await executeRuntimeList(context: context)
        case let command as NolonCodexRuntimeStopCommand:
            return try await executeRuntimeStop(command: command, context: context)
        default:
            throw NolonCoreCLIError.invalidArguments("Unsupported parsed command type: \(type(of: parsed))")
        }
    }

    private static func executeAuthList(command: NolonCodexAuthListCommand, context: NolonCLIExecutionContext) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        let payload = try await context.codexService().authList(providerID: providerID)
        return formatAuthList(payload)
    }

    private static func executeAuthStatus(command: NolonCodexAuthStatusCommand, context: NolonCLIExecutionContext) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        let payload = try await context.codexService().authStatus(providerID: providerID)
        return formatAuthStatus(payload)
    }

    private static func executeAuthActivate(command: NolonCodexAuthActivateCommand, context: NolonCLIExecutionContext) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        let accountID: UUID
        if let rawAccountID = command.accountID {
            guard let parsed = UUID(uuidString: rawAccountID) else {
                throw NolonCoreCLIError.invalidArguments("Invalid --account-id: \(rawAccountID)")
            }
            accountID = parsed
        } else {
            _ = command.tui
            guard stdinIsTTY() else {
                throw NolonCoreCLIError.invalidArguments("Interactive selection requires a TTY terminal.")
            }
            let list = try await context.codexService().authList(providerID: providerID)
            guard !list.accounts.isEmpty else {
                throw NolonCoreCLIError.domainFailed(
                    code: "codex_auth_account_not_found",
                    message: "No Codex accounts available for activation."
                )
            }
            writePrompt(renderActivatePicker(accounts: list.accounts))
            guard let input = readInputLine() else {
                throw NolonCoreCLIError.invalidArguments("Activation cancelled")
            }
            accountID = try parseActivateSelection(input: input, accounts: list.accounts)
        }
        let payload = try await context.codexService().authActivate(providerID: providerID, accountID: accountID)
        return formatAuthActivate(payload)
    }

    private static func executeAuthLogin(command: NolonCodexAuthLoginCommand, context: NolonCLIExecutionContext) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        let preferred: UUID?
        if let preferredAccountID = command.preferredAccountID {
            guard let parsed = UUID(uuidString: preferredAccountID) else {
                throw NolonCoreCLIError.invalidArguments("Invalid --preferred-account-id: \(preferredAccountID)")
            }
            preferred = parsed
        } else {
            preferred = nil
        }
        let payload = try await context.codexService().authLogin(providerID: providerID, preferredAccountID: preferred)
        return formatAuthLogin(payload)
    }

    private static func executeAuthDelete(command: NolonCodexAuthDeleteCommand, context: NolonCLIExecutionContext) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        guard let accountID = UUID(uuidString: command.accountID) else {
            throw NolonCoreCLIError.invalidArguments("Invalid --account-id: \(command.accountID)")
        }
        let payload = try await context.codexService().authDelete(providerID: providerID, accountID: accountID)
        return formatAuthDelete(payload)
    }

    private static func executeBinaryList(context: NolonCLIExecutionContext) async throws -> String {
        let payload = try await context.codexService().binaryList()
        return formatBinaryList(payload)
    }

    private static func executeBinaryCurrent(context: NolonCLIExecutionContext) async throws -> String {
        let payload = try await context.codexService().binaryCurrent()
        return formatBinaryCurrent(payload)
    }

    private static func executeBinaryInstall(command: NolonCodexBinaryInstallCommand, context: NolonCLIExecutionContext) async throws -> String {
        let version = try parseCodexVersionArgument(command.version, option: "--version")
        let payload = try await context.codexService().binaryInstall(version: version, setDefault: command.setDefault)
        return formatBinaryInstall(payload)
    }

    private static func executeBinaryUse(command: NolonCodexBinaryUseCommand, context: NolonCLIExecutionContext) async throws -> String {
        let version = try parseCodexVersionArgument(command.version, option: "--version")
        let payload = try await context.codexService().binaryUse(version: version)
        return formatBinaryUse(payload)
    }

    private static func executeBinaryDoctor(context: NolonCLIExecutionContext) async throws -> String {
        let payload = try await context.codexService().binaryDoctor()
        return formatBinaryDoctor(payload)
    }

    private static func executeStatusProbe(command: NolonCodexStatusProbeCommand, context: NolonCLIExecutionContext) async throws -> String {
        let providerID: String?
        if let provider = command.provider {
            providerID = try parseCodexProviderID(provider)
        } else {
            providerID = nil
        }
        let payload = try await context.codexService().statusProbe(providerID: providerID)
        return formatStatusProbe(payload)
    }

    private static func executeRuntimeList(context: NolonCLIExecutionContext) async throws -> String {
        let payload = try await context.codexService().runtimeList(providerID: nil)
        return formatRuntimeList(payload)
    }

    private static func executeRuntimeStop(command: NolonCodexRuntimeStopCommand, context: NolonCLIExecutionContext) async throws -> String {
        guard command.pid > 1 else {
            throw NolonCoreCLIError.invalidArguments("Invalid --pid: \(command.pid)")
        }
        guard command.timeoutSeconds > 0 else {
            throw NolonCoreCLIError.invalidArguments("Invalid --timeout-seconds: \(command.timeoutSeconds)")
        }
        let payload = try await context.codexService().runtimeStop(
            pid: command.pid,
            force: command.force,
            timeoutSeconds: command.timeoutSeconds
        )
        return formatRuntimeStop(payload)
    }

    private static func parseRootCommand(_ arguments: [String]) throws -> any ParsableCommand {
        do {
            return try NolonRootCommand.parseAsRoot(arguments)
        } catch {
            throw NolonCoreCLIError.invalidArguments(error.localizedDescription)
        }
    }

    private static func validateUnsupportedRoute(arguments: [String]) throws {
        guard arguments.count >= 3 else { return }
        let root = arguments[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard root == "codex" else { return }
        let group = arguments[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let action = arguments[2].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let supportedByGroup: [String: Set<String>] = [
            "auth": ["list", "status", "activate", "login", "delete"],
            "binary": ["list", "current", "install", "use", "doctor"],
            "status": ["probe"],
            "runtime": ["list", "stop"],
        ]
        if let actions = supportedByGroup[group], !actions.contains(action) {
            throw NolonCoreCLIError.domainFailed(
                code: "unsupported_command",
                message: "Unsupported command: \(root).\(group).\(action)"
            )
        }
    }

    private static func parseCodexProviderID(_ providerID: String) throws -> String {
        try canonicalCodexProviderID(providerID)
    }

    private static func parseCodexVersionArgument(_ raw: String, option: String) throws -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw NolonCoreCLIError.invalidArguments("Invalid \(option): value cannot be empty")
        }
        return trimmed
    }

    private static func canonicalCodexProviderID(_ providerID: String) throws -> String {
        let normalized = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch normalized {
        case "codex":
            return "codex"
        case "codexxcode", "codex-xcode":
            return "codex-xcode"
        default:
            throw NolonCoreCLIError.invalidArguments("Unsupported --provider: \(providerID)")
        }
    }

    private static func formatBinaryList(_ payload: NolonCodexBinaryListPayload) -> String {
        guard !payload.versions.isEmpty else { return "" }
        let versionWidth = payload.versions.map { $0.detectedVersion.count }.max() ?? 0
        let nameWidth = payload.versions.map { $0.displayName.count }.max() ?? 0
        let sourceWidth = payload.versions.map { $0.source.count }.max() ?? 0

        return payload.versions
            .map { version in
                let marker = version.isSelected ? "*" : " "
                let versionColumn = padRight(version.detectedVersion, to: versionWidth)
                let nameColumn = padRight(version.displayName, to: nameWidth)
                let sourceColumn = padRight(version.source, to: sourceWidth)
                return "\(marker) \(versionColumn) | \(nameColumn) | \(sourceColumn) | \(version.id)"
            }
            .joined(separator: "\n")
    }

    private static func padRight(_ value: String, to width: Int) -> String {
        guard value.count < width else { return value }
        return value + String(repeating: " ", count: width - value.count)
    }

    private static func formatAuthList(_ payload: NolonCodexAuthListPayload) -> String {
        let title = "邮箱 | 状态 | 用量 | 刷新时间"
        guard !payload.accounts.isEmpty else { return title }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        let rows: [(marker: String, email: String, status: String, usage: String, refresh: String)] = payload.accounts.map { account in
            let marker = account.isActive ? "*" : " "
            let emailRaw = account.email?.trimmingCharacters(in: .whitespacesAndNewlines)
            let email = (emailRaw?.isEmpty == false) ? (emailRaw ?? "-") : "-"
            let status = account.isActive ? "已激活" : "未激活"
            let usageRaw = account.usageDisplay?.trimmingCharacters(in: .whitespacesAndNewlines)
            let usage = (usageRaw?.isEmpty == false) ? (usageRaw ?? "-") : "-"
            let refresh = account.refreshedAt.map { formatter.string(from: $0) } ?? "-"
            return (marker, email, status, usage, refresh)
        }

        let emailWidth = max("邮箱".count, rows.map { $0.email.count }.max() ?? 0)
        let statusWidth = max("状态".count, rows.map { $0.status.count }.max() ?? 0)
        let usageWidth = max("用量".count, rows.map { $0.usage.count }.max() ?? 0)
        let refreshWidth = max("刷新时间".count, rows.map { $0.refresh.count }.max() ?? 0)

        let header = "\(padRight("邮箱", to: emailWidth)) | \(padRight("状态", to: statusWidth)) | \(padRight("用量", to: usageWidth)) | \(padRight("刷新时间", to: refreshWidth))"
        let body = rows.map { row in
            "\(row.marker) \(padRight(row.email, to: emailWidth)) | \(padRight(row.status, to: statusWidth)) | \(padRight(row.usage, to: usageWidth)) | \(padRight(row.refresh, to: refreshWidth))"
        }.joined(separator: "\n")
        return "\(header)\n\(body)"
    }

    private static func formatAuthStatus(_ payload: NolonCodexAuthStatusPayload) -> String {
        [
            "provider: \(payload.providerID)",
            "active_account_id: \(payload.activeAccountID?.uuidString ?? "-")",
            "account_count: \(payload.accountCount)",
            "auth_hash_hex: \(payload.authHashHex ?? "-")",
        ].joined(separator: "\n")
    }

    private static func formatAuthActivate(_ payload: NolonCodexAuthActivatePayload) -> String {
        [
            "provider: \(payload.providerID)",
            "account_id: \(payload.accountID.uuidString)",
            "runtime_switched: \(payload.runtimeSwitched)",
            "runtime_error: \(payload.runtimeErrorDescription ?? "-")",
        ].joined(separator: "\n")
    }

    private static func formatAuthLogin(_ payload: NolonCodexAuthLoginPayload) -> String {
        [
            "provider: \(payload.providerID)",
            "account_id: \(payload.accountID.uuidString)",
            "account_name: \(payload.accountName)",
            "login_url: \(payload.loginURL ?? "-")",
            "runtime_switched: \(payload.runtimeSwitched)",
            "runtime_error: \(payload.runtimeErrorDescription ?? "-")",
        ].joined(separator: "\n")
    }

    private static func formatAuthDelete(_ payload: NolonCodexAuthDeletePayload) -> String {
        [
            "provider: \(payload.providerID)",
            "account_id: \(payload.accountID.uuidString)",
            "was_active: \(payload.wasActive)",
        ].joined(separator: "\n")
    }

    private static func formatBinaryCurrent(_ payload: NolonCodexBinaryCurrentPayload) -> String {
        [
            "selected_version_id: \(payload.selectedVersionID ?? "-")",
            "current_version: \(payload.currentVersion ?? "-")",
            "active_cli_path: \(payload.activeCLIPath ?? "-")",
        ].joined(separator: "\n")
    }

    private static func formatBinaryInstall(_ payload: NolonCodexBinaryInstallPayload) -> String {
        [
            "requested_version: \(payload.requestedVersion)",
            "installed_version_id: \(payload.installedVersionID)",
            "installed_detected_version: \(payload.installedDetectedVersion)",
            "activated: \(payload.activated)",
        ].joined(separator: "\n")
    }

    private static func formatBinaryUse(_ payload: NolonCodexBinaryUsePayload) -> String {
        "selected_version_id: \(payload.selectedVersionID)"
    }

    private static func formatBinaryDoctor(_ payload: NolonCodexBinaryDoctorPayload) -> String {
        [
            "selected_version_id: \(payload.selectedVersionID ?? "-")",
            "current_version: \(payload.currentVersion ?? "-")",
            "active_cli_path: \(payload.activeCLIPath ?? "-")",
            "managed_version_count: \(payload.managedVersionCount)",
            "path_configured: \(payload.pathConfigured)",
            "path_active: \(payload.pathActive)",
            "profile_path: \(payload.profilePath)",
        ].joined(separator: "\n")
    }

    private static func formatStatusProbe(_ payload: NolonCodexStatusProbePayload) -> String {
        let rows: [(String, String)] = [
            ("provider", payload.providerID ?? "-"),
            ("resolved_executable", payload.resolvedExecutable ?? "-"),
            ("credits", payload.credits.map { String($0) } ?? "-"),
            ("five_hour_percent_left", payload.fiveHourPercentLeft.map { String($0) } ?? "-"),
            ("weekly_percent_left", payload.weeklyPercentLeft.map { String($0) } ?? "-"),
            ("five_hour_reset", payload.fiveHourResetDescription ?? "-"),
            ("weekly_reset", payload.weeklyResetDescription ?? "-"),
        ]
        let keyWidth = rows.map(\.0.count).max() ?? 0
        return rows
            .map { key, value in
                "\(padRight(key, to: keyWidth)) | \(value)"
            }
            .joined(separator: "\n")
    }

    private static func formatRuntimeList(_ payload: NolonCodexRuntimeListPayload) -> String {
        let title = "PID | PPID | 运行时长 | Provider | 命令"
        guard !payload.processes.isEmpty else { return title }

        let pidWidth = max("PID".count, payload.processes.map { String($0.pid).count }.max() ?? 0)
        let ppidWidth = max("PPID".count, payload.processes.map { $0.ppid.map(String.init)?.count ?? 1 }.max() ?? 0)
        let elapsedWidth = max("运行时长".count, payload.processes.map { $0.elapsed.count }.max() ?? 0)
        let providerWidth = max("Provider".count, payload.processes.map { ($0.providerHint ?? "-").count }.max() ?? 0)

        let header = "\(padRight("PID", to: pidWidth)) | \(padRight("PPID", to: ppidWidth)) | \(padRight("运行时长", to: elapsedWidth)) | \(padRight("Provider", to: providerWidth)) | 命令"
        let body = payload.processes.map { process in
            let ppidText = process.ppid.map(String.init) ?? "-"
            let providerText = process.providerHint ?? "-"
            return "\(padRight(String(process.pid), to: pidWidth)) | \(padRight(ppidText, to: ppidWidth)) | \(padRight(process.elapsed, to: elapsedWidth)) | \(padRight(providerText, to: providerWidth)) | \(process.command)"
        }.joined(separator: "\n")
        return "\(header)\n\(body)"
    }

    private static func formatRuntimeStop(_ payload: NolonCodexRuntimeStopPayload) -> String {
        [
            "pid: \(payload.pid)",
            "signal: \(payload.requestedSignal)",
            "escalated: \(payload.didEscalateToKill)",
            "exited: \(payload.exited)",
        ].joined(separator: "\n")
    }

    static func parseActivateSelection(input: String, accounts: [NolonCodexAuthAccountView]) throws -> UUID {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased() == "q" || trimmed.lowercased() == "quit" {
            throw NolonCoreCLIError.invalidArguments("Activation cancelled")
        }
        if let parsedIndex = Int(trimmed), parsedIndex >= 1, parsedIndex <= accounts.count {
            return accounts[parsedIndex - 1].id
        }
        if let uuid = UUID(uuidString: trimmed), accounts.contains(where: { $0.id == uuid }) {
            return uuid
        }
        if let matchedByEmail = accounts.first(where: { account in
            guard let email = account.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
                return false
            }
            return email.caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            return matchedByEmail.id
        }
        throw NolonCoreCLIError.invalidArguments("Invalid selection")
    }

    static func renderActivatePicker(accounts: [NolonCodexAuthAccountView]) -> String {
        let rows = accounts.enumerated().map { index, account -> String in
            let marker = account.isActive ? "*" : " "
            let email = account.email ?? "-"
            let usageRaw = account.usageDisplay?.trimmingCharacters(in: .whitespacesAndNewlines)
            let usage = (usageRaw?.isEmpty == false) ? (usageRaw ?? "-") : "-"
            return "\(index + 1). [\(marker)] \(account.name) <\(email)> 用量: \(usage) \(account.id.uuidString)"
        }
        return """
        请选择要激活的账号（输入编号 / 账号 UUID，q 取消）:
        \(rows.joined(separator: "\n"))
        > 
        """
    }
}

private struct NolonCodexCommandPath: RawRepresentable, ExpressibleByStringLiteral, Equatable, Sendable {
    static let authList: Self = "codex.auth.list"
    static let authStatus: Self = "codex.auth.status"
    static let authActivate: Self = "codex.auth.activate"
    static let authLogin: Self = "codex.auth.login"
    static let authDelete: Self = "codex.auth.delete"
    static let binaryList: Self = "codex.binary.list"
    static let binaryCurrent: Self = "codex.binary.current"
    static let binaryInstall: Self = "codex.binary.install"
    static let binaryUse: Self = "codex.binary.use"
    static let binaryDoctor: Self = "codex.binary.doctor"
    static let statusProbe: Self = "codex.status.probe"
    static let runtimeList: Self = "codex.runtime.list"
    static let runtimeStop: Self = "codex.runtime.stop"

    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(_ value: String) {
        self.rawValue = value
    }

    init(stringLiteral value: String) {
        self.rawValue = value
    }
}
