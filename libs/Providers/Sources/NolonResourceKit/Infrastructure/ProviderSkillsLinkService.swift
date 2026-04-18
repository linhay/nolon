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

    @discardableResult
    public func healManagedLinkIfNeeded(provider: Provider) throws -> Bool {
        guard provider.skillsLinkEnabled else { return false }
        return try SkillInstallRootResolver.healManagedProviderRootIfNeeded(
            providerPath: STFolder(provider.defaultSkillsPath),
            activeGlobalRoot: nolonManager.skillsFolder
        )
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

enum SkillInstallRootResolver {
    static func resolvedScannableFolder(providerPath: STFolder) -> STFolder? {
        let rawPath = STPath(providerPath.url)
        if rawPath.isSymbolicLink,
           let destination = try? rawPath.destinationOfSymbolicLink(),
           destination.isFolderExists {
            return STFolder(destination.url)
        }

        if rawPath.isFolderExists {
            return providerPath
        }

        return nil
    }

    static func resolvedProviderRootIfLinked(providerPath: STFolder) -> STFolder? {
        let standardizedProviderURL = providerPath.url.standardizedFileURL
        let resolvedProviderRootURL = providerPath.url.resolvingSymlinksInPath().standardizedFileURL

        guard standardizedProviderURL.path != resolvedProviderRootURL.path else {
            return nil
        }

        return STFolder(resolvedProviderRootURL)
    }

    static func resolvedProviderRootIfMatchesExpectedRoot(
        providerPath: STFolder,
        expectedRoot: STFolder
    ) -> STFolder? {
        let resolvedProviderRootURL = providerPath.url.resolvingSymlinksInPath().standardizedFileURL
        let resolvedExpectedRootURL = expectedRoot.url.resolvingSymlinksInPath().standardizedFileURL

        guard resolvedProviderRootURL.path == resolvedExpectedRootURL.path else {
            return nil
        }

        return STFolder(resolvedProviderRootURL)
    }

    static func resolvedProviderRootIfMirrorsSourceRoot(
        providerPath: STFolder,
        sourcePath: STPath
    ) -> STFolder? {
        resolvedProviderRootIfMatchesExpectedRoot(
            providerPath: providerPath,
            expectedRoot: STFolder(sourcePath.url.deletingLastPathComponent())
        )
    }

    @discardableResult
    static func healManagedProviderRootIfNeeded(
        providerPath: STFolder,
        activeGlobalRoot: STFolder
    ) throws -> Bool {
        let providerRootPath = STPath(providerPath.url)
        guard providerRootPath.isSymbolicLink else { return false }

        let activeGlobalRootPath = activeGlobalRoot.url.standardizedFileURL.path
        guard let destinationURL = try? providerRootPath.destinationOfSymbolicLink().url.standardizedFileURL else {
            return false
        }
        guard destinationURL.path != activeGlobalRootPath else { return false }

        let destinationFolder = STFolder(destinationURL)
        guard looksLikeManagedNolonSkillsRoot(destinationFolder) else {
            return false
        }

        try providerRootPath.deleteIncludingBrokenSymlink()
        try providerRootPath.createSymbolicLink(to: STPath(activeGlobalRootPath))
        return true
    }

    private static func looksLikeManagedNolonSkillsRoot(_ folder: STFolder) -> Bool {
        guard folder.url.lastPathComponent == "skills" else { return false }

        let homeFolder = STFolder(folder.url.deletingLastPathComponent())
        return homeFolder.folder("repositories").isExists
            && homeFolder.folder("mcps").isExists
            && homeFolder.folder("agents").isExists
    }
}
