import Testing
import ProviderCatalog
@testable import nolon

@MainActor
struct CodexImportExportViewModelParityTests {
    @Test("BDD: Given root and engine state when reading import sheet state then values stay parity")
    func testBDD_GivenRootAndEngineState_WhenReadingImportSheetState_ThenValuesStayParity() {
        let provider = Provider(
            id: "codex",
            kind: .vendor,
            name: "Codex",
            defaultSkillsPath: "/tmp/codex/skills",
            workflowPath: "/tmp/codex/prompts",
            vendorCategory: .original,
            templateId: ProviderTemplate.codex.rawValue
        )
        let root = ProviderUsageRootViewModel(provider: provider)

        #expect(root.importExportViewModel.isShowingCodexImportSheet == root.state.engine.isShowingCodexImportSheet)
        #expect(root.importExportViewModel.sheetViewModel.sections == root.state.engine.codexImportCandidateSections)
    }
}
