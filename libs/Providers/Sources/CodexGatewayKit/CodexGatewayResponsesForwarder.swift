import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Vapor

public struct CodexGatewayUpstreamRequest: Sendable, Equatable {
    public let url: URL
    public let method: HTTPMethod
    public let headers: [String: String]
    public let body: Data

    public init(url: URL, method: HTTPMethod, headers: [String: String], body: Data) {
        self.url = url
        self.method = method
        self.headers = headers
        self.body = body
    }
}

public struct CodexGatewayUpstreamResponse: Sendable, Equatable {
    public let status: HTTPResponseStatus
    public let body: Data
    public let contentTypeHeader: String?

    public init(status: HTTPResponseStatus, body: Data, contentTypeHeader: String?) {
        self.status = status
        self.body = body
        self.contentTypeHeader = contentTypeHeader
    }
}

public protocol CodexGatewayUpstreamTransporting: Sendable {
    func execute(_ request: CodexGatewayUpstreamRequest) async throws -> CodexGatewayUpstreamResponse
}

public struct CodexGatewayURLSessionTransport: CodexGatewayUpstreamTransporting {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func execute(_ request: CodexGatewayUpstreamRequest) async throws -> CodexGatewayUpstreamResponse {
        var urlRequest = URLRequest(url: request.url)
        urlRequest.httpMethod = request.method.rawValue
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw Abort(.badGateway, reason: "Invalid upstream HTTP response.")
        }
        return CodexGatewayUpstreamResponse(
            status: HTTPResponseStatus(statusCode: httpResponse.statusCode),
            body: data,
            contentTypeHeader: httpResponse.value(forHTTPHeaderField: "Content-Type")
        )
    }
}

public struct CodexGatewayResponsesForwarder: Sendable {
    private let upstreamBaseURL: URL
    private let upstreamHeaders: [String: String]
    private let transport: any CodexGatewayUpstreamTransporting

    public init(
        upstreamBaseURL: URL,
        upstreamHeaders: [String: String] = [:],
        transport: any CodexGatewayUpstreamTransporting = CodexGatewayURLSessionTransport()
    ) {
        self.upstreamBaseURL = upstreamBaseURL
        self.upstreamHeaders = upstreamHeaders
        self.transport = transport
    }

    public func makeHandler() -> CodexGatewayServer.ResponsesHandler {
        { context in
            try await forward(context)
        }
    }

    public func forward(_ context: CodexGatewayResponsesRequestContext) async throws -> CodexGatewayResponsesResult {
        let expectsStream = bodyIndicatesStream(context.body)
        let upstreamRequest = try buildRequest(for: context)
        let upstreamResponse = try await transport.execute(upstreamRequest)
        if expectsStream {
            try validateStreamResponse(upstreamResponse)
        }
        let contentType = resolveContentType(header: upstreamResponse.contentTypeHeader)
        return CodexGatewayResponsesResult(
            status: upstreamResponse.status,
            bodyData: upstreamResponse.body,
            contentType: contentType
        )
    }

    private func buildRequest(for context: CodexGatewayResponsesRequestContext) throws -> CodexGatewayUpstreamRequest {
        guard let url = resolveUpstreamURL(for: context.path) else {
            throw Abort(.badGateway, reason: "Invalid upstream request URL.")
        }

        var headers = context.requestHeaders
        headers["Content-Type"] = "application/json"
        if headers["Accept"] == nil && headers["accept"] == nil {
            headers["Accept"] = bodyIndicatesStream(context.body) ? "text/event-stream" : "application/json"
        }
        for (name, value) in upstreamHeaders {
            headers[name] = value
        }
        if let sessionID = context.sessionID {
            headers["session_id"] = sessionID
        }
        if let conversationID = context.conversationID {
            headers["conversation_id"] = conversationID
        }

        return CodexGatewayUpstreamRequest(
            url: url,
            method: .POST,
            headers: headers,
            body: Data(context.body.utf8)
        )
    }

    private func resolveUpstreamURL(for requestPath: String) -> URL? {
        let baseSegments = upstreamBaseURL.path
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        var requestSegments = requestPath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        if !baseSegments.isEmpty, requestSegments.first?.lowercased() == "v1" {
            let baseEndsWithV1 = baseSegments.last?.lowercased() == "v1"
            if baseEndsWithV1 || requestSegments.count > 1 {
                requestSegments.removeFirst()
            }
        }

        let finalSegments: [String]
        if baseSegments.isEmpty {
            finalSegments = requestSegments
        } else {
            finalSegments = baseSegments + requestSegments
        }

        var components = URLComponents(url: upstreamBaseURL, resolvingAgainstBaseURL: false)
        components?.path = "/" + finalSegments.joined(separator: "/")
        return components?.url
    }

    private func resolveContentType(header: String?) -> HTTPMediaType {
        guard let header else { return .json }
        let lowercased = header.lowercased()
        if lowercased.contains("text/event-stream") {
            return HTTPMediaType(type: "text", subType: "event-stream")
        }
        if lowercased.contains("application/json") {
            return .json
        }
        if lowercased.contains("application/x-ndjson") {
            return HTTPMediaType(type: "application", subType: "x-ndjson")
        }
        if lowercased.contains("text/plain") {
            return .plainText
        }
        return .plainText
    }

    private func bodyIndicatesStream(_ body: String) -> Bool {
        guard let data = body.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any],
              let stream = root["stream"] as? Bool else {
            return false
        }
        return stream
    }

    private func validateStreamResponse(_ response: CodexGatewayUpstreamResponse) throws {
        let contentType = response.contentTypeHeader?.lowercased() ?? ""
        let body = String(decoding: response.body, as: UTF8.self)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        // ChatGPT auth expires may silently return HTML login page with 200 status.
        if contentType.contains("text/html") || trimmedBody.hasPrefix("<!doctype html") || trimmedBody.hasPrefix("<html") {
            throw Abort(.badGateway, reason: "Upstream returned HTML page instead of SSE stream.")
        }

        let appearsToBeSSE = contentType.contains("text/event-stream") || body.contains("event:")
        guard appearsToBeSSE else {
            throw Abort(.badGateway, reason: "Upstream stream protocol mismatch: expected SSE payload.")
        }

        guard body.contains("response.completed") else {
            throw Abort(.badGateway, reason: "Upstream stream ended before response.completed.")
        }
    }
}
