import SwiftUI
import NolonUIFoundation

public extension View {
    func installProviderSelectionSheet(
        isPresented: Binding<Bool>,
        itemName: String,
        providers: [SkillInstallProviderOption],
        onSelectProviderID: @escaping (String) -> Void
    ) -> some View {
        self.sheet(isPresented: isPresented) {
            InstallProviderSelectionSheet(
                isPresented: isPresented,
                itemName: itemName,
                providers: providers,
                onConfirm: onSelectProviderID
            )
        }
    }
}
