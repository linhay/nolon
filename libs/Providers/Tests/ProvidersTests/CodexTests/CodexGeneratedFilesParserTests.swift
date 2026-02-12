import Foundation
import Testing
@testable import CodexProvider

@Suite("Codex Generated Files Parser")
struct CodexGeneratedFilesParserTests {
    @Test("Parse auth.json with JWT claims")
    func parseAuthJSON() throws {
        let jwt = Self.makeJWT(payload: """
        {
          "email": "user@example.com",
          "https://api.openai.com/auth": {
            "chatgpt_plan_type": "pro",
            "chatgpt_user_id": "user-123",
            "chatgpt_account_id": "org-456"
          }
        }
        """)

        let json = """
        {
          "auth_mode": "chatgpt",
          "OPENAI_API_KEY": null,
          "tokens": {
            "id_token": "\(jwt)",
            "access_token": "access-abc",
            "refresh_token": "refresh-def",
            "account_id": "org-456"
          },
          "last_refresh": "2026-02-11T12:00:00Z"
        }
        """

        let parsed = try CodexGeneratedFilesParser.parseAuth(jsonString: json)
        #expect(parsed.authMode == .chatgpt)
        #expect(parsed.tokens?.accessToken == "access-abc")
        #expect(parsed.tokens?.idTokenClaims?.email == "user@example.com")
        #expect(parsed.tokens?.idTokenClaims?.chatgptPlanType == "pro")
        #expect(parsed.tokens?.idTokenClaims?.chatgptAccountID == "org-456")
    }

    @Test("Parse rollout session_meta and token_count event")
    func parseRolloutLines() throws {
        let sessionLine = """
        {
          "timestamp": "2026-02-11T12:00:00Z",
          "type": "session_meta",
          "payload": {
            "id": "thread-001",
            "cwd": "/tmp/project",
            "source": "cli",
            "model_provider": "openai",
            "git": {
              "commit_hash": "abc",
              "branch": "main",
              "repository_url": "https://example.com/repo.git"
            }
          }
        }
        """
        let parsedSession = try CodexGeneratedFilesParser.parseRolloutLine(text: sessionLine)
        if case let .sessionMeta(meta) = parsedSession.item {
            #expect(meta.id == "thread-001")
            #expect(meta.cwd == "/tmp/project")
            #expect(meta.git?.branch == "main")
        } else {
            Issue.record("Expected session_meta")
        }

        let tokenLine = """
        {
          "timestamp": "2026-02-11T12:00:01Z",
          "type": "event_msg",
          "payload": {
            "type": "token_count",
            "info": {
              "model": "gpt-5",
              "total_token_usage": {
                "input_tokens": 200,
                "cached_input_tokens": 50,
                "output_tokens": 100,
                "total_tokens": 300
              },
              "last_token_usage": {
                "input_tokens": 20,
                "cached_input_tokens": 5,
                "output_tokens": 10,
                "total_tokens": 30
              }
            }
          }
        }
        """
        let parsedToken = try CodexGeneratedFilesParser.parseRolloutLine(text: tokenLine)
        if case let .tokenCount(tokenCount) = parsedToken.item {
            #expect(tokenCount.model == "gpt-5")
            #expect(tokenCount.totalUsage?.inputTokens == 200)
            #expect(tokenCount.totalUsage?.cachedInputTokens == 50)
            #expect(tokenCount.lastUsage?.outputTokens == 10)
        } else {
            Issue.record("Expected token_count")
        }
    }

    @Test("Parse rollout response_item, event_msg(user_message), compacted")
    func parseRolloutAdditionalItems() throws {
        let responseLine = """
        {
          "timestamp": "2026-02-11T12:00:01Z",
          "type": "response_item",
          "payload": {
            "type": "message",
            "role": "assistant",
            "phase": "final_answer",
            "content": [
              { "type": "output_text", "text": "Done" }
            ]
          }
        }
        """
        let parsedResponse = try CodexGeneratedFilesParser.parseRolloutLine(text: responseLine)
        if case let .responseItem(item) = parsedResponse.item {
            if case let .message(role, content, phase) = item.kind {
                #expect(role == "assistant")
                #expect(phase == "final_answer")
                #expect(content.count == 1)
            } else {
                Issue.record("Expected response_item.message")
            }
        } else {
            Issue.record("Expected response_item")
        }

        let userMessageLine = """
        {
          "timestamp": "2026-02-11T12:00:02Z",
          "type": "event_msg",
          "payload": {
            "type": "user_message",
            "message": "hello",
            "images": ["https://a.example/img.png"],
            "local_images": ["/tmp/a.png"],
            "text_elements": [{"kind":"text","start":0,"end":5}]
          }
        }
        """
        let parsedEvent = try CodexGeneratedFilesParser.parseRolloutLine(text: userMessageLine)
        if case let .eventMsg(event) = parsedEvent.item {
            if case let .userMessage(user) = event.kind {
                #expect(user.message == "hello")
                #expect(user.images?.count == 1)
                #expect(user.localImages.count == 1)
            } else {
                Issue.record("Expected event_msg.user_message")
            }
        } else {
            Issue.record("Expected event_msg")
        }

        let compactedLine = """
        {
          "timestamp": "2026-02-11T12:00:03Z",
          "type": "compacted",
          "payload": {
            "message": "summary",
            "replacement_history": [
              {
                "type": "message",
                "role": "assistant",
                "content": [{ "type": "output_text", "text": "R" }]
              }
            ]
          }
        }
        """
        let parsedCompacted = try CodexGeneratedFilesParser.parseRolloutLine(text: compactedLine)
        if case let .compacted(item) = parsedCompacted.item {
            #expect(item.message == "summary")
            #expect(item.replacementHistory?.count == 1)
        } else {
            Issue.record("Expected compacted")
        }
    }

    @Test("Parse rollout response_item custom_tool_call and output as structured JSON")
    func parseRolloutCustomToolItems() throws {
        let callLine = """
        {
          "timestamp": "2026-02-11T12:00:04Z",
          "type": "response_item",
          "payload": {
            "type": "custom_tool_call",
            "name": "docs.search",
            "call_id": "call-1",
            "input": {
              "query": "swift testing"
            }
          }
        }
        """
        let parsedCall = try CodexGeneratedFilesParser.parseRolloutLine(text: callLine)
        if case let .responseItem(item) = parsedCall.item {
            if case let .customToolCall(name, callID, input) = item.kind {
                #expect(name == "docs.search")
                #expect(callID == "call-1")
                #expect(input?.objectValue?["query"]?.stringValue == "swift testing")
            } else {
                Issue.record("Expected response_item.custom_tool_call")
            }
        } else {
            Issue.record("Expected response_item")
        }

        let outputLine = """
        {
          "timestamp": "2026-02-11T12:00:05Z",
          "type": "response_item",
          "payload": {
            "type": "custom_tool_call_output",
            "call_id": "call-1",
            "output": {
              "hits": 3
            }
          }
        }
        """
        let parsedOutput = try CodexGeneratedFilesParser.parseRolloutLine(text: outputLine)
        if case let .responseItem(item) = parsedOutput.item {
            if case let .customToolCallOutput(callID, output) = item.kind {
                #expect(callID == "call-1")
                #expect(output?.objectValue?["hits"]?.intValue == 3)
            } else {
                Issue.record("Expected response_item.custom_tool_call_output")
            }
        } else {
            Issue.record("Expected response_item")
        }
    }

    @Test("Parse history.jsonl entries with session_id and conversation_id")
    func parseHistoryJSONL() throws {
        let history = """
        {"session_id":"s-1","ts":1739275200,"text":"hello"}
        {"conversation_id":"s-2","ts":1739275201,"text":"world"}
        """
        let entries = try CodexGeneratedFilesParser.parseHistoryLines(data: Data(history.utf8))
        #expect(entries.count == 2)
        #expect(entries[0].sessionID == "s-1")
        #expect(entries[1].sessionID == "s-2")
        #expect(entries[1].text == "world")
    }

    @Test("Parse config.toml and managed_config.toml")
    func parseConfigToml() throws {
        let toml = """
        model = "gpt-5"
        profile = "work"
        approval_policy = "on-request"
        sandbox_mode = "workspace-write"
        chatgpt_base_url = "https://chatgpt.com/backend-api"

        [features]
        web_search_request = true
        shell_tool = false

        [history]
        persistence = "save-all"
        max_bytes = 1024

        [sandbox_workspace_write]
        network_access = true
        writable_roots = ["/tmp/project"]

        [mcp_servers.docs]
        command = "npx"
        args = ["-y", "@acme/docs-mcp"]
        enabled = true

        [profiles.work]
        model = "gpt-5-codex"
        approval_policy = "on-request"
        """
        let parsed = try CodexGeneratedFilesParser.parseConfigToml(data: Data(toml.utf8))
        #expect(parsed.model == "gpt-5")
        #expect(parsed.profile == "work")
        #expect(parsed.features?["web_search_request"] == true)
        #expect(parsed.history?.maxBytes == 1024)
        #expect(parsed.sandboxWorkspaceWrite?.networkAccess == true)
        #expect(parsed.mcpServers["docs"]?.command == "npx")
        #expect(parsed.profiles["work"]?.model == "gpt-5-codex")

        let managedToml = """
        model = "gpt-5.2-codex"

        [features]
        unified_exec = true
        """
        let managed = try CodexGeneratedFilesParser.parseConfigToml(data: Data(managedToml.utf8))
        #expect(managed.model == "gpt-5.2-codex")
        #expect(managed.features?["unified_exec"] == true)
    }

    @Test("Load sessions and archived_sessions rollout files")
    func loadRolloutFilesFromHome() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-home-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sessionsDir = tempRoot
            .appendingPathComponent("sessions/2026/02/11", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        let archivedDir = tempRoot
            .appendingPathComponent("archived_sessions/2026/02/11", isDirectory: true)
        try FileManager.default.createDirectory(at: archivedDir, withIntermediateDirectories: true)

        let sessionFile = sessionsDir.appendingPathComponent("rollout-a.jsonl")
        try """
        {"timestamp":"2026-02-11T12:00:00Z","type":"session_meta","payload":{"id":"s1","cwd":"/tmp"}}
        """.write(to: sessionFile, atomically: true, encoding: .utf8)

        let archivedFile = archivedDir.appendingPathComponent("rollout-b.jsonl")
        try """
        {"timestamp":"2026-02-11T12:00:00Z","type":"session_meta","payload":{"id":"s2","cwd":"/tmp"}}
        """.write(to: archivedFile, atomically: true, encoding: .utf8)

        let files = try CodexGeneratedFilesParser.loadRolloutFiles(codexHome: tempRoot, includeArchived: true)
        #expect(files.count == 2)
        #expect(files.contains(where: { $0.path.hasSuffix("rollout-a.jsonl") }))
        #expect(files.contains(where: { $0.path.hasSuffix("rollout-b.jsonl") }))
    }

    private static func makeJWT(payload: String) -> String {
        let header = #"{"alg":"none","typ":"JWT"}"#
        func encode(_ raw: String) -> String {
            Data(raw.utf8)
                .base64EncodedString()
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return "\(encode(header)).\(encode(payload)).sig"
    }
}
