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
    public let chatgptAccountID: String?

    public init(idToken: String, accessToken: String, chatgptAccountID: String? = nil) {
        self.idToken = idToken
        self.accessToken = accessToken
        self.chatgptAccountID = chatgptAccountID
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

public struct CodexRuntimeRateLimitsSnapshot: Sendable, Equatable, Codable {
    public let primary: CodexRuntimeRateLimitWindow?
    public let secondary: CodexRuntimeRateLimitWindow?
    public let credits: CodexRuntimeCreditsSnapshot?

    public init(
        primary: CodexRuntimeRateLimitWindow?,
        secondary: CodexRuntimeRateLimitWindow?,
        credits: CodexRuntimeCreditsSnapshot?
    ) {
        self.primary = primary
        self.secondary = secondary
        self.credits = credits
    }
}

public struct CodexRuntimeRateLimitWindow: Sendable, Equatable, Codable {
    public let usedPercent: Double
    public let windowDurationMins: Int?
    public let resetsAt: Int?

    public init(usedPercent: Double, windowDurationMins: Int?, resetsAt: Int?) {
        self.usedPercent = usedPercent
        self.windowDurationMins = windowDurationMins
        self.resetsAt = resetsAt
    }
}

public struct CodexRuntimeCreditsSnapshot: Sendable, Equatable, Codable {
    public let hasCredits: Bool
    public let unlimited: Bool
    public let balance: String?

    public init(hasCredits: Bool, unlimited: Bool, balance: String?) {
        self.hasCredits = hasCredits
        self.unlimited = unlimited
        self.balance = balance
    }
}
