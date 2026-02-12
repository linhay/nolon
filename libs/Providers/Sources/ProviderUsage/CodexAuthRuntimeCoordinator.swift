import Foundation
import CodexProvider
import CodexCLIKit

public enum CodexAuthRuntimeCoordinatorError: LocalizedError, Sendable, Equatable {
    case tokenPairMissing(accountID: UUID)
    case runtimeSwitchFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case let .tokenPairMissing(accountID):
            return "Codex account token pair is missing for account: \(accountID.uuidString)"
        case let .runtimeSwitchFailed(reason):
            return "Failed to switch Codex runtime account: \(reason)"
        }
    }
}

public actor CodexAuthRuntimeCoordinator {
    public static let shared = CodexAuthRuntimeCoordinator()

    typealias TokenReader = @Sendable (CodexAuthAccount) async throws -> (idToken: String, accessToken: String)?
    typealias RuntimeSwitch = @Sendable (String, String, String, [String: String]) async throws -> Void

    private let tokenReader: TokenReader
    private let runtimeSwitch: RuntimeSwitch

    public init() {
        let authManager = CodexAuthManager()
        let switcher = CodexRuntimeAccountSwitcher.shared

        self.tokenReader = { account in
            try await authManager.readTokenPair(for: account)
        }
        self.runtimeSwitch = { idToken, accessToken, executable, environment in
            let tokenPair = CodexTokenPair(idToken: idToken, accessToken: accessToken)
            _ = try await switcher.switchAccount(tokens: tokenPair, executable: executable, environment: environment)
        }
    }

    init(tokenReader: @escaping TokenReader, runtimeSwitch: @escaping RuntimeSwitch) {
        self.tokenReader = tokenReader
        self.runtimeSwitch = runtimeSwitch
    }

    public func activateAccountInRuntime(
        account: CodexAuthAccount,
        executable: String = "codex",
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) async throws {
        guard let tokenPair = try await tokenReader(account) else {
            throw CodexAuthRuntimeCoordinatorError.tokenPairMissing(accountID: account.id)
        }

        do {
            try await runtimeSwitch(tokenPair.idToken, tokenPair.accessToken, executable, environment)
        } catch let error as CodexCLIError {
            throw CodexAuthRuntimeCoordinatorError.runtimeSwitchFailed(reason: error.localizedDescription)
        } catch {
            throw CodexAuthRuntimeCoordinatorError.runtimeSwitchFailed(reason: error.localizedDescription)
        }
    }
}
