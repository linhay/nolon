import Foundation
import ProviderCatalog
import Observation
import SwiftUI
import STFilePath
import NolonResourceKit

@MainActor
@Observable
final class ProviderSkillsViewModel {
    var selectedProviderIndex = 0
    var providerStates: [ProviderSkillState] = []
    var errorMessage: String?
    var availableUpdates: [SkillUpdateInfo] = []
    var isCheckingUpdates = false
    
    private var repository: SkillRepository
    private var installer: SkillInstaller
    private var updateChecker: SkillUpdateChecker
    var settings: ProviderSettings

    init() {
        let repo = SkillRepository()
        let sett = ProviderSettings()
        self.repository = repo
        self.settings = sett
        self.installer = SkillInstaller(repository: repo, settings: sett)
        self.updateChecker = SkillUpdateChecker()
    }
    
    var selectedProvider: Provider? {
        guard selectedProviderIndex < settings.providers.count else { return nil }
        return settings.providers[selectedProviderIndex]
    }
    
    var hasOrphanedSkills: Bool {
        providerStates.contains { $0.state == .orphaned }
    }
    
    func loadProviderStates() async {
        guard let provider = selectedProvider else {
            providerStates = []
            return
        }
        
        do {
            providerStates = try installer.scanProvider(provider: provider)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func migrateAll() async {
        guard let provider = selectedProvider else { return }
        
        do {
            _ = try installer.migrateAll(from: provider)
            await loadProviderStates()
            await onRefresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // The original view had a closure `onRefresh`. We should probably expose a callback or notification.
    // Or just reload local states.
    // The view calls `onRefresh` passed to it.
    // Wait, ProviderSkillsView defined `let onRefresh: () async -> Void`.
    // So the ViewModel should probably call that.
    var onRefreshHandler: (() async -> Void)?
    
    func onRefresh() async {
        await onRefreshHandler?()
    }
    
    // Actions for Row
    func uninstallSkill(at path: String) async {
        do {
            try STPath(path).deleteIncludingBrokenSymlink()
            await loadProviderStates()
        } catch {
            // handle error
        }
    }
    
    func migrateSkill(skillName: String) async {
        guard let provider = selectedProvider else { return }
        do {
            _ = try installer.migrate(skillName: skillName, from: provider)
            await loadProviderStates()
        } catch {
            // handle error
        }
    }
    
    func repairSymlink(skillName: String) async {
        guard let provider = selectedProvider else { return }
        do {
            try installer.repairSymlink(skillName: skillName, for: provider)
            await loadProviderStates()
        } catch {
            // handle error
        }
    }
    
    func deletePath(_ path: String) async {
        do {
            try STPath(path).deleteIncludingBrokenSymlink()
            await loadProviderStates()
        } catch {
        }
    }
    
    func checkForUpdates() async {
        isCheckingUpdates = true
        defer { isCheckingUpdates = false }
        
        availableUpdates = await updateChecker.checkForUpdates()
    }
    
    func skillHasUpdate(_ skillName: String) -> Bool {
        availableUpdates.first { $0.id == skillName }?.hasUpdate ?? false
    }
    
    func performUpdate(_ update: SkillUpdateInfo) async {
        guard let provider = selectedProvider else { return }
        
        do {
            switch update.updateSource {
            case .clawdhub:
                let zipURL = try await SkillsRepositoryFacade.downloadRemoteResource(
                    kind: .skill,
                    slug: update.id,
                    version: nil,
                    baseURL: RepositoryTemplate.clawdhub.createRepository().baseURL
                )
                defer {
                    try? STPath(zipURL).deleteIncludingBrokenSymlink()
                }
                try installer.updateSkill(slug: update.id, to: provider, zipURL: zipURL)
            default:
                break
            }
            
            await loadProviderStates()
            await checkForUpdates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
