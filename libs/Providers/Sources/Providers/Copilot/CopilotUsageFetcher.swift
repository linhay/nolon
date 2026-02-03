import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Fetches Copilot usage information from GitHub API
public struct CopilotUsageFetcher: Sendable {
    private let token: String
    private let session: URLSession
    
    /// Initialize with a GitHub token
    /// - Parameter token: GitHub OAuth token (not Copilot token)
    public init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }
    
    /// Fetch Copilot usage from GitHub API
    /// - Returns: Copilot usage snapshot
    public func fetch() async throws -> CopilotUsageSnapshot {
        guard let url = URL(string: "https://api.github.com/copilot_internal/user") else {
            throw CopilotUsageError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.setValue("token \(self.token)", forHTTPHeaderField: "Authorization")
        self.addCommonHeaders(to: &request)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw CopilotUsageError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200:
            break
        case 401, 403:
            throw CopilotUsageError.unauthorized
        case let code where code >= 400:
            let message = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw CopilotUsageError.apiError(code, message)
        default:
            throw CopilotUsageError.invalidResponse
        }
        
        let usageResponse: CopilotUsageResponse
        do {
            usageResponse = try JSONDecoder().decode(CopilotUsageResponse.self, from: data)
        } catch {
            throw CopilotUsageError.decodingError(error.localizedDescription)
        }
        
        let premiumQuota = usageResponse.quotaSnapshots.premiumInteractions.map {
            CopilotQuota(
                feature: "premium_interactions",
                total: $0.entitlement,
                remaining: $0.remaining,
                percentRemaining: $0.percentRemaining
            )
        }
        
        let chatQuota = usageResponse.quotaSnapshots.chat.map {
            CopilotQuota(
                feature: "chat",
                total: $0.entitlement,
                remaining: $0.remaining,
                percentRemaining: $0.percentRemaining
            )
        }
        
        return CopilotUsageSnapshot(
            plan: usageResponse.copilotPlan,
            premiumQuota: premiumQuota,
            chatQuota: chatQuota,
            quotaResetDate: usageResponse.quotaResetDate
        )
    }
    
    private func addCommonHeaders(to request: inout URLRequest) {
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("vscode/1.96.2", forHTTPHeaderField: "Editor-Version")
        request.setValue("copilot-chat/0.26.7", forHTTPHeaderField: "Editor-Plugin-Version")
        request.setValue("GitHubCopilotChat/0.26.7", forHTTPHeaderField: "User-Agent")
        request.setValue("2025-04-01", forHTTPHeaderField: "X-Github-Api-Version")
    }
}

// MARK: - Convenience Helper

/// Main helper for fetching Copilot usage
public actor CopilotHelper {
    private nonisolated let token: String?
    private nonisolated let environment: [String: String]
    
    /// Initialize CopilotHelper
    /// - Parameters:
    ///   - token: GitHub OAuth token. If nil, will try to read from environment
    ///   - environment: Environment variables to check for token
    public init(
        token: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.token = token
        self.environment = environment
    }
    
    /// Get token from environment or provided value
    private nonisolated func resolveToken() -> String? {
        if let provided = self.token {
            return provided
        }
        return self.environment["COPILOT_API_TOKEN"]
    }
    
    /// Fetch Copilot usage
    /// - Returns: Copilot usage snapshot
    /// - Throws: CopilotUsageError if token is missing or API call fails
    public func fetchUsage() async throws -> CopilotUsageSnapshot {
        guard let token = self.resolveToken() else {
            throw CopilotUsageError.invalidToken
        }
        
        let fetcher = CopilotUsageFetcher(token: token)
        return try await fetcher.fetch()
    }
    
    /// Check if token is available
    public nonisolated var isAuthenticated: Bool {
        self.resolveToken() != nil
    }
    
    /// Get the resolved token (for debugging, be careful with this)
    public nonisolated var currentToken: String? {
        self.resolveToken()
    }
}
