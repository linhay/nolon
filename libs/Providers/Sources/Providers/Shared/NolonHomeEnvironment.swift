import Foundation
import STFilePath

public enum NolonHomeEnvironment {
    public static let variableName = "NOLON_HOME"

    public static func resolveNolonHomeFolder(
        environment: [String: String],
        userHomeURL: URL = STFolder(NSHomeDirectory()).url
    ) -> STFolder {
        if let raw = environment[variableName] {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return STFolder(normalizeDirectoryPath(trimmed))
            }
        }
        return STFolder(userHomeURL.appendingPathComponent(".nolon", isDirectory: true))
    }

    private static func normalizeDirectoryPath(_ rawPath: String) -> URL {
        let expanded = (rawPath as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return URL(fileURLWithPath: expanded, isDirectory: true).standardizedFileURL
        }
        let currentDirectory = FileManager.default.currentDirectoryPath
        return URL(fileURLWithPath: expanded, relativeTo: URL(fileURLWithPath: currentDirectory, isDirectory: true))
            .standardizedFileURL
    }
}

