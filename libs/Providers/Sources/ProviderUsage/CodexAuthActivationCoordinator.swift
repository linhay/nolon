import Foundation
import ProviderCatalog

public struct CodexAuthActivationResult: Sendable, Equatable {
    public let runtimeSwitched: Bool
    public let runtimeErrorDescription: String?

    public init(runtimeSwitched: Bool, runtimeErrorDescription: String?) {
        self.runtimeSwitched = runtimeSwitched
        self.runtimeErrorDescription = runtimeErrorDescription
    }
}

public actor CodexAuthActivationCoordinator {
    public static let shared = CodexAuthActivationCoordinator()

    typealias AuthActivate = @Sendable (CodexAuthAccount, Provider) async throws -> Void
    typealias RuntimeActivate = @Sendable (CodexAuthAccount) async throws -> Void

    private let authActivate: AuthActivate
    private let runtimeActivate: RuntimeActivate

    public init() {
        let authManager = CodexAuthManager()
        let runtimeCoordinator = CodexAuthRuntimeCoordinator.shared
        self.authActivate = { account, provider in
            try await authManager.activateAccountAndMarkActive(account, for: provider)
        }
        self.runtimeActivate = { account in
            try await runtimeCoordinator.activateAccountInRuntime(account: account)
        }
    }

    init(authActivate: @escaping AuthActivate, runtimeActivate: @escaping RuntimeActivate) {
        self.authActivate = authActivate
        self.runtimeActivate = runtimeActivate
    }

    public func activate(
        account: CodexAuthAccount,
        provider: Provider
    ) async throws -> CodexAuthActivationResult {
        try await authActivate(account, provider)
        do {
            try await runtimeActivate(account)
            return CodexAuthActivationResult(runtimeSwitched: true, runtimeErrorDescription: nil)
        } catch {
            return CodexAuthActivationResult(
                runtimeSwitched: false,
                runtimeErrorDescription: error.localizedDescription
            )
        }
    }
}
