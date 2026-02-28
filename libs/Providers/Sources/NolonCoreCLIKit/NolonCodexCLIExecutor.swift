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
        case let command as NolonCodexAuthUsageCommand:
            return try await executeAuthUsage(command: command, context: context, outputMode: outputMode)
        case let command as NolonCodexAuthUsageTrendCommand:
            return try await executeAuthUsageTrend(command: command, context: context, outputMode: outputMode)
        case let command as NolonCodexAuthStatusCommand:
            return try await executeAuthStatus(command: command, context: context, outputMode: outputMode)
        case let command as NolonCodexAuthRefreshCommand:
            return try await executeAuthRefresh(command: command, context: context, outputMode: outputMode)
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
        case _ as NolonProviderDiscoverCommand:
            return try await executeProviderList(context: context, outputMode: outputMode)
        default:
            throw NolonCoreCLIError.invalidArguments("Unsupported parsed command type: \(type(of: parsed))")
        }
    }

    private static func executeAuthList(command: NolonCodexAuthListCommand, context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        if outputMode == .text {
            return try await renderAuthOverview(providerID: providerID, context: context)
        }
        let payload = try await context.codexService().authList(providerID: providerID)
        return try renderOutput(
            command: .authList,
            payload: payload,
            outputMode: outputMode,
            textFormatter: { formatAuthList($0) }
        )
    }

    private static func executeAuthUsage(command: NolonCodexAuthUsageCommand, context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        if command.accountID != nil, command.email != nil {
            throw NolonCoreCLIError.invalidArguments("Use either --account-id or --email, not both.")
        }
        if command.refresh == false, (command.accountID != nil || command.email != nil) {
            throw NolonCoreCLIError.invalidArguments("--account-id/--email requires --refresh.")
        }

        let targetAccountID: UUID?
        if let rawAccountID = command.accountID {
            guard let parsed = UUID(uuidString: rawAccountID) else {
                throw NolonCoreCLIError.invalidArguments("Invalid --account-id: \(rawAccountID)")
            }
            targetAccountID = parsed
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
            targetAccountID = matched.id
        } else {
            targetAccountID = nil
        }

        if outputMode == .text, command.summary == false {
            return try await renderAuthOverview(
                providerID: providerID,
                context: context,
                refreshUsage: command.refresh,
                targetAccountID: targetAccountID
            )
        }
        let payload: NolonCodexAuthUsagePayload
        if command.refresh {
            payload = try await context.codexService().authUsageRefresh(providerID: providerID, accountID: targetAccountID)
        } else {
            payload = try await context.codexService().authUsage(providerID: providerID)
        }
        if command.summary {
            return try renderOutput(command: .authUsage, payload: payload, outputMode: outputMode, textFormatter: formatAuthUsageSummary)
        }
        return try renderOutput(
            command: .authUsage,
            payload: payload,
            outputMode: outputMode,
            textFormatter: { formatAuthUsageAccounts($0) }
        )
    }

    private static func executeAuthStatus(command: NolonCodexAuthStatusCommand, context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        if outputMode == .text {
            return try await renderAuthOverview(providerID: providerID, context: context)
        }
        let payload = try await context.codexService().authStatus(providerID: providerID)
        return try renderOutput(command: .authStatus, payload: payload, outputMode: outputMode, textFormatter: formatAuthStatus)
    }

    private static func executeAuthUsageTrend(command: NolonCodexAuthUsageTrendCommand, context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        let rangeRaw = command.range.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let range = NolonCodexUsageTrendRange(rawValue: rangeRaw) else {
            throw NolonCoreCLIError.invalidArguments("Invalid --range: \(command.range). Supported values: 7d, 30d, all")
        }
        let payload = try await context.codexService().authUsageTrend(providerID: providerID, range: range)
        return try renderOutput(command: .authUsageTrend, payload: payload, outputMode: outputMode, textFormatter: formatAuthUsageTrend)
    }

    private static func executeAuthRefresh(command: NolonCodexAuthRefreshCommand, context: NolonCLIExecutionContext, outputMode: OutputMode) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        if command.accountID != nil, command.email != nil {
            throw NolonCoreCLIError.invalidArguments("Use either --account-id or --email, not both.")
        }

        let targetAccountID: UUID?
        if let rawAccountID = command.accountID {
            guard let parsed = UUID(uuidString: rawAccountID) else {
                throw NolonCoreCLIError.invalidArguments("Invalid --account-id: \(rawAccountID)")
            }
            targetAccountID = parsed
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
            targetAccountID = matched.id
        } else {
            targetAccountID = nil
        }

        let payload = try await context.codexService().authRefresh(providerID: providerID, accountID: targetAccountID)
        return try renderOutput(command: .authRefresh, payload: payload, outputMode: outputMode, textFormatter: formatAuthRefresh)
    }

    private static func renderAuthOverview(
        providerID: String,
        context: NolonCLIExecutionContext,
        refreshUsage: Bool = false,
        targetAccountID: UUID? = nil
    ) async throws -> String {
        let service = context.codexService()
        let list = try await service.authList(providerID: providerID)
        let usage: NolonCodexAuthUsagePayload
        if refreshUsage {
            usage = try await service.authUsageRefresh(providerID: providerID, accountID: targetAccountID)
        } else {
            usage = try await service.authUsage(providerID: providerID)
        }
        let status = try await service.authStatus(providerID: providerID)
        return formatAuthOverview(list: list, usage: usage, status: status)
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
            let message = NolonRootCommand.message(for: error)
            throw NolonCoreCLIError.invalidArguments(message)
        }
    }

    private static func validateUnsupportedRoute(arguments: [String]) throws {
        guard arguments.count >= 2 else { return }
        let root = arguments[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if root == "provider" {
            let actions: Set<String> = ["list", "discover"]
            guard arguments.count >= 2 else { return }
            let action = arguments[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if !actions.contains(action) {
                throw NolonCoreCLIError.domainFailed(
                    code: "unsupported_command",
                    message: "Unsupported command: provider.\(action). Available actions for provider: discover, list."
                )
            }
            return
        }

        guard root == "codex" else { return }
        let group = arguments[1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let supportedByGroup: [String: Set<String>] = [
            "auth": ["list", "usage", "usage-trend", "status", "refresh", "activate", "login", "delete"],
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

    private static func formatAuthList(
        _ payload: NolonCodexAuthListPayload,
        activeAccountIDOverride: UUID? = nil,
        tokenHealthByAccountID: [UUID: String] = [:],
        fallbackUsageAccounts: [NolonCodexAuthUsageAccountView] = []
    ) -> String {
        let title = "邮箱 | 状态 | 令牌健康"

        let resolvedActiveID = activeAccountIDOverride ?? payload.activeAccountID
        let rows: [(marker: String, email: String, status: String, tokenHealth: String)] = {
            if payload.accounts.isEmpty {
                return fallbackUsageAccounts.map { account in
                    let isActive = resolvedActiveID.map { account.id == $0 } ?? account.isActive
                    let marker = isActive ? "*" : " "
                    let emailRaw = account.email?.trimmingCharacters(in: .whitespacesAndNewlines)
                    let email = (emailRaw?.isEmpty == false) ? (emailRaw ?? "-") : "-"
                    let status = isActive ? "已激活" : "未激活"
                    let tokenHealth = tokenHealthByAccountID[account.id] ?? "-"
                    return (marker, email, status, tokenHealth)
                }
            }
            return payload.accounts.map { account in
            let isActive = resolvedActiveID.map { account.id == $0 } ?? account.isActive
            let marker = isActive ? "*" : " "
            let emailRaw = account.email?.trimmingCharacters(in: .whitespacesAndNewlines)
            let email = (emailRaw?.isEmpty == false) ? (emailRaw ?? "-") : "-"
            let status = isActive ? "已激活" : "未激活"
            let tokenHealth = tokenHealthByAccountID[account.id] ?? "-"
            return (marker, email, status, tokenHealth)
            }
        }()
        guard !rows.isEmpty else { return title }

        let emailWidth = max("邮箱".count, rows.map { $0.email.count }.max() ?? 0)
        let statusWidth = max("状态".count, rows.map { $0.status.count }.max() ?? 0)
        let tokenHealthWidth = max("令牌健康".count, rows.map { $0.tokenHealth.count }.max() ?? 0)

        let header = "\(padRight("邮箱", to: emailWidth)) | \(padRight("状态", to: statusWidth)) | \(padRight("令牌健康", to: tokenHealthWidth))"
        let body = rows.map { row in
            "\(row.marker) \(padRight(row.email, to: emailWidth)) | \(padRight(row.status, to: statusWidth)) | \(padRight(row.tokenHealth, to: tokenHealthWidth))"
        }.joined(separator: "\n")
        return "\(header)\n\(body)"
    }

    private static func formatAuthStatus(_ payload: NolonCodexAuthStatusPayload) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        let rows: [(String, String)] = [
            ("提供方", payload.providerID),
            ("激活账号", payload.activeAccountID?.uuidString ?? "-"),
            ("账号总数", String(payload.accountCount)),
            ("已缓存用量", String(payload.usageCachedAccountCount)),
            ("5h平均剩余", payload.usageAvgFiveHourRemainingPercent.map { "\($0)%" } ?? "-"),
            ("7d平均剩余", payload.usageAvgWeeklyRemainingPercent.map { "\($0)%" } ?? "-"),
            ("最新刷新", payload.usageLatestRefreshedAt.map { formatter.string(from: $0) } ?? "-"),
            ("认证快照哈希", payload.authHashHex ?? "-"),
        ]
        let keyWidth = rows.map(\.0.count).max() ?? 0
        return rows.map { key, value in
            "\(padRight(key, to: keyWidth)) | \(value)"
        }.joined(separator: "\n")
    }

    private static func formatAuthOverview(
        list: NolonCodexAuthListPayload,
        usage: NolonCodexAuthUsagePayload,
        status: NolonCodexAuthStatusPayload
    ) -> String {
        let resolvedActiveID = status.activeAccountID ?? list.activeAccountID
        let tokenHealthByAccountID = Dictionary(uniqueKeysWithValues: usage.accounts.map { account in
            (account.id, formatTokenHealth(expiresAt: account.expiresAt, hasRefreshToken: account.hasRefreshToken))
        })
        let sections = [
            "[账号]",
            formatAuthList(
                list,
                activeAccountIDOverride: resolvedActiveID,
                tokenHealthByAccountID: tokenHealthByAccountID,
                fallbackUsageAccounts: usage.accounts
            ),
            "",
            "[用量]",
            formatAuthUsageAccounts(usage, activeAccountIDOverride: resolvedActiveID),
            "",
            "[状态]",
            formatAuthStatus(status),
        ]
        return sections.joined(separator: "\n")
    }

    private static func formatAuthUsageAccounts(_ payload: NolonCodexAuthUsagePayload, activeAccountIDOverride: UUID? = nil) -> String {
        let title = "邮箱 | 状态 | 失败类型 | 5h剩余 | 7d剩余"
        guard !payload.accounts.isEmpty else { return title }

        let resolvedActiveID = activeAccountIDOverride
        let rows: [(marker: String, email: String, status: String, failureType: String, fiveHour: String, weekly: String)] = payload.accounts.map { account in
            let isActive = resolvedActiveID.map { account.id == $0 } ?? account.isActive
            let marker = isActive ? "*" : " "
            let emailRaw = account.email?.trimmingCharacters(in: .whitespacesAndNewlines)
            let email = (emailRaw?.isEmpty == false) ? (emailRaw ?? "-") : "-"
            let status = account.status.rawValue
            let failureType = account.failureType?.rawValue ?? "-"
            let fiveHour = account.fiveHourRemainingPercent.map { "\($0)%" } ?? "-"
            let weekly = account.weeklyRemainingPercent.map { "\($0)%" } ?? "-"
            return (marker, email, status, failureType, fiveHour, weekly)
        }

        let emailWidth = max("邮箱".count, rows.map { $0.email.count }.max() ?? 0)
        let statusWidth = max("状态".count, rows.map { $0.status.count }.max() ?? 0)
        let failureTypeWidth = max("失败类型".count, rows.map { $0.failureType.count }.max() ?? 0)
        let fiveHourWidth = max("5h剩余".count, rows.map { $0.fiveHour.count }.max() ?? 0)
        let weeklyWidth = max("7d剩余".count, rows.map { $0.weekly.count }.max() ?? 0)

        let header = "\(padRight("邮箱", to: emailWidth)) | \(padRight("状态", to: statusWidth)) | \(padRight("失败类型", to: failureTypeWidth)) | \(padRight("5h剩余", to: fiveHourWidth)) | \(padRight("7d剩余", to: weeklyWidth))"
        let body = rows.map { row in
            "\(row.marker) \(padRight(row.email, to: emailWidth)) | \(padRight(row.status, to: statusWidth)) | \(padRight(row.failureType, to: failureTypeWidth)) | \(padRight(row.fiveHour, to: fiveHourWidth)) | \(padRight(row.weekly, to: weeklyWidth))"
        }.joined(separator: "\n")
        var lines: [String] = ["\(header)\n\(body)"]
        lines.append(contentsOf: formatTokenSummaryTable(prefix: "Tokens汇总", summary: payload.summary))
        if shouldShowGlobalFallbackHint(payload.accounts) {
            lines.append("提示: 当前 Tokens 来自全局回退（~/.codex/sessions），账号间可能出现同值。")
        }
        if !payload.skippedAccounts.isEmpty {
            lines.append("")
            lines.append("[跳过刷新]")
            for skipped in payload.skippedAccounts {
                lines.append("\(skipped.accountID.uuidString) | \(skipped.reason)")
            }
        }
        return lines.joined(separator: "\n")
    }

    private static func formatAuthUsageSummary(_ payload: NolonCodexAuthUsagePayload) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"

        let rows: [(String, String)] = [
            ("账号总数", String(payload.summary.accountCount)),
            ("已缓存用量", String(payload.summary.cachedCount)),
            ("刷新失败账号", String(payload.accounts.filter { $0.syncFailedAt != nil || $0.syncFailureMessage != nil }.count)),
            ("5h平均剩余", payload.summary.avgFiveHourRemainingPercent.map { "\($0)%" } ?? "-"),
            ("7d平均剩余", payload.summary.avgWeeklyRemainingPercent.map { "\($0)%" } ?? "-"),
            ("Access最早到期", formatAccessExpiry(payload.summary.earliestExpiresAt)),
            ("最新刷新", payload.summary.latestRefreshedAt.map { formatter.string(from: $0) } ?? "-"),
        ]
        let keyWidth = rows.map(\.0.count).max() ?? 0
        var lines = rows
            .map { key, value in
                "\(padRight(key, to: keyWidth)) | \(value)"
            }
        lines.append(contentsOf: formatTokenSummaryTable(prefix: "Tokens", summary: payload.summary))
        return lines.joined(separator: "\n")
    }

    private static func formatAuthUsageTrend(_ payload: NolonCodexAuthUsageTrendPayload) -> String {
        var lines: [String] = [
            "provider | \(payload.providerID)",
            "range | \(payload.range.rawValue)",
            "source | \(payload.sourceLabel)",
            "updated_at | \(payload.updatedAt.formatted(date: .abbreviated, time: .shortened))",
            "summary.today | \(formatTokensInMillions(payload.summary.todayTokens))",
            "summary.7d | \(formatTokensInMillions(payload.summary.last7DaysTokens))",
            "summary.30d | \(formatTokensInMillions(payload.summary.last30DaysTokens))",
            "",
        ]
        let header = "date | total | input | output | cache"
        let rows = payload.points
            .sorted { $0.date > $1.date }
            .map { point in
                "\(point.date) | \(point.totalTokens) | \(point.inputTokens) | \(point.outputTokens) | \(point.cacheReadTokens)"
            }
        lines.append(header)
        lines.append(contentsOf: rows)
        return lines.joined(separator: "\n")
    }

    private static func formatTokenSummaryTable(prefix: String, summary: NolonCodexAuthUsageSummaryView) -> [String] {
        let h1 = "1d"
        let h7 = "7d"
        let h14 = "14d"
        let h30 = "30d"
        let hall = "all"

        let v1 = formatTokensInMillions(summary.totalToken1dCount)
        let v7 = formatTokensInMillions(summary.totalToken7dCount)
        let v14 = formatTokensInMillions(summary.totalToken14dCount)
        let v30 = formatTokensInMillions(summary.totalToken30dCount)
        let vall = formatTokensInMillions(summary.totalTokenAllCount)

        let c1 = max(h1.count, v1.count)
        let c7 = max(h7.count, v7.count)
        let c14 = max(h14.count, v14.count)
        let c30 = max(h30.count, v30.count)
        let call = max(hall.count, vall.count)

        let header = "\(prefix) | \(padRight(h1, to: c1)) | \(padRight(h7, to: c7)) | \(padRight(h14, to: c14)) | \(padRight(h30, to: c30)) | \(padRight(hall, to: call))"
        let values = "\(padRight("", to: prefix.count)) | \(padRight(v1, to: c1)) | \(padRight(v7, to: c7)) | \(padRight(v14, to: c14)) | \(padRight(v30, to: c30)) | \(padRight(vall, to: call))"
        return [header, values]
    }

    private static func formatTokensInMillions(_ value: Int?) -> String {
        guard let value else { return "-" }
        let millions = Double(value) / 1_000_000
        return String(format: "%.1fm", millions)
    }

    private static func shouldShowGlobalFallbackHint(_ accounts: [NolonCodexAuthUsageAccountView]) -> Bool {
        let nonEmpty = accounts.compactMap(\.usageSource).filter { !$0.isEmpty }
        guard !nonEmpty.isEmpty else { return false }
        return nonEmpty.allSatisfy { $0.lowercased().contains("(global)") }
    }

    private static func formatExpiryInfo(_ expiresAt: Date?, hasRefreshToken: Bool?) -> String {
        guard let expiresAt else { return "-" }
        let delta = Int(expiresAt.timeIntervalSinceNow)
        if delta >= 0 {
            return "剩余 \(formatDuration(delta))"
        }
        if hasRefreshToken == true {
            return "已过期 \(formatDuration(-delta)) (可刷新)"
        }
        return "已过期 \(formatDuration(-delta))"
    }

    private static func formatAccessExpiry(_ expiresAt: Date?) -> String {
        guard let expiresAt else { return "-" }
        let delta = Int(expiresAt.timeIntervalSinceNow)
        if delta >= 0 {
            return "剩余 \(formatDuration(delta))"
        }
        return "已过期 \(formatDuration(-delta))"
    }

    private static func formatTokenHealth(expiresAt: Date?, hasRefreshToken: Bool?) -> String {
        let access = "Access:\(formatAccessExpiry(expiresAt))"
        let refresh: String
        switch hasRefreshToken {
        case .some(true):
            refresh = "Refresh:可用"
        case .some(false):
            refresh = "Refresh:缺失"
        case .none:
            refresh = "Refresh:未知"
        }
        return "\(access) | \(refresh)"
    }

    private static func formatDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private static func formatDuration(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let day = 24 * 3600
        let hour = 3600
        let minute = 60
        if clamped >= day {
            let d = clamped / day
            let h = (clamped % day) / hour
            return "\(d)d \(h)h"
        }
        if clamped >= hour {
            let h = clamped / hour
            let m = (clamped % hour) / minute
            return "\(h)h \(m)m"
        }
        let m = max(1, clamped / minute)
        return "\(m)m"
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

    private static func formatAuthRefresh(_ payload: NolonCodexAuthRefreshPayload) -> String {
        var lines: [String] = []
        lines.reserveCapacity(payload.items.count + 5)
        lines.append("提供方: \(payload.providerID)")
        lines.append("邮箱                         | 状态  | 结果   | 运行时切换 | 错误码")
        for item in payload.items {
            let marker = item.isActive ? "*" : " "
            let email = item.email ?? item.accountName
            let status = item.isActive ? "已激活" : "未激活"
            let result = item.success ? "成功" : "失败"
            let runtime = item.runtimeSwitched ? "已切换" : "未切换"
            let code = item.errorCode ?? "-"
            lines.append(
                "\(marker) \(pad(email, to: 27)) | \(pad(status, to: 3)) | \(pad(result, to: 4)) | \(pad(runtime, to: 7)) | \(code)"
            )
        }
        lines.append("汇总-总数: \(payload.summary.totalCount)")
        lines.append("汇总-成功: \(payload.summary.successCount)")
        lines.append("汇总-失败: \(payload.summary.failureCount)")
        return lines.joined(separator: "\n")
    }

    private static func pad(_ raw: String, to width: Int) -> String {
        let count = raw.count
        guard count < width else { return raw }
        return raw + String(repeating: " ", count: width - count)
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
        let rows = accounts.enumerated().map { index, account in
            let marker = account.isActive ? "*" : " "
            let email = account.email ?? "-"
            let usageRaw = account.usageDisplay?.trimmingCharacters(in: .whitespacesAndNewlines)
            let usage = (usageRaw?.isEmpty == false) ? (usageRaw ?? "-") : "-"
            return (
                index: "\(index + 1).",
                marker: marker,
                email: email,
                usage: usage,
                accountID: account.id.uuidString
            )
        }
        let indexWidth = max("编号".count, rows.map(\.index.count).max() ?? 0)
        let markerWidth = max("状态".count, 1)
        let emailWidth = max("邮箱".count, rows.map(\.email.count).max() ?? 0)
        let usageWidth = max("用量".count, rows.map(\.usage.count).max() ?? 0)
        let header = "\(padRight("编号", to: indexWidth)) | \(padRight("状态", to: markerWidth)) | \(padRight("邮箱", to: emailWidth)) | \(padRight("用量", to: usageWidth)) | 账号ID"
        let table = rows.map { row in
            "\(padRight(row.index, to: indexWidth)) | \(padRight(row.marker, to: markerWidth)) | \(padRight(row.email, to: emailWidth)) | \(padRight(row.usage, to: usageWidth)) | \(row.accountID)"
        }.joined(separator: "\n")
        return """
        请选择要激活的账号（输入编号 / 账号 UUID / 邮箱，q 取消）:
        \(header)
        \(table)
        > 
        """
    }
}

private struct NolonCodexCommandPath: RawRepresentable, ExpressibleByStringLiteral, Equatable, Sendable {
    static let authList: Self = "codex.auth.list"
    static let authUsage: Self = "codex.auth.usage"
    static let authUsageTrend: Self = "codex.auth.usage-trend"
    static let authStatus: Self = "codex.auth.status"
    static let authRefresh: Self = "codex.auth.refresh"
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
