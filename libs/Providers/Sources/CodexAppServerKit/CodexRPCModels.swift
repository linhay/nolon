import Foundation
import JsonRPCKit

public typealias CodexRPCID = JsonRPCID
public typealias CodexRPCErrorObject = JsonRPCErrorObject
public typealias CodexRPCResponseMessage = JsonRPCResponseMessage
public typealias CodexRPCNotificationMessage = JsonRPCNotificationMessage
public typealias CodexRPCServerRequestMessage = JsonRPCServerRequestMessage

public struct CodexTokenPair: Sendable, Equatable {
    public let idToken: String
    public let accessToken: String

    public init(idToken: String, accessToken: String) {
        self.idToken = idToken
        self.accessToken = accessToken
    }
}

public enum CodexRefreshReason: String, Sendable {
    case unauthorized
    case unknown
}

public enum CodexRuntimeAuthMode: String, Sendable, Equatable {
    case apikey
    case chatgpt
    case chatgptAuthTokens
}

public struct CodexRuntimeAccountState: Sendable, Equatable {
    public let email: String?
    public let planType: String?
    public let requiresOpenaiAuth: Bool
    public let authMode: CodexRuntimeAuthMode?

    public init(email: String?, planType: String?, requiresOpenaiAuth: Bool, authMode: CodexRuntimeAuthMode?) {
        self.email = email
        self.planType = planType
        self.requiresOpenaiAuth = requiresOpenaiAuth
        self.authMode = authMode
    }
}
