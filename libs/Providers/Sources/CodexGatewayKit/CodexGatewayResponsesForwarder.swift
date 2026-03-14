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
        let upstreamRequest = try buildRequest(for: context)
        let upstreamResponse = try await transport.execute(upstreamRequest)
        let contentType = resolveContentType(header: upstreamResponse.contentTypeHeader)
        return CodexGatewayResponsesResult(
            status: upstreamResponse.status,
            body: String(decoding: upstreamResponse.body, as: UTF8.self),
            contentType: contentType
        )
    }

    private func buildRequest(for context: CodexGatewayResponsesRequestContext) throws -> CodexGatewayUpstreamRequest {
        let resolvedPath = normalizedPath(for: context.path)
        guard let url = URL(string: resolvedPath, relativeTo: upstreamBaseURL)?.absoluteURL else {
            throw Abort(.badGateway, reason: "Invalid upstream request URL.")
        }

        var headers: [String: String] = [
            "Content-Type": "application/json"
        ]
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

    private func normalizedPath(for requestPath: String) -> String {
        let upstreamPath = upstreamBaseURL.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard upstreamPath == "v1", requestPath.hasPrefix("/v1/") else {
            return requestPath
        }
        return String(requestPath.dropFirst(3))
    }

    private func resolveContentType(header: String?) -> HTTPMediaType {
        guard let header else { return .json }
        let lowercased = header.lowercased()
        if lowercased.contains("application/json") {
            return .json
        }
        if lowercased.contains("text/plain") {
            return .plainText
        }
        return .plainText
    }
}
