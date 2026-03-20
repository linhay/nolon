import Foundation
import Vapor

public struct CodexGatewayConfig: Sendable, Equatable, Codable {
    public var host: String
    public var port: Int

    public init(host: String = "127.0.0.1", port: Int = 8080) {
        self.host = host
        self.port = port
    }
}

public enum CodexGatewayRuntimeStatus: String, Sendable, Equatable, Codable, Content {
    case stopped
    case starting
    case running
    case degraded
}

public struct CodexGatewayHealthResponse: Sendable, Equatable, Codable, Content {
    public let status: String

    public init(status: String = "ok") {
        self.status = status
    }
}

public struct CodexGatewayStatusSnapshot: Sendable, Equatable, Codable, Content {
    public var status: CodexGatewayRuntimeStatus
    public var host: String
    public var port: Int
    public var startedAt: Date?

    public init(
        status: CodexGatewayRuntimeStatus,
        host: String,
        port: Int,
        startedAt: Date?
    ) {
        self.status = status
        self.host = host
        self.port = port
        self.startedAt = startedAt
    }
}

public struct CodexGatewayResponsesRequestContext: Sendable, Equatable {
    public let path: String
    public let body: String
    public let sessionID: String?
    public let conversationID: String?
    public let requestHeaders: [String: String]

    public init(
        path: String,
        body: String,
        sessionID: String?,
        conversationID: String?,
        requestHeaders: [String: String] = [:]
    ) {
        self.path = path
        self.body = body
        self.sessionID = sessionID
        self.conversationID = conversationID
        self.requestHeaders = requestHeaders
    }
}

public struct CodexGatewayResponsesResult: Sendable, Equatable {
    public let status: HTTPResponseStatus
    public let bodyData: Data
    public let contentType: HTTPMediaType

    public var body: String {
        String(decoding: bodyData, as: UTF8.self)
    }

    public init(
        status: HTTPResponseStatus = .ok,
        body: String,
        contentType: HTTPMediaType = .json
    ) {
        self.status = status
        self.bodyData = Data(body.utf8)
        self.contentType = contentType
    }

    public init(
        status: HTTPResponseStatus = .ok,
        bodyData: Data,
        contentType: HTTPMediaType = .json
    ) {
        self.status = status
        self.bodyData = bodyData
        self.contentType = contentType
    }
}

public enum CodexGatewayServer {
    public typealias StatusProvider = @Sendable () -> CodexGatewayStatusSnapshot
    public typealias ResponsesHandler = @Sendable (CodexGatewayResponsesRequestContext) async throws -> CodexGatewayResponsesResult

    public static func configure(
        app: Application,
        statusProvider: @escaping StatusProvider,
        responsesHandler: @escaping ResponsesHandler = { _ in
            CodexGatewayResponsesResult(
                status: .notImplemented,
                body: #"{"error":{"message":"Codex gateway responses forwarding is not configured."}}"#
            )
        }
    ) throws {
        try app.register(
            collection: CodexGatewayRouteCollection(
                statusProvider: statusProvider,
                responsesHandler: responsesHandler
            )
        )
    }
}

struct CodexGatewayRouteCollection: RouteCollection {
    private static let responsesMaxBodySize: ByteCount = "64mb"
    private static let forwardedHeaderNames: Set<String> = [
        "accept",
        "accept-language",
        "openai-beta",
        "openai-organization",
        "openai-project",
        "idempotency-key",
        "user-agent"
    ]
    private static let forwardedHeaderPrefixes: [String] = [
        "x-stainless-",
        "x-openai-"
    ]
    let statusProvider: CodexGatewayServer.StatusProvider
    let responsesHandler: CodexGatewayServer.ResponsesHandler

    func boot(routes: RoutesBuilder) throws {
        routes.get("healthz") { _ in
            CodexGatewayHealthResponse()
        }
        routes.grouped("gateway").get("status") { _ in
            statusProvider()
        }
        routes.on(.POST, "v1", "responses", body: .collect(maxSize: Self.responsesMaxBodySize), use: handleResponses)
        routes.on(.POST, "responses", body: .collect(maxSize: Self.responsesMaxBodySize), use: handleResponses)
    }

    private func handleResponses(_ request: Request) async throws -> Response {
        var requestHeaders: [String: String] = [:]
        for header in request.headers {
            let lowercasedName = header.name.lowercased()
            let shouldForward = Self.forwardedHeaderNames.contains(lowercasedName) ||
                Self.forwardedHeaderPrefixes.contains(where: { lowercasedName.hasPrefix($0) })
            guard shouldForward else { continue }
            requestHeaders[header.name] = header.value
        }
        let context = CodexGatewayResponsesRequestContext(
            path: request.url.path,
            body: request.body.string ?? "",
            sessionID: request.headers.first(name: "session_id"),
            conversationID: request.headers.first(name: "conversation_id"),
            requestHeaders: requestHeaders
        )
        let result = try await responsesHandler(context)
        let response = Response(status: result.status)
        response.headers.replaceOrAdd(name: .contentType, value: result.contentType.serialize())
        response.body = .init(data: result.bodyData)
        return response
    }
}
