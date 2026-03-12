import SwiftUI
import Observation
import ProviderCatalog
import NolonResourceKit

// MARK: - ViewModel

@Observable
final class ProviderSidebarViewModel {
    var editingProvider: Provider?
    
    var settings: ProviderSettings
    
    init(settings: ProviderSettings) {
        self.settings = settings
    }
    
    @MainActor
    func deleteProvider(_ provider: Provider, currentSelection: Binding<MainSidebarSelection?>) {
        settings.removeProvider(provider)
        if currentSelection.wrappedValue == .provider(provider.id) {
            if let firstProvider = settings.providers.first {
                currentSelection.wrappedValue = .provider(firstProvider.id)
            } else {
                currentSelection.wrappedValue = .accounts
            }
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
    func moveProviders<Value: Equatable>(
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
    func selectFirstProviderIfNone(selection: Binding<MainSidebarSelection?>) {
        if selection.wrappedValue == nil {
            if let firstProvider = settings.providers.first {
                selection.wrappedValue = .provider(firstProvider.id)
            } else {
                selection.wrappedValue = .accounts
            }
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
    @Binding var selectedItem: MainSidebarSelection?
    @ObservedObject var settings: ProviderSettings
    @State private var viewModel: ProviderSidebarViewModel
    @State private var showingAddSheet = false

    private var providerSections: [ProviderPresentationSections.ProviderSection] {
        ProviderPresentationSections.providerSections(providers: settings.providers)
    }
    
    public init(
        selectedItem: Binding<MainSidebarSelection?>,
        settings: ProviderSettings
    ) {
        self._selectedItem = selectedItem
        self.settings = settings
        self._viewModel = State(initialValue: ProviderSidebarViewModel(settings: settings))
    }
    
    public var body: some View {
        List(selection: $selectedItem) {
            ForEach(providerSections) { section in
                Section {
                    ForEach(section.providers) { provider in
                        ProviderRowView(
                            provider: provider,
                            isSelected: selectedItem == .provider(provider.id),
                            onShowInFinder: { viewModel.showInFinder(provider) },
                            onViewOfficialDocumentation: { viewModel.openOfficialDocumentation(for: provider) },
                            onEdit: { viewModel.editingProvider = provider },
                            onDelete: { viewModel.deleteProvider(provider, currentSelection: $selectedItem) }
                        )
                        .tag(MainSidebarSelection.provider(provider.id))
                    }
                    .onDelete { offsets in
                        let idsToDelete = Set(offsets.map { section.providers[$0].id })
                        let originalIndices = IndexSet(
                            settings.providers.enumerated().compactMap { index, provider in
                                idsToDelete.contains(provider.id) ? index : nil
                            }
                        )
                        viewModel.deleteProviders(at: originalIndices)
                    }
                    .onMove { source, destination in
                        switch section.id {
                        case .originalVendors:
                            viewModel.moveProviders(
                                in: \.vendorCategory,
                                matching: .original,
                                from: source,
                                to: destination
                            )
                        case .integratedVendors:
                            viewModel.moveProviders(
                                in: \.vendorCategory,
                                matching: .integrated,
                                from: source,
                                to: destination
                            )
                        case .projects:
                            viewModel.moveProviders(in: \.kind, matching: .project, from: source, to: destination)
                        }
                    }
                } header: {
                    Text(NSLocalizedString(section.titleKey, value: section.fallbackTitle, comment: "Provider section title"))
                }
            }

            Section {
                Label(
                    NSLocalizedString("sidebar.tools.accounts", value: "Accounts", comment: "Accounts sidebar item"),
                    systemImage: "person.crop.circle.badge.checkmark"
                )
                .tag(MainSidebarSelection.accounts)

                Label(
                    NSLocalizedString("sidebar.plugins.management", value: "Plugin Management", comment: "Plugin management sidebar item"),
                    systemImage: "puzzlepiece.extension"
                )
                .tag(MainSidebarSelection.pluginManagement)
            } header: {
                Text(NSLocalizedString("sidebar.section.tools", value: "Tools", comment: "Tools section"))
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(NSLocalizedString("app.title", comment: "nolon"))

        .sheet(item: $viewModel.editingProvider) { provider in
            EditProviderSheet(settings: viewModel.settings, provider: provider)
        }
        .onAppear {
            viewModel.selectFirstProviderIfNone(selection: $selectedItem)
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
