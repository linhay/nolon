import ProviderCatalog

@MainActor
final class ProviderUsageRootViewModelStore {
    static let shared = ProviderUsageRootViewModelStore()

    private var cached: [Provider.ID: ProviderUsageRootViewModel] = [:]

    func viewModel(for provider: Provider) -> ProviderUsageRootViewModel {
        if let existing = cached[provider.id] {
            return existing
        }
        let created = ProviderUsageRootViewModel(provider: provider)
        cached[provider.id] = created
        return created
    }

    func clear() {
        cached.removeAll()
    }
}

