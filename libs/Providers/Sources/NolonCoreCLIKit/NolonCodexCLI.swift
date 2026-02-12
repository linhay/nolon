import ArgumentParser
import CodexCLIKit
import CodexProvider
import Foundation
import ProviderCatalog
import ProviderUsage
import STFilePath

public protocol NolonCodexCLIServing: Sendable {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload
    func binaryList() async throws -> NolonCodexBinaryListPayload
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload
}

public struct NolonCodexAuthAccountView: Codable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public let relativeAuthPath: String
    public let isActive: Bool
}

public struct NolonCodexAuthListPayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let activeAccountID: UUID?
    public let accounts: [NolonCodexAuthAccountView]
}

public struct NolonCodexAuthStatusPayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let activeAccountID: UUID?
    public let accountCount: Int
    public let authHashHex: String?
}

public struct NolonCodexAuthActivatePayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let accountID: UUID
    public let runtimeSwitched: Bool
    public let runtimeErrorDescription: String?
}

public struct NolonCodexAuthLoginPayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let accountID: UUID
    public let accountName: String
    public let runtimeSwitched: Bool
    public let runtimeErrorDescription: String?
}

public struct NolonCodexManagedVersionView: Codable, Sendable, Equatable {
    public let id: String
    public let displayName: String
    public let detectedVersion: String
    public let source: String
    public let importedAt: Date
    public let isSelected: Bool
}

public struct NolonCodexBinaryListPayload: Codable, Sendable, Equatable {
    public let selectedVersionID: String?
    public let versions: [NolonCodexManagedVersionView]
}

public struct NolonCodexBinaryCurrentPayload: Codable, Sendable, Equatable {
    public let selectedVersionID: String?
    public let currentVersion: String?
    public let activeCLIPath: String?
}

public struct NolonCodexBinaryInstallPayload: Codable, Sendable, Equatable {
    public let requestedVersion: String
    public let installedVersionID: String
    public let installedDetectedVersion: String
    public let activated: Bool
}

public struct NolonCodexBinaryUsePayload: Codable, Sendable, Equatable {
    public let selectedVersionID: String
}

public struct NolonCodexBinaryDoctorPayload: Codable, Sendable, Equatable {
    public let selectedVersionID: String?
    public let currentVersion: String?
    public let activeCLIPath: String?
    public let managedVersionCount: Int
    public let pathConfigured: Bool
    public let pathActive: Bool
    public let profilePath: String
}

public struct NolonCodexStatusProbePayload: Codable, Sendable, Equatable {
    public let providerID: String?
    public let resolvedExecutable: String?
    public let credits: Double?
    public let fiveHourPercentLeft: Int?
    public let weeklyPercentLeft: Int?
    public let fiveHourResetDescription: String?
    public let weeklyResetDescription: String?
}

public struct NolonLiveCodexCLIService: NolonCodexCLIServing {
    private let authManager: CodexAuthManager
    private let binaryManager: CodexBinaryManager
    private let loginRunner: CodexLoginRunner
    private let environment: [String: String]

    public init(
        authManager: CodexAuthManager = CodexAuthManager(),
        binaryManager: CodexBinaryManager = .shared,
        loginRunner: CodexLoginRunner = .init(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.authManager = authManager
        self.binaryManager = binaryManager
        self.loginRunner = loginRunner
        self.environment = environment
    }

    public func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        let provider = try Self.provider(for: providerID)
        let accounts = try await authManager.loadAccounts()
        let activeID = await authManager.activeAccountId(for: provider)
        return NolonCodexAuthListPayload(
            providerID: providerID,
            activeAccountID: activeID,
            accounts: accounts.map { account in
                NolonCodexAuthAccountView(
                    id: account.id,
                    name: account.name,
                    createdAt: account.createdAt,
                    relativeAuthPath: account.relativeAuthPath,
                    isActive: account.id == activeID
                )
            }
        )
    }

    public func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload {
        let provider = try Self.provider(for: providerID)
        let accounts = try await authManager.loadAccounts()
        let activeID = await authManager.activeAccountId(for: provider)
        let authHashHex = await authManager.currentAuthHashHex(for: provider)
        return NolonCodexAuthStatusPayload(
            providerID: providerID,
            activeAccountID: activeID,
            accountCount: accounts.count,
            authHashHex: authHashHex
        )
    }

    public func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload {
        let provider = try Self.provider(for: providerID)
        let accounts = try await authManager.loadAccounts()
        guard let account = accounts.first(where: { $0.id == accountID }) else {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_auth_account_not_found",
                message: "Codex account not found: \(accountID.uuidString)"
            )
        }

        let result = try await CodexAuthActivationCoordinator.shared.activate(account: account, provider: provider)
        return NolonCodexAuthActivatePayload(
            providerID: providerID,
            accountID: accountID,
            runtimeSwitched: result.runtimeSwitched,
            runtimeErrorDescription: result.runtimeErrorDescription
        )
    }

    public func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload {
        let provider = try Self.provider(for: providerID)
        try await authManager.prepareForCLILogin(provider: provider, archiveAccountName: nil)

        guard let codexHome = await authManager.codexHomeFolder(for: provider) else {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_home_unavailable",
                message: "Codex home path is unavailable for provider: \(providerID)"
            )
        }

        let handle = try loginRunner.startLogin(
            binary: "codex",
            environment: environment,
            codexHome: codexHome
        )
        while handle.isRunning {
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        guard let authJSONString = try await authManager.readAuthJSONString(from: provider), !authJSONString.isEmpty else {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_login_auth_missing",
                message: "No auth.json generated after codex login."
            )
        }

        let account = try await authManager.recordCLILoginSnapshot(
            authJSONString: authJSONString,
            preferredAccountID: preferredAccountID
        )
        let activation = try await CodexAuthActivationCoordinator.shared.activate(account: account, provider: provider)
        return NolonCodexAuthLoginPayload(
            providerID: providerID,
            accountID: account.id,
            accountName: account.name,
            runtimeSwitched: activation.runtimeSwitched,
            runtimeErrorDescription: activation.runtimeErrorDescription
        )
    }

    public func binaryList() async throws -> NolonCodexBinaryListPayload {
        let manifest = try await binaryManager.loadManifest()
        let selected = manifest.selectedVersionId
        let versions = manifest.versions.map { version in
            NolonCodexManagedVersionView(
                id: version.id,
                displayName: version.displayName,
                detectedVersion: version.detectedVersion,
                source: version.source,
                importedAt: version.importedAt,
                isSelected: version.id == selected
            )
        }
        return NolonCodexBinaryListPayload(selectedVersionID: selected, versions: versions)
    }

    public func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload {
        let manifest = try await binaryManager.loadManifest()
        let currentVersion = try await binaryManager.currentCLIVersion()
        let activePath = await binaryManager.activeCLIPathIfAvailable()
        return NolonCodexBinaryCurrentPayload(
            selectedVersionID: manifest.selectedVersionId,
            currentVersion: currentVersion,
            activeCLIPath: activePath
        )
    }

    public func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload {
        let manifest = try await binaryManager.loadManifest()
        let releases = try await binaryManager.fetchRemoteReleases(includePrerelease: manifest.includeBetaVersions)
        guard let matched = releases.first(where: { $0.version == version || $0.tag == version }) else {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_binary_not_found",
                message: "Requested Codex version not found: \(version)"
            )
        }
        let managed = try await binaryManager.downloadAndImport(from: matched.assetURL, displayName: "Codex \(matched.version)")
        if setDefault {
            try await binaryManager.activate(versionId: managed.id)
        }
        return NolonCodexBinaryInstallPayload(
            requestedVersion: version,
            installedVersionID: managed.id,
            installedDetectedVersion: managed.detectedVersion,
            activated: setDefault
        )
    }

    public func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload {
        let versions = try await binaryManager.listVersions()
        guard let target = versions.first(where: { $0.detectedVersion == version || $0.id == version }) else {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_binary_not_found",
                message: "Managed Codex version not found: \(version)"
            )
        }
        try await binaryManager.activate(versionId: target.id)
        return NolonCodexBinaryUsePayload(selectedVersionID: target.id)
    }

    public func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload {
        let manifest = try await binaryManager.loadManifest()
        let currentVersion = try await binaryManager.currentCLIVersion()
        let activePath = await binaryManager.activeCLIPathIfAvailable()
        let pathStatus = await binaryManager.codexPathStatus()
        return NolonCodexBinaryDoctorPayload(
            selectedVersionID: manifest.selectedVersionId,
            currentVersion: currentVersion,
            activeCLIPath: activePath,
            managedVersionCount: manifest.versions.count,
            pathConfigured: pathStatus.configured,
            pathActive: pathStatus.active,
            profilePath: pathStatus.profilePath
        )
    }

    public func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload {
        var env = environment
        if let codexPath = await binaryManager.activeCLIPathIfAvailable() {
            env["CODEX_CLI_PATH"] = codexPath
        }
        if let managed = try? await binaryManager.launchEnvironmentVariables() {
            env.merge(managed) { _, new in new }
        }

        let probe = CodexStatusProbe(environment: env)
        let snapshot = try await probe.fetch()
        let resolvedExecutable = CodexCommandExecutor(executable: "codex", environment: env).resolveExecutable()
        return NolonCodexStatusProbePayload(
            providerID: providerID,
            resolvedExecutable: resolvedExecutable,
            credits: snapshot.credits,
            fiveHourPercentLeft: snapshot.fiveHourPercentLeft,
            weeklyPercentLeft: snapshot.weeklyPercentLeft,
            fiveHourResetDescription: snapshot.fiveHourResetDescription,
            weeklyResetDescription: snapshot.weeklyResetDescription
        )
    }

    private static func provider(for providerID: String) throws -> Provider {
        let normalized = providerID.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let template: ProviderTemplate
        switch normalized {
        case "codex":
            template = .codex
        case "codexxcode", "codex-xcode":
            template = .codexXcode
        default:
            throw NolonCoreCLIError.invalidArguments("Unsupported --provider: \(providerID)")
        }

        let base = template.createProvider()
        return Provider(
            id: normalized,
            kind: base.kind,
            name: base.name,
            projectRootPath: base.projectRootPath,
            defaultSkillsPath: base.defaultSkillsPath,
            workflowPath: base.workflowPath,
            commandPath: base.commandPath,
            iconName: base.iconName,
            installMethod: base.installMethod,
            templateId: base.templateId,
            additionalSkillsPaths: base.additionalSkillsPaths,
            documentationURL: base.documentationURL
        )
    }
}

public enum NolonCLIEntrypoint {
    public static func execute(
        arguments: [String],
        codexService: any NolonCodexCLIServing = NolonLiveCodexCLIService()
    ) async -> NolonCLIExecutionResult {
        let context = NolonCLIExecutionContext(service: codexService)
        do {
            let output = try await executeCommand(arguments: arguments, context: context)
            return NolonCLIExecutionResult(exitCode: 0, stdout: output, stderr: "")
        } catch let error as NolonCoreCLIError {
            return NolonCLIExecutionResult(exitCode: 2, stdout: "", stderr: context.errorJSON(for: error))
        } catch {
            let wrapped = NolonCoreCLIError.invalidArguments(error.localizedDescription)
            return NolonCLIExecutionResult(exitCode: 2, stdout: "", stderr: context.errorJSON(for: wrapped))
        }
    }

    private static func executeCommand(
        arguments: [String],
        context: NolonCLIExecutionContext
    ) async throws -> String {
        guard arguments.count >= 3 else {
            throw NolonCoreCLIError.invalidArguments("Missing command. Expected: codex <group> <action> ...")
        }

        let route = "\(arguments[0]).\(arguments[1]).\(arguments[2])"
        let optionArgs = Array(arguments.dropFirst(3))

        switch route {
        case "codex.auth.list":
            let args = try parseArguments(NolonCodexAuthListArguments.self, optionArgs)
            let payload = try await context.codexService().authList(providerID: args.provider)
            return try context.successJSON(command: "codex.auth.list", data: payload)
        case "codex.auth.status":
            let args = try parseArguments(NolonCodexAuthStatusArguments.self, optionArgs)
            let payload = try await context.codexService().authStatus(providerID: args.provider)
            return try context.successJSON(command: "codex.auth.status", data: payload)
        case "codex.auth.activate":
            let args = try parseArguments(NolonCodexAuthActivateArguments.self, optionArgs)
            guard let accountID = UUID(uuidString: args.accountID) else {
                throw NolonCoreCLIError.invalidArguments("Invalid --account-id: \(args.accountID)")
            }
            let payload = try await context.codexService().authActivate(providerID: args.provider, accountID: accountID)
            return try context.successJSON(command: "codex.auth.activate", data: payload)
        case "codex.auth.login":
            let args = try parseArguments(NolonCodexAuthLoginArguments.self, optionArgs)
            let preferred: UUID?
            if let preferredAccountID = args.preferredAccountID {
                guard let parsed = UUID(uuidString: preferredAccountID) else {
                    throw NolonCoreCLIError.invalidArguments("Invalid --preferred-account-id: \(preferredAccountID)")
                }
                preferred = parsed
            } else {
                preferred = nil
            }
            let payload = try await context.codexService().authLogin(providerID: args.provider, preferredAccountID: preferred)
            return try context.successJSON(command: "codex.auth.login", data: payload)
        case "codex.binary.list":
            let _: NolonCodexNoArguments = try parseArguments(NolonCodexNoArguments.self, optionArgs)
            let payload = try await context.codexService().binaryList()
            return try context.successJSON(command: "codex.binary.list", data: payload)
        case "codex.binary.current":
            let _: NolonCodexNoArguments = try parseArguments(NolonCodexNoArguments.self, optionArgs)
            let payload = try await context.codexService().binaryCurrent()
            return try context.successJSON(command: "codex.binary.current", data: payload)
        case "codex.binary.install":
            let args = try parseArguments(NolonCodexBinaryInstallArguments.self, optionArgs)
            let payload = try await context.codexService().binaryInstall(version: args.version, setDefault: args.setDefault)
            return try context.successJSON(command: "codex.binary.install", data: payload)
        case "codex.binary.use":
            let args = try parseArguments(NolonCodexBinaryUseArguments.self, optionArgs)
            let payload = try await context.codexService().binaryUse(version: args.version)
            return try context.successJSON(command: "codex.binary.use", data: payload)
        case "codex.binary.doctor":
            let _: NolonCodexNoArguments = try parseArguments(NolonCodexNoArguments.self, optionArgs)
            let payload = try await context.codexService().binaryDoctor()
            return try context.successJSON(command: "codex.binary.doctor", data: payload)
        case "codex.status.probe":
            let args = try parseArguments(NolonCodexStatusProbeArguments.self, optionArgs)
            let payload = try await context.codexService().statusProbe(providerID: args.provider)
            return try context.successJSON(command: "codex.status.probe", data: payload)
        default:
            throw NolonCoreCLIError.invalidArguments("Unsupported command: \(route)")
        }
    }

    private static func parseArguments<T: ParsableArguments>(_ type: T.Type, _ arguments: [String]) throws -> T {
        do {
            return try T.parse(arguments)
        } catch {
            throw NolonCoreCLIError.invalidArguments(error.localizedDescription)
        }
    }
}

private final class NolonCLIExecutionContext: @unchecked Sendable {
    private let service: any NolonCodexCLIServing

    init(service: any NolonCodexCLIServing) {
        self.service = service
    }

    func codexService() -> any NolonCodexCLIServing {
        service
    }

    func successJSON<Payload: Encodable & Sendable>(command: String, data: Payload) throws -> String {
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

    private func encodeJSON<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(value)
        return String(decoding: data, as: UTF8.self)
    }
}

private struct NolonCodexAuthListArguments: ParsableArguments {
    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"
}

private struct NolonCodexAuthStatusArguments: ParsableArguments {
    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"
}

private struct NolonCodexAuthActivateArguments: ParsableArguments {
    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"

    @Option(name: .long, help: "Account id UUID.")
    var accountID: String
}

private struct NolonCodexAuthLoginArguments: ParsableArguments {
    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"

    @Option(name: .long, help: "Preferred account id UUID for snapshot update.")
    var preferredAccountID: String?
}

private struct NolonCodexBinaryInstallArguments: ParsableArguments {
    @Option(name: .long, help: "Version tag to install, e.g. 0.26.0 or rust-v0.26.0.")
    var version: String

    @Flag(name: .long, help: "Activate this version after install.")
    var setDefault: Bool = false
}

private struct NolonCodexBinaryUseArguments: ParsableArguments {
    @Option(name: .long, help: "Version id or semantic version.")
    var version: String
}

private struct NolonCodexStatusProbeArguments: ParsableArguments {
    @Option(name: .long, help: "Provider id for reporting context.")
    var provider: String?
}

private struct NolonCodexNoArguments: ParsableArguments {}
