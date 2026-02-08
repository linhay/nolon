import Foundation
import Testing
@testable import CodexProvider

@Suite("Codex models_cache.json")
struct CodexModelsCacheTests {
    @Test("Decodes full models cache payload")
    func decodesFullPayload() throws {
        let json = """
        {
          "fetched_at": "2026-02-08T11:15:59.680735Z",
          "etag": "W/\\"etag-value\\"",
          "client_version": "0.98.0",
          "models": [
            {
              "slug": "gpt-5.2-codex",
              "display_name": "gpt-5.2-codex",
              "description": "Frontier agentic coding model.",
              "default_reasoning_level": "medium",
              "supported_reasoning_levels": [
                { "effort": "low", "description": "Fast responses with lighter reasoning" },
                { "effort": "medium", "description": "Balanced reasoning depth" }
              ],
              "shell_type": "shell_command",
              "visibility": "list",
              "minimal_client_version": [0, 98, 0],
              "supported_in_api": true,
              "priority": 0,
              "upgrade": { "id": "gpt-5.3-codex", "slug": "gpt-5.3-codex" },
              "base_instructions": "You are Codex.",
              "model_messages": {
                "instructions_template": "Template",
                "instructions_variables": {
                  "personality_default": "",
                  "personality_pragmatic": "Pragmatic"
                }
              },
              "supports_reasoning_summaries": true,
              "support_verbosity": false,
              "default_verbosity": null,
              "apply_patch_tool_type": "freeform",
              "truncation_policy": { "mode": "tokens", "limit": 10000 },
              "supports_parallel_tool_calls": true,
              "context_window": 272000,
              "effective_context_window_percent": 95,
              "experimental_supported_tools": ["tool-a", "tool-b"],
              "input_modalities": ["text", "image"]
            }
          ]
        }
        """

        let data = try #require(json.data(using: .utf8))
        let cache = try CodexModelsCache.decode(from: data)

        #expect(cache.clientVersion == "0.98.0")
        #expect(cache.models.count == 1)

        let model = try #require(cache.models.first)
        #expect(model.slug == "gpt-5.2-codex")
        #expect(model.displayName == "gpt-5.2-codex")
        #expect(model.supportedReasoningLevels.count == 2)
        #expect(model.minimalClientVersion == [0, 98, 0])
        #expect(model.supportsVerbosity == false)
        #expect(model.truncationPolicy?.mode == "tokens")
        #expect(model.truncationPolicy?.limit == 10000)
        #expect(model.modelMessages?.instructionsVariables["personality_pragmatic"] == "Pragmatic")
        #expect(model.inputModalities == ["text", "image"])
    }

    @Test("Loads cache via CodexHelper with CODEX_HOME override")
    func loadsViaHelperFromCodexHome() throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("codex-model-cache-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: base) }

        let cacheURL = base.appendingPathComponent("models_cache.json", isDirectory: false)
        let json = """
        {
          "fetched_at": "2026-02-08T11:15:59Z",
          "etag": null,
          "client_version": "0.99.0",
          "models": [
            { "slug": "visible-model", "display_name": "visible-model", "visibility": "list", "supported_reasoning_levels": [] },
            { "slug": "hidden-model", "display_name": "hidden-model", "visibility": "hide", "supported_reasoning_levels": [] }
          ]
        }
        """
        try json.write(to: cacheURL, atomically: true, encoding: .utf8)

        let helper = CodexHelper(environment: ["CODEX_HOME": base.path])
        let snapshot = try helper.loadModelsCache()
        let visible = try helper.loadVisibleModelsFromCache()

        #expect(snapshot.clientVersion == "0.99.0")
        #expect(snapshot.models.count == 2)
        #expect(visible.map(\.slug) == ["visible-model"])
    }
}
