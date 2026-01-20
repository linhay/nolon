import Foundation

/// Errors that can occur during skill operations
public enum SkillError: Error, LocalizedError {
    case parsingFailed(String)
    case symlinkFailed(String)
    case conflictDetected(skillName: String, providers: [SkillProvider])
    case brokenSymlink(path: String)
    case skillNotFound(id: String)
    case directoryCreationFailed(path: String)
    case fileOperationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .parsingFailed(let details):
            return "Failed to parse SKILL.md: \(details)"
        case .symlinkFailed(let details):
            return "Failed to create symlink: \(details)"
        case .conflictDetected(let skillName, let providers):
            let providerNames = providers.map { $0.displayName }.joined(separator: ", ")
            return
                "Skill '\(skillName)' has different versions in: \(providerNames). Please choose which version to keep."
        case .brokenSymlink(let path):
            return "Symlink at '\(path)' points to a non-existent file"
        case .skillNotFound(let id):
            return "Skill '\(id)' not found"
        case .directoryCreationFailed(let path):
            return "Failed to create directory at '\(path)'"
        case .fileOperationFailed(let details):
            return "File operation failed: \(details)"
        }
    }
}
