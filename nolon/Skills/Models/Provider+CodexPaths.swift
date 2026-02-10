import Foundation
import ProviderCatalog

extension Provider {
    var codexHomeURL: URL {
        URL(fileURLWithPath: defaultSkillsPath, isDirectory: true).deletingLastPathComponent()
    }

    var codexRulesURL: URL {
        codexHomeURL.appendingPathComponent("rules", isDirectory: true)
    }

    var codexDefaultRulesFileURL: URL {
        codexRulesURL.appendingPathComponent("default.rules", isDirectory: false)
    }
}
