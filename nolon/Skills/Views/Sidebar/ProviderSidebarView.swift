import SwiftUI
import Observation

// MARK: - ViewModel

@Observable
final class ProviderSidebarViewModel {
    var editingProvider: Provider?
    
    var settings: ProviderSettings
    
    init(settings: ProviderSettings) {
        self.settings = settings
    }
    
    @MainActor
    func deleteProvider(_ provider: Provider, currentSelection: Binding<Provider.ID?>) {
        settings.removeProvider(provider)
        if currentSelection.wrappedValue == provider.id {
            currentSelection.wrappedValue = settings.providers.first?.id
        }
    }
    
    @MainActor
    func deleteProviders(at offsets: IndexSet) {
        settings.removeProvider(at: offsets)
    }
    
    @MainActor
    func moveProviders(from source: IndexSet, to destination: Int) {
        settings.moveProvider(from: source, to: destination)
    }
    
    @MainActor
    func selectFirstProviderIfNone(selection: Binding<Provider.ID?>) {
        if selection.wrappedValue == nil {
            selection.wrappedValue = settings.providers.first?.id
        }
    }
    
    @MainActor
    func showInFinder(_ provider: Provider) {
        let url = URL(fileURLWithPath: provider.defaultSkillsPath)
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: url.path)
    }
}

// MARK: - View

/// Left column 1: Provider sidebar (collapsible)
/// Displays the unified list of all providers with selection state
@MainActor
public struct ProviderSidebarView: View {
    @Binding var selectedProviderId: Provider.ID?
    @ObservedObject var settings: ProviderSettings
    @State private var viewModel: ProviderSidebarViewModel
    @State private var showingAddSheet = false
    
    public init(
        selectedProviderId: Binding<Provider.ID?>,
        settings: ProviderSettings
    ) {
        self._selectedProviderId = selectedProviderId
        self.settings = settings
        self._viewModel = State(initialValue: ProviderSidebarViewModel(settings: settings))
    }
    
    public var body: some View {
        List(selection: $selectedProviderId) {
            Section {
                ForEach(settings.providers) { provider in
                    ProviderRowView(
                        provider: provider,
                        isSelected: selectedProviderId == provider.id,
                        onShowInFinder: { viewModel.showInFinder(provider) },
                        onEdit: { viewModel.editingProvider = provider },
                        onDelete: { viewModel.deleteProvider(provider, currentSelection: $selectedProviderId) }
                    )
                    .tag(provider.id)
                }
                .onDelete { offsets in
                    viewModel.deleteProviders(at: offsets)
                }
                .onMove { source, destination in
                    viewModel.moveProviders(from: source, to: destination)
                }
            } header: {
                Text(NSLocalizedString("sidebar.providers", comment: "Providers"))
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(NSLocalizedString("app.title", comment: "nolon"))

        .sheet(item: $viewModel.editingProvider) { provider in
            EditProviderSheet(settings: viewModel.settings, provider: provider)
        }
        .onAppear {
            viewModel.selectFirstProviderIfNone(selection: $selectedProviderId)
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label(NSLocalizedString("action.add_provider", value: "Add Provider", comment: "Add Provider"), systemImage: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddProviderSheet(settings: viewModel.settings)
        }
    }
}
