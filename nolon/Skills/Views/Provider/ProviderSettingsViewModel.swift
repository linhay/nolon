import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class ProviderSettingsViewModel {
    var settings: ProviderSettings
    var editingProvider: Provider?
    
    init(settings: ProviderSettings) {
        self.settings = settings
    }
    
    func removeProvider(_ provider: Provider) {
        settings.removeProvider(provider)
    }
    
    func moveProvider(from source: IndexSet, to destination: Int) {
        settings.moveProvider(from: source, to: destination)
    }
    
    func removeProvider(at offsets: IndexSet) {
        settings.removeProvider(at: offsets)
    }
    
    func selectFile(for provider: Provider) {
        let url = URL(fileURLWithPath: provider.skillsPath)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}
