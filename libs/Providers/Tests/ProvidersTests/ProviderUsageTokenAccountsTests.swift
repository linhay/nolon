import Foundation
import Testing
import ProviderUsage
import STFilePath

@Suite("ProviderUsage TokenAccounts")
struct ProviderUsageTokenAccountsTests {
    @Test("FileTokenAccountStore supports STFile")
    func fileTokenAccountStoreSupportsSTFile() throws {
        let root = STFolder(FileManager.default.temporaryDirectory
            .appendingPathComponent("provider-token-accounts-\(UUID().uuidString)", isDirectory: true))
        _ = root.createIfNotExists()
        defer { try? root.delete() }

        let storeFile = root.folder("nested").file("token-accounts.json")
        let store = FileTokenAccountStore(file: storeFile)

        let account = ProviderTokenAccount(
            id: UUID(),
            label: "token-a",
            token: "tok-value",
            addedAt: 1_739_000_000,
            lastUsed: nil
        )
        let payload = ProviderTokenAccountData(version: 1, accounts: [account], activeIndex: 0)
        try store.storeAccounts([.codex: payload])

        let reloaded = try store.loadAccounts()
        #expect(storeFile.isExists == true)
        #expect(reloaded[.codex]?.accounts.first?.token == "tok-value")
    }
}
