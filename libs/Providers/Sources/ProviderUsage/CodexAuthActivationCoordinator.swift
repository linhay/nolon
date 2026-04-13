import Foundation
import ProviderCatalog

public actor CodexAuthActivationCoordinator {
    public static let shared = CodexAuthActivationCoordinator()

    typealias AuthActivate = @Sendable (CodexAuthAccount, Provider) async throws -> Void

    private let authActivate: AuthActivate

    public init() {
        let authManager = CodexAuthManager.shared
        self.authActivate = { account, provider in
            try await authManager.activateAccountAndMarkActive(account, for: provider)
        }
    }

    init(authActivate: @escaping AuthActivate) {
        self.authActivate = authActivate
    }

    public func activate(
        account: CodexAuthAccount,
        provider: Provider
    ) async throws {
        try await authActivate(account, provider)
    }
}
