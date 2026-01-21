import SwiftUI

struct SkillInstallSheet: View {
    let providers: [Provider]
    let skillName: String
    let onConfirm: (Provider) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedProviderID: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    if providers.isEmpty {
                        Text("No providers available. Please create a local provider first.")
                            .foregroundStyle(.secondary)
                    } else {
                        Picker("Install to", selection: $selectedProviderID) {
                            Text("Select a provider...")
                                .tag(nil as String?)
                            ForEach(providers) { provider in
                                Label(provider.name, systemImage: provider.iconName)
                                    .tag(provider.id as String?)
                            }
                        }
                    }
                } footer: {
                    Text("Select a provider folder where this skill will be installed.")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("Install \(skillName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Install") {
                        if let providerID = selectedProviderID,
                            let provider = providers.first(where: { $0.id == providerID })
                        {
                            onConfirm(provider)
                            dismiss()
                        }
                    }
                    .disabled(selectedProviderID == nil)
                }
            }
            .onAppear {
                // Auto-select first provider if available
                if selectedProviderID == nil, let firstProvider = providers.first {
                    selectedProviderID = firstProvider.id
                }
            }
        }
        .frame(width: 400, height: 250)
    }
}
