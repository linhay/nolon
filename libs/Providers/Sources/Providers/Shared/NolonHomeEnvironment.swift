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
            return STFolder(expanded).url.standardizedFileURL
        }
        let currentDirectory = STFolder(FileManager.default.currentDirectoryPath)
        return currentDirectory.folder(expanded).url.standardizedFileURL
    }
}
