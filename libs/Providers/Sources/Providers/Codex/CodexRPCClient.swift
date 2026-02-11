import Foundation
import CodexCLIKit
import CodexAppServerKit

// MARK: - Codex RPC client (local process)

struct RPCAccountResponse: Decodable {
    let account: RPCAccountDetails?
    let requiresOpenaiAuth: Bool?
}

enum RPCAccountDetails: Decodable {
    case apiKey
    case chatgpt(email: String, planType: String)

    enum CodingKeys: String, CodingKey {
        case type
        case email
        case planType
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        switch type.lowercased() {
        case "apikey":
            self = .apiKey
        case "chatgpt":
            let email = try container.decodeIfPresent(String.self, forKey: .email) ?? "unknown"
            let plan = try container.decodeIfPresent(String.self, forKey: .planType) ?? "unknown"
            self = .chatgpt(email: email, planType: plan)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Unknown account type \(type)")
        }
    }
}

struct RPCRateLimitsResponse: Decodable, Encodable {
    let rateLimits: RPCRateLimitSnapshot
}

struct RPCRateLimitSnapshot: Decodable, Encodable {
    let primary: RPCRateLimitWindow?
    let secondary: RPCRateLimitWindow?
    let credits: RPCCreditsSnapshot?
}

struct RPCRateLimitWindow: Decodable, Encodable {
    let usedPercent: Double
    let windowDurationMins: Int?
    let resetsAt: Int?
}

struct RPCCreditsSnapshot: Decodable, Encodable {
    let hasCredits: Bool
    let unlimited: Bool
    let balance: String?
}

private enum RPCWireError: Error, LocalizedError {
    case startFailed(String)
    case requestFailed(String)
    case malformed(String)

    var errorDescription: String? {
        switch self {
        case let .startFailed(message):
            "Codex not running. Try running a Codex command first. (\(message))"
        case let .requestFailed(message):
            "Codex connection failed: \(message)"
        case let .malformed(message):
            "Codex returned invalid data: \(message)"
        }
    }
}

final class CodexRPCClient: @unchecked Sendable {
    private let session: CodexAppServerSession

    init(
        executable: String = "codex",
        arguments: [String] = ["-s", "read-only", "-a", "untrusted", "app-server"],
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) throws {
        let startupArguments: [String]
        if arguments.last == "app-server" {
            startupArguments = arguments
        } else {
            startupArguments = ["app-server"]
        }
        self.session = CodexAppServerSession(
            executable: executable,
            environment: environment,
            startupArguments: startupArguments
        )
    }

    func initialize(clientName: String, clientVersion: String) async throws {
        do {
            try await session.initialize(clientName: clientName, clientVersion: clientVersion, experimentalApi: true)
        } catch {
            throw RPCWireError.requestFailed(error.localizedDescription)
        }
    }

    func fetchRateLimits() async throws -> RPCRateLimitsResponse {
        let message = try await self.request(method: CodexAppServerMethod.accountRateLimitsRead.rawValue)
        return try self.decodeResult(from: message)
    }

    func fetchAccount() async throws -> RPCAccountResponse {
        let message = try await self.request(method: CodexAppServerMethod.accountRead.rawValue, params: ["refreshToken": false])
        return try self.decodeResult(from: message)
    }

    func shutdown() {
        Task { await session.shutdown() }
    }

    private func request(method: String, params: Any = [:]) async throws -> Any {
        do {
            let paramsData = try CodexAppServerSession.encodeParams(params)
            let response = try await session.request(method: method, paramsData: paramsData)
            return response.result ?? [:]
        } catch {
            throw RPCWireError.requestFailed(error.localizedDescription)
        }
    }

    private func decodeResult<T: Decodable>(from result: Any) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: result)
        let decoder = JSONDecoder()
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw RPCWireError.malformed(error.localizedDescription)
        }
    }
}
