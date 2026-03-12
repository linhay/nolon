import ProviderCatalog

@MainActor
final class ProviderUsageViewModelStore {
    static let shared = ProviderUsageViewModelStore()

    private var cached: [Provider.ID: ProviderUsageViewModel] = [:]

    func viewModel(for provider: Provider) -> ProviderUsageViewModel {
        if let existing = cached[provider.id] {
            return existing
        }
        let created = ProviderUsageViewModel(provider: provider)
        cached[provider.id] = created
        return created
    }

    func clear() {
        cached.removeAll()
    }
}
