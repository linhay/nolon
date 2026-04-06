import Foundation
import ProviderCatalog
import STFilePath

public final class ProviderAgentsLinkService: @unchecked Sendable {
    private let fileManager: FileManager
    private let nolonManager: NolonManager

    public init(
        fileManager: FileManager = .default,
        nolonManager: NolonManager = .shared
    ) {
        self.fileManager = fileManager
        self.nolonManager = nolonManager
    }

    public func applyEnable(provider: Provider) throws {
        guard provider.templateId == "codex" || provider.templateId == "codexXcode" else { return }
        _ = nolonManager.agentsFolder.createIfNotExists()
        _ = provider.codexHomeFolder.createIfNotExists()

        let globalBase = nolonManager.agentsFolder.file("AGENTS.md")
        let globalOverride = nolonManager.agentsFolder.file("AGENTS.override.md")

        try ensureLinked(
            providerFile: provider.codexAgentsFile,
            globalFile: globalBase,
            backupFile: provider.codexHomeFolder.file("AGENTS.md.bak")
        )
        try ensureLinked(
            providerFile: provider.codexAgentsOverrideFile,
            globalFile: globalOverride,
            backupFile: provider.codexHomeFolder.file("AGENTS.override.md.bak")
        )
    }

    public func applyDisable(provider: Provider) throws {
        guard provider.templateId == "codex" || provider.templateId == "codexXcode" else { return }

        let baseBackup = provider.codexHomeFolder.file("AGENTS.md.bak")
        let overrideBackup = provider.codexHomeFolder.file("AGENTS.override.md.bak")
        try restoreFromBackupIfNeeded(target: provider.codexAgentsFile, backup: baseBackup)
        try restoreFromBackupIfNeeded(target: provider.codexAgentsOverrideFile, backup: overrideBackup)
    }
}

private extension ProviderAgentsLinkService {
    func ensureLinked(providerFile: STFile, globalFile: STFile, backupFile: STFile) throws {
        if isLinked(providerFile: providerFile, to: globalFile.url) {
            return
        }

        if providerFile.isSymbolicLink {
            try providerFile.deleteIncludingBrokenSymlink()
        } else if providerFile.isExists {
            if backupFile.isExists || backupFile.isSymbolicLink {
                try backupFile.deleteIncludingBrokenSymlink()
            }
            try providerFile.move(to: backupFile, isOverlay: true)
        }

        if !globalFile.isExists {
            try "".write(to: globalFile.url, atomically: true, encoding: .utf8)
        }

        try STPath(providerFile.url).createSymbolicLink(to: STPath(globalFile.url))
    }

    func restoreFromBackupIfNeeded(target: STFile, backup: STFile) throws {
        if target.isSymbolicLink {
            try target.deleteIncludingBrokenSymlink()
        }
        if backup.isExists || backup.isSymbolicLink {
            if target.isExists || target.isSymbolicLink {
                try target.deleteIncludingBrokenSymlink()
            }
            try backup.move(to: target, isOverlay: true)
        }
    }

    func isLinked(providerFile: STFile, to globalURL: URL) -> Bool {
        let path = STPath(providerFile.url)
        guard path.isSymbolicLink else { return false }
        guard let destination = try? path.destinationOfSymbolicLink().url.standardizedFileURL.path else {
            return false
        }
        return destination == globalURL.standardizedFileURL.path
    }
}
