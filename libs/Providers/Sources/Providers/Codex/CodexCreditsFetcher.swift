import Foundation

// MARK: - Credits Helper

/// Main helper for fetching Codex credits with fallback strategies
public actor CodexCreditsFetcher {
    private let codexBinary: String?
    private let environment: [String: String]

    public init(
        codexBinary: String? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.codexBinary = codexBinary
        self.environment = environment
    }

    /// Fetch credits using RPC (primary) with TTY fallback
    public func fetchCredits(keepCLISessionsAlive: Bool = false) async throws -> CreditsSnapshot {
        try await withFallback(
            primary: { try await self.fetchRPCCredits() },
            secondary: { try await self.fetchTTYCredits(keepCLISessionsAlive: keepCLISessionsAlive) }
        )
    }

    /// Fetch credits via Codex RPC interface
    private func fetchRPCCredits() async throws -> CreditsSnapshot {
        let limits = try await CodexRuntimeSupport.withRuntimeService(
            preferredBinary: self.codexBinary,
            environment: self.environment
        ) { service in
            try await service.readRateLimits()
        }

        guard let credits = limits.credits else {
            throw CreditsFetchError.parseFailed("No credits field in rate limits")
        }

        if credits.unlimited {
            return CreditsSnapshot(remaining: .infinity, events: [], updatedAt: Date())
        }
        if let balance = credits.balance {
            let remaining = Self.parseCredits(balance)
            return CreditsSnapshot(remaining: remaining, events: [], updatedAt: Date())
        }
        
        // Codex RPC sometimes omits the balance field (credits unavailable yet). Preserve this as "unknown"
        // rather than failing the whole fetch.
        return CreditsSnapshot(remaining: .nan, events: [], updatedAt: Date())
    }

    /// Fetch credits via TTY status probe
    private func fetchTTYCredits(keepCLISessionsAlive: Bool) async throws -> CreditsSnapshot {
        let probe = CodexStatusProbe(
            codexBinary: CodexRuntimeSupport.resolvedBinary(
                preferredBinary: self.codexBinary,
                environment: self.environment
            ),
            keepCLISessionsAlive: keepCLISessionsAlive,
            environment: self.environment
        )

        let status = try await probe.fetch()

        guard let credits = status.credits else {
            throw CreditsFetchError.parseFailed("No credits found in status")
        }

        return CreditsSnapshot(remaining: credits, events: [], updatedAt: Date())
    }

    /// Fallback helper: try primary, on failure try secondary
    private func withFallback<T>(
        primary: @escaping () async throws -> T,
        secondary: @escaping () async throws -> T
    ) async throws -> T {
        do {
            return try await primary()
        } catch let primaryError {
            do {
                return try await secondary()
            } catch {
                // Preserve original failure
                throw primaryError
            }
        }
    }

    /// Parse credit balance from various formats
    private static func parseCredits(_ balance: String) -> Double {
        // Remove currency symbols and formatting
        let cleaned = balance
            .replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
            .replacingOccurrences(of: " ", with: "")

        return Double(cleaned) ?? 0.0
    }
}
