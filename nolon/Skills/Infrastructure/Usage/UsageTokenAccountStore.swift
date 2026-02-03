import Foundation
import ProviderUsage
import CodexBarProviderCatalog

actor UsageTokenAccountStore {
    static let shared = UsageTokenAccountStore()

    private let store: ProviderTokenAccountStoring

    init(store: ProviderTokenAccountStoring = FileTokenAccountStore(fileURL: UsageTokenAccountStore.defaultFileURL())) {
        self.store = store
    }

    func accountsData(for provider: UsageProvider) throws -> ProviderTokenAccountData? {
        let all = try self.store.loadAccounts()
        return all[provider]
    }

    func tokenAccounts(for provider: UsageProvider) throws -> [ProviderTokenAccount] {
        try self.accountsData(for: provider)?.accounts ?? []
    }

    func upsertAccount(
        provider: UsageProvider,
        label: String,
        token: String) throws
    {
        var all = try self.store.loadAccounts()
        let now = Date().timeIntervalSince1970
        let new = ProviderTokenAccount(
            id: UUID(),
            label: label.trimmingCharacters(in: .whitespacesAndNewlines),
            token: token.trimmingCharacters(in: .whitespacesAndNewlines),
            addedAt: now,
            lastUsed: nil)

        let existing = all[provider]
        var accounts = existing?.accounts ?? []
        accounts.append(new)

        let activeIndex = existing?.clampedActiveIndex() ?? 0
        all[provider] = ProviderTokenAccountData(version: 1, accounts: accounts, activeIndex: activeIndex)
        try self.store.storeAccounts(all)
    }

    func deleteAccount(provider: UsageProvider, accountID: UUID) throws {
        var all = try self.store.loadAccounts()
        guard let existing = all[provider] else { return }

        let remaining = existing.accounts.filter { $0.id != accountID }
        if remaining.isEmpty {
            all[provider] = nil
        } else {
            all[provider] = ProviderTokenAccountData(
                version: existing.version,
                accounts: remaining,
                activeIndex: min(existing.activeIndex, remaining.count - 1))
        }
        try self.store.storeAccounts(all)
    }

    static func defaultFileURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base
            .appendingPathComponent("Nolon", isDirectory: true)
            .appendingPathComponent("token-accounts.json")
    }
}
