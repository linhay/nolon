import Foundation
import ProviderCatalog
import STFilePath

public struct ProviderSkillsLinkPreflight: Sendable, Equatable {
    public let globalSkillsPath: String
    public let providerSkillsPath: String
    public let backupPath: String
    public let isAlreadyLinked: Bool
    public let isProviderSkillsEmpty: Bool
    public let requiresConfirmation: Bool

    public init(
        globalSkillsPath: String,
        providerSkillsPath: String,
        backupPath: String,
        isAlreadyLinked: Bool,
        isProviderSkillsEmpty: Bool,
        requiresConfirmation: Bool
    ) {
        self.globalSkillsPath = globalSkillsPath
        self.providerSkillsPath = providerSkillsPath
        self.backupPath = backupPath
        self.isAlreadyLinked = isAlreadyLinked
        self.isProviderSkillsEmpty = isProviderSkillsEmpty
        self.requiresConfirmation = requiresConfirmation
    }
}

public final class ProviderSkillsLinkService: @unchecked Sendable {
    private let fileManager: FileManager
    private let nolonManager: NolonManager

    public init(
        fileManager: FileManager = .default,
        nolonManager: NolonManager = .shared
    ) {
        self.fileManager = fileManager
        self.nolonManager = nolonManager
    }

    public func preflightEnable(provider: Provider) throws -> ProviderSkillsLinkPreflight {
        let globalFolder = nolonManager.skillsFolder
        _ = globalFolder.createIfNotExists()

        let providerPath = STPath(provider.defaultSkillsPath)
        let backupPath = backupPathForProviderSkills(provider: provider)

        let parentURL = URL(fileURLWithPath: provider.defaultSkillsPath).deletingLastPathComponent()
        let parentFolder = STFolder(parentURL)
        _ = parentFolder.createIfNotExists()
        guard fileManager.isWritableFile(atPath: parentFolder.url.path) else {
            throw SkillError.fileOperationFailed("Provider skills parent folder is not writable: \(parentFolder.url.path)")
        }
        guard fileManager.isWritableFile(atPath: globalFolder.url.path) else {
            throw SkillError.fileOperationFailed("Global skills folder is not writable: \(globalFolder.url.path)")
        }

        let alreadyLinked = isTargetLinked(
            to: globalFolder.url,
            targetURL: providerPath.url
        )
        let isEmpty = !hasVisibleContents(at: providerPath.url)
        let requiresConfirmation = !alreadyLinked && providerPath.isExists && !providerPath.isSymbolicLink && !isEmpty

        return ProviderSkillsLinkPreflight(
            globalSkillsPath: globalFolder.url.path,
            providerSkillsPath: providerPath.url.path,
            backupPath: backupPath,
            isAlreadyLinked: alreadyLinked,
            isProviderSkillsEmpty: isEmpty,
            requiresConfirmation: requiresConfirmation
        )
    }

    public func applyEnable(provider: Provider, backupExisting: Bool) throws {
        let globalFolder = nolonManager.skillsFolder
        _ = globalFolder.createIfNotExists()

        let targetPath = STPath(provider.defaultSkillsPath)
        let targetURL = targetPath.url
        if isTargetLinked(to: globalFolder.url, targetURL: targetURL) {
            return
        }

        if targetPath.isExists || targetPath.isSymbolicLink {
            if targetPath.isSymbolicLink {
                try targetPath.deleteIncludingBrokenSymlink()
            } else if hasVisibleContents(at: targetURL), backupExisting {
                try moveProviderSkillsToBackup(provider: provider)
            } else {
                try targetPath.deleteIncludingBrokenSymlink()
            }
        } else {
            let parent = STFolder(targetURL.deletingLastPathComponent())
            _ = parent.createIfNotExists()
        }

        try STPath(provider.defaultSkillsPath).createSymbolicLink(to: STPath(globalFolder.url.path))
    }

    public func applyDisable(provider: Provider) throws {
        let targetPath = STPath(provider.defaultSkillsPath)
        let backupPath = STPath(backupPathForProviderSkills(provider: provider))

        if targetPath.isSymbolicLink {
            try targetPath.deleteIncludingBrokenSymlink()
        }

        if backupPath.isExists || backupPath.isSymbolicLink {
            try targetPath.deleteIncludingBrokenSymlink()
            try backupPath.move(to: targetPath, isOverlay: true)
            return
        }

        _ = STFolder(provider.defaultSkillsPath).createIfNotExists()
    }
}

private extension ProviderSkillsLinkService {
    func backupPathForProviderSkills(provider: Provider) -> String {
        let targetURL = URL(fileURLWithPath: provider.defaultSkillsPath)
        return targetURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(targetURL.lastPathComponent).bak", isDirectory: true)
            .path
    }

    func moveProviderSkillsToBackup(provider: Provider) throws {
        let targetPath = STPath(provider.defaultSkillsPath)
        let backupPath = STPath(backupPathForProviderSkills(provider: provider))
        if backupPath.isExists || backupPath.isSymbolicLink {
            try backupPath.deleteIncludingBrokenSymlink()
        }
        try targetPath.move(to: backupPath, isOverlay: true)
    }

    func isTargetLinked(to sourceURL: URL, targetURL: URL) -> Bool {
        let targetPath = STPath(targetURL)
        guard targetPath.isSymbolicLink else { return false }
        guard let destination = try? targetPath.destinationOfSymbolicLink().url.standardizedFileURL.path else {
            return false
        }
        return destination == sourceURL.standardizedFileURL.path
    }

    func hasVisibleContents(at targetURL: URL) -> Bool {
        let targetPath = STPath(targetURL)
        guard targetPath.isExists else { return false }
        guard STFolder(targetURL).isExists else { return true }
        let contents = (try? STFolder(targetURL).subFilePaths()) ?? []
        return contents.contains { !$0.url.lastPathComponent.hasPrefix(".") }
    }
}
