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
        if let helpText = NolonCodexCLIHelpResolver.resolvedHelpText(arguments: arguments) {
            return NolonCLIExecutionResult(exitCode: 0, stdout: helpText, stderr: "")
        }

        let context = NolonCLIExecutionContext(service: codexService)
        do {
            let output = try await NolonCodexCLIExecutor.execute(arguments: arguments, context: context)
            return NolonCLIExecutionResult(exitCode: 0, stdout: output, stderr: "")
        } catch let error as NolonCoreCLIError {
            return NolonCLIExecutionResult(exitCode: 2, stdout: "", stderr: context.errorJSON(for: error))
        } catch {
            let wrapped = NolonCoreCLIError.invalidArguments(error.localizedDescription)
            return NolonCLIExecutionResult(exitCode: 2, stdout: "", stderr: context.errorJSON(for: wrapped))
        }
    }
}
