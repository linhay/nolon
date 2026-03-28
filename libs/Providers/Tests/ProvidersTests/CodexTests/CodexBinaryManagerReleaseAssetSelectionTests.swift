import Testing
@testable import CodexProvider

@Suite("CodexBinaryManager Release Asset Selection")
struct CodexBinaryManagerReleaseAssetSelectionTests {
    @Test("Given mixed Rust release assets, when selecting codex archive, then choose exact codex binary tarball")
    func selectsExactCodexTarball() {
        let assets = [
            "argument-comment-lint-aarch64-apple-darwin.tar.gz",
            "codex-responses-api-proxy-aarch64-apple-darwin.tar.gz",
            "codex-aarch64-apple-darwin.tar.gz",
            "codex-zsh-aarch64-apple-darwin.tar.gz"
        ]

        let selected = CodexBinaryManager.preferredCodexArchiveAssetName(
            from: assets,
            architectureNeedle: "aarch64-apple-darwin"
        )

        #expect(selected == "codex-aarch64-apple-darwin.tar.gz")
    }

    @Test("Given no exact architecture tarball, when selecting codex archive, then fallback to legacy codex.tar.gz")
    func fallsBackToLegacyCodexTarball() {
        let assets = [
            "argument-comment-lint-aarch64-apple-darwin.tar.gz",
            "codex.tar.gz"
        ]

        let selected = CodexBinaryManager.preferredCodexArchiveAssetName(
            from: assets,
            architectureNeedle: "aarch64-apple-darwin"
        )

        #expect(selected == "codex.tar.gz")
    }

    @Test("Given no codex binary archive asset, when selecting codex archive, then return nil")
    func returnsNilWhenCodexArchiveMissing() {
        let assets = [
            "argument-comment-lint-aarch64-apple-darwin.tar.gz",
            "codex-responses-api-proxy-aarch64-apple-darwin.tar.gz",
            "codex-zsh-aarch64-apple-darwin.tar.gz"
        ]

        let selected = CodexBinaryManager.preferredCodexArchiveAssetName(
            from: assets,
            architectureNeedle: "aarch64-apple-darwin"
        )

        #expect(selected == nil)
    }
}
