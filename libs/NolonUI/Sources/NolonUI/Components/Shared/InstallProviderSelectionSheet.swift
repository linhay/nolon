import SwiftUI
import NolonUIFoundation

public struct InstallProviderSelectionSheet: View {
    @Binding var isPresented: Bool
    let itemName: String
    let providers: [SkillInstallProviderOption]
    let onConfirm: (String) -> Void

    public init(
        isPresented: Binding<Bool>,
        itemName: String,
        providers: [SkillInstallProviderOption],
        onConfirm: @escaping (String) -> Void
    ) {
        self._isPresented = isPresented
        self.itemName = itemName
        self.providers = providers
        self.onConfirm = onConfirm
    }

    public var body: some View {
        SkillInstallSheetView(
            viewModel: SkillInstallSheetViewModel(
                data: .init(
                    skillName: itemName,
                    providers: providers
                ),
                onConfirm: { providerID in
                    onConfirm(providerID)
                    isPresented = false
                },
                onCancel: {
                    isPresented = false
                }
            )
        )
    }
}
