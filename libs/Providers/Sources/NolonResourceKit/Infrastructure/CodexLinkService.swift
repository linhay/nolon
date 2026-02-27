import Foundation
import ProviderCatalog
import STFilePath

public enum CodexLinkFolderKind: String, CaseIterable, Sendable {
    case prompts
    case rules
    case skills
}

public struct CodexLinkStatus: Sendable, Equatable {
    public let folder: CodexLinkFolderKind
    public let sourceURL: URL
    public let targetURL: URL
    public let isLinked: Bool
    public let hasVisibleEntries: Bool

    public init(
        folder: CodexLinkFolderKind,
        sourceURL: URL,
        targetURL: URL,
        isLinked: Bool,
        hasVisibleEntries: Bool
    ) {
        self.folder = folder
        self.sourceURL = sourceURL
        self.targetURL = targetURL
        self.isLinked = isLinked
        self.hasVisibleEntries = hasVisibleEntries
    }
}

public final class CodexLinkService: @unchecked Sendable {
    private let homeDirectoryPath: String

    public init(
        homeDirectoryPath: String = NSHomeDirectory()
    ) {
        self.homeDirectoryPath = homeDirectoryPath
    }

    public func status(folder: CodexLinkFolderKind, provider: Provider) -> CodexLinkStatus {
        let pair = linkPair(folder: folder, provider: provider)
        let linked = isTargetLinked(to: pair.sourceURL, targetURL: pair.targetURL)
        let hasVisible = !linked && hasVisibleContents(at: pair.targetURL)
        return CodexLinkStatus(
            folder: folder,
            sourceURL: pair.sourceURL,
            targetURL: pair.targetURL,
            isLinked: linked,
            hasVisibleEntries: hasVisible
        )
    }

    public func apply(enabled: Bool, folder: CodexLinkFolderKind, provider: Provider) throws {
        let pair = linkPair(folder: folder, provider: provider)
        if enabled {
            _ = STFolder(pair.sourceURL).createIfNotExists()
            try STPath(pair.targetURL).deleteIncludingBrokenSymlink()
            try STPath(pair.targetURL).createSymbolicLink(to: STPath(pair.sourceURL))
            return
        }

        if STPath(pair.targetURL).isSymbolicLink {
            try STPath(pair.targetURL).deleteIncludingBrokenSymlink()
        } else if STPath(pair.targetURL).isExists && !STFolder(pair.targetURL).isExists {
            try STPath(pair.targetURL).deleteIncludingBrokenSymlink()
        }
        _ = STFolder(pair.targetURL).createIfNotExists()
    }

    public func linkPair(folder: CodexLinkFolderKind, provider: Provider) -> (sourceURL: URL, targetURL: URL) {
        let sourceRoot = STFolder("\(homeDirectoryPath)/.codex")
        let targetRoot = STFolder(STFolder(provider.defaultSkillsPath).url.deletingLastPathComponent())
        return (
            sourceRoot.url.appendingPathComponent(folder.rawValue, isDirectory: true),
            targetRoot.url.appendingPathComponent(folder.rawValue, isDirectory: true)
        )
    }

    private func isTargetLinked(to sourceURL: URL, targetURL: URL) -> Bool {
        let targetPath = STPath(targetURL)
        guard targetPath.isSymbolicLink else { return false }
        do {
            let resolved = try targetPath.destinationOfSymbolicLink().url.standardizedFileURL
            return resolved.path == sourceURL.standardizedFileURL.path
        } catch {
            return false
        }
    }

    private func hasVisibleContents(at targetURL: URL) -> Bool {
        let targetPath = STPath(targetURL)
        guard targetPath.isExists else { return false }
        guard STFolder(targetURL).isExists else { return true }
        let contents = (try? STFolder(targetURL).subFilePaths()) ?? []
        return contents.contains { !$0.url.lastPathComponent.hasPrefix(".") }
    }
}
