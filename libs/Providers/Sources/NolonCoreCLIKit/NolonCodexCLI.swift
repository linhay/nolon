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
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload
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

public struct NolonCodexAuthDeletePayload: Codable, Sendable, Equatable {
    public let providerID: String
    public let accountID: UUID
    public let wasActive: Bool
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
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        let provider = try Self.provider(for: canonicalProviderID)
        let accounts = try await authManager.loadAccounts()
        let activeID = await authManager.activeAccountId(for: provider)
        return NolonCodexAuthListPayload(
            providerID: canonicalProviderID,
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
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        let provider = try Self.provider(for: canonicalProviderID)
        let accounts = try await authManager.loadAccounts()
        let activeID = await authManager.activeAccountId(for: provider)
        let authHashHex = await authManager.currentAuthHashHex(for: provider)
        return NolonCodexAuthStatusPayload(
            providerID: canonicalProviderID,
            activeAccountID: activeID,
            accountCount: accounts.count,
            authHashHex: authHashHex
        )
    }

    public func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload {
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        let provider = try Self.provider(for: canonicalProviderID)
        let accounts = try await authManager.loadAccounts()
        guard let account = accounts.first(where: { $0.id == accountID }) else {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_auth_account_not_found",
                message: "Codex account not found: \(accountID.uuidString)"
            )
        }

        let result = try await CodexAuthActivationCoordinator.shared.activate(account: account, provider: provider)
        return NolonCodexAuthActivatePayload(
            providerID: canonicalProviderID,
            accountID: accountID,
            runtimeSwitched: result.runtimeSwitched,
            runtimeErrorDescription: result.runtimeErrorDescription
        )
    }

    public func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload {
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        let provider = try Self.provider(for: canonicalProviderID)
        try await authManager.prepareForCLILogin(provider: provider, archiveAccountName: nil)

        guard let codexHome = await authManager.codexHomeFolder(for: provider) else {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_home_unavailable",
                message: "Codex home path is unavailable for provider: \(canonicalProviderID)"
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
            providerID: canonicalProviderID,
            accountID: account.id,
            accountName: account.name,
            runtimeSwitched: activation.runtimeSwitched,
            runtimeErrorDescription: activation.runtimeErrorDescription
        )
    }

    public func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload {
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        let provider = try Self.provider(for: canonicalProviderID)
        let accounts = try await authManager.loadAccounts()
        guard accounts.contains(where: { $0.id == accountID }) else {
            throw NolonCoreCLIError.domainFailed(
                code: "codex_auth_account_not_found",
                message: "Codex account not found: \(accountID.uuidString)"
            )
        }
        let activeID = await authManager.activeAccountId(for: provider)
        try await authManager.deleteAccount(id: accountID)
        return NolonCodexAuthDeletePayload(
            providerID: canonicalProviderID,
            accountID: accountID,
            wasActive: activeID == accountID
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
        let canonicalProviderID: String?
        if let providerID {
            canonicalProviderID = try Self.canonicalProviderID(providerID)
            _ = try Self.provider(for: providerID)
        } else {
            canonicalProviderID = nil
        }
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
            providerID: canonicalProviderID,
            resolvedExecutable: resolvedExecutable,
            credits: snapshot.credits,
            fiveHourPercentLeft: snapshot.fiveHourPercentLeft,
            weeklyPercentLeft: snapshot.weeklyPercentLeft,
            fiveHourResetDescription: snapshot.fiveHourResetDescription,
            weeklyResetDescription: snapshot.weeklyResetDescription
        )
    }

    private static func provider(for providerID: String) throws -> Provider {
        let canonicalID = try canonicalProviderID(providerID)
        let template: ProviderTemplate
        switch canonicalID {
        case "codex":
            template = .codex
        case "codex-xcode":
            template = .codexXcode
        default:
            throw NolonCoreCLIError.invalidArguments("Unsupported --provider: \(providerID)")
        }

        let base = template.createProvider()
        return Provider(
            id: canonicalID,
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

    private static func canonicalProviderID(_ providerID: String) throws -> String {
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
}

public enum NolonCLIEntrypoint {
    public static func execute(
        arguments: [String],
        codexService: any NolonCodexCLIServing = NolonLiveCodexCLIService()
    ) async -> NolonCLIExecutionResult {
        if let helpText = resolvedHelpText(arguments: arguments) {
            return NolonCLIExecutionResult(exitCode: 0, stdout: helpText, stderr: "")
        }

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

    private static func resolvedHelpText(arguments: [String]) -> String? {
        let normalized = arguments.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }

        if normalized.isEmpty || normalized == ["help"] || normalized == ["-h"] || normalized == ["--help"] {
            return rootHelpText()
        }
        if normalized == ["codex", "help"] || normalized == ["codex", "-h"] || normalized == ["codex", "--help"] {
            return codexHelpText()
        }
        if normalized == ["codex", "auth", "help"] || normalized == ["codex", "auth", "-h"] || normalized == ["codex", "auth", "--help"] {
            return codexAuthHelpText()
        }
        if normalized == ["codex", "binary", "help"] || normalized == ["codex", "binary", "-h"] || normalized == ["codex", "binary", "--help"] {
            return codexBinaryHelpText()
        }
        if normalized == ["codex", "status", "help"] || normalized == ["codex", "status", "-h"] || normalized == ["codex", "status", "--help"] {
            return codexStatusHelpText()
        }
        if normalized == ["codex", "auth", "list", "help"] || normalized == ["codex", "auth", "list", "-h"] || normalized == ["codex", "auth", "list", "--help"] {
            return codexAuthListHelpText()
        }
        if normalized == ["codex", "auth", "status", "help"] || normalized == ["codex", "auth", "status", "-h"] || normalized == ["codex", "auth", "status", "--help"] {
            return codexAuthStatusHelpText()
        }
        if normalized == ["codex", "auth", "activate", "help"] || normalized == ["codex", "auth", "activate", "-h"] || normalized == ["codex", "auth", "activate", "--help"] {
            return codexAuthActivateHelpText()
        }
        if normalized == ["codex", "auth", "login", "help"] || normalized == ["codex", "auth", "login", "-h"] || normalized == ["codex", "auth", "login", "--help"] {
            return codexAuthLoginHelpText()
        }
        if normalized == ["codex", "auth", "delete", "help"] || normalized == ["codex", "auth", "delete", "-h"] || normalized == ["codex", "auth", "delete", "--help"] {
            return codexAuthDeleteHelpText()
        }
        if normalized == ["codex", "binary", "install", "help"] || normalized == ["codex", "binary", "install", "-h"] || normalized == ["codex", "binary", "install", "--help"] {
            return codexBinaryInstallHelpText()
        }
        return nil
    }

    private static func rootHelpText() -> String {
        codexHelpText()
    }

    private static func codexHelpText() -> String {
        """
        Usage: nolon codex <group> <action> [options]

        Groups:
          auth      list | status | activate | login | delete
          binary    list | current | install | use | doctor
          status    probe

        Examples:
          nolon codex auth list --provider codex
          nolon codex binary current
          nolon codex status probe --provider codex
        """
    }

    private static func codexAuthHelpText() -> String {
        """
        Usage: nolon codex auth <action> [options]

        Actions:
          list      [--provider codex|codex-xcode]
          status    [--provider codex|codex-xcode]
          activate  --account-id <uuid> [--provider ...]
          login     [--preferred-account-id <uuid>] [--provider ...]
          delete    --account-id <uuid> [--provider ...]
        """
    }

    private static func codexBinaryHelpText() -> String {
        """
        Usage: nolon codex binary <action> [options]

        Actions:
          list
          current
          install  --version <version-or-tag> [--set-default]
          use      --version <version-or-id>
          doctor
        """
    }

    private static func codexStatusHelpText() -> String {
        """
        Usage: nolon codex status <action> [options]

        Actions:
          probe    [--provider codex|codex-xcode]
        """
    }

    private static func codexAuthListHelpText() -> String {
        """
        Usage: nolon codex auth list [options]

        Options:
          --provider <id>   Provider id, default is codex.
        """
    }

    private static func codexAuthStatusHelpText() -> String {
        """
        Usage: nolon codex auth status [options]

        Options:
          --provider <id>   Provider id, default is codex.
        """
    }

    private static func codexAuthActivateHelpText() -> String {
        """
        Usage: nolon codex auth activate --account-id <uuid> [--provider <id>]

        Options:
          --provider <id>     Provider id, default is codex.
          --account-id <id>   Account id UUID.
        """
    }

    private static func codexAuthLoginHelpText() -> String {
        """
        Usage: nolon codex auth login [--provider <id>] [--preferred-account-id <uuid>]

        Options:
          --provider <id>               Provider id, default is codex.
          --preferred-account-id <id>   Preferred account id UUID for snapshot update.
        """
    }

    private static func codexAuthDeleteHelpText() -> String {
        """
        Usage: nolon codex auth delete --account-id <uuid> [--provider <id>]

        Options:
          --provider <id>     Provider id, default is codex.
          --account-id <id>   Account id UUID.
        """
    }

    private static func codexBinaryInstallHelpText() -> String {
        """
        Usage: nolon codex binary install --version <version-or-tag> [--set-default]

        Options:
          --version <value>   Version tag to install, e.g. 0.26.0 or rust-v0.26.0.
          --set-default       Activate this version after install.
        """
    }

    private static func executeCommand(
        arguments: [String],
        context: NolonCLIExecutionContext
    ) async throws -> String {
        guard arguments.count >= 3 else {
            throw NolonCoreCLIError.invalidArguments("Missing command. Expected: codex <group> <action> ...")
        }

        let route = try NolonCodexCommandPath(
            root: arguments[0],
            group: arguments[1],
            action: arguments[2]
        )
        let optionArgs = Array(arguments.dropFirst(3))

        switch route {
        case .authList:
            return try await executeAuthList(optionArgs: optionArgs, context: context)
        case .authStatus:
            return try await executeAuthStatus(optionArgs: optionArgs, context: context)
        case .authActivate:
            return try await executeAuthActivate(optionArgs: optionArgs, context: context)
        case .authLogin:
            return try await executeAuthLogin(optionArgs: optionArgs, context: context)
        case .authDelete:
            return try await executeAuthDelete(optionArgs: optionArgs, context: context)
        case .binaryList:
            return try await executeBinaryList(optionArgs: optionArgs, context: context)
        case .binaryCurrent:
            return try await executeBinaryCurrent(optionArgs: optionArgs, context: context)
        case .binaryInstall:
            return try await executeBinaryInstall(optionArgs: optionArgs, context: context)
        case .binaryUse:
            return try await executeBinaryUse(optionArgs: optionArgs, context: context)
        case .binaryDoctor:
            return try await executeBinaryDoctor(optionArgs: optionArgs, context: context)
        case .statusProbe:
            return try await executeStatusProbe(optionArgs: optionArgs, context: context)
        default:
            throw NolonCoreCLIError.domainFailed(
                code: "unsupported_command",
                message: "Unsupported command: \(route.rawValue)"
            )
        }
    }

    private static func executeAuthList(optionArgs: [String], context: NolonCLIExecutionContext) async throws -> String {
        let args = try parseCommand(NolonCodexAuthListCommand.self, optionArgs)
        let providerID = try parseCodexProviderID(args.provider)
        let payload = try await context.codexService().authList(providerID: providerID)
        return try context.successJSON(command: NolonCodexCommandPath.authList.rawValue, data: payload)
    }

    private static func executeAuthStatus(optionArgs: [String], context: NolonCLIExecutionContext) async throws -> String {
        let args = try parseCommand(NolonCodexAuthStatusCommand.self, optionArgs)
        let providerID = try parseCodexProviderID(args.provider)
        let payload = try await context.codexService().authStatus(providerID: providerID)
        return try context.successJSON(command: NolonCodexCommandPath.authStatus.rawValue, data: payload)
    }

    private static func executeAuthActivate(optionArgs: [String], context: NolonCLIExecutionContext) async throws -> String {
        let args = try parseCommand(NolonCodexAuthActivateCommand.self, optionArgs)
        let providerID = try parseCodexProviderID(args.provider)
        guard let accountID = UUID(uuidString: args.accountID) else {
            throw NolonCoreCLIError.invalidArguments("Invalid --account-id: \(args.accountID)")
        }
        let payload = try await context.codexService().authActivate(providerID: providerID, accountID: accountID)
        return try context.successJSON(command: NolonCodexCommandPath.authActivate.rawValue, data: payload)
    }

    private static func executeAuthLogin(optionArgs: [String], context: NolonCLIExecutionContext) async throws -> String {
        let args = try parseCommand(NolonCodexAuthLoginCommand.self, optionArgs)
        let providerID = try parseCodexProviderID(args.provider)
        let preferred: UUID?
        if let preferredAccountID = args.preferredAccountID {
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

    private static func executeAuthDelete(optionArgs: [String], context: NolonCLIExecutionContext) async throws -> String {
        let args = try parseCommand(NolonCodexAuthDeleteCommand.self, optionArgs)
        let providerID = try parseCodexProviderID(args.provider)
        guard let accountID = UUID(uuidString: args.accountID) else {
            throw NolonCoreCLIError.invalidArguments("Invalid --account-id: \(args.accountID)")
        }
        let payload = try await context.codexService().authDelete(providerID: providerID, accountID: accountID)
        return try context.successJSON(command: NolonCodexCommandPath.authDelete.rawValue, data: payload)
    }

    private static func executeBinaryList(optionArgs: [String], context: NolonCLIExecutionContext) async throws -> String {
        let _: NolonCodexNoArguments = try parseArguments(NolonCodexNoArguments.self, optionArgs)
        let payload = try await context.codexService().binaryList()
        return try context.successJSON(command: NolonCodexCommandPath.binaryList.rawValue, data: payload)
    }

    private static func executeBinaryCurrent(optionArgs: [String], context: NolonCLIExecutionContext) async throws -> String {
        let _: NolonCodexNoArguments = try parseArguments(NolonCodexNoArguments.self, optionArgs)
        let payload = try await context.codexService().binaryCurrent()
        return try context.successJSON(command: NolonCodexCommandPath.binaryCurrent.rawValue, data: payload)
    }

    private static func executeBinaryInstall(optionArgs: [String], context: NolonCLIExecutionContext) async throws -> String {
        let args = try parseArguments(NolonCodexBinaryInstallArguments.self, optionArgs)
        let version = try parseCodexVersionArgument(args.version, option: "--version")
        let payload = try await context.codexService().binaryInstall(version: version, setDefault: args.setDefault)
        return try context.successJSON(command: NolonCodexCommandPath.binaryInstall.rawValue, data: payload)
    }

    private static func executeBinaryUse(optionArgs: [String], context: NolonCLIExecutionContext) async throws -> String {
        let args = try parseArguments(NolonCodexBinaryUseArguments.self, optionArgs)
        let version = try parseCodexVersionArgument(args.version, option: "--version")
        let payload = try await context.codexService().binaryUse(version: version)
        return try context.successJSON(command: NolonCodexCommandPath.binaryUse.rawValue, data: payload)
    }

    private static func executeBinaryDoctor(optionArgs: [String], context: NolonCLIExecutionContext) async throws -> String {
        let _: NolonCodexNoArguments = try parseArguments(NolonCodexNoArguments.self, optionArgs)
        let payload = try await context.codexService().binaryDoctor()
        return try context.successJSON(command: NolonCodexCommandPath.binaryDoctor.rawValue, data: payload)
    }

    private static func executeStatusProbe(optionArgs: [String], context: NolonCLIExecutionContext) async throws -> String {
        let args = try parseArguments(NolonCodexStatusProbeArguments.self, optionArgs)
        let providerID: String?
        if let provider = args.provider {
            providerID = try parseCodexProviderID(provider)
        } else {
            providerID = nil
        }
        let payload = try await context.codexService().statusProbe(providerID: providerID)
        return try context.successJSON(command: NolonCodexCommandPath.statusProbe.rawValue, data: payload)
    }

    private static func parseArguments<T: ParsableArguments>(_ type: T.Type, _ arguments: [String]) throws -> T {
        do {
            return try T.parse(arguments)
        } catch {
            throw NolonCoreCLIError.invalidArguments(error.localizedDescription)
        }
    }

    private static func parseCommand<T: ParsableCommand>(_ type: T.Type, _ arguments: [String]) throws -> T {
        do {
            let parsed = try T.parseAsRoot(arguments)
            guard let typed = parsed as? T else {
                throw NolonCoreCLIError.invalidArguments("Failed to parse command type: \(T.self)")
            }
            return typed
        } catch {
            throw NolonCoreCLIError.invalidArguments(error.localizedDescription)
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

    init(root: String, group: String, action: String) throws {
        let normalizedRoot = root.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedGroup = group.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedAction = action.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedRoot.isEmpty, !normalizedGroup.isEmpty, !normalizedAction.isEmpty else {
            throw NolonCoreCLIError.invalidArguments("Command path cannot contain empty segments.")
        }
        self.rawValue = "\(normalizedRoot).\(normalizedGroup).\(normalizedAction)"
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

private struct NolonCodexAuthListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "list")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"
}

private struct NolonCodexAuthStatusCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "status")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"
}

private struct NolonCodexAuthActivateCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "activate")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"

    @Option(name: .long, help: "Account id UUID.")
    var accountID: String
}

private struct NolonCodexAuthLoginCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "login")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"

    @Option(name: .long, help: "Preferred account id UUID for snapshot update.")
    var preferredAccountID: String?
}

private struct NolonCodexAuthDeleteCommand: ParsableCommand {
    static let configuration = CommandConfiguration(commandName: "delete")

    @Option(name: .long, help: "Provider id, default is codex.")
    var provider: String = "codex"

    @Option(name: .long, help: "Account id UUID.")
    var accountID: String
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
