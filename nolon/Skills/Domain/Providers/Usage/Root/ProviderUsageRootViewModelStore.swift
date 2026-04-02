import ProviderCatalog

@MainActor
final class ProviderUsageRootViewModelStore {
    static let shared = ProviderUsageRootViewModelStore()

    private var cached: [Provider.ID: ProviderUsageRootViewModel] = [:]

    func viewModel(for provider: Provider) -> ProviderUsageRootViewModel {
        if let existing = cached[provider.id] {
            if existing.provider == provider {
                return existing
            }
            let recreated = ProviderUsageRootViewModel(provider: provider)
            cached[provider.id] = recreated
            return recreated
        }
        let created = ProviderUsageRootViewModel(provider: provider)
        cached[provider.id] = created
        return created
    }

    func clear() {
        cached.removeAll()
    }
}
