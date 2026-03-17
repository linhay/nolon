import Testing
import Vapor
import XCTVapor
import STFilePath
import ProviderUsage
@testable import CodexGatewayKit

@Suite("CodexGatewayKit")
struct CodexGatewayKitTests {
    @Test("Given Vapor gateway routes are registered, when probing healthz, then returns ok payload")
    func healthRouteReturnsOK() throws {
        let app = try makeApplication()
        defer { app.shutdown() }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "healthz") { response in
                #expect(response.status == .ok)
                let payload = try response.content.decode(CodexGatewayHealthResponse.self)
                #expect(payload.status == "ok")
            }
        }
    }

    @Test("Given Vapor gateway routes are registered, when requesting gateway status, then returns current snapshot")
    func statusRouteReturnsSnapshot() throws {
        let snapshot = CodexGatewayStatusSnapshot(
            status: .running,
            host: "127.0.0.1",
            port: 8080,
            startedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
        let app = try makeApplication(snapshot: snapshot)
        defer { app.shutdown() }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.GET, "gateway/status") { response in
                #expect(response.status == .ok)
                let payload = try response.content.decode(CodexGatewayStatusSnapshot.self)
                #expect(payload == snapshot)
            }
        }
    }

    @Test("Given responses handler is configured, when posting v1 responses, then request is forwarded to handler and returns JSON response")
    func responsesRouteForwardsRequestToHandler() throws {
        let expectedRequest = CodexGatewayResponsesRequestContext(
            path: "/v1/responses",
            body: #"{"input":"hello"}"#,
            sessionID: "session-1",
            conversationID: "conversation-1"
        )
        let app = try makeApplication { context in
            #expect(context == expectedRequest)
            return CodexGatewayResponsesResult(
                status: .ok,
                body: #"{"id":"resp_123","status":"completed"}"#
            )
        }
        defer { app.shutdown() }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "v1/responses", beforeRequest: { request in
                try request.content.encode(["input": "hello"], as: .json)
                request.headers.replaceOrAdd(name: "session_id", value: "session-1")
                request.headers.replaceOrAdd(name: "conversation_id", value: "conversation-1")
            }, afterResponse: { response in
                #expect(response.status == .ok)
                #expect(response.headers.contentType == .json)
                #expect(response.body.string == #"{"id":"resp_123","status":"completed"}"#)
            })
        }
    }

    @Test("Given responses handler is configured, when posting responses alias, then alias route returns handler response")
    func responsesAliasRouteReturnsHandlerResponse() throws {
        let app = try makeApplication { context in
            #expect(context.path == "/responses")
            return CodexGatewayResponsesResult(
                status: .accepted,
                body: #"{"id":"resp_alias","status":"queued"}"#
            )
        }
        defer { app.shutdown() }

        try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
            try app.test(.POST, "responses", beforeRequest: { request in
                try request.content.encode(["input": "hello"], as: .json)
            }, afterResponse: { response in
                #expect(response.status == .accepted)
                #expect(response.body.string == #"{"id":"resp_alias","status":"queued"}"#)
            })
        }
    }

    @Test("Given responses forwarder, when forwarding request context, then upstream request preserves path body and sticky headers")
    func responsesForwarderBuildsUpstreamRequest() async throws {
        let transport = RecordingUpstreamTransport(
            response: CodexGatewayUpstreamResponse(
                status: .ok,
                body: Data(#"{"id":"resp_forwarded","status":"completed"}"#.utf8),
                contentTypeHeader: "application/json"
            )
        )
        let forwarder = CodexGatewayResponsesForwarder(
            upstreamBaseURL: URL(string: "https://gateway.example.com")!,
            transport: transport
        )

        let result = try await forwarder.forward(
            CodexGatewayResponsesRequestContext(
                path: "/v1/responses",
                body: #"{"input":"hello"}"#,
                sessionID: "session-1",
                conversationID: "conversation-1"
            )
        )
        let recorded = await transport.lastRequest()

        #expect(recorded?.url.absoluteString == "https://gateway.example.com/v1/responses")
        #expect(recorded?.method == .POST)
        #expect(recorded?.headers["Content-Type"] == "application/json")
        #expect(recorded?.headers["session_id"] == "session-1")
        #expect(recorded?.headers["conversation_id"] == "conversation-1")
        #expect(String(decoding: recorded?.body ?? Data(), as: UTF8.self) == #"{"input":"hello"}"#)
        #expect(result.status == .ok)
        #expect(result.body == #"{"id":"resp_forwarded","status":"completed"}"#)
        #expect(result.contentType == .json)
    }

    @Test("Given upstream base URL already ends with v1, when forwarding v1 responses path, then path is normalized and auth headers are injected")
    func responsesForwarderNormalizesV1PathAndInjectsHeaders() async throws {
        let transport = RecordingUpstreamTransport(
            response: CodexGatewayUpstreamResponse(
                status: .ok,
                body: Data(#"{"id":"resp_forwarded"}"#.utf8),
                contentTypeHeader: "application/json"
            )
        )
        let forwarder = CodexGatewayResponsesForwarder(
            upstreamBaseURL: URL(string: "https://gateway.example.com/v1")!,
            upstreamHeaders: [
                "Authorization": "Bearer test-token",
                "ChatGPT-Account-ID": "acct_123"
            ],
            transport: transport
        )

        _ = try await forwarder.forward(
            CodexGatewayResponsesRequestContext(
                path: "/v1/responses",
                body: #"{"input":"hello"}"#,
                sessionID: nil,
                conversationID: nil
            )
        )
        let recorded = await transport.lastRequest()

        #expect(recorded?.url.absoluteString == "https://gateway.example.com/responses")
        #expect(recorded?.headers["Authorization"] == "Bearer test-token")
        #expect(recorded?.headers["ChatGPT-Account-ID"] == "acct_123")
    }

    @Test("Given configured API key and relay accounts, when loading gateway candidates, then upstream targets and auth headers are resolved from auth source")
    func accountSourceLoadsConfiguredCandidates() async throws {
        let root = try makeTempRoot("codex-gateway-account-source-configured")
        defer { try? root.delete() }

        let authManager = CodexAuthManager(rootURL: root.url)
        _ = try await authManager.addConfiguredAccount(
            name: "Direct",
            apiKey: "sk-direct",
            relay: nil
        )
        _ = try await authManager.addConfiguredAccount(
            name: "Relay",
            apiKey: "sk-relay",
            relay: CodexAuthManager.ConfiguredRelay(
                baseURL: "https://relay.example.com/v1",
                modelProvider: "relay-openai",
                headers: ["X-Relay-Key": "relay-secret"]
            )
        )
        let source = CodexGatewayAccountSource(authManager: authManager)

        let candidates = try await source.loadCandidates()
        let direct = try #require(candidates.first(where: { $0.upstreamBaseURL?.host == "api.openai.com" }))
        let relay = try #require(candidates.first(where: { $0.upstreamBaseURL?.host == "relay.example.com" }))

        #expect(direct.isSchedulable)
        #expect(direct.upstreamHeaders["Authorization"] == "Bearer sk-direct")
        #expect(relay.isSchedulable)
        #expect(relay.upstreamHeaders["Authorization"] == "Bearer sk-relay")
        #expect(relay.upstreamHeaders["X-Relay-Key"] == "relay-secret")
    }

    @Test("Given gateway virtual reply account marker, when loading gateway candidates, then virtual account is not schedulable")
    func accountSourceSkipsGatewayVirtualReplyCandidate() async throws {
        let root = try makeTempRoot("codex-gateway-account-source-virtual")
        defer { try? root.delete() }

        let authManager = CodexAuthManager(rootURL: root.url)
        _ = try await authManager.addConfiguredAccount(
            name: "Direct",
            apiKey: "sk-direct",
            relay: nil
        )
        _ = try await authManager.addConfiguredAccount(
            name: "Virtual",
            apiKey: "nolon-gateway-virtual-api-key",
            relay: CodexAuthManager.ConfiguredRelay(
                baseURL: "http://127.0.0.1:18086",
                modelProvider: "openai",
                queryParams: [
                    "nolon_gateway_virtual": "1",
                    "provider_id": "codex",
                ]
            )
        )

        let source = CodexGatewayAccountSource(authManager: authManager)
        let candidates = try await source.loadCandidates()

        let direct = try #require(candidates.first(where: { $0.upstreamBaseURL?.host == "api.openai.com" }))
        let virtual = try #require(candidates.first(where: { $0.upstreamBaseURL == nil }))

        #expect(direct.isSchedulable == true)
        #expect(virtual.isSchedulable == false)
    }

    @Test("Given chatgpt auth account, when loading gateway candidates, then candidate uses chatgpt codex backend and account header")
    func accountSourceLoadsChatGPTCandidate() async throws {
        let root = try makeTempRoot("codex-gateway-account-source-chatgpt")
        defer { try? root.delete() }

        let authManager = CodexAuthManager(rootURL: root.url)
        _ = try await authManager.addAccount(
            name: "ChatGPT",
            authJSONString: """
            {
              "auth_mode": "chatgptAuthTokens",
              "email": "coder@example.com",
              "tokens": {
                "id_token": "header.eyJodHRwczovL2FwaS5vcGVuYWkuY29tL2F1dGgiOnsiY2hhdGdwdF9hY2NvdW50X2lkIjoiYWNjdF9jaGF0Z3B0In19.signature",
                "access_token": "chatgpt-token"
              }
            }
            """
        )
        let source = CodexGatewayAccountSource(authManager: authManager)

        let candidates = try await source.loadCandidates()
        let candidate = try #require(candidates.first)

        #expect(candidate.isSchedulable)
        #expect(candidate.upstreamBaseURL?.absoluteString == "https://chatgpt.com/backend-api/codex")
        #expect(candidate.upstreamHeaders["Authorization"] == "Bearer chatgpt-token")
        #expect(candidate.upstreamHeaders["ChatGPT-Account-ID"] == "acct_chatgpt")
    }

    @Test("Given live account source, when routing responses request, then handler uses real account candidates without custom candidate closure")
    func routingServiceUsesLiveAccountSource() async throws {
        let root = try makeTempRoot("codex-gateway-live-routing")
        defer { try? root.delete() }

        let authManager = CodexAuthManager(rootURL: root.url)
        _ = try await authManager.addConfiguredAccount(
            name: "Direct",
            apiKey: "sk-direct",
            relay: nil
        )
        let transport = RecordingUpstreamTransport(
            response: CodexGatewayUpstreamResponse(
                status: .ok,
                body: Data(#"{"id":"resp_live"}"#.utf8),
                contentTypeHeader: "application/json"
            )
        )
        let accountSource = CodexGatewayAccountSource(authManager: authManager)
        let service = CodexGatewayResponsesRoutingService(
            accountSource: accountSource,
            transport: transport
        )

        let result = try await service.handle(
            CodexGatewayResponsesRequestContext(
                path: "/v1/responses",
                body: #"{"input":"hello"}"#,
                sessionID: nil,
                conversationID: nil
            )
        )
        let recorded = await transport.lastRequest()

        #expect(recorded?.url.absoluteString == "https://api.openai.com/v1/responses")
        #expect(recorded?.headers["Authorization"] == "Bearer sk-direct")
        #expect(result.status == .ok)
        #expect(result.body == #"{"id":"resp_live"}"#)
    }

    @Test("Given control service starts gateway, when loading state, then persisted snapshot is running")
    func controlServiceStartPersistsSnapshot() async throws {
        let root = try makeTempRoot("codex-gateway-kit-start")
        defer { try? root.delete() }

        let store = CodexGatewayStateStore(file: root.file("state.json"))
        let service = CodexGatewayControlService(
            statusStore: store,
            now: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        let started = try await service.start(config: CodexGatewayConfig(host: "127.0.0.1", port: 9090))
        let loaded = await store.load()

        #expect(started.status == .running)
        #expect(loaded == started)
    }

    @Test("Given control service stops gateway, when loading state, then persisted snapshot is stopped and keeps endpoint")
    func controlServiceStopPersistsSnapshot() async throws {
        let root = try makeTempRoot("codex-gateway-kit-stop")
        defer { try? root.delete() }

        let store = CodexGatewayStateStore(file: root.file("state.json"))
        try await store.save(
            CodexGatewayStatusSnapshot(
                status: .running,
                host: "127.0.0.1",
                port: 9090,
                startedAt: Date(timeIntervalSince1970: 1_700_000_000)
            )
        )
        let service = CodexGatewayControlService(statusStore: store)

        let stopped = try await service.stop()
        let loaded = await store.load()

        #expect(stopped.status == .stopped)
        #expect(stopped.port == 9090)
        #expect(stopped.startedAt == nil)
        #expect(loaded == stopped)
    }

    @Test("Given existing config with unrelated sections, when patching and restoring gateway config, then only controlled keys change")
    func configManagerPatchAndRestoreControlledKeys() async throws {
        let root = try makeTempRoot("codex-gateway-config-patch")
        defer { try? root.delete() }

        let configFile = root.file("config.toml")
        try configFile.overlay(
            with: """
            model = "gpt-5"
            base_url = "https://api.openai.com/v1"
            model_provider = "custom"
            cli_auth_credentials_store = "keyring"

            [profiles.default]
            model = "gpt-5"
            """
        )
        let manager = CodexGatewayConfigManager(
            stateStore: CodexGatewayManagedConfigStateStore(file: root.file("gateway-config.json"))
        )

        try await manager.patchGatewayConfig(configFile: configFile, config: CodexGatewayConfig(host: "127.0.0.1", port: 8088))
        let patched = try configFile.read()
        #expect(patched.contains(#"base_url = "http://127.0.0.1:8088""#))
        #expect(patched.contains(#"model_provider = "openai""#))
        #expect(patched.contains(#"cli_auth_credentials_store = "file""#))
        #expect(patched.contains(#"[profiles.default]"#))
        #expect(patched.contains(#"model = "gpt-5""#))

        try await manager.restoreGatewayConfig(configFile: configFile)
        let restored = try configFile.read()
        #expect(restored.contains(#"base_url = "https://api.openai.com/v1""#))
        #expect(restored.contains(#"model_provider = "custom""#))
        #expect(restored.contains(#"cli_auth_credentials_store = "keyring""#))
        #expect(restored.contains(#"[profiles.default]"#))
    }

    @Test("Given config file created by patch only, when restoring, then generated config file is removed")
    func configManagerRestoreRemovesGeneratedConfigFile() async throws {
        let root = try makeTempRoot("codex-gateway-config-remove")
        defer { try? root.delete() }

        let configFile = root.file("config.toml")
        let manager = CodexGatewayConfigManager(
            stateStore: CodexGatewayManagedConfigStateStore(file: root.file("gateway-config.json"))
        )

        try await manager.patchGatewayConfig(configFile: configFile, config: CodexGatewayConfig(host: "127.0.0.1", port: 8089))
        #expect(configFile.isExists)

        try await manager.restoreGatewayConfig(configFile: configFile)
        #expect(configFile.isExists == false)
    }

    private func makeApplication(
        snapshot: CodexGatewayStatusSnapshot = CodexGatewayStatusSnapshot(
            status: .stopped,
            host: "127.0.0.1",
            port: 8080,
            startedAt: nil
        ),
        responsesHandler: @escaping CodexGatewayServer.ResponsesHandler = { _ in
            CodexGatewayResponsesResult(
                status: .notImplemented,
                body: #"{"error":{"message":"Codex gateway responses forwarding is not configured."}}"#
            )
        }
    ) throws -> Application {
        let app = Application(.testing)
        try CodexGatewayServer.configure(
            app: app,
            statusProvider: { snapshot },
            responsesHandler: responsesHandler
        )
        return app
    }

    private func makeTempRoot(_ prefix: String) throws -> STFolder {
        let path = NSTemporaryDirectory().appending(prefix).appending("-").appending(UUID().uuidString)
        let folder = STFolder(path)
        _ = folder.createIfNotExists()
        return folder
    }
}

private actor RecordingUpstreamTransport: CodexGatewayUpstreamTransporting {
    private var request: CodexGatewayUpstreamRequest?
    private let response: CodexGatewayUpstreamResponse

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
