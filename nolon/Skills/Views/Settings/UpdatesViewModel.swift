import Foundation
import Observation
import SwiftUI
import os.log
import STFilePath

@MainActor
@Observable
final class UpdatesViewModel {
    private let logger = Logger(subsystem: "com.nolon", category: "UpdatesViewModel")
    var availableUpdates: [SkillUpdateInfo] = []
    var isChecking = false
    var isUpdating = false
    var errorMessage: String?
    var lastCheckDate: Date?
    var updateProgress: String?
    
    private let updateChecker = SkillUpdateChecker()
    private let clawdhubRepository = ClawdhubRepository()
    private let settings = ProviderSettings()
    
    var updatableCount: Int {
        availableUpdates.filter { $0.hasUpdate }.count
    }
    
    var hasUpdates: Bool {
        updatableCount > 0
    }
    
    func checkForUpdates() async {
        isChecking = true
        defer { isChecking = false }
        
        availableUpdates = await updateChecker.checkForUpdates()
        lastCheckDate = Date()
    }
    
    func refresh() async {
        await checkForUpdates()
    }
    
    func performUpdate(_ update: SkillUpdateInfo) async {
        isUpdating = true
        updateProgress = "Updating \(update.skillName)..."
        defer {
            isUpdating = false
            updateProgress = nil
        }
        
        do {
            switch update.updateSource {
            case .clawdhub:
                try await updateClawdhubSkill(update)
            case .github:
                try await updateGitSkill(update)
            default:
                errorMessage = "Update not supported for this source"
            }
            
            await refresh()
        } catch {
            errorMessage = "Update failed: \(error.localizedDescription)"
        }
    }
    
    func updateAll() async {
        let updatesToApply = availableUpdates.filter { $0.hasUpdate }
        guard !updatesToApply.isEmpty else { return }
        
        for update in updatesToApply {
            await performUpdate(update)
        }
    }
    
    private func updateClawdhubSkill(_ update: SkillUpdateInfo) async throws {
        let zipURL = try await clawdhubRepository.downloadSkill(slug: update.id)
        defer {
            try? STPath(zipURL).deleteIncludingBrokenSymlink()
        }
        
        let repo = SkillRepository()
        let installer = SkillInstaller(repository: repo, settings: settings)
        
        let updatedSkill = try installer.updateSkillGlobal(slug: update.id, zipURL: zipURL)
        
        for provider in settings.providers {
            do {
                try installer.install(skill: updatedSkill, to: provider)
            } catch {
                logger.error("Failed to install updated skill \(update.id, privacy: .public) to provider \(provider.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    private func updateGitSkill(_ update: SkillUpdateInfo) async throws {
    }
}
