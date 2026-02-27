import Foundation

public enum WorkflowSourceKind: String, Sendable, Equatable, CaseIterable {
    case skill
    case user
    case mcp
    case unknown
}

public enum WorkflowSourceResolver {
    public static func resolve(
        workflowPath: String,
        resolvedPath: String? = nil,
        nolonManager: NolonManager = .shared
    ) -> WorkflowSourceKind {
        let rawPath = normalizePath(workflowPath)
        let targetPath = normalizePath(resolvedPath ?? workflowPath)

        if targetPath.hasPrefix(normalizePath(nolonManager.generatedWorkflowsPath)) {
            return .skill
        }
        if targetPath.hasPrefix(normalizePath(nolonManager.mcpsWorkflowsPath)) {
            return .mcp
        }
        if targetPath.hasPrefix(normalizePath(nolonManager.userWorkflowsPath)) {
            return .user
        }

        // Backward compatibility with legacy provider/internal paths.
        if rawPath.contains("Skills/Workflows") || rawPath.contains(".gemini/workflows") {
            return .skill
        }
        return .unknown
    }

    public static func resolveSymlinkDestination(
        linkPath: String,
        destination: String
    ) -> String {
        if destination.hasPrefix("/") || destination.hasPrefix("~") {
            return normalizePath(destination)
        }
        let baseURL = URL(fileURLWithPath: linkPath).deletingLastPathComponent()
        let combined = (baseURL.path as NSString).appendingPathComponent(destination)
        return normalizePath(combined)
    }

    private static func normalizePath(_ raw: String) -> String {
        let expanded = NSString(string: raw).expandingTildeInPath
        return URL(fileURLWithPath: expanded).standardizedFileURL.path
    }
}
