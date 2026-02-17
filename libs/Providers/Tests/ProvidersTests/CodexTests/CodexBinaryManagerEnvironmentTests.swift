import Foundation
import Testing
import STFilePath
@testable import CodexProvider

@Suite("CodexBinaryManager NOLON_HOME")
struct CodexBinaryManagerEnvironmentTests {
    @Test("Given NOLON_HOME env, when manager is initialized, then codex root uses isolated folder")
    func usesNolonHomeEnvironment() async {
        let isolatedRoot = STFolder("/tmp")
            .folder("nolon-home-binary-\(UUID().uuidString)")
            .url
            .standardizedFileURL
        let manager = CodexBinaryManager(
            environment: ["NOLON_HOME": isolatedRoot.path]
        )

        let root = await manager.rootFolder
        let expected = STFolder(isolatedRoot).folder("codex")
        #expect(root == expected)
    }

    @Test("Given explicit nolon home, when env also exists, then explicit path wins")
    func explicitNolonHomeWinsOverEnvironment() async {
        let explicitRoot = STFolder("/tmp")
            .folder("nolon-home-explicit-\(UUID().uuidString)")
            .url
            .standardizedFileURL
        let envRoot = STFolder("/tmp")
            .folder("nolon-home-env-\(UUID().uuidString)")
            .url
            .standardizedFileURL

        let manager = CodexBinaryManager(
            nolonHomeURL: explicitRoot,
            environment: ["NOLON_HOME": envRoot.path]
        )

        let root = await manager.rootFolder
        let expected = STFolder(explicitRoot).folder("codex")
        #expect(root == expected)
    }
}
