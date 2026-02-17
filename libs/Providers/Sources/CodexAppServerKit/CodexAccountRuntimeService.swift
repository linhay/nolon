import Foundation
import CodexCLIKit

public protocol CodexTokenRefreshing: Sendable {
    func refreshedTokens(reason: CodexRefreshReason) async throws -> CodexTokenPair
}

private struct AccountReadPayload: Decodable {
    let account: AccountDetailsPayload?
    let requiresOpenaiAuth: Bool?
}

private struct AccountDetailsPayload: Decodable {
    let type: String?
    let email: String?
    let planType: String?
}

private struct RateLimitsReadPayload: Decodable {
    let rateLimits: CodexRuntimeRateLimitsSnapshot
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

    public func switchAccount(idToken: String, accessToken: String, chatgptAccountID: String? = nil) async throws {
        async let updated = session.waitForNotification(method: .accountUpdated, timeout: 8)
        let params: [String: Any] = [
            "type": "chatgptAuthTokens",
            "idToken": idToken,
            "accessToken": accessToken,
            "chatgptAccountId": chatgptAccountID ?? NSNull(),
        ]
        let paramsData = try CodexAppServerSession.encodeParams(params)
        _ = try await session.request(method: CodexAppServerMethod.accountLoginStart.rawValue, paramsData: paramsData)
        _ = try await updated
    }

    public func readAccount(refreshToken: Bool = false) async throws -> CodexRuntimeAccountState {
        let params = try CodexAppServerSession.encodeParams([
            "refreshToken": refreshToken,
        ])
        let response = try await session.request(method: CodexAppServerMethod.accountRead.rawValue, paramsData: params)
        let payload: AccountReadPayload = try decodeResult(response.result)
        let account = payload.account
        let mode = account?.type.flatMap(Self.parseAuthMode)

        return CodexRuntimeAccountState(
            email: account?.email,
            planType: account?.planType,
            requiresOpenaiAuth: payload.requiresOpenaiAuth ?? false,
            authMode: mode
        )
    }

    public func readRateLimits() async throws -> CodexRuntimeRateLimitsSnapshot {
        let response = try await session.request(method: CodexAppServerMethod.accountRateLimitsRead.rawValue)
        let payload: RateLimitsReadPayload = try decodeResult(response.result)
        return payload.rateLimits
    }

    public func logout() async throws {
        let params = try CodexAppServerSession.encodeParams(NSNull())
        _ = try await session.request(method: CodexAppServerMethod.accountLogout.rawValue, paramsData: params)
    }

    public func shutdown() async {
        await session.shutdown()
    }

    private func decodeResult<T: Decodable>(_ raw: Any?) throws -> T {
        let object = raw ?? [:]
        do {
            let data = try JSONSerialization.data(withJSONObject: object)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CodexCLIError.invalidOutput(error.localizedDescription)
        }
    }

    private static func parseAuthMode(_ raw: String) -> CodexRuntimeAuthMode? {
        if let mode = CodexRuntimeAuthMode(rawValue: raw) {
            return mode
        }
        switch raw.lowercased() {
        case "apikey":
            return .apikey
        case "chatgpt":
            return .chatgpt
        case "chatgptauthtokens":
            return .chatgptAuthTokens
        default:
            return nil
        }
    }
}
