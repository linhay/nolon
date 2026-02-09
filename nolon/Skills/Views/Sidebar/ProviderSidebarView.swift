import SwiftUI
import Observation
import ProviderCatalog

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
    func moveVendorProviders(from source: IndexSet, to destination: Int) {
        moveProviders(in: \.kind, matching: .vendor, from: source, to: destination)
    }

    @MainActor
    private func moveProviders<Value: Equatable>(
        in keyPath: KeyPath<Provider, Value>,
        matching value: Value,
        from source: IndexSet,
        to destination: Int
    ) {
        guard !source.isEmpty else { return }

        let allProviders = settings.providers
        let matchingIndices = allProviders.indices.filter { allProviders[$0][keyPath: keyPath] == value }
        var matchingProviders = matchingIndices.map { allProviders[$0] }

        matchingProviders.move(fromOffsets: source, toOffset: destination)

        var updatedProviders = allProviders
        for (offset, index) in matchingIndices.enumerated() {
            updatedProviders[index] = matchingProviders[offset]
        }

        settings.providers = updatedProviders
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

    @MainActor
    func openOfficialDocumentation(for provider: Provider) {
        guard let url = provider.documentationURL else { return }
        NSWorkspace.shared.open(url)
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

    private var vendorProviders: [Provider] {
        settings.providers.filter { $0.kind == .vendor }
    }

    private var projectProviders: [Provider] {
        settings.providers.filter { $0.kind == .project }
    }
    
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
            if !vendorProviders.isEmpty {
                Section {
                    ForEach(vendorProviders) { provider in
                        ProviderRowView(
                            provider: provider,
                            isSelected: selectedProviderId == provider.id,
                            onShowInFinder: { viewModel.showInFinder(provider) },
                            onViewOfficialDocumentation: { viewModel.openOfficialDocumentation(for: provider) },
                            onEdit: { viewModel.editingProvider = provider },
                            onDelete: { viewModel.deleteProvider(provider, currentSelection: $selectedProviderId) }
                        )
                        .tag(provider.id)
                    }
                    .onDelete { offsets in
                        let idsToDelete = Set(offsets.map { vendorProviders[$0].id })
                        let originalIndices = IndexSet(
                            settings.providers.enumerated().compactMap { index, provider in
                                idsToDelete.contains(provider.id) ? index : nil
                            }
                        )
                        viewModel.deleteProviders(at: originalIndices)
                    }
                    .onMove { source, destination in
                        viewModel.moveVendorProviders(from: source, to: destination)
                    }
                } header: {
                    Text(NSLocalizedString("sidebar.providers.vendors", value: "Vendors", comment: "Vendor providers section"))
                }
            }

            if !projectProviders.isEmpty {
                Section {
                    ForEach(projectProviders) { provider in
                        ProviderRowView(
                            provider: provider,
                            isSelected: selectedProviderId == provider.id,
                            onShowInFinder: { viewModel.showInFinder(provider) },
                            onViewOfficialDocumentation: { viewModel.openOfficialDocumentation(for: provider) },
                            onEdit: { viewModel.editingProvider = provider },
                            onDelete: { viewModel.deleteProvider(provider, currentSelection: $selectedProviderId) }
                        )
                        .tag(provider.id)
                    }
                    .onDelete { offsets in
                        let idsToDelete = Set(offsets.map { projectProviders[$0].id })
                        let originalIndices = IndexSet(
                            settings.providers.enumerated().compactMap { index, provider in
                                idsToDelete.contains(provider.id) ? index : nil
                            }
                        )
                        viewModel.deleteProviders(at: originalIndices)
                    }
                } header: {
                    Text(NSLocalizedString("sidebar.providers.projects", value: "Projects", comment: "Project providers section"))
                }
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
                        .dsIconLabelButton()
                }
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            AddProviderSheet(settings: viewModel.settings)
        }
    }
}
