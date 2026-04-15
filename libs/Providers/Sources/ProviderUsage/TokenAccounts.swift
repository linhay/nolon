import Foundation
import CodexBarProviderCatalog
import STFilePath
import SKProcessRunner

public enum ProviderUsagePaths {
    public static func defaultTokenAccountsFileURL(
        baseDirectory: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
    ) -> URL {
        let base = baseDirectory ?? STFolder(NSHomeDirectory()).url
        return base
            .appendingPathComponent("Nolon", isDirectory: true)
            .appendingPathComponent("token-accounts.json")
    }
}

public struct ProviderTokenAccount: Identifiable, Codable, Sendable, Equatable {
    public let id: UUID
    public let label: String
    public let token: String
    public let addedAt: TimeInterval
    public let lastUsed: TimeInterval?

    public init(
        id: UUID,
        label: String,
        token: String,
        addedAt: TimeInterval,
        lastUsed: TimeInterval?
    ) {
        self.id = id
        self.label = label
        self.token = token
        self.addedAt = addedAt
        self.lastUsed = lastUsed
    }

    public var displayName: String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? NSLocalizedString("usage.account.token", value: "Token account", comment: "Token account label") : trimmed
    }
}

public struct ProviderTokenAccountData: Codable, Sendable, Equatable {
    public let version: Int
    public let accounts: [ProviderTokenAccount]
    public let activeIndex: Int

    public init(version: Int, accounts: [ProviderTokenAccount], activeIndex: Int) {
        self.version = version
        self.accounts = accounts
        self.activeIndex = activeIndex
    }

    public func clampedActiveIndex() -> Int {
        guard !accounts.isEmpty else { return 0 }
        return min(max(activeIndex, 0), accounts.count - 1)
    }
}

public protocol ProviderTokenAccountStoring: Sendable {
    func loadAccounts() throws -> [UsageProvider: ProviderTokenAccountData]
    func storeAccounts(_ accounts: [UsageProvider: ProviderTokenAccountData]) throws
}

public final class FileTokenAccountStore: ProviderTokenAccountStoring {
    private let file: STFile
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL) {
        self.file = STFile(fileURL)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public init(file: STFile) {
        self.file = file
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.encoder = encoder
        self.decoder = JSONDecoder()
    }

    public func loadAccounts() throws -> [UsageProvider: ProviderTokenAccountData] {
        guard file.isExists else {
            return [:]
        }
        let data = try file.data()
        if data.isEmpty {
            return [:]
        }
        return try decoder.decode([UsageProvider: ProviderTokenAccountData].self, from: data)
    }

    public func storeAccounts(_ accounts: [UsageProvider: ProviderTokenAccountData]) throws {
        _ = file.parentFolder()?.createIfNotExists()
        let data = try encoder.encode(accounts)
        try file.overlay(with: data)
    }
}

public enum GitHubCLITokenResolver {
    public static func resolve(environment: [String: String] = ProcessInfo.processInfo.environment) async -> String? {
        guard let payload = makePayload(environment: environment) else { return nil }

        do {
            let result = try await SKProcessRunner.run(payload)
            guard result.exitCode == 0 else { return nil }
            return normalizeToken(result.stdout)
        } catch {
            return nil
        }
    }

    public static func resolveSync(environment: [String: String] = ProcessInfo.processInfo.environment) -> String? {
        guard let payload = makePayload(environment: environment) else { return nil }

        do {
            let result = try SKProcessRunner.runSync(payload)
            guard result.exitCode == 0 else { return nil }
            return normalizeToken(result.stdout)
        } catch {
            return nil
        }
    }

    static func makePayload(
        environment: [String: String],
        shellResolver: (_ binary: String, _ environment: [String: String]) -> URL? = { binary, environment in
            SKProcessRunner.resolveExecutableInUserShellSync(named: binary, environment: environment)
        },
        pathResolver: (_ binary: String, _ environment: [String: String]) -> URL? = { binary, environment in
            try? SKProcessRunner.resolveExecutable(binary, environment: environment)
        },
        shellEnvironmentLoader: (_ environment: [String: String]) -> [String: String] = { environment in
            SKProcessRunner.loadUserShellEnvironmentSync(environment: environment)
        }
    ) -> SKProcessPayload? {
        let resolvedEnvironment = mergedEnvironment(
            environment,
            shellEnvironmentLoader: shellEnvironmentLoader
        )
        guard let executableURL = resolveExecutableURL(
            named: "gh",
            environment: resolvedEnvironment,
            shellResolver: shellResolver,
            pathResolver: pathResolver
        ) else {
            return nil
        }

        var payload = SKProcessPayload.executableURL(executableURL)
        payload.arguments = ["auth", "token"]
        payload.environment = SKProcessEnvironment(resolvedEnvironment)
        payload.timeoutMs = 5_000
        payload.throwOnNonZeroExit = false
        return payload
    }

    static func resolveExecutableURL(
        named binary: String,
        environment: [String: String],
        fileManager: FileManager = .default,
        shellResolver: (_ binary: String, _ environment: [String: String]) -> URL? = { binary, environment in
            SKProcessRunner.resolveExecutableInUserShellSync(named: binary, environment: environment)
        },
        pathResolver: (_ binary: String, _ environment: [String: String]) -> URL? = { binary, environment in
            try? SKProcessRunner.resolveExecutable(binary, environment: environment)
        }
    ) -> URL? {
        if binary.contains("/") {
            return fileManager.isExecutableFile(atPath: binary) ? URL(fileURLWithPath: binary) : nil
        }

        if let resolved = shellResolver(binary, environment) {
            return resolved
        }
        return pathResolver(binary, environment)
    }

    static func mergedEnvironment(_ environment: [String: String]) -> [String: String] {
        mergedEnvironment(environment) { shellBaseEnvironment in
            SKProcessRunner.loadUserShellEnvironmentSync(environment: shellBaseEnvironment)
        }
    }

    static func mergedEnvironment(
        _ environment: [String: String],
        shellEnvironmentLoader: (_ environment: [String: String]) -> [String: String]
    ) -> [String: String] {
        let processEnvironment = ProcessInfo.processInfo.environment
        let shellEnvironment = shellEnvironmentLoader(processEnvironment)
        var resolved = processEnvironment
        resolved.merge(shellEnvironment) { _, shell in shell }
        resolved.merge(environment) { _, new in new }
        let baselinePaths = [
            "/usr/local/bin",
            "/opt/homebrew/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
        ]
        let existingPaths = (resolved["PATH"] ?? "")
            .split(separator: ":")
            .map(String.init)
        var mergedPaths = existingPaths
        for path in baselinePaths where !mergedPaths.contains(path) {
            mergedPaths.append(path)
        }
        resolved["PATH"] = mergedPaths.joined(separator: ":")
        return resolved
    }

    private static func normalizeToken(_ raw: String) -> String? {
        let token = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return token.isEmpty ? nil : token
    }
}
