import Foundation
import Testing
@testable import CodexGatewayKit

@Suite("CodexGatewayScheduler")
struct CodexGatewaySchedulerTests {
    @Test("Given no schedulable candidates, when selecting account, then returns noCandidate")
    func returnsNoCandidateWhenAllCandidatesAreUnschedulable() {
        let scheduler = CodexGatewayScheduler()

        let decision = scheduler.selectAccount(
            from: [
                makeCandidate(isSchedulable: false),
                makeCandidate(inFlightCount: 1, isSchedulable: false)
            ]
        )

        #expect(decision == .noCandidate)
    }

    @Test("Given candidate is saturated, when selecting account, then saturated candidate is filtered out")
    func filtersOutSaturatedCandidates() {
        let scheduler = CodexGatewayScheduler()
        let available = makeCandidate(
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
            priority: 2,
            concurrencyLimit: 2,
            inFlightCount: 1
        )

        let decision = scheduler.selectAccount(
            from: [
                makeCandidate(concurrencyLimit: 1, inFlightCount: 1),
                available
            ]
        )

        #expect(decision == .selected(available))
    }

    @Test("Given different priorities, when selecting account, then lower priority value wins")
    func prefersLowerPriority() {
        let scheduler = CodexGatewayScheduler()
        let preferred = makeCandidate(
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
            priority: 1
        )
        let other = makeCandidate(
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
            priority: 3
        )

        let decision = scheduler.selectAccount(from: [other, preferred])

        #expect(decision == .selected(preferred))
    }

    @Test("Given same priority, when selecting account, then lower inflight count wins")
    func prefersLowerInflightCountOnSamePriority() {
        let scheduler = CodexGatewayScheduler()
        let preferred = makeCandidate(
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000005")!,
            priority: 1,
            inFlightCount: 0
        )
        let other = makeCandidate(
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000006")!,
            priority: 1,
            inFlightCount: 2
        )

        let decision = scheduler.selectAccount(from: [other, preferred])

        #expect(decision == .selected(preferred))
    }

    @Test("Given same priority and inflight count, when selecting account, then oldest lastSelectedAt wins")
    func prefersLeastRecentlyUsedCandidate() {
        let scheduler = CodexGatewayScheduler()
        let preferred = makeCandidate(
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000007")!,
            priority: 1,
            inFlightCount: 1,
            lastSelectedAt: Date(timeIntervalSince1970: 100)
        )
        let other = makeCandidate(
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000008")!,
            priority: 1,
            inFlightCount: 1,
            lastSelectedAt: Date(timeIntervalSince1970: 200)
        )

        let decision = scheduler.selectAccount(from: [other, preferred])

        #expect(decision == .selected(preferred))
    }

    @Test("Given equal metrics with nil lastSelectedAt, when selecting account, then stable accountID ordering breaks ties")
    func usesStableAccountIDTieBreaker() {
        let scheduler = CodexGatewayScheduler()
        let preferred = makeCandidate(
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000009")!,
            priority: 1,
            inFlightCount: 0,
            lastSelectedAt: nil
        )
        let other = makeCandidate(
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000010")!,
            priority: 1,
            inFlightCount: 0,
            lastSelectedAt: nil
        )

        let decision = scheduler.selectAccount(from: [other, preferred])

        #expect(decision == .selected(preferred))
    }

    @Test("Given schedulable upstream candidates, when handling responses request, then selected upstream receives forwarded request")
    func routingServiceForwardsToSelectedUpstream() async throws {
        let transport = RecordingGatewayTransport(
            response: CodexGatewayUpstreamResponse(
                status: .ok,
                body: Data(#"{"id":"resp_selected"}"#.utf8),
                contentTypeHeader: "application/json"
            )
        )
        let selectedCandidate = makeCandidate(
            accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000011")!,
            priority: 1,
            upstreamBaseURL: URL(string: "https://selected.example.com")!
        )
        let service = CodexGatewayResponsesRoutingService(
            candidates: {
                [
                    makeCandidate(
                        accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000012")!,
                        priority: 2,
                        upstreamBaseURL: URL(string: "https://other.example.com")!
                    ),
                    selectedCandidate
                ]
            },
            transport: transport
        )

        let result = try await service.handle(
            CodexGatewayResponsesRequestContext(
                path: "/v1/responses",
                body: #"{"input":"hello"}"#,
                sessionID: "session-1",
                conversationID: nil
            )
        )
        let request = await transport.lastRequest()

        #expect(request?.url.absoluteString == "https://selected.example.com/v1/responses")
        #expect(result.status == .ok)
        #expect(result.body == #"{"id":"resp_selected"}"#)
    }

    @Test("Given no schedulable upstream candidates, when handling responses request, then returns service unavailable error")
    func routingServiceReturnsServiceUnavailableWithoutRoutableCandidate() async throws {
        let service = CodexGatewayResponsesRoutingService(
            candidates: {
                [
                    makeCandidate(isSchedulable: false),
                    makeCandidate(
                        accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000013")!,
                        upstreamBaseURL: nil
                    )
                ]
            }
        )

        let result = try await service.handle(
            CodexGatewayResponsesRequestContext(
                path: "/v1/responses",
                body: #"{"input":"hello"}"#,
                sessionID: nil,
                conversationID: nil
            )
        )

        #expect(result.status == .serviceUnavailable)
        #expect(result.body.contains("no schedulable upstream account"))
    }

    @Test("Given sticky session already bound, when later request arrives, then routing service prefers the bound candidate over better ranked candidates")
    func routingServicePrefersStickyCandidate() async throws {
        let stickyStore = CodexGatewayStickySessionStore()
        let stickyAccountID = UUID(uuidString: "00000000-0000-0000-0000-000000000014")!
        await stickyStore.bind(accountID: stickyAccountID, for: "session-sticky")
        let transport = SequencedGatewayTransport(
            responsesByURL: [
                "https://sticky.example.com/v1/responses": [
                    .success(
                        CodexGatewayUpstreamResponse(
                            status: .ok,
                            body: Data(#"{"id":"resp_sticky"}"#.utf8),
                            contentTypeHeader: "application/json"
                        )
                    )
                ]
            ]
        )
        let service = CodexGatewayResponsesRoutingService(
            candidates: {
                [
                    makeCandidate(
                        accountID: stickyAccountID,
                        priority: 9,
                        upstreamBaseURL: URL(string: "https://sticky.example.com")!
                    ),
                    makeCandidate(
                        accountID: UUID(uuidString: "00000000-0000-0000-0000-000000000015")!,
                        priority: 1,
                        upstreamBaseURL: URL(string: "https://better.example.com")!
                    )
                ]
            },
            stickyStore: stickyStore,
            transport: transport
        )

        let result = try await service.handle(
            CodexGatewayResponsesRequestContext(
                path: "/v1/responses",
                body: #"{"input":"hello"}"#,
                sessionID: "session-sticky",
                conversationID: nil
            )
        )
        let requests = await transport.recordedRequests()

        #expect(requests.count == 1)
        #expect(requests.first?.url.absoluteString == "https://sticky.example.com/v1/responses")
        #expect(result.body == #"{"id":"resp_sticky"}"#)
    }

    @Test("Given selected upstream returns failoverable status, when another candidate exists, then routing service retries next candidate and rebinds sticky session")
    func routingServiceFailsOverAndRebindsStickySession() async throws {
        let stickyStore = CodexGatewayStickySessionStore()
        let firstAccountID = UUID(uuidString: "00000000-0000-0000-0000-000000000016")!
        let secondAccountID = UUID(uuidString: "00000000-0000-0000-0000-000000000017")!
        let transport = SequencedGatewayTransport(
            responsesByURL: [
                "https://first.example.com/v1/responses": [
                    .success(
                        CodexGatewayUpstreamResponse(
                            status: .internalServerError,
                            body: Data(#"{"error":"boom"}"#.utf8),
                            contentTypeHeader: "application/json"
                        )
                    )
                ],
                "https://second.example.com/v1/responses": [
                    .success(
                        CodexGatewayUpstreamResponse(
                            status: .ok,
                            body: Data(#"{"id":"resp_second"}"#.utf8),
                            contentTypeHeader: "application/json"
                        )
                    )
                ]
            ]
        )
        let service = CodexGatewayResponsesRoutingService(
            candidates: {
                [
                    makeCandidate(
                        accountID: firstAccountID,
                        priority: 1,
                        upstreamBaseURL: URL(string: "https://first.example.com")!
                    ),
                    makeCandidate(
                        accountID: secondAccountID,
                        priority: 2,
                        upstreamBaseURL: URL(string: "https://second.example.com")!
                    )
                ]
            },
            stickyStore: stickyStore,
            transport: transport
        )

        let result = try await service.handle(
            CodexGatewayResponsesRequestContext(
                path: "/v1/responses",
                body: #"{"input":"hello"}"#,
                sessionID: "session-failover",
                conversationID: nil
            )
        )
        let requests = await transport.recordedRequests()
        let rebound = await stickyStore.loadAccountID(for: "session-failover")

        #expect(requests.count == 2)
        #expect(requests[0].url.absoluteString == "https://first.example.com/v1/responses")
        #expect(requests[1].url.absoluteString == "https://second.example.com/v1/responses")
        #expect(result.status == .ok)
        #expect(result.body == #"{"id":"resp_second"}"#)
        #expect(rebound == secondAccountID)
    }

    private func makeCandidate(
        accountID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        priority: Int = 1,
        concurrencyLimit: Int = 4,
        inFlightCount: Int = 0,
        lastSelectedAt: Date? = Date(timeIntervalSince1970: 100),
        isSchedulable: Bool = true,
        upstreamBaseURL: URL? = URL(string: "https://gateway.example.com")
    ) -> CodexGatewayCandidate {
        CodexGatewayCandidate(
            accountID: accountID,
            priority: priority,
            concurrencyLimit: concurrencyLimit,
            inFlightCount: inFlightCount,
            lastSelectedAt: lastSelectedAt,
            isSchedulable: isSchedulable,
            upstreamBaseURL: upstreamBaseURL,
            upstreamHeaders: [:]
        )
    }
}

private actor RecordingGatewayTransport: CodexGatewayUpstreamTransporting {
    private let response: CodexGatewayUpstreamResponse
    private var request: CodexGatewayUpstreamRequest?

    init(response: CodexGatewayUpstreamResponse) {
        self.response = response
    }

    func execute(_ request: CodexGatewayUpstreamRequest) async throws -> CodexGatewayUpstreamResponse {
        self.request = request
        return response
    }

    func lastRequest() -> CodexGatewayUpstreamRequest? {
        request
    }
}

private actor SequencedGatewayTransport: CodexGatewayUpstreamTransporting {
    enum Step: Sendable {
        case success(CodexGatewayUpstreamResponse)
        case failure(any Error & Sendable)
    }

    private var responsesByURL: [String: [Step]]
    private var requests: [CodexGatewayUpstreamRequest] = []

    init(responsesByURL: [String: [Step]]) {
        self.responsesByURL = responsesByURL
    }

    func execute(_ request: CodexGatewayUpstreamRequest) async throws -> CodexGatewayUpstreamResponse {
        requests.append(request)
        guard var steps = responsesByURL[request.url.absoluteString], !steps.isEmpty else {
            throw TestTransportError.missingStub(request.url.absoluteString)
        }
        let step = steps.removeFirst()
        responsesByURL[request.url.absoluteString] = steps
        switch step {
        case let .success(response):
            return response
        case let .failure(error):
            throw error
        }
    }

    func recordedRequests() -> [CodexGatewayUpstreamRequest] {
        requests
    }
}

private enum TestTransportError: Error {
    case missingStub(String)
}
