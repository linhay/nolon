import Foundation
import Testing
@testable import CodexProvider

@Suite("Codex EventMsg Compatibility")
struct CodexEventMsgCompatibilityTests {
    @Test("EventMsg types from codex schema should map to known kinds or dedicated typed cases")
    func eventMsgSchemaCompatibility() throws {
        let allTypes: [String] = [
            "error",
            "warning",
            "context_compacted",
            "thread_rolled_back",
            "task_started",
            "task_complete",
            "token_count",
            "agent_message",
            "user_message",
            "agent_message_delta",
            "agent_reasoning",
            "agent_reasoning_delta",
            "agent_reasoning_raw_content",
            "agent_reasoning_raw_content_delta",
            "agent_reasoning_section_break",
            "session_configured",
            "thread_name_updated",
            "mcp_startup_update",
            "mcp_startup_complete",
            "mcp_tool_call_begin",
            "mcp_tool_call_end",
            "web_search_begin",
            "web_search_end",
            "exec_command_begin",
            "exec_command_output_delta",
            "terminal_interaction",
            "exec_command_end",
            "view_image_tool_call",
            "exec_approval_request",
            "request_user_input",
            "dynamic_tool_call_request",
            "elicitation_request",
            "apply_patch_approval_request",
            "deprecation_notice",
            "background_event",
            "undo_started",
            "undo_completed",
            "stream_error",
            "patch_apply_begin",
            "patch_apply_end",
            "turn_diff",
            "get_history_entry_response",
            "mcp_list_tools_response",
            "list_custom_prompts_response",
            "list_skills_response",
            "list_remote_skills_response",
            "remote_skill_downloaded",
            "skills_update_available",
            "plan_update",
            "turn_aborted",
            "shutdown_complete",
            "entered_review_mode",
            "exited_review_mode",
            "raw_response_item",
            "item_started",
            "item_completed",
            "agent_message_content_delta",
            "plan_delta",
            "reasoning_content_delta",
            "reasoning_raw_content_delta",
            "collab_agent_spawn_begin",
            "collab_agent_spawn_end",
            "collab_agent_interaction_begin",
            "collab_agent_interaction_end",
            "collab_waiting_begin",
            "collab_waiting_end",
            "collab_close_begin",
            "collab_close_end",
        ]

        for type in allTypes {
            let line = """
            {
              "timestamp": "2026-02-13T12:00:00Z",
              "type": "event_msg",
              "payload": {
                "type": "\(type)"
              }
            }
            """

            let parsed = try CodexGeneratedFilesParser.parseRolloutLine(text: line)
            if type == "token_count" {
                if case .tokenCount = parsed.item {
                    continue
                }
                Issue.record("Expected token_count to map to top-level tokenCount item")
                continue
            }

            guard case let .eventMsg(eventMessage) = parsed.item else {
                Issue.record("Expected event_msg item for type: \(type)")
                continue
            }

            if case let .other(otherType, _) = eventMessage.kind {
                Issue.record("Expected known event mapping for type: \(type), got other(\(otherType))")
            }
        }
    }

    @Test("ResponseItem types from codex schema should map to typed response kinds")
    func responseItemSchemaCompatibility() throws {
        let allTypes: [String] = [
            "message",
            "reasoning",
            "local_shell_call",
            "function_call",
            "function_call_output",
            "custom_tool_call",
            "custom_tool_call_output",
            "web_search_call",
            "ghost_snapshot",
            "compaction",
            "other",
        ]

        for type in allTypes {
            let line = """
            {
              "timestamp": "2026-02-13T12:00:00Z",
              "type": "response_item",
              "payload": {
                "type": "\(type)"
              }
            }
            """

            let parsed = try CodexGeneratedFilesParser.parseRolloutLine(text: line)
            guard case let .responseItem(item) = parsed.item else {
                Issue.record("Expected response_item for type: \(type)")
                continue
            }

            if type == "other" {
                if case .other = item.kind {
                    continue
                }
                Issue.record("Expected response_item.other mapping for type: other")
                continue
            }

            if case let .other(otherType, _) = item.kind {
                Issue.record("Expected typed response item mapping for type: \(type), got other(\(otherType))")
            }
        }
    }
}
