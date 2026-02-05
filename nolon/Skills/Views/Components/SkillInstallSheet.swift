import SwiftUI
import ProviderCatalog

struct SkillInstallSheet: View {
    let providers: [Provider]
    let skillName: String
    let onConfirm: (Provider) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedProviderID: String?

    var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(
                title: NSLocalizedString("Install", comment: "Install"),
                subtitle: skillName
            ) {
                dismiss()
            }

            Form {
                Section {
                    if providers.isEmpty {
                        Text(NSLocalizedString("No providers available. Please create a local provider first.", comment: "No providers"))
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    } else {
                        Picker(NSLocalizedString("Install to", comment: "Install to"), selection: $selectedProviderID) {
                            Text(NSLocalizedString("Select a provider...", comment: "Select provider"))
                                .tag(nil as String?)
                            ForEach(providers) { provider in
                                Label(provider.name, systemImage: provider.iconName)
                                    .tag(provider.id as String?)
                            }
                        }
                    }
                } footer: {
                    Text(NSLocalizedString("Select a provider folder where this skill will be installed.", comment: "Install destination"))
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }
            }
            .formStyle(.grouped)
            .onAppear {
                // Auto-select first provider if available
                if selectedProviderID == nil, let firstProvider = providers.first {
                    selectedProviderID = firstProvider.id
                }
            }

            Divider()
                .background(DesignSystem.Colors.Component.separator.opacity(0.25))

            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "Cancel")) { dismiss() }
                    .buttonStyle(.plain)

                Spacer(minLength: 0)

                Button(NSLocalizedString("Install", comment: "Install")) {
                    if let providerID = selectedProviderID,
                        let provider = providers.first(where: { $0.id == providerID })
                    {
                        onConfirm(provider)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedProviderID == nil)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 400, height: 280)
    }
}
