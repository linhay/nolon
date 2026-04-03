import Foundation
import ProviderUsage

public actor CodexGatewayAccountSource {
    fileprivate static let gatewayVirtualMarkerKey = "nolon_gateway_virtual"
    fileprivate static let gatewayVirtualAPIKey = "nolon-gateway-virtual-api-key"
    private let authManager: CodexAuthManager
    private let openAIBaseURL: URL
    private let chatGPTBaseURL: URL

    public init(
        authManager: CodexAuthManager = CodexAuthManager(),
        openAIBaseURL: URL = URL(string: "https://api.openai.com")!,
        chatGPTBaseURL: URL = URL(string: "https://chatgpt.com/backend-api/codex")!
    ) {
        self.authManager = authManager
        self.openAIBaseURL = openAIBaseURL
        self.chatGPTBaseURL = chatGPTBaseURL
    }

    public func loadCandidates() async throws -> [CodexGatewayCandidate] {
        let accounts = try await authManager.loadAccounts()
        var candidates: [CodexGatewayCandidate] = []
        candidates.reserveCapacity(accounts.count)

        for account in accounts {
            let candidate = try await makeCandidate(for: account)
            candidates.append(candidate)
        }
        return candidates
    }

    private func makeCandidate(for account: CodexAuthAccount) async throws -> CodexGatewayCandidate {
        guard let data = authManager.accountAuthData(for: account), !data.isEmpty else {
            throw CocoaError(.fileNoSuchFile)
        }
        let summary = CodexAuthSummary.fromJSONData(data)
        let usageCache = try await authManager.loadUsageCache(for: account)
        let authPayload = try parseAuthPayload(from: data)
        let upstream = resolveUpstream(summary: summary, payload: authPayload)

        return CodexGatewayCandidate(
            accountID: account.id,
            priority: 10,
            concurrencyLimit: 1,
            inFlightCount: 0,
            lastSelectedAt: usageCache?.cachedAt,
            isSchedulable: upstream != nil,
            upstreamBaseURL: upstream?.baseURL,
            upstreamHeaders: upstream?.headers ?? [:]
        )
    }

    private func parseAuthPayload(from data: Data) throws -> AuthPayload {
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let root = jsonObject as? [String: Any] else {
            return AuthPayload()
        }

        let tokens = root["tokens"] as? [String: Any]
        let nolon = root["nolon"] as? [String: Any]
        let relay = nolon?["relay"] as? [String: Any]

        return AuthPayload(
            authMode: Self.stringValue(root["auth_mode"]),
            apiKey: Self.stringValue(root["OPENAI_API_KEY"]),
            accessToken: Self.stringValue(tokens?["access_token"]) ?? Self.stringValue(root["access_token"]),
            accountID: Self.stringValue(root["account_id"]),
            relayBaseURL: Self.stringValue(relay?["base_url"]) ?? Self.stringValue(root["base_url"]),
            relayQueryParams: Self.stringMap(relay?["query_params"]),
            relayHeaders: Self.stringMap(relay?["headers"])
        )
    }

    private func resolveUpstream(summary: CodexAuthSummary, payload: AuthPayload) -> UpstreamConfiguration? {
        if payload.isGatewayVirtual {
            return nil
        }
        if let baseURLString = payload.relayBaseURL,
           let baseURL = URL(string: baseURLString),
           let apiKey = payload.apiKey
        {
            var headers = payload.relayHeaders
            headers["Authorization"] = "Bearer \(apiKey)"
            return UpstreamConfiguration(baseURL: baseURL, headers: headers)
        }
        switch summary.cardKind {
        case .officialAPIKey:
            guard let apiKey = payload.apiKey else { return nil }
            return UpstreamConfiguration(
                baseURL: openAIBaseURL,
                headers: ["Authorization": "Bearer \(apiKey)"]
            )
        case .relayProfile:
            guard let baseURLString = payload.relayBaseURL,
                  let baseURL = URL(string: baseURLString),
                  let apiKey = payload.apiKey
            else {
                return nil
            }
            var headers = payload.relayHeaders
            headers["Authorization"] = "Bearer \(apiKey)"
            return UpstreamConfiguration(baseURL: baseURL, headers: headers)
        case .chatgptAccount:
            guard let accessToken = payload.accessToken else { return nil }
            var headers = ["Authorization": "Bearer \(accessToken)"]
            if let accountID = summary.accountID ?? payload.accountID {
                headers["ChatGPT-Account-ID"] = accountID
            }
            return UpstreamConfiguration(baseURL: chatGPTBaseURL, headers: headers)
        case nil:
            if let apiKey = payload.apiKey {
                return UpstreamConfiguration(
                    baseURL: openAIBaseURL,
                    headers: ["Authorization": "Bearer \(apiKey)"]
                )
            }
            if let accessToken = payload.accessToken {
                return UpstreamConfiguration(
                    baseURL: chatGPTBaseURL,
                    headers: ["Authorization": "Bearer \(accessToken)"]
                )
            }
            return nil
        }
    }

    private nonisolated static func stringValue(_ value: Any?) -> String? {
        guard let raw = value as? String else { return nil }
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private nonisolated static func stringMap(_ value: Any?) -> [String: String] {
        guard let raw = value as? [String: Any] else { return [:] }
        var result: [String: String] = [:]
        for (key, value) in raw {
            if let string = Self.stringValue(value) {
                result[key] = string
            }
        }
        return result
    }
}

private struct AuthPayload {
    var authMode: String?
    var apiKey: String?
    var accessToken: String?
    var accountID: String?
    var relayBaseURL: String?
    var relayQueryParams: [String: String] = [:]
    var relayHeaders: [String: String] = [:]

    var isGatewayVirtual: Bool {
        let marker = relayQueryParams[CodexGatewayAccountSource.gatewayVirtualMarkerKey]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if marker == "1" || marker == "true" {
            return true
        }
        guard let apiKey else { return false }
        return apiKey == CodexGatewayAccountSource.gatewayVirtualAPIKey
    }
}

private struct UpstreamConfiguration {
    let baseURL: URL
    let headers: [String: String]
}
