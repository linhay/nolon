import Foundation
import CodexProvider
import CodexCLIKit
import STFilePath

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

    typealias TokenReader = @Sendable (CodexAuthAccount) async throws -> (idToken: String, accessToken: String, chatgptAccountID: String?)?
    typealias RuntimeSwitch = @Sendable (String, String, String?, String, [String: String]) async throws -> Void

    private let tokenReader: TokenReader
    private let runtimeSwitch: RuntimeSwitch
    private let runtimeHomeResolver: @Sendable (UUID, [String: String]) -> STFolder

    public init() {
        let authManager = CodexAuthManager()
        let switcher = CodexRuntimeAccountSwitcher.shared

        self.tokenReader = { account in
            try await authManager.readTokenPair(for: account)
        }
        self.runtimeHomeResolver = { accountID, environment in
            CodexAuthManager(environment: environment).runtimeHomeFolder(accountID: accountID)
        }
        self.runtimeSwitch = { idToken, accessToken, chatgptAccountID, executable, environment in
            let tokenPair = CodexTokenPair(idToken: idToken, accessToken: accessToken, chatgptAccountID: chatgptAccountID)
            _ = try await switcher.switchAccount(tokens: tokenPair, executable: executable, environment: environment)
        }
    }

    init(
        tokenReader: @escaping TokenReader,
        runtimeSwitch: @escaping RuntimeSwitch,
        runtimeHomeResolver: @escaping @Sendable (UUID, [String: String]) -> STFolder = { accountID, environment in
            CodexAuthManager(environment: environment).runtimeHomeFolder(accountID: accountID)
        }
    ) {
        self.tokenReader = tokenReader
        self.runtimeSwitch = runtimeSwitch
        self.runtimeHomeResolver = runtimeHomeResolver
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
            var runtimeEnvironment = environment
            let runtimeHome = runtimeHomeResolver(account.id, environment)
            _ = runtimeHome.createIfNotExists()
            runtimeEnvironment["CODEX_HOME"] = runtimeHome.url.standardizedFileURL.path
            try await runtimeSwitch(tokenPair.idToken, tokenPair.accessToken, tokenPair.chatgptAccountID, executable, runtimeEnvironment)
        } catch let error as CodexCLIError {
            throw CodexAuthRuntimeCoordinatorError.runtimeSwitchFailed(reason: error.localizedDescription)
        } catch {
            throw CodexAuthRuntimeCoordinatorError.runtimeSwitchFailed(reason: error.localizedDescription)
        }
    }
}
