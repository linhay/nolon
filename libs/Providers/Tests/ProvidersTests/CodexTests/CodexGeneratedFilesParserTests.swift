import Foundation
import Testing
@testable import CodexProvider
import STFilePath

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

    @Test("Parse rollout response_item function/local-shell/web-search/ghost-snapshot")
    func parseRolloutResponseItemVariants() throws {
        let functionOutputLine = """
        {
          "timestamp": "2026-02-11T12:00:06Z",
          "type": "response_item",
          "payload": {
            "type": "function_call_output",
            "call_id": "call-fn-1",
            "output": { "ok": true }
          }
        }
        """
        let parsedFunctionOutput = try CodexGeneratedFilesParser.parseRolloutLine(text: functionOutputLine)
        if case let .responseItem(item) = parsedFunctionOutput.item {
            if case let .functionCallOutput(callID, output) = item.kind {
                #expect(callID == "call-fn-1")
                #expect(output?.objectValue?["ok"]?.stringValue == nil)
                if case let .bool(ok)? = output?.objectValue?["ok"] {
                    #expect(ok == true)
                } else {
                    Issue.record("Expected bool output.ok")
                }
            } else {
                Issue.record("Expected response_item.function_call_output")
            }
        } else {
            Issue.record("Expected response_item")
        }

        let localShellLine = """
        {
          "timestamp": "2026-02-11T12:00:07Z",
          "type": "response_item",
          "payload": {
            "type": "local_shell_call",
            "status": "completed",
            "action": { "command": "ls -la" }
          }
        }
        """
        let parsedLocalShell = try CodexGeneratedFilesParser.parseRolloutLine(text: localShellLine)
        if case let .responseItem(item) = parsedLocalShell.item {
            if case let .localShellCall(status, action) = item.kind {
                #expect(status == "completed")
                #expect(action?.objectValue?["command"]?.stringValue == "ls -la")
            } else {
                Issue.record("Expected response_item.local_shell_call")
            }
        } else {
            Issue.record("Expected response_item")
        }

        let webSearchLine = """
        {
          "timestamp": "2026-02-11T12:00:08Z",
          "type": "response_item",
          "payload": {
            "type": "web_search_call",
            "status": "running",
            "action": { "query": "swift testing" }
          }
        }
        """
        let parsedWebSearch = try CodexGeneratedFilesParser.parseRolloutLine(text: webSearchLine)
        if case let .responseItem(item) = parsedWebSearch.item {
            if case let .webSearchCall(status, action) = item.kind {
                #expect(status == "running")
                #expect(action?.objectValue?["query"]?.stringValue == "swift testing")
            } else {
                Issue.record("Expected response_item.web_search_call")
            }
        } else {
            Issue.record("Expected response_item")
        }

        let ghostLine = """
        {
          "timestamp": "2026-02-11T12:00:09Z",
          "type": "response_item",
          "payload": {
            "type": "ghost_snapshot",
            "ghost_commit": { "sha": "abc123" }
          }
        }
        """
        let parsedGhost = try CodexGeneratedFilesParser.parseRolloutLine(text: ghostLine)
        if case let .responseItem(item) = parsedGhost.item {
            if case let .ghostSnapshot(ghostCommit) = item.kind {
                #expect(ghostCommit?.objectValue?["sha"]?.stringValue == "abc123")
            } else {
                Issue.record("Expected response_item.ghost_snapshot")
            }
        } else {
            Issue.record("Expected response_item")
        }
    }

    @Test("Parse rollout event_msg variants and unknown fallback")
    func parseRolloutEventMessageVariantsAndFallback() throws {
        let agentLine = """
        {
          "timestamp": "2026-02-11T12:00:10Z",
          "type": "event_msg",
          "payload": {
            "type": "agent_message",
            "message": "working..."
          }
        }
        """
        let parsedAgent = try CodexGeneratedFilesParser.parseRolloutLine(text: agentLine)
        if case let .eventMsg(event) = parsedAgent.item {
            if case let .agentMessage(message) = event.kind {
                #expect(message == "working...")
            } else {
                Issue.record("Expected event_msg.agent_message")
            }
        } else {
            Issue.record("Expected event_msg")
        }

        let warningLine = """
        {
          "timestamp": "2026-02-11T12:00:11Z",
          "type": "event_msg",
          "payload": {
            "type": "warning",
            "message": "be careful"
          }
        }
        """
        let parsedWarning = try CodexGeneratedFilesParser.parseRolloutLine(text: warningLine)
        if case let .eventMsg(event) = parsedWarning.item {
            if case let .warning(message) = event.kind {
                #expect(message == "be careful")
            } else {
                Issue.record("Expected event_msg.warning")
            }
        } else {
            Issue.record("Expected event_msg")
        }

        let errorLine = """
        {
          "timestamp": "2026-02-11T12:00:11Z",
          "type": "event_msg",
          "payload": {
            "type": "error",
            "message": "boom"
          }
        }
        """
        let parsedError = try CodexGeneratedFilesParser.parseRolloutLine(text: errorLine)
        if case let .eventMsg(event) = parsedError.item {
            if case let .error(message) = event.kind {
                #expect(message == "boom")
            } else {
                Issue.record("Expected event_msg.error")
            }
        } else {
            Issue.record("Expected event_msg")
        }

        let turnCompleteLine = """
        {
          "timestamp": "2026-02-11T12:00:12Z",
          "type": "event_msg",
          "payload": {
            "type": "turn_complete",
            "last_agent_message": "done"
          }
        }
        """
        let parsedTurnComplete = try CodexGeneratedFilesParser.parseRolloutLine(text: turnCompleteLine)
        if case let .eventMsg(event) = parsedTurnComplete.item {
            if case let .turnComplete(lastAgentMessage) = event.kind {
                #expect(lastAgentMessage == "done")
            } else {
                Issue.record("Expected event_msg.turn_complete")
            }
        } else {
            Issue.record("Expected event_msg")
        }

        let unknownEventLine = """
        {
          "timestamp": "2026-02-11T12:00:13Z",
          "type": "event_msg",
          "payload": {
            "type": "custom_unknown_event",
            "x": 1
          }
        }
        """
        let parsedUnknownEvent = try CodexGeneratedFilesParser.parseRolloutLine(text: unknownEventLine)
        if case let .eventMsg(event) = parsedUnknownEvent.item {
            if case let .other(type, payload) = event.kind {
                #expect(type == "custom_unknown_event")
                #expect(payload?.objectValue?["x"]?.intValue == 1)
            } else {
                Issue.record("Expected event_msg.other fallback")
            }
        } else {
            Issue.record("Expected event_msg")
        }

        let unknownTopLevelLine = """
        {
          "timestamp": "2026-02-11T12:00:14Z",
          "type": "brand_new_line_type",
          "payload": {
            "ignored": true
          }
        }
        """
        let parsedUnknownTopLevel = try CodexGeneratedFilesParser.parseRolloutLine(text: unknownTopLevelLine)
        if case let .other(type) = parsedUnknownTopLevel.item {
            #expect(type == "brand_new_line_type")
        } else {
            Issue.record("Expected top-level other(type:) fallback")
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

    @Test("Parse rollout reasoning/compaction_summary and nested token_count/task lifecycle")
    func parseRolloutReasoningCompactionAndNestedEvents() throws {
        let reasoningLine = """
        {
          "timestamp": "2026-02-11T12:00:15Z",
          "type": "response_item",
          "payload": {
            "type": "reasoning",
            "summary": {"text": "thinking"},
            "content": [{"kind": "reasoning_text", "text": "detail"}]
          }
        }
        """
        let parsedReasoning = try CodexGeneratedFilesParser.parseRolloutLine(text: reasoningLine)
        if case let .responseItem(item) = parsedReasoning.item {
            if case let .reasoning(summary, content) = item.kind {
                #expect(summary?.objectValue?["text"]?.stringValue == "thinking")
                if case let .array(values)? = content {
                    #expect(values.count == 1)
                } else {
                    Issue.record("Expected reasoning content to be array")
                }
            } else {
                Issue.record("Expected response_item.reasoning")
            }
        } else {
            Issue.record("Expected response_item")
        }

        let compactionSummaryLine = """
        {
          "timestamp": "2026-02-11T12:00:16Z",
          "type": "response_item",
          "payload": {
            "type": "compaction_summary",
            "encrypted_content": "enc-1"
          }
        }
        """
        let parsedCompaction = try CodexGeneratedFilesParser.parseRolloutLine(text: compactionSummaryLine)
        if case let .responseItem(item) = parsedCompaction.item {
            if case let .compaction(encryptedContent) = item.kind {
                #expect(encryptedContent == "enc-1")
            } else {
                Issue.record("Expected response_item.compaction_summary")
            }
        } else {
            Issue.record("Expected response_item")
        }

        let nestedTokenLine = """
        {
          "timestamp": "2026-02-11T12:00:17Z",
          "type": "event_msg",
          "payload": {
            "payload": {
              "type": "token_count",
              "info": {
                "model_name": "gpt-5.2-codex",
                "total_token_usage": { "input_tokens": 10, "output_tokens": 5, "total_tokens": 15 }
              }
            }
          }
        }
        """
        let parsedNestedToken = try CodexGeneratedFilesParser.parseRolloutLine(text: nestedTokenLine)
        if case let .tokenCount(tokenCount) = parsedNestedToken.item {
            #expect(tokenCount.model == "gpt-5.2-codex")
            #expect(tokenCount.totalUsage?.totalTokens == 15)
        } else {
            Issue.record("Expected top-level tokenCount for nested event_msg payload.token_count")
        }

        let taskStartedLine = """
        {
          "timestamp": "2026-02-11T12:00:18Z",
          "type": "event_msg",
          "payload": {
            "type": "task_started",
            "model_context_window": 272000
          }
        }
        """
        let parsedTaskStarted = try CodexGeneratedFilesParser.parseRolloutLine(text: taskStartedLine)
        if case let .eventMsg(event) = parsedTaskStarted.item {
            if case let .turnStarted(modelContextWindow) = event.kind {
                #expect(modelContextWindow == 272000)
            } else {
                Issue.record("Expected event_msg.task_started as turnStarted")
            }
        } else {
            Issue.record("Expected event_msg")
        }

        let taskCompleteLine = """
        {
          "timestamp": "2026-02-11T12:00:19Z",
          "type": "event_msg",
          "payload": {
            "type": "task_complete",
            "last_agent_message": "all done"
          }
        }
        """
        let parsedTaskComplete = try CodexGeneratedFilesParser.parseRolloutLine(text: taskCompleteLine)
        if case let .eventMsg(event) = parsedTaskComplete.item {
            if case let .turnComplete(lastAgentMessage) = event.kind {
                #expect(lastAgentMessage == "all done")
            } else {
                Issue.record("Expected event_msg.task_complete as turnComplete")
            }
        } else {
            Issue.record("Expected event_msg")
        }
    }

    @Test("Load all codex generated files from CODEX_HOME")
    func loadAllGeneratedFilesFromHome() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-home-all-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let jwt = Self.makeJWT(payload: """
        {
          "email": "all@example.com",
          "https://api.openai.com/auth": {
            "chatgpt_plan_type": "plus",
            "chatgpt_account_id": "org-all"
          }
        }
        """)
        try """
        {
          "auth_mode": "chatgpt",
          "tokens": {
            "id_token": "\(jwt)",
            "access_token": "access-all",
            "refresh_token": "refresh-all",
            "account_id": "org-all"
          }
        }
        """.write(to: tempRoot.appendingPathComponent("auth.json"), atomically: true, encoding: .utf8)

        try """
        {"session_id":"h-1","ts":1739275200,"text":"hi"}
        """.write(to: tempRoot.appendingPathComponent("history.jsonl"), atomically: true, encoding: .utf8)

        try """
        model = "gpt-5"
        [features]
        web_search_request = true
        """.write(to: tempRoot.appendingPathComponent("config.toml"), atomically: true, encoding: .utf8)

        try """
        model = "gpt-5.2-codex"
        """.write(to: tempRoot.appendingPathComponent("managed_config.toml"), atomically: true, encoding: .utf8)

        let sessionsDir = tempRoot
            .appendingPathComponent("sessions/2026/02/11", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        try """
        {"timestamp":"2026-02-11T12:00:00Z","type":"session_meta","payload":{"id":"s-all"}}
        """.write(to: sessionsDir.appendingPathComponent("rollout.jsonl"), atomically: true, encoding: .utf8)

        let snapshot = try CodexGeneratedFilesParser.loadAllGeneratedFiles(codexHome: tempRoot, includeArchived: true)
        #expect(snapshot.auth?.tokens?.accessToken == "access-all")
        #expect(snapshot.history.count == 1)
        #expect(snapshot.history.first?.sessionID == "h-1")
        #expect(snapshot.config?.model == "gpt-5")
        #expect(snapshot.managedConfig?.model == "gpt-5.2-codex")
        #expect(snapshot.rolloutFiles.count == 1)
        #expect(snapshot.rolloutFiles.first?.lines.count == 1)
    }

    @Test("Load all generated files can exclude archived_sessions")
    func loadAllGeneratedFilesExcludeArchived() throws {
        let tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-home-no-archived-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        let sessionsDir = tempRoot.appendingPathComponent("sessions/2026/02/11", isDirectory: true)
        let archivedDir = tempRoot.appendingPathComponent("archived_sessions/2026/02/11", isDirectory: true)
        try FileManager.default.createDirectory(at: sessionsDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: archivedDir, withIntermediateDirectories: true)

        try """
        {"timestamp":"2026-02-11T12:00:00Z","type":"session_meta","payload":{"id":"s-live"}}
        """.write(to: sessionsDir.appendingPathComponent("live.jsonl"), atomically: true, encoding: .utf8)
        try """
        {"timestamp":"2026-02-11T12:00:00Z","type":"session_meta","payload":{"id":"s-archived"}}
        """.write(to: archivedDir.appendingPathComponent("archived.jsonl"), atomically: true, encoding: .utf8)

        let snapshot = try CodexGeneratedFilesParser.loadAllGeneratedFiles(codexHome: tempRoot, includeArchived: false)
        #expect(snapshot.rolloutFiles.count == 1)
        #expect(snapshot.rolloutFiles.first?.path.hasSuffix("live.jsonl") == true)
    }

    @Test("Load all generated files from STFolder root")
    func loadAllGeneratedFilesFromSTFolder() throws {
        let root = STFolder(FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-home-stfolder-\(UUID().uuidString)", isDirectory: true))
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let sessions = root.folder("sessions").folder("2026").folder("02").folder("12")
        _ = sessions.createIfNotExists()
        try sessions.file("rollout.jsonl").overlay(with: """
        {"timestamp":"2026-02-12T12:00:00Z","type":"session_meta","payload":{"id":"st-root"}}
        """)

        let snapshot = try CodexGeneratedFilesParser.loadAllGeneratedFiles(codexHome: root, includeArchived: false)
        #expect(snapshot.rolloutFiles.count == 1)
        #expect(snapshot.rolloutFiles.first?.lines.count == 1)
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
