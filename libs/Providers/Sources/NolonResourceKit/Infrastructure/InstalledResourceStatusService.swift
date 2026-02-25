import Foundation
import ProviderCatalog
import STFilePath

public final class InstalledResourceStatusService: @unchecked Sendable {
    private let fileManager: FileManager
    private let nolonManager: NolonManager

    public init(
        fileManager: FileManager = .default,
        nolonManager: NolonManager = .shared
    ) {
        self.fileManager = fileManager
        self.nolonManager = nolonManager
    }

    @MainActor
    public func installedSkillIDs(
        provider: Provider?,
        repository: SkillRepository,
        settings: ProviderSettings
    ) throws -> Set<String> {
        guard let provider else {
            return Set(try repository.listSkills().map(\.id))
        }

        let installer = SkillInstaller(
            repository: repository,
            settings: settings,
            nolonManager: nolonManager
        )
        let states = try installer.scanProvider(provider: provider)
        return Set(states.filter { $0.state == .installed }.map(\.skillName))
    }

    public func installedWorkflowIDs(provider: Provider?) -> Set<String> {
        guard let provider else { return [] }
        let folder = STFolder(provider.workflowPath)
        guard folder.isExists, let files = try? folder.files() else { return [] }
        return Set(
            files.compactMap { file in
                guard file.url.pathExtension.lowercased() == "md" else { return nil }
                return file.url.deletingPathExtension().lastPathComponent
            }
        )
    }

    public func installedMcpIDs(provider: Provider?) -> Set<String> {
        (try? installedMcpIDsStrict(provider: provider)) ?? []
    }

    public func installedMcpIDsStrict(provider: Provider?) throws -> Set<String> {
        guard let provider else {
            return slugsFromGlobalMcpCache()
        }
        guard let templateID = provider.templateId,
              let template = ProviderTemplate(rawValue: templateID) else {
            return []
        }
        let servers = try MCPConfigManager.listServers(for: template)
        return Set(servers.map(\.name))
    }

    private func slugsFromGlobalMcpCache() -> Set<String> {
        let folder = STFolder(nolonManager.mcpsURL)
        guard folder.isExists, let files = try? folder.files() else { return [] }
        return Set(
            files.compactMap { file in
                let name = file.url.lastPathComponent
                guard !name.hasPrefix(".") else { return nil }
                if file.url.pathExtension.lowercased() == "json" {
                    return file.url.deletingPathExtension().lastPathComponent
                }
                return name
            }
        )
    }
}
