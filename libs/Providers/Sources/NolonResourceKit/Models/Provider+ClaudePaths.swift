import Foundation
import ProviderCatalog
import STFilePath

extension Provider {
    public var claudeHomeFolder: STFolder {
        STPath(defaultSkillsPath).parentFolder() ?? STFolder(defaultSkillsPath)
    }

    public var claudeInstructionsFile: STFile {
        claudeHomeFolder.file("CLAUDE.md")
    }

    public var claudeInstructionsFileURL: URL {
        claudeInstructionsFile.url
    }
}
