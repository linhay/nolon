import Foundation
import CodexCLIKit
import CodexAppServerKit

protocol CodexRuntimeAccountServing: Sendable {
    func initialize(clientName: String, clientVersion: String) async throws
    func switchAccount(idToken: String, accessToken: String, chatgptAccountID: String?) async throws
    func readAccount(refreshToken: Bool) async throws -> CodexRuntimeAccountState
    func logout() async throws
    func shutdown() async
}

extension CodexAccountRuntimeService: CodexRuntimeAccountServing {}

public actor CodexRuntimeAccountSwitcher {
    typealias ServiceFactory = @Sendable (String, [String: String]) -> any CodexRuntimeAccountServing

    public static let shared = CodexRuntimeAccountSwitcher()

    private var services: [String: any CodexRuntimeAccountServing] = [:]
    private let serviceFactory: ServiceFactory

    public init() {
        self.serviceFactory = { executable, environment in
            CodexAccountRuntimeService(executable: executable, environment: environment)
        }
    }

    init(serviceFactory: @escaping ServiceFactory) {
        self.serviceFactory = serviceFactory
    }

    public func switchAccount(
        tokens: CodexTokenPair,
        executable: String = "codex",
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws -> CodexRuntimeAccountState {
        let service = try await serviceFor(executable: executable, environment: environment)
        do {
            try await service.switchAccount(
                idToken: tokens.idToken,
                accessToken: tokens.accessToken,
                chatgptAccountID: tokens.chatgptAccountID
            )
            return try await service.readAccount(refreshToken: false)
        } catch let error as CodexCLIError {
            throw error
        } catch let error as CodexAccountRuntimeServiceError {
            let details = error.errorDescription ?? error.code
            throw CodexCLIError.protocolError("account/\(error.code): \(details)")
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

    private func serviceFor(executable: String, environment: [String: String]) async throws -> any CodexRuntimeAccountServing {
        let resolvedBinary = await CodexRuntimeSupport.resolvedBinaryAsync(preferredBinary: executable, environment: environment)
        let key = cacheKey(executable: resolvedBinary, environment: environment)
        if let existing = services[key] {
            return existing
        }
        let created = serviceFactory(resolvedBinary, environment)
        do {
            try await created.initialize(clientName: "nolon", clientVersion: "1.0.0")
        } catch let error as CodexAccountRuntimeServiceError {
            let details = error.errorDescription ?? error.code
            throw CodexCLIError.protocolError("account/\(error.code): \(details)")
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
