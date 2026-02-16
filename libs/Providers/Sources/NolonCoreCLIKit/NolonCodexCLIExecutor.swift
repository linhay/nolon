import ArgumentParser
import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

enum NolonCodexCLIExecutor {
    private enum OutputMode {
        case text
        case json
    }

    struct IOOverrides: Sendable {
        let isTTY: @Sendable () -> Bool
        let readInputLine: @Sendable () -> String?
        let writePrompt: @Sendable (String) -> Void
    }

    @TaskLocal
    private static var ioOverrides: IOOverrides?

    private static let defaultIO = IOOverrides(
        isTTY: { isatty(STDIN_FILENO) == 1 },
        readInputLine: { readLine(strippingNewline: true) },
        writePrompt: { prompt in
            FileHandle.standardOutput.write(Data(prompt.utf8))
        }
    )

    static func withIOOverrides<T>(
        _ overrides: IOOverrides,
        operation: () async throws -> T
    ) async rethrows -> T {
        try await $ioOverrides.withValue(overrides, operation: operation)
    }

    private static func currentIO() -> IOOverrides {
        ioOverrides ?? defaultIO
    }

    static func execute(
        arguments: [String],
        context: NolonCLIExecutionContext
    ) async throws -> String {
        let (outputMode, normalizedArguments) = extractOutputMode(arguments: arguments)
        try validateUnsupportedRoute(arguments: normalizedArguments)
        let parsed = try parseRootCommand(normalizedArguments)

        switch parsed {
        case let command as NolonCodexAuthListCommand:
            return try await executeAuthList(command: command, context: context, outputMode: outputMode)
        case let command as NolonCodexAuthStatusCommand:
            return try await executeAuthStatus(command: command, context: context, outputMode: outputMode)
        case let command as NolonCodexAuthActivateCommand:
            return try await executeAuthActivate(command: command, context: context, outputMode: outputMode)
        case let command as NolonCodexAuthLoginCommand:
            return try await executeAuthLogin(command: command, context: context, outputMode: outputMode)
        case let command as NolonCodexAuthDeleteCommand:
            return try await executeAuthDelete(command: command, context: context, outputMode: outputMode)
        case _ as NolonCodexBinaryListCommand:
            return try await executeBinaryList(context: context, outputMode: outputMode)
        case _ as NolonCodexBinaryAvailableCommand:
            return try await executeBinaryAvailable(context: context, outputMode: outputMode)
        case _ as NolonCodexBinarySwitchCommand:
            return try await executeBinarySwitch(context: context, outputMode: outputMode)
        case _ as NolonCodexBinaryCurrentCommand:
            return try await executeBinaryCurrent(context: context, outputMode: outputMode)
        case let command as NolonCodexBinaryInstallCommand:
            return try await executeBinaryInstall(command: command, context: context, outputMode: outputMode)
        case let command as NolonCodexBinaryUseCommand:
            return try await executeBinaryUse(command: command, context: context, outputMode: outputMode)
        case _ as NolonCodexBinaryDoctorCommand:
            return try await executeBinaryDoctor(context: context, outputMode: outputMode)
        case let command as NolonCodexStatusProbeCommand:
            return try await executeStatusProbe(command: command, context: context, outputMode: outputMode)
        case _ as NolonCodexStatusDoctorCommand:
            return try await executeStatusDoctor(context: context, outputMode: outputMode)
        case _ as NolonCodexRuntimeListCommand:
            return try await executeRuntimeList(context: context, outputMode: outputMode)
        case let command as NolonCodexRuntimeStopCommand:
            return try await executeRuntimeStop(command: command, context: context, outputMode: outputMode)
        case _ as NolonCodexProviderDiscoverCommand:
            return try await executeProviderDiscover(context: context, outputMode: outputMode)
        case _ as NolonProviderListCommand:
            return try await executeProviderList(context: context, outputMode: outputMode)
        default:
            throw NolonCoreCLIError.invalidArguments("Unsupported parsed command type: \(type(of: parsed))")
        }
    }

    private static func executeAuthList(command: NolonCodexAuthListCommand, context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        let payload = try await context.codexService().authList(providerID: providerID)
        return try renderOutput(command: .authList, payload: payload, outputMode: outputMode, textFormatter: formatAuthList)
    }

    private static func executeAuthStatus(command: NolonCodexAuthStatusCommand, context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        let payload = try await context.codexService().authStatus(providerID: providerID)
        return try renderOutput(command: .authStatus, payload: payload, outputMode: outputMode, textFormatter: formatAuthStatus)
    }

    private static func executeAuthActivate(command: NolonCodexAuthActivateCommand, context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        let accountID: UUID
        if command.accountID != nil, command.email != nil {
            throw NolonCoreCLIError.invalidArguments("Use either --account-id or --email, not both.")
        } else if let rawAccountID = command.accountID {
            guard let parsed = UUID(uuidString: rawAccountID) else {
                throw NolonCoreCLIError.invalidArguments("Invalid --account-id: \(rawAccountID)")
            }
            accountID = parsed
        } else if let rawEmail = command.email?.trimmingCharacters(in: .whitespacesAndNewlines), !rawEmail.isEmpty {
            let list = try await context.codexService().authList(providerID: providerID)
            guard let matched = list.accounts.first(where: { account in
                guard let email = account.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty else {
                    return false
                }
                return email.caseInsensitiveCompare(rawEmail) == .orderedSame
            }) else {
                throw NolonCoreCLIError.domainFailed(
                    code: "codex_auth_account_not_found",
                    message: "Codex account not found for email: \(rawEmail)"
                )
            }
            accountID = matched.id
        } else {
            _ = command.tui
            let io = currentIO()
            guard io.isTTY() else {
                throw NolonCoreCLIError.invalidArguments("Interactive selection requires a TTY terminal. Use --account-id <uuid> or --email <email>.")
            }
            let list = try await context.codexService().authList(providerID: providerID)
            guard !list.accounts.isEmpty else {
                throw NolonCoreCLIError.domainFailed(
                    code: "codex_auth_account_not_found",
                    message: "No Codex accounts available for activation."
                )
            }
            io.writePrompt(renderActivatePicker(accounts: list.accounts))
            guard let input = io.readInputLine() else {
                throw NolonCoreCLIError.invalidArguments("Activation cancelled")
            }
            accountID = try parseActivateSelection(input: input, accounts: list.accounts)
        }
        let payload = try await context.codexService().authActivate(providerID: providerID, accountID: accountID)
        return try renderOutput(command: .authActivate, payload: payload, outputMode: outputMode, textFormatter: formatAuthActivate)
    }

    private static func executeAuthLogin(command: NolonCodexAuthLoginCommand, context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
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
        return try renderOutput(command: .authLogin, payload: payload, outputMode: outputMode, textFormatter: formatAuthLogin)
    }

    private static func executeAuthDelete(command: NolonCodexAuthDeleteCommand, context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        guard let accountID = UUID(uuidString: command.accountID) else {
            throw NolonCoreCLIError.invalidArguments("Invalid --account-id: \(command.accountID)")
        }
        let payload = try await context.codexService().authDelete(providerID: providerID, accountID: accountID)
        return try renderOutput(command: .authDelete, payload: payload, outputMode: outputMode, textFormatter: formatAuthDelete)
    }

    private static func executeBinaryList(context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let payload = try await context.codexService().binaryList()
        return try renderOutput(command: .binaryList, payload: payload, outputMode: outputMode, textFormatter: formatBinaryList)
    }

    private static func executeBinaryAvailable(context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let payload = try await context.codexService().binaryAvailable()
        return try renderOutput(command: .binaryAvailable, payload: payload, outputMode: outputMode, textFormatter: formatBinaryAvailable)
    }

    private static func executeBinarySwitch(context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let io = currentIO()
        guard io.isTTY() else {
            throw NolonCoreCLIError.invalidArguments(
                "Interactive selection requires a TTY terminal. Use `nolon codex binary install <version>` or `nolon codex binary use --version <version-or-id>`."
            )
        }

        let installed = try await context.codexService().binaryList()
        let available = try await context.codexService().binaryAvailable()
        let entries = buildBinarySwitchEntries(installed: installed, available: available)
        guard !entries.isEmpty else {
            throw NolonCoreCLIError.domainFailed(code: "codex_binary_not_found", message: "No Codex versions available for switching.")
        }

        io.writePrompt(renderBinarySwitchPicker(entries: entries))
        guard let input = io.readInputLine() else {
            throw NolonCoreCLIError.invalidArguments("Switch cancelled")
        }

        let selection = try parseBinarySwitchSelection(input: input, entries: entries)
        switch selection.action {
        case .activate:
            let payload = try await context.codexService().binaryUse(version: selection.versionID)
            let result = NolonCodexBinarySwitchPayload(
                action: "activate",
                requestedVersion: selection.version,
                selectedVersionID: payload.selectedVersionID
            )
            return try renderOutput(command: .binarySwitch, payload: result, outputMode: outputMode, textFormatter: formatBinarySwitch)
        case .install:
            let payload = try await context.codexService().binaryInstall(version: selection.version, setDefault: true)
            let result = NolonCodexBinarySwitchPayload(
                action: "install",
                requestedVersion: payload.requestedVersion,
                selectedVersionID: payload.installedVersionID
            )
            return try renderOutput(command: .binarySwitch, payload: result, outputMode: outputMode, textFormatter: formatBinarySwitch)
        }
    }

    private static func executeBinaryCurrent(context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let payload = try await context.codexService().binaryCurrent()
        return try renderOutput(command: .binaryCurrent, payload: payload, outputMode: outputMode, textFormatter: formatBinaryCurrent)
    }

    private static func executeBinaryInstall(command: NolonCodexBinaryInstallCommand, context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let version = try parseCodexVersionArgument(command.version, option: "version")
        let payload = try await context.codexService().binaryInstall(version: version, setDefault: command.setDefault)
        return try renderOutput(command: .binaryInstall, payload: payload, outputMode: outputMode, textFormatter: formatBinaryInstall)
    }

    private static func executeBinaryUse(command: NolonCodexBinaryUseCommand, context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let version = try parseCodexVersionArgument(command.version, option: "--version")
        let payload = try await context.codexService().binaryUse(version: version)
        return try renderOutput(command: .binaryUse, payload: payload, outputMode: outputMode, textFormatter: formatBinaryUse)
    }

    private static func executeBinaryDoctor(context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let payload = try await context.codexService().binaryDoctor()
        return try renderOutput(command: .binaryDoctor, payload: payload, outputMode: outputMode, textFormatter: formatBinaryDoctor)
    }

    private static func executeStatusProbe(command: NolonCodexStatusProbeCommand, context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let providerID: String?
        if let provider = command.provider {
            providerID = try parseCodexProviderID(provider)
        } else {
            providerID = nil
        }
        let payload: NolonCodexStatusProbePayload
        do {
            payload = try await context.codexService().statusProbe(providerID: providerID)
        } catch {
            guard shouldDowngradeStatusProbeError(error) else { throw error }
            payload = makeStatusProbeWarningPayload(providerID: providerID, message: error.localizedDescription)
        }
        return try renderOutput(command: .statusProbe, payload: payload, outputMode: outputMode, textFormatter: formatStatusProbe)
    }

    private static func executeStatusDoctor(context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let auth = try await context.codexService().authStatus(providerID: "codex")
        let binary = try await context.codexService().binaryDoctor()
        let runtime = try await context.codexService().runtimeList(providerID: nil)
        let statusPayload: NolonCodexStatusProbePayload
        do {
            statusPayload = try await context.codexService().statusProbe(providerID: "codex")
        } catch {
            guard shouldDowngradeStatusProbeError(error) else { throw error }
            statusPayload = makeStatusProbeWarningPayload(providerID: "codex", message: error.localizedDescription)
        }
        let payload = NolonCodexStatusDoctorPayload(
            providerID: "codex",
            accountCount: auth.accountCount,
            activeAccountID: auth.activeAccountID?.uuidString,
            selectedVersionID: binary.selectedVersionID,
            currentVersion: binary.currentVersion,
            pathActive: binary.pathActive,
            runtimeCount: runtime.processes.count,
            resolvedExecutable: statusPayload.resolvedExecutable,
            probeWarning: statusPayload.probeWarning,
            probeHint: statusPayload.probeHint
        )
        return try renderOutput(command: .statusDoctor, payload: payload, outputMode: outputMode, textFormatter: formatStatusDoctor)
    }

    private static func executeRuntimeList(context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let payload = try await context.codexService().runtimeList(providerID: nil)
        return try renderOutput(command: .runtimeList, payload: payload, outputMode: outputMode, textFormatter: formatRuntimeList)
    }

    private static func executeRuntimeStop(command: NolonCodexRuntimeStopCommand, context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
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
        return try renderOutput(command: .runtimeStop, payload: payload, outputMode: outputMode, textFormatter: formatRuntimeStop)
    }

    private static func executeProviderDiscover(context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let payload = try await context.codexService().providerDiscover()
        return try renderOutput(command: .providerDiscover, payload: payload, outputMode: outputMode, textFormatter: formatProviderDiscover)
    }

    private static func executeProviderList(context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let payload = try await context.codexService().providerList()
        return try renderOutput(command: .providerList, payload: payload, outputMode: outputMode, textFormatter: formatProviderList)
    }

    private static func shouldDowngradeStatusProbeError(_ error: Error) -> Bool {
        let message: String
        if let cliError = error as? NolonCoreCLIError {
            message = cliError.errorDescription ?? error.localizedDescription
        } else {
            message = error.localizedDescription
        }
        return message.localizedCaseInsensitiveContains("Could not parse Codex status")
    }

    private static func makeStatusProbeWarningPayload(providerID: String?, message: String) -> NolonCodexStatusProbePayload {
        NolonCodexStatusProbePayload(
            providerID: providerID,
            resolvedExecutable: nil,
            credits: nil,
            fiveHourPercentLeft: nil,
            weeklyPercentLeft: nil,
            fiveHourResetDescription: nil,
            weeklyResetDescription: nil,
            probeWarning: message,
            probeHint: "Run `nolon codex status doctor --json` for diagnostics, then retry."
        )
    }

    private static func extractOutputMode(arguments: [String]) -> (OutputMode, [String]) {
        let filtered = arguments.filter { $0 != "--json" }
        let outputMode: OutputMode = filtered.count == arguments.count ? .text : .json
        return (outputMode, filtered)
    }

    private static func renderOutput<Payload: Encodable>(
        command: NolonCodexCommandPath,
        payload: Payload,
        outputMode: OutputMode,
        textFormatter: (Payload) -> String
    ) throws -> String {
        switch outputMode {
        case .text:
            return textFormatter(payload)
        case .json:
            return try encodeJSON(
                NolonCodexSuccessEnvelope(
                    command: command.rawValue,
                    data: payload
                )
            )
        }
    }

    private static func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }

    private static func parseRootCommand(_ arguments: [String]) throws -> any ParsableCommand {
        do {
            return try NolonRootCommand.parseAsRoot(arguments)
        } catch {
            throw NolonCoreCLIError.invalidArguments(error.localizedDescription)
        }
    }

    private static func validateUnsupportedRoute(arguments: [String]) throws {
        guard arguments.count >= 2 else { return }
        let root = arguments[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if root == "provider" {
            let actions: Set<String> = ["list"]
            guard arguments.count >= 2 else { return }
            let action = arguments[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !actions.contains(action) {
                throw NolonCoreCLIError.domainFailed(
                    code: "unsupported_command",
                    message: "Unsupported command: provider.\(action). Available actions for provider: list."
                )
            }
            return
        }

        guard root == "codex" else { return }
        let group = arguments[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let supportedByGroup: [String: Set<String>] = [
            "auth": ["list", "status", "activate", "login", "delete"],
            "binary": ["list", "current", "install", "use", "available", "switch", "doctor"],
            "status": ["probe", "doctor"],
            "runtime": ["list", "stop"],
            "provider": ["discover"],
        ]
        guard let actions = supportedByGroup[group] else {
            throw NolonCoreCLIError.invalidArguments(
                "Unknown group '\(group)'. Available groups: \(supportedByGroup.keys.sorted().joined(separator: ", "))."
            )
        }
        guard arguments.count >= 3 else { return }
        let action = arguments[2].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !actions.contains(action) {
            throw NolonCoreCLIError.domainFailed(
                code: "unsupported_command",
                message: "Unsupported command: \(root).\(group).\(action). Available actions for \(group): \(actions.sorted().joined(separator: ", "))."
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

    private enum BinarySwitchAction {
        case activate
        case install
    }

    private struct BinarySwitchEntry {
        let version: String
        let tag: String?
        let versionID: String
        let status: String
        let isSelected: Bool
        let action: BinarySwitchAction
    }

    private static func buildBinarySwitchEntries(
        installed: NolonCodexBinaryListPayload,
        available: NolonCodexBinaryAvailablePayload
    ) -> [BinarySwitchEntry] {
        var entries: [BinarySwitchEntry] = []
        let installedVersions = Set(installed.versions.map { $0.detectedVersion })

        for version in installed.versions {
            entries.append(
                BinarySwitchEntry(
                    version: version.detectedVersion,
                    tag: nil,
                    versionID: version.id,
                    status: "已安装",
                    isSelected: version.isSelected,
                    action: .activate
                )
            )
        }

        for release in available.versions where !installedVersions.contains(release.version) {
            entries.append(
                BinarySwitchEntry(
                    version: release.version,
                    tag: release.tag,
                    versionID: release.version,
                    status: "可下载",
                    isSelected: false,
                    action: .install
                )
            )
        }

        return entries
    }

    private static func renderBinarySwitchPicker(entries: [BinarySwitchEntry]) -> String {
        let rows = entries.enumerated().map { index, entry -> String in
            let selected = entry.isSelected ? "*" : " "
            let tag = entry.tag.map { " (\($0))" } ?? ""
            return "\(index + 1). [\(selected) \(entry.status)] \(entry.version)\(tag)"
        }
        return """
        请选择要切换的版本（输入编号，q 取消）:
        \(rows.joined(separator: "\n"))
        > 
        """
    }

    private static func parseBinarySwitchSelection(
        input: String,
        entries: [BinarySwitchEntry]
    ) throws -> BinarySwitchEntry {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if trimmed == "q" {
            throw NolonCoreCLIError.invalidArguments("Switch cancelled")
        }
        guard let index = Int(trimmed), index > 0, index <= entries.count else {
            throw NolonCoreCLIError.invalidArguments("Invalid selection")
        }
        return entries[index - 1]
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

    private static func formatBinaryAvailable(_ payload: NolonCodexBinaryAvailablePayload) -> String {
        guard !payload.versions.isEmpty else { return "" }
        let versionWidth = payload.versions.map { $0.version.count }.max() ?? 0
        let tagWidth = payload.versions.map { $0.tag.count }.max() ?? 0
        let prereleaseWidth = payload.versions.map { $0.isPrerelease.description.count }.max() ?? 0

        return payload.versions
            .map { release in
                let versionColumn = padRight(release.version, to: versionWidth)
                let tagColumn = padRight(release.tag, to: tagWidth)
                let prereleaseColumn = padRight(release.isPrerelease.description, to: prereleaseWidth)
                return "\(versionColumn) | \(tagColumn) | \(prereleaseColumn) | \(release.downloadURL)"
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

    private static func formatBinarySwitch(_ payload: NolonCodexBinarySwitchPayload) -> String {
        [
            "action: \(payload.action)",
            "requested_version: \(payload.requestedVersion)",
            "selected_version_id: \(payload.selectedVersionID)",
        ].joined(separator: "\n")
    }

    private static func formatStatusProbe(_ payload: NolonCodexStatusProbePayload) -> String {
        var rows: [(String, String)] = [
            ("provider", payload.providerID ?? "-"),
            ("resolved_executable", payload.resolvedExecutable ?? "-"),
            ("credits", payload.credits.map { String($0) } ?? "-"),
            ("five_hour_percent_left", payload.fiveHourPercentLeft.map { String($0) } ?? "-"),
            ("weekly_percent_left", payload.weeklyPercentLeft.map { String($0) } ?? "-"),
            ("five_hour_reset", payload.fiveHourResetDescription ?? "-"),
            ("weekly_reset", payload.weeklyResetDescription ?? "-"),
        ]
        if let warning = payload.probeWarning, !warning.isEmpty {
            rows.append(("probe_warning", warning))
            if let hint = payload.probeHint, !hint.isEmpty {
                rows.append(("probe_hint", hint))
            }
        }
        let keyWidth = rows.map(\.0.count).max() ?? 0
        return rows
            .map { key, value in
                "\(padRight(key, to: keyWidth)) | \(value)"
            }
            .joined(separator: "\n")
    }

    private static func formatStatusDoctor(_ payload: NolonCodexStatusDoctorPayload) -> String {
        let checks: [(name: String, status: String, detail: String)] = [
            (
                "auth",
                payload.accountCount > 0 ? "ok" : "warn",
                "accounts=\(payload.accountCount), active=\(payload.activeAccountID ?? "-")"
            ),
            (
                "binary",
                payload.pathActive ? "ok" : "warn",
                "selected=\(payload.selectedVersionID ?? "-"), current=\(payload.currentVersion ?? "-")"
            ),
            (
                "runtime",
                "ok",
                "running=\(payload.runtimeCount)"
            ),
            (
                "status_probe",
                payload.probeWarning == nil ? "ok" : "warn",
                {
                    if let warning = payload.probeWarning {
                        if let hint = payload.probeHint, !hint.isEmpty {
                            return "\(warning) (hint: \(hint))"
                        }
                        return warning
                    }
                    return "resolved=\(payload.resolvedExecutable ?? "-")"
                }()
            ),
        ]

        let nameWidth = max("检查项".count, checks.map(\.name.count).max() ?? 0)
        let statusWidth = max("状态".count, checks.map(\.status.count).max() ?? 0)
        let header = "\(padRight("检查项", to: nameWidth)) | \(padRight("状态", to: statusWidth)) | 详情"
        let body = checks
            .map { check in
                "\(padRight(check.name, to: nameWidth)) | \(padRight(check.status, to: statusWidth)) | \(check.detail)"
            }
            .joined(separator: "\n")
        return "\(header)\n\(body)"
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

    private static func formatProviderDiscover(_ payload: NolonCodexProviderDiscoverPayload) -> String {
        guard !payload.providers.isEmpty else { return "No codex providers discovered." }
        let rows = payload.providers.map { provider in
            let state: String
            if !provider.authExists {
                state = "missing"
            } else if provider.authIsSymlink {
                state = "symlink"
            } else {
                state = "file"
            }
            return (
                providerID: provider.providerID,
                state: state,
                authPath: provider.authPath,
                target: provider.authSymlinkTargetPath ?? "-"
            )
        }

        let providerWidth = max("provider".count, rows.map(\.providerID.count).max() ?? 0)
        let stateWidth = max("auth_state".count, rows.map(\.state.count).max() ?? 0)
        let authPathWidth = max("auth_path".count, rows.map(\.authPath.count).max() ?? 0)
        let header = "\(padRight("provider", to: providerWidth)) | \(padRight("auth_state", to: stateWidth)) | \(padRight("auth_path", to: authPathWidth)) | link_target"
        let body = rows.map { row in
            "\(padRight(row.providerID, to: providerWidth)) | \(padRight(row.state, to: stateWidth)) | \(padRight(row.authPath, to: authPathWidth)) | \(row.target)"
        }.joined(separator: "\n")
        return "\(header)\n\(body)"
    }

    private static func formatProviderList(_ payload: NolonProviderListPayload) -> String {
        guard !payload.providers.isEmpty else { return "No providers found." }
        let rows = payload.providers.map { provider in
            (
                providerID: provider.providerID,
                name: provider.name,
                cli: provider.cli,
                installed: provider.installed ? "yes" : "no",
                path: provider.executablePath ?? "-"
            )
        }
        let providerWidth = max("provider".count, rows.map(\.providerID.count).max() ?? 0)
        let nameWidth = max("name".count, rows.map(\.name.count).max() ?? 0)
        let cliWidth = max("cli".count, rows.map(\.cli.count).max() ?? 0)
        let installedWidth = max("installed".count, rows.map(\.installed.count).max() ?? 0)
        let header = "\(padRight("provider", to: providerWidth)) | \(padRight("name", to: nameWidth)) | \(padRight("cli", to: cliWidth)) | \(padRight("installed", to: installedWidth)) | executable_path"
        let body = rows.map { row in
            "\(padRight(row.providerID, to: providerWidth)) | \(padRight(row.name, to: nameWidth)) | \(padRight(row.cli, to: cliWidth)) | \(padRight(row.installed, to: installedWidth)) | \(row.path)"
        }.joined(separator: "\n")
        return "\(header)\n\(body)"
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
        请选择要激活的账号（输入编号 / 账号 UUID / 邮箱，q 取消）:
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
    static let binaryAvailable: Self = "codex.binary.available"
    static let binarySwitch: Self = "codex.binary.switch"
    static let binaryCurrent: Self = "codex.binary.current"
    static let binaryInstall: Self = "codex.binary.install"
    static let binaryUse: Self = "codex.binary.use"
    static let binaryDoctor: Self = "codex.binary.doctor"
    static let statusProbe: Self = "codex.status.probe"
    static let statusDoctor: Self = "codex.status.doctor"
    static let runtimeList: Self = "codex.runtime.list"
    static let runtimeStop: Self = "codex.runtime.stop"
    static let providerDiscover: Self = "codex.provider.discover"
    static let providerList: Self = "provider.list"

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

private struct NolonCodexSuccessEnvelope<Payload: Encodable>: Encodable {
    let ok: Bool = true
    let command: String
    let data: Payload
}

private struct NolonCodexStatusDoctorPayload: Codable, Sendable, Equatable {
    let providerID: String
    let accountCount: Int
    let activeAccountID: String?
    let selectedVersionID: String?
    let currentVersion: String?
    let pathActive: Bool
    let runtimeCount: Int
    let resolvedExecutable: String?
    let probeWarning: String?
    let probeHint: String?
}
