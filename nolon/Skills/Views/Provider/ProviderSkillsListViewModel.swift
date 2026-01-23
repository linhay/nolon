import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ProviderSkillsListViewModel {
    // Dependencies
    var provider: Provider?
    let settings: ProviderSettings
    
    // State
    var allSkills: [Skill] = []
    var installedSkillIds: Set<String> = []
    var orphanedSkillStates: [ProviderSkillState] = []
    var brokenSkillStates: [ProviderSkillState] = []
    var searchText = ""
    var errorMessage: String?
    
    var skillToDelete: Skill?
    var showingDeleteAlert = false
    
    var conflictingSkillState: ProviderSkillState?
    var showingConflictAlert = false
    
    // Internals
    private var repository: SkillRepository
    private var installer: SkillInstaller
    
    init(provider: Provider?, settings: ProviderSettings) {
        self.provider = provider
        self.settings = settings
        let repo = SkillRepository()
        self.repository = repo
        self.installer = SkillInstaller(repository: repo, settings: settings)
    }
    
    // MARK: - Computed Properties
    
    var providerName: String {
        provider?.displayName ?? NSLocalizedString("skills_list.no_provider", comment: "Select a Provider")
    }
    
    var filteredSkills: [Skill] {
        if searchText.isEmpty {
            return allSkills
        }
        return allSkills.filter { $0.matches(query: searchText) }
    }
    
    var installedSkills: [Skill] {
        filteredSkills.filter { installedSkillIds.contains($0.id) }
    }
    
    var availableSkills: [Skill] {
        filteredSkills.filter { skill in
            !installedSkillIds.contains(skill.id)
                && !orphanedSkillStates.contains { $0.skillName == skill.id }
        }
    }
    
    var filteredOrphanedSkills: [ProviderSkillState] {
        if searchText.isEmpty {
            return orphanedSkillStates
        }
        return orphanedSkillStates.filter {
            $0.skillName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    var filteredBrokenSkills: [ProviderSkillState] {
        if searchText.isEmpty {
            return brokenSkillStates
        }
        return brokenSkillStates.filter {
            $0.skillName.localizedCaseInsensitiveContains(searchText)
        }
    }
    
    // MARK: - Actions
    
    func updateProvider(_ provider: Provider?) async {
        self.provider = provider
        await loadSkills()
    }
    
    func loadSkills() async {
        guard let provider = provider else {
            installedSkillIds = []
            return
        }
        
        do {
            allSkills = try repository.listSkills()
            
            // Scan provider directory
            let states = try installer.scanProvider(provider: provider)
            
            installedSkillIds = Set(states.filter { $0.state == .installed }.map(\.skillName))
            orphanedSkillStates = states.filter { $0.state == .orphaned }
            brokenSkillStates = states.filter { $0.state == .broken }
            
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func installSkill(_ skill: Skill) async {
        guard let provider = provider else { return }
        do {
            try installer.install(skill: skill, to: provider)
            await loadSkills()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func uninstallSkill(_ skill: Skill) async {
        guard let provider = provider else { return }
        do {
            try installer.uninstall(skill: skill, from: provider)
            await loadSkills()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func confirmDelete(_ skill: Skill) {
        skillToDelete = skill
        showingDeleteAlert = true
    }
    
    func performDelete(_ skill: Skill) {
        do {
            // Note: The original code logic was:
            // if installedSkillIds.contains(skill.id) { ... }
            // try FileManager.default.removeItem(atPath: skill.globalPath)
            
            try FileManager.default.removeItem(atPath: skill.globalPath)
            
            // Refresh
            Task {
                await loadSkills()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func migrateSkill(_ skillState: ProviderSkillState) async {
        guard let provider = provider else { return }
        do {
            _ = try installer.migrate(skillName: skillState.skillName, from: provider)
            await loadSkills()
        } catch let error as SkillError {
            if case .conflictDetected = error {
                conflictingSkillState = skillState
                showingConflictAlert = true
            } else {
                errorMessage = error.localizedDescription
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func migrateSkillWithOverwrite(_ skillState: ProviderSkillState) async {
        guard let provider = provider else { return }
        do {
            _ = try installer.migrate(
                skillName: skillState.skillName, from: provider, overwriteExisting: true)
            await loadSkills()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func repairSymlink(_ skillState: ProviderSkillState) async {
        guard let provider = provider else { return }
        do {
            try installer.repairSymlink(skillName: skillState.skillName, for: provider)
            await loadSkills()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func uninstallBrokenSkill(_ skillState: ProviderSkillState) async {
        guard let provider = provider else { return }
        let providerPath = provider.skillsPath
        let targetPath = "\(providerPath)/\(skillState.skillName)"
        do {
            try FileManager.default.removeItem(atPath: targetPath)
            await loadSkills()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func revealInFinder(_ path: String) {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
    }
}
