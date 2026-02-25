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
    private var updateOrchestrator: SkillUpdateOrchestrator
    private var maintenanceService = ProviderSkillMaintenanceService()
    var settings: ProviderSettings

    init() {
        let repo = SkillRepository()
        let sett = ProviderSettings()
        self.repository = repo
        self.settings = sett
        self.installer = SkillInstaller(repository: repo, settings: sett)
        self.updateOrchestrator = SkillUpdateOrchestrator(repository: repo, settings: sett)
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
            let scan = try maintenanceService.scanProviderSkills(
                providerPath: STFolder(provider.defaultSkillsPath),
                globalSkillsPath: NolonManager.shared.skillsFolder
            )
            providerStates = scan.states.map { state in
                ProviderSkillState(
                    skillName: state.skillID,
                    state: {
                        switch state.state {
                        case .installed: return .installed
                        case .orphaned: return .orphaned
                        case .broken: return .broken
                        }
                    }(),
                    path: state.path,
                    basePath: provider.defaultSkillsPath
                )
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func migrateAll() async {
        guard let provider = selectedProvider else { return }
        
        do {
            let scan = try maintenanceService.scanProviderSkills(
                providerPath: STFolder(provider.defaultSkillsPath),
                globalSkillsPath: NolonManager.shared.skillsFolder
            )
            for state in scan.states where state.state == .orphaned {
                _ = try maintenanceService.migrateSkill(
                    skillID: state.skillID,
                    providerPath: STFolder(provider.defaultSkillsPath),
                    globalSkillsPath: NolonManager.shared.skillsFolder,
                    installMethod: provider.installMethod
                )
            }
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
        guard let provider = selectedProvider else { return }
        do {
            let skillID = URL(fileURLWithPath: path).lastPathComponent
            _ = try maintenanceService.uninstallSkill(
                skillID: skillID,
                providerPath: STFolder(provider.defaultSkillsPath)
            )
            await loadProviderStates()
        } catch {
            // handle error
        }
    }
    
    func migrateSkill(skillName: String) async {
        guard let provider = selectedProvider else { return }
        do {
            _ = try maintenanceService.migrateSkill(
                skillID: skillName,
                providerPath: STFolder(provider.defaultSkillsPath),
                globalSkillsPath: NolonManager.shared.skillsFolder,
                installMethod: provider.installMethod
            )
            await loadProviderStates()
        } catch {
            // handle error
        }
    }
    
    func repairSymlink(skillName: String) async {
        guard let provider = selectedProvider else { return }
        do {
            _ = try maintenanceService.repairSkill(
                skillID: skillName,
                providerPath: STFolder(provider.defaultSkillsPath),
                globalSkillsPath: NolonManager.shared.skillsFolder,
                installMethod: provider.installMethod
            )
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
        
        availableUpdates = await updateOrchestrator.checkForUpdates()
    }
    
    func skillHasUpdate(_ skillName: String) -> Bool {
        availableUpdates.first { $0.id == skillName }?.hasUpdate ?? false
    }
    
    func performUpdate(_ update: SkillUpdateInfo) async {
        guard let provider = selectedProvider else { return }
        
        do {
            let result = try await updateOrchestrator.update(update)
            if !result.appliedProviderIDs.contains(provider.id),
               let warning = result.warnings.first {
                errorMessage = warning
            }
            await loadProviderStates()
            await checkForUpdates()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
