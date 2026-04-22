import Foundation
import STFilePath

public enum NolonHomeEnvironment {
    public static let variableName = "NOLON_HOME"
    private static let xctestConfigurationVariableName = "XCTestConfigurationFilePath"
    private static let xctestSessionVariableName = "XCTestSessionIdentifier"
    private static let defaultUserHomeURL = STFolder(NSHomeDirectory()).url.standardizedFileURL

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
        let normalizedUserHomeURL = userHomeURL.standardizedFileURL
        if shouldUseIsolatedXCTestHome(
            environment: environment,
            userHomeURL: normalizedUserHomeURL
        ) {
            return STFolder(defaultXCTestHomeURL(environment: environment))
        }
        return STFolder(normalizedUserHomeURL.appendingPathComponent(".nolon", isDirectory: true))
    }

    public static func resolveApplicationSupportFolder(
        environment: [String: String],
        fileManager: FileManager = .default,
        userHomeURL: URL = STFolder(NSHomeDirectory()).url
    ) -> URL {
        let normalizedUserHomeURL = userHomeURL.standardizedFileURL
        if shouldUseIsolatedXCTestHome(
            environment: environment,
            userHomeURL: normalizedUserHomeURL
        ) {
            return defaultXCTestHomeURL(environment: environment)
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
                .standardizedFileURL
        }

        if normalizedUserHomeURL.path != defaultUserHomeURL.path {
            return normalizedUserHomeURL
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("Application Support", isDirectory: true)
                .standardizedFileURL
        }

        if let applicationSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            return applicationSupportURL.standardizedFileURL
        }

        return normalizedUserHomeURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Application Support", isDirectory: true)
            .standardizedFileURL
    }

    private static func normalizeDirectoryPath(_ rawPath: String) -> URL {
        let expanded = (rawPath as NSString).expandingTildeInPath
        if expanded.hasPrefix("/") {
            return STFolder(expanded).url.standardizedFileURL
        }
        let currentDirectory = STFolder(FileManager.default.currentDirectoryPath)
        return currentDirectory.folder(expanded).url.standardizedFileURL
    }

    private static func isRunningUnderXCTest(environment: [String: String]) -> Bool {
        environment[xctestConfigurationVariableName]?.isEmpty == false
            || environment[xctestSessionVariableName]?.isEmpty == false
    }

    private static func shouldUseIsolatedXCTestHome(
        environment: [String: String],
        userHomeURL: URL
    ) -> Bool {
        isRunningUnderXCTest(environment: environment)
            && userHomeURL.standardizedFileURL.path == defaultUserHomeURL.path
    }

    private static func defaultXCTestHomeURL(environment: [String: String]) -> URL {
        let seed = environment[xctestSessionVariableName]
            ?? environment[xctestConfigurationVariableName]
            ?? "default"
        let hash = seed.utf8.reduce(UInt64(5381)) { partial, byte in
            ((partial << 5) &+ partial) &+ UInt64(byte)
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("nolon-xctest-\(String(hash, radix: 16))", isDirectory: true)
            .standardizedFileURL
    }
}
