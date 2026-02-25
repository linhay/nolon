import Foundation
import ProviderCatalog
import STFilePath

public struct SkillUpdateApplyResult: Sendable, Equatable {
    public let updatedSkillID: String
    public let source: SkillUpdateInfo.UpdateSource
    public let appliedProviderIDs: [String]
    public let warnings: [String]

    public init(
        updatedSkillID: String,
        source: SkillUpdateInfo.UpdateSource,
        appliedProviderIDs: [String],
        warnings: [String]
    ) {
        self.updatedSkillID = updatedSkillID
        self.source = source
        self.appliedProviderIDs = appliedProviderIDs
        self.warnings = warnings
    }
}

@MainActor
public final class SkillUpdateOrchestrator: @unchecked Sendable {
    private let updateChecker: SkillUpdateChecker
    private let repository: SkillRepository
    private let settings: ProviderSettings

    public init(
        updateChecker: SkillUpdateChecker = .init(),
        repository: SkillRepository = .init(),
        settings: ProviderSettings = .shared
    ) {
        self.updateChecker = updateChecker
        self.repository = repository
        self.settings = settings
    }

    public func checkForUpdates() async -> [SkillUpdateInfo] {
        await updateChecker.checkForUpdates()
    }

    public func update(_ update: SkillUpdateInfo) async throws -> SkillUpdateApplyResult {
        switch update.updateSource {
        case .clawdhub:
            return try await applyClawdhubUpdate(update)
        case .github, .gitlab, .local:
            return SkillUpdateApplyResult(
                updatedSkillID: update.id,
                source: update.updateSource,
                appliedProviderIDs: [],
                warnings: ["Update not supported for source \(update.updateSource.rawValue)"]
            )
        }
    }

    private func applyClawdhubUpdate(_ update: SkillUpdateInfo) async throws -> SkillUpdateApplyResult {
        let zipURL = try await SkillsRepositoryFacade.downloadRemoteResource(
            kind: .skill,
            slug: update.id,
            version: nil,
            baseURL: RepositoryTemplate.clawdhub.createRepository().baseURL
        )
        defer {
            try? STPath(zipURL).deleteIncludingBrokenSymlink()
        }

        let installer = SkillInstaller(repository: repository, settings: settings)
        let updatedSkill = try installer.updateSkillGlobal(slug: update.id, zipURL: zipURL)
        var appliedProviderIDs: [String] = []
        var warnings: [String] = []
        for provider in settings.providers {
            do {
                try installer.install(skill: updatedSkill, to: provider)
                appliedProviderIDs.append(provider.id)
            } catch {
                warnings.append("\(provider.id): \(error.localizedDescription)")
            }
        }
        return SkillUpdateApplyResult(
            updatedSkillID: update.id,
            source: .clawdhub,
            appliedProviderIDs: appliedProviderIDs.sorted(),
            warnings: warnings
        )
    }
}
