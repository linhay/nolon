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
        let targets = linkTargets(for: provider)
        guard !targets.isEmpty else { return }
        _ = nolonManager.agentsFolder.createIfNotExists()
        for target in targets {
            _ = STFolder(target.providerFile.url.deletingLastPathComponent()).createIfNotExists()
            try ensureLinked(
                providerFile: target.providerFile,
                globalFile: target.globalFile,
                backupFile: target.backupFile
            )
        }
    }

    public func applyDisable(provider: Provider) throws {
        let targets = linkTargets(for: provider)
        guard !targets.isEmpty else { return }
        for target in targets {
            try restoreFromBackupIfNeeded(target: target.providerFile, backup: target.backupFile)
        }
    }
}

private extension ProviderAgentsLinkService {
    struct LinkTarget {
        let providerFile: STFile
        let globalFile: STFile
        let backupFile: STFile
    }

    func linkTargets(for provider: Provider) -> [LinkTarget] {
        let globalBase = nolonManager.agentsFolder.file("AGENTS.md")
        let globalOverride = nolonManager.agentsFolder.file("AGENTS.override.md")

        if provider.templateId == "codex" || provider.templateId == "codexXcode" {
            return [
                LinkTarget(
                    providerFile: provider.codexAgentsFile,
                    globalFile: globalBase,
                    backupFile: provider.codexHomeFolder.file("AGENTS.md.bak")
                ),
                LinkTarget(
                    providerFile: provider.codexAgentsOverrideFile,
                    globalFile: globalOverride,
                    backupFile: provider.codexHomeFolder.file("AGENTS.override.md.bak")
                ),
            ]
        }

        if provider.templateId == ProviderTemplate.claudeCode.rawValue {
            return [
                LinkTarget(
                    providerFile: provider.claudeInstructionsFile,
                    globalFile: globalBase,
                    backupFile: provider.claudeHomeFolder.file("CLAUDE.md.bak")
                ),
            ]
        }

        if provider.templateId == "opencode" || provider.templateId == "copilot" {
            let providerHome = STFolder(URL(fileURLWithPath: provider.defaultSkillsPath).deletingLastPathComponent())
            return [
                LinkTarget(
                    providerFile: providerHome.file("AGENTS.md"),
                    globalFile: globalBase,
                    backupFile: providerHome.file("AGENTS.md.bak")
                ),
            ]
        }

        return []
    }

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
        } else if target.isExists {
            try target.deleteIncludingBrokenSymlink()
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
