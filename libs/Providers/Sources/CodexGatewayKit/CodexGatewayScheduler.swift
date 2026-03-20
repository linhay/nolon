import Foundation
import Vapor

public actor CodexGatewayStickySessionStore {
    private var bindings: [String: UUID] = [:]

    public init() {}

    public func loadAccountID(for key: String) -> UUID? {
        bindings[key]
    }

    public func bind(accountID: UUID, for key: String) {
        bindings[key] = accountID
    }

    public func removeAccountID(for key: String) {
        bindings.removeValue(forKey: key)
    }
}

public struct CodexGatewayCandidate: Sendable, Equatable {
    public let accountID: UUID
    public let priority: Int
    public let concurrencyLimit: Int
    public let inFlightCount: Int
    public let lastSelectedAt: Date?
    public let isSchedulable: Bool
    public let upstreamBaseURL: URL?
    public let upstreamHeaders: [String: String]

    public init(
        accountID: UUID,
        priority: Int,
        concurrencyLimit: Int,
        inFlightCount: Int,
        lastSelectedAt: Date?,
        isSchedulable: Bool,
        upstreamBaseURL: URL? = nil,
        upstreamHeaders: [String: String] = [:]
    ) {
        self.accountID = accountID
        self.priority = priority
        self.concurrencyLimit = concurrencyLimit
        self.inFlightCount = inFlightCount
        self.lastSelectedAt = lastSelectedAt
        self.isSchedulable = isSchedulable
        self.upstreamBaseURL = upstreamBaseURL
        self.upstreamHeaders = upstreamHeaders
    }

    public var hasAvailableCapacity: Bool {
        inFlightCount < concurrencyLimit
    }
}

public enum CodexGatewaySchedulerDecision: Sendable, Equatable {
    case selected(CodexGatewayCandidate)
    case noCandidate
}

public struct CodexGatewayScheduler: Sendable {
    public init() {}

    public func selectAccount(from candidates: [CodexGatewayCandidate]) -> CodexGatewaySchedulerDecision {
        let filtered = candidates
            .filter(\.isSchedulable)
            .filter(\.hasAvailableCapacity)
            .sorted(by: compareCandidates)

        guard let selected = filtered.first else {
            return .noCandidate
        }
        return .selected(selected)
    }

    private func compareCandidates(_ lhs: CodexGatewayCandidate, _ rhs: CodexGatewayCandidate) -> Bool {
        if lhs.priority != rhs.priority {
            return lhs.priority < rhs.priority
        }
        if lhs.inFlightCount != rhs.inFlightCount {
            return lhs.inFlightCount < rhs.inFlightCount
        }

        switch (lhs.lastSelectedAt, rhs.lastSelectedAt) {
        case let (lhsDate?, rhsDate?) where lhsDate != rhsDate:
            return lhsDate < rhsDate
        case (nil, .some):
            return true
        case (.some, nil):
            return false
        default:
            return lhs.accountID.uuidString < rhs.accountID.uuidString
        }
    }
}

public struct CodexGatewayResponsesRoutingService: Sendable {
    public typealias CandidateProvider = @Sendable () async throws -> [CodexGatewayCandidate]

    private let candidates: CandidateProvider
    private let scheduler: CodexGatewayScheduler
    private let transport: any CodexGatewayUpstreamTransporting
    private let stickyStore: CodexGatewayStickySessionStore

    public init(
        candidates: @escaping CandidateProvider,
        scheduler: CodexGatewayScheduler = CodexGatewayScheduler(),
        stickyStore: CodexGatewayStickySessionStore = CodexGatewayStickySessionStore(),
        transport: any CodexGatewayUpstreamTransporting = CodexGatewayURLSessionTransport()
    ) {
        self.candidates = candidates
        self.scheduler = scheduler
        self.stickyStore = stickyStore
        self.transport = transport
    }

    public init(
        accountSource: CodexGatewayAccountSource,
        scheduler: CodexGatewayScheduler = CodexGatewayScheduler(),
        stickyStore: CodexGatewayStickySessionStore = CodexGatewayStickySessionStore(),
        transport: any CodexGatewayUpstreamTransporting = CodexGatewayURLSessionTransport()
    ) {
        self.init(
            candidates: {
                try await accountSource.loadCandidates()
            },
            scheduler: scheduler,
            stickyStore: stickyStore,
            transport: transport
        )
    }

    public func makeHandler() -> CodexGatewayServer.ResponsesHandler {
        { context in
            try await handle(context)
        }
    }

    public func handle(_ context: CodexGatewayResponsesRequestContext) async throws -> CodexGatewayResponsesResult {
        let availableCandidates = try await candidates()
        let stickyKey = extractStickyKey(from: context)
        var remainingCandidates = availableCandidates
        var lastFailureReason: String?

        if let stickyCandidate = await resolveStickyCandidate(
            from: remainingCandidates,
            stickyKey: stickyKey
        ) {
            let stickyResult = try await attemptForward(
                candidate: stickyCandidate,
                context: context,
                stickyKey: stickyKey
            )
            switch stickyResult {
            case let .completed(result):
                return result
            case let .retry(reason):
                lastFailureReason = reason
                remainingCandidates.removeAll { $0.accountID == stickyCandidate.accountID }
            }
        }

        while true {
            let decision = scheduler.selectAccount(from: remainingCandidates)
            guard case let .selected(candidate) = decision,
                  candidate.upstreamBaseURL != nil else {
                if let stickyKey {
                    await stickyStore.removeAccountID(for: stickyKey)
                }
                return makeNoSchedulableResult(reason: lastFailureReason)
            }

            switch try await attemptForward(
                candidate: candidate,
                context: context,
                stickyKey: stickyKey
            ) {
            case let .completed(result):
                return result
            case let .retry(reason):
                lastFailureReason = reason
                remainingCandidates.removeAll { $0.accountID == candidate.accountID }
                if remainingCandidates.isEmpty {
                    return makeNoSchedulableResult(reason: lastFailureReason)
                }
            }
        }
    }

    private func extractStickyKey(from context: CodexGatewayResponsesRequestContext) -> String? {
        context.sessionID ?? context.conversationID
    }

    private func resolveStickyCandidate(
        from candidates: [CodexGatewayCandidate],
        stickyKey: String?
    ) async -> CodexGatewayCandidate? {
        guard let stickyKey,
              let stickyAccountID = await stickyStore.loadAccountID(for: stickyKey),
              let stickyCandidate = candidates.first(where: { $0.accountID == stickyAccountID && $0.isSchedulable && $0.hasAvailableCapacity })
        else {
            return nil
        }
        return stickyCandidate
    }

    private func isFailoverable(status: HTTPResponseStatus) -> Bool {
        status == .tooManyRequests ||
            status == .unauthorized ||
            status == .forbidden ||
            status.code >= 500
    }

    private func attemptForward(
        candidate: CodexGatewayCandidate,
        context: CodexGatewayResponsesRequestContext,
        stickyKey: String?
    ) async throws -> AttemptResult {
        guard let upstreamBaseURL = candidate.upstreamBaseURL else {
            if let stickyKey {
                await stickyStore.removeAccountID(for: stickyKey)
            }
            return .retry(reason: "Candidate has no upstream base URL.")
        }

        let forwarder = CodexGatewayResponsesForwarder(
            upstreamBaseURL: upstreamBaseURL,
            upstreamHeaders: candidate.upstreamHeaders,
            transport: transport
        )

        do {
            let result = try await forwarder.forward(context)
            if isFailoverable(status: result.status) {
                if let stickyKey {
                    await stickyStore.removeAccountID(for: stickyKey)
                }
                return .retry(reason: "Upstream returned failoverable status \(result.status.code).")
            }
            if let stickyKey, result.status.code < 400 {
                await stickyStore.bind(accountID: candidate.accountID, for: stickyKey)
            }
            return .completed(result)
        } catch {
            if let stickyKey {
                await stickyStore.removeAccountID(for: stickyKey)
            }
            return .retry(reason: error.localizedDescription)
        }
    }

    private func makeNoSchedulableResult(reason: String?) -> CodexGatewayResponsesResult {
        let message: String
        if let reason, !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            message = "Codex gateway has no schedulable upstream account. Last failure: \(reason)"
        } else {
            message = "Codex gateway has no schedulable upstream account."
        }
        let escapedMessage = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return CodexGatewayResponsesResult(
            status: .serviceUnavailable,
            body: #"{"error":{"message":"\#(escapedMessage)"}}"#
        )
    }
}

private enum AttemptResult {
    case completed(CodexGatewayResponsesResult)
    case retry(reason: String?)
}
