import Foundation
import ProviderCatalog
import STFilePath

public struct ProviderSkillSnapshotService: Sendable {
    private let maintenanceService: ProviderSkillMaintenanceService
    private let nolonManager: NolonManager

    public init(
        maintenanceService: ProviderSkillMaintenanceService = .init(),
        nolonManager: NolonManager = .shared
    ) {
        self.maintenanceService = maintenanceService
        self.nolonManager = nolonManager
    }

    public func load(provider: Provider) throws -> [Skill] {
        let scanPaths = providerSkillScanPaths(provider: provider)
        var skills: [Skill] = []

        for path in scanPaths {
            let providerFolder = STFolder(path)
            guard providerFolder.isExists else { continue }

            let scan = try maintenanceService.scanProviderSkills(
                providerPath: providerFolder,
                globalSkillsPath: nolonManager.skillsFolder
            )

            for state in scan.states where state.state != .broken {
                guard let parsed = parseSkill(state: state, sourcePath: scan.providerPath) else { continue }
                skills.append(parsed)
            }
        }

        return skills
    }
}

private extension ProviderSkillSnapshotService {
    func providerSkillScanPaths(provider: Provider) -> [String] {
        var paths: [String] = [provider.defaultSkillsPath]
        if let additional = provider.additionalSkillsPaths {
            for path in additional where path != provider.defaultSkillsPath {
                paths.append(path)
            }
        }
        return paths
    }

    func parseSkill(state: ProviderSkillStateItem, sourcePath: String) -> Skill? {
        let skillMDPath = STFile("\(state.path)/SKILL.md")
        guard skillMDPath.isExists,
              let content = try? skillMDPath.read(),
              var skill = try? SkillParser.parse(
                  content: content,
                  id: state.skillID,
                  globalPath: state.path
              ) else {
            return nil
        }

        skill.sourcePath = sourcePath
        skill.installationState = Self.installationState(state.state)
        return skill
    }

    static func installationState(_ state: ProviderSkillStateKind) -> SkillInstallationState {
        switch state {
        case .installed: return .installed
        case .orphaned: return .orphaned
        case .broken: return .broken
        }
    }
}
