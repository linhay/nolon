import SwiftUI
import NolonUIFoundation

public struct SkillInstallSheetView: View {
    @State private var viewModel: SkillInstallSheetViewModel

    public init(viewModel: SkillInstallSheetViewModel) {
        self._viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 0) {
            SheetHeaderView(
                title: NSLocalizedString("Install", comment: "Install"),
                subtitle: viewModel.data.skillName
            ) {
                viewModel.cancel()
            }

            Divider()

            Form {
                Section {
                    if viewModel.data.providers.isEmpty {
                        Text(NSLocalizedString("No providers available. Please create a local provider first.", comment: "No providers"))
                            .font(.body)
                            .foregroundStyle(DesignSystem.Colors.Text.secondary)
                    } else {
                        Picker(NSLocalizedString("Install to", comment: "Install to"), selection: $viewModel.selectedProviderID) {
                            Text(NSLocalizedString("Select a provider...", comment: "Select provider"))
                                .tag(nil as String?)
                            ForEach(viewModel.data.providers) { provider in
                                if let iconName = provider.iconName {
                                    Label(provider.name, systemImage: iconName)
                                        .tag(provider.id as String?)
                                } else {
                                    Text(provider.name)
                                        .tag(provider.id as String?)
                                }
                            }
                        }
                    }
                } footer: {
                    Text(NSLocalizedString("Select a provider folder where this skill will be installed.", comment: "Install destination"))
                        .font(.body)
                        .foregroundStyle(DesignSystem.Colors.Text.secondary)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack(spacing: 12) {
                Button(NSLocalizedString("Cancel", comment: "Cancel")) {
                    viewModel.cancel()
                }
                .dsLinkButton()

                Spacer(minLength: 0)

                Button(NSLocalizedString("Install", comment: "Install")) {
                    viewModel.confirmInstall()
                }
                .dsPrimaryButton()
                .disabled(viewModel.selectedProviderID == nil)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .frame(width: 400, height: 280)
    }
}
