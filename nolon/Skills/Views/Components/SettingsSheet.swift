import SwiftUI

/// Top-right toolbar: Settings popover/sheet
/// Reuses ProviderSettingsView content in a sheet presentation
@MainActor
public struct SettingsSheet: View {
    @ObservedObject var settings: ProviderSettings
    @Environment(\.dismiss) private var dismiss
    
    public init(settings: ProviderSettings) {
        self.settings = settings
    }
    
    public var body: some View {
        NavigationStack {
            ProviderSettingsView(settings: settings)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(NSLocalizedString("generic.done", comment: "Done")) {
                            dismiss()
                        }
                    }
                }
        }
        .frame(minWidth: 500, minHeight: 400)
    }
}
