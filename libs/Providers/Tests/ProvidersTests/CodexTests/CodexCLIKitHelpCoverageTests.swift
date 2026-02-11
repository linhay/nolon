import Foundation
import Testing
@testable import CodexCLIKit

@Suite("CodexCLIKit Help Coverage")
struct CodexCLIKitHelpCoverageTests {
    private var executor: CodexCommandExecutor {
        CodexCommandExecutor()
    }

    @Test("Top-level command set matches current codex --help")
    func topLevelCoverage() async throws {
        guard executor.resolveExecutable() != nil else { return }

        let scanner = CodexHelpScanner(executor: executor)
        let node = try await scanner.scanTopLevel()
        let actual = node.commands
        let expected = CodexCLIReference.supportedTopLevelCommands()

        #expect(actual == expected)

        for (command, expectedSubcommands) in CodexCLIReference.expectedSubcommandsByTopLevel() {
            let subNode = try await scanner.scan(commandPath: [command])
            #expect(subNode.commands == expectedSubcommands)
        }
    }
}
