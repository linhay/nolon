import ArgumentParser
import CodexCLIKit
import CodexProvider
import Foundation
import ProviderCatalog
import ProviderUsage
import SKProcessRunner
import STFilePath
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

public protocol NolonCodexCLIServing: Sendable {
    func authList(providerID: String) async throws -> NolonCodexAuthListPayload
    func authStatus(providerID: String) async throws -> NolonCodexAuthStatusPayload
    func authActivate(providerID: String, accountID: UUID) async throws -> NolonCodexAuthActivatePayload
    func authLogin(providerID: String, preferredAccountID: UUID?) async throws -> NolonCodexAuthLoginPayload
    func authDelete(providerID: String, accountID: UUID) async throws -> NolonCodexAuthDeletePayload
    func binaryList() async throws -> NolonCodexBinaryListPayload
    func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload
    func binaryCurrent() async throws -> NolonCodexBinaryCurrentPayload
    func binaryInstall(version: String, setDefault: Bool) async throws -> NolonCodexBinaryInstallPayload
    func binaryUse(version: String) async throws -> NolonCodexBinaryUsePayload
    func binaryDoctor() async throws -> NolonCodexBinaryDoctorPayload
    func statusProbe(providerID: String?) async throws -> NolonCodexStatusProbePayload
    func providerList() async throws -> NolonProviderListPayload
    func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload
    func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload
    func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload
}

public struct NolonCodexAuthAccountView: Codable, Sendable, Equatable {
    public let id: UUID
    public let name: String
    public let createdAt: Date
    public let relativeAuthPath: String
    public let isActive: Bool
    public let email: String?
    public let usageDisplay: String?
    public let refreshedAt: Date?
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
    public let loginURL: String?
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

public struct NolonCodexRemoteVersionView: Codable, Sendable, Equatable {
    public let version: String
    public let tag: String
    public let downloadURL: String
    public let isPrerelease: Bool
}

public struct NolonCodexBinaryListPayload: Codable, Sendable, Equatable {
    public let selectedVersionID: String?
    public let versions: [NolonCodexManagedVersionView]
}

public struct NolonCodexBinaryAvailablePayload: Codable, Sendable, Equatable {
    public let versions: [NolonCodexRemoteVersionView]
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

public struct NolonCodexBinarySwitchPayload: Codable, Sendable, Equatable {
    public let action: String
    public let requestedVersion: String
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
    public let probeWarning: String?
    public let probeHint: String?
}

public struct NolonCodexRuntimeProcessView: Codable, Sendable, Equatable {
    public let pid: Int32
    public let ppid: Int32?
    public let elapsed: String
    public let providerHint: String?
    public let command: String
}

public struct NolonProviderCLIView: Codable, Sendable, Equatable {
    public let providerID: String
    public let name: String
    public let cli: String
    public let installed: Bool
    public let executablePath: String?
}

public struct NolonProviderListPayload: Codable, Sendable, Equatable {
    public let providers: [NolonProviderCLIView]
}

public struct NolonCodexProviderDiscoverView: Codable, Sendable, Equatable {
    public let providerID: String
    public let name: String
    public let templateID: String
    public let codexHomePath: String
    public let authPath: String
    public let authExists: Bool
    public let authIsSymlink: Bool
    public let authSymlinkTargetPath: String?
}

public struct NolonCodexProviderDiscoverPayload: Codable, Sendable, Equatable {
    public let providers: [NolonCodexProviderDiscoverView]
}

public struct NolonCodexRuntimeListPayload: Codable, Sendable, Equatable {
    public let processes: [NolonCodexRuntimeProcessView]
}

public struct NolonCodexRuntimeStopPayload: Codable, Sendable, Equatable {
    public let pid: Int32
    public let requestedSignal: String
    public let didEscalateToKill: Bool
    public let exited: Bool
}

public struct NolonLiveCodexCLIService: NolonCodexCLIServing {
    private let authManager: CodexAuthManager
    private let binaryManager: CodexBinaryManager
    private let loginRunner: CodexLoginRunner
    private let environment: [String: String]
    private let runtimeProcessInspector: any NolonCodexRuntimeProcessInspecting
    private let runtimeSignalController: any NolonCodexRuntimeSignalControlling
    private let currentPIDProvider: @Sendable () -> Int32
    private let sleep: @Sendable (UInt64) async throws -> Void

    public init(
        authManager: CodexAuthManager = CodexAuthManager(),
        binaryManager: CodexBinaryManager = .shared,
        loginRunner: CodexLoginRunner = .init(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.init(
            authManager: authManager,
            binaryManager: binaryManager,
            loginRunner: loginRunner,
            environment: environment,
            runtimeProcessInspector: NolonCodexRuntimeProcessInspector(),
            runtimeSignalController: NolonCodexRuntimeSignalController(),
            currentPIDProvider: { getpid() },
            sleep: { nanoseconds in
                try await Task.sleep(nanoseconds: nanoseconds)
            }
        )
    }

    init(
        authManager: CodexAuthManager,
        binaryManager: CodexBinaryManager,
        loginRunner: CodexLoginRunner,
        environment: [String: String],
        runtimeProcessInspector: any NolonCodexRuntimeProcessInspecting,
        runtimeSignalController: any NolonCodexRuntimeSignalControlling,
        currentPIDProvider: @escaping @Sendable () -> Int32,
        sleep: @escaping @Sendable (UInt64) async throws -> Void
    ) {
        self.authManager = authManager
        self.binaryManager = binaryManager
        self.loginRunner = loginRunner
        self.environment = environment
        self.runtimeProcessInspector = runtimeProcessInspector
        self.runtimeSignalController = runtimeSignalController
        self.currentPIDProvider = currentPIDProvider
        self.sleep = sleep
    }

    public func authList(providerID: String) async throws -> NolonCodexAuthListPayload {
        let canonicalProviderID = try Self.canonicalProviderID(providerID)
        let provider = try Self.provider(for: canonicalProviderID)
        let accounts = try await authManager.loadAccounts()
        let activeID = await authManager.activeAccountId(for: provider)
        var views: [NolonCodexAuthAccountView] = []
        views.reserveCapacity(accounts.count)
        for account in accounts {
            let email = Self.loadEmail(for: account, authManager: authManager)
            let usageCache = try? await authManager.loadUsageCache(for: account)
            views.append(
                NolonCodexAuthAccountView(
                    id: account.id,
                    name: account.name,
                    createdAt: account.createdAt,
                    relativeAuthPath: account.relativeAuthPath,
                    isActive: account.id == activeID,
                    email: email,
                    usageDisplay: Self.makeUsageDisplay(from: usageCache),
                    refreshedAt: Self.resolveRefreshTime(from: usageCache)
                )
            )
        }
        return NolonCodexAuthListPayload(
            providerID: canonicalProviderID,
            activeAccountID: activeID,
            accounts: views
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
        let codexHome = authManager.cliLoginCodexHomeFolder(providerID: canonicalProviderID)
        _ = codexHome.createIfNotExists()
        let isolatedAuthFile = codexHome.file("auth.json")
        if isolatedAuthFile.isExists {
            try isolatedAuthFile.delete()
        }

        let loginResult = try await loginRunner.loginAndAwaitAuthResult(
            binary: "codex",
            environment: environment,
            codexHome: codexHome
        )

        let account = try await authManager.recordCLILoginSnapshot(
            authJSONString: loginResult.authJSONString,
            preferredAccountID: preferredAccountID
        )
        let activation = try await CodexAuthActivationCoordinator.shared.activate(account: account, provider: provider)
        return NolonCodexAuthLoginPayload(
            providerID: canonicalProviderID,
            accountID: account.id,
            accountName: account.name,
            runtimeSwitched: activation.runtimeSwitched,
            runtimeErrorDescription: activation.runtimeErrorDescription,
            loginURL: loginResult.loginURL
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

    public func binaryAvailable() async throws -> NolonCodexBinaryAvailablePayload {
        let manifest = try await binaryManager.loadManifest()
        let releases = try await binaryManager.fetchRemoteReleases(includePrerelease: manifest.includeBetaVersions)
        let versions = releases.map { release in
            NolonCodexRemoteVersionView(
                version: release.version,
                tag: release.tag,
                downloadURL: release.assetURL.absoluteString,
                isPrerelease: release.isPrerelease
            )
        }
        return NolonCodexBinaryAvailablePayload(versions: versions)
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
            weeklyResetDescription: snapshot.weeklyResetDescription,
            probeWarning: nil,
            probeHint: nil
        )
    }

    public func providerList() async throws -> NolonProviderListPayload {
        let templates = ProviderTemplate.allCases.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
        let providers: [NolonProviderCLIView] = templates.compactMap { template in
            let executable = template.cliName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !executable.isEmpty else { return nil }
            let resolved = Self.resolveCLIInOfficialPaths(named: executable)
            guard let resolved else { return nil }
            return NolonProviderCLIView(
                providerID: template.providerID,
                name: template.displayName,
                cli: executable,
                installed: true,
                executablePath: resolved
            )
        }
        return NolonProviderListPayload(providers: providers)
    }

    public func providerDiscover() async throws -> NolonCodexProviderDiscoverPayload {
        let providerIDs = ["codex", "codex-xcode"]
        var providers: [NolonCodexProviderDiscoverView] = []
        providers.reserveCapacity(providerIDs.count)

        for providerID in providerIDs {
            let provider = try Self.provider(for: providerID)
            let authFile = await authManager.authFile(for: provider)
            let targetPath: String?
            if let authFile, authFile.isSymbolicLink {
                targetPath = try? authFile.destinationOfSymbolicLink().url.standardizedFileURL.path
            } else {
                targetPath = nil
            }

            providers.append(
                NolonCodexProviderDiscoverView(
                    providerID: providerID,
                    name: provider.name,
                    templateID: provider.templateId ?? providerID,
                    codexHomePath: authFile?.parentFolder()?.url.standardizedFileURL.path ?? "-",
                    authPath: authFile?.url.standardizedFileURL.path ?? "-",
                    authExists: authFile?.isExists ?? false,
                    authIsSymlink: authFile?.isSymbolicLink ?? false,
                    authSymlinkTargetPath: targetPath
                )
            )
        }

        return NolonCodexProviderDiscoverPayload(providers: providers)
    }

    public func runtimeList(providerID: String?) async throws -> NolonCodexRuntimeListPayload {
        _ = providerID
        let currentPID = currentPIDProvider()
        let snapshots = try runtimeProcessInspector.listProcesses()
        let views = snapshots
            .filter { snapshot in
                snapshot.pid != currentPID && Self.isCodexRuntimeCommand(snapshot.command)
            }
            .sorted(by: { $0.pid < $1.pid })
            .map { snapshot in
                NolonCodexRuntimeProcessView(
                    pid: snapshot.pid,
                    ppid: snapshot.ppid,
                    elapsed: snapshot.elapsed,
                    providerHint: Self.providerHint(from: snapshot.command),
                    command: snapshot.command
                )
            }
        return NolonCodexRuntimeListPayload(processes: views)
    }

    public func runtimeStop(pid: Int32, force: Bool, timeoutSeconds: Int) async throws -> NolonCodexRuntimeStopPayload {
        guard pid > 1 else {
            throw NolonCoreCLIError.invalidArguments("Invalid --pid: \(pid)")
        }
        guard timeoutSeconds > 0 else {
            throw NolonCoreCLIError.invalidArguments("Invalid --timeout-seconds: \(timeoutSeconds)")
        }
        if pid == currentPIDProvider() {
            throw NolonCoreCLIError.invalidArguments("Refusing to stop current nolon process: \(pid)")
        }

        if force {
            try runtimeSignalController.send(signal: SIGKILL, to: pid)
            let exited = !runtimeSignalController.isRunning(pid: pid)
            return NolonCodexRuntimeStopPayload(
                pid: pid,
                requestedSignal: "kill",
                didEscalateToKill: false,
                exited: exited
            )
        }

        try runtimeSignalController.send(signal: SIGTERM, to: pid)
        let attempts = max(1, timeoutSeconds * 10)
        for _ in 0..<attempts {
            if !runtimeSignalController.isRunning(pid: pid) {
                return NolonCodexRuntimeStopPayload(
                    pid: pid,
                    requestedSignal: "term",
                    didEscalateToKill: false,
                    exited: true
                )
            }
            try await sleep(100_000_000)
        }

        try runtimeSignalController.send(signal: SIGKILL, to: pid)
        for _ in 0..<20 {
            if !runtimeSignalController.isRunning(pid: pid) {
                break
            }
            try await sleep(100_000_000)
        }
        let exited = !runtimeSignalController.isRunning(pid: pid)
        return NolonCodexRuntimeStopPayload(
            pid: pid,
            requestedSignal: "term",
            didEscalateToKill: true,
            exited: exited
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

    private static func loadEmail(for account: CodexAuthAccount, authManager: CodexAuthManager) -> String? {
        guard let data = try? authManager.accountAuthFile(relativeAuthPath: account.relativeAuthPath).data(), !data.isEmpty else { return nil }
        let summary = CodexAuthSummary.fromJSONData(data)
        return summary.email
    }

    private static func makeUsageDisplay(from cache: CodexAuthUsageCache?) -> String? {
        guard let cache else { return nil }
        let primary = cache.usage.primary.map { Int($0.remainingPercent.rounded()) }
        let secondary = cache.usage.secondary.map { Int($0.remainingPercent.rounded()) }
        let left = primary.map { "\($0)%" } ?? "-"
        let right = secondary.map { "\($0)%" } ?? "-"
        return "5h \(left) / 7d \(right)"
    }

    private static func resolveRefreshTime(from cache: CodexAuthUsageCache?) -> Date? {
        guard let cache else { return nil }
        return cache.creditsRefreshedAt ?? cache.usage.updatedAt
    }

    private static func isCodexRuntimeCommand(_ command: String) -> Bool {
        if isNolonCodexCLICommand(command) {
            return false
        }
        let normalized = command.lowercased()
        return normalized.contains("codex-app-server") || normalized.contains("codex")
    }

    private static func isNolonCodexCLICommand(_ command: String) -> Bool {
        let normalized = command.lowercased()
        return normalized.contains("nolon codex ")
    }

    private static func providerHint(from command: String) -> String? {
        let normalized = command.lowercased()
        if normalized.contains("codex-xcode") || normalized.contains("codexxcode") {
            return "codex-xcode"
        }
        if normalized.contains("codex") {
            return "codex"
        }
        return nil
    }

    private static func resolveCLIInOfficialPaths(named executable: String) -> String? {
        let candidates = [
            "/opt/homebrew/bin/\(executable)",
            "/usr/local/bin/\(executable)",
            "/usr/bin/\(executable)",
        ]

        let fileManager = FileManager.default
        for path in candidates {
            guard fileManager.fileExists(atPath: path),
                  fileManager.isExecutableFile(atPath: path)
            else { continue }
            return URL(fileURLWithPath: path).standardizedFileURL.path
        }
        return nil
    }
}

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
            return await NolonCoreCLIRunner().execute(arguments: normalizedArguments)
        }

        let context = NolonCLIExecutionContext(service: codexService)
        do {
            let output = try await NolonCodexCLIExecutor.execute(arguments: normalizedArguments, context: context)
            return NolonCLIExecutionResult(exitCode: 0, stdout: output, stderr: "")
        } catch let error as NolonCoreCLIError {
            return NolonCLIExecutionResult(exitCode: 2, stdout: "", stderr: context.errorJSON(for: error))
        } catch {
            let message = NolonRootCommand.message(for: error)
            let wrapped = NolonCoreCLIError.invalidArguments(message)
            return NolonCLIExecutionResult(exitCode: 2, stdout: "", stderr: context.errorJSON(for: wrapped))
        }
    }

    private static func shouldRouteToCoreCLI(arguments: [String]) -> Bool {
        guard let root = arguments.first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        else {
            return false
        }
        return root == "skills" || root == "workflow" || root == "mcp" || root == "remote"
    }

    private static func normalizeHelpArguments(_ arguments: [String]) -> [String] {
        guard !arguments.isEmpty else { return [] }
        var normalized = arguments
        if normalized.last == "help" {
            normalized[normalized.count - 1] = "--help"
        }
        if normalized.contains("--help") || normalized.contains("-h") {
            return normalized
        }
        let root = normalized[0].lowercased()
        let groupsNeedingHelp: [String: Set<String>] = [
            "codex": ["auth", "binary", "status", "runtime", "provider"],
            "skills": ["repo", "migrate"],
        ]
        let rootCommands = Set(["codex", "provider", "skills", "workflow", "mcp", "remote"])
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
            return NolonProviderListCommand.self
        case "skills":
            guard arguments.count >= 2 else { return NolonSkillsRootCommand.self }
            let action = arguments[1].lowercased()
            switch action {
            case "repo":
                guard arguments.count >= 3 else { return NolonSkillsRepoGroupCommand.self }
                return skillsRepoCommandType(action: arguments[2])
            case "migrate":
                guard arguments.count >= 3 else { return NolonSkillsMigrateGroupCommand.self }
                return skillsMigrateCommandType(action: arguments[2])
            case "discover":
                return NolonSkillsDiscoverCommand.self
            case "parse":
                return NolonSkillsParseCommand.self
            case "install":
                return NolonSkillsInstallCommand.self
            case "uninstall":
                return NolonSkillsUninstallCommand.self
            default:
                return NolonSkillsRootCommand.self
            }
        case "workflow":
            guard arguments.count >= 2 else { return NolonWorkflowRootCommand.self }
            return workflowCommandType(action: arguments[1])
        case "mcp":
            guard arguments.count >= 2 else { return NolonMcpRootCommand.self }
            return mcpCommandType(action: arguments[1])
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
        case "status":
            return NolonCodexAuthStatusCommand.self
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
        case "discover":
            return NolonWorkflowDiscoverCommand.self
        case "install":
            return NolonWorkflowInstallCommand.self
        case "uninstall":
            return NolonWorkflowUninstallCommand.self
        default:
            return NolonWorkflowRootCommand.self
        }
    }

    private static func mcpCommandType(action: String) -> ParsableCommand.Type? {
        switch action.lowercased() {
        case "discover":
            return NolonMcpDiscoverCommand.self
        case "install":
            return NolonMcpInstallCommand.self
        case "uninstall":
            return NolonMcpUninstallCommand.self
        default:
            return NolonMcpRootCommand.self
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

struct NolonRuntimeProcessSnapshot: Sendable, Equatable {
    let pid: Int32
    let ppid: Int32?
    let elapsed: String
    let command: String
}

protocol NolonCodexRuntimeProcessInspecting: Sendable {
    func listProcesses() throws -> [NolonRuntimeProcessSnapshot]
}

protocol NolonCodexRuntimeSignalControlling: Sendable {
    func send(signal: Int32, to pid: Int32) throws
    func isRunning(pid: Int32) -> Bool
}

struct NolonCodexRuntimeProcessInspector: NolonCodexRuntimeProcessInspecting {
    func listProcesses() throws -> [NolonRuntimeProcessSnapshot] {
        var payload = SKProcessPayload.executableURL(URL(fileURLWithPath: "/bin/ps"))
        payload.arguments = ["-axo", "pid=,ppid=,etime=,command="]
        payload.throwOnNonZeroExit = false
        payload.timeoutMs = 10_000
        let result = try SKProcessRunner.runSync(payload)

        guard result.exitCode == 0 else {
            let stderr = result.stderr.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let stdout = result.stdout.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            let message = stderr.isEmpty ? (stdout.isEmpty ? "ps command failed" : stdout) : stderr
            throw NolonCoreCLIError.domainFailed(code: "runtime_ps_failed", message: message)
        }
        let content = result.stdout

        return content
            .split(separator: "\n")
            .compactMap { line in
                let parts = line.split(omittingEmptySubsequences: true, whereSeparator: { $0.isWhitespace })
                guard parts.count >= 4, let pid = Int32(parts[0]), let ppid = Int32(parts[1]) else {
                    return nil
                }
                let elapsed = String(parts[2])
                let command = parts.dropFirst(3).joined(separator: " ")
                return NolonRuntimeProcessSnapshot(pid: pid, ppid: ppid, elapsed: elapsed, command: command)
            }
    }
}

struct NolonCodexRuntimeSignalController: NolonCodexRuntimeSignalControlling {
    func send(signal: Int32, to pid: Int32) throws {
        if kill(pid, signal) != 0 {
            let code = errno
            throw NolonCoreCLIError.domainFailed(
                code: "runtime_signal_failed",
                message: "Failed to send signal \(signal) to pid \(pid), errno=\(code)"
            )
        }
    }

    func isRunning(pid: Int32) -> Bool {
        if kill(pid, 0) == 0 {
            return true
        }
        return errno == EPERM
    }
}
