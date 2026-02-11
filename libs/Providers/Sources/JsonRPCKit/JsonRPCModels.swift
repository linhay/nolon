import Foundation

public enum JsonRPCID: Hashable, Sendable {
    case int(Int)
    case string(String)

    public init?(any value: Any?) {
        switch value {
        case let number as NSNumber:
            self = .int(number.intValue)
        case let string as String:
            self = .string(string)
        default:
            return nil
        }
    }

    public var rawValue: Any {
        switch self {
        case let .int(value): return value
        case let .string(value): return value
        }
    }
}

public struct JsonRPCErrorObject: Sendable, Equatable {
    public let code: Int
    public let message: String

    public init(code: Int, message: String) {
        self.code = code
        self.message = message
    }
}

public struct JsonRPCResponseMessage: @unchecked Sendable {
    public let id: JsonRPCID
    public let result: Any?
    public let error: JsonRPCErrorObject?

    public init(id: JsonRPCID, result: Any?, error: JsonRPCErrorObject?) {
        self.id = id
        self.result = result
        self.error = error
    }
}

public struct JsonRPCNotificationMessage: @unchecked Sendable {
    public let method: String
    public let params: Any?

    public init(method: String, params: Any?) {
        self.method = method
        self.params = params
    }
}

public struct JsonRPCServerRequestMessage: @unchecked Sendable {
    public let id: JsonRPCID
    public let method: String
    public let params: Any?

    public init(id: JsonRPCID, method: String, params: Any?) {
        self.id = id
        self.method = method
        self.params = params
    }
}
