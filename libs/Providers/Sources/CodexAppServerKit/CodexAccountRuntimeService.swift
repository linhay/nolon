import Foundation
import CodexCLIKit
import STJSON

public protocol CodexTokenRefreshing: Sendable {
    func refreshedTokens(reason: CodexRefreshReason) async throws -> CodexTokenPair
}

public enum CodexAccountRuntimeServiceError: LocalizedError, Sendable, Equatable {
    case unsupportedServerRequest(method: String)
    case runtimeServiceDeallocated
    case loginStartMissingLoginID
    case loginStartMissingAuthURL
    case loginCompletedUnexpectedID(expected: String, actual: String)
    case loginCompletedFailed(message: String)
    case invalidPayload(context: String, details: String)

    public var code: String {
        switch self {
        case .unsupportedServerRequest:
            return "unsupported_server_request"
        case .runtimeServiceDeallocated:
            return "runtime_service_deallocated"
        case .loginStartMissingLoginID:
            return "login_start_missing_login_id"
        case .loginStartMissingAuthURL:
            return "login_start_missing_auth_url"
        case .loginCompletedUnexpectedID:
            return "login_completed_unexpected_id"
        case .loginCompletedFailed:
            return "login_completed_failed"
        case .invalidPayload:
            return "invalid_payload"
        }
    }

    public var errorDescription: String? {
        switch self {
        case let .unsupportedServerRequest(method):
            return "Unsupported server request: \(method)"
        case .runtimeServiceDeallocated:
            return "Runtime service deallocated"
        case .loginStartMissingLoginID:
            return "Missing loginId from account/login/start"
        case .loginStartMissingAuthURL:
            return "Missing authUrl from account/login/start"
        case let .loginCompletedUnexpectedID(expected, actual):
            return "Unexpected login completion id: \(actual), expected: \(expected)"
        case let .loginCompletedFailed(message):
            return message
        case let .invalidPayload(context, details):
            return "Invalid payload for \(context): \(details)"
        }
    }
}

private struct AccountReadPayload: Decodable {
    let account: AccountDetailsPayload?
    let requiresOpenaiAuth: Bool?
}

private struct AccountLoginStartPayload: Decodable {
    let type: String?
    let loginId: String?
    let authUrl: String?
}

private struct AccountLoginCompletedPayload: Decodable {
    let loginId: String?
    let success: Bool?
    let error: String?
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
                throw CodexAccountRuntimeServiceError.unsupportedServerRequest(method: request.method)
            }
            guard let self else {
                throw CodexAccountRuntimeServiceError.runtimeServiceDeallocated
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
            let payload: [String: Any] = [
                "idToken": tokenPair.idToken,
                "accessToken": tokenPair.accessToken,
                "chatgptAccountId": tokenPair.chatgptAccountID ?? NSNull(),
            ]
            return payload
        }
    }

    public func initialize(clientName: String = "nolon", clientVersion: String = "1.0.0") async throws {
        try await session.initialize(clientName: clientName, clientVersion: clientVersion, experimentalApi: true)
    }

    public func startChatGPTLogin() async throws -> (loginID: String, authURL: URL) {
        let paramsData = try CodexAppServerSession.encodeParams([
            "type": "chatgpt",
        ])
        let response = try await session.request(method: CodexAppServerMethod.accountLoginStart.rawValue, paramsData: paramsData)
        let payload: AccountLoginStartPayload = try decodeResult(response.result, context: "account/login/start")
        guard let loginID = payload.loginId?.trimmingCharacters(in: .whitespacesAndNewlines), !loginID.isEmpty else {
            throw CodexAccountRuntimeServiceError.loginStartMissingLoginID
        }
        guard let authURLRaw = payload.authUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
              let authURL = URL(string: authURLRaw) else {
            throw CodexAccountRuntimeServiceError.loginStartMissingAuthURL
        }
        return (loginID, authURL)
    }

    public func awaitChatGPTLoginCompletion(loginID: String, timeout: TimeInterval = 300) async throws {
        let notification = try await session.waitForNotification(method: .accountLoginCompleted, timeout: timeout)
        let payload: AccountLoginCompletedPayload = try decodeResult(notification.params, context: "account/login/completed")
        if let completedID = payload.loginId, !completedID.isEmpty, completedID != loginID {
            throw CodexAccountRuntimeServiceError.loginCompletedUnexpectedID(expected: loginID, actual: completedID)
        }
        if payload.success == true {
            return
        }
        let message = payload.error?.trimmingCharacters(in: .whitespacesAndNewlines)
        throw CodexAccountRuntimeServiceError.loginCompletedFailed(message: message?.isEmpty == false ? message! : "ChatGPT login failed")
    }

    public func cancelChatGPTLogin(loginID: String) async throws {
        let paramsData = try CodexAppServerSession.encodeParams([
            "loginId": loginID,
        ])
        _ = try await session.request(method: CodexAppServerMethod.accountLoginCancel.rawValue, paramsData: paramsData)
    }

    public func readAccount(refreshToken: Bool = false) async throws -> CodexRuntimeAccountState {
        let params = try CodexAppServerSession.encodeParams([
            "refreshToken": refreshToken,
        ])
        let response = try await session.request(method: CodexAppServerMethod.accountRead.rawValue, paramsData: params)
        let payload: AccountReadPayload = try decodeResult(response.result, context: "account/read")
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
        let payload: RateLimitsReadPayload = try decodeResult(response.result, context: "account/rateLimits/read")
        return payload.rateLimits
    }

    public func logout() async throws {
        let params = try CodexAppServerSession.encodeParams([:])
        _ = try await session.request(method: CodexAppServerMethod.accountLogout.rawValue, paramsData: params)
    }

    public func shutdown() async {
        await session.shutdown()
    }

    private func decodeResult<T: Decodable>(_ raw: Any?, context: String) throws -> T {
        let object = raw ?? [:]
        do {
            let payload = Self.anyCodable(from: object)
            let data = try JSONEncoder().encode(payload)
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw CodexAccountRuntimeServiceError.invalidPayload(context: context, details: error.localizedDescription)
        }
    }

    private static func anyCodable(from value: Any) -> AnyCodable {
        switch value {
        case let codable as AnyCodable:
            return codable
        case let dict as [String: Any]:
            return AnyCodable(dict.mapValues(Self.anyCodable(from:)))
        case let array as [Any]:
            return AnyCodable(array.map(Self.anyCodable(from:)))
        case let bool as Bool:
            return AnyCodable(bool)
        case let number as NSNumber:
            return AnyCodable(number)
        case let string as String:
            return AnyCodable(string)
        case is NSNull:
            return AnyCodable(nil)
        default:
            return AnyCodable(value)
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
