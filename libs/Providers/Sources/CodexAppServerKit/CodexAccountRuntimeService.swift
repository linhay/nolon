import Foundation
import CodexCLIKit

public protocol CodexTokenRefreshing: Sendable {
    func refreshedTokens(reason: CodexRefreshReason) async throws -> CodexTokenPair
}

public actor CodexAccountRuntimeService {
    private let session: CodexAppServerSession
    private var tokenRefresher: (any CodexTokenRefreshing)?

    public init(
        executable: String = "codex",
        environment: [String: String] = ProcessInfo.processInfo.environment,
        session: CodexAppServerSession? = nil
    ) {
        self.session = session ?? CodexAppServerSession(executable: executable, environment: environment)
    }

    public func setTokenRefresher(_ refresher: (any CodexTokenRefreshing)?) async {
        self.tokenRefresher = refresher
        await session.setServerRequestHandler { [weak self] request in
            guard request.method == CodexAppServerServerRequest.accountChatGPTAuthTokensRefresh.rawValue else {
                throw CodexCLIError.protocolError("Unsupported server request: \(request.method)")
            }
            guard let self else {
                throw CodexCLIError.protocolError("Runtime service deallocated")
            }
            guard let refresher = await self.tokenRefresher else {
                throw CodexCLIError.recoverableFallback("No token refresher configured")
            }

            let reason: CodexRefreshReason
            if let params = request.params as? [String: Any],
               let reasonRaw = params["reason"] as? String,
               reasonRaw.lowercased() == "unauthorized" {
                reason = .unauthorized
            } else {
                reason = .unknown
            }

            let tokenPair = try await refresher.refreshedTokens(reason: reason)
            return [
                "idToken": tokenPair.idToken,
                "accessToken": tokenPair.accessToken,
            ]
        }
    }

    public func initialize(clientName: String = "nolon", clientVersion: String = "1.0.0") async throws {
        try await session.initialize(clientName: clientName, clientVersion: clientVersion, experimentalApi: true)
    }

    public func switchAccount(idToken: String, accessToken: String) async throws {
        async let updated = session.waitForNotification(method: .accountUpdated, timeout: 8)
        let params = try CodexAppServerSession.encodeParams([
            "type": "chatgptAuthTokens",
            "idToken": idToken,
            "accessToken": accessToken,
        ])
        _ = try await session.request(method: CodexAppServerMethod.accountLoginStart.rawValue, paramsData: params)
        _ = try await updated
    }

    public func readAccount(refreshToken: Bool = false) async throws -> CodexRuntimeAccountState {
        let params = try CodexAppServerSession.encodeParams([
            "refreshToken": refreshToken,
        ])
        let response = try await session.request(method: CodexAppServerMethod.accountRead.rawValue, paramsData: params)
        let raw = response.result

        guard let dict = raw as? [String: Any] else {
            throw CodexCLIError.invalidOutput("account/read result is not object")
        }

        let requiresOpenaiAuth = (dict["requiresOpenaiAuth"] as? Bool) ?? false
        let account = dict["account"] as? [String: Any]
        let email = account?["email"] as? String
        let plan = account?["planType"] as? String

        // account/read does not always return authMode; best effort from account type.
        let mode: CodexRuntimeAuthMode?
        if let accountType = (account?["type"] as? String)?.lowercased() {
            mode = CodexRuntimeAuthMode(rawValue: accountType)
        } else {
            mode = nil
        }

        return CodexRuntimeAccountState(
            email: email,
            planType: plan,
            requiresOpenaiAuth: requiresOpenaiAuth,
            authMode: mode
        )
    }

    public func logout() async throws {
        let params = try CodexAppServerSession.encodeParams(NSNull())
        _ = try await session.request(method: CodexAppServerMethod.accountLogout.rawValue, paramsData: params)
    }

    public func shutdown() async {
        await session.shutdown()
    }
}
