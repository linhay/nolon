import Foundation
import ProviderCatalog
import STFilePath

extension Provider {
    public var codexHomeFolder: STFolder {
        STPath(defaultSkillsPath).parentFolder() ?? STFolder(defaultSkillsPath)
    }

    public var codexRulesFolder: STFolder {
        codexHomeFolder.folder("rules")
    }

    public var codexDefaultRulesFile: STFile {
        codexRulesFolder.file("default.rules")
    }

    public var codexAgentsFile: STFile {
        codexHomeFolder.file("AGENTS.md")
    }

    public var codexAgentsOverrideFile: STFile {
        codexHomeFolder.file("AGENTS.override.md")
    }

    public var codexRulesURL: URL {
        codexRulesFolder.url
    }

    public var codexAgentsFileURL: URL {
        codexAgentsFile.url
    }

}
