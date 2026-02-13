import ArgumentParser
import Foundation

enum NolonCodexCLIExecutor {
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
        default:
            throw NolonCoreCLIError.invalidArguments("Unsupported parsed command type: \(type(of: parsed))")
        }
    }

    private static func executeAuthList(command: NolonCodexAuthListCommand, context: NolonCLIExecutionContext) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        let payload = try await context.codexService().authList(providerID: providerID)
        return try context.successJSON(command: NolonCodexCommandPath.authList.rawValue, data: payload)
    }

    private static func executeAuthStatus(command: NolonCodexAuthStatusCommand, context: NolonCLIExecutionContext) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        let payload = try await context.codexService().authStatus(providerID: providerID)
        return try context.successJSON(command: NolonCodexCommandPath.authStatus.rawValue, data: payload)
    }

    private static func executeAuthActivate(command: NolonCodexAuthActivateCommand, context: NolonCLIExecutionContext) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        guard let accountID = UUID(uuidString: command.accountID) else {
            throw NolonCoreCLIError.invalidArguments("Invalid --account-id: \(command.accountID)")
        }
        let payload = try await context.codexService().authActivate(providerID: providerID, accountID: accountID)
        return try context.successJSON(command: NolonCodexCommandPath.authActivate.rawValue, data: payload)
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
        return try context.successJSON(command: NolonCodexCommandPath.authLogin.rawValue, data: payload)
    }

    private static func executeAuthDelete(command: NolonCodexAuthDeleteCommand, context: NolonCLIExecutionContext) async throws -> String {
        let providerID = try parseCodexProviderID(command.provider)
        guard let accountID = UUID(uuidString: command.accountID) else {
            throw NolonCoreCLIError.invalidArguments("Invalid --account-id: \(command.accountID)")
        }
        let payload = try await context.codexService().authDelete(providerID: providerID, accountID: accountID)
        return try context.successJSON(command: NolonCodexCommandPath.authDelete.rawValue, data: payload)
    }

    private static func executeBinaryList(context: NolonCLIExecutionContext) async throws -> String {
        let payload = try await context.codexService().binaryList()
        return formatBinaryList(payload)
    }

    private static func executeBinaryCurrent(context: NolonCLIExecutionContext) async throws -> String {
        let payload = try await context.codexService().binaryCurrent()
        return try context.successJSON(command: NolonCodexCommandPath.binaryCurrent.rawValue, data: payload)
    }

    private static func executeBinaryInstall(command: NolonCodexBinaryInstallCommand, context: NolonCLIExecutionContext) async throws -> String {
        let version = try parseCodexVersionArgument(command.version, option: "--version")
        let payload = try await context.codexService().binaryInstall(version: version, setDefault: command.setDefault)
        return try context.successJSON(command: NolonCodexCommandPath.binaryInstall.rawValue, data: payload)
    }

    private static func executeBinaryUse(command: NolonCodexBinaryUseCommand, context: NolonCLIExecutionContext) async throws -> String {
        let version = try parseCodexVersionArgument(command.version, option: "--version")
        let payload = try await context.codexService().binaryUse(version: version)
        return try context.successJSON(command: NolonCodexCommandPath.binaryUse.rawValue, data: payload)
    }

    private static func executeBinaryDoctor(context: NolonCLIExecutionContext) async throws -> String {
        let payload = try await context.codexService().binaryDoctor()
        return try context.successJSON(command: NolonCodexCommandPath.binaryDoctor.rawValue, data: payload)
    }

    private static func executeStatusProbe(command: NolonCodexStatusProbeCommand, context: NolonCLIExecutionContext) async throws -> String {
        let providerID: String?
        if let provider = command.provider {
            providerID = try parseCodexProviderID(provider)
        } else {
            providerID = nil
        }
        let payload = try await context.codexService().statusProbe(providerID: providerID)
        return try context.successJSON(command: NolonCodexCommandPath.statusProbe.rawValue, data: payload)
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
        return payload.versions
            .map { version in
                let marker = version.isSelected ? "*" : " "
                return "\(marker) \(version.detectedVersion)"
            }
            .joined(separator: "\n")
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
