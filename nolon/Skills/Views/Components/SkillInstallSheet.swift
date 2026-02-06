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

            SheetDivider()

            Form {
                Section {
                    if providers.isEmpty {
                        Text(NSLocalizedString("No providers available. Please create a local provider first.", comment: "No providers"))
                            .dsSecondaryText(font: .body)
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
                        .dsSecondaryText(font: .body)
                }
            }
            .formStyle(.grouped)
            .sheetScrollContentPadding()
            .onAppear {
                // Auto-select first provider if available
                if selectedProviderID == nil, let firstProvider = providers.first {
                    selectedProviderID = firstProvider.id
                }
            }

            SheetDivider()

            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "Cancel")) { dismiss() }
                    .dsLinkButton()

                Spacer(minLength: 0)

                Button(NSLocalizedString("Install", comment: "Install")) {
                    if let providerID = selectedProviderID,
                        let provider = providers.first(where: { $0.id == providerID })
                    {
                        onConfirm(provider)
                        dismiss()
                    }
                }
                .dsPrimaryButton()
                .disabled(selectedProviderID == nil)
            }
            .padding(.horizontal, SheetLayout.footerHorizontalPadding)
            .padding(.vertical, SheetLayout.footerVerticalPadding)
        }
        .frame(width: 400, height: 280)
    }
}
