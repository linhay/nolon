import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ProviderSkillsViewModel {
    var selectedProviderIndex = 0
    var providerStates: [ProviderSkillState] = []
    var errorMessage: String?
    
    // Dependencies
    private var repository: SkillRepository
    private var installer: SkillInstaller
    // We keep settings here. If ProviderSettings is ObservableObject, we might lose reactivity 
    // unless we treat it carefully. But since the original View had @StateObject var settings = ProviderSettings(), 
    // it owned a local copy. We will convert this to a property here.
    // Ideally ProviderSettings should be shared, but we respect the original View's behavior or fix it.
    // The original view init didn't take settings, so it created a fresh one.
    // We'll create one here too.
    var settings: ProviderSettings

    init() {
        let repo = SkillRepository()
        let sett = ProviderSettings()
        self.repository = repo
        self.settings = sett
        self.installer = SkillInstaller(repository: repo, settings: sett)
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
            try FileManager.default.removeItem(atPath: path)
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
            try FileManager.default.removeItem(atPath: path)
            await loadProviderStates()
        } catch {
             // handle error
        }
    }
}
