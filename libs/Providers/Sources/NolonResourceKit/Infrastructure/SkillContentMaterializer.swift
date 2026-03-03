import Foundation
import STFilePath

public enum SkillContentMaterializer {
    /// Copy a skill folder and replace symlinks with concrete files/folders.
    /// This makes the copied skill self-contained after moving out of its repository root.
    public static func copyMaterializingSymlinks(from source: STPath, to destination: STPath) throws {
        try source.copy(to: destination, isOverlay: true)
        try materializeSymlinkEntries(sourceRoot: source.url.standardizedFileURL, destinationRoot: destination.url.standardizedFileURL)
    }

    private static func materializeSymlinkEntries(sourceRoot: URL, destinationRoot: URL) throws {
        try materializeSymlinkEntries(at: sourceRoot, destination: destinationRoot)
    }

    private static func materializeSymlinkEntries(at sourceDirectory: URL, destination destinationDirectory: URL) throws {
        let fileManager = FileManager.default
        let keys: Set<URLResourceKey> = [.isSymbolicLinkKey, .isDirectoryKey]
        let children = try fileManager.contentsOfDirectory(
            at: sourceDirectory,
            includingPropertiesForKeys: Array(keys),
            options: []
        )

        for sourceEntry in children {
            let values = try sourceEntry.resourceValues(forKeys: keys)
            let destinationEntry = destinationDirectory.appendingPathComponent(sourceEntry.lastPathComponent, isDirectory: false)

            if values.isDirectory == true, values.isSymbolicLink != true {
                try materializeSymlinkEntries(at: sourceEntry, destination: destinationEntry)
                continue
            }
            guard values.isSymbolicLink == true else { continue }

            let linkTarget = try fileManager.destinationOfSymbolicLink(atPath: sourceEntry.path)
            let resolvedTarget = URL(fileURLWithPath: linkTarget, relativeTo: sourceEntry.deletingLastPathComponent()).standardizedFileURL
            guard fileManager.fileExists(atPath: resolvedTarget.path) else { continue }

            let destinationPath = STPath(destinationEntry.path)
            if destinationPath.isExists || destinationPath.isSymbolicLink {
                try destinationPath.deleteIncludingBrokenSymlink()
            }

            let parent = destinationEntry.deletingLastPathComponent()
            try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)
            try fileManager.copyItem(at: resolvedTarget, to: destinationEntry)
        }
    }
}
