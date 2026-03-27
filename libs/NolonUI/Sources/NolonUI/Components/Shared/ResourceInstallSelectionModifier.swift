import SwiftUI
import NolonUIFoundation

public extension View {
    func resourceInstallSelectionSheet(
        using viewModel: ResourceInstallSelectionViewModel
    ) -> some View {
        self.installProviderSelectionSheet(
            isPresented: Binding(
                get: { viewModel.isProviderSheetPresented },
                set: { viewModel.isProviderSheetPresented = $0 }
            ),
            itemName: viewModel.itemName,
            providers: viewModel.providers
        ) { providerID in
            viewModel.handleSelectedProvider(providerID)
        }
    }
}
