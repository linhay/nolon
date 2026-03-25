import SwiftUI
import Observation
import AppKit
import ProviderCatalog
import NolonResourceKit
import NolonUI
import NolonUIFoundation

// MARK: - ViewModel

@Observable
final class ProviderSidebarViewModel {
    var editingProvider: Provider?

    var settings: ProviderSettings

    init(settings: ProviderSettings) {
        self.settings = settings
    }

    @MainActor
    func deleteProvider(_ provider: Provider, currentSelectionKey: Binding<String?>) {
        settings.removeProvider(provider)
        if currentSelectionKey.wrappedValue == ProviderSidebarAdapter.providerSelectionKey(provider.id) {
            if let firstProvider = settings.providers.first {
                currentSelectionKey.wrappedValue = ProviderSidebarAdapter.providerSelectionKey(firstProvider.id)
            } else {
                currentSelectionKey.wrappedValue = ProviderSidebarAdapter.accountsSelectionKey
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
    func selectFirstProviderIfNone(selectionKey: Binding<String?>) {
        if selectionKey.wrappedValue == nil {
            if let firstProvider = settings.providers.first {
                selectionKey.wrappedValue = ProviderSidebarAdapter.providerSelectionKey(firstProvider.id)
            } else {
                selectionKey.wrappedValue = ProviderSidebarAdapter.accountsSelectionKey
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
public struct ProviderSidebarView: View, DebugPageLocatable {
    @Binding var selectedItemKey: String?
    let settings: ProviderSettings
    @State private var viewModel: ProviderSidebarViewModel
    @State private var showingAddSheet = false
    @State private var commandState = AppCommandState.shared

    private var sidebarSections: [SidebarSection] {
        ProviderSidebarAdapter.sections(from: settings.providers)
    }

    public init(
        selectedItemKey: Binding<String?>,
        settings: ProviderSettings
    ) {
        self._selectedItemKey = selectedItemKey
        self.settings = settings
        self._viewModel = State(initialValue: ProviderSidebarViewModel(settings: settings))
    }

    var debugPageMarkerItems: [PageMarkerItem] {
        var items = [PageMarkerItem(title: "Sidebar")]
        guard let selectedItemKey,
              let selection = MainSidebarSelection(storageKey: selectedItemKey)
        else {
            return items
        }

        switch selection {
        case let .provider(providerID):
            if let provider = settings.providers.first(where: { $0.id == providerID }) {
                items.append(PageMarkerItem(title: provider.displayName))
            } else {
                items.append(PageMarkerItem(title: "Provider"))
            }
        case .accounts:
            items.append(PageMarkerItem(title: NSLocalizedString("sidebar.tools.accounts", value: "Accounts", comment: "Accounts sidebar item")))
        case .pluginManagement:
            items.append(PageMarkerItem(title: NSLocalizedString("sidebar.plugins.management", value: "Plugin Management", comment: "Plugin management sidebar item")))
        }
        return items
    }

    public var body: some View {
        ProviderSidebarComponent(
            selectedItemKey: $selectedItemKey,
            sections: sidebarSections,
            providerDebugLocatorText: { item in
                providerDebugLocatorText(for: item)
            },
            onShowInFinder: { item in
                guard let provider = provider(for: item) else { return }
                viewModel.showInFinder(provider)
            },
            onViewOfficialDocumentation: { item in
                guard let provider = provider(for: item) else { return }
                viewModel.openOfficialDocumentation(for: provider)
            },
            onEdit: { item in
                guard let provider = provider(for: item) else { return }
                viewModel.editingProvider = provider
            },
            onDeleteProvider: { item in
                guard let provider = provider(for: item) else { return }
                viewModel.deleteProvider(provider, currentSelectionKey: $selectedItemKey)
            },
            onDeleteOffsets: { section, offsets in
                let idsToDelete = Set(offsets.map { section.items[$0].id })
                let originalIndices = IndexSet(
                    settings.providers.enumerated().compactMap { index, provider in
                        idsToDelete.contains(provider.id) ? index : nil
                    }
                )
                viewModel.deleteProviders(at: originalIndices)
            },
            onMove: { section, source, destination in
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
            },
            onAddProvider: {
                showingAddSheet = true
            },
            onCopyDebugMarker: { locatorText in
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(locatorText, forType: .string)
                DebugMarkerToastCenter.shared.showCopiedPageMarkerToast(locatorText)
            }
        )
        .sheet(item: $viewModel.editingProvider) { provider in
            EditProviderSheet(settings: viewModel.settings, provider: provider)
        }
        .onAppear {
            viewModel.selectFirstProviderIfNone(selectionKey: $selectedItemKey)
        }
        .sheet(isPresented: $showingAddSheet) {
            AddProviderSheet(settings: viewModel.settings)
        }
        .debugPageLocator(debugPageMarkerItems)
    }

    private func provider(for item: SidebarProviderItem) -> Provider? {
        settings.providers.first(where: { $0.id == item.id })
    }

    private func providerDebugLocatorText(for item: SidebarProviderItem) -> String? {
        guard PageMarkerRouteResolver.isEnabledInCurrentBuild,
              commandState.isDebugPageMarkersEnabled,
              let provider = provider(for: item)
        else {
            return nil
        }

        return providerDebugLocatorText(provider)
    }

    private func providerDebugLocatorText(
        _ provider: Provider,
        fileID: String = #fileID,
        line: Int = #line,
        function: String = #function
    ) -> String {
        PageMarkerRouteResolver.locatorText(
            for: [
                PageMarkerItem(title: "Sidebar"),
                PageMarkerItem(title: provider.displayName)
            ],
            source: PageMarkerRouteResolver.source(
                fileID: fileID,
                line: line,
                function: function
            )
        )
    }
}
