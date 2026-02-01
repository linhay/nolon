import Foundation

enum CodexPaths {
    static func codexHomeURL(for provider: Provider) -> URL? {
        guard provider.templateId == ProviderTemplate.codex.rawValue else { return nil }
        // In templates, defaultSkillsPath is `<codex-home>/skills` (in practice: `~/.codex/skills`).
        return URL(fileURLWithPath: provider.defaultSkillsPath).deletingLastPathComponent()
    }

    static func authJsonURL(codexHomeURL: URL) -> URL {
        codexHomeURL.appendingPathComponent("auth.json")
    }

    static func stateDbURL(codexHomeURL: URL) -> URL {
        codexHomeURL.appendingPathComponent("state.sqlite")
    }
}
