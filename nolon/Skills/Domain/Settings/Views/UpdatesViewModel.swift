import Foundation
import Observation
import SwiftUI
import NolonResourceKit

@MainActor
@Observable
final class UpdatesViewModel {
    var availableUpdates: [SkillUpdateInfo] = []
    var isChecking = false
    var isUpdating = false
    var errorMessage: String?
    var lastCheckDate: Date?
    var updateProgress: String?
    
    private let updateOrchestrator: SkillUpdateOrchestrator
    
    init(updateOrchestrator: SkillUpdateOrchestrator? = nil) {
        self.updateOrchestrator = updateOrchestrator ?? SkillUpdateOrchestrator()
    }

    var updatableCount: Int {
        availableUpdates.filter { $0.hasUpdate }.count
    }
    
    var hasUpdates: Bool {
        updatableCount > 0
    }
    
    func checkForUpdates() async {
        isChecking = true
        defer { isChecking = false }
        
        availableUpdates = await updateOrchestrator.checkForUpdates()
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
            let result = try await updateOrchestrator.update(update)
            if let warning = result.warnings.first {
                errorMessage = warning
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
}
