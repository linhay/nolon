import Foundation

public enum PiAuthStatus: Equatable, Sendable {
    case unavailable
    case available(email: String?)
    case invalid
}

public enum PiAuthStatusParser {
    public static func parse(_ data: Data) -> PiAuthStatus {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .invalid
        }

        return .available(email: extractEmail(from: object))
    }

    public static func extractEmail(from object: [String: Any]) -> String? {
        if let email = object["email"] as? String, !email.isEmpty {
            return email
        }
        if let user = object["user"] as? [String: Any], let email = user["email"] as? String, !email.isEmpty {
            return email
        }
        if let account = object["account"] as? [String: Any], let email = account["email"] as? String, !email.isEmpty {
            return email
        }
        return nil
    }
}
