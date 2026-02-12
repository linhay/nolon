import Foundation
import CodexCLIKit
import CodexAppServerKit

public actor CodexRuntimeAccountSwitcher {
    public static let shared = CodexRuntimeAccountSwitcher()

    private var services: [String: CodexAccountRuntimeService] = [:]

    public init() {}

    public func switchAccount(
        tokens: CodexTokenPair,
        executable: String = "codex",
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws -> CodexRuntimeAccountState {
        let service = try await serviceFor(executable: executable, environment: environment)
        do {
            try await service.switchAccount(idToken: tokens.idToken, accessToken: tokens.accessToken)
            return try await service.readAccount(refreshToken: false)
        } catch let error as CodexCLIError {
            throw error
        } catch {
            throw CodexCLIError.recoverableFallback(error.localizedDescription)
        }
    }

    public func logout(
        executable: String = "codex",
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws {
        let service = try await serviceFor(executable: executable, environment: environment)
        try await service.logout()
    }

    public func shutdownAll() async {
        let values = services.values
        services.removeAll()
        for service in values {
            await service.shutdown()
        }
    }

    private func serviceFor(executable: String, environment: [String: String]) async throws -> CodexAccountRuntimeService {
        let resolvedBinary = CodexRuntimeSupport.resolvedBinary(preferredBinary: executable, environment: environment)
        let key = cacheKey(executable: resolvedBinary, environment: environment)
        if let existing = services[key] {
            return existing
        }
        let created = CodexAccountRuntimeService(executable: resolvedBinary, environment: environment)
        do {
            try await created.initialize(clientName: "nolon", clientVersion: "1.0.0")
        } catch {
            throw CodexCLIError.recoverableFallback(error.localizedDescription)
        }
        services[key] = created
        return created
    }

    private func cacheKey(executable: String, environment: [String: String]) -> String {
        let codexHome = environment["CODEX_HOME"] ?? ""
        let cli = environment["CODEX_CLI_PATH"] ?? ""
        return "\(executable)|\(codexHome)|\(cli)"
    }
}
